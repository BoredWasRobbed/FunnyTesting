-- @ScriptType: ModuleScript
local Players = game:GetService("Players")

local CharacterRegistry = require(script.Parent:WaitForChild("CharacterRegistry"))

local CombatConfig = {}

local DEFAULT = {
	Evasive = {
		Max = 100,
		DealDamageGain = 7,
		TakeDamageGain = 12,
		ConsumeAmount = 100,
		EvasiveDashSpeed = 82,
		EvasiveDashDuration = 0.24,
	},

	Block = {
		FrontDot = 0,
		ChipMultiplier = 0,
		CanBlockRagdoll = false,
	},

	M1 = {
		SkillName = "CombatM1",
		ResetTime = 1.1,
		MaxCombo = 4,
		AttackWalkSpeed = 6,
		Finisher = {
			Knockback = { Force = 45, Up = 0 },
			Ragdoll = { Duration = 1.2 },
		},
		Steps = {
			{
				Id = "M1_1",
				Name = "M1 1",
				Damage = 4,
				Shape = "Box",
				Size = Vector3.new(5.5, 5, 6),
				Offset = CFrame.new(0, 0, -3.2),
				Duration = 0.12,
				Windup = 0.05,
				StateDuration = 0.28,
				HitStun = 0.22,
				Knockback = { Force = 18, Up = 0 },
				Parryable = true,
			},
			{
				Id = "M1_2",
				Name = "M1 2",
				Damage = 4,
				Shape = "Box",
				Size = Vector3.new(5.5, 5, 6),
				Offset = CFrame.new(0, 0, -3.2),
				Duration = 0.12,
				Windup = 0.05,
				StateDuration = 0.28,
				HitStun = 0.22,
				Knockback = { Force = 19, Up = 0 },
				Parryable = true,
			},
			{
				Id = "M1_3",
				Name = "M1 3",
				Damage = 5,
				Shape = "Box",
				Size = Vector3.new(5.8, 5, 6.2),
				Offset = CFrame.new(0, 0, -3.3),
				Duration = 0.13,
				Windup = 0.06,
				StateDuration = 0.3,
				HitStun = 0.24,
				Knockback = { Force = 21, Up = 0 },
				Parryable = true,
			},
			{
				Id = "M1_4",
				Name = "M1 4",
				Damage = 6,
				Shape = "Box",
				Size = Vector3.new(6.2, 5, 6.8),
				Offset = CFrame.new(0, 0, -3.6),
				Duration = 0.14,
				Windup = 0.07,
				StateDuration = 0.42,
				HitStun = 0.35,
				Knockback = { Force = 45, Up = 0 },
				Ragdoll = { Duration = 1.2 },
				Parryable = true,
			},
		},
		Uppercut = {
			Id = "M1_Uppercut",
			Name = "Uppercut",
			Damage = 7,
			Shape = "Box",
			Size = Vector3.new(6, 7, 6),
			Offset = CFrame.new(0, 1.2, -3.2),
			Duration = 0.16,
			Windup = 0.07,
			StateDuration = 0.46,
			HitStun = 0.35,
			Knockback = { Force = 12, Up = 58 },
			Ragdoll = { Duration = 1.1 },
			Parryable = true,
		},
		Downslam = {
			Id = "M1_Downslam",
			Name = "Down Slam",
			Damage = 8,
			Shape = "Box",
			Size = Vector3.new(7, 8, 7),
			Offset = CFrame.new(0, -2.5, -2.4),
			Duration = 0.18,
			Windup = 0.06,
			StateDuration = 0.5,
			HitStun = 0.35,
			Knockback = { Force = 8, Up = -52 },
			Ragdoll = { Duration = 1.3 },
			Parryable = true,
		},
	},

	Dash = {
		Cooldown = 0.85,
		Side = {
			Speed = 64,
			Duration = 0.22,
			StateDuration = 0.28,
		},
		Back = {
			Speed = 58,
			Duration = 0.24,
			StateDuration = 0.3,
		},
		Forward = {
			SkillName = "CombatForwardDash",
			Speed = 74,
			Duration = 0.24,
			StateDuration = 0.3,
			Cooldown = 1.45,
			HitStart = 0.13,
			HitDuration = 0.26,
			Damage = 6,
			Shape = "Box",
			Size = Vector3.new(6, 5, 7),
			Offset = CFrame.new(0, 0, -3.6),
			HitStun = 0.28,
			Knockback = { Force = 34, Up = 4 },
			Parryable = true,
		},
	},
}

