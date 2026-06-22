-- @ScriptType: ModuleScript
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HitboxSystem = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("HitboxSystem"))

local ParryCounter = {}

function ParryCounter.Play(player: Player, context)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	HitboxSystem.Create({
		Owner = player,
		SkillName = context.SkillName,
		MoveId = context.Move.Skill or context.Move.Name,
		ReportToServer = true,
		ReportStartToServer = true,
		StateDuration = 0.35,
		AttachTo = root,
		Offset = CFrame.new(0, 0, -3),
		Shape = "Box",
		Size = Vector3.new(8, 6, 8),
		Duration = 0.35,
		TickRate = 1 / 60,
		TargetMode = "Part",
		RequireHumanoid = false,
		Ignore = { character },
		Debug = true,
		DebugColor = Color3.fromRGB(255, 255, 255),

		MoveParry = {
			Enabled = true,
			ReflectProjectiles = true,
		},

		Validate = function(result)
			return result.Part:GetAttribute("ParryableProjectile") == true
				or CollectionService:HasTag(result.Part, "ParryableProjectile")
		end,
	})
end

return ParryCounter