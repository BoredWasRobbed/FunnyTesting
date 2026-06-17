-- @ScriptType: ModuleScript
--!strict
export type Action = typeof(script.ActionTemplate)
type KeybindImpl = {
	CurrentContext: string,
	EnableContext: (context: string) -> (),
	GetAction: (context: string, name: string) -> Action	
}

type KeybindContext = {
	context: InputContext,
	keybinds: { [string]: Action }
}

-- module table:
local Keybind = {
	CurrentContext = ""
} :: KeybindImpl

-- constant variables
local ACTION_TEMPLATE = script.ActionTemplate
local ALWAYS_ON_STATE = "Idle" -- this state will always be on

-- Private variables
local keybinds: { [string]: KeybindContext } = {}

-- Private functions
local function getContext(name: string): KeybindContext
	if keybinds[name] == nil then
		local context = Instance.new("InputContext")
		context.Enabled = name == ALWAYS_ON_STATE
		context.Name = name
		context.Parent = script
		
		keybinds[name] = {
			context = context,
			keybinds = {}
		}
	end
	return keybinds[name]
end

local function getEmptyAction(): Action
	return ACTION_TEMPLATE:Clone()
end

-- Global methods
function Keybind.GetAction(context, name)
	local context = getContext(context)
	
	local action = context.keybinds[name]
	if action == nil then
		action = getEmptyAction()
		action.Name = name
		action.Parent = context.context
		
		for _, v in action:GetChildren() do
			local binding = v :: InputBinding
			local bindingName = v.Name
			
			binding:GetPropertyChangedSignal("KeyCode"):Connect(function()
				if binding.KeyCode == Enum.KeyCode.Unknown then return end
				
				-- cannot bind non-gamepad keycodes into gamepad binding
				local isGamepadBinding = (binding.KeyCode.Name:find("Button") ~= nil or
					binding.KeyCode.Name:find("DPad") ~= nil) and binding.KeyCode.Name:find("Mouse") == nil
				
				if (bindingName == "GamepadBinding") ~= isGamepadBinding then
					binding.KeyCode = Enum.KeyCode.Unknown
					warn("Invalid keybind provided. Gamepad bindings must only use gamepad buttons, and vice versa for keyboard.")
					return
				end
				
				
				-- loop to check for duplicates
				for otherName, v in context.keybinds do
					if v == action then continue end -- don't check itself
					
					if v[bindingName].KeyCode == binding.KeyCode then
						warn(`Conflicting keybinds found for {name} and {otherName}.`)
					end
				end
			end)
		end
		
		context.keybinds[name] = action
	end
	return action
end

function Keybind.EnableContext(context)
	for name, v in keybinds do
		v.context.Enabled = name == context or name == ALWAYS_ON_STATE
	end
	Keybind.CurrentContext = context
end

return Keybind

