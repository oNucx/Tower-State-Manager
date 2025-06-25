local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ChangeTowerState = ReplicatedStorage.Events.ChangeTowerState

local player = Players.LocalPlayer
local character = player.CharacterAdded:Wait()
local HumanoidRootPart = character:WaitForChild("HumanoidRootPart")

if not HumanoidRootPart then
	return
end

local Tower = workspace.Tower

local lastSteppedOn = nil
local currentSteppedOn = nil

RunService.RenderStepped:Connect(function()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character, CollectionService:GetTagged("Ignore") }

	local RaycastResult =
		workspace:Raycast(character:WaitForChild("Right Leg").Position, Vector3.new(0, -10, 0), raycastParams)

	lastSteppedOn = currentSteppedOn
	currentSteppedOn = RaycastResult.Instance

	if currentSteppedOn ~= lastSteppedOn and currentSteppedOn:IsDescendantOf(Tower) then
		ChangeTowerState:FireServer(true)
	elseif currentSteppedOn ~= lastSteppedOn and not currentSteppedOn:IsDescendantOf(Tower) then
		ChangeTowerState:FireServer(false)
	end
end)
