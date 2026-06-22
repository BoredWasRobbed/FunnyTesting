-- @ScriptType: ModuleScript
local Ragdoll = {}

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ActiveRagdolls = {} 

local SocketData = {
	Neck = {
		UpperAngle = 60, 
		TwistLowerAngle = -70, 
		TwistUpperAngle = 70
	}, 
	Shoulder = {
		UpperAngle = 170, 
		TwistLowerAngle = -85, 
		TwistUpperAngle = 85
	}, 
	Hip = {
		UpperAngle = 90, 
		TwistLowerAngle = -10, 
		TwistUpperAngle = 80
	}
};

function weldTogether(Clone, Part)
	local Weld = Instance.new("Weld");
	Weld.Part0 = Clone;
	Weld.Part1 = Part;
	local CloneCFrame = CFrame.new(Clone.Position);
	Weld.C0 = Clone.CFrame:inverse() * CloneCFrame;
	Weld.C1 = Part.CFrame:inverse() * CloneCFrame;
	Weld.Parent = Clone;
end;

function Ragdoll:Ragdoll(Character, Duration, Stacking)
	local Humanoid = Character:FindFirstChild("Humanoid")
	local Torso = Character:FindFirstChild("Torso")
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not Humanoid or not Torso or not HumanoidRootPart then return end;

	local Player = Players:GetPlayerFromCharacter(Character)

	if not Duration then
		Duration = 5
	end

	if Stacking == nil then
		Stacking = true
	end

	if ActiveRagdolls[Character] then
		if Stacking == true then
			ActiveRagdolls[Character] = ActiveRagdolls[Character] + Duration
		end
		return
	end

	ActiveRagdolls[Character] = Duration

	Humanoid.PlatformStand = true
	Humanoid.AutoRotate = false
	Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local Motors = {};
	for i,v in pairs(Character:GetDescendants()) do
		if v:IsA("Motor6D") and v.Part0 and v.Part1 then
			Motors[v.Part0] = true;
			Motors[v.Part1] = true;
		end
	end

	local BoneParts = {}
	for i,v in pairs(Character:GetChildren()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" and Motors[v] then
			local Part = v:Clone();
			Part:ClearAllChildren();
			Part.Transparency = 1;
			Part.Name = "Bone";
			Part.Size = Part.Size * 0.7;
			Part.CanCollide = true;
			Part.Parent = v;
			weldTogether(Part, v);
			if Part:CanSetNetworkOwnership() then
				pcall(function()
					Part:SetNetworkOwner(nil);
				end);
			end;
			table.insert(BoneParts, v);
		end;
	end

	for i,v in pairs(Torso:GetChildren()) do
		if v:IsA("Motor6D") then
			local a0 = Instance.new("Attachment");
			a0.Name = "RagdollAttach";
			a0.Parent = v.Part0;
			a0.CFrame = v.C0;
			CollectionService:AddTag(a0, "RagdollAttach");

			local a1 = Instance.new("Attachment");
			a1.Name = "RagdollAttach";
			a1.Parent = v.Part1;
			a1.CFrame = v.C1;
			CollectionService:AddTag(a1, "RagdollAttach");

			local socket = Instance.new("BallSocketConstraint");
			socket.Attachment0 = a0;
			socket.Attachment1 = a1;

			local Selected = nil;
			if v.Name:match("Neck") then
				Selected = SocketData.Neck;
			elseif v.Name:match("Shoulder") then
				Selected = SocketData.Shoulder;
			elseif v.Name:match("Hip") then
				Selected = SocketData.Hip;
			end;

			if Selected then
				socket.LimitsEnabled = true;
				socket.TwistLimitsEnabled = true;
				socket.UpperAngle = Selected.UpperAngle;
				socket.TwistUpperAngle = Selected.TwistUpperAngle;
				socket.TwistLowerAngle = Selected.TwistLowerAngle;
			end;

			socket.Name = "Socket" .. v.Name;
			socket.Parent = v.Parent;
			v.Part0 = nil;
		end;
	end;

	print("RAGDOLLED")

	Character:SetAttribute("IsRagdolled", true)


	task.spawn(function()
		while ActiveRagdolls[Character] and ActiveRagdolls[Character] > 0 do
			task.wait(0.1)
			ActiveRagdolls[Character] -= 0.1
		end

		ActiveRagdolls[Character] = nil

		HumanoidRootPart.CFrame = CFrame.new((HumanoidRootPart.CFrame * CFrame.Angles(0, math.rad(math.random(0, 359)), 0) * CFrame.new(0, math.random(0, 100) / 100, -1)).Position, HumanoidRootPart.Position)

		for i,v in pairs(Character:GetChildren()) do
			if v:IsA("BasePart") then
				local Bone = v:FindFirstChild("Bone")
				if Bone then
					Bone:Destroy()
				end

				pcall(function()
					v:SetNetworkOwner(Player);
				end);
			end
		end

		for i,v in pairs(Torso:GetChildren()) do
			if v:IsA("BallSocketConstraint") or v.Name == "RagdollAttach" then
				v:Destroy()
			elseif v:IsA("Motor6D") then
				v.Part0 = Torso
			end
		end

		Humanoid.PlatformStand = false
		Humanoid.AutoRotate = true

		Character:SetAttribute("IsRagdolled", false)

		Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)
end

function Ragdoll:Unragdoll(Character)
	local Humanoid, Torso, HumanoidRootPart = Character:FindFirstChild("Humanoid"), Character:FindFirstChild("Torso"), Character:FindFirstChild("HumanoidRootPart")
	if not Humanoid or not Torso or not HumanoidRootPart then return end;
	local Player = Players:GetPlayerFromCharacter(Character)

	HumanoidRootPart.CFrame = CFrame.new((HumanoidRootPart.CFrame * CFrame.Angles(0, math.rad(math.random(0, 359)), 0) * CFrame.new(0, math.random(0, 100) / 100, -1)).Position, HumanoidRootPart.Position)


	print("UNRAGDOLLED")


	for i,v in pairs(Character:GetChildren()) do
		if v:IsA("BasePart") then
			local Bone = v:FindFirstChild("Bone")
			if Bone then
				Bone:Destroy()
			end

			local success, err = pcall(function()
				v:SetNetworkOwner(Player);
			end);
		end
	end

	for i,v in pairs(Torso:GetChildren()) do
		if v:IsA("BallSocketConstraint") or v.Name == "RagdollAttach" then
			v:Destroy()
		elseif v:IsA("Motor6D") then
			v.Part0 = Torso
		end
	end

	Character:SetAttribute("IsRagdolled", false)
	Humanoid.PlatformStand = false
	Humanoid.AutoRotate = true
	Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

return Ragdoll