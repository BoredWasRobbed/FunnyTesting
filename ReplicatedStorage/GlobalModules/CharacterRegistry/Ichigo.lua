-- @ScriptType: ModuleScript
local Ichigo = {}

Ichigo.Moveset = {
	["Vizard"] = {
		Type = "Special",
		Name = "Vizard",
		Bind = "R"
	},
	["GetsugaTensho"] = {
		Type = "BaseMove",
		Name = "GetsugaTensho",
		Bind = "1",
		Tooltip = "HOLD"
	},
	["VanishingJab"] = {
		Type = "BaseMove",
		Name = "VanishingJab",
		Bind = "2"
	},
	["Krash"] = {
		Type = "BaseMove",
		Name = "Krash",
		Bind = "3"
	},
	["Shunpo"] = {
		Type = "BaseMove",
		Name = "Shunpo",
		Bind = "4"
	}
}

function Ichigo.getMoveset()
	return Ichigo.Moveset
end

return Ichigo
