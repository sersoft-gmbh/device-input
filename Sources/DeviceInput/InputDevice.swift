public import SystemPackage
public import FileStreamer
public import CInput

/// Represents an input device at a given file path.
public struct InputDevice: Equatable, Sendable {
    /// The file path to the input device.
    public let eventFile: FilePath
    /// Whether or not the device should be 'grabbed'.
    /// If true, an `ioctl` is done with `EVIOCGRAB` on the file handle.
    public let grabsDevice: Bool

    /// The async events sequence.
    @inlinable
    public var events: Events {
        .init(_device: self)
    }
    /// Creates a new input device with the given parameters.
    /// - Parameters:
    ///   - eventFile: The path to the input device's event file.
    ///   - grabDevice: Whether to grab the device. Default is `true`.
    public init(eventFile: FilePath, grabDevice: Bool = true) {
        self.eventFile = eventFile
        self.grabsDevice = grabDevice
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.eventFile == rhs.eventFile
    }
}

extension InputDevice {
    /// An active stream sequence that asynchronously sends events.
    public struct Events: Sendable, Equatable, AsyncSequence {
        public typealias Element = InputEvent

        /// The asynchronous iterator.
        @frozen
        public struct AsyncIterator: AsyncIteratorProtocol {
            public typealias Failure = any Error

            @usableFromInline
            final class _Storage {
                @usableFromInline
                var _device: InputDevice?

                @usableFromInline
                init(_device: InputDevice) {
                    self._device = _device
                }

                deinit {
                    guard let _device else { return }
                    Task {
                        try await AsyncIterator.streamsStorage._removeStreamSequence(for: _device)
                    }
                }
            }

            @usableFromInline
            let _storage: _Storage

            @usableFromInline
            var _iterator: AsyncCompactMapSequence<FileStream<input_event, Failure>, Element>.AsyncIterator?

            @usableFromInline
            init(_device: InputDevice) {
                _storage = .init(_device: _device)
            }

            @usableFromInline
            mutating func _setup(isolation actor: isolated (any Actor)?) async throws {
                assert(!Task.isCancelled)
                assert(_storage._device != nil)
                assert(_iterator == nil)
                guard let device = _storage._device else { return }
                _iterator = try await Self.streamsStorage
                    ._getStreamSequence(for: device)
                    .compactMap { Element(cInputEvent: $0) }
                    .makeAsyncIterator()
            }

            @usableFromInline
            mutating func _finalize(isolation actor: isolated (any Actor)?) async throws {
                guard let device = _storage._device else { return }
                (_storage._device, _iterator) = (nil, nil)
                try await Self.streamsStorage._removeStreamSequence(for: device)
            }

            @inlinable
            public mutating func _next(isolation actor: isolated (any Actor)?) async throws(Failure) -> Element? {
                guard !Task.isCancelled && _storage._device != nil else {
                    try await _finalize(isolation: actor)
                    return nil
                }
                if _iterator == nil { try await _setup(isolation: actor) }
                let next = try await _iterator?.next(isolation: actor)
                if next == nil {
                    try await _finalize(isolation: actor)
                }
                return next
            }

#if compiler(>=6.1)
            @inlinable
            public mutating func next(isolation actor: isolated (any Actor)?) async throws(Failure) -> Element? {
                try await _next(isolation: actor)
            }
#else
            @inlinable
            public mutating func next() async throws -> Element? {
                try await _next(isolation: #isolation)
            }
#endif
        }

        /// The device that is streaming.
        public let device: InputDevice

        @usableFromInline
        init(_device: InputDevice) {
            device = _device
        }

        @inlinable
        public func makeAsyncIterator() -> AsyncIterator {
            .init(_device: device)
        }
    }
}

extension InputDevice.Events.AsyncIterator {
    fileprivate final actor StreamsStorage {
        private typealias StreamInformation = (stream: FileStream<input_event, any Error>, fileDescriptor: FileDescriptor, refCount: Int)

        private var streamValues = Dictionary<FilePath, StreamInformation>()

        func _getStreamSequence(for device: InputDevice) throws -> FileStream<input_event, any Error> {
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
            let newStream = FileStream<input_event, _>(fileDescriptor: fileDesc, failureBehavior: .throw)
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
