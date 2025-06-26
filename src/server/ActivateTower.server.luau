local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerStateManager = require(script.Parent.Modules.TowerStateManager)

local ChangeTowerState = ReplicatedStorage.Events.ChangeTowerState

local NewTower = TowerStateManager.new(workspace.Tower)

local Emitter = NewTower.emitter
local TowerArea = NewTower.tower.TowerArea
local CharacterInsideTowerArea = Emitter:FindFirstChild("CharacterInsideTowerArea")

NewTower:UpdateState("idle")

local function CheckIfInsideTowerArea(humanoidRootPart, area)
	local HumanoidRootPartPosition = humanoidRootPart.Position
	local TowerAreaPos = area.Position
	local TowerAreaSize = area.Size

	local minX = TowerAreaPos.X - TowerAreaSize.X / 2 - 5
	local maxX = TowerAreaPos.X + TowerAreaSize.X / 2 + 5
	local minZ = TowerAreaPos.Z - TowerAreaSize.Z / 2 - 5
	local maxZ = TowerAreaPos.Z + TowerAreaSize.Z / 2 + 5

	return HumanoidRootPartPosition.X >= minX
		and HumanoidRootPartPosition.X <= maxX
		and HumanoidRootPartPosition.Z >= minZ
		and HumanoidRootPartPosition.Z <= maxZ
end

ChangeTowerState.OnServerEvent:Connect(function(player, bool)
	local character = player.Character

	if not character then
		return
	end

	local HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
	if not HumanoidRootPart then
		return
	end

	if CheckIfInsideTowerArea(HumanoidRootPart, TowerArea) then
		if bool then
			print("Changing value")
			CharacterInsideTowerArea.Value = true
		else
			CharacterInsideTowerArea.Value = false
		end
	end
end)

CharacterInsideTowerArea.Changed:Connect(function()
	if CharacterInsideTowerArea.Value then
		print("inspecting")
		NewTower:UpdateState("inspecting")
	elseif not CharacterInsideTowerArea.Value then
		print("Idle")
		NewTower:UpdateState("idle")
	end
end)
