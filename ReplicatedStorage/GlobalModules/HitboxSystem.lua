-- @ScriptType: ModuleScript
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HitboxSystem = {}
HitboxSystem.__index = HitboxSystem

local DEFAULTS = {
	Shape = "Box",
	Size = Vector3.new(4, 4, 4),
	Radius = 4,
	Offset = CFrame.new(),
	Duration = 0.15,
	TickRate = 1 / 30,
	TargetMode = "Humanoid",
	RequireHumanoid = true,
	CanHitSelf = false,
	IgnoreSameTeam = false,
	MaxHits = nil,
	MaxTargetsPerScan = nil,
	HitInterval = nil,
	Debug = false,
	DebugColor = Color3.fromRGB(255, 60, 60),
	DebugTransparency = 0.75,
	ReportToServer = false,
	ReportStartToServer = false,
	RemoteName = "HitboxReport",
	ReflectionRemoteName = "ProjectileReflected",
	ReflectionGracePeriod = 0.75,
	MoveParry = nil,
	Parry = nil,
	Parryable = false,
}

local reportRemote = nil
local reflectionRemote = nil
local reflectionConnection = nil
local activeProjectiles = {}

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

local function asArray(value)
	if value == nil then
		return {}
	end

	if typeof(value) == "table" then
		return value
	end

	return { value }
end

local function hasAnyTag(instance, tags)
	for _, tag in ipairs(asArray(tags)) do
		if CollectionService:HasTag(instance, tag) then
			return true
		end
	end

	return false
end

local function hasAllTags(instance, tags)
	for _, tag in ipairs(asArray(tags)) do
		if not CollectionService:HasTag(instance, tag) then
			return false
		end
	end

	return true
end

local function getOwnerCharacter(owner)
	if typeof(owner) == "Instance" and owner:IsA("Player") then
		return owner.Character
	end

	if typeof(owner) == "Instance" and owner:IsA("Model") then
		return owner
	end

	return nil
end

local function getOwnerUserId(owner)
	if typeof(owner) == "Instance" and owner:IsA("Player") then
		return owner.UserId
	end

	return nil
end

local function getOwnerName(owner)
	if typeof(owner) == "Instance" then
		return owner.Name
	end

	return nil
end

local function syncProjectileOwner(part, owner)
	if not part then
		return
	end

	part:SetAttribute("ProjectileOwnerUserId", getOwnerUserId(owner))
	part:SetAttribute("ProjectileOwnerName", getOwnerName(owner))

	if typeof(owner) ~= "Instance" then
		return
	end

	local ownerValue = part:FindFirstChild("ProjectileOwner")
	if not ownerValue then
		ownerValue = Instance.new("ObjectValue")
		ownerValue.Name = "ProjectileOwner"
		ownerValue.Parent = part
	end

	if ownerValue:IsA("ObjectValue") then
		ownerValue.Value = owner
	end
end

local function getModelFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return model
	end

	return nil
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

local function getTargetPlayer(model)
	return model and Players:GetPlayerFromCharacter(model)
end

local function getInstanceCFrame(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance.CFrame
	end

	if instance:IsA("Model") then
		return instance:GetPivot()
	end

	return nil
end

local function createOverlapParams(config)
	if config.OverlapParams then
		return config.OverlapParams
	end

	local params = OverlapParams.new()
	params.FilterType = config.FilterType or Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = config.FilterDescendantsInstances or config.Ignore or {}

	if config.CollisionGroup then
		params.CollisionGroup = config.CollisionGroup
	end

	if config.MaxParts then
		params.MaxParts = config.MaxParts
	end

	return params
end

local function shouldRejectByTags(target, model, config)
	if config.RequiredTags and not hasAllTags(model or target, config.RequiredTags) then
		return true
	end

	if config.RejectedTags and hasAnyTag(model or target, config.RejectedTags) then
		return true
	end

	return false
end

local function isSameTeam(owner, targetModel)
	if not owner or not targetModel then
		return false
	end

	if typeof(owner) ~= "Instance" or not owner:IsA("Player") then
		return false
	end

	local targetPlayer = getTargetPlayer(targetModel)
	return targetPlayer and targetPlayer.Team == owner.Team
end

local function getReportRemote(remoteName)
	if reportRemote then
		return reportRemote
	end

	if not RunService:IsClient() then
		return nil
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	reportRemote = remotes:WaitForChild(remoteName or "HitboxReport")
	return reportRemote
end

local function getReflectionRemote(remoteName)
	if reflectionRemote then
		return reflectionRemote
	end

	if not RunService:IsClient() then
		return nil
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	reflectionRemote = remotes:WaitForChild(remoteName or "ProjectileReflected")
	return reflectionRemote
end

local function ensureReflectionListener(remoteName)
	if reflectionConnection or not RunService:IsClient() then
		return
	end

	local remote = getReflectionRemote(remoteName)
	if not remote then
		return
	end

	reflectionConnection = remote.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or type(payload.ProjectileId) ~= "string" then
			return
		end

		local hitbox = activeProjectiles[payload.ProjectileId]
		if hitbox then
			hitbox:Reflect(payload)
		end
	end)
