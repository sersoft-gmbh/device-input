/*
#define EV_SYN			0x00
#define EV_KEY			0x01
#define EV_REL			0x02
#define EV_ABS			0x03
#define EV_MSC			0x04
#define EV_SW			0x05
#define EV_LED			0x11
#define EV_SND			0x12
#define EV_REP			0x14
#define EV_FF			0x15
#define EV_PWR			0x16
#define EV_FF_STATUS		0x17
#define EV_MAX			0x1f
#define EV_CNT			(EV_MAX+1)
*/

extension InputEvent {
	public enum Kind: CUnsignedShort {
		case syn = 0x00
		case key = 0x01
		case rel = 0x02
		case abs = 0x03
		case msc = 0x04
		case sw  = 0x05
		case led = 0x11
		case snd = 0x12
		case rep = 0x14
		case ff  = 0x15
		case pwr = 0x16
		case ffStatus = 0x17

		case max = 0x1f
		case cnt = 0x20 //(0x1f + 1)
	}
}
