-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HitboxSystem = require(ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("HitboxSystem"))

local ExampleProjectileSkill = {}

function ExampleProjectileSkill.Play(player: Player, context)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	HitboxSystem.Projectile({
		Owner = player,
		SkillName = context.SkillName,
		MoveId = context.Move.Skill or context.Move.Name,
		ReportToServer = true,
		CFrame = root.CFrame * CFrame.new(0, 1, -3),
		Shape = "Sphere",
		Radius = 2.5,
		Duration = 3,
		TickRate = 1 / 60,
		Ignore = { character },
		IgnoreSameTeam = true,
		StopOnFirstHit = true,
		Debug = true,
		DebugColor = Color3.fromRGB(80, 180, 255),

		Projectile = {
			Direction = root.CFrame.LookVector,
			Speed = 120,
			MaxDistance = 180,
			FaceDirection = true,
		},

		OnHit = function(result)
			print(`{context.DisplayName} projectile hit {result.Model.Name}`)
		end,
	})
end

return ExampleProjectileSkill