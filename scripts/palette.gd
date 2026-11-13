extends RefCounted
## Colour themes (the palette button in the top bar cycles through these).
## "arrows" = candy colours handed out to the arrows (neighbours get different ones).
## "deco"   = colours of the soft background bubbles.

const THEMES := [
	{ # Candy - bright and kid friendly (default)
		"name": "Candy",
		"bg": Color("fff6dc"), "line": Color("4a2c7a"), "title": Color("ff5c8a"),
		"rule": Color("ffd6a5"), "panel": Color("ffffff"), "footer": Color("ffc93c"),
		"footer_text": Color("4a2c7a"), "drop": Color("3da5f4"), "danger": Color("ff3b3b"),
		"hint": Color("7c4dff"), "dim": Color("c9b8e8"), "gold": Color("ff9f1c"),
		"arrows": [Color("ff5c8a"), Color("ff9f1c"), Color("f5b800"), Color("1fbfae"), Color("3da5f4"),
			Color("845ef7"), Color("45c45b"), Color("ff6b6b"), Color("e64980"), Color("15aabf")],
		"deco": [Color("ffb3c7"), Color("a5d8ff"), Color("ffe08a")],
	},
	{ # Night - neon on dark
		"name": "Night",
		"bg": Color("1b1f3b"), "line": Color("e8ecff"), "title": Color("ffd166"),
		"rule": Color("343a6b"), "panel": Color("2a2f57"), "footer": Color("232850"),
		"footer_text": Color("aeb8ff"), "drop": Color("5ec8ff"), "danger": Color("ff6b6b"),
		"hint": Color("ffffff"), "dim": Color("5a63a0"), "gold": Color("ff9f1c"),
		"arrows": [Color("ff6fa5"), Color("ffb84d"), Color("ffe66d"), Color("4df0c9"), Color("5ec8ff"),
			Color("a78bff"), Color("7cff8a"), Color("ff8a8a"), Color("ff7ce0"), Color("4de1ff")],
		"deco": [Color("3a3f7a"), Color("2f5a8a"), Color("5a3a7a")],
	},
	{ # Meadow - greens, blues and sunshine
		"name": "Meadow",
		"bg": Color("e3f6e1"), "line": Color("24533c"), "title": Color("1f9d6b"),
		"rule": Color("b7e0b5"), "panel": Color("ffffff"), "footer": Color("b6e3a8"),
		"footer_text": Color("24533c"), "drop": Color("3da5f4"), "danger": Color("e8453c"),
		"hint": Color("ff7a00"), "dim": Color("98c79a"), "gold": Color("ffa62b"),
		"arrows": [Color("2f9e44"), Color("f59f00"), Color("1c7ed6"), Color("e8590c"), Color("0ca678"),
			Color("7048e8"), Color("d6336c"), Color("74b816"), Color("1098ad"), Color("f03e3e")],
		"deco": [Color("b2f2bb"), Color("a5d8ff"), Color("ffec99")],
	},
	{ # Bubblegum - pinks and purples
		"name": "Bubblegum",
		"bg": Color("ffe3f1"), "line": Color("7a2e5c"), "title": Color("e83e8c"),
		"rule": Color("ffc2df"), "panel": Color("ffffff"), "footer": Color("ffb3d9"),
		"footer_text": Color("7a2e5c"), "drop": Color("5aa9f7"), "danger": Color("d7263d"),
		"hint": Color("6741d9"), "dim": Color("e0a9c8"), "gold": Color("ff7eb6"),
		"arrows": [Color("e64980"), Color("ae3ec9"), Color("7048e8"), Color("4c6ef5"), Color("15aabf"),
			Color("fd7e14"), Color("f06595"), Color("be4bdb"), Color("fa5252"), Color("20c997")],
		"deco": [Color("ffc9e3"), Color("e5c6ff"), Color("c5d8ff")],
	},
	{ # Parchment - the calm original look
		"name": "Parchment",
		"bg": Color("f4ebd9"), "line": Color("7a5233"), "title": Color("c8902a"),
		"rule": Color("d9c6a5"), "panel": Color("ffffff"), "footer": Color("dcc9a3"),
		"footer_text": Color("7f5a1c"), "drop": Color("4da8f2"), "danger": Color("d9482b"),
		"hint": Color("2e9e6b"), "dim": Color("b7a58a"), "gold": Color("e3a52f"),
		"arrows": [Color("7a5233")],
		"deco": [Color("eadcc0"), Color("e6d2ac"), Color("efe3cb")],
	},
]


static func get_theme(i: int) -> Dictionary:
	return THEMES[posmod(i, THEMES.size())]
