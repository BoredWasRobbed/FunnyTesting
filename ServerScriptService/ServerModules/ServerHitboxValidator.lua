-- @ScriptType: ModuleScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerHitboxValidator = {}
ServerHitboxValidator.__index = ServerHitboxValidator

local DEFAULTS = {
	RemoteName = "HitboxReport",
	Debug = false,
	RateLimitWindow = 1,
	MaxReportsPerWindow = 35,
	DefaultLeeway = 5,
	DefaultCooldown = 0,
	DefaultHitInterval = 0.25,
	DefaultCastWindow = 1.25,
	DefaultMaxTargetsPerCast = 12,
}

local function mergeConfig(config)
	local merged = {}

	for key, value in pairs(DEFAULTS) do
		merged[key] = value
	end

	for key, value in pairs(config or {}) do
		merged[key] = value
	end

	return merged
end

local function getOrCreateRemote(remoteName)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild(remoteName)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = remotes
	end

	return remote
end

local function getHumanoid(model)
	return model and model:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(model)
	if not model then
		return nil
	end

	return model:FindFirstChild("HumanoidRootPart")
		or model.PrimaryPart
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("UpperTorso")
end

local function getModelFromPayloadTarget(target)
	if typeof(target) ~= "Instance" then
		return nil
	end

	if target:IsA("Model") then
		return target
	end

	if target:IsA("BasePart") then
		return target:FindFirstAncestorOfClass("Model")
	end

	if target:IsA("Humanoid") then
		return target.Parent
	end

	return nil
end

local function getReportedPart(payload, targetModel)
	local part = payload.Part
	if typeof(part) == "Instance" and part:IsA("BasePart") and part:IsDescendantOf(targetModel) then
		return part
	end

	return getRootPart(targetModel)
end

local function getSkillName(payload)
	if typeof(payload) ~= "table" then
		return nil
	end

	local skillName = payload.Skill or payload.SkillName or payload.MoveId
	if type(skillName) ~= "string" then
		return nil
	end

	if #skillName <= 0 or #skillName > 80 then
		return nil
	end

	return skillName
end

local function asArray(value)
	if value == nil then
		return {}
	end

	if typeof(value) == "table" then
		return value
	end

	return { value }
end

local function isSameTeam(attacker, targetModel)
	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	return targetPlayer and attacker.Team ~= nil and targetPlayer.Team == attacker.Team
end

local function getReach(skillConfig, config)
	if skillConfig.MaxDistance then
		return skillConfig.MaxDistance
	end

	local leeway = skillConfig.Leeway or config.DefaultLeeway
	local offsetDistance = 0

	if skillConfig.Offset then
		offsetDistance = skillConfig.Offset.Position.Magnitude
	end

	local shape = string.lower(skillConfig.Shape or "Box")
	if shape == "sphere" or shape == "radius" then
		return offsetDistance + (skillConfig.Radius or 4) + leeway
	end

	return offsetDistance + ((skillConfig.Size or Vector3.new(4, 4, 4)).Magnitude / 2) + leeway
end

local function getOverlapParams(attackerCharacter, skillConfig)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local ignored = { attackerCharacter }
	for _, instance in ipairs(asArray(skillConfig.Ignore)) do
		table.insert(ignored, instance)
	end

	params.FilterDescendantsInstances = ignored

	if skillConfig.CollisionGroup then
		params.CollisionGroup = skillConfig.CollisionGroup
	end

	return params
end

local function inflateSize(size, leeway)
	return size + Vector3.new(leeway * 2, leeway * 2, leeway * 2)
end

function ServerHitboxValidator.new(config)
	local self = setmetatable({}, ServerHitboxValidator)

	self.Config = mergeConfig(config)
	self.Remote = getOrCreateRemote(self.Config.RemoteName)
	self.Connection = nil
	self.Skills = {}
	self.RateWindows = {}
	self.Cooldowns = {}
	self.ActiveCasts = {}
	self.TargetIntervals = {}

	if self.Config.Skills then
		self:RegisterSkills(self.Config.Skills)
	end

	Players.PlayerRemoving:Connect(function(player)
		self.RateWindows[player] = nil
		self.Cooldowns[player] = nil
		self.ActiveCasts[player] = nil
		self.TargetIntervals[player] = nil
	end)

	return self
end

function ServerHitboxValidator:RegisterSkill(skillName, skillConfig)
	self.Skills[skillName] = skillConfig or {}
	return self
end

function ServerHitboxValidator:RegisterSkills(skills)
	for skillName, skillConfig in pairs(skills) do
		self:RegisterSkill(skillName, skillConfig)
	end

	return self
end

function ServerHitboxValidator:Reject(player, reason, payload, skillConfig)
	if self.Config.Debug or (skillConfig and skillConfig.Debug) then
		warn(`Rejected hitbox report from {player.Name}: {reason}`)
	end

	if self.Config.OnRejected then
		self.Config.OnRejected(player, reason, payload, skillConfig)
	end

	return false, reason
end

