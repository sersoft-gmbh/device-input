import CInput

extension InputEvent {
    /// Contains the code of an input event.
    @frozen
	public struct Code: RawRepresentable, Hashable {
        /// inherited
		public typealias RawValue = input_event_code

        /// inherited
		public let rawValue: RawValue

        /// inherited
		public init(rawValue: RawValue) {
			self.rawValue = rawValue
		}
	}
}

#if compiler(>=5.5.2) && canImport(_Concurrency)
extension InputEvent.Code: Sendable {}
#endif

extension InputEvent.Code {
    /// Returns the character value of the event code if available.
    /// Certain control codes (e.g. escape, shift, ...) don't have a character value.
	public var character: Character? { InputEvent.Code.keyCodeMapping[rawValue] }
}

fileprivate extension InputEvent.Code {
	static let keyCodeMapping: [InputEvent.Code.RawValue: Character] = [
	//    0: "RESERVED",
	//    1: "ESC",
	    2: "1",
	    3: "2",
	    4: "3",
	    5: "4",
	    6: "5",
	    7: "6",
	    8: "7",
	    9: "8",
	    10: "9",
	    11: "0",
	    12: "-", // MINUS
	    13: "=", // EQUAL
	//    14: "BACKSPACE",
	    15: "\t", // TAB
	    16: "q",
	    17: "w",
	    18: "e",
	    19: "r",
	    20: "t",
	    21: "y",
	    22: "u",
	    23: "i",
	    24: "o",
	    25: "p",
	    26: "(", // LEFTBRACE
	    27: ")", // RIGHTBRACE
	    28: "\n", // ENTER
	//    29: "LEFTCTRL",
	    30: "a",
	    31: "s",
	    32: "d",
	    33: "f",
	    34: "g",
	    35: "h",
	    36: "j",
	    37: "k",
	    38: "l",
	    39: ";", // SEMICOLON
	    40: "`", // APOSTROPHE
	    41: "^", // GRAVE
	//    42: "LEFTSHIFT",
	    43: "\\", // BACKSLASH
	    44: "z",
	    45: "x",
	    46: "c",
	    47: "v",
	    48: "b",
	    49: "n",
	    50: "m",
	    51: ",", // COMMA
	    52: ".", // DOT
	    53: "/", // SLASH
	//    54: "RIGHTSHIFT",
	    55: "*", // KPASTERISK
	//    56: "LEFTALT",
	    57: " ", // SPACE
	//    58: "CAPSLOCK",
	//    59: "F1",
	//    60: "F2",
	//    61: "F3",
	//    62: "F4",
	//    63: "F5",
	//    64: "F6",
	//    65: "F7",
	//    66: "F8",
	//    67: "F9",
	//    68: "F10",
	//    69: "NUMLOCK",
	//    70: "SCROLLLOCK",
	    71: "7", // KP7
	    72: "8", // KP8
	    73: "9", // KP9
	    74: "-", // KPMINUS
	    75: "4", // KP4
	    76: "5", // KP5
	    77: "6", // KP6
	    78: "+", // KPPLUS
	    79: "1", // KP1
	    80: "2", // KP2
	    81: "3", // KP3
	    82: "0", // KP0
	    83: ".", // KPDOT
	//    85: "ZENKAKUHANKAKU",
	//    86: "102ND",
	//    87: "F11",
	//    88: "F12",
	//    89: "RO",
	//    90: "KATAKANA",
	//    91: "HIRAGANA",
	//    92: "HENKAN",
	//    93: "KATAKANAHIRAGANA",
	//    94: "MUHENKAN",
	    95: ",", // KPJPCOMMA
	//    96: "KPENTER",
	//    97: "RIGHTCTRL",
	    98: "/", // KPSLASH
	//    99: "SYSRQ",
	//    100: "RIGHTALT",
	    101: "\n", // LINEFEED
	    0x1b2: "$", // DOLLAR
	    0x1b3: "€", // EURO
	    0x200: "0",
	    0x201: "1",
	    0x202: "2",
	    0x203: "3",
	    0x204: "4",
	    0x205: "5",
	    0x206: "6",
	    0x207: "7",
	    0x208: "8",
	    0x209: "9",
	    0x20a: "*", // NUMERIC_STAR
	    0x20b: "#", // NUMERIC_POUND
	    0x20c: "a", // NUMERIC_A
	    0x20d: "b", // NUMERIC_B
	    0x20e: "c", // NUMERIC_C
	    0x20f: "d", // NUMERIC_D
	]
}