local function deepCopy(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		if typeof(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function deepMerge(base, override)
	local merged = deepCopy(base)

	for key, value in pairs(override or {}) do
		if typeof(value) == "table" and typeof(merged[key]) == "table" then
			merged[key] = deepMerge(merged[key], value)
		elseif typeof(value) == "table" then
			merged[key] = deepCopy(value)
		else
			merged[key] = value
		end
	end

	return merged
end

local function getCharacterName(subject)
	if typeof(subject) == "Instance" and subject:IsA("Player") then
		return subject:GetAttribute("CurrentCharacter") or subject:GetAttribute("Character") or "Ichigo"
	end

	if typeof(subject) == "Instance" and subject:IsA("Model") then
		local player = Players:GetPlayerFromCharacter(subject)
		if player then
			return getCharacterName(player)
		end

		return subject:GetAttribute("CurrentCharacter") or subject:GetAttribute("Character") or "Ichigo"
	end

	return "Ichigo"
end

local function getStep(m1Config, comboIndex, variantName)
	local maxCombo = m1Config.MaxCombo or #(m1Config.Steps or {})
	local clampedIndex = math.clamp(tonumber(comboIndex) or 1, 1, math.max(maxCombo, 1))

	if clampedIndex == maxCombo then
		if variantName == "Downslam" and m1Config.Downslam then
			return deepMerge(m1Config.Steps[clampedIndex] or {}, m1Config.Downslam)
		end

		if variantName == "Uppercut" and m1Config.Uppercut then
			return deepMerge(m1Config.Steps[clampedIndex] or {}, m1Config.Uppercut)
		end
	end

	local step = deepCopy(m1Config.Steps[clampedIndex] or m1Config.Steps[#m1Config.Steps] or {})
	if clampedIndex == maxCombo and not variantName and step.SpecialType ~= true then
		step = deepMerge(m1Config.Finisher or {}, step)
	end

	return step
end

local function buildSkillConfig(stepConfig, extra)
	local config = deepMerge({
		Shape = "Box",
		Size = Vector3.new(5, 5, 5),
		Offset = CFrame.new(0, 0, -3),
		Duration = 0.12,
		CastWindow = 0.45,
		MaxTargetsPerCast = 1,
		HitInterval = 0.2,
		IgnoreSameTeam = true,
		RequireLineOfSight = false,
		ServerRecast = true,
		MinFacingDot = -0.2,
	}, stepConfig or {})

	for key, value in pairs(extra or {}) do
		config[key] = value
	end

	return config
end

function CombatConfig.GetCharacterName(subject)
	return getCharacterName(subject)
end

function CombatConfig.GetForCharacter(characterName)
	local character = CharacterRegistry:getCharacter(characterName)
	return deepMerge(DEFAULT, character and character.Combat or {})
end

function CombatConfig.GetForSubject(subject)
	return CombatConfig.GetForCharacter(getCharacterName(subject))
end

function CombatConfig.GetM1Step(subject, comboIndex, variantName)
	local combat = CombatConfig.GetForSubject(subject)
	return getStep(combat.M1, comboIndex, variantName)
end

function CombatConfig.GetDash(subject, direction)
	local combat = CombatConfig.GetForSubject(subject)
	local dash = combat.Dash

	if direction == "Forward" then
		return deepCopy(dash.Forward)
	end

	if direction == "Back" then
		return deepMerge(dash.Side, dash.Back)
	end

	return deepCopy(dash.Side)
end

function CombatConfig.GetBlock(subject)
	return deepCopy(CombatConfig.GetForSubject(subject).Block)
end

function CombatConfig.GetEvasive(subject)
	return deepCopy(CombatConfig.GetForSubject(subject).Evasive)
end

function CombatConfig.GetM1SkillConfig(subject, payload)
	local combat = CombatConfig.GetForSubject(subject)
	local step = getStep(combat.M1, payload and payload.ComboIndex, payload and payload.ComboVariant)

	return buildSkillConfig(step, {
		CombatKind = "M1",
		SkillName = combat.M1.SkillName or "CombatM1",
		ComboIndex = payload and payload.ComboIndex,
		ComboVariant = payload and payload.ComboVariant,
	})
end

function CombatConfig.GetForwardDashSkillConfig(subject)
	local dash = CombatConfig.GetDash(subject, "Forward")

	return buildSkillConfig(dash, {
		CombatKind = "ForwardDash",
		SkillName = dash.SkillName or "CombatForwardDash",
		CastWindow = dash.Duration or 0.45,
	})
end

return CombatConfig