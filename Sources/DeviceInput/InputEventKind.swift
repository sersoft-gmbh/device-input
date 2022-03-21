import CInput

extension InputEvent {
    /// Defines the type of input event.
	public enum Kind: input_event_type {
		case synchronization = 0x00 // EV_SYN
		case keyStateChange = 0x01 // EV_KEY
		case relativeAxis = 0x02 // EV_REL
		case absoluteAxis = 0x03 // EV_ABS
		case miscellaneous = 0x04 // EV_MSC
		case binarySwitch = 0x05 // EV_SW
		case led = 0x11 // EV_LED
		case sound = 0x12 // EV_SND
		case autoRepeat = 0x14 // EV_REP
		case forceFeedback = 0x15 // EV_FF
		case power = 0x16 // EV_PWR
		case forceFeedbackStatus = 0x17 // EV_FF_STATUS

        /// The maximum raw value of this type.
        static var max: RawValue { 0x1f } // EV_MAX
        /// The amount of raw values possible in this type.
        static var count: RawValue { max + 1 } // EV_CNT
	}
}

#if compiler(>=5.5.2) && canImport(_Concurrency)
extension InputEvent.Kind: Sendable {}
#endif
