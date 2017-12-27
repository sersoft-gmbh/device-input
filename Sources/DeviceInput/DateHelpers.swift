#if os(Linux)
    import struct Glibc.timeval
#else
    import struct Darwin.timeval
#endif
import struct Foundation.Date
import typealias Foundation.TimeInterval

internal extension Date {
	init(time: timeval) {
		let timeInterval = TimeInterval(time.tv_sec) + (TimeInterval(time.tv_usec) / 1_000_000)
		self = Date(timeIntervalSince1970: timeInterval)
	}
}
