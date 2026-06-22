-- @ScriptType: ModuleScript
local HttpService = game:GetService("HttpService")

local PlayerStateMachine = {}
PlayerStateMachine.__index = PlayerStateMachine

local DEFAULT_REPLICATED_STATES = {
	Airborne = true,
	Attacking = true,
	Blocking = true,
	Dashing = true,
	Dead = true,
	Endlag = true,
	Frozen = true,
	GuardBroken = true,
	IFrames = true,
	Knockback = true,
	MoveParry = true,
	Ragdolled = true,
	Spawning = true,
	Sprinting = true,
	Stunned = true,
	SuperArmor = true,
	UsingSkill = true,
}

local DEFAULT_STATE_DEFINITIONS = {
	Dead = {
		Priority = 1000,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Jump = true,
			Move = true,
			Skill = true,
			Sprint = true,
		},
		Cancels = {
			"Airborne",
			"Attacking",
			"Blocking",
			"Dashing",
			"Endlag",
			"Frozen",
			"GuardBroken",
			"Knockback",
			"MoveParry",
			"Ragdolled",
			"Sprinting",
			"Stunned",
			"UsingSkill",
		},
	},

	Spawning = {
		Priority = 900,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Skill = true,
		},
	},

	Stunned = {
		BlockedBy = {
			"Dead",
		},
		Priority = 800,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Jump = true,
			Move = true,
			Skill = true,
			Sprint = true,
		},
		Cancels = {
			"Attacking",
			"Blocking",
			"Dashing",
			"MoveParry",
			"Sprinting",
			"UsingSkill",
		},
	},

	Ragdolled = {
		BlockedBy = {
			"Dead",
		},
		Priority = 790,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Jump = true,
			Move = true,
			Skill = true,
			Sprint = true,
		},
		Cancels = {
			"Attacking",
			"Blocking",
			"Dashing",
			"MoveParry",
			"Sprinting",
			"UsingSkill",
		},
	},

	Frozen = {
		BlockedBy = {
			"Dead",
		},
		Priority = 780,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Jump = true,
			Move = true,
			Skill = true,
			Sprint = true,
		},
		Cancels = {
			"Attacking",
			"Blocking",
			"Dashing",
			"MoveParry",
			"Sprinting",
			"UsingSkill",
		},
	},

	GuardBroken = {
		BlockedBy = {
			"Dead",
		},
		Priority = 700,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Jump = true,
			Skill = true,
			Sprint = true,
		},
		Cancels = {
			"Blocking",
			"MoveParry",
		},
	},

	Knockback = {
		BlockedBy = {
			"Dead",
		},
		Priority = 650,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Skill = true,
		},
		Cancels = {
			"Attacking",
			"Blocking",
			"Dashing",
			"MoveParry",
			"Sprinting",
			"UsingSkill",
		},
	},

	UsingSkill = {
		Action = "Skill",
		Priority = 600,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Skill = true,
			Sprint = true,
		},
		Cancels = {
			"Blocking",
			"Sprinting",
		},
	},

	Attacking = {
		Action = "Attack",
		Priority = 550,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Skill = true,
			Sprint = true,
		},
		Cancels = {
			"Blocking",
			"Sprinting",
		},
	},

	MoveParry = {
		Priority = 525,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Skill = true,
			Sprint = true,
		},
		Cancels = {
			"Blocking",
			"Sprinting",
		},
	},

	Endlag = {
		Priority = 500,
		Blocks = {
			Attack = true,
			CharacterSwitch = true,
			Dash = true,
			Skill = true,
		},
	},

	Dashing = {
		Action = "Dash",
		Priority = 400,
		Blocks = {
			Attack = true,
			Block = true,
			CharacterSwitch = true,
			Dash = true,
			Skill = true,
			Sprint = true,
		},
		Cancels = {
			"Blocking",
			"Sprinting",
		},
	},

	Blocking = {
		Action = "Block",
		Priority = 300,
		Blocks = {
			Attack = true,
			CharacterSwitch = true,
			Dash = true,
			Sprint = true,
		},
		Cancels = {
			"Sprinting",
		},
	},

	Sprinting = {
		Action = "Sprint",
		Priority = 100,
		Blocks = {
			Block = true,
		},
	},

	Airborne = {
		Priority = 50,
	},

	IFrames = {
		Priority = 250,
	},

	SuperArmor = {
		Priority = 240,
	},
}

