-- @ScriptType: ModuleScript
local Ichigo = {}

Ichigo.Moveset = {
	["Vizard"] = {
		Type = "Special",
		Skill = "Vizard",
		Name = "Vizard",
		Bind = "R",
		Cooldown = 8,
	},
	["GetsugaTensho"] = {
		Type = "BaseMove",
		Skill = "GetsugaTensho",
		Name = "Getsuga Tensho",
		Bind = "1",
		Tooltip = "VARIANTS",
		Cooldown = 5,
		Variants = {
			{
				Id = "Air",
				Name = "Aerial Getsuga Tensho",
				Skill = "GetsugaTenshoAir",
				Priority = 100,
				Cooldown = 6,
				Conditions = {
					Air = true,
				},
			},
			{
				Id = "Jump",
				Name = "Rising Getsuga Tensho",
				Skill = "GetsugaTenshoJump",
				Priority = 80,
				Cooldown = 5,
				Conditions = {
					Jump = true,
				},
			},
			{
				Id = "Block",
				Name = "Guard Break Getsuga",
				Skill = "GetsugaTenshoBlock",
				Priority = 70,
				Cooldown = 7,
				Conditions = {
					Block = true,
				},
			},
			{
				Id = "LowHP",
				Name = "Desperate Getsuga Tensho",
				Skill = "GetsugaTenshoLowHP",
				Priority = 60,
				Cooldown = 10,
				Conditions = {
					HPAtOrBelow = 0.35,
				},
			},
		},
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
		Skill = "Krash",
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

Ichigo.Combat = {
	M1 = {
		MaxCombo = 4,
	},

	Dash = {
		Forward = {
			SkillName = "CombatForwardDash",
			Speed = 78,
		},
	},
}

return Ichigo