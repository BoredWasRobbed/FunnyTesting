-- @ScriptType: ModuleScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage:WaitForChild("DataService")).server

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")

local CharacterRegistry = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("CharacterRegistry"))
local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService"))

local DEFAULT_CHARACTER = "Ichigo"
local DATA_CHARACTER_KEY = "Character"
local DATA_LOAD_TIMEOUT = 10

local CharacterService = {}

local selectedCharacters = {}
local loadedPlayers = {}

local function getDefaultCharacter()
	if CharacterRegistry:getCharacter(DEFAULT_CHARACTER) then
		return DEFAULT_CHARACTER
	end

	for characterName in pairs(CharacterRegistry:getCharacters()) do
		return characterName
	end

	return DEFAULT_CHARACTER
end

local function getValidCharacterName(characterName)
	if typeof(characterName) == "string" and CharacterRegistry:getCharacter(characterName) then
		return characterName
	end

	return getDefaultCharacter()
end

local function tryCall(methodName, ...)
	local method = DataService[methodName]
	if typeof(method) ~= "function" then
		return false, nil
	end

	local success, result = pcall(method, DataService, ...)
	if success and result ~= nil then
		return true, result
	end

	local dotSuccess, dotResult = pcall(method, ...)
	if dotSuccess then
		return true, dotResult
	end

	if success then
		return true, result
	end

	return false, dotResult
end

local function getProfileData(player: Player)
	local success, result

	success, result = tryCall("get", player)
	if success and typeof(result) == "table" then
		return result.Data or result
	end

	success, result = tryCall("Get", player)
	if success and typeof(result) == "table" then
		return result.Data or result
	end

	success, result = tryCall("getData", player)
	if success and typeof(result) == "table" then
		return result.Data or result
	end

	success, result = tryCall("GetData", player)
	if success and typeof(result) == "table" then
		return result.Data or result
	end

	local profiles = DataService.Profiles or DataService.profiles
	if typeof(profiles) == "table" then
		local profile = profiles[player] or profiles[player.UserId] or profiles[tostring(player.UserId)]
		if typeof(profile) == "table" then
			return profile.Data or profile
		end
	end

	return nil
end

local function readDataValue(player: Player, key: string)
	local data = getProfileData(player)
	if typeof(data) == "table" and data[key] ~= nil then
		return data[key]
	end

	local success, result

	success, result = tryCall("get", player, key)
	if success and result ~= nil then
		return result
	end

	success, result = tryCall("Get", player, key)
	if success and result ~= nil then
		return result
	end

	success, result = tryCall("get", key, player)
	if success and result ~= nil then
		return result
	end

	success, result = tryCall("Get", key, player)
	if success and result ~= nil then
		return result
	end

	return nil
end

local function writeDataValue(player: Player, key: string, value)
	local data = getProfileData(player)
	if typeof(data) == "table" then
		data[key] = value
	end

	local success

	success = tryCall("set", player, key, value)
	if success then
		return true
	end

	success = tryCall("Set", player, key, value)
	if success then
		return true
	end

	success = tryCall("set", key, value, player)
	if success then
		return true
	end

	success = tryCall("Set", key, value, player)
	if success then
		return true
	end

	success = tryCall("update", player, key, function()
		return value
	end)
	if success then
		return true
	end

	success = tryCall("Update", player, key, function()
		return value
	end)
	if success then
		return true
	end

	return data ~= nil
end

local function waitForData(player: Player)
	local startTime = os.clock()

	while player.Parent and os.clock() - startTime < DATA_LOAD_TIMEOUT do
		local data = getProfileData(player)
		if typeof(data) == "table" then
			return data
		end

		task.wait(0.1)
	end

	return getProfileData(player)
end

function CharacterService:canUseCharacter(player: Player, characterName: string)
	return CharacterRegistry:getCharacter(characterName) ~= nil
end

function CharacterService:getCurrentCharacter(player: Player)
	if selectedCharacters[player] then
		return selectedCharacters[player]
	end

	local attributeCharacter = player:GetAttribute("CurrentCharacter")
	if attributeCharacter then
		local characterName = getValidCharacterName(attributeCharacter)
		selectedCharacters[player] = characterName
		return characterName
	end

	return self:loadCharacter(player)
end

function CharacterService:setCurrentCharacter(player: Player, characterName: string)
	characterName = getValidCharacterName(characterName)

	selectedCharacters[player] = characterName
	player:SetAttribute("CurrentCharacter", characterName)
	writeDataValue(player, DATA_CHARACTER_KEY, characterName)

	return characterName
end

function CharacterService:loadCharacter(player: Player)
	if loadedPlayers[player] then
		return selectedCharacters[player] or getValidCharacterName(readDataValue(player, DATA_CHARACTER_KEY))
	end

	waitForData(player)

	local savedCharacter = readDataValue(player, DATA_CHARACTER_KEY)
	loadedPlayers[player] = true

	return self:setCurrentCharacter(player, savedCharacter)
end

function CharacterService:sendCharacter(player: Player, characterName: string, options)
	characterName = getValidCharacterName(characterName)

	local characterModule = CharacterRegistry:getCharacter(characterName)
	if not characterModule then
		return
	end

	SwitchEvent:FireClient(player, {
		Name = characterName,
		Moveset = characterModule.Moveset,
		Initial = options and options.Initial == true,
	})
end

function CharacterService:sendCurrentCharacter(player: Player, options)
	local characterName = self:getCurrentCharacter(player)
	self:sendCharacter(player, characterName, options)
end

function CharacterService:switchCharacter(player: Player, characterName: string)
	if typeof(characterName) ~= "string" then
		return
	end

	if not self:canUseCharacter(player, characterName) then
		return
	end

	local canSwitch = PlayerStateService:Can(player, "CharacterSwitch")
	if not canSwitch then
		return
	end

	characterName = self:setCurrentCharacter(player, characterName)
	self:sendCharacter(player, characterName, {
		Initial = false,
	})
end

function CharacterService:Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:loadCharacter(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local characterName = selectedCharacters[player] or player:GetAttribute("CurrentCharacter")
		if characterName then
			writeDataValue(player, DATA_CHARACTER_KEY, getValidCharacterName(characterName))
		end

		selectedCharacters[player] = nil
		loadedPlayers[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:loadCharacter(player)
		end)
	end
end

return CharacterService