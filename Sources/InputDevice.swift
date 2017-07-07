import struct Foundation.URL
import struct Foundation.UUID
import class Foundation.FileHandle
import class Dispatch.DispatchQueue

#if os(Linux)
import Clibgrabdevice
#endif

public struct InputDevice: Equatable {
	public let eventFile: URL
	private let streamer: Streamer

	public init(eventFile: URL, grabDevice: Bool = true) throws {
		let resolvedFile = eventFile.resolvingSymlinksInPath()
		// guard FileManager.default.fileExists(atPath: resolvedFile.path) else { return nil }
		// guard let streamer = Streamer(file: resolvedFile) else { return nil }
		self.eventFile = eventFile
		self.streamer = try Streamer(file: resolvedFile, grabDevice: grabDevice)
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

		public init(queue: DispatchQueue, handler: @escaping (InputDevice, InputEvent) -> Void) {
			self.queue = queue
			self.handler = handler
		}
	}
}

fileprivate extension InputDevice {
	fileprivate final class Streamer {
		private let workerQueue = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamer.worker")

		let fileHandle: FileHandle
		let grabDevice: Bool

		var device: InputDevice! = nil
		var handler: Set<InputDevice.EventConsumer> = []

		private var isOpen = false
		private var isStreaming = false
		private var wantsStop = false

		init(file: URL, grabDevice: Bool) throws {
			self.fileHandle = try FileHandle(forReadingFrom: file)
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
			guard !isStreaming else { return }
			if wantsStop {
				// Wait for the current stream to stop.
				workerQueue.sync { wantsStop = false }
			}
			open()
			// This will crash on linux on event files...
			// fileHandle.seekToEndOfFile()
			workerQueue.async { [weak self] in
				guard let `self` = self else { return }
				let chunkSize = MemoryLayout<CInputEvent>.size
				while !self.wantsStop {
					let data = self.fileHandle.readData(ofLength: chunkSize)
                    if data.count == chunkSize,
                        let event = data.withUnsafeBytes({ InputEvent(cInputEvent: $0.pointee) }) {
                        self.handler.forEach { $0.notify(about: event, from: self.device) }
                    }
				}
			}
			// fileHandle.readabilityHandler = { [weak self] handle in
			// 	self?.handleReading(for: handle)
			// }
			// fileHandle.waitForDataInBackgroundAndNotify()
			// notificationObserver = NotificationCenter.default.addObserver(forName: .NSFileHandleDataAvailable, object: fileHandle, queue: nil) { [weak self] _ in
			// 	guard let `self` = self else { return }
			// 	self.handleReading(for: self.fileHandle)
			// }
			isStreaming = true
		}

		func endStreaming() {
			guard isStreaming else { return }
			wantsStop = true
			// fileHandle.readabilityHandler = nil
			// NotificationCenter.default.removeObserver(notificationObserver)
			isStreaming = false
		}

		// private func handleReading(for handle: FileHandle) {
		// 	guard !wantsStop else { return }
		// 	guard handle === fileHandle else { return }
		// 	let chunkSize = MemoryLayout<CInputEvent>.size
		// 	let data = handle.readData(ofLength: chunkSize)
		// 	if data.count == chunkSize {
		// 		if let event = data.withUnsafeBytes({ (ptr: UnsafePointer<CInputEvent>) in InputEvent(cInputEvent: ptr.pointee) }) {
		// 			handler.forEach { $0.notify(about: event, from: self.device) }
		// 		}
		// 	}
		// }

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
