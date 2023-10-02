import Foundation
import XCTest
import SystemPackage
import CInput
@testable import DeviceInput

fileprivate extension InputEvent {
    static func cEvent(date: Date, kind: Kind, code: Code, value: Value) -> input_event {
        var cEvent = input_event()
        let seconds = time_t(date.timeIntervalSince1970)
        let uSeconds = suseconds_t((date.timeIntervalSince1970 - TimeInterval(seconds)) * 1_000_000)
        input_event_set_sec(&cEvent, seconds)
        input_event_set_usec(&cEvent, uSeconds)
        cEvent.type = kind.rawValue
        cEvent.code = code.rawValue
        cEvent.value = value.rawValue
        return cEvent
    }

    init(date: Date, kind: Kind, code: Code, value: Value) {
        self.init(cInputEvent: Self.cEvent(date: date, kind: kind, code: code, value: value))!
    }
}

final class InputDeviceTests: XCTestCase {
    func testEquatable() {
        let device1 = InputDevice(eventFile: FilePath("/path/to/file1"), grabDevice: true)
        let device2 = InputDevice(eventFile: FilePath("/path/to/file1"), grabDevice: false)
        let device3 = InputDevice(eventFile: FilePath("/path/to/file2"), grabDevice: false)
        XCTAssertEqual(device1, device2)
        XCTAssertNotEqual(device1, device3)
        XCTAssertNotEqual(device2, device3)
    }

    func testAsyncEventStreams() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        addTeardownBlock {
            try FileManager.default.removeItem(at: tempDir)
        }
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
            try eventsToSend.dropLast(4).withUnsafeBytes {
                _ = try handle.write($0)
            }
            try eventsToSend.dropFirst(3).withUnsafeBytes {
                _ = try handle.write($0)
            }
        }
        let foundEvents = try await task.value
        XCTAssertEqual(eventsToSend.count, foundEvents.count)
        XCTAssertEqual(foundEvents, eventsToSend.compactMap(InputEvent.init))
    }

    func testSequenceCancellation() async throws {
        final actor FoundEventsStorage {
            private(set) var events = Array<InputEvent>()

            @discardableResult
            func add(_ event: InputEvent) -> Int {
                events.append(event)
                return events.count
            }
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        addTeardownBlock {
            try FileManager.default.removeItem(at: tempDir)
        }
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
            try eventsToSend.dropLast(4).withUnsafeBytes {
                _ = try handle.write($0)
            }
            task.cancel()
            try eventsToSend.dropFirst(3).withUnsafeBytes {
                _ = try handle.write($0)
            }
        }
        let foundEvents = await foundEventsStorage.events
        let result = await task.result
        XCTAssertTrue(task.isCancelled)
        XCTAssertThrowsError(try result.get()) {
            XCTAssertTrue($0 is CancellationError)
        }
        XCTAssertGreaterThan(eventsToSend.count, foundEvents.count)
    }
}
