-- @ScriptType: ModuleScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("CombatConfig"))

local EvasiveService = {}

local function getPlayer(subject)
	if typeof(subject) == "Instance" and subject:IsA("Player") then
		return subject
	end

	if typeof(subject) == "Instance" and subject:IsA("Model") then
		return Players:GetPlayerFromCharacter(subject)
	end

	return nil
end

local function getCharacter(subject)
	if typeof(subject) == "Instance" and subject:IsA("Player") then
		return subject.Character
	end

	if typeof(subject) == "Instance" and subject:IsA("Model") then
		return subject
	end

	return nil
end

local function setAttribute(subject, name, value)
	local player = getPlayer(subject)
	local character = getCharacter(subject)

	if player then
		player:SetAttribute(name, value)
	end

	if character then
		character:SetAttribute(name, value)
	end
end

function EvasiveService:GetMax(subject)
	return CombatConfig.GetEvasive(subject).Max or 100
end

function EvasiveService:Get(subject)
	local player = getPlayer(subject)
	local character = getCharacter(subject)
	local value = player and player:GetAttribute("Evasive")

	if value == nil and character then
		value = character:GetAttribute("Evasive")
	end

	return tonumber(value) or 0
end

function EvasiveService:Set(subject, value)
	local max = self:GetMax(subject)
	local clamped = math.clamp(tonumber(value) or 0, 0, max)

	setAttribute(subject, "EvasiveMax", max)
	setAttribute(subject, "Evasive", clamped)
	setAttribute(subject, "EvasiveReady", clamped >= max)

	return clamped
end

function EvasiveService:Add(subject, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return self:Get(subject)
	end

	return self:Set(subject, self:Get(subject) + amount)
end

function EvasiveService:Consume(subject, amount)
	local config = CombatConfig.GetEvasive(subject)
	amount = amount or config.ConsumeAmount or self:GetMax(subject)

	if self:Get(subject) < amount then
		return false
	end

	self:Set(subject, self:Get(subject) - amount)
	return true
end

function EvasiveService:CanEvasive(subject)
	return self:Get(subject) >= self:GetMax(subject)
end

function EvasiveService:ApplyDamageGain(attacker, target, damage, hitConfig)
	damage = tonumber(damage) or 0
	if damage <= 0 then
		return
	end

	local attackerEvasive = CombatConfig.GetEvasive(attacker)
	local targetEvasive = CombatConfig.GetEvasive(target)
	local dealGain = hitConfig.DealEvasiveGain or attackerEvasive.DealDamageGain or 0
	local takeGain = hitConfig.TakeEvasiveGain or targetEvasive.TakeDamageGain or 0

	self:Add(attacker, dealGain)
	self:Add(target, takeGain)
end

return EvasiveService