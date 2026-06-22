-- @ScriptType: ModuleScript
local SkillSystem = {}

local AIR_STATES = {
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
}

local skillCache = {}

local function getHumanoid(player: Player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function readInputBool(inputState, keys)
	if not inputState then
		return false
	end

	for _, key in ipairs(keys) do
		if inputState[key] ~= nil then
			return inputState[key] == true
		end
	end

	return false
end

local function getPlayerState(player: Player, inputState)
	local character = player.Character
	local humanoid = getHumanoid(player)
	local health = humanoid and humanoid.Health or 0
	local maxHealth = humanoid and humanoid.MaxHealth or 100

	local isAir = false
	if humanoid then
		isAir = humanoid.FloorMaterial == Enum.Material.Air or AIR_STATES[humanoid:GetState()] == true
	end

	if inputState and inputState.Air ~= nil then
		isAir = inputState.Air == true
	end

	local isJump = readInputBool(inputState, { "Jump", "Space", "JumpHeld", "SpaceHeld" })
	local isBlock = readInputBool(inputState, { "Block", "Blocking", "BlockHeld" })

	if not isBlock then
		isBlock = player:GetAttribute("Blocking") == true
			or (character and character:GetAttribute("Blocking") == true)
	end

	return {
		Air = isAir,
		Jump = isJump,
		Space = isJump,
		Block = isBlock,
		Health = health,
		MaxHealth = maxHealth,
		HealthPercent = maxHealth > 0 and health / maxHealth or 0,
	}
end

local function passesBoolCondition(expected, actual)
	if expected == nil then
		return true
	end

	return actual == expected
end

local function firstNonNil(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if value ~= nil then
			return value
		end
	end

	return nil
end

local function passesHpCondition(threshold, state)
	if threshold == nil then
		return true
	end

	if threshold <= 1 then
		return state.HealthPercent <= threshold
	end

	return state.Health <= threshold
end

local function passesHpTableCondition(hpCondition, state)
	if hpCondition == nil then
		return true
	end

	if type(hpCondition) == "number" then
		return passesHpCondition(hpCondition, state)
	end

	if hpCondition.AtOrBelow ~= nil then
		return passesHpCondition(hpCondition.AtOrBelow, state)
	end

	return true
end

local function variantMatches(variant, state)
	local conditions = variant.Conditions or variant.When
	if not conditions then
		return true
	end

	if not passesBoolCondition(conditions.Air, state.Air) then
		return false
	end

	if not passesBoolCondition(firstNonNil(conditions.Jump, conditions.Space), state.Jump) then
		return false
	end

	if not passesBoolCondition(firstNonNil(conditions.Block, conditions.Blocking), state.Block) then
		return false
	end

	if not passesHpCondition(firstNonNil(conditions.HPAtOrBelow, conditions.HealthAtOrBelow), state) then
		return false
	end

	if not passesHpTableCondition(firstNonNil(conditions.HP, conditions.Health), state) then
		return false
	end

	return true
end

local function getPriority(variant)
	return variant.Priority or 0
end

local function getSortedVariants(move)
	local sorted = {}

	for index, variant in ipairs(move.Variants or {}) do
		table.insert(sorted, {
			Index = index,
			Variant = variant,
		})
	end

	table.sort(sorted, function(a, b)
		local aPriority = getPriority(a.Variant)
		local bPriority = getPriority(b.Variant)

		if aPriority == bPriority then
			return a.Index < b.Index
		end

		return aPriority > bPriority
	end)

	return sorted
end

function SkillSystem:GetSkillModule(skillName: string)
	if not skillName then
		return nil
	end

	if skillCache[skillName] then
		return skillCache[skillName]
	end

	local moduleScript = script:FindFirstChild(skillName)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		warn(`No skill module named "{skillName}" exists under SkillSystem.`)
		return nil
	end

	local skillModule = require(moduleScript)
	skillCache[skillName] = skillModule
	return skillModule
end

function SkillSystem:ResolveMove(player: Player, move, inputState)
	local state = getPlayerState(player, inputState)
	local baseSkillName = move.Skill or move.SkillName or move.Id or move.Name

	for _, entry in ipairs(getSortedVariants(move)) do
		local variant = entry.Variant

		if variantMatches(variant, state) then
			local skillName = variant.Skill or variant.SkillName or variant.Module or baseSkillName
			local variantName = variant.Id or variant.Variant or variant.Name
			local displayName = variant.DisplayName or variant.Name or move.Name

			return {
				Move = move,
				SkillName = skillName,
				Skill = skillName,
				Variant = variant,
				VariantName = variantName,
				DisplayName = displayName,
				Cooldown = firstNonNil(variant.Cooldown, move.Cooldown, 0),
				IsVariant = true,
				State = state,
			}
		end
	end

	return {
		Move = move,
		SkillName = baseSkillName,
		Skill = baseSkillName,
		Variant = nil,
		VariantName = nil,
		DisplayName = move.Name,
		Cooldown = move.Cooldown or 0,
		IsVariant = false,
		State = state,
	}
end

function SkillSystem:Play(player: Player, move, inputState)
	local result = self:ResolveMove(player, move, inputState)

	if player:GetAttribute("State_CanSkill") == false then
		result.BlockedByState = true
		result.BlockedReason = player:GetAttribute("State_Primary") or "StateLocked"
		return result
	end

	local skillModule = self:GetSkillModule(result.SkillName)

	if not skillModule then
		return result
	end

	local play = skillModule.Play or skillModule.Activate
	if typeof(play) ~= "function" then
		warn(`Skill module "{result.SkillName}" does not have a Play or Activate function.`)
		return result
	end

	play(player, result)
	return result
end

return SkillSystem