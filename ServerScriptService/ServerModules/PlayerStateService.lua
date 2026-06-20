-- @ScriptType: ModuleScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalModules = ReplicatedStorage:WaitForChild("GlobalModules")
local PlayerStateMachine = require(GlobalModules:WaitForChild("PlayerStateMachine"))

local PlayerStateService = {}

PlayerStateService.Machines = {}
PlayerStateService.Connections = {}
PlayerStateService.CharacterConnections = {}
PlayerStateService.Initialized = false
PlayerStateService.StateRequest = nil
PlayerStateService.StateChanged = nil

PlayerStateService.Movement = {
	ApplyMovementLocks = true,
	DefaultWalkSpeed = 16,
	DefaultJumpPower = 50,
	BlockingWalkSpeed = 8,
	BusyWalkSpeed = 6,
	LockedWalkSpeed = 0,
	LockedJumpPower = 0,
}

local AIR_STATES = {
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Jumping] = true,
}

local LAND_STATES = {
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
}

local function isPlayer(subject)
	return typeof(subject) == "Instance" and subject:IsA("Player")
end

local function isCharacterModel(subject)
	return typeof(subject) == "Instance" and subject:IsA("Model")
end

local function getCharacter(subject)
	if isPlayer(subject) then
		return subject.Character
	end

	if isCharacterModel(subject) then
		return subject
	end

	return nil
end

local function getPlayer(subject)
	if isPlayer(subject) then
		return subject
	end

	if isCharacterModel(subject) then
		return Players:GetPlayerFromCharacter(subject)
	end

	return nil
end

local function getHumanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid")
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

local function disconnectAll(connections)
	for _, connection in ipairs(connections or {}) do
		connection:Disconnect()
	end

	table.clear(connections)
end

