import Dispatch
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
    ///   - grabDevice: Whether to grab the device. Default is `true`.
    public init(eventFile: FilePath, grabDevice: Bool = true) {
		self.eventFile = eventFile
        self.grabsDevice = grabDevice
	}

    /// Registers an event consumer and starts receiving events from the input device.
    /// - Parameter eventConsumer: The consumer to register.
    /// - Throws: Errors that occur while starting to stream.
    /// - Note: The `eventConsumer` will always be registered, even if the device is already streaming.
    @inlinable
	public func startStreaming(informing eventConsumer: EventConsumer) throws -> ActiveStream {
        let active = try InputDevice._getStream(for: self)
        active.addEventConsumer(eventConsumer)
        return active
	}

    /// Returns the currently active stream for this device if there is one.
    @inlinable
    public func currentActiveStream() -> ActiveStream? {
        InputDevice._getExistingStream(for: self)
    }

#if compiler(>=5.5) && canImport(_Concurrency) && !os(Linux)
    /// Creates an active stream sequence that asynchronously sends events.
    /// - Parameter eventConsumer: The consumer to register.
    /// - Throws: Errors that occur while starting to stream.
    /// - Note: The `eventConsumer` will always be registered, even if the device is already streaming.
    @inlinable
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public var events: ActiveStreamSequence {
        get throws {
            try InputDevice._getStreamSequence(for: self)
        }
    }
#endif

    /// inherited
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.eventFile == rhs.eventFile
    }
}

extension InputDevice {
    /// An object that calls a given closure for an input device event.
    public struct EventConsumer {
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

        fileprivate func notify(about events: [InputEvent], from device: InputDevice) {
            queue.async { closure(device, events) }
        }
    }
}

extension InputDevice {
    /// An active stream for an `InputDevice`.
    public struct ActiveStream: Equatable {
        @usableFromInline
        final class _Callbacks {
            private let lock = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.activestream.callbacks.lock")
            private var _callbacks = Array<EventConsumer>()

            var current: Array<EventConsumer> {
                dispatchPrecondition(condition: .notOnQueue(lock))
                return lock.sync { _callbacks }
            }

            @usableFromInline
            func add(_ consumer: EventConsumer) {
                dispatchPrecondition(condition: .notOnQueue(lock))
                lock.sync { _callbacks.append(consumer) }
            }
        }

        /// The device that is streaming.
        public let device: InputDevice
        /// The open file stream.
        let stream: FileStream<input_event>
        /// The callbacks.
        @usableFromInline
        let callbacks = _Callbacks()

        fileprivate init(device: InputDevice) throws {
            self.device = device
            self.stream = try FileStream(fileDescriptor: .open(device.eventFile, .readOnly)) { [callbacks] in
                let events = $0.compactMap(InputEvent.init)
                callbacks.current.forEach { $0.notify(about: events, from: device) }
            }
            if device.grabsDevice {
                do {
                    try stream.fileDescriptor.takeGrab()
                } catch {
                    do {
                        try stream.fileDescriptor.close()
                    } catch {
                        print("Grabbing the device at \(device.eventFile) threw an error and trying to close the file descriptor failed: \(error)")
                    }
                    throw error
                }
            }
            stream.beginStreaming()
        }

        /// Adds an event consumer to the device.
        /// - Parameter eventConsumer: The consumer to add.
        @inlinable
        public func addEventConsumer(_ eventConsumer: EventConsumer) {
            callbacks.add(eventConsumer)
        }

        /// Stops the input device from receivng any events. All registered event consumers will be automatically deregistered by this call.
        /// - Throws: Errors that occur while closing the file handle.
        public func stopStreaming() throws {
            guard let stream = InputDevice._removeStream(for: device)?.stream else { return }
            assert(stream.fileDescriptor == self.stream.fileDescriptor)
            try stream.fileDescriptor.closeAfter {
                stream.endStreaming()
                if device.grabsDevice {
                    try stream.fileDescriptor.releaseGrab()
                }
            }
        }

        /// inherited
        public static func ==(lhs: Self, rhs: Self) -> Bool {
            lhs.device == rhs.device && lhs.stream.fileDescriptor == rhs.stream.fileDescriptor
        }
    }
}

extension InputDevice {
    private static let fileStreamersLock = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamers.lock")
    private static var fileStreamers: [FilePath: ActiveStream] = [:]

    @usableFromInline
    static func _getExistingStream(for device: InputDevice) -> ActiveStream? {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return fileStreamersLock.sync { fileStreamers[device.eventFile] }
    }

