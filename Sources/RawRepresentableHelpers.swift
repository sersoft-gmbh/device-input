public extension RawRepresentable where RawValue: Hashable {
	public var hashValue: Int { return rawValue.hashValue }
}
