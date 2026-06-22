-- @ScriptType: Script
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")
local CombatRequestEvent = Remotes:FindFirstChild("CombatRequest")
local RequestCharacterEvent = Remotes:FindFirstChild("RequestCharacter")

local ServerModules = ServerScriptService:WaitForChild("ServerModules")
local CombatService = require(ServerModules:WaitForChild("CombatService"))
local PlayerStateService = require(ServerModules:WaitForChild("PlayerStateService"))
local CharacterService = require(ServerModules:WaitForChild("CharacterService"))

PlayerStateService:Init()
CombatService:Init()
CharacterService:Init()

SwitchEvent.OnServerEvent:Connect(function(player, characterName)
	CharacterService:switchCharacter(player, characterName)
end)

RequestCharacterEvent.OnServerEvent:Connect(function(player)
	CharacterService:sendCurrentCharacter(player, {
		Initial = true,
	})
end)