local DEFAULT_ACTION_DEFINITIONS = {
	Attack = {},
	Block = {},
	CharacterSwitch = {},
	Dash = {},
	Jump = {},
	Move = {},
	Skill = {},
	Sprint = {},
}

local LEGACY_ATTRIBUTES = {
	Attacking = "Attacking",
	Blocking = "Blocking",
	Dead = "Dead",
	Stunned = "Stunned",
	UsingSkill = "InSkill",
}

local function shallowCopy(source)
	local copy = {}

	for key, value in pairs(source or {}) do
		if typeof(value) == "table" then
			copy[key] = shallowCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function mergeInto(target, source)
	for key, value in pairs(source or {}) do
		if typeof(value) == "table" and typeof(target[key]) == "table" then
			mergeInto(target[key], value)
		elseif typeof(value) == "table" then
			target[key] = shallowCopy(value)
		else
			target[key] = value
		end
	end

	return target
end

local function getNow()
	return os.clock()
end

local function isInstance(value)
	return typeof(value) == "Instance"
end

local function getPlayerCharacter(subject)
	if isInstance(subject) and subject:IsA("Player") then
		return subject.Character
	end

	if isInstance(subject) and subject:IsA("Model") then
		return subject
	end

	return nil
end

local function setAttribute(instance, name, value)
	if isInstance(instance) then
		instance:SetAttribute(name, value)
	end
end

local function asDictionary(list)
	local dictionary = {}

	for key, value in pairs(list or {}) do
		if type(key) == "number" then
			dictionary[value] = true
		else
			dictionary[key] = value
		end
	end

	return dictionary
end

local function sanitizeValue(value)
	local valueType = typeof(value)

	if valueType == "boolean" or valueType == "number" or valueType == "string" then
		return value
	end

	if valueType == "Vector3" then
		return {
			X = value.X,
			Y = value.Y,
			Z = value.Z,
		}
	end

	if valueType == "CFrame" then
		local position = value.Position
		return {
			X = position.X,
			Y = position.Y,
			Z = position.Z,
		}
	end

	return nil
end

local function sanitizeData(data)
	local sanitized = {}

	for key, value in pairs(data or {}) do
		local cleanValue = sanitizeValue(value)
		if cleanValue ~= nil then
			sanitized[key] = cleanValue
		end
	end

	return sanitized
end

function PlayerStateMachine.new(subject, config)
	local self = setmetatable({}, PlayerStateMachine)

	config = config or {}

	self.Subject = subject
	self.Character = config.Character or getPlayerCharacter(subject)
	self.StateDefinitions = shallowCopy(DEFAULT_STATE_DEFINITIONS)
	self.ActionDefinitions = shallowCopy(DEFAULT_ACTION_DEFINITIONS)
	self.ReplicatedStates = shallowCopy(DEFAULT_REPLICATED_STATES)
	self.ReplicationEnabled = config.Replicate ~= false
	self.AttributePrefix = config.AttributePrefix or "State_"
	self.States = {}
	self.Serial = 0
	self.Listeners = {}
	self.Destroyed = false

	for stateName, definition in pairs(config.StateDefinitions or {}) do
		self:DefineState(stateName, definition)
	end

	for actionName, definition in pairs(config.ActionDefinitions or {}) do
		self:DefineAction(actionName, definition)
	end

	for stateName, replicated in pairs(config.ReplicatedStates or {}) do
		self.ReplicatedStates[stateName] = replicated
	end

	self:Replicate()
	return self
end

function PlayerStateMachine:DefineState(stateName, definition)
	self.StateDefinitions[stateName] = mergeInto(self.StateDefinitions[stateName] or {}, definition or {})
	return self
end

function PlayerStateMachine:DefineAction(actionName, definition)
	self.ActionDefinitions[actionName] = mergeInto(self.ActionDefinitions[actionName] or {}, definition or {})
	return self
end

function PlayerStateMachine:OnChanged(callback)
	table.insert(self.Listeners, callback)

	local disconnected = false
	return {
		Disconnect = function()
			if disconnected then
				return
			end

			disconnected = true

			for index, listener in ipairs(self.Listeners) do
				if listener == callback then
					table.remove(self.Listeners, index)
					break
				end
			end
		end,
	}
