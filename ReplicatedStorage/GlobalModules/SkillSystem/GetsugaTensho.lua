-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HitboxSystem = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("HitboxSystem"))

local GetsugaTensho = {}

function GetsugaTensho.Play(player: Player, context)
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
		AttachTo = root,
		Offset = CFrame.new(0, 0, -4),
		Shape = "Box",
		Size = Vector3.new(7, 5, 8),
		Duration = 0.18,
		TickRate = 1 / 60,
		Ignore = { character },
		IgnoreSameTeam = true,
		MaxTargetsPerScan = nil,
		Debug = true,
		DebugColor = Color3.fromRGB(255, 230, 80),

		Validate = function(result)
			return result.Humanoid ~= nil
		end,

		OnHit = function(result)
			print(`{context.DisplayName} hit {result.Model.Name}`)
		end,
	})
end

return GetsugaTensho