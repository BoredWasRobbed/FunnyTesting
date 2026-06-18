-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local UI = Assets:WaitForChild("UI")

local GlobalModules = ReplicatedStorage:WaitForChild("GlobalModules")
local CharacterRegistry = require(GlobalModules:WaitForChild("CharacterRegistry"))
local Keybind = require(GlobalModules:WaitForChild("Keybind"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwitchEvent = Remotes:WaitForChild("SwitchCharacter")

local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

local KeyCodeByBind = {
	["1"] = Enum.KeyCode.One,
	["2"] = Enum.KeyCode.Two,
	["3"] = Enum.KeyCode.Three,
	["4"] = Enum.KeyCode.Four,
	["5"] = Enum.KeyCode.Five,
	["6"] = Enum.KeyCode.Six,
	["7"] = Enum.KeyCode.Seven,
	["8"] = Enum.KeyCode.Eight,
	["9"] = Enum.KeyCode.Nine
}

local UIHandler = {}

local function getMoveByType(moveset, moveType)
	for _, item in pairs(moveset) do
		if item.Type == moveType then
			return item
		end
	end
end

local function insertHotbarItem(player: Player, item: {}, layoutOrder: number)
	if not item then return end
	
	if item.Type == "BaseMove" then
		local newMove = UI.MoveTemplate:Clone()
		newMove.Bind.Text = item.Bind or tostring(layoutOrder)
		newMove.MoveName.Text = item.Name or "N/A"
		newMove.Tooltip.Text = item.Tooltip or ""
		newMove.LayoutOrder = layoutOrder or tonumber(item.Bind)
		newMove.Parent = player:WaitForChild("PlayerGui"):WaitForChild("HUD").MovesetContainer.Hotbar
		
		local bind = Keybind.GetAction("Idle", item.Name)
		bind.KeyboardBinding.KeyCode = KeyCodeByBind[item.Bind]
		
		bind.Pressed:Connect(function()
			print(item.Name)
		end)
	end
end

local function applyGradient(fillFrame: Frame, gradientData)
	if not fillFrame or not gradientData then return end

	local gradient = fillFrame:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = fillFrame
	end

	if gradientData.Color then
		gradient.Color = gradientData.Color
	end

	if gradientData.Transparency then
		gradient.Transparency = gradientData.Transparency
	end

	if gradientData.Rotation then
		gradient.Rotation = gradientData.Rotation
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
	local playerGui = player:WaitForChild("PlayerGui")
	local MovesetContainer = playerGui:WaitForChild("HUD").MovesetContainer

	local awakeningMove = getMoveByType(characterMoveset, "Awakening")
	if awakeningMove then
		MovesetContainer.AwakeningBar.AwakeningName.Text = awakeningMove.Name
		MovesetContainer.AwakeningBar.BindDisplay.Text = "Press ".. awakeningMove.Bind.." to Awaken"
	end

	for _, v in pairs(MovesetContainer.Hotbar:GetChildren()) do
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

function UIHandler.applyCharacterBars(player: Player, characterName: string)
	local character = CharacterRegistry:getCharacter(characterName)
	if not character or not character.UI or not character.UI.BarGradients then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local MovesetContainer = playerGui:WaitForChild("HUD").MovesetContainer

	local awakeningFill = MovesetContainer.AwakeningBar.Fill
	local specialFill = MovesetContainer.Hotbar.SpecialBar.Fill

	applyGradient(awakeningFill, character.UI.BarGradients.Awakening)
	applyGradient(specialFill, character.UI.BarGradients.Special)
end

return UIHandler
