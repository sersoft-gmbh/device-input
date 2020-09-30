import struct Foundation.Date
import typealias Foundation.TimeInterval
import Cinput

public struct InputEvent: Hashable {
	public let date: Date
	public let kind: Kind
	public let code: Code
	public let value: Value

	internal init?(cInputEvent: input_event) {
		guard let type = Kind(rawValue: cInputEvent.type) else { return nil }
        let timeInterval = TimeInterval(input_event_get_sec(cInputEvent)) + (TimeInterval(input_event_get_usec(cInputEvent)) / 1_000_000)
		date = Date(timeIntervalSince1970: timeInterval)
		kind = type
		code = Code(rawValue: cInputEvent.code)
		value = Value(rawValue: cInputEvent.value)
	}
}
