public extension InputEvent {
	public struct Code: RawRepresentable, Hashable {
		public typealias RawValue = CUnsignedShort

		public let rawValue: RawValue

		public init(rawValue: RawValue) {
			self.rawValue = rawValue
		}
	}
}

public extension InputEvent.Code {
	public var stringValue: String? {
		return InputEvent.Code.keyCodeMapping[rawValue]
	}
}

fileprivate extension InputEvent.Code {
	static let keyCodeMapping: [CUnsignedShort: String] = [
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
	    16: "Q",
	    17: "W",
	    18: "E",
	    19: "R",
	    20: "T",
	    21: "Y",
	    22: "U",
	    23: "I",
	    24: "O",
	    25: "P",
	    26: "(", // LEFTBRACE
	    27: ")", // RIGHTBRACE
	    28: "\n", // ENTER
	//    29: "LEFTCTRL",
	    30: "A",
	    31: "S",
	    32: "D",
	    33: "F",
	    34: "G",
	    35: "H",
	    36: "J",
	    37: "K",
	    38: "L",
	    39: ";", // SEMICOLON
	    40: "`", // APOSTROPHE
	    41: "^", // GRAVE
	//    42: "LEFTSHIFT",
	    43: "\\", // BACKSLASH
	    44: "Z",
	    45: "X",
	    46: "C",
	    47: "V",
	    48: "B",
	    49: "N",
	    50: "M",
	    51: ",", // COMMA
	    52: ".", // DOT
	   53: "/", // SLASH
	//    54: "RIGHTSHIFT",
	//    55: "KPASTERISK",
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
	//    71: "KP7",
	//    72: "KP8",
	//    73: "KP9",
	//    74: "KPMINUS",
	//    75: "KP4",
	//    76: "KP5",
	//    77: "KP6",
	//    78: "KPPLUS",
	//    79: "KP1",
	//    80: "KP2",
	//    81: "KP3",
	//    82: "KP0",
	//    83: "KPDOT",
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
	//    95: "KPJPCOMMA",
	//    96: "KPENTER",
	//    97: "RIGHTCTRL",
	//    98: "KPSLASH",
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
	//    0x20b: "NUMERIC_POUND",
	    0x20c: "A", // NUMERIC_A
	    0x20d: "B", // NUMERIC_B
	    0x20e: "C", // NUMERIC_C
	    0x20f: "D" // NUMERIC_D
	]
}
