-- @ScriptType: Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerModules = ServerScriptService:WaitForChild("ServerModules")
local ServerHitboxValidator = require(ServerModules:WaitForChild("ServerHitboxValidator"))

local CharacterRegistry = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("CharacterRegistry"))

local function getCurrentCharacterName(player: Player)
	return player:GetAttribute("CurrentCharacter")
		or player:GetAttribute("Character")
		or player:GetAttribute("SelectedCharacter")
		or "Ichigo"
end

local function characterHasSkill(player: Player, skillName: string)
	local characterName = getCurrentCharacterName(player)
	local characterData = CharacterRegistry:getCharacter(characterName)
	if not characterData or not characterData.Moveset then
		return false
	end

	for _, move in pairs(characterData.Moveset) do
		if move.Skill == skillName or move.SkillName == skillName then
			return true
		end

		for _, variant in ipairs(move.Variants or {}) do
			if variant.Skill == skillName or variant.SkillName == skillName then
				return true
			end
		end
	end

	return false
end

local validator = ServerHitboxValidator.new({
	Debug = true,
	MaxReportsPerWindow = 35,
	DefaultLeeway = 5,
	DefaultCastWindow = 1.25,
	DefaultMaxTargetsPerCast = 12,

	OnParried = function(result)
		print(`{result.ParryPlayer.Name} parried {result.OriginalAttacker.Name}'s {result.Skill}`)
	end,

	OnParriedProjectile = function(result)
		print(`{result.ParryPlayer.Name} parried a projectile from {result.OriginalAttacker.Name}`)
	end,

	OnProjectileReflected = function(result)
		print(`{result.ParryPlayer.Name} reflected {result.OriginalAttacker.Name}'s projectile`)
	end,

	CanUseSkill = function(player, skillName)
		return characterHasSkill(player, skillName)
	end,

	Skills = {
		GetsugaTensho = {
			Shape = "Box",
			Size = Vector3.new(7, 5, 8),
			Offset = CFrame.new(0, 0, -4),
			Cooldown = 5,
			CastWindow = 0.4,
			MaxTargetsPerCast = 5,
			HitInterval = 0.2,
			IgnoreSameTeam = true,
			RequireLineOfSight = false,
			MinFacingDot = -0.15,
			Parryable = true,

			OnValidatedHit = function(result)
				result.TargetHumanoid:TakeDamage(12)
			end,
		},

		GetsugaTenshoAir = {
			Shape = "Sphere",
			Radius = 5,
			MaxDistance = 16,
			Cooldown = 6,
			CastWindow = 0.5,
			MaxTargetsPerCast = 5,
			HitInterval = 0.2,
			IgnoreSameTeam = true,
			RequireLineOfSight = false,
			Parryable = true,

			OnValidatedHit = function(result)
				result.TargetHumanoid:TakeDamage(14)
			end,
		},

		ParryCounter = {
			Shape = "Box",
			Size = Vector3.new(8, 6, 8),
			Offset = CFrame.new(0, 0, -3),
			MaxDistance = 12,
			Cooldown = 1.4,
			CastWindow = 0.5,
			ServerRecast = false,
			IgnoreSameTeam = true,

			Parry = {
				Enabled = true,
				Window = 0.35,
				ReflectProjectiles = true,
				ProjectileParryDistance = 14,
			},
		},

		ExampleProjectile = {
			Shape = "Sphere",
			Radius = 2.5,
			MaxDistance = 185,
			Cooldown = 3,
			CastWindow = 3,
			MaxTargetsPerCast = 1,
			Projectile = true,
			IgnoreSameTeam = true,
			RequireLineOfSight = true,
			ServerRecast = false,
			Parryable = true,
			ReflectedProjectileLifetime = 4,

			OnValidatedHit = function(result)
				result.TargetHumanoid:TakeDamage(10)
			end,
		},
	},
})

validator:Start()