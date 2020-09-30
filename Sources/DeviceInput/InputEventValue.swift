import Cinput

extension InputEvent {
	public struct Value: RawRepresentable, Hashable {
		public typealias RawValue = input_event_value

		public let rawValue: RawValue
        
        public init(rawValue: RawValue) {
			self.rawValue = rawValue
		}
	}
}

extension InputEvent.Value {
	public static let keyUp = InputEvent.Value(rawValue: 0)
	public static let keyDown = InputEvent.Value(rawValue: 1)
}
