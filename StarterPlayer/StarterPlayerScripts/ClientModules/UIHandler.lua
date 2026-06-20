-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local UI = Assets:WaitForChild("UI")

local GlobalModules = ReplicatedStorage:WaitForChild("GlobalModules")
local CharacterRegistry = require(GlobalModules:WaitForChild("CharacterRegistry"))
local Keybind = require(GlobalModules:WaitForChild("Keybind"))
local SkillSystem = require(GlobalModules:WaitForChild("SkillSystem"))

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
local VARIANT_FLASH_TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local VARIANT_TEXT_SWAP_DELAY = 0.06
local VARIANT_POLL_INTERVAL = 0.05
local TYPEWRITE_INTERVAL = 0.025
local BLOCK_KEY = Enum.KeyCode.F

local activeTransitionId = 0
local activeHotbarTween = nil
local restingHotbarPosition = nil
local activeMoveConnections = {}
local activeMoveActions = {}
local activeMoveEntries = {}
local variantUpdateConnection = nil
local lastVariantUpdateTime = 0

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

local function getMoveId(item)
	return item.Skill or item.Id or item.Name
end

local function getResultDisplayName(result)
	if result.DisplayName then
		return result.DisplayName
	end

	if result.Variant then
		return result.Variant.DisplayName or result.Variant.Name or result.Move.Name or "N/A"
	end

	return result.Move.Name or "N/A"
end

local function getResultDisplayKey(result)
	if result.IsVariant then
		return `Variant:{result.VariantName or result.SkillName or getResultDisplayName(result)}`
	end

	return `Base:{result.SkillName or result.Move.Skill or result.Move.Name}`
end

local function getResultCooldown(result)
	if result.Cooldown ~= nil then
		return tonumber(result.Cooldown) or 0
	end

	if result.Variant and result.Variant.Cooldown ~= nil then
		return tonumber(result.Variant.Cooldown) or 0
	end

	return tonumber(result.Move.Cooldown) or 0
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

local function getMoveInputState(player: Player)
	local character = player.Character

	return {
		Jump = UserInputService:IsKeyDown(Enum.KeyCode.Space),
		Space = UserInputService:IsKeyDown(Enum.KeyCode.Space),
		Block = UserInputService:IsKeyDown(BLOCK_KEY)
			or player:GetAttribute("Blocking") == true
			or (character and character:GetAttribute("Blocking") == true),
	}
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

