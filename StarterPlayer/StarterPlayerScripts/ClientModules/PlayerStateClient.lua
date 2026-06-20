-- @ScriptType: ModuleScript
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateClient = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRequest = remotes:WaitForChild("StateRequest")
local stateChanged = remotes:WaitForChild("StateChanged")

PlayerStateClient.Snapshot = nil
PlayerStateClient.Listeners = {}
PlayerStateClient.Started = false

local function readSnapshotFromAttributes()
	local encoded = player:GetAttribute("State_Snapshot")
	if type(encoded) ~= "string" then
		return nil
	end

	local ok, snapshot = pcall(function()
		return HttpService:JSONDecode(encoded)
	end)

	return ok and snapshot or nil
end

function PlayerStateClient.Start()
	if PlayerStateClient.Started then
		return PlayerStateClient
	end

	PlayerStateClient.Started = true
	PlayerStateClient.Snapshot = readSnapshotFromAttributes()

	stateChanged.OnClientEvent:Connect(function(snapshot, stateName, reason)
		PlayerStateClient.Snapshot = snapshot

		for _, listener in ipairs(PlayerStateClient.Listeners) do
			listener(snapshot, stateName, reason)
		end
	end)

	player:GetAttributeChangedSignal("State_Snapshot"):Connect(function()
		PlayerStateClient.Snapshot = readSnapshotFromAttributes()
	end)

	return PlayerStateClient
end

function PlayerStateClient.OnChanged(callback)
	table.insert(PlayerStateClient.Listeners, callback)

	local disconnected = false
	return {
		Disconnect = function()
			if disconnected then
				return
			end

			disconnected = true

			for index, listener in ipairs(PlayerStateClient.Listeners) do
				if listener == callback then
					table.remove(PlayerStateClient.Listeners, index)
					break
				end
			end
		end,
	}
end

function PlayerStateClient.GetSnapshot()
	return PlayerStateClient.Snapshot or readSnapshotFromAttributes()
end

function PlayerStateClient.HasState(stateName)
	return player:GetAttribute(`State_{stateName}`) == true
end

function PlayerStateClient.GetCurrentSkill()
	return player:GetAttribute("State_CurrentSkill") or player:GetAttribute("CurrentSkill")
end

function PlayerStateClient.Can(actionName)
	local attributeName = `State_Can{actionName}`
	local value = player:GetAttribute(attributeName)

	if value == nil then
		return true
	end

	return value == true
end

function PlayerStateClient.RequestBlocking(active)
	stateRequest:FireServer({
		Action = "SetBlocking",
		Active = active == true,
	})
end

function PlayerStateClient.RequestSprinting(active)
	stateRequest:FireServer({
		Action = "SetSprinting",
		Active = active == true,
	})
end

return PlayerStateClient