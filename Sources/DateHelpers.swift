import Foundation

internal extension Date {
	init(time: timeval) {
		let timeInterval = TimeInterval(time.tv_sec) + (TimeInterval(time.tv_usec) / 1000000)
		self = Date(timeIntervalSince1970: timeInterval)
	}
}
