-- @ScriptType: ModuleScript
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local workspace = game:GetService("Workspace")

local GlobalModules = ReplicatedStorage:WaitForChild("GlobalModules")
local CombatConfig = require(GlobalModules:WaitForChild("CombatConfig"))
local HitboxSystem = require(GlobalModules:WaitForChild("HitboxSystem"))

local PlayerStateClient = require(script.Parent:WaitForChild("PlayerStateClient"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local CombatClient = {}

CombatClient.Started = false
CombatClient.ComboIndex = 0
CombatClient.LastM1At = 0
CombatClient.NextM1At = 0
CombatClient.DashCooldowns = {}
CombatClient.Blocking = false

local M1_INPUT = Enum.UserInputType.MouseButton1
local BLOCK_KEY = Enum.KeyCode.F
local DASH_KEY = Enum.KeyCode.Q

local combatRequest = nil

local function getCombatRequest()
	if combatRequest then
		return combatRequest
	end

	combatRequest = remotes:FindFirstChild("CombatRequest")
	if not combatRequest then
		warn("CombatRequest remote is missing. Server combat dash requests will not fire yet.")
	end

	return combatRequest
end

local function isTyping()
	return UserInputService:GetFocusedTextBox() ~= nil
end

local function getCharacter()
	return player.Character
end

local function getRoot()
	local character = getCharacter()
	return character and (
		character:FindFirstChild("HumanoidRootPart")
			or character.PrimaryPart
			or character:FindFirstChild("Torso")
			or character:FindFirstChild("UpperTorso")
	)
end

local function getHumanoid()
	local character = getCharacter()
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function isAirborne()
	local humanoid = getHumanoid()
	if not humanoid then
		return false
	end

	return humanoid.FloorMaterial == Enum.Material.Air
		or humanoid:GetState() == Enum.HumanoidStateType.Freefall
		or humanoid:GetState() == Enum.HumanoidStateType.Jumping
end

local function flatUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return fallback or Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function getCameraBasis()
	local camera = workspace.CurrentCamera
	local root = getRoot()
	local fallbackLook = root and flatUnit(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local fallbackRight = root and flatUnit(root.CFrame.RightVector) or Vector3.new(1, 0, 0)

	if not camera then
		return fallbackLook, fallbackRight
	end

	return flatUnit(camera.CFrame.LookVector, fallbackLook), flatUnit(camera.CFrame.RightVector, fallbackRight)
end

local function getDashDirection()
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		return "Back"
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.A) and not UserInputService:IsKeyDown(Enum.KeyCode.D) then
		return "Left"
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.D) and not UserInputService:IsKeyDown(Enum.KeyCode.A) then
		return "Right"
	end

	return "Forward"
end

local function getDashVector(directionName)
	local look, right = getCameraBasis()

	if directionName == "Back" then
		return -look
	end

	if directionName == "Left" then
		return -right
	end

	if directionName == "Right" then
		return right
	end

	return look
end

local function applyDashVelocity(directionName, dashConfig)
	local root = getRoot()
	if not root then
		return
	end

	local startedAt = os.clock()
	local duration = dashConfig.Duration or 0.22
	local speed = dashConfig.Speed or 60
	local connection = nil

	connection = RunService.Heartbeat:Connect(function()
		if os.clock() - startedAt >= duration or not root.Parent then
			connection:Disconnect()
			return
		end

		local direction = getDashVector(directionName)
		local currentVelocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, currentVelocity.Y, direction.Z * speed)
	end)
end

local function getNextComboIndex()
	local combat = CombatConfig.GetForSubject(player)
	local m1 = combat.M1
	local maxCombo = m1.MaxCombo or #(m1.Steps or {})
	local now = os.clock()

	if now - CombatClient.LastM1At > (m1.ResetTime or 1.1) then
		return 1
	end

	return (CombatClient.ComboIndex % maxCombo) + 1
end

local function getComboVariant(comboIndex, spaceHeld)
	local combat = CombatConfig.GetForSubject(player)
	local maxCombo = combat.M1.MaxCombo or #(combat.M1.Steps or {})

	if comboIndex < maxCombo then
		return nil
	end

	if isAirborne() then
		return "Downslam"
	end

	if spaceHeld or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		return "Uppercut"
	end

	return nil
end

