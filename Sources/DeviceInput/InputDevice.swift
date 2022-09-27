import Dispatch
import SystemPackage
import FileStreamer
import CInput

/// Represents an input device at a given file path.
public struct InputDevice: Equatable {
    /// The file path to the input device.
    public let eventFile: FilePath
    /// Whether or not the device should be 'grabbed'.
    /// If true, an `ioctl` is done with `EVIOCGRAB` on the file handle.
    public let grabsDevice: Bool

#if compiler(>=5.5.2) && canImport(_Concurrency)
    /// Creates an active stream sequence that asynchronously sends events.
    /// - Parameter eventConsumer: The consumer to register.
    /// - Throws: Errors that occur while starting to stream.
    /// - Note: The `eventConsumer` will always be registered, even if the device is already streaming.
    @inlinable
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public var events: ActiveStreamSequence {
        assert(!grabsDevice || currentActiveStream() == nil,
               "Cannot use async events sequence and callback based streaming in parallel when the device is being grabbed!")
        return .init(_device: self)
    }
#endif

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

    /// inherited
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.eventFile == rhs.eventFile
    }
}

extension InputDevice {
    /// An object that calls a given closure for an input device event.
    public struct EventConsumer {
        private let queue: DispatchQueue
        private let closure: (InputDevice, Array<InputEvent>) -> Void

        /// Creates a new consumer with the given parameters.
        /// - Parameters:
        ///   - queue: The queue on which to call `handler`.
        ///   - handler: The closure to call for each event of an input device.
        public init(queue: DispatchQueue, handler: @escaping (InputDevice, Array<InputEvent>) -> Void) {
            self.queue = queue
            self.closure = handler
        }

        fileprivate func notify(about events: Array<InputEvent>, from device: InputDevice) {
            queue.async { closure(device, events) }
        }
    }
}

extension InputDevice {
    /// An active stream for an ``InputDevice``.
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

        /// Stops the input device from receiving any events. All registered event consumers will be automatically deregistered by this call.
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
    private static var fileStreamers = Dictionary<FilePath, ActiveStream>()

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

#if compiler(>=5.5.2) && canImport(_Concurrency)
extension InputDevice.ActiveStream._Callbacks: @unchecked Sendable {} // unchecked because of manual locking
extension InputDevice.ActiveStream: @unchecked Sendable {} // unchecked because of FileStream which we use in a Sendable-safe way
extension InputDevice: @unchecked Sendable {} // unchecked because of FilePath
#endif

#if compiler(>=5.5.2) && canImport(_Concurrency)
extension InputDevice {
    /// An active stream sequence that asynchronously sends events.
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public struct ActiveStreamSequence: Equatable, AsyncSequence {
        /// inherited
        public typealias Element = InputEvent
        /// inherited
        public typealias AsyncIterator = Iterator

        /// The asynchronous iterator.
        @frozen
        public struct Iterator: AsyncIteratorProtocol {
            @usableFromInline
            var _device: InputDevice?

            @usableFromInline
            var _iterator: AsyncCompactMapSequence<FileStream<input_event>.Sequence, InputEvent>.AsyncIterator?

            @usableFromInline
            init(_device: InputDevice) {
                self._device = _device
            }

            @usableFromInline
            mutating func _setup() async throws {
                assert(!Task.isCancelled)
                assert(_device != nil)
                assert(_iterator == nil)
                guard let device = _device else { return }
                _iterator = try await Self.streamsStorage
                    ._getStreamSequence(for: device)
                    .compactMap { Element(cInputEvent: $0) }
                    .makeAsyncIterator()
            }

            @usableFromInline
            mutating func _finalize() async throws {
                guard let device = _device else { return }
                (_device, _iterator) = (nil, nil)
                try await Self.streamsStorage._removeStreamSequence(for: device)
            }

            /// inherited
            @inlinable
            public mutating func next() async throws -> Element? {
                guard !Task.isCancelled && _device != nil else {
                    try await _finalize()
                    return nil
                }
                if _iterator == nil { try await _setup() }
                let next = await _iterator?.next()
                if next == nil {
                    try await _finalize()
                }
                return next
            }
        }

        /// The device that is streaming.
        public let device: InputDevice

        @usableFromInline
        init(_device: InputDevice) {
            device = _device
        }

        /// inherited
        @inlinable
        public func makeAsyncIterator() -> AsyncIterator {
            .init(_device: device)
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension InputDevice.ActiveStreamSequence.AsyncIterator {
    fileprivate final actor StreamsStorage {
        private typealias StreamInformation = (stream: FileStream<input_event>.Sequence, fileDescriptor: FileDescriptor, refCount: Int)

        private var streamValues = Dictionary<FilePath, StreamInformation>()

        func _getStreamSequence(for device: InputDevice) throws -> FileStream<input_event>.Sequence {
            if var existing = streamValues[device.eventFile] {
                existing.refCount += 1
                streamValues[device.eventFile] = existing
                return existing.stream
            }
            let fileDesc = try FileDescriptor.open(device.eventFile, .readOnly)
            if device.grabsDevice {
                do {
                    try fileDesc.takeGrab()
                } catch {
                    do {
                        try fileDesc.close()
                    } catch {
                        print("Grabbing the device at \(device.eventFile) threw an error and trying to close the file descriptor failed: \(error)")
                    }
                    throw error
                }
            }
            let newStream = FileStream<input_event>.Sequence(fileDescriptor: fileDesc)
            streamValues[device.eventFile] = (newStream, fileDesc, 1)
            return newStream
        }

        func _removeStreamSequence(for device: InputDevice) throws {
            guard var existing = streamValues[device.eventFile] else { return }
            guard existing.refCount <= 1 else {
                existing.refCount -= 1
                streamValues[device.eventFile] = existing
                return
            }
            streamValues.removeValue(forKey: device.eventFile)
            if device.grabsDevice {
                try existing.fileDescriptor.closeAfter {
                    try existing.fileDescriptor.releaseGrab()
                }
            } else {
                try existing.fileDescriptor.close()
            }
        }
    }

    fileprivate static let streamsStorage = StreamsStorage()
}
#endif
