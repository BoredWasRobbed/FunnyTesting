-- @ScriptType: LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer").StarterPlayerScripts

local ClientModules = StarterPlayerScripts:WaitForChild("ClientModules")
local UIHandler = require(ClientModules:WaitForChild("UIHandler"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")
local RequestCharacterEvent = Remotes:WaitForChild("RequestCharacter")

local player = game.Players.LocalPlayer

UIHandler.constructCharacterList()

SwitchEvent.OnClientEvent:Connect(function(characterData)
	if characterData.Initial then
		UIHandler.applyCharacterBars(player, characterData.Name)
		UIHandler.constructMoveset(player, characterData.Moveset)
		return
	end

	UIHandler.transitionCharacter(player, characterData.Name, characterData.Moveset)
end)

RequestCharacterEvent:FireServer()