public extension InputEvent {
	public struct Value: RawRepresentable, Hashable {
		public typealias RawValue = CUnsignedInt

		public let rawValue: RawValue
        
        public var hashValue: Int { return rawValue.hashValue }

		public init(rawValue: RawValue) {
			self.rawValue = rawValue
		}
	}
}

public extension InputEvent.Value {
	public static let keyUp = InputEvent.Value(rawValue: 0)
	public static let keyDown = InputEvent.Value(rawValue: 1)
}