end

function HitboxSystem.new(config)
	local self = setmetatable({}, HitboxSystem)

	self.Config = mergeConfig(config)
	self.OverlapParams = createOverlapParams(self.Config)
	self.Active = false
	self.Elapsed = 0
	self.Accumulator = 0
	self.TotalHits = 0
	self.HitTimes = {}
	self.DebugPart = nil
	self.Connection = nil
	self.TraveledDistance = 0
	self.CastId = self.Config.CastId or HttpService:GenerateGUID(false)
	self.ProjectileId = self.Config.ProjectileId or (self.Config.Projectile and HttpService:GenerateGUID(false)) or nil
	self.Reflected = false
	self.ReflectedOwner = nil
	self.OriginalOwner = self.Config.Owner

	if self.Config.Projectile then
		local projectile = self.Config.Projectile
		local direction = projectile.Direction or Vector3.new(0, 0, -1)
		local speed = projectile.Speed or 80

		self.CurrentCFrame = self.Config.CFrame or CFrame.new()
		self.ProjectileVelocity = projectile.Velocity or direction.Unit * speed

		if projectile.Part then
			projectile.Part:SetAttribute("ProjectileId", self.ProjectileId)
			projectile.Part:SetAttribute("ParryableProjectile", self.Config.Parryable == true or projectile.Parryable == true)
			projectile.Part:SetAttribute("ProjectileSkill", self.Config.SkillName or self.Config.Skill or self.Config.MoveId)
			syncProjectileOwner(projectile.Part, self.Config.Owner)
		end
	end

	return self
end

function HitboxSystem:GetCFrame()
	local config = self.Config

	if config.CFrameProvider then
		return config.CFrameProvider(self)
	end

	if config.Projectile then
		return self.CurrentCFrame
	end

	local attachedCFrame = getInstanceCFrame(config.AttachTo)
	if attachedCFrame then
		return attachedCFrame * config.Offset
	end

	if config.CFrame then
		return config.CFrame * config.Offset
	end

	if config.Position then
		return CFrame.new(config.Position) * config.Offset
	end

	return CFrame.new() * config.Offset
end

function HitboxSystem:GetParts()
	local config = self.Config
	local cframe = self:GetCFrame()
	local shape = string.lower(config.Shape)

	if shape == "sphere" or shape == "radius" then
		return workspace:GetPartBoundsInRadius(cframe.Position, config.Radius, self.OverlapParams)
	end

	if shape == "part" and config.Part then
		return workspace:GetPartsInPart(config.Part, self.OverlapParams)
	end

	return workspace:GetPartBoundsInBox(cframe, config.Size, self.OverlapParams)
end

function HitboxSystem:ResolveTarget(part)
	local config = self.Config

	if config.TargetMode == "Part" then
		return {
			Target = part,
			Part = part,
			Model = getModelFromPart(part),
			Humanoid = nil,
		}
	end

	local model = getModelFromPart(part)
	local humanoid = getHumanoid(model)

	if config.RequireHumanoid and not humanoid then
		return nil
	end

	if humanoid and humanoid.Health <= 0 then
		return nil
	end

	return {
		Target = config.TargetMode == "Model" and model or humanoid,
		Part = part,
		Model = model,
		Humanoid = humanoid,
	}
end

