-- @ScriptType: ModuleScript
local CharacterRegistry = {}

CharacterRegistry.Characters = {}

for _, character in ipairs(script:GetChildren()) do
	if character:IsA("ModuleScript") then
		CharacterRegistry.Characters[character.Name] = require(character)
	end
end

function CharacterRegistry:getCharacters()
	return self.Characters
end

function CharacterRegistry:getCharacter(name)
	return self.Characters[name]
end

return CharacterRegistry
