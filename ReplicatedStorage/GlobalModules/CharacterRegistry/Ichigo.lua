-- @ScriptType: ModuleScript
local Ichigo = {}

Ichigo.Moveset = {
	["Vizard"] = {
		Type = "Special",
		Name = "Vizard",
		Bind = "R"
	},
	["GetsugaTensho"] = {
		Type = "BaseMove",
		Name = "Getsuga Tensho",
		Bind = "1",
		Tooltip = "HOLD"
	},
	["VanishingJab"] = {
		Type = "BaseMove",
		Name = "Vanishing Jab",
		Bind = "2"
	},
	["Krash"] = {
		Type = "BaseMove",
		Name = "Krash",
		Bind = "3"
	},
	["Shunpo"] = {
		Type = "BaseMove",
		Name = "Shunpo",
		Bind = "4"
	},
	["BAN-KAI!"] = {
		Type = "Awakening",
		Name = "BAN-KAI!",
		Bind = "G"
	}
}

Ichigo.UI = {
	BarGradients = {
		Awakening = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 164, 8)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 191, 41)),
			})
		},

		Special = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 164, 8)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 191, 41)),
			})
		},
	}
}

return Ichigo