local function createCombatHitbox(skillName, stepConfig, extraPayload)
	local root = getRoot()
	local character = getCharacter()
	if not root or not character then
		return
	end

	HitboxSystem.Create({
		Owner = player,
		SkillName = skillName,
		MoveId = stepConfig.Id or skillName,
		ReportToServer = true,
		ReportStartToServer = true,
		AttachTo = root,
		Offset = stepConfig.Offset or CFrame.new(0, 0, -3),
		Shape = stepConfig.Shape or "Box",
		Size = stepConfig.Size or Vector3.new(5, 5, 5),
		Radius = stepConfig.Radius,
		Duration = stepConfig.Duration or 0.12,
		TickRate = stepConfig.TickRate or 1 / 60,
		Ignore = { character },
		IgnoreSameTeam = true,
		StopOnFirstHit = stepConfig.StopOnFirstHit ~= false,
		Debug = stepConfig.Debug == true,
		DebugColor = stepConfig.DebugColor or Color3.fromRGB(255, 255, 255),
		Parryable = stepConfig.Parryable == true,
		ExtraPayload = extraPayload,
	})
end

function CombatClient:DoM1()
	if os.clock() < self.NextM1At then
		return
	end

	if PlayerStateClient.Can("Attack") == false then
		return
	end

	local combat = CombatConfig.GetForSubject(player)
	local comboIndex = getNextComboIndex()
	local spaceHeldAtInput = UserInputService:IsKeyDown(Enum.KeyCode.Space)
	local comboVariant = getComboVariant(comboIndex, spaceHeldAtInput)
	local stepConfig = CombatConfig.GetM1Step(player, comboIndex, comboVariant)
	local castId = HttpService:GenerateGUID(false)
	local windup = stepConfig.Windup or 0

	self.ComboIndex = comboIndex
	self.LastM1At = os.clock()
	self.NextM1At = self.LastM1At + (stepConfig.InputDelay or math.max((stepConfig.StateDuration or 0.28) * 0.65, 0.14))

	local remote = getCombatRequest()
	if remote then
		remote:FireServer({
			Action = "M1Start",
			CastId = castId,
			ComboIndex = comboIndex,
			ComboVariant = comboVariant,
			SpaceHeld = spaceHeldAtInput,
			ClientTime = os.clock(),
		})
	end

	task.delay(windup, function()
		if not player.Parent then
			return
		end

		local finalVariant = getComboVariant(comboIndex, spaceHeldAtInput)
		local finalStepConfig = CombatConfig.GetM1Step(player, comboIndex, finalVariant)

		createCombatHitbox(combat.M1.SkillName or "CombatM1", finalStepConfig, {
			CombatKind = "M1",
			CastId = castId,
			ComboIndex = comboIndex,
			ComboVariant = finalVariant,
			SpaceHeld = spaceHeldAtInput or UserInputService:IsKeyDown(Enum.KeyCode.Space),
		})
	end)
end

function CombatClient:DoDash()
	local isRagdolled = PlayerStateClient.HasState("Ragdolled")
	local character = getCharacter()

	if PlayerStateClient.Can("Dash") == false and not isRagdolled then
		return
	end

	if isRagdolled and (player:GetAttribute("EvasiveReady") ~= true or (character and character:GetAttribute("TrueRagdoll") == true)) then
		return
	end

	local directionName = getDashDirection()
	local dashConfig = CombatConfig.GetDash(player, directionName)
	local combat = CombatConfig.GetForSubject(player)
	local now = os.clock()
	local cooldown = dashConfig.Cooldown or combat.Dash.Cooldown or 0.85

	if self.DashCooldowns[directionName] and self.DashCooldowns[directionName] > now then
		return
	end

	self.DashCooldowns[directionName] = now + cooldown

	local remote = getCombatRequest()
	if remote then
		remote:FireServer({
			Action = "Dash",
			Direction = directionName,
			ClientTime = os.clock(),
		})
	end

	applyDashVelocity(directionName, dashConfig)

	if isRagdolled then
		return
	end

	if directionName ~= "Forward" then
		return
	end

	task.delay(dashConfig.HitStart or 0.12, function()
		if not player.Parent then
			return
		end

		local castId = HttpService:GenerateGUID(false)
		local hitConfig = table.clone(dashConfig)
		hitConfig.Duration = dashConfig.HitDuration or 0.22

		createCombatHitbox(dashConfig.SkillName or "CombatForwardDash", hitConfig, {
			CombatKind = "ForwardDash",
			CastId = castId,
		})
	end)
end

function CombatClient:SetBlocking(active)
	if self.Blocking == active then
		return
	end

	self.Blocking = active
	PlayerStateClient.RequestBlocking(active)
end

function CombatClient.Start()
	if CombatClient.Started then
		return CombatClient
	end

	CombatClient.Started = true

	UserInputService.InputBegan:Connect(function(input)
		if isTyping() then
			return
		end

		if input.UserInputType == M1_INPUT then
			CombatClient:DoM1()
		elseif input.KeyCode == BLOCK_KEY then
			CombatClient:SetBlocking(true)
		elseif input.KeyCode == DASH_KEY then
			CombatClient:DoDash()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if isTyping() then
			return
		end

		if input.KeyCode == BLOCK_KEY then
			CombatClient:SetBlocking(false)
		end
	end)

	return CombatClient
end

return CombatClient