end

function PlayerStateMachine:FireChanged(stateName, reason)
	if self.Destroyed then
		return
	end

	self:Replicate()

	local snapshot = self:GetSnapshot()
	for _, listener in ipairs(self.Listeners) do
		listener(snapshot, stateName, reason, self)
	end
end

function PlayerStateMachine:BindCharacter(character)
	self.Character = character
	self:Replicate()
	return self
end

function PlayerStateMachine:GetAttributeTargets()
	local targets = {}

	if isInstance(self.Subject) then
		table.insert(targets, self.Subject)
	end

	if isInstance(self.Character) and self.Character ~= self.Subject then
		table.insert(targets, self.Character)
	end

	return targets
end

function PlayerStateMachine:SetAttributeOnTargets(name, value)
	for _, target in ipairs(self:GetAttributeTargets()) do
		setAttribute(target, name, value)
	end
end

function PlayerStateMachine:GetStateDefinition(stateName)
	return self.StateDefinitions[stateName] or {}
end

function PlayerStateMachine:GetActionDefinition(actionName)
	return self.ActionDefinitions[actionName] or {}
end

function PlayerStateMachine:HasState(stateName)
	return self.States[stateName] ~= nil
end

function PlayerStateMachine:GetState(stateName)
	return self.States[stateName]
end

function PlayerStateMachine:GetStateData(stateName)
	local state = self:GetState(stateName)
	return state and state.Data or nil
end

function PlayerStateMachine:GetCurrentSkill()
	local usingSkill = self:GetState("UsingSkill")
	if usingSkill then
		return usingSkill.Data.Skill or usingSkill.Data.SkillName
	end

	local parry = self:GetState("MoveParry")
	if parry then
		return parry.Data.Skill or parry.Data.SkillName
	end

	local attack = self:GetState("Attacking")
	if attack then
		return attack.Data.Skill or attack.Data.SkillName or attack.Data.MoveId
	end

	return nil
end

function PlayerStateMachine:IsCurrentSkill(skillName, castId)
	local usingSkill = self:GetState("UsingSkill") or self:GetState("MoveParry") or self:GetState("Attacking")
	if not usingSkill then
		return false
	end

	local data = usingSkill.Data
	local currentSkill = data.Skill or data.SkillName or data.MoveId
	if currentSkill ~= skillName then
		return false
	end

	if castId ~= nil and data.CastId ~= nil then
		return data.CastId == castId
	end

	return true
end

function PlayerStateMachine:GetPrimaryState()
	local bestName = nil
	local bestPriority = -math.huge

	for stateName in pairs(self.States) do
		local definition = self:GetStateDefinition(stateName)
		local priority = definition.Priority or 0

		if priority > bestPriority then
			bestName = stateName
			bestPriority = priority
		end
	end

	return bestName
end

function PlayerStateMachine:Can(actionName, context)
	context = context or {}

	if context.Force == true then
		return true
	end

	local actionDefinition = self:GetActionDefinition(actionName)
	local blockedBy = asDictionary(actionDefinition.BlockedBy)
	local required = asDictionary(actionDefinition.Required)

	for stateName in pairs(required) do
		if not self:HasState(stateName) then
			return false, `requires_{stateName}`
		end
	end

	for stateName in pairs(blockedBy) do
		if self:HasState(stateName) then
			return false, stateName
		end
	end

	for stateName, state in pairs(self.States) do
		local definition = self:GetStateDefinition(stateName)
		local blocks = definition.Blocks or {}

		if blocks.All or blocks[actionName] then
			if context.AllowSameSkill and self:IsCurrentSkill(context.Skill or context.SkillName, context.CastId) then
				continue
			end

			if context.IgnoreStates and context.IgnoreStates[stateName] then
				continue
			end

			return false, stateName, state
		end
	end

	if actionDefinition.Check and actionDefinition.Check(self, context) == false then
		return false, "action_check_failed"
	end

	return true
end

function PlayerStateMachine:CanEnterState(stateName, options)
	options = options or {}

	local definition = self:GetStateDefinition(stateName)
	local blockedBy = asDictionary(definition.BlockedBy)

	for blockingState in pairs(blockedBy) do
		if self:HasState(blockingState) then
			return false, blockingState
		end
	end

	if definition.Action then
		return self:Can(definition.Action, options.Data)
	end

	return true
