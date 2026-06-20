-- @ScriptType: Script
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerModules = ServerScriptService:WaitForChild("ServerModules")
local PlayerStateService = require(ServerModules:WaitForChild("PlayerStateService"))
local CharacterService = require(ServerModules:WaitForChild("CharacterService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")

local RequestCharacterEvent = Remotes:FindFirstChild("RequestCharacter")
if not RequestCharacterEvent then
	RequestCharacterEvent = Instance.new("RemoteEvent")
	RequestCharacterEvent.Name = "RequestCharacter"
	RequestCharacterEvent.Parent = Remotes
end

PlayerStateService:Init()
CharacterService:Init()

SwitchEvent.OnServerEvent:Connect(function(player, characterName)
	CharacterService:switchCharacter(player, characterName)
end)

RequestCharacterEvent.OnServerEvent:Connect(function(player)
	CharacterService:sendCurrentCharacter(player, {
		Initial = true,
	})
end)