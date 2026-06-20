-- @ScriptType: ModuleScript
local GetsugaTensho = {}

function GetsugaTensho.Play(player: Player, context)
	print(`Playing {context.SkillName} for {player.Name}`)
end

return GetsugaTensho