function HitboxSystem:CanHit(result)
	local config = self.Config
	local ownerCharacter = getOwnerCharacter(config.Owner)

	if not result or not result.Target then
		return false
	end

	if not config.CanHitSelf and ownerCharacter and result.Model == ownerCharacter then
		return false
	end

	if config.IgnoreSameTeam and isSameTeam(config.Owner, result.Model) then
		return false
	end

	if shouldRejectByTags(result.Target, result.Model, config) then
		return false
	end

	if config.Validate and config.Validate(result, self) == false then
		return false
	end

	return true
end

function HitboxSystem:CanTriggerTarget(targetKey)
	local config = self.Config
	local now = os.clock()
	local lastHitTime = self.HitTimes[targetKey]

	if config.HitInterval == nil and lastHitTime ~= nil then
		return false
	end

	if config.HitInterval ~= nil and lastHitTime ~= nil and now - lastHitTime < config.HitInterval then
		return false
	end

	return true
end

function HitboxSystem:ProcessHit(result)
	local targetKey = result.Model or result.Target or result.Part
	if not self:CanTriggerTarget(targetKey) then
		return false
	end

	self.HitTimes[targetKey] = os.clock()
	self.TotalHits += 1

	result.Hitbox = self
	result.CFrame = self:GetCFrame()
	result.Time = os.clock()

	if self.Config.OnHit then
		self.Config.OnHit(result, self)
	end

	if self.Config.ReportToServer then
		self:ReportHit(result)
	end

	if self.Config.StopOnHit or self.Config.StopOnFirstHit then
		self:Stop()
	end

	if self.Config.MaxHits and self.TotalHits >= self.Config.MaxHits then
		self:Stop()
	end

	return true
end

function HitboxSystem:ReportHit(result)
	local remote = getReportRemote(self.Config.RemoteName)
	if not remote then
		return
	end

	local skillName = self.Config.SkillName or self.Config.Skill or self.Config.MoveId
	if not skillName then
		warn("Hitbox report skipped because SkillName/Skill/MoveId is missing.")
		return
	end

	local reflectedOwnerUserId = typeof(self.ReflectedOwner) == "Instance" and self.ReflectedOwner:IsA("Player") and self.ReflectedOwner.UserId or nil
	local originalOwnerUserId = typeof(self.OriginalOwner) == "Instance" and self.OriginalOwner:IsA("Player") and self.OriginalOwner.UserId or nil

	remote:FireServer({
		Kind = "Hit",
		Skill = skillName,
		MoveId = self.Config.MoveId or skillName,
		CastId = self.CastId,
		Target = result.Model or result.Target,
		Part = result.Part,
		HitPosition = result.Part and result.Part.Position,
		HitboxCFrame = result.CFrame,
		ClientTime = os.clock(),
		Parryable = self.Config.Parryable == true,
		IsProjectile = self.Config.Projectile ~= nil,
		ProjectileId = self.ProjectileId,
		ProjectileSkill = skillName,
		ProjectilePart = self.Config.Projectile and self.Config.Projectile.Part or nil,
		Reflected = self.Reflected == true,
		ReflectedOwnerUserId = reflectedOwnerUserId,
		OriginalOwnerUserId = originalOwnerUserId,
	})
end

function HitboxSystem:ReportStart()
	local remote = getReportRemote(self.Config.RemoteName)
	if not remote then
		return
	end

	local skillName = self.Config.SkillName or self.Config.Skill or self.Config.MoveId
	if not skillName then
		warn("Hitbox start report skipped because SkillName/Skill/MoveId is missing.")
		return
	end

	remote:FireServer({
		Kind = "Start",
		Skill = skillName,
		MoveId = self.Config.MoveId or skillName,
		CastId = self.CastId,
		HitboxCFrame = self:GetCFrame(),
		ClientTime = os.clock(),
		ActionState = self.Config.ActionState,
		StateDuration = self.Config.StateDuration or self.Config.Duration,
		MoveParry = self.Config.MoveParry,
		Parry = self.Config.Parry,
		Parryable = self.Config.Parryable == true,
		IsProjectile = self.Config.Projectile ~= nil,
		ProjectileId = self.ProjectileId,
		ProjectilePart = self.Config.Projectile and self.Config.Projectile.Part or nil,
	})
end

function HitboxSystem:RefreshOverlapParams()
	self.OverlapParams = createOverlapParams(self.Config)
	return self
