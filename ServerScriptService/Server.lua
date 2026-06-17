-- @ScriptType: Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer").StarterPlayerScripts

local GlobalModules = ReplicatedStorage:WaitForChild("GlobalModules")
local CharacterService = require(GlobalModules:WaitForChild("CharacterService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")

SwitchEvent.OnServerEvent:Connect(function(player, characterName)
	CharacterService.switchCharacter(player, characterName)
end)