function PlayerStateService:Init(config)
	if self.Initialized then
		return self
	end

	self.Initialized = true

	if config and config.Movement then
		for key, value in pairs(config.Movement) do
			self.Movement[key] = value
		end
	end

	self.StateRequest = getOrCreateRemote("StateRequest")
	self.StateChanged = getOrCreateRemote("StateChanged")

	self.StateRequest.OnServerEvent:Connect(function(player, payload)
		self:HandleClientRequest(player, payload)
	end)

	Players.PlayerAdded:Connect(function(player)
		self:SetupPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:CleanupSubject(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:SetupPlayer(player)
	end

	return self
end

function PlayerStateService:SetupSubject(subject, options)
	if not subject or self.Machines[subject] then
		return self.Machines[subject]
	end

	options = options or {}

	local character = options.Character or getCharacter(subject)
	local machine = PlayerStateMachine.new(subject, {
		Character = character,
		Replicate = options.Replicate ~= false,
		StateDefinitions = options.StateDefinitions,
		ActionDefinitions = options.ActionDefinitions,
		ReplicatedStates = options.ReplicatedStates,
	})

	self.Machines[subject] = machine
	self.Connections[subject] = {}
	self.CharacterConnections[subject] = {}

	table.insert(self.Connections[subject], machine:OnChanged(function(snapshot, stateName, reason)
		local player = getPlayer(subject)
		if player and self.StateChanged then
			self.StateChanged:FireClient(player, snapshot, stateName, reason)
		end

		self:ApplyMovement(subject)
	end))

	if isPlayer(subject) then
		table.insert(self.Connections[subject], subject.CharacterAdded:Connect(function(newCharacter)
			self:BindCharacter(subject, newCharacter)
		end))
	elseif isCharacterModel(subject) then
		table.insert(self.Connections[subject], subject.Destroying:Connect(function()
			self:CleanupSubject(subject)
		end))
	end

	if character then
		self:BindCharacter(subject, character)
	end

	return machine
end

function PlayerStateService:SetupPlayer(player, options)
	return self:SetupSubject(player, options)
end

function PlayerStateService:SetupNPC(character, options)
	return self:SetupSubject(character, options)
end

function PlayerStateService:CleanupSubject(subject)
	local machine = self.Machines[subject]
	if machine then
		machine:Destroy()
	end

	disconnectAll(self.Connections[subject])
	disconnectAll(self.CharacterConnections[subject])

	self.Connections[subject] = nil
	self.CharacterConnections[subject] = nil
	self.Machines[subject] = nil
end

function PlayerStateService:CleanupPlayer(player)
	self:CleanupSubject(player)
end

function PlayerStateService:CleanupNPC(character)
	self:CleanupSubject(character)
end

function PlayerStateService:BindCharacter(subject, character)
	local machine = self:GetMachine(subject)
	if not machine then
		return
	end

	disconnectAll(self.CharacterConnections[subject])
	self.CharacterConnections[subject] = {}

	machine:BindCharacter(character)
	machine:ClearTransientStates()
	machine:SetDead(false)
	machine:AddState("Spawning", {
		Duration = 0.35,
		Force = true,
		Source = "CharacterAdded",
	})

	local humanoid = getHumanoid(character)
	if not humanoid then
		return
	end

	humanoid:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
	humanoid:SetAttribute("BaseJumpPower", humanoid.JumpPower)
	humanoid:SetAttribute("BaseJumpHeight", humanoid.JumpHeight)

	table.insert(self.CharacterConnections[subject], humanoid.Died:Connect(function()
		machine:ClearStates()
		machine:SetDead(true)
		self:ApplyMovement(subject)
	end))

	table.insert(self.CharacterConnections[subject], humanoid.StateChanged:Connect(function(_, newState)
		if AIR_STATES[newState] then
			machine:SetAirborne(true, {
				HumanoidState = newState.Name,
			})
		elseif LAND_STATES[newState] then
			machine:SetAirborne(false)
		end
	end))

	self:ApplyMovement(subject)
end

function PlayerStateService:GetSubjectFromCharacter(character)
	return Players:GetPlayerFromCharacter(character) or character
end

function PlayerStateService:GetMachine(subject)
	if not subject then
		return nil
	end

	if self.Machines[subject] then
		return self.Machines[subject]
	end

	if isPlayer(subject) then
		return self:SetupPlayer(subject)
	end

	if isCharacterModel(subject) then
		return self:SetupNPC(subject)
	end

	return nil
end

function PlayerStateService:GetSnapshot(subject)
	local machine = self:GetMachine(subject)
	return machine and machine:GetSnapshot() or nil
end

function PlayerStateService:HasState(subject, stateName)
	local machine = self:GetMachine(subject)
	return machine and machine:HasState(stateName) or false
end

function PlayerStateService:Can(subject, actionName, context)
	local machine = self:GetMachine(subject)
	if not machine then
		return false, "missing_state_machine"
	end

	return machine:Can(actionName, context)
end

function PlayerStateService:CanUseSkill(subject, skillName, context)
	context = context or {}
	context.Skill = skillName
	context.SkillName = skillName
	context.AllowSameSkill = true

	local machine = self:GetMachine(subject)
	if not machine then
		return false, "missing_state_machine"
	end

	if machine:IsCurrentSkill(skillName, context.CastId) then
		return true
	end

	return machine:Can("Skill", context)
end

function PlayerStateService:IsCurrentSkill(subject, skillName, castId)
	local machine = self:GetMachine(subject)
	return machine and machine:IsCurrentSkill(skillName, castId) or false
end

function PlayerStateService:AddState(subject, stateName, options)
	local machine = self:GetMachine(subject)
	return machine:AddState(stateName, options)
end

function PlayerStateService:RemoveState(subject, stateName, reason)
	local machine = self:GetMachine(subject)
	return machine:RemoveState(stateName, reason)
end

function PlayerStateService:SetBlocking(subject, active, data)
	local machine = self:GetMachine(subject)
	return machine:SetBlocking(active, data)
end

function PlayerStateService:SetSprinting(subject, active, data)
	local machine = self:GetMachine(subject)
	return machine:SetSprinting(active, data)
end

function PlayerStateService:Stun(subject, duration, data)
	local machine = self:GetMachine(subject)
	return machine:Stun(duration, data)
end

function PlayerStateService:GuardBreak(subject, duration, data)
	local machine = self:GetMachine(subject)
	return machine:GuardBreak(duration, data)
end

function PlayerStateService:StartAttack(subject, moveId, duration, data)
	local machine = self:GetMachine(subject)
	return machine:StartAttack(moveId, duration, data)
end

function PlayerStateService:StartSkill(subject, skillName, duration, data)
	local machine = self:GetMachine(subject)
	return machine:StartSkill(skillName, duration, data)
end

function PlayerStateService:EndSkill(subject, skillName, castId)
	local machine = self:GetMachine(subject)
	return machine:EndSkill(skillName, castId)
end

function PlayerStateService:SetMoveParry(subject, active, duration, data)
	local machine = self:GetMachine(subject)
	return machine:SetMoveParry(active, duration, data)
end

function PlayerStateService:SetParrying(subject, active, duration, data)
	return self:SetMoveParry(subject, active, duration, data)
end

function PlayerStateService:SetDashing(subject, active, duration, data)
	local machine = self:GetMachine(subject)
	return machine:SetDashing(active, duration, data)
end

function PlayerStateService:SetIFrames(subject, active, duration, data)
	local machine = self:GetMachine(subject)
	return machine:SetIFrames(active, duration, data)
end

function PlayerStateService:SetSuperArmor(subject, active, duration, data)
	local machine = self:GetMachine(subject)
	return machine:SetSuperArmor(active, duration, data)
end

function PlayerStateService:SetRagdolled(subject, active, duration, data)
	local machine = self:GetMachine(subject)
	return machine:SetRagdolled(active, duration, data)
end

function PlayerStateService:HandleClientRequest(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	local action = payload.Action

	if action == "SetBlocking" then
		local active = payload.Active == true

		if active then
			local canBlock = self:Can(player, "Block")
			if canBlock then
				self:SetBlocking(player, true, {
					Source = "Client",
				})
			end
		else
			self:SetBlocking(player, false)
		end

		return
	end

	if action == "SetSprinting" then
		local active = payload.Active == true

		if active then
			local canSprint = self:Can(player, "Sprint")
			if canSprint then
				self:SetSprinting(player, true, {
					Source = "Client",
				})
			end
		else
			self:SetSprinting(player, false)
		end
	end
end

function PlayerStateService:ApplyMovement(subject)
	if not self.Movement.ApplyMovementLocks then
		return
	end

	local machine = self.Machines[subject]
	local character = getCharacter(subject)
	local humanoid = getHumanoid(character)
	if not machine or not humanoid then
		return
	end

	local baseWalkSpeed = humanoid:GetAttribute("BaseWalkSpeed") or self.Movement.DefaultWalkSpeed
	local baseJumpPower = humanoid:GetAttribute("BaseJumpPower") or self.Movement.DefaultJumpPower
	local baseJumpHeight = humanoid:GetAttribute("BaseJumpHeight") or humanoid.JumpHeight
	local walkSpeed = baseWalkSpeed
	local jumpPower = baseJumpPower
	local jumpHeight = baseJumpHeight

	if machine:HasState("Dead") or machine:HasState("Frozen") or machine:HasState("Ragdolled") or machine:HasState("Stunned") or machine:HasState("GuardBroken") then
		walkSpeed = self.Movement.LockedWalkSpeed
		jumpPower = self.Movement.LockedJumpPower
		jumpHeight = 0
	elseif machine:HasState("UsingSkill") or machine:HasState("Attacking") or machine:HasState("MoveParry") then
		walkSpeed = self.Movement.BusyWalkSpeed
	elseif machine:HasState("Blocking") then
		walkSpeed = self.Movement.BlockingWalkSpeed
	end

	humanoid.WalkSpeed = walkSpeed

	if humanoid.UseJumpPower ~= false then
		humanoid.JumpPower = jumpPower
	else
		humanoid.JumpHeight = jumpHeight
	end
end

return PlayerStateService