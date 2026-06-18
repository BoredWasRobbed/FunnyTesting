-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

local GENERATED_MOVE_ATTRIBUTE = "GeneratedHotbarMove"
local HOTBAR_DOWN_OFFSET = 140
local HOTBAR_TWEEN_INFO = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
local FILL_CLEAR_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TYPEWRITE_INTERVAL = 0.025

local activeTransitionId = 0
local activeHotbarTween = nil
local restingHotbarPosition = nil
local activeMoveConnections = {}
local activeMoveActions = {}

local function getKeyCode(bind)
	if not bind then
		return nil
	end

	return KeyCodeByBind[bind] or Enum.KeyCode[bind]
end

local function getMoveByType(moveset, moveType)
	for _, item in pairs(moveset) do
		if item.Type == moveType then
			return item
		end
	end
end

local function getMoveLayoutOrder(item, fallbackOrder)
	return item.LayoutOrder or tonumber(item.Bind) or fallbackOrder
end

local function getSortedBaseMoves(moveset)
	local moves = {}

	for _, item in pairs(moveset) do
		if item.Type == "BaseMove" then
			table.insert(moves, item)
		end
	end

	table.sort(moves, function(a, b)
		return getMoveLayoutOrder(a, 0) < getMoveLayoutOrder(b, 0)
	end)

	return moves
end

local function getMovesetContainer(player: Player)
	local playerGui = player:WaitForChild("PlayerGui")
	return playerGui:WaitForChild("HUD"):WaitForChild("MovesetContainer")
end

local function getSpecialBar(MovesetContainer)
	return MovesetContainer:FindFirstChild("SpecialBar")
		or MovesetContainer.Hotbar:FindFirstChild("SpecialBar")
end

local function getDownPosition()
	return restingHotbarPosition + UDim2.fromOffset(0, HOTBAR_DOWN_OFFSET)
end

local function tweenAndWait(instance, tweenInfo, goal, transitionId)
	if activeHotbarTween then
		activeHotbarTween:Cancel()
	end

	local tween = TweenService:Create(instance, tweenInfo, goal)
	activeHotbarTween = tween

	local completed = false
	local connection = tween.Completed:Connect(function()
		completed = true
	end)

	tween:Play()

	while not completed and activeTransitionId == transitionId do
		task.wait()
	end

	connection:Disconnect()

	if activeTransitionId ~= transitionId then
		tween:Cancel()
		return false
	end

	return true
end

local function typewriteText(label, text, transitionId)
	label.Text = ""

	for i = 1, #text do
		if activeTransitionId ~= transitionId then
			return false
		end

		label.Text = string.sub(text, 1, i)
		task.wait(TYPEWRITE_INTERVAL)
	end

	return true
end

local function clearTextWithTypewrite(label, transitionId)
	local text = label.Text

	for i = #text, 0, -1 do
		if activeTransitionId ~= transitionId then
			return false
		end

		label.Text = string.sub(text, 1, i)
		task.wait(TYPEWRITE_INTERVAL)
	end

	return true
end

local function clearAwakeningFill(awakeningBar)
	local fill = awakeningBar:FindFirstChild("Fill")
	if not fill then
		return
	end

	TweenService:Create(fill, FILL_CLEAR_TWEEN_INFO, {
		Size = UDim2.new(0, 0, fill.Size.Y.Scale, fill.Size.Y.Offset),
	}):Play()
end

local function clearMoveKeybinds()
	for _, connection in pairs(activeMoveConnections) do
		connection:Disconnect()
	end

	for _, action in pairs(activeMoveActions) do
		local keyboardBinding = action:FindFirstChild("KeyboardBinding")
		if keyboardBinding then
			keyboardBinding.KeyCode = Enum.KeyCode.Unknown
		end
	end

	table.clear(activeMoveConnections)
	table.clear(activeMoveActions)
end

local function bindMoveInput(item)
	local keyCode = getKeyCode(item.Bind)
	if not keyCode then
		warn(`No KeyCode found for bind "{tostring(item.Bind)}" on move "{item.Name}".`)
		return
	end

	local bind = Keybind.GetAction("Idle", item.Name)
	bind.KeyboardBinding.KeyCode = keyCode

	activeMoveActions[item.Name] = bind
	activeMoveConnections[item.Name] = bind.Pressed:Connect(function()
		print(item.Name)
	end)
