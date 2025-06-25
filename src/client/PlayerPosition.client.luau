local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

print("Loading")

local ChangeTowerState = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ChangeTowerState")

local player = Players.LocalPlayer

while not player do
	player = Players.LocalPlayer
	task.wait()
end

local character = player.Character or player.CharacterAdded:Wait()

while not character:IsDescendantOf(workspace) do
	task.wait()
end

local HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
local RightLeg = character:FindFirstChild("Right Leg") or character:WaitForChild("RightFoot") -- R15 fallback

if not HumanoidRootPart or not RightLeg then
	warn("Required parts missing from character")
	return
end

local Tower = workspace:WaitForChild("Tower")

local lastSteppedOn = nil
local currentSteppedOn = nil

print("Ready")

RunService.Heartbeat:Connect(function()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {
		player.Character,
		table.unpack(CollectionService:GetTagged("Ignore")),
	}

	local rayOrigin = RightLeg.Position
	local rayDirection = Vector3.new(0, -10, 0)

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	lastSteppedOn = currentSteppedOn
	currentSteppedOn = raycastResult and raycastResult.Instance or nil

	if currentSteppedOn ~= lastSteppedOn then
		if currentSteppedOn and currentSteppedOn:IsDescendantOf(Tower) then
			print("Touching Tower Area")
			ChangeTowerState:FireServer(true)
		else
			ChangeTowerState:FireServer(false)
		end
	end
end)
