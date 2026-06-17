-- @ScriptType: Script
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerModules = ServerScriptService:WaitForChild("ServerModules")
local CharacterService = require(ServerModules:WaitForChild("CharacterService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")

SwitchEvent.OnServerEvent:Connect(function(player, characterName)
	CharacterService:switchCharacter(player, characterName)
end)