-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")

local CharacterRegistry = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("CharacterRegistry"))

local CharacterService = {}

function CharacterService:canUseCharacter(player, characterName)
	return CharacterRegistry:getCharacter(characterName) ~= nil
end

function CharacterService:switchCharacter(player, characterName)
	if typeof(characterName) ~= "string" then
		return
	end

	if not self:canUseCharacter(player, characterName) then
		return
	end

	local characterModule = CharacterRegistry:getCharacter(characterName)
	if not characterModule then
		return
	end

	SwitchEvent:FireClient(player, {
		Name = characterName,
		Moveset = characterModule.Moveset,
	})
end

return CharacterService