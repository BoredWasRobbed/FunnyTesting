-- @ScriptType: Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerModules = ServerScriptService:WaitForChild("ServerModules")
local CombatDamageService = require(ServerModules:WaitForChild("CombatDamageService"))
local CombatService = require(ServerModules:WaitForChild("CombatService"))
local PlayerStateService = require(ServerModules:WaitForChild("PlayerStateService"))
local ServerHitboxValidator = require(ServerModules:WaitForChild("ServerHitboxValidator"))

local CharacterRegistry = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("CharacterRegistry"))

CombatService:Init()
PlayerStateService:Init()

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

local function getSubjectName(subject)
	return subject and subject.Name or "Unknown"
end

local skillConfigs = {
	GetsugaTensho = {
		Shape = "Box",
		Size = Vector3.new(7, 5, 8),
		Offset = CFrame.new(0, 0, -4),
		Damage = 12,
		Cooldown = 5,
		CastWindow = 0.4,
		StateDuration = 0.45,
		MaxTargetsPerCast = 5,
		HitInterval = 0.2,
		IgnoreSameTeam = true,
		RequireLineOfSight = false,
		MinFacingDot = -0.15,
		HitStun = 0.25,
		Knockback = { Force = 28, Up = 4 },
		Parryable = true,
	},

	GetsugaTenshoAir = {
		Shape = "Sphere",
		Radius = 5,
		MaxDistance = 16,
		Damage = 14,
		Cooldown = 6,
		CastWindow = 0.5,
		StateDuration = 0.45,
		MaxTargetsPerCast = 5,
		HitInterval = 0.2,
		IgnoreSameTeam = true,
		RequireLineOfSight = false,
		HitStun = 0.3,
		Knockback = { Force = 30, Up = -18 },
		Parryable = true,
	},

	ParryCounter = {
		Shape = "Box",
		Size = Vector3.new(8, 6, 8),
		Offset = CFrame.new(0, 0, -3),
		MaxDistance = 12,
		Cooldown = 1.4,
		CastWindow = 0.5,
		StateDuration = 0.35,
		ServerRecast = false,
		IgnoreSameTeam = true,

		MoveParry = {
			Enabled = true,
			Window = 0.35,
			ReflectProjectiles = true,
			ProjectileParryDistance = 14,
		},
	},

	ExampleProjectileSkill = {
		Shape = "Sphere",
		Radius = 2.5,
		MaxDistance = 185,
		Damage = 10,
		Cooldown = 3,
		CastWindow = 3,
		StateDuration = 0.35,
		MaxTargetsPerCast = 1,
		Projectile = true,
		IgnoreSameTeam = true,
		RequireLineOfSight = true,
		ServerRecast = false,
		Parryable = true,
		ReflectedProjectileLifetime = 4,
	},
}

local validator = ServerHitboxValidator.new({
	Debug = true,
	MaxReportsPerWindow = 35,
	DefaultLeeway = 5,
	DefaultCastWindow = 1.25,
	DefaultMaxTargetsPerCast = 12,

	OnParried = function(result)
		print(`{getSubjectName(result.ParrySubject)} move-parried {getSubjectName(result.OriginalAttacker)}'s {result.Skill}`)
	end,

	OnParriedProjectile = function(result)
		local remaining = result.Parry and math.max(result.Parry.ExpiresAt - os.clock(), 0.05) or 0.1
		PlayerStateService:SetMoveParry(result.ParrySubject, true, remaining, {
			Skill = result.Skill,
			SkillName = result.Skill,
			CastId = result.Payload and result.Payload.CastId,
			Source = "HitboxValidator",
			Force = true,
		})

		print(`{getSubjectName(result.ParrySubject)} move-parried a projectile from {getSubjectName(result.OriginalAttacker)}`)
	end,

	OnProjectileReflected = function(result)
		print(`{getSubjectName(result.ParrySubject)} reflected {getSubjectName(result.OriginalAttacker)}'s projectile`)
	end,

	GetSkillConfig = function(player, skillName, payload)
		local combatSkillConfig = CombatService:GetCombatSkillConfig(player, skillName, payload)
		if combatSkillConfig then
			return combatSkillConfig
		end

		return skillConfigs[skillName]
	end,

	CanUseSkill = function(player, skillName, payload)
		local combatCanUse = CombatService:CanUseSkill(player, skillName, payload)
		if combatCanUse ~= nil then
			return combatCanUse
		end

		if not characterHasSkill(player, skillName) then
			return false
		end

		if PlayerStateService:IsCurrentSkill(player, skillName, payload and payload.CastId) then
			return true
		end

		return PlayerStateService:CanUseSkill(player, skillName, {
			CastId = payload and payload.CastId,
		})
	end,

	OnValidatedStart = function(result)
		if CombatService:OnValidatedStart(result) then
			return
		end

		local payload = result.Payload or {}
		local duration = result.Config.StateDuration or result.Config.CastWindow or 0.35

		PlayerStateService:StartSkill(result.Attacker, result.Skill, duration, {
			Skill = result.Skill,
			SkillName = result.Skill,
			CastId = payload.CastId,
			IsProjectile = result.Config.Projectile == true,
			Source = "HitboxValidator",
		})

		if result.Parry then
			local remaining = math.max(result.Parry.ExpiresAt - os.clock(), 0.05)
			PlayerStateService:SetMoveParry(result.Attacker, true, remaining, {
				Skill = result.Skill,
				SkillName = result.Skill,
				CastId = payload.CastId,
				Source = "HitboxValidator",
				Force = true,
			})
		end
	end,

	OnValidatedHit = function(result)
		CombatDamageService:ApplyHit(result)
	end,

	Skills = skillConfigs,
})

validator:Start()