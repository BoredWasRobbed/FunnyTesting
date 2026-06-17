-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local UI = Assets:WaitForChild("UI")

local GlobalModules = ReplicatedStorage:WaitForChild("GlobalModules")
local CharacterRegistry = require(GlobalModules:WaitForChild("CharacterRegistry"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")

local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

local UIHandler = {}

local function insertHotbarItem(player: Player, item: {}, layoutOrder: number)
	if not item then return end
	
	if item.Type == "BaseMove" then
		local newMove = UI.MoveTemplate:Clone()
		newMove.Bind.Text = item.Bind or tostring(layoutOrder)
		newMove.MoveName.Text = item.Name or "N/A"
		newMove.Tooltip.Text = item.Tooltip or ""
		newMove.LayoutOrder = layoutOrder or tonumber(item.Bind)
		newMove.Parent = player:WaitForChild("PlayerGui"):WaitForChild("HUD").MovesetContainer.Hotbar
	end
end

function UIHandler.constructCharacterList()
	local characterList = {}

	for characterName, _ in pairs(CharacterRegistry:getCharacters()) do
		local newIcon = Icon.new()
		newIcon:setLabel(characterName)
		newIcon:bindEvent("toggled", function()
			SwitchEvent:FireServer(characterName)
		end)

		table.insert(characterList, newIcon)
	end
	
	Icon.new()
		:setName("CharacterList")
		:setLabel("Characters")
		:setDropdown(characterList)
end


function UIHandler.constructMoveset(player, characterMoveset)
	for i, v in pairs(player:WaitForChild("PlayerGui"):WaitForChild("HUD").MovesetContainer.Hotbar:GetChildren()) do
		if v:FindFirstChild("MoveName") then
			v:Destroy()
		end
	end
	
	for _, item in pairs(characterMoveset) do
		if item.Type == "BaseMove" then
			insertHotbarItem(player, item)
		end
	end
end

return UIHandler
