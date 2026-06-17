-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")

local CharacterService = {}

CharacterService.CharacterModules = {}

for _, character in pairs(script:GetChildren()) do
	if character:IsA("ModuleScript") then
		CharacterService.CharacterModules[character.Name] = require(character)
	end
end

local function getEnv()
	return RunService:IsServer() and "Server" or "Client"
end

function CharacterService:getCharacters()
	return self.CharacterModules
end

function CharacterService:getCharacter(name)
	return self.CharacterModules[name]
end

function CharacterService.switchCharacter(player: Player, characterName: string)
	if getEnv() == "Client" then return end
	
	local characterModule = CharacterService:getCharacter(characterName)
	print(characterModule.Moveset)
	
	if characterModule then
		SwitchEvent:FireClient(player, characterModule.Moveset)
	end
end

return CharacterService
