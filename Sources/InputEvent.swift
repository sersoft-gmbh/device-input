import Foundation

public struct InputEvent: Hashable {
	public let date: Date
	public let kind: Kind
	public let code: Code
	public let value: Value

	public var hashValue: Int { return date.hashValue ^ kind.hashValue ^ code.hashValue ^ value.hashValue }

	public static func ==(lhs: InputEvent, rhs: InputEvent) -> Bool {
		return (lhs.date, lhs.kind, lhs.code, lhs.value) == (rhs.date, rhs.kind, rhs.code, rhs.value)
	}

	internal init?(cInputEvent: CInputEvent) {
		guard let type = Kind(rawValue: cInputEvent.type) else { return nil }
		date = Date(time: cInputEvent.time)
		kind = type
		code = Code(rawValue: cInputEvent.code)
		value = Value(rawValue: cInputEvent.value)
	}
}