end

function PlayerStateMachine:AddState(stateName, options)
	if self.Destroyed then
		return false, "destroyed"
	end

	options = options or {}

	if options.Force ~= true then
		local canEnter, reason = self:CanEnterState(stateName, options)
		if not canEnter then
			return false, reason
		end
	end

	local definition = self:GetStateDefinition(stateName)
	local now = getNow()
	local duration = options.Duration or options.Time or definition.Duration
	local data = mergeInto(shallowCopy(definition.Data or {}), options.Data or {})

	self.Serial += 1

	for _, cancelledState in ipairs(options.Cancels or definition.Cancels or {}) do
		self:RemoveState(cancelledState, `cancelled_by_{stateName}`, true)
	end

	local state = {
		Name = stateName,
		Data = data,
		Source = options.Source,
		StartedAt = now,
		ExpiresAt = duration and duration > 0 and now + duration or nil,
		Token = self.Serial,
	}

	self.States[stateName] = state

	if duration and duration > 0 then
		local token = state.Token
		task.delay(duration, function()
			local current = self.States[stateName]
			if current and current.Token == token then
				self:RemoveState(stateName, "expired")
			end
		end)
	end

	self:FireChanged(stateName, "added")
	return true, state
end

function PlayerStateMachine:RemoveState(stateName, reason, silent)
	local state = self.States[stateName]
	if not state then
		return false
	end

	self.States[stateName] = nil

	if not silent then
		self:FireChanged(stateName, reason or "removed")
	end

	return true, state
end

function PlayerStateMachine:ClearStates(options)
	options = options or {}
	local keep = options.Keep or {}
	local removed = false

	for stateName in pairs(self.States) do
		if not keep[stateName] then
			self.States[stateName] = nil
			removed = true
		end
	end

	if removed then
		self:FireChanged(nil, "cleared")
	end

	return removed
end

function PlayerStateMachine:ClearTransientStates()
	return self:ClearStates({
		Keep = {
			Dead = true,
		},
	})
end

function PlayerStateMachine:SetBlocking(active, data)
	if active then
		return self:AddState("Blocking", {
			Data = data,
			Source = data and data.Source or "StateMachine",
		})
	end

	return self:RemoveState("Blocking", "blocking_ended")
end

function PlayerStateMachine:SetSprinting(active, data)
	if active then
		return self:AddState("Sprinting", {
			Data = data,
			Source = data and data.Source or "StateMachine",
		})
	end

	return self:RemoveState("Sprinting", "sprinting_ended")
end

function PlayerStateMachine:Stun(duration, data)
	return self:AddState("Stunned", {
		Duration = duration,
		Data = data,
		Source = data and data.Source or "StateMachine",
		Force = data and data.Force,
	})
end

function PlayerStateMachine:GuardBreak(duration, data)
	return self:AddState("GuardBroken", {
		Duration = duration,
		Data = data,
		Source = data and data.Source or "StateMachine",
		Force = data and data.Force,
	})
end

function PlayerStateMachine:SetRagdolled(active, duration, data)
	if active then
		return self:AddState("Ragdolled", {
			Duration = duration,
			Data = data,
			Source = data and data.Source or "StateMachine",
			Force = data and data.Force,
		})
	end

	return self:RemoveState("Ragdolled", "ragdoll_ended")
end

function PlayerStateMachine:SetIFrames(active, duration, data)
	if active then
		return self:AddState("IFrames", {
			Duration = duration,
			Data = data,
			Source = data and data.Source or "StateMachine",
		})
	end

	return self:RemoveState("IFrames", "iframes_ended")
end

function PlayerStateMachine:SetSuperArmor(active, duration, data)
	if active then
		return self:AddState("SuperArmor", {
			Duration = duration,
			Data = data,
			Source = data and data.Source or "StateMachine",
		})
	end

	return self:RemoveState("SuperArmor", "super_armor_ended")
end

function PlayerStateMachine:StartAttack(moveId, duration, data)
	data = mergeInto({
		MoveId = moveId,
	}, data or {})

	return self:AddState("Attacking", {
		Duration = duration,
		Data = data,
		Source = data.Source or "StateMachine",
	})
end

