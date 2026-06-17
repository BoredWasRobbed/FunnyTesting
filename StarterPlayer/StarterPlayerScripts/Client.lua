-- @ScriptType: LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer").StarterPlayerScripts

local DataService = require(ReplicatedStorage:WaitForChild("DataService")).client

local ClientModules = StarterPlayerScripts:WaitForChild("ClientModules")
local UIHandler = require(ClientModules:WaitForChild("UIHandler"))

local GlobalModules = ReplicatedStorage:WaitForChild("GlobalModules")
local CharacterService = require(GlobalModules:WaitForChild("CharacterService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")

local player = game.Players.LocalPlayer

UIHandler.constructCharacterList()

SwitchEvent.OnClientEvent:Connect(function(characterMoveset)
	UIHandler.constructMoveset(player, characterMoveset)
end)