function ServerHitboxValidator:CheckRateLimit(player, payload)
	local now = os.clock()
	local window = self.RateWindows[player]

	if not window or now - window.Start >= self.Config.RateLimitWindow then
		window = {
			Start = now,
			Count = 0,
		}
		self.RateWindows[player] = window
	end

	window.Count += 1

	if window.Count > self.Config.MaxReportsPerWindow then
		return self:Reject(player, "rate_limited", payload)
	end

	return true
end

function ServerHitboxValidator:GetSkillConfig(player, skillName, payload)
	if self.Config.GetSkillConfig then
		return self.Config.GetSkillConfig(player, skillName, payload)
	end

	return self.Skills[skillName]
end

function ServerHitboxValidator:CheckCastAndCooldown(player, skillName, targetModel, skillConfig, payload)
	local now = os.clock()
	local castId = payload.CastId
	if type(castId) ~= "string" or #castId <= 0 or #castId > 80 then
		return self:Reject(player, "bad_cast_id", payload, skillConfig)
	end

	local perPlayerCasts = self.ActiveCasts[player]
	if not perPlayerCasts then
		perPlayerCasts = {}
		self.ActiveCasts[player] = perPlayerCasts
	end

	local perSkillCasts = perPlayerCasts[skillName]
	if not perSkillCasts then
		perSkillCasts = {}
		perPlayerCasts[skillName] = perSkillCasts
	end

	for existingCastId, cast in pairs(perSkillCasts) do
		if now - cast.StartedAt > (skillConfig.CastWindow or self.Config.DefaultCastWindow) then
			perSkillCasts[existingCastId] = nil
		end
	end

	local cast = perSkillCasts[castId]
	if cast then
		if now - cast.StartedAt > (skillConfig.CastWindow or self.Config.DefaultCastWindow) then
			perSkillCasts[castId] = nil
			return self:Reject(player, "expired_cast", payload, skillConfig)
		end

		if cast.Targets[targetModel] then
			return self:Reject(player, "duplicate_cast_target", payload, skillConfig)
		end

		if cast.HitCount >= (skillConfig.MaxTargetsPerCast or self.Config.DefaultMaxTargetsPerCast) then
			return self:Reject(player, "cast_target_limit", payload, skillConfig)
		end

		cast.Targets[targetModel] = true
		cast.HitCount += 1
		return true
	end

	local cooldowns = self.Cooldowns[player]
	if not cooldowns then
		cooldowns = {}
		self.Cooldowns[player] = cooldowns
	end

	if cooldowns[skillName] and cooldowns[skillName] > now then
		return self:Reject(player, "cooldown", payload, skillConfig)
	end

	local cooldown = skillConfig.ServerCooldown or skillConfig.Cooldown or self.Config.DefaultCooldown
	if cooldown > 0 then
		cooldowns[skillName] = now + cooldown
	end

	perSkillCasts[castId] = {
		StartedAt = now,
		HitCount = 1,
		Targets = {
			[targetModel] = true,
		},
	}

	return true
end

function ServerHitboxValidator:CheckTargetInterval(player, skillName, targetModel, skillConfig, payload)
	local now = os.clock()
	local perPlayer = self.TargetIntervals[player]
	if not perPlayer then
		perPlayer = {}
		self.TargetIntervals[player] = perPlayer
	end

	local perSkill = perPlayer[skillName]
	if not perSkill then
		perSkill = {}
		perPlayer[skillName] = perSkill
	end

	local lastHitTime = perSkill[targetModel]
	local interval = skillConfig.HitInterval or self.Config.DefaultHitInterval

	if lastHitTime and now - lastHitTime < interval then
		return self:Reject(player, "target_interval", payload, skillConfig)
	end

	perSkill[targetModel] = now
	return true
end

function ServerHitboxValidator:CheckLineOfSight(attackerCharacter, attackerRoot, targetModel, targetRoot, skillConfig, payload)
	if not skillConfig.RequireLineOfSight then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attackerCharacter }

	local direction = targetRoot.Position - attackerRoot.Position
	local result = workspace:Raycast(attackerRoot.Position, direction, params)

	if result and not result.Instance:IsDescendantOf(targetModel) then
		return false, "line_of_sight"
	end

	return true
end

function ServerHitboxValidator:CheckFacing(attackerRoot, targetRoot, skillConfig)
	if not skillConfig.MinFacingDot then
		return true
	end

	local toTarget = targetRoot.Position - attackerRoot.Position
	if toTarget.Magnitude <= 0 then
		return true
	end

	return attackerRoot.CFrame.LookVector:Dot(toTarget.Unit) >= skillConfig.MinFacingDot
end

function ServerHitboxValidator:CheckServerOverlap(attackerCharacter, attackerRoot, targetModel, skillConfig)
	if skillConfig.ServerRecast == false or skillConfig.Projectile then
		return true
	end

	local leeway = skillConfig.Leeway or self.Config.DefaultLeeway
	local offset = skillConfig.Offset or CFrame.new()
	local cframe = attackerRoot.CFrame * offset
	local shape = string.lower(skillConfig.Shape or "Box")
	local params = getOverlapParams(attackerCharacter, skillConfig)
	local parts

	if shape == "sphere" or shape == "radius" then
		parts = workspace:GetPartBoundsInRadius(cframe.Position, (skillConfig.Radius or 4) + leeway, params)
	else
		parts = workspace:GetPartBoundsInBox(cframe, inflateSize(skillConfig.Size or Vector3.new(4, 4, 4), leeway), params)
	end

	for _, part in ipairs(parts) do
		if part:IsDescendantOf(targetModel) then
			return true
		end
	end

	return false