function PlayerStateMachine:StartSkill(skillName, duration, data)
	data = mergeInto({
		Skill = skillName,
		SkillName = skillName,
	}, data or {})

	return self:AddState("UsingSkill", {
		Duration = duration,
		Data = data,
		Source = data.Source or "StateMachine",
	})
end

function PlayerStateMachine:EndSkill(skillName, castId)
	if skillName and not self:IsCurrentSkill(skillName, castId) then
		return false
	end

	return self:RemoveState("UsingSkill", "skill_ended")
end

function PlayerStateMachine:SetMoveParry(active, duration, data)
	if active then
		return self:AddState("MoveParry", {
			Duration = duration,
			Data = data,
			Source = data and data.Source or "StateMachine",
			Force = data and data.Force,
		})
	end

	return self:RemoveState("MoveParry", "move_parry_ended")
end

function PlayerStateMachine:SetParrying(active, duration, data)
	return self:SetMoveParry(active, duration, data)
end

function PlayerStateMachine:SetDashing(active, duration, data)
	if active then
		return self:AddState("Dashing", {
			Duration = duration,
			Data = data,
			Source = data and data.Source or "StateMachine",
		})
	end

	return self:RemoveState("Dashing", "dash_ended")
end

function PlayerStateMachine:SetAirborne(active, data)
	if active then
		return self:AddState("Airborne", {
			Data = data,
			Source = data and data.Source or "Humanoid",
			Force = true,
		})
	end

	return self:RemoveState("Airborne", "landed")
end

function PlayerStateMachine:SetDead(active)
	if active then
		return self:AddState("Dead", {
			Force = true,
			Source = "Humanoid",
		})
	end

	return self:RemoveState("Dead", "revived")
end

function PlayerStateMachine:GetSnapshot()
	local states = {}

	for stateName, state in pairs(self.States) do
		states[stateName] = {
			StartedAt = state.StartedAt,
			ExpiresAt = state.ExpiresAt,
			Source = state.Source,
			Data = sanitizeData(state.Data),
		}
	end

	return {
		States = states,
		PrimaryState = self:GetPrimaryState(),
		CurrentSkill = self:GetCurrentSkill(),
		CanAttack = self:Can("Attack"),
		CanBlock = self:Can("Block"),
		CanDash = self:Can("Dash"),
		CanMove = self:Can("Move"),
		CanSkill = self:Can("Skill"),
		CanSprint = self:Can("Sprint"),
	}
end

function PlayerStateMachine:Replicate()
	if not self.ReplicationEnabled then
		return
	end

	for stateName, replicated in pairs(self.ReplicatedStates) do
		if replicated then
			local active = self:HasState(stateName)
			self:SetAttributeOnTargets(self.AttributePrefix .. stateName, active or nil)
		end
	end

	for stateName, attributeName in pairs(LEGACY_ATTRIBUTES) do
		local active = self:HasState(stateName)
		self:SetAttributeOnTargets(attributeName, active or nil)
	end

	local currentSkill = self:GetCurrentSkill()
	local primaryState = self:GetPrimaryState()
	local snapshot = self:GetSnapshot()

	self:SetAttributeOnTargets(self.AttributePrefix .. "CurrentSkill", currentSkill)
	self:SetAttributeOnTargets(self.AttributePrefix .. "Primary", primaryState)
	self:SetAttributeOnTargets("CurrentSkill", currentSkill)

	self:SetAttributeOnTargets(self.AttributePrefix .. "CanAttack", snapshot.CanAttack)
	self:SetAttributeOnTargets(self.AttributePrefix .. "CanBlock", snapshot.CanBlock)
	self:SetAttributeOnTargets(self.AttributePrefix .. "CanDash", snapshot.CanDash)
	self:SetAttributeOnTargets(self.AttributePrefix .. "CanMove", snapshot.CanMove)
	self:SetAttributeOnTargets(self.AttributePrefix .. "CanSkill", snapshot.CanSkill)
	self:SetAttributeOnTargets(self.AttributePrefix .. "CanSprint", snapshot.CanSprint)

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(snapshot)
	end)

	if ok then
		self:SetAttributeOnTargets(self.AttributePrefix .. "Snapshot", encoded)
	end
end

function PlayerStateMachine:Destroy()
	if self.Destroyed then
		return
	end

	self:ClearStates()
	self.Destroyed = true
	table.clear(self.Listeners)
end

return PlayerStateMachine