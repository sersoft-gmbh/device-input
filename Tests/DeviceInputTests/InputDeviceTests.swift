import Foundation
import XCTest
import SystemPackage
import Cinput
@testable import DeviceInput

fileprivate extension InputEvent {
    static func cEvent(date: Date, kind: Kind, code: Code, value: Value) -> input_event {
        var cEvent = input_event()
        let seconds = Int32(date.timeIntervalSince1970)
        let uSeconds = Int32((date.timeIntervalSince1970 - TimeInterval(seconds)) * 1_000_000)
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

    func testEventParsing() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        let eventFile = FilePath(tempDir.appendingPathComponent("event_file").path)
        let handle = try FileDescriptor.open(eventFile, .writeOnly,
                                             options: [.create, .append],
                                             permissions: [.ownerReadWrite, .groupReadWrite])
        let inputDevice = InputDevice(eventFile: eventFile, grabDevice: false)
        let expect = expectation(description: "Waiting for events to be received")
        var (foundDevice, foundEvents): (InputDevice?, [InputEvent]) = (nil, [])
        let consumer = InputDevice.EventConsumer(queue: .global()) {
            (foundDevice, foundEvents) = ($0, $1)
            expect.fulfill()
        }
        let activeStream = try inputDevice.startStreaming(informing: consumer)
        defer {
            try? activeStream.stopStreaming()
        }
        var cEvent = InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 5), value: .keyUp)
        try handle.closeAfter {
            try withUnsafeBytes(of: &cEvent) {
                _ = try handle.write($0)
            }
        }
        waitForExpectations(timeout: 3)
        XCTAssertNotNil(foundDevice)
        XCTAssertFalse(foundEvents.isEmpty)
        XCTAssertEqual(foundDevice, inputDevice)
        XCTAssertEqual(foundEvents, try [XCTUnwrap(InputEvent(cInputEvent: cEvent))])
    }

    func testMultipleEventsParsing() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        let eventFile = FilePath(tempDir.appendingPathComponent("event_file").path)
        let handle = try FileDescriptor.open(eventFile, .writeOnly,
                                             options: [.create, .append],
                                             permissions: [.ownerReadWrite, .groupReadWrite])
        let inputDevice = InputDevice(eventFile: eventFile, grabDevice: false)
        let expect = expectation(description: "Waiting for events to be received")
        let eventsToSend = [
            InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 5), value: .keyUp),
            InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 6), value: .keyUp),
            InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 7), value: .keyUp),
            InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 8), value: .keyUp),
            InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 9), value: .keyUp),
            InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 2), value: .keyUp),
            InputEvent.cEvent(date: Date(), kind: .keyStateChange, code: .init(rawValue: 3), value: .keyUp),
        ]
        var foundEvents = Array<InputEvent>()
        let consumer = InputDevice.EventConsumer(queue: DispatchQueue(label: "test")) {
            foundEvents.append(contentsOf: $1)
            if foundEvents.count >= eventsToSend.count {
                expect.fulfill()
            }
        }
        let activeStream = try inputDevice.startStreaming(informing: consumer)
        defer {
            try? activeStream.stopStreaming()
        }
        try handle.closeAfter {
            try eventsToSend.dropLast(4).withUnsafeBytes {
                _ = try handle.write($0)
            }
            try eventsToSend.dropFirst(3).withUnsafeBytes {
                _ = try handle.write($0)
            }
        }
        waitForExpectations(timeout: 5)
        XCTAssertEqual(eventsToSend.count, foundEvents.count)
        XCTAssertEqual(foundEvents, eventsToSend.compactMap(InputEvent.init))
    }
}
