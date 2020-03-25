#if os(Linux)
    import struct Glibc.timeval
#else
    import struct Darwin.timeval
#endif
/**
* This strcut is replicating a C struct.
* It's crucial that this is not changed and matches the C Struct exactly.
* Otherwise it might not be possible to read events!
*/
struct CInputEvent {
    let time: timeval
    let type: CUnsignedShort
    let code: CUnsignedShort
    let value: CUnsignedInt

    // Instances are created by the system. No init needed. This gets optimized away by the compiler.
    @available(*, unavailable)
    private init() { time = .init(); type = .init(); code = .init(); value = .init() }
}
