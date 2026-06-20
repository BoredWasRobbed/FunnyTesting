-- @ScriptType: ModuleScript
local SanktBogen = {}

function SanktBogen.Play(player: Player, context)
	print(`Playing {context.VariantName} variant of {context.Move.Name} for {player.Name}`)
end

return SanktBogen
