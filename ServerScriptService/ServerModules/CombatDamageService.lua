-- @ScriptType: ModuleScript
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("CombatConfig"))
local EvasiveService = require(script.Parent:WaitForChild("EvasiveService"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))

local CombatDamageService = {}

local function getSubjectFromCharacter(character)
	return Players:GetPlayerFromCharacter(character) or character
end

local function getRoot(character)
	return character and (
		character:FindFirstChild("HumanoidRootPart")
			or character.PrimaryPart
			or character:FindFirstChild("Torso")
			or character:FindFirstChild("UpperTorso")
	)
end

local function isBlocked(result, hitConfig)
	if hitConfig.BlockBypass or hitConfig.IgnoresBlock then
		return false
	end

	local targetSubject = getSubjectFromCharacter(result.TargetModel)
	if not PlayerStateService:HasState(targetSubject, "Blocking") then
		return false
	end

	local targetRoot = result.TargetRoot or getRoot(result.TargetModel)
	local attackerRoot = result.AttackerRoot or getRoot(result.AttackerCharacter)
	if not targetRoot or not attackerRoot then
		return false
	end

	local incoming = attackerRoot.Position - targetRoot.Position
	if incoming.Magnitude <= 0 then
		return true
	end

	local blockConfig = CombatConfig.GetBlock(targetSubject)
	return targetRoot.CFrame.LookVector:Dot(incoming.Unit) >= (hitConfig.BlockFrontDot or blockConfig.FrontDot or 0)
end

local function applyKnockback(result, hitConfig)
	local knockback = hitConfig.Knockback
	if not knockback then
		return
	end

	local targetRoot = result.TargetRoot or getRoot(result.TargetModel)
	local attackerRoot = result.AttackerRoot or getRoot(result.AttackerCharacter)
	if not targetRoot or not attackerRoot then
		return
	end

	local direction = targetRoot.Position - attackerRoot.Position
	if direction.Magnitude <= 0 then
		direction = attackerRoot.CFrame.LookVector
	end

	local velocity
	if typeof(knockback) == "Vector3" then
		velocity = knockback
	else
		local force = knockback.Force or knockback.Power or 0
		local up = knockback.Up or 0
		velocity = direction.Unit * force + Vector3.new(0, up, 0)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "CombatKnockbackAttachment"
	attachment.Parent = targetRoot

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "CombatKnockback"
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = knockback.MaxForce or 50000
	linearVelocity.VectorVelocity = velocity
	linearVelocity.Parent = targetRoot

	Debris:AddItem(linearVelocity, knockback.Duration or 0.16)
	Debris:AddItem(attachment, knockback.Duration or 0.16)
end

function CombatDamageService:ApplyHit(result)
	local hitConfig = result.Config or {}
	local targetSubject = getSubjectFromCharacter(result.TargetModel)

	if PlayerStateService:HasState(targetSubject, "Ragdolled") and hitConfig.HitRagdoll ~= true then
		return {
			Ignored = true,
			Reason = "target_ragdolled",
		}
	end

	if isBlocked(result, hitConfig) then
		local blockConfig = CombatConfig.GetBlock(targetSubject)
		local chipMultiplier = hitConfig.ChipMultiplier or blockConfig.ChipMultiplier or 0
		local chipDamage = math.max((hitConfig.Damage or 0) * chipMultiplier, 0)

		if chipDamage > 0 then
			result.TargetHumanoid:TakeDamage(chipDamage)
			EvasiveService:ApplyDamageGain(result.Attacker, targetSubject, chipDamage, hitConfig)
		else
			EvasiveService:Add(targetSubject, hitConfig.BlockEvasiveGain or 3)
		end

		if hitConfig.OnBlocked then
			hitConfig.OnBlocked(result, blockConfig)
		end

		if blockConfig.OnBlocked then
			blockConfig.OnBlocked(result, hitConfig)
		end

		return {
			Blocked = true,
			Damage = chipDamage,
		}
	end

	local damage = tonumber(hitConfig.Damage) or 0
	if damage > 0 then
		result.TargetHumanoid:TakeDamage(damage)
		EvasiveService:ApplyDamageGain(result.Attacker, targetSubject, damage, hitConfig)
	end

	if hitConfig.HitStun and hitConfig.HitStun > 0 then
		PlayerStateService:Stun(targetSubject, hitConfig.HitStun, {
			Source = "CombatDamageService",
			Skill = result.Skill,
		})
	end

	applyKnockback(result, hitConfig)

	local ragdoll = hitConfig.Ragdoll
	if ragdoll then
		RagdollService:Ragdoll(targetSubject, ragdoll.Duration or hitConfig.RagdollDuration or 1, {
			Source = result.Skill,
			TrueRagdoll = hitConfig.TrueRagdoll == true or ragdoll.TrueRagdoll == true,
		})
	end

	return {
		Damage = damage,
		Ragdolled = ragdoll ~= nil,
	}
end

return CombatDamageService