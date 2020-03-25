import struct Foundation.URL
import struct Foundation.UUID
import class Foundation.FileHandle
import class Dispatch.DispatchQueue

#if os(Linux)
import Glibc
import Clibgrabdevice
#endif

public struct InputDevice: Equatable {
	public let eventFile: URL
	private let streamer: Streamer

	public init(eventFile: URL, grabDevice: Bool = true) throws {
		self.eventFile = eventFile
		self.streamer = try Streamer(file: eventFile, grabDevice: grabDevice)
		self.streamer.device = self
	}

	public static func ==(lhs: InputDevice, rhs: InputDevice) -> Bool {
		return lhs.eventFile == rhs.eventFile
	}

	public func startReceivingEvents() {
		streamer.beginStreaming()
	}

	public func stopReceivingEvents() {
		streamer.endStreaming()
	}

	public func add(eventConsumer: EventConsumer) {
		streamer.handler.insert(eventConsumer)
	}

	public func remove(eventConsumer: EventConsumer) {
		streamer.handler.remove(eventConsumer)
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

		public static func ==(lhs: InputDevice.EventConsumer, rhs: InputDevice.EventConsumer) -> Bool {
			return lhs.uuid == rhs.uuid
		}

        fileprivate func notify(about event: InputEvent, from device: InputDevice) {
            queue.async { self.handler(device, event) }
        }
	}
}

fileprivate extension InputDevice {
	final class Streamer {
		private let workerQueue = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamer.worker")

		let fileHandle: FileHandle
		let grabDevice: Bool

		var device: InputDevice! = nil
		var handler: Set<InputDevice.EventConsumer> = []

		private var isOpen = false
		private var isStreaming = false
		private var wantsStop = false

		init(file: URL, grabDevice: Bool) throws {
			self.fileHandle = try FileHandle(forReadingFrom: file.resolvingSymlinksInPath())
			self.grabDevice = grabDevice
		}

		deinit { close() }

		func open() {
			guard !isOpen else { return }
			#if os(Linux)
				if grabDevice && grab_device(fileHandle.fileDescriptor) != 0 {
					print("Failed to grab exclusive rights on file ptr (\(errno))!")
				}
			#endif
			isOpen = true
		}

		func beginStreaming() {
			if wantsStop {
				// Wait for the current stream to stop.
				workerQueue.sync { wantsStop = false }
			}
            guard !isStreaming else { return }
			open()
			workerQueue.async {
                defer { self.isStreaming = false }
				let chunkSize = MemoryLayout<CInputEvent>.size
				while !self.wantsStop {
					let data = self.fileHandle.readData(ofLength: chunkSize)
                    if data.count.isMultiple(of: chunkSize) {
                        data.withUnsafeBytes { $0.bindMemory(to: CInputEvent.self).compactMap { InputEvent(cInputEvent: $0) } }
                            .forEach { event in
                                self.handler.forEach { $0.notify(about: event, from: self.device) }
                        }
                    }
				}
			}
			isStreaming = true
		}

		func endStreaming() {
			guard isStreaming else { return }
			wantsStop = true
		}

		func close() {
			guard isOpen else { return }
			#if os(Linux)
				if grabDevice && release_device(fileHandle.fileDescriptor) != 0 {
					print("Failed to release exclusive rights on file ptr (\(errno))!")
				}
			#endif
			fileHandle.closeFile()
			isOpen = false
		}
	}
}