end

local function clearHotbarMoves(hotbar)
	for _, child in ipairs(hotbar:GetChildren()) do
		if child:GetAttribute(GENERATED_MOVE_ATTRIBUTE) or child:FindFirstChild("MoveName") then
			child:Destroy()
		end
	end
end

local function insertHotbarItem(hotbar, item, layoutOrder)
	if not item then return end

	local newMove = UI.MoveTemplate:Clone()
	newMove.Name = `Move_{item.Name}`
	newMove.Visible = true
	newMove.Bind.Text = item.Bind or tostring(layoutOrder)
	newMove.MoveName.Text = item.Name or "N/A"
	newMove.Tooltip.Text = item.Tooltip or ""
	newMove.LayoutOrder = layoutOrder
	newMove:SetAttribute(GENERATED_MOVE_ATTRIBUTE, true)
	newMove.Parent = hotbar

	bindMoveInput(item)
end

local function rebuildHotbar(hotbar, characterMoveset)
	clearMoveKeybinds()
	clearHotbarMoves(hotbar)

	for index, item in ipairs(getSortedBaseMoves(characterMoveset)) do
		insertHotbarItem(hotbar, item, getMoveLayoutOrder(item, index))
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
		newIcon:bindEvent("selected", function()
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
	local MovesetContainer = getMovesetContainer(player)
	local hotbar = MovesetContainer:WaitForChild("Hotbar")
	local awakeningBar = MovesetContainer:WaitForChild("AwakeningBar")
	local awakeningMove = getMoveByType(characterMoveset, "Awakening")

	if awakeningMove then
		awakeningBar.AwakeningName.Text = awakeningMove.Name
		awakeningBar.BindDisplay.Text = "Press " .. awakeningMove.Bind .. " to Awaken"
	end

	rebuildHotbar(hotbar, characterMoveset)
end

function UIHandler.applyCharacterBars(player: Player, characterName: string)
	local character = CharacterRegistry:getCharacter(characterName)
	if not character or not character.UI or not character.UI.BarGradients then
		return
	end

	local MovesetContainer = getMovesetContainer(player)
	local awakeningFill = MovesetContainer.AwakeningBar.Fill
	local specialBar = getSpecialBar(MovesetContainer)
	local specialFill = specialBar and specialBar:FindFirstChild("Fill")

	applyGradient(awakeningFill, character.UI.BarGradients.Awakening)
	applyGradient(specialFill, character.UI.BarGradients.Special)
end

function UIHandler.transitionCharacter(player: Player, characterName: string, characterMoveset)
	activeTransitionId += 1
	local transitionId = activeTransitionId

	local MovesetContainer = getMovesetContainer(player)
	local hotbar = MovesetContainer:WaitForChild("Hotbar")
	local awakeningBar = MovesetContainer:WaitForChild("AwakeningBar")
	local awakeningName = awakeningBar:WaitForChild("AwakeningName")
	local bindDisplay = awakeningBar:WaitForChild("BindDisplay")
	local awakeningMove = getMoveByType(characterMoveset, "Awakening")

	restingHotbarPosition = restingHotbarPosition or hotbar.Position

	if not tweenAndWait(hotbar, HOTBAR_TWEEN_INFO, {
		Position = getDownPosition(),
		}, transitionId) then
		return
	end

	clearAwakeningFill(awakeningBar)

	if not clearTextWithTypewrite(awakeningName, transitionId) then
		return
	end

	rebuildHotbar(hotbar, characterMoveset)
	UIHandler.applyCharacterBars(player, characterName)

	if awakeningMove then
		bindDisplay.Text = "Press " .. awakeningMove.Bind .. " to Awaken"

		if not typewriteText(awakeningName, awakeningMove.Name, transitionId) then
			return
		end
	else
		bindDisplay.Text = ""
	end

	tweenAndWait(hotbar, HOTBAR_TWEEN_INFO, {
		Position = restingHotbarPosition,
	}, transitionId)
end

return UIHandler