import Foundation
import Testing
import SystemPackage
import CInput
@testable import DeviceInput

fileprivate extension InputEvent {
    static func cEvent(date: Date, kind: Kind, code: Code, value: Value) -> input_event {
        var cEvent = input_event()
        let seconds = time_t(date.timeIntervalSince1970)
        let uSeconds = suseconds_t((date.timeIntervalSince1970 - TimeInterval(seconds)) * 1_000_000)
#if compiler(>=6.2)
        unsafe input_event_set_sec(&cEvent, seconds)
        unsafe input_event_set_usec(&cEvent, uSeconds)
#else
        input_event_set_sec(&cEvent, seconds)
        input_event_set_usec(&cEvent, uSeconds)
#endif
        cEvent.type = kind.rawValue
        cEvent.code = code.rawValue
        cEvent.value = value.rawValue
        return cEvent
    }

    init(date: Date, kind: Kind, code: Code, value: Value) {
        self.init(cInputEvent: Self.cEvent(date: date, kind: kind, code: code, value: value))!
    }
}

@Suite
struct InputDeviceTests {
    private func withTemporaryDirectory(do work: (URL) async throws -> ()) async throws {
        let newSubdir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: newSubdir, withIntermediateDirectories: true)
        do {
            try await work(newSubdir)
        } catch {
            #expect(throws: Never.self) {
                try FileManager.default.removeItem(at: newSubdir)
            }
            throw error
        }
        try FileManager.default.removeItem(at: newSubdir)
    }

    @Test
    func equatable() {
        let device1 = InputDevice(eventFile: FilePath("/path/to/file1"), grabDevice: true)
        let device2 = InputDevice(eventFile: FilePath("/path/to/file1"), grabDevice: false)
        let device3 = InputDevice(eventFile: FilePath("/path/to/file2"), grabDevice: false)
        #expect(device1 == device2)
        #expect(device1 != device3)
        #expect(device2 != device3)
    }

    @Test
    func asyncEventStreams() async throws {
        try await withTemporaryDirectory { tempDir in
            let eventFile = FilePath(tempDir.appendingPathComponent("event_file").path)
            let handle = try FileDescriptor.open(eventFile, .writeOnly,
                                                 options: [.create, .append],
                                                 permissions: [.ownerReadWrite, .groupReadWrite])
            let inputDevice = InputDevice(eventFile: eventFile, grabDevice: false)
            let eventsToSend = [
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 5), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 6), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 7), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 8), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 9), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 2), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 3), value: .keyUp),
            ]
            let task = Task<Array<InputEvent>, any Error>.detached {
                var foundEvents = Array<InputEvent>()
                for try await event in inputDevice.events {
                    foundEvents.append(event)
                    if foundEvents.count >= eventsToSend.count {
                        break
                    }
                }
                return foundEvents
            }
            try await Task.sleep(nanoseconds: 1_000_000) // wait for loop to be set up
            try handle.closeAfter {
#if compiler(>=6.2)
                unsafe try eventsToSend.dropLast(4).withUnsafeBytes {
                    _ = unsafe try handle.write($0)
                }
                unsafe try eventsToSend.dropFirst(3).withUnsafeBytes {
                    _ = unsafe try handle.write($0)
                }
#else
                try eventsToSend.dropLast(4).withUnsafeBytes {
                    _ = try handle.write($0)
                }
                try eventsToSend.dropFirst(3).withUnsafeBytes {
                    _ = try handle.write($0)
                }
#endif
            }
            let foundEvents = try await task.value
            #expect(eventsToSend.count == foundEvents.count)
            #expect(foundEvents == eventsToSend.compactMap(InputEvent.init))
        }
    }

    @Test
    func sequenceCancellation() async throws {
        final actor FoundEventsStorage {
            private(set) var events = Array<InputEvent>()

            @discardableResult
            func add(_ event: InputEvent) -> Int {
                events.append(event)
                return events.count
            }
        }

        try await withTemporaryDirectory { tempDir in
            let eventFile = FilePath(tempDir.appendingPathComponent("event_file").path)
            let handle = try FileDescriptor.open(eventFile, .writeOnly,
                                                 options: [.create, .append],
                                                 permissions: [.ownerReadWrite, .groupReadWrite])
            let inputDevice = InputDevice(eventFile: eventFile, grabDevice: false)
            let eventsToSend = [
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 5), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 6), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 7), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 8), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 9), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 2), value: .keyUp),
                InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 3), value: .keyUp),
            ]
            let foundEventsStorage = FoundEventsStorage()
            let task = Task<Void, any Error>.detached {
                for try await event in inputDevice.events {
                    let foundCount = await foundEventsStorage.add(event)
                    if foundCount >= eventsToSend.count {
                        break
                    }
                }
                try Task.checkCancellation()
            }
            try await Task.sleep(nanoseconds: 1_000_000) // wait for loop to be set up
            try handle.closeAfter {
#if compiler(>=6.2)
                unsafe try eventsToSend.dropLast(4).withUnsafeBytes {
                    _ = unsafe try handle.write($0)
                }
#else
                try eventsToSend.dropLast(4).withUnsafeBytes {
                    _ = try handle.write($0)
                }
#endif
                task.cancel()
#if compiler(>=6.2)
                unsafe try eventsToSend.dropFirst(3).withUnsafeBytes {
                    _ = unsafe try handle.write($0)
                }
#else
                try eventsToSend.dropFirst(3).withUnsafeBytes {
                    _ = try handle.write($0)
                }
#endif
            }
            let foundEvents = await foundEventsStorage.events
            let result = await task.result
            #expect(task.isCancelled)
            #expect(throws: CancellationError.self) { try result.get() }
            #expect(eventsToSend.count > foundEvents.count)
        }
    }
}