end

function HitboxSystem:SetIgnoreList(ignore)
	self.Config.Ignore = ignore or {}
	self.Config.FilterDescendantsInstances = self.Config.Ignore
	return self:RefreshOverlapParams()
end

function HitboxSystem:ConnectHeartbeat()
	if self.Connection then
		return
	end

	self.Connection = RunService.Heartbeat:Connect(function(dt)
		self:Step(dt)
	end)
end

function HitboxSystem:Reflect(reflection)
	local projectile = self.Config.Projectile
	if not projectile then
		return
	end

	self.Reflected = true
	local reflectedOwner = reflection.ParrySubject or reflection.ParryPlayer
	self.ReflectedOwner = reflectedOwner

	if reflectedOwner then
		self.Config.Owner = reflectedOwner
	end

	if projectile.RefreshIgnoreOnReflect ~= false then
		local ignore = {}
		local parryCharacter = getOwnerCharacter(reflectedOwner)

		if parryCharacter then
			table.insert(ignore, parryCharacter)
		end

		for _, instance in ipairs(asArray(projectile.ReflectIgnore)) do
			table.insert(ignore, instance)
		end

		self:SetIgnoreList(ignore)
	end

	local customVelocity
	if projectile.OnReflect then
		customVelocity = projectile.OnReflect(self, reflection)
	end

	if customVelocity == nil and self.Config.OnReflect then
		customVelocity = self.Config.OnReflect(self, reflection)
	end

	if customVelocity == false then
		return
	end

	if typeof(customVelocity) == "Vector3" then
		self.ProjectileVelocity = customVelocity
	else
		local originalRoot = getRootPart(getOwnerCharacter(reflection.OriginalAttacker))
		local speed = projectile.ReflectionSpeed or projectile.Speed or self.ProjectileVelocity.Magnitude
		speed *= projectile.ReflectionSpeedMultiplier or 1

		if originalRoot then
			local direction = originalRoot.Position - self.CurrentCFrame.Position
			if direction.Magnitude > 0 then
				self.ProjectileVelocity = direction.Unit * speed
			else
				self.ProjectileVelocity = -self.ProjectileVelocity
			end
		else
			self.ProjectileVelocity = -self.ProjectileVelocity
		end
	end

	if projectile.Part then
		projectile.Part:SetAttribute("Reflected", true)
		projectile.Part:SetAttribute("ReflectedFromUserId", getOwnerUserId(reflection.OriginalAttacker))
		projectile.Part:SetAttribute("ReflectedFromName", getOwnerName(reflection.OriginalAttacker))
		syncProjectileOwner(projectile.Part, reflectedOwner)
	end

	table.clear(self.HitTimes)
	self.Elapsed = 0
	self.Accumulator = self.Config.TickRate
	self.TraveledDistance = 0
	self.Active = true

	if self.ProjectileId then
		activeProjectiles[self.ProjectileId] = self
	end

	self:ConnectHeartbeat()

	if projectile.OnReflected then
		projectile.OnReflected(self, reflection)
	end

	if self.Config.OnReflected then
		self.Config.OnReflected(self, reflection)
	end
end

function HitboxSystem:Scan()
	local seenThisScan = {}
	local targetsHitThisScan = 0

	for _, part in ipairs(self:GetParts()) do
		if not self.Active then
			break
		end

		local result = self:ResolveTarget(part)
		if result then
			local targetKey = result.Model or result.Target or result.Part

			if not seenThisScan[targetKey] and self:CanHit(result) then
				seenThisScan[targetKey] = true

				if self:ProcessHit(result) then
					targetsHitThisScan += 1
				end

				if self.Config.MaxTargetsPerScan and targetsHitThisScan >= self.Config.MaxTargetsPerScan then
					break
				end
			end
		end
	end
end