local function flashMoveBackground(moveFrame)
	if not moveFrame or not moveFrame.Parent then
		return
	end

	local flash = Instance.new("Frame")
	flash.Name = "VariantFlash"
	flash.AnchorPoint = Vector2.new(0, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0.08
	flash.BorderSizePixel = 0
	flash.Position = UDim2.fromScale(0, 0)
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = moveFrame.ZIndex + 20
	flash.Parent = moveFrame

	local corner = moveFrame:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = flash
	end

	local tween = TweenService:Create(flash, VARIANT_FLASH_TWEEN_INFO, {
		BackgroundTransparency = 1,
	})

	tween.Completed:Connect(function()
		flash:Destroy()
	end)

	tween:Play()
end

local function setMoveDisplay(entry, result, shouldFlash)
	local displayKey = getResultDisplayKey(result)
	if entry.DisplayKey == displayKey then
		return
	end

	entry.DisplayKey = displayKey
	entry.CurrentResult = result

	local displayName = getResultDisplayName(result)
	local moveNameLabel = entry.Frame:FindFirstChild("MoveName")
	if not moveNameLabel then
		return
	end

	if not shouldFlash then
		moveNameLabel.Text = displayName
		return
	end

	entry.DisplayChangeId = (entry.DisplayChangeId or 0) + 1
	local displayChangeId = entry.DisplayChangeId

	flashMoveBackground(entry.Frame)

	task.delay(VARIANT_TEXT_SWAP_DELAY, function()
		if activeMoveEntries[entry.MoveId] ~= entry then
			return
		end

		if entry.DisplayChangeId ~= displayChangeId or not entry.Frame.Parent then
			return
		end

		moveNameLabel.Text = displayName
	end)
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

local function getCooldownFill(moveFrame)
	return moveFrame:FindFirstChild("CooldownFill")
end

local function setCooldownGradientVisible(fill, isVisible)
	local gradient = fill:FindFirstChildOfClass("UIGradient")
	if not gradient then
		return
	end

	gradient.Transparency = NumberSequence.new(isVisible and 0 or 1)
end

local function setCooldownFillScale(fill, yScale)
	fill.Size = UDim2.new(fill.Size.X.Scale, fill.Size.X.Offset, yScale, 0)
end

local function resetCooldownFill(moveFrame)
	local fill = getCooldownFill(moveFrame)
	if not fill then
		return
	end

	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	setCooldownFillScale(fill, 0)
	setCooldownGradientVisible(fill, false)
	fill.Visible = false
end

local function clearCooldown(entry)
	if entry.CooldownTween then
		entry.CooldownTween:Cancel()
		entry.CooldownTween = nil
	end

	if entry.CooldownConnection then
		entry.CooldownConnection:Disconnect()
		entry.CooldownConnection = nil
	end

	entry.CooldownEndsAt = 0
	resetCooldownFill(entry.Frame)
end

local function isMoveOnCooldown(entry)
	return (entry.CooldownEndsAt or 0) > os.clock()
end

local function startCooldown(entry, cooldown)
	cooldown = tonumber(cooldown) or 0
	if cooldown <= 0 then
		return
	end

	if entry.CooldownTween then
		entry.CooldownTween:Cancel()
	end

	if entry.CooldownConnection then
		entry.CooldownConnection:Disconnect()
	end

	local fill = getCooldownFill(entry.Frame)
	if not fill then
		return
	end

	entry.CooldownEndsAt = os.clock() + cooldown
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	setCooldownFillScale(fill, 1)
	setCooldownGradientVisible(fill, true)
	fill.Visible = true

	local tween = TweenService:Create(fill, TweenInfo.new(cooldown, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		Size = UDim2.new(fill.Size.X.Scale, fill.Size.X.Offset, 0, 0),
	})

	entry.CooldownTween = tween
	entry.CooldownConnection = tween.Completed:Connect(function()
		if activeMoveEntries[entry.MoveId] ~= entry then
			return
		end

		entry.CooldownTween = nil
		entry.CooldownConnection:Disconnect()
		entry.CooldownConnection = nil
		entry.CooldownEndsAt = 0
		setCooldownGradientVisible(fill, false)
		fill.Visible = false
	end)

	tween:Play()
end

local function stopVariantWatcher()
	if variantUpdateConnection then
		variantUpdateConnection:Disconnect()
		variantUpdateConnection = nil
	end
end

local function updateActiveMoveVariants(player: Player)
	local inputState = getMoveInputState(player)

	for _, entry in pairs(activeMoveEntries) do
		if entry.Frame and entry.Frame.Parent then
			local result = SkillSystem:ResolveMove(player, entry.Move, inputState)
			setMoveDisplay(entry, result, true)
		end
	end
end

local function startVariantWatcher(player: Player)
	stopVariantWatcher()
	lastVariantUpdateTime = 0

	variantUpdateConnection = RunService.RenderStepped:Connect(function()
		if next(activeMoveEntries) == nil then
			stopVariantWatcher()
			return
		end

		local now = os.clock()
		if now - lastVariantUpdateTime < VARIANT_POLL_INTERVAL then
			return
		end

		lastVariantUpdateTime = now
		updateActiveMoveVariants(player)
	end)
end

local function clearMoveKeybinds()
	stopVariantWatcher()

	for _, connection in pairs(activeMoveConnections) do
		connection:Disconnect()
	end

	for _, entry in pairs(activeMoveEntries) do
		clearCooldown(entry)
	end

	for _, action in pairs(activeMoveActions) do
		local keyboardBinding = action:FindFirstChild("KeyboardBinding")
		if keyboardBinding then
			keyboardBinding.KeyCode = Enum.KeyCode.Unknown
		end
	end

	table.clear(activeMoveConnections)
	table.clear(activeMoveActions)
	table.clear(activeMoveEntries)
end

local function bindMoveInput(player: Player, entry)
	local keyCode = getKeyCode(entry.Move.Bind)
	if not keyCode then
		warn(`No KeyCode found for bind "{tostring(entry.Move.Bind)}" on move "{entry.Move.Name}".`)
		return
	end

	local bind = Keybind.GetAction("Idle", entry.Move.Name)
	bind.KeyboardBinding.KeyCode = keyCode

	activeMoveActions[entry.MoveId] = bind
	activeMoveConnections[entry.MoveId] = bind.Pressed:Connect(function()
		if isMoveOnCooldown(entry) then
			return
		end

		local inputState = getMoveInputState(player)
		local result = SkillSystem:Play(player, entry.Move, inputState)
		setMoveDisplay(entry, result, false)

		startCooldown(entry, getResultCooldown(result))
	end)
end

local function clearHotbarMoves(hotbar)
	for _, child in ipairs(hotbar:GetChildren()) do
		if child:GetAttribute(GENERATED_MOVE_ATTRIBUTE) or child:FindFirstChild("MoveName") then
			child:Destroy()
		end
	end
end

local function insertHotbarItem(player: Player, hotbar, item, layoutOrder)
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

	local moveId = getMoveId(item)
	local entry = {
		MoveId = moveId,
		Move = item,
		Frame = newMove,
		CooldownEndsAt = 0,
	}

	activeMoveEntries[moveId] = entry
	resetCooldownFill(newMove)
	setMoveDisplay(entry, SkillSystem:ResolveMove(player, item, getMoveInputState(player)), false)
	bindMoveInput(player, entry)
end

local function rebuildHotbar(player: Player, hotbar, characterMoveset)
	clearMoveKeybinds()
	clearHotbarMoves(hotbar)

	for index, item in ipairs(getSortedBaseMoves(characterMoveset)) do
		insertHotbarItem(player, hotbar, item, getMoveLayoutOrder(item, index))
	end

	startVariantWatcher(player)
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

	rebuildHotbar(player, hotbar, characterMoveset)
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

	rebuildHotbar(player, hotbar, characterMoveset)
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
