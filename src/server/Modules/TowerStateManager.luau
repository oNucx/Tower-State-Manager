--[[My previous application got declined since I had too much nesting in the code. I also used some deprecated API's
I have now reduced the amout of nesting by splitting the code into smaller functions, added more guard clauses and stopped using the outdated API
Whether this gets approved or not, please provide feedback on how I can improve my coding abilities
Thank you for reviewing this application!]]

--This is my attempt at a state manager. This module manages everything related to the different states of the "Tower"
local TowerStateManager = {}
TowerStateManager.__index = TowerStateManager

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local ProjectileHandler = require(script.Parent.ProjectileHandler)

--Different states and attack states
local States = {
	"idle",
	"inspecting",
	"attacking",
}

local AttackStates = {
	"Shooting",
	"Eruption",
	"IceSpikes",
}

--Creates and initializes the main tower used in this project
function TowerStateManager.new(tower, state)
	local self = setmetatable({}, TowerStateManager)
	self.tower = tower
	self.state = state
	self.finishedAttacking = true
	self.AttackState = nil
	self.emitter = self.tower:FindFirstChild("Emitter")

	self.CurrentTween = {}

	return self
end

--Returns State
function TowerStateManager:GetState()
	return self.state
end

--Returns AttackState
function TowerStateManager:GetAttackState()
	return self.AttackState
end

--Changes the tween of the emitter
function TowerStateManager:ChangeTween(color, position, orientation, time)
	local goal = {}
	goal.Color = color
	goal.Position = position
	goal.Orientation = orientation

	local tween = TweenService:Create(self.emitter, TweenInfo.new(time, Enum.EasingStyle.Linear), goal)
	table.insert(self.CurrentTween, tween)
	tween:Play()
	tween.Completed:Wait()
	table.clear(self.CurrentTween)
end

--Cancel's the tween
function TowerStateManager:CancelTween()
	for _, tween in pairs(self.CurrentTween) do
		tween:Cancel()
	end
end

--Sets state and AttackState to nil and waits for the attack to finish if the tower is attacking
function TowerStateManager:RemoveLastState()
	self.state, self.AttackState = nil
	while not self.finishedAttacking do
		task.wait()
	end
end

