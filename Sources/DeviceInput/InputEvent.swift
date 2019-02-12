import struct Foundation.Date

public struct InputEvent: Hashable {
	public let date: Date
	public let kind: Kind
	public let code: Code
	public let value: Value

	internal init?(cInputEvent: CInputEvent) {
		guard let type = Kind(rawValue: cInputEvent.type) else { return nil }
		date = Date(time: cInputEvent.time)
		kind = type
		code = Code(rawValue: cInputEvent.code)
		value = Value(rawValue: cInputEvent.value)
	}
}
