import Dispatch
import struct Foundation.UUID
import SystemPackage
import FileStreamer
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
        try InputDevice.getStream(for: self, adding: eventConsumer).beginStreaming()
	}

    /// Stops the input device from receivng any events. All registered event consumers will be automatically deregistered by this call.
    /// - Throws: Errors that occur while closing the file handle.
	public func stopReceivingEvents() throws {
        try InputDevice.removeStream(for: self)?.close()
	}

    /// Adds an event consumer to the device.
    /// - Parameter eventConsumer: The consumer to add.
    /// - Note: This methods does internal preprarations for receiving events if necessary.
    ///         Thus only call this if you called or will call `startReceivingEvents` on this input device.
	public func addEventConsumer(_ eventConsumer: EventConsumer) {
        InputDevice.addConsumer(eventConsumer, for: self)
	}

    /// Removes the given event consumer from the input device.
    /// - Parameter eventConsumer: The consumer to remove.
    /// - Note: If this is the last registered event consumer, the input device will stop streaming events
    ///         and needs to be re-started with `startReceivingEvents`.
	public func removeEventConsumer(_ eventConsumer: EventConsumer) {
        InputDevice.removeConsumer(eventConsumer, for: self)
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
    typealias OpenStream = (stream: FileStream<input_event>, consumers: Set<EventConsumer>)
    private static let fileStreamersLock = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamers.lock")
    private static var fileStreamers: [FilePath: OpenStream] = [:]

    private static func makeStream(for device: InputDevice) -> FileStream<input_event> {
        let newStream = FileStream<input_event>(filePath: device.eventFile)
        if device.grabsDevice {
            newStream.addOpenCallback { try $1.takeGrab() }
            newStream.addCloseCallback { try $1.releaseGrab() }
        }
        newStream.addCallback { stream, values in
            let events = values.compactMap(InputEvent.init)
            registeredConsumers(for: device)
                .forEach { $0.notify(about: events, from: device) }
        }
        return newStream
    }

    private static func registeredConsumers(for device: InputDevice) -> Set<EventConsumer> {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return fileStreamersLock.sync {
            fileStreamers[device.eventFile]?.consumers
        } ?? []
    }

    private static func withRegisteredConsumers<T>(for device: InputDevice, do work: (FileStream<input_event>, inout Set<EventConsumer>) throws -> T) rethrows -> T {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return try fileStreamersLock.sync {
            var value = fileStreamers[device.eventFile] ?? (makeStream(for: device), [])
            defer { fileStreamers[device.eventFile] = value }
            return try work(value.stream, &value.consumers)
        }
    }

    fileprivate static func getStream(for device: InputDevice, adding consumer: EventConsumer) -> FileStream<input_event> {
        withRegisteredConsumers(for: device) {
            $1.insert(consumer)
            return $0
        }
    }

    fileprivate static func addConsumer(_ consumer: EventConsumer, for device: InputDevice) {
        withRegisteredConsumers(for: device) { _ = $1.insert(consumer) }
    }

    fileprivate static func removeConsumer(_ consumer: EventConsumer, for device: InputDevice) {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return fileStreamersLock.sync {
            guard var value = fileStreamers[device.eventFile] else { return }
            value.consumers.remove(consumer)
            fileStreamers[device.eventFile] = value.consumers.isEmpty ? nil : value
        }
    }

    fileprivate static func removeStream(for device: InputDevice) -> FileStream<input_event>? {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return fileStreamersLock.sync { fileStreamers.removeValue(forKey: device.eventFile)?.stream }
    }
}
