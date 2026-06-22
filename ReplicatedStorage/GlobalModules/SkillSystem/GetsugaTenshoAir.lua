-- @ScriptType: ModuleScript
local GetsugaTenshoAir = {}

function GetsugaTenshoAir.Play(player: Player, context)
	print(`Playing {context.VariantName} variant of {context.Move.Name} for {player.Name}`)
end

return GetsugaTenshoAir