function TowerStateManager:BeginAttackingState()
	--The new AttackState cannot be it's previous AttackState. Also checks if the attack is finished to prevent multiple attack running at the same time
	--Then uses TweenService to adjust it's position and then starts the random attack selected
	while self.state == "attacking" do
		local randomAttack = AttackStates[math.random(1, #AttackStates)]

		if self.AttackState == randomAttack then
			continue
		end

		self.AttackState = randomAttack

		if not self.finishedAttacking then
			repeat
				task.wait()
			until self.finishedAttacking
		end

		if self.emitter.Position ~= self.tower.EmitterAlignmentPart.Position then
			self:ChangeTween(nil, self.tower.EmitterAlignmentPart.Position, nil, 0.5)
		end

		self.finishedAttacking = false
		TowerStateManager[randomAttack](self)

		print("State changed to: " .. self.AttackState)

		--Waits for 5 seconds and breaks while loop if state changes
		for _ = 1, 50 do
			if self.state ~= "attacking" then
				break
			end
			task.wait(0.1)
		end

		if self.state ~= "attacking" then
			break
		end
	end
end

--Updates the state of the tower and works as a transition between the different states
function TowerStateManager:UpdateState(newState)
	if not table.find(States, newState) then
		return
	end

	if not self.emitter then
		return
	end

	if self.state == newState then
		return
	end

	--Changes the tower's state and attackstate to nil and cancels any tweens that are playing
	self:RemoveLastState()
	self:CancelTween()

	self.state = newState

	--If state is "attacking", then selects a random AttackState
	if newState == "attacking" then
		if #Players:GetChildren() == 0 then
			warn("No players found")
			self:UpdateState("idle")
			return
		end

		self:BeginAttackingState()
	elseif newState == "idle" then
		self:Idle()
	elseif newState == "inspecting" then
		self:Inspecting()
	else
		warn("Invalid state: " .. newState)
		return
	end
end

--If idle, rotates 360 degrees around it's X and Y axis
function TowerStateManager:Idle()
	if self.state ~= "idle" then
		warn("Cannot set to idle when not in idle state")
		return
	end

	task.spawn(function()
		while self:GetState() == "idle" do
			local orientation = 360
			self:ChangeTween(
				Color3.new(0, 0, 0), --Color
				self.tower.EmitterAlignmentPart.Position, --Position
				Vector3.new(orientation, orientation, 0), --Orientation
				3 --Time
			)
			orientation += 360
		end
	end)
end

--[[The inspecting state is initialized when the player is in the tower's perimetter. If the tween gets completed (player has been long enough in tower's perimetter)
then the state changes to attack state. Otherwise, transitions to idle state.]]
function TowerStateManager:Inspecting()
	if self.state ~= "inspecting" then
		warn("Cannot set to inspecting when not in inspecting state")
		return
	end

	if not self.emitter then
		warn("Emitter not found in tower")
		return
	end

	task.spawn(function()
		while self:GetState() == "inspecting" do
			self:ChangeTween(
				Color3.new(0.505882, 0.254902, 0.792157),
				self.tower.EmitterAlignmentPart.Position,
				Vector3.new(0, 0, 0),
				4
			)

			if self:GetState() == "inspecting" then
				self:UpdateState("attacking")
			else
				self:UpdateState("idle")
			end
		end
	end)
end

--Shoots projectiles at the player
function TowerStateManager:Shooting()
	local PlayerTarget
	local character
	local HumanoidRootPart

	--Changes it's color
	task.spawn(function()
		self:ChangeTween(Color3.new(0.862745, 0.87451, 0.168627), nil, nil, 1)
	end)

	--Changes the player target every 1.5 seconds by selecting a random player inside the game
	local function TurnAndShootProjectiles()
		while self:GetAttackState() == "Shooting" do
			local RandomNumber = Random.new()

			PlayerTarget = Players:GetChildren()[math.random(1, #Players:GetChildren())]
			character = PlayerTarget.Character
			if not character then
				warn("No humanoid root part found on " .. PlayerTarget.Name)
				task.wait()
				continue
			end
			HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if not HumanoidRootPart then
				warn("No humanoid root part found on " .. PlayerTarget.Name)
				task.wait()
				continue
			end

			for _ = 1, 1.5 / 0.05 do
				if self:GetAttackState() == nil then
					self.finishedAttacking = true
					break
				end
				--adjusts it's CFrame to the character it's targetting
				self.emitter.CFrame = CFrame.new(self.emitter.Position, HumanoidRootPart.Position)

				--[[creates a projectile which has the properites: 
				object, name, tag, size, position, color, anchored, material and shape respectively]]
				local projectile = ProjectileHandler.new(
					Instance.new("Part"),
					"Projectile",
					"Ignore",
					Vector3.new(1, 1, 1),
					Vector3.new(
						RandomNumber:NextNumber(self.emitter.Position.X - 30, self.emitter.Position.X + 30),
						RandomNumber:NextNumber(self.emitter.Position.Y + 5, self.emitter.Position.Y + 15),
						RandomNumber:NextNumber(self.emitter.Position.Z - 30, self.emitter.Position.Z + 30)
					),
					self.emitter.Color,
					false,
					Enum.Material.Neon,
					Enum.PartType.Block
				)

				--Using LinearVelocity to fire the part at the location of the character's HumanoidRootPart
				projectile.object.Parent = workspace
				projectile.object.LinearVelocity.VectorVelocity = (
					HumanoidRootPart.Position - projectile.object.Position
				).Unit * 60

				--Destroys the projectile after 5 seconds
				Debris:AddItem(projectile.object, 5)

				task.wait(0.05)
			end
		end
		self.finishedAttacking = true
		coroutine.yield()
	end

	--Creates a coroutine which will start (resume) or wait/stop (yield) based on the tower's current state
	local turnAndShoot = coroutine.create(TurnAndShootProjectiles)

	coroutine.resume(turnAndShoot)
end

--Launches bombs in the air at random from the emitter's position
function TowerStateManager:Eruption()
	if self.state ~= "attacking" then
		warn("Cannot shoot when not in attacking state")
		return
	end

	--Visual changes
	task.spawn(function()
		while self:GetAttackState() == "Eruption" do
			local orientation = 360

			self:ChangeTween(Color3.new(0.745098, 0.294118, 0.262745), nil, Vector3.new(0, orientation, 0), 1)

			orientation += 360 or -360
		end
	end)

	local function LaunchBomb()
		while self:GetAttackState() == "Eruption" do
			local RandomNumber = Random.new()

			--Creates bomb
			local bomb = ProjectileHandler.new(
				Instance.new("Part"),
				"Bomb",
				"Ignore",
				Vector3.new(3, 3, 3),
				self.emitter.Position,
				self.emitter.Color,
				false,
				Enum.Material.Neon,
				Enum.PartType.Block
			)

			bomb.object.Parent = workspace

			--Uses VectorForce to apply a force on the bomb which acts positively in the Y-direction. This functions as custom gravity for the object
			bomb.object.VectorForce.Force = Vector3.new(0, 150, 0) * bomb.object:GetMass()

			--Sends a bomb at a random speed and angle in the 3D-space using AssemblyLinearVelocity
			bomb.object.AssemblyLinearVelocity = Vector3.new(
				RandomNumber:NextNumber(-2, 2),
				RandomNumber:NextNumber(1, 2),
				RandomNumber:NextNumber(-2, 2)
			) * bomb.object:GetMass()

			--If bomb hits the surface (in this case, the baseplate which is stored inside a map folder), it spawns an instance that acts as an explosion
			--"Comment": I realize that I could have used CollectionService instead of storing the objects the bomb can hit inside a map folder
			bomb.object.Touched:Connect(function(hit)
				if hit.Parent ~= workspace.Map then
					return
				end

				local explosion = ProjectileHandler.new(
					Instance.new("Part"),
					"Explosion",
					"Ignore",
					Vector3.new(15, 15, 15),
					bomb.object.Position,
					self.emitter.Color,
					true,
					Enum.Material.Neon,
					Enum.PartType.Ball
				)

				explosion.object.Parent = workspace

				Debris:AddItem(explosion.object, 3)

				bomb.object:Destroy()
				bomb.object = nil
			end)

			if bomb.object ~= nil then
				Debris:AddItem(bomb.object, 5)
			end

			task.wait(0.3)
		end
		self.finishedAttacking = true
		coroutine.yield()
	end

	--Same as before with the "Shooting" state
	local FireBomb = coroutine.create(LaunchBomb)

	coroutine.resume(FireBomb)
end

--Spawns Ice spikes from the ground around the tower which travel outwards
function TowerStateManager:IceSpikes()
	if self.state ~= "attacking" then
		warn("Cannot shoot when not in attacking state")
		return
	end

	local function SpawnIceSpikes()
		if self:GetAttackState() == nil then
			self.finishedAttacking = true
			return
		end

		local angle = math.random(0, 360 / 10)
		local radius = 5

		task.spawn(function()
			while self:GetAttackState() == "IceSpikes" do
				--[[Creates 5 ice spikes, each located 72 degrees apart from eachother. The spikes form a pentagon which travels outwards determined by the radius.
				I use sine and cosine to make this happen.]]
				for _ = 1, 5 do
					radius += 2
					angle += 360 / 5

					local radian = math.rad(angle)
					local sin = math.sin(radian) * radius
					local cos = math.cos(radian) * radius

					--Creates and pivots the position of a new clone from a pre-made IceSpike model
					local IceSpike = ServerStorage.IceSpike:Clone()
					IceSpike.Name = "NewSpike"
					IceSpike:PivotTo(
						CFrame.new(
							Vector3.new(
								self.tower.BottomPart.Position.X + cos,
								self.tower.BottomPart.Position.Y + IceSpike.PrimaryPart.Size.Y / 2,
								self.tower.BottomPart.Position.Z + sin
							)
						)
					)

					for _, member in pairs(IceSpike:GetChildren()) do
						member.Color = self.emitter.Color
					end
					IceSpike.Parent = workspace
					Debris:AddItem(IceSpike, 1)
				end
				task.wait(0.2)
			end
		end)
	end

	--This creates two different tween's with the goal of creating a slam animation. The emitter will rise and the slam down, which calls the SpawnIceSpikes function
	task.spawn(function()
		while self:GetAttackState() == "IceSpikes" do
			self:ChangeTween(Color3.new(0.231373, 0.741176, 0.866667), self.tower.EmitterTopPosition.Position, nil, 1)

			self:ChangeTween(nil, self.tower.EmitterBottomPosition.Position, nil, 0.2)

			SpawnIceSpikes()
			task.wait(0.5)
		end
		self.finishedAttacking = true
	end)
end

return TowerStateManager
