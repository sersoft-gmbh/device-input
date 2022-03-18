import CInput

extension InputEvent {
    /// Represents the value of an input event.
    @frozen
	public struct Value: RawRepresentable, Hashable {
        /// inherited
		public typealias RawValue = input_event_value

        /// inherited
		public let rawValue: RawValue

        /// inherited
        public init(rawValue: RawValue) {
			self.rawValue = rawValue
		}
	}
}

extension InputEvent.Value {
    /// The key-up value of an event.
	public static let keyUp = InputEvent.Value(rawValue: 0)
    /// The key-down value of an event.
	public static let keyDown = InputEvent.Value(rawValue: 1)
    /// The auto-repeat value of an event.
    public static let autoRepeat = InputEvent.Value(rawValue: 2)
}

#if compiler(>=5.5.2) && canImport(_Concurrency)
extension InputEvent.Value: Sendable {}
#endif
