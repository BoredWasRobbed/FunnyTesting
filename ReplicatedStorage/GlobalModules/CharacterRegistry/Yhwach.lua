-- @ScriptType: ModuleScript
local Yhwach = {}

Yhwach.Moveset = {
	["Auswählen"] = {
		Type = "Special",
		Name = "Auswählen",
		Bind = "R"
	},
	["SanktBogen"] = {
		Type = "BaseMove",
		Name = "Sankt Bogen",
		Bind = "1",
		Tooltip = "HOLD"
	},
	["BlutArterie"] = {
		Type = "BaseMove",
		Name = "Blut Arterie",
		Bind = "2"
	},
	["FlashingReishi"] = {
		Type = "BaseMove",
		Name = "Flashing Reishi",
		Bind = "3"
	},
	["Hirenkyaku"] = {
		Type = "BaseMove",
		Name = "Hirenkyaku",
		Bind = "4"
	},
	["TheSealedKing"] = {
		Type = "Awakening",
		Name = "The Sealed King",
		Bind = "G"
	}
}

Yhwach.UI = {
	BarGradients = {
		Awakening = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 187, 255)),
			})
		},

		Special = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 187, 255)),
			})
		},
	}
}

return Yhwach