end

function ServerHitboxValidator:Validate(player, payload)
	if typeof(payload) ~= "table" then
		return self:Reject(player, "bad_payload", payload)
	end

	if not self:CheckRateLimit(player, payload) then
		return false
	end

	local skillName = getSkillName(payload)
	if not skillName then
		return self:Reject(player, "bad_skill", payload)
	end

	local skillConfig = self:GetSkillConfig(player, skillName, payload)
	if not skillConfig then
		return self:Reject(player, "unregistered_skill", payload)
	end

	if self.Config.CanUseSkill and self.Config.CanUseSkill(player, skillName, payload, skillConfig) == false then
		return self:Reject(player, "skill_not_allowed", payload, skillConfig)
	end

	if skillConfig.CanUseSkill and skillConfig.CanUseSkill(player, skillName, payload, skillConfig) == false then
		return self:Reject(player, "skill_config_rejected", payload, skillConfig)
	end

	local attackerCharacter = player.Character
	local attackerHumanoid = getHumanoid(attackerCharacter)
	local attackerRoot = getRootPart(attackerCharacter)

	if not attackerCharacter or not attackerHumanoid or not attackerRoot or attackerHumanoid.Health <= 0 then
		return self:Reject(player, "bad_attacker", payload, skillConfig)
	end

	local targetModel = getModelFromPayloadTarget(payload.Target)
	local targetHumanoid = getHumanoid(targetModel)
	local targetRoot = getRootPart(targetModel)
	local reportedPart = getReportedPart(payload, targetModel)

	if not targetModel or not targetHumanoid or not targetRoot or targetHumanoid.Health <= 0 then
		return self:Reject(player, "bad_target", payload, skillConfig)
	end

	if reportedPart and not reportedPart:IsDescendantOf(targetModel) then
		return self:Reject(player, "bad_part", payload, skillConfig)
	end

	if not skillConfig.CanHitSelf and targetModel == attackerCharacter then
		return self:Reject(player, "self_hit", payload, skillConfig)
	end

	if skillConfig.IgnoreSameTeam and isSameTeam(player, targetModel) then
		return self:Reject(player, "same_team", payload, skillConfig)
	end

	local distance = (attackerRoot.Position - targetRoot.Position).Magnitude
	if distance > getReach(skillConfig, self.Config) then
		return self:Reject(player, "too_far", payload, skillConfig)
	end

	if not self:CheckFacing(attackerRoot, targetRoot, skillConfig) then
		return self:Reject(player, "bad_facing", payload, skillConfig)
	end

	local losOk, losReason = self:CheckLineOfSight(attackerCharacter, attackerRoot, targetModel, targetRoot, skillConfig, payload)
	if not losOk then
		return self:Reject(player, losReason, payload, skillConfig)
	end

	if not self:CheckServerOverlap(attackerCharacter, attackerRoot, targetModel, skillConfig) then
		return self:Reject(player, "server_recast_miss", payload, skillConfig)
	end

	if skillConfig.Validate and skillConfig.Validate(player, payload, {
		Skill = skillName,
		AttackerCharacter = attackerCharacter,
		AttackerHumanoid = attackerHumanoid,
		AttackerRoot = attackerRoot,
		TargetModel = targetModel,
		TargetHumanoid = targetHumanoid,
		TargetRoot = targetRoot,
		ReportedPart = reportedPart,
		Distance = distance,
		}) == false then
		return self:Reject(player, "custom_validate", payload, skillConfig)
	end

	if not self:CheckCastAndCooldown(player, skillName, targetModel, skillConfig, payload) then
		return false
	end

	if not self:CheckTargetInterval(player, skillName, targetModel, skillConfig, payload) then
		return false
	end

	return true, {
		Skill = skillName,
		Config = skillConfig,
		Attacker = player,
		AttackerCharacter = attackerCharacter,
		AttackerHumanoid = attackerHumanoid,
		AttackerRoot = attackerRoot,
		TargetModel = targetModel,
		TargetHumanoid = targetHumanoid,
		TargetRoot = targetRoot,
		ReportedPart = reportedPart,
		Payload = payload,
		Distance = distance,
	}
end

function ServerHitboxValidator:HandleReport(player, payload)
	local ok, result = self:Validate(player, payload)
	if not ok then
		return
	end

	if result.Config.OnValidatedHit then
		result.Config.OnValidatedHit(result)
	end

	if self.Config.OnValidatedHit then
		self.Config.OnValidatedHit(result)
	end
end

function ServerHitboxValidator:Start()
	if self.Connection then
		return self
	end

	self.Connection = self.Remote.OnServerEvent:Connect(function(player, payload)
		self:HandleReport(player, payload)
	end)

	return self
end

function ServerHitboxValidator:Stop()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

return ServerHitboxValidator