    @usableFromInline
    static func _getStream(for device: InputDevice) throws -> ActiveStream {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return try fileStreamersLock.sync {
            if let existing = fileStreamers[device.eventFile] { return existing }
            let new = try ActiveStream(device: device)
            fileStreamers[device.eventFile] = new
            return new
        }
    }

    @usableFromInline
    static func _removeStream(for device: InputDevice) -> ActiveStream? {
        dispatchPrecondition(condition: .notOnQueue(fileStreamersLock))
        return fileStreamersLock.sync { fileStreamers.removeValue(forKey: device.eventFile) }
    }
}

#if compiler(>=5.5) && canImport(_Concurrency) && !os(Linux)
extension InputDevice {
    /// An active stream sequence that asynchrounously sends events.
    @available(iOS 15, tvOS 15, watchOS 8, macOS 12, *)
    public struct ActiveStreamSequence: Equatable, AsyncSequence {
        /// inherited
        public typealias Element = InputEvent
        /// inherited
        public typealias AsyncIterator = Iterator

        /// The asynchronous iterator.
        @frozen
        public struct Iterator: AsyncIteratorProtocol {
            @usableFromInline
            typealias _UnderlyingIterator = AsyncCompactMapSequence<FileStream<input_event>.Sequence, InputEvent>.AsyncIterator

            @usableFromInline
            let _fileDescriptor: FileDescriptor

            @usableFromInline
            var _iterator: _UnderlyingIterator

            @usableFromInline
            init(_fileDescriptor: FileDescriptor, _iterator: _UnderlyingIterator) {
                self._fileDescriptor = _fileDescriptor
                self._iterator = _iterator
            }

            /// inherited
            @inlinable
            public mutating func next() async throws -> Element? {
                guard !Task.isCancelled else {
                    try _fileDescriptor.close()
                    return nil
                }
                return await _iterator.next()
            }
        }

        /// The device that is streaming.
        public let device: InputDevice
        /// The file descriptor.
        let fileDescriptor: FileDescriptor
        /// The open file stream sequence.
        let stream: FileStream<input_event>.Sequence

        fileprivate init(device: InputDevice) throws {
            self.device = device
            self.fileDescriptor = try .open(device.eventFile, .readOnly)
            self.stream = .init(fileDescriptor: fileDescriptor)
            if device.grabsDevice {
                do {
                    try fileDescriptor.takeGrab()
                } catch {
                    do {
                        try fileDescriptor.close()
                    } catch {
                        print("Grabbing the device at \(device.eventFile) threw an error and trying to close the file descriptor failed: \(error)")
                    }
                    throw error
                }
            }
        }

        /// inherited
        public func makeAsyncIterator() -> AsyncIterator {
            .init(_fileDescriptor: fileDescriptor, _iterator: stream.compactMap(Element.init).makeAsyncIterator())
        }

        /// inherited
        public static func ==(lhs: Self, rhs: Self) -> Bool {
            lhs.device == rhs.device && lhs.fileDescriptor == rhs.fileDescriptor
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension InputDevice {
    private static let fileStreamerSequencesLock = DispatchQueue(label: "de.sersoft.deviceinput.inputdevice.streamer-sequences.lock")
    private static var fileStreamerSequences: [FilePath: ActiveStreamSequence] = [:]

    @usableFromInline
    static func _getExistingStreamSequence(for device: InputDevice) -> ActiveStreamSequence? {
        dispatchPrecondition(condition: .notOnQueue(fileStreamerSequencesLock))
        return fileStreamerSequencesLock.sync { fileStreamerSequences[device.eventFile] }
    }

    @usableFromInline
    static func _getStreamSequence(for device: InputDevice) throws -> ActiveStreamSequence {
        dispatchPrecondition(condition: .notOnQueue(fileStreamerSequencesLock))
        return try fileStreamerSequencesLock.sync {
            if let existing = fileStreamerSequences[device.eventFile] { return existing }
            let new = try ActiveStreamSequence(device: device)
            fileStreamerSequences[device.eventFile] = new
            return new
        }
    }

    @usableFromInline
    static func _removeStreamSequence(for device: InputDevice) -> ActiveStreamSequence? {
        dispatchPrecondition(condition: .notOnQueue(fileStreamerSequencesLock))
        return fileStreamerSequencesLock.sync { fileStreamerSequences.removeValue(forKey: device.eventFile) }
    }
}
#endif
