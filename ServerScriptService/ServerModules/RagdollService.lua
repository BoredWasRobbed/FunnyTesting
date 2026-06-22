-- @ScriptType: ModuleScript
local Players = game:GetService("Players")

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local RagdollService = {}

local activeRagdolls = {}
local RAGDOLL_FOLDER_NAME = "CombatRagdoll"

local function getCharacter(subject)
	if typeof(subject) == "Instance" and subject:IsA("Player") then
		return subject.Character
	end

	if typeof(subject) == "Instance" and subject:IsA("Model") then
		return subject
	end

	return nil
end

local function getSubject(character)
	return Players:GetPlayerFromCharacter(character) or character
end

local function getHumanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function shouldRagdollMotor(motor)
	if not motor.Part0 or not motor.Part1 then
		return false
	end

	if motor.Part0.Name == "HumanoidRootPart" or motor.Part1.Name == "HumanoidRootPart" then
		return false
	end

	return true
end

local function clearConstraints(character)
	local folder = character and character:FindFirstChild(RAGDOLL_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			descendant.Enabled = true
		elseif descendant:IsA("Attachment") and descendant:GetAttribute("CombatRagdollAttachment") == true then
			descendant:Destroy()
		end
	end
end

function RagdollService:IsRagdolled(subject)
	local character = getCharacter(subject)
	return character and activeRagdolls[character] ~= nil
end

function RagdollService:Ragdoll(subject, duration, options)
	local character = getCharacter(subject)
	local humanoid = getHumanoid(character)
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end

	options = options or {}
	duration = tonumber(duration) or tonumber(options.Duration) or 1

	clearConstraints(character)

	local folder = Instance.new("Folder")
	folder.Name = RAGDOLL_FOLDER_NAME
	folder.Parent = character

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and shouldRagdollMotor(descendant) then
			local attachment0 = Instance.new("Attachment")
			attachment0.Name = `Ragdoll_{descendant.Name}_0`
			attachment0.CFrame = descendant.C0
			attachment0:SetAttribute("CombatRagdollAttachment", true)
			attachment0.Parent = descendant.Part0

			local attachment1 = Instance.new("Attachment")
			attachment1.Name = `Ragdoll_{descendant.Name}_1`
			attachment1.CFrame = descendant.C1
			attachment1:SetAttribute("CombatRagdollAttachment", true)
			attachment1.Parent = descendant.Part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Name = `Ragdoll_{descendant.Name}`
			socket.Attachment0 = attachment0
			socket.Attachment1 = attachment1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.Parent = folder

			descendant.Enabled = false
		end
	end

	local token = os.clock()
	activeRagdolls[character] = {
		Token = token,
		Subject = getSubject(character),
		TrueRagdoll = options.TrueRagdoll == true,
	}

	character:SetAttribute("TrueRagdoll", options.TrueRagdoll == true)
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	PlayerStateService:SetRagdolled(getSubject(character), true, duration, {
		Source = options.Source or "RagdollService",
		TrueRagdoll = options.TrueRagdoll == true,
		Force = true,
	})

	task.delay(duration, function()
		local active = activeRagdolls[character]
		if active and active.Token == token then
			self:Unragdoll(character)
		end
	end)

	return true
end

function RagdollService:Unragdoll(subject)
	local character = getCharacter(subject)
	local humanoid = getHumanoid(character)
	if not character then
		return false
	end

	activeRagdolls[character] = nil
	clearConstraints(character)
	character:SetAttribute("TrueRagdoll", nil)

	if humanoid and humanoid.Health > 0 then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	PlayerStateService:SetRagdolled(getSubject(character), false)
	return true
end

function RagdollService:IsTrueRagdoll(subject)
	local character = getCharacter(subject)
	local active = character and activeRagdolls[character]

	return (active and active.TrueRagdoll == true)
		or (character and character:GetAttribute("TrueRagdoll") == true)
		or false
end

return RagdollService