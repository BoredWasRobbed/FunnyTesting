-- @ScriptType: ModuleScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("CombatConfig"))
local EvasiveService = require(script.Parent:WaitForChild("EvasiveService"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))
local RagdollService = require(script.Parent:WaitForChild("RagdollService"))

local CombatService = {}

CombatService.Initialized = false
CombatService.Remote = nil
CombatService.ComboStates = {}
CombatService.ActiveCombatCasts = {}
CombatService.DashCooldowns = {}

local COMBAT_SKILLS = {
	CombatM1 = true,
	CombatForwardDash = true,
}

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

local function normalizeDirection(direction)
	if direction == "Left" or direction == "Right" or direction == "Back" or direction == "Forward" then
		return direction
	end

	return "Forward"
end

local function getComboLength(player)
	local combat = CombatConfig.GetForSubject(player)
	return combat.M1.MaxCombo or #(combat.M1.Steps or {})
end

local function isValidCastId(castId)
	return type(castId) == "string" and #castId > 0 and #castId <= 80
end

function CombatService:Init()
	if self.Initialized then
		return self
	end

	self.Initialized = true
	self.Remote = getOrCreateRemote("CombatRequest")

	self.Remote.OnServerEvent:Connect(function(player, payload)
		self:HandleRequest(player, payload)
	end)

	Players.PlayerAdded:Connect(function(player)
		EvasiveService:Set(player, EvasiveService:Get(player))
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.ComboStates[player] = nil
		self.DashCooldowns[player] = nil

		for castId, cast in pairs(self.ActiveCombatCasts) do
			if cast.Player == player then
				self.ActiveCombatCasts[castId] = nil
			end
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		EvasiveService:Set(player, EvasiveService:Get(player))
	end

	return self
end

function CombatService:IsCombatSkill(skillName, subject)
	if COMBAT_SKILLS[skillName] == true then
		return true
	end

	if subject then
		local combat = CombatConfig.GetForSubject(subject)
		local m1SkillName = combat.M1.SkillName or "CombatM1"
		local forwardDashSkillName = combat.Dash.Forward.SkillName or "CombatForwardDash"

		return skillName == m1SkillName or skillName == forwardDashSkillName
	end

	return false
end

function CombatService:GetNextComboIndex(player)
	local combat = CombatConfig.GetForSubject(player)
	local state = self.ComboStates[player]
	local now = os.clock()
	local maxCombo = getComboLength(player)

	if not state or now - state.LastAt > (combat.M1.ResetTime or 1.1) then
		return 1
	end

	return (state.Index % maxCombo) + 1
end

function CombatService:ResolveM1Variant(player, comboIndex, payload)
	if comboIndex < getComboLength(player) then
		return nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local airborne = false

	if humanoid then
		airborne = humanoid.FloorMaterial == Enum.Material.Air
			or humanoid:GetState() == Enum.HumanoidStateType.Freefall
			or humanoid:GetState() == Enum.HumanoidStateType.Jumping
	end

	if airborne then
		return "Downslam"
	end

	if payload and payload.SpaceHeld == true then
		return "Uppercut"
	end

	return nil
end

function CombatService:GetCombatSkillConfig(player, skillName, payload)
	payload = payload or {}
	local combat = CombatConfig.GetForSubject(player)
	local m1SkillName = combat.M1.SkillName or "CombatM1"
	local forwardDashSkillName = combat.Dash.Forward.SkillName or "CombatForwardDash"

	if payload.CastId and self.ActiveCombatCasts[payload.CastId] then
		return self.ActiveCombatCasts[payload.CastId].Config
	end

	if skillName == m1SkillName then
		local comboIndex = tonumber(payload.ComboIndex) or self:GetNextComboIndex(player)
		local variant = self:ResolveM1Variant(player, comboIndex, payload)
		return CombatConfig.GetM1SkillConfig(player, {
			ComboIndex = comboIndex,
			ComboVariant = variant,
		})
	end

	if skillName == forwardDashSkillName then
		return CombatConfig.GetForwardDashSkillConfig(player)
	end

	return nil
end

function CombatService:CanUseSkill(player, skillName, payload)
	payload = payload or {}

	if not self:IsCombatSkill(skillName, player) then
		return nil
	end

	if payload.CastId and self.ActiveCombatCasts[payload.CastId] then
		return true
	end

	local combat = CombatConfig.GetForSubject(player)
	if skillName == (combat.M1.SkillName or "CombatM1") then
		if payload.Kind == "Start" and tonumber(payload.ComboIndex) ~= self:GetNextComboIndex(player) then
			return false
		end

		return PlayerStateService:Can(player, "Attack")
	end

	if skillName == (combat.Dash.Forward.SkillName or "CombatForwardDash") then
		return PlayerStateService:HasState(player, "Dashing") or PlayerStateService:Can(player, "Dash")
	end

	return true
end

function CombatService:OnValidatedStart(result)
	local player = result.Attacker
	local payload = result.Payload or {}
	local skillName = result.Skill

	if not self:IsCombatSkill(skillName, player) then
		return false
	end

	local stateDuration = result.Config.StateDuration or result.Config.Duration or 0.3

	local existingCast = payload.CastId and self.ActiveCombatCasts[payload.CastId]
	if existingCast and existingCast.Player == player and existingCast.StateStarted then
		return true
	end

	local combat = CombatConfig.GetForSubject(player)
	if skillName == (combat.M1.SkillName or "CombatM1") then
		local comboIndex = tonumber(payload.ComboIndex) or self:GetNextComboIndex(player)

		self.ComboStates[player] = {
			Index = comboIndex,
			LastAt = os.clock(),
		}

		PlayerStateService:StartAttack(player, result.Config.Id or skillName, stateDuration, {
			Skill = skillName,
			CastId = payload.CastId,
			ComboIndex = comboIndex,
			ComboVariant = result.Config.ComboVariant,
			WalkSpeed = combat.M1.AttackWalkSpeed,
			Source = "CombatService",
		})
	elseif skillName == (combat.Dash.Forward.SkillName or "CombatForwardDash") then
		PlayerStateService:SetDashing(player, true, stateDuration, {
			Skill = skillName,
			CastId = payload.CastId,
			Direction = "Forward",
			Source = "CombatService",
			Force = true,
		})
	end

	if payload.CastId then
		self.ActiveCombatCasts[payload.CastId] = {
			Player = player,
			Skill = skillName,
			Config = result.Config,
			StartedAt = os.clock(),
		}

		task.delay((result.Config.CastWindow or 0.5) + 0.5, function()
			local cast = self.ActiveCombatCasts[payload.CastId]
			if cast and cast.Player == player then
				self.ActiveCombatCasts[payload.CastId] = nil
			end
		end)
	end

	return true
end

function CombatService:RequestM1Start(player, payload)
	payload = payload or {}
	local combat = CombatConfig.GetForSubject(player)
	local skillName = combat.M1.SkillName or "CombatM1"
	local castId = payload.CastId

	if not isValidCastId(castId) then
		return false
	end

	if self.ActiveCombatCasts[castId] then
		return true
	end

	if not PlayerStateService:Can(player, "Attack") then
		return false
	end

	local nextComboIndex = self:GetNextComboIndex(player)
	local comboIndex = tonumber(payload.ComboIndex) or nextComboIndex
	if comboIndex ~= nextComboIndex then
		return false
	end

	local variant = self:ResolveM1Variant(player, comboIndex, payload)
	local config = CombatConfig.GetM1SkillConfig(player, {
		ComboIndex = comboIndex,
		ComboVariant = variant,
	})
	local stateDuration = config.StateDuration or config.Duration or 0.3

	self.ComboStates[player] = {
		Index = comboIndex,
		LastAt = os.clock(),
	}

	self.ActiveCombatCasts[castId] = {
		Player = player,
		Skill = skillName,
		Config = config,
		StartedAt = os.clock(),
		StateStarted = true,
	}

	PlayerStateService:StartAttack(player, config.Id or skillName, stateDuration, {
		Skill = skillName,
		CastId = castId,
		ComboIndex = comboIndex,
		ComboVariant = variant,
		WalkSpeed = combat.M1.AttackWalkSpeed,
		Source = "CombatService",
	})

	task.delay((config.CastWindow or 0.5) + 0.5, function()
		local cast = self.ActiveCombatCasts[castId]
		if cast and cast.Player == player then
			self.ActiveCombatCasts[castId] = nil
		end
	end)

	return true
end

function CombatService:RequestDash(player, payload)
	local direction = normalizeDirection(payload.Direction)
	local dashConfig = CombatConfig.GetDash(player, direction)
	local now = os.clock()
	local cooldown = dashConfig.Cooldown or CombatConfig.GetForSubject(player).Dash.Cooldown or 0.85
	local cooldowns = self.DashCooldowns[player] or {}
	self.DashCooldowns[player] = cooldowns

	if cooldowns[direction] and cooldowns[direction] > now then
		return false
	end

	local evasiveDash = false
	if PlayerStateService:HasState(player, "Ragdolled") then
		if RagdollService:IsTrueRagdoll(player) or not EvasiveService:CanEvasive(player) then
			return false
		end

		local evasiveConfig = CombatConfig.GetEvasive(player)
		if not EvasiveService:Consume(player, evasiveConfig.ConsumeAmount) then
			return false
		end

		RagdollService:Unragdoll(player)
		evasiveDash = true
		dashConfig.Speed = evasiveConfig.EvasiveDashSpeed or dashConfig.Speed
		dashConfig.Duration = evasiveConfig.EvasiveDashDuration or dashConfig.Duration
	end

	if not evasiveDash and not PlayerStateService:Can(player, "Dash") then
		return false
	end

	cooldowns[direction] = now + cooldown
	PlayerStateService:SetDashing(player, true, dashConfig.StateDuration or dashConfig.Duration or 0.25, {
		Direction = direction,
		Evasive = evasiveDash,
		Source = "CombatService",
		Force = evasiveDash,
	})

	return true
end

function CombatService:HandleRequest(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.Action == "Dash" then
		self:RequestDash(player, payload)
	elseif payload.Action == "M1Start" then
		self:RequestM1Start(player, payload)
	end
end

return CombatService