function HitboxSystem:StepProjectile(dt)
	local projectile = self.Config.Projectile
	if not projectile then
		return
	end

	if projectile.Gravity then
		self.ProjectileVelocity += projectile.Gravity * dt
	end

	local delta = self.ProjectileVelocity * dt
	local currentPosition = self.CurrentCFrame.Position
	local nextPosition = currentPosition + delta

	self.TraveledDistance += delta.Magnitude

	if projectile.FaceDirection ~= false and self.ProjectileVelocity.Magnitude > 0 then
		self.CurrentCFrame = CFrame.lookAt(nextPosition, nextPosition + self.ProjectileVelocity.Unit)
	else
		self.CurrentCFrame = CFrame.new(nextPosition) * (self.CurrentCFrame - self.CurrentCFrame.Position)
	end

	if projectile.Part then
		projectile.Part.CFrame = self.CurrentCFrame
	end

	if projectile.OnStep then
		projectile.OnStep(self, dt)
	end

	if projectile.MaxDistance and self.TraveledDistance >= projectile.MaxDistance then
		self:Stop()
	end
end

function HitboxSystem:UpdateDebug()
	if not self.Config.Debug then
		return
	end

	if not self.DebugPart then
		local part = Instance.new("Part")
		part.Name = "ClientHitboxDebug"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Color = self.Config.DebugColor
		part.Transparency = self.Config.DebugTransparency
		part.Parent = workspace

		self.DebugPart = part
	end

	local shape = string.lower(self.Config.Shape)
	self.DebugPart.CFrame = self:GetCFrame()

	if shape == "sphere" or shape == "radius" then
		self.DebugPart.Shape = Enum.PartType.Ball
		self.DebugPart.Size = Vector3.new(self.Config.Radius * 2, self.Config.Radius * 2, self.Config.Radius * 2)
	else
		self.DebugPart.Shape = Enum.PartType.Block
		self.DebugPart.Size = self.Config.Size
	end
end

function HitboxSystem:Step(dt)
	if not self.Active then
		return
	end

	self.Elapsed += dt
	self.Accumulator += dt

	self:StepProjectile(dt)
	if not self.Active then
		return
	end

	self:UpdateDebug()

	if self.Config.OnStep then
		self.Config.OnStep(self, dt)
	end

	if self.Accumulator >= self.Config.TickRate then
		self.Accumulator = 0
		self:Scan()
	end

	if self.Config.Duration and self.Elapsed >= self.Config.Duration then
		self:Stop()
	end
end

function HitboxSystem:Start()
	if self.Active then
		return self
	end

	self.Active = true
	self.Elapsed = 0
	self.Accumulator = self.Config.ScanImmediately == false and 0 or self.Config.TickRate

	if self.Config.OnStart then
		self.Config.OnStart(self)
	end

	if self.Config.ReportToServer and (self.Config.ReportStartToServer or self.Config.MoveParry or self.Config.Parry) then
		self:ReportStart()
	end

	if self.Config.Projectile and self.ProjectileId then
		activeProjectiles[self.ProjectileId] = self
		ensureReflectionListener(self.Config.ReflectionRemoteName)
	end

	self:ConnectHeartbeat()

	return self
end

function HitboxSystem:Stop()
	if not self.Active then
		return
	end

	self.Active = false

	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	if self.DebugPart then
		self.DebugPart:Destroy()
		self.DebugPart = nil
	end

	if self.Config.OnEnded then
		self.Config.OnEnded(self)
	end

	if self.Config.Projectile and self.ProjectileId then
		local projectileId = self.ProjectileId
		local gracePeriod = self.Config.ReflectionGracePeriod

		if gracePeriod <= 0 then
			if activeProjectiles[projectileId] == self then
				activeProjectiles[projectileId] = nil
			end
		else
			task.delay(gracePeriod, function()
				if activeProjectiles[projectileId] == self and not self.Active then
					activeProjectiles[projectileId] = nil
				end
			end)
		end
	end
end

function HitboxSystem:Destroy()
	self:Stop()
	if self.ProjectileId and activeProjectiles[self.ProjectileId] == self then
		activeProjectiles[self.ProjectileId] = nil
	end

	table.clear(self.HitTimes)
end

function HitboxSystem.Create(config)
	return HitboxSystem.new(config):Start()
end

function HitboxSystem.Cast(config)
	local hitbox = HitboxSystem.new(config)
	hitbox.Active = true
	hitbox:Scan()
	hitbox:Destroy()
	return hitbox
end

function HitboxSystem.Projectile(config)
	config = config or {}
	config.Projectile = config.Projectile or {}
	return HitboxSystem.Create(config)
end

return HitboxSystem