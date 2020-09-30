import Dispatch
import struct Foundation.UUID
import Cinput
import SystemPackage

public struct InputDevice: Equatable {
    public let eventFile: FilePath
    public let grabsDevice: Bool

	public init(eventFile: FilePath, grabDevice: Bool = true) {
		self.eventFile = eventFile
        self.grabsDevice = grabDevice
	}

	public func startReceivingEvents(informing eventConsumer: EventConsumer) throws {
        let streamer = InputDevice.makeStreamer(for: self)
        streamer.addHandler(eventConsumer)
        try streamer.beginStreaming()
	}

	public func stopReceivingEvents() throws {
        guard let streamer = InputDevice.removeStreamer(for: self) else { return }
        try streamer.close()
	}

	public func add(eventConsumer: EventConsumer) {
        InputDevice.streamer(for: self)?.addHandler(eventConsumer)
	}

	public func remove(eventConsumer: EventConsumer) {
        InputDevice.streamer(for: self)?.removeHandler(eventConsumer)
	}

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.eventFile == rhs.eventFile
    }
}

extension InputDevice {
    private static let fileStreamersLock = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamers.lock")
    private static var fileStreamers: [FilePath: Streamer] = [:]

    fileprivate static func streamer(for device: InputDevice) -> Streamer? {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return fileStreamersLock.sync { fileStreamers[device.eventFile] }
    }

    fileprivate static func makeStreamer(for device: InputDevice) -> Streamer {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return fileStreamersLock.sync {
            if let existingStreamer = fileStreamers[device.eventFile] { return existingStreamer }
            let newStreamer = Streamer(inputDevice: device)
            fileStreamers[device.eventFile] = newStreamer
            return newStreamer
        }
    }

    fileprivate static func removeStreamer(for device: InputDevice) -> Streamer? {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return fileStreamersLock.sync { fileStreamers.removeValue(forKey: device.eventFile) }
    }
}

extension InputDevice {
	public struct EventConsumer: Hashable {
		private let uuid = UUID()
		public let queue: DispatchQueue
		public let handler: (InputDevice, InputEvent) -> Void

        public init(queue: DispatchQueue, handler: @escaping (InputDevice, InputEvent) -> Void) {
            self.queue = queue
            self.handler = handler
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(uuid)
        }

		public static func ==(lhs: Self, rhs: Self) -> Bool {
			lhs.uuid == rhs.uuid
		}

        fileprivate func notify(about event: InputEvent, from device: InputDevice) {
            queue.async { handler(device, event) }
        }
	}
}

extension InputDevice {
    fileprivate final class Streamer {
        private typealias FileSource = DispatchSourceRead
        private enum State {
            case closed
            case open(FileDescriptor)
            case streaming(FileDescriptor, FileSource)
        }

        private struct Storage {
            var state: State = .closed
            var handler: Set<InputDevice.EventConsumer> = []
        }

        let device: InputDevice

        private let storageLock = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamer.storage.lock")
        private var storage = Storage()

		init(inputDevice: InputDevice) {
            device = inputDevice
		}

		deinit {
            do {
                try close()
            } catch {
                print("Trying to close the file descriptor at \(device.eventFile) on streamer deallocation failed: \(error)")
            }
        }

        private func withStorage<T>(do work: (inout Storage) throws -> T) rethrows -> T {
            dispatchPrecondition(condition: .notOnQueue(storageLock))
            return try storageLock.sync { try work(&storage) }
        }

        private func withStorageValue<Value, T>(_ keyPath: WritableKeyPath<Storage, Value>, do work: (inout Value) throws -> T) rethrows -> T {
            try withStorage { try work(&$0[keyPath: keyPath]) }
        }

        private func getStorageValue<Value>(for keyPath: KeyPath<Storage, Value>) -> Value {
            withStorage { $0[keyPath: keyPath] }
        }

        func addHandler(_ handler: EventConsumer) {
            withStorageValue(\.handler) { _ = $0.insert(handler) }
        }

        func removeHandler(_ handler: EventConsumer) {
            withStorageValue(\.handler) { _ = $0.remove(handler) }
        }

		func open() throws {
            try withStorageValue(\.state) {
                guard case .closed = $0 else { return }
                $0 = try .open(_open())
            }
		}

        private func _open() throws -> FileDescriptor {
            let descriptor = try FileDescriptor.open(device.eventFile, .readOnly)
            if device.grabsDevice {
                do {
                    try descriptor.takeGrab()
                } catch {
                    do {
                        try descriptor.close()
                    } catch {
                        print("Grabbing the device at \(device.eventFile) threw an error and trying to close the file descriptor failed: \(error)")
                    }
                    throw error
                }
            }
            return descriptor
        }

        func beginStreaming() throws {
            try withStorageValue(\.state) {
                switch $0 {
                case .closed:
                    let fileDesc = try _open()
                    $0 = try .streaming(fileDesc, _beginStreaming(from: fileDesc))
                case .open(let fileDesc):
                    $0 = try .streaming(fileDesc, _beginStreaming(from: fileDesc))
                case .streaming(_, _): return
                }
            }
        }

        private func _beginStreaming(from fileDesc: FileDescriptor) throws -> FileSource {
            let workerQueue = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamer.worker")
            let source = DispatchSource.makeReadSource(fileDescriptor: fileDesc.rawValue, queue: workerQueue)
            // This is not available on linux...
//                .makeFileSystemObjectSource(fileDescriptor: fileDesc.rawValue, eventMask: [.write, .extend], queue: workerQueue)
            source.setEventHandler(handler: { [unowned self] in
                do {
                    let buffer = UnsafeMutableBufferPointer<input_event>.allocate(capacity: 1)
                    defer { buffer.deallocate() }
                    let bytesRead = try fileDesc.read(into: UnsafeMutableRawBufferPointer(buffer))
                    if bytesRead.isMultiple(of: MemoryLayout<input_event>.size) {
                        buffer.lazy.compactMap { InputEvent(cInputEvent: $0) }.forEach { event in
                            self.getStorageValue(for: \.handler).forEach { $0.notify(about: event, from: self.device) }
                        }
                    } else {
                        do {
                            try fileDesc.seek(offset: Int64(-bytesRead), from: .current)
                        } catch {
                            print("File handle did not contain enough data, but seeking back failed: \(error)")
                        }
                    }
                } catch {
                    print("Failed to read from event file: \(error)")
                }
            })
            source.activate()
            return source
		}

		func endStreaming() throws {
            try withStorageValue(\.state) {
                guard case .streaming(let fileDesc, let source) = $0 else { return }
                try _endStreaming(of: source)
                $0 = .open(fileDesc)
            }
		}

        private func _endStreaming(of source: FileSource) throws {
            source.cancel()
        }

		func close() throws {
            try withStorageValue(\.state) {
                switch $0 {
                case .closed: return
                case .streaming(let fileDesc, let source):
                    try _endStreaming(of: source)
                    fallthrough
                case .open(let fileDesc): try _close(fileDesc)
                }
                $0 = .closed
            }
		}

        private func _close(_ fileDesc: FileDescriptor) throws {
            try fileDesc.closeAfter {
                if device.grabsDevice {
                    try fileDesc.releaseGrab()
                }
            }
        }
	}
}
