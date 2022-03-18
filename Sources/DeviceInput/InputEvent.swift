import struct Foundation.Date
import typealias Foundation.TimeInterval
import CInput

/// Describes an input event.
public struct InputEvent: Hashable {
    /// The timestamp of the event.
	public let date: Date
    /// The kind of event.
	public let kind: Kind
    /// The code of the event.
	public let code: Code
    /// The value of the event.
	public let value: Value

    @usableFromInline
	internal init?(cInputEvent: input_event) {
		guard let type = Kind(rawValue: cInputEvent.type) else { return nil }
        let timeInterval = TimeInterval(input_event_get_sec(cInputEvent)) + (TimeInterval(input_event_get_usec(cInputEvent)) / 1_000_000)
		date = Date(timeIntervalSince1970: timeInterval)
		kind = type
		code = Code(rawValue: cInputEvent.code)
		value = Value(rawValue: cInputEvent.value)
	}
}


//#if compiler(>=5.5.2) && canImport(_Concurrency)
//extension InputEvent: Sendable {} // Missinc conformance of `Foundation.Date`
//#endif
