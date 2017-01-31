import Foundation

public struct InputDevice: Equatable {
	public let eventFile: URL
	private let streamer: Streamer

	public init?(eventFile: URL) {
		guard FileManager.default.fileExists(atPath: eventFile.path) else { return nil }
		guard let streamer = Streamer(file: eventFile) else { return nil }
		self.eventFile = eventFile
		self.streamer = streamer
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

public extension InputDevice {
	public struct EventConsumer: Hashable {
		private let uuid = UUID()
		public let queue: DispatchQueue
		public let handler: (InputDevice, InputEvent) -> Void

		public var hashValue: Int { return uuid.hashValue }

		fileprivate func notify(about event: InputEvent, from device: InputDevice) {
			queue.async { self.handler(device, event) }
		}

		public static func ==(lhs: InputDevice.EventConsumer, rhs: InputDevice.EventConsumer) -> Bool {
			return lhs.uuid == rhs.uuid
		}
	}
}

fileprivate extension InputDevice {
	fileprivate class Streamer {
		private let workerQueue = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamer.worker")
		let stream: InputStream
		var device: InputDevice! = nil

		private var isOpen = false
		private var isStreaming = false
		private var wantsStop = false

		var handler: Set<InputDevice.EventConsumer> = []

		init?(file: URL) {
			guard let stream = InputStream(url: file) else { return nil }
			self.stream = stream
		}

		deinit { close() }

		func open() {
			guard !isOpen else { return }
			stream.open()
			isOpen = true
		}

		func beginStreaming() {
			open()
			workerQueue.async { [weak self] in
				guard let `self` = self else { return }
				let chunkSize = MemoryLayout<CInputEvent>.size
				while !self.wantsStop {
					var buffer = [UInt8](repeating: 0, count: chunkSize)
					_ = self.stream.read(&buffer, maxLength: chunkSize)
					let eventPtr = UnsafePointer<CInputEvent>(OpaquePointer(buffer))
					if let event = InputEvent(cInputEvent: eventPtr.pointee) {
						self.handler.forEach { $0.notify(about: event, from: self.device) }
					}
				}
				self.wantsStop = false
			}
		}

		func endStreaming() {
			wantsStop = true
		}

		func close() {
			guard isOpen else { return }
			stream.close()
			isOpen = false
		}
	}
}
