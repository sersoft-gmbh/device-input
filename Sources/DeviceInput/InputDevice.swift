import Dispatch
import struct Foundation.UUID
import SystemPackage
import Cinput

/// Represents an input device at a given file path.
public struct InputDevice: Equatable {
    /// The file path to the input device.
    public let eventFile: FilePath
    /// Whether or not the device should be 'grabbed'.
    /// If true, an `ioctl` is done with `EVIOCGRAB` on the file handle.
    public let grabsDevice: Bool

    /// Creates a new input device with the given parameters.
    /// - Parameters:
    ///   - eventFile: The path to the input device's event file.
    ///   - grabDevice: Whether or not to grab the device. Default is `true`.
    public init(eventFile: FilePath, grabDevice: Bool = true) {
		self.eventFile = eventFile
        self.grabsDevice = grabDevice
	}

    /// Registers an event consumer and starts receiving events from the input device.
    /// - Parameter eventConsumer: The consumer to register.
    /// - Throws: Errors that occur while starting to stream.
	public func startReceivingEvents(informing eventConsumer: EventConsumer) throws {
        let streamer = InputDevice.makeStreamer(for: self)
        streamer.addHandler(eventConsumer)
        try streamer.beginStreaming()
	}

    /// Stops the input device from receivng any events. All registered event consumers will be automatically deregistered by this call.
    /// - Throws: Errors that occur while closing the file handle.
	public func stopReceivingEvents() throws {
        guard let streamer = InputDevice.removeStreamer(for: self) else { return }
        try streamer.close()
	}

    /// Adds an event consumer to the device.
    /// - Parameter eventConsumer: The consumer to add.
    /// - Note: This methods does internal preprarations for receiving events if necessary.
    ///         Thus only call this if you called or will call `startReceivingEvents` on this input device.
	public func addEventConsumer(_ eventConsumer: EventConsumer) {
        InputDevice.makeStreamer(for: self).addHandler(eventConsumer)
	}

    /// Removes the given event consumer from the input device.
    /// - Parameter eventConsumer: The consumer to remove.
    /// - Note: If this is the last registered event consumer, the input device will stop streaming events
    ///         and needs to be re-started with `startReceivingEvents`.
	public func removeEventConsumer(_ eventConsumer: EventConsumer) {
        InputDevice.removeStreamer(for: self) { $0.removeHandler(eventConsumer) }
	}

    /// inherited
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.eventFile == rhs.eventFile
    }
}

extension InputDevice {
    /// An object that calls a given closure for an input device event.
    public struct EventConsumer: Hashable {
        private let uuid = UUID()
        private let queue: DispatchQueue
        private let closure: (InputDevice, [InputEvent]) -> Void

        /// Creates a new consumer with the given parameters.
        /// - Parameters:
        ///   - queue: The queue on which to call `handler`.
        ///   - handler: The closure to call for each event of an input device.
        public init(queue: DispatchQueue, handler: @escaping (InputDevice, [InputEvent]) -> Void) {
            self.queue = queue
            self.closure = handler
        }

        /// inherited
        public func hash(into hasher: inout Hasher) {
            hasher.combine(uuid)
        }

        /// inherited
        public static func ==(lhs: Self, rhs: Self) -> Bool {
            lhs.uuid == rhs.uuid
        }

        fileprivate func notify(about events: [InputEvent], from device: InputDevice) {
            queue.async { closure(device, events) }
        }
    }
}

extension InputDevice {
    private static let fileStreamersLock = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamers.lock")
    private static var fileStreamers: [FilePath: Streamer] = [:]

//    fileprivate static func streamer(for device: InputDevice) -> Streamer? {
//        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
//        return fileStreamersLock.sync { fileStreamers[device.eventFile] }
//    }

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

    fileprivate static func removeStreamer(for device: InputDevice, if condition: (Streamer) throws -> Bool) rethrows {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return try fileStreamersLock.sync {
            guard let value = fileStreamers[device.eventFile], try condition(value) else { return }
            fileStreamers.removeValue(forKey: device.eventFile)
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

        func removeHandler(_ handler: EventConsumer) -> Bool {
            withStorageValue(\.handler) {
                $0.remove(handler)
                return $0.isEmpty
            }
        }

//		func open() throws {
//            try withStorageValue(\.state) {
//                guard case .closed = $0 else { return }
//                $0 = try .open(_open())
//            }
//		}

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
            var remainingData = 0
            let eventSize = MemoryLayout<input_event>.size
            source.setEventHandler { [unowned self] in
                do {
                    remainingData += Int(source.data)
                    guard case let capacity = remainingData / eventSize, capacity > 0 else { return }
                    let buffer = UnsafeMutableBufferPointer<input_event>.allocate(capacity: capacity)
                    defer { buffer.deallocate() }
                    let bytesRead = try fileDesc.read(into: UnsafeMutableRawBufferPointer(buffer))
                    if case let noOfEvents = bytesRead / eventSize, noOfEvents > 0 {
                        let events: Array<InputEvent> = buffer.lazy
                            .prefix(noOfEvents)
                            .compactMap { InputEvent(cInputEvent: $0) }
                        self.getStorageValue(for: \.handler)
                            .forEach { $0.notify(about: events, from: self.device) }
                    }
                    let leftOverBytes = bytesRead % eventSize
                    remainingData -= bytesRead - leftOverBytes
                    if leftOverBytes > 0 {
                        do {
                            try fileDesc.seek(offset: Int64(-leftOverBytes), from: .current)
                        } catch {
                            // If we failed to seek, we need to drop the left-over bytes.
                            remainingData -= leftOverBytes
                            print("Too much data was read from the file handle, but seeking back failed: \(error)")
                        }
                    }
                } catch {
                    print("Failed to read from event file: \(error)")
                }
            }
            source.activate()
            return source
		}

//		func endStreaming() throws {
//            try withStorageValue(\.state) {
//                guard case .streaming(let fileDesc, let source) = $0 else { return }
//                try _endStreaming(of: source)
//                $0 = .open(fileDesc)
//            }
//		}

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
