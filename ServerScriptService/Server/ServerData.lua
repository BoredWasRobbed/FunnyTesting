-- @ScriptType: Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(ReplicatedStorage.DataService).server

local DataTemplate = {
	
}

DataService:init({
	template = DataTemplate,
	useMock = false,
	resetData = false
})