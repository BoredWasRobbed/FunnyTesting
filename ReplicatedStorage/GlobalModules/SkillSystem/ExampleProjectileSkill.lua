-- @ScriptType: ModuleScript
local Debris = game:GetService("Debris")
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

	local projectilePart = Instance.new("Part")
	projectilePart.Name = "ExampleProjectile"
	projectilePart.Shape = Enum.PartType.Ball
	projectilePart.Size = Vector3.new(2.5, 2.5, 2.5)
	projectilePart.Anchored = true
	projectilePart.CanCollide = false
	projectilePart.CanQuery = true
	projectilePart.CanTouch = false
	projectilePart.Material = Enum.Material.Neon
	projectilePart.Color = Color3.fromRGB(80, 180, 255)
	projectilePart.CFrame = root.CFrame * CFrame.new(0, 1, -3)
	projectilePart.Parent = workspace
	Debris:AddItem(projectilePart, 5)

	HitboxSystem.Projectile({
		Owner = player,
		SkillName = context.SkillName,
		MoveId = context.Move.Skill or context.Move.Name,
		ReportToServer = true,
		Parryable = true,
		CFrame = projectilePart.CFrame,
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
			Part = projectilePart,
			Direction = root.CFrame.LookVector,
			Speed = 120,
			ReflectionSpeedMultiplier = 1.15,
			MaxDistance = 180,
			FaceDirection = true,

			OnReflected = function()
				projectilePart.Color = Color3.fromRGB(255, 255, 255)
			end,
		},

		OnHit = function(result)
			print(`{context.DisplayName} projectile hit {result.Model.Name}`)
		end,
	})
end

return ExampleProjectileSkill