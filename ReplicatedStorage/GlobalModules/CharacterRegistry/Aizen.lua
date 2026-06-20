-- @ScriptType: ModuleScript
local Aizen = {}

Aizen.Moveset = {
	["Vizard"] = {
		Type = "Special",
		Skill = "Vizard",
		Name = "Vizard",
		Bind = "R",
		Cooldown = 8,
	},
	["ParryCounter"] = {
		Type = "BaseMove",
		Skill = "ParryCounter",
		Name = "Parry Counter",
		Bind = "1",
		Cooldown = 5,
	},
	["VanishingJab"] = {
		Type = "BaseMove",
		Skill = "VanishingJab",
		Name = "Vanishing Jab",
		Bind = "2",
		Cooldown = 4,
	},
	["Krash"] = {
		Type = "BaseMove",
		Skill = "ExampleProjectileSkill",
		Name = "Krash",
		Bind = "3",
		Cooldown = 7,
	},
	["Shunpo"] = {
		Type = "BaseMove",
		Skill = "Shunpo",
		Name = "Shunpo",
		Bind = "4",
		Cooldown = 3,
	},
	["BAN-KAI!"] = {
		Type = "Awakening",
		Skill = "Bankai",
		Name = "BAN-KAI!",
		Bind = "G",
		Cooldown = 1,
	}
}

Aizen.UI = {
	BarGradients = {
		Awakening = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(114, 33, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(158, 47, 255)),
			})
		},

		Special = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(114, 33, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(158, 47, 255)),
			})
		},
	}
}

return Aizen