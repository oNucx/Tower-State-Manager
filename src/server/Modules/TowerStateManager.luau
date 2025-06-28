--Whether this gets approved or not, please provide feedback on how I can improve my coding abilities
--Thank you for reviewing this application!--]]

--This is my attempt at a state manager. This module manages everything related to the different states of the "Tower"
local TowerStateManager = {}
TowerStateManager.__index = TowerStateManager

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

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

--Constants mainly used when tweening or attacking. This makes the code more organized, dynamic and easier to de-bug
local ATTACK_VARIABLES = {
	TWEEN_TRANSITION_TIME = 0.5, --Mainly used between the different attack states
	MAXIMUM_COST = 10, --The maximum budget or cost for each attack sequence. Explained in greater detail under StartAttack()
	SPIKE_AMOUNT = 10, --Amount of waves the IceSpike attack will generate
	ORIENTATION = 360, --Used to rotate the object when tweening
	ANGLE = 360 / 5, --Angle between the different spikes in the IceSpike attack. In this case, creating a pentagon formation
}

--Stores the different objects an attack uses in a dictionary. Makes modifying attacks easier
--I decided to use a function as the position, mainly for the projectile which needs a defined variable in order to function properly
local DifferentAttacks = {
	projectile = {
		object = Instance.new("Part"),
		name = "Projectile",
		tag = "Ignore",
		size = Vector3.new(1, 1, 1),
		position = function(emitter)
			local RandomNumber = Random.new()
			local EmitterPosition = emitter.Position
			return Vector3.new(
				RandomNumber:NextNumber(EmitterPosition.X - 30, EmitterPosition.X + 30),
				RandomNumber:NextNumber(EmitterPosition.Y + 5, EmitterPosition.Y + 15),
				RandomNumber:NextNumber(EmitterPosition.Z - 30, EmitterPosition.Z + 30)
			)
		end,
		color = Color3.new(0.862745, 0.87451, 0.168627),
		anchored = false,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Block,
	},

	bomb = {
		object = Instance.new("Part"),
		name = "Bomb",
		tag = "Ignore",
		size = Vector3.new(3, 3, 3),
		position = function(emitter)
			return emitter.Position
		end,
		color = Color3.new(0.745098, 0.294118, 0.262745),
		anchored = false,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Block,
	},
	explosion = {
		object = Instance.new("Part"),
		name = "Explosion",
		tag = "Ignore",
		size = Vector3.new(15, 15, 15),
		position = function(bomb)
			return bomb.Position
		end,
		color = Color3.new(0.745098, 0.294118, 0.262745),
		anchored = true,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
	},
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

--Returns the state the tower is in when called
function TowerStateManager:GetState()
	return self.state
end

--Returns the AttackState the tower is in when called
function TowerStateManager:GetAttackState()
	return self.AttackState
end

--[[A centralized function used when changing the appearance of the emitter. The function uses the variables color, position and orientation for the change in appearance 
--as well as time for how long the tween should last. This makes the code more dynamic instead of repeating the code every time
--the towers looks should update]]
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

--Cancels any tween which is running
function TowerStateManager:CancelTween()
	for _, tween in pairs(self.CurrentTween) do
		tween:Cancel()
	end
end

--Sets state and AttackState to nil, removing any previous state. Then the function waits until the tower is finished attacking before continuing the UpdateState() function (shown later on)
function TowerStateManager:RemoveLastState()
	self.state, self.AttackState = nil
	self.finishedAttacking = true
	while not self.finishedAttacking do
		print("Waiting")
		task.wait()
	end
end

-- Runs the chosen attack pattern in a loop until its "cost" exceeds MAXMIMUM_COST
--This function is the primary loop for any attack in this module
function TowerStateManager:StartAttack(randomAttack)
	--[[MaximumCost works as a "total cost" before changing attacks. Let's say the attack chosen is IceSpikes. After the attack, the IceSpikes function returns a number. This number is then
	added to the CurrentCost variable. Then it runs an if statement checking if the MaximumCost is lower than the CurrentCost. 
	The while-loop will run again if this is not the case. Now, since the IceSpike attack is a pretty big attack, it will also return a big number (higher cost), which will
	result in fewer iterations of the IceSpikes attack. But if the attack is, let's say, "Shooting", which only fires one projectile
	before it returns a number, the scale of the attack is much smaller and quicker, resulting in a lower number ("cost) and more iterations of the attack.
	So the MaximumAttacks variables does not act as the amount of attacks the state will do, but acts as a limit for how many points a given attackstate can use before the total cost of the 
	attack used exceeds the maximum cost.]]

	local MaximumCost = ATTACK_VARIABLES.MAXIMUM_COST
	local CurrentCost = 0
	while self:GetAttackState() == randomAttack do
		--If there are no players in the game, there are no one to attack, so the tower will transition to the "Idle" state
		if #Players:GetChildren() == 0 then
			self:UpdateState("idle")
			return
		end

		if self.state == nil then
			self.finishedAttacking = true
			break
		end

		--Calls a random attack based on the attack chosen
		local numberRecieved = TowerStateManager[randomAttack](self)

		CurrentCost += numberRecieved
		numberRecieved = nil
		if MaximumCost < CurrentCost then
			self.finishedAttacking = true
			print("Finished attack")
			break
		end
	end

	--When an attack is finished and attackstate is not nil, then calls ChangeAttackingState to change attack.
	--If not, then updates the current state to idle
	if self:GetAttackState() ~= nil then
		print("Changing attack")
		self:ChangeAttackingState()
	else
		self:UpdateState("idle")
	end
end

--When called, and if in the "attacking" state, chooses a new attack, makes visual changes to the emitter and calls the StartAttack function menthioned above
function TowerStateManager:ChangeAttackingState()
	if self.state ~= "attacking" then
		print("not in attacking state")
		return
	end

	local randomAttack

	--This repeat-until loop makes it certain that a new attack is chosen using math.random to find a new attack and a condition checking if the attack chosen is not the previous attack
	repeat
		print("Changing attack")
		randomAttack = AttackStates[math.random(1, #AttackStates)]
		task.wait()
	until randomAttack ~= self.AttackState

	self.AttackState = randomAttack

	--Waits until the tower is finished attacking. Every time an iteration of an attack is finished, self.finishedAttacking is set to true.
	--This prevents multiple attacks from running at the same time
	if not self.finishedAttacking then
		repeat
			print("Not finished attacking")
			task.wait()
		until self.finishedAttacking
	end

	--Changes the tween using the ChangeTween function. This statically changes the emitter's color, position and orientation. Since the tower is stationary, I created an EmitterAlignmentPart
	--for the emitter object to align with.
	if self.AttackState == "Shooting" then
		self:ChangeTween(
			Color3.new(0.862745, 0.87451, 0.168627),
			self.tower.EmitterAlignmentPart.Position,
			Vector3.new(0, 0, 0),
			ATTACK_VARIABLES.TWEEN_TRANSITION_TIME
		)
	elseif self.AttackState == "Eruption" then
		self:ChangeTween(
			Color3.new(0.745098, 0.294118, 0.262745),
			self.tower.EmitterAlignmentPart.Position,
			Vector3.new(0, 0, 0),
			ATTACK_VARIABLES.TWEEN_TRANSITION_TIME
		)
	elseif self.AttackState == "IceSpikes" then
		self:ChangeTween(
			Color3.new(0.231373, 0.741176, 0.866667),
			self.tower.EmitterAlignmentPart.Position,
			Vector3.new(0, 0, 0),
			ATTACK_VARIABLES.TWEEN_TRANSITION_TIME
		)
	else
		warn("Invalid state when changing state")
		return
	end

	--Moves the emitter to a pre-defined position if it's not already there
	if self.emitter.Position ~= self.tower.EmitterAlignmentPart.Position then
		self:ChangeTween(nil, self.tower.EmitterAlignmentPart.Position, nil, ATTACK_VARIABLES.TWEEN_TRANSITION_TIME)
	end

	self.finishedAttacking = false
	self:StartAttack(randomAttack)
end

--This function works as a transition between the tower's previous state and new state. Every time a state is updated, this function is called
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

	--Removes previous state
	self:RemoveLastState()
	--Cancels any tween playing
	self:CancelTween()

	self.state = newState

	--Initializes the new state
	self:StartState(self.state)
end

--When called, checks the state given and calls the function associated to the new state. If the state is "attacking", then it will call the ChangeAttackState.
--This function picks a random attack which is then later called in the StartAttack function.
function TowerStateManager:StartState(state)
	if state == "attacking" then
		if #Players:GetChildren() == 0 then
			warn("No players found")
			self:UpdateState("idle")
			return
		end

		self:ChangeAttackingState()
	elseif state == "idle" then
		self:Idle()
	elseif state == "inspecting" then
		self:Inspecting()
	else
		warn("Invalid state: " .. state)
		return
	end
end

--This idle state does nothing other than change the emitter's properties
function TowerStateManager:Idle()
	if self.state ~= "idle" then
		warn("Cannot set to idle when not in idle state")
		return
	end

	local orientation = ATTACK_VARIABLES.ORIENTATION

	self:ChangeTween(
		Color3.new(0, 0, 0), --Color
		self.tower.EmitterAlignmentPart.Position, --Position
		Vector3.new(orientation, orientation, 0), --Orientation
		3 --Time
	)
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

	self:ChangeTween(
		Color3.new(0.505882, 0.254902, 0.792157),
		self.tower.EmitterAlignmentPart.Position,
		Vector3.new(0, 0, 0),
		2
	)

	if self:GetState() == "inspecting" then
		self:UpdateState("attacking")
	else
		self:UpdateState("idle")
	end
end

--Creates a new attack object using the module ProjectileHandler. The attack is chosen based on it's name, which is stoer in the
--DifferentAttacks dictionary. Then assings the value of each key respectively
local function _spawnAttack(emitter, attackName)
	local reference = DifferentAttacks[attackName]

	local attack = ProjectileHandler.new(
		reference.object,
		reference.name,
		reference.tag,
		reference.size,
		reference.position(emitter),
		reference.color,
		reference.anchored,
		reference.material,
		reference.shape
	)

	return attack
end

--[[When called, changes the player target by getting a random player from Players, using several guard clauses to check if the validity of the player.
	This function is used when in the "Shooting" state as it, since the emitter is only shooting at one player at the time while in this state.
	The reason I only return the HumanoidRootPart is because it's the only variable I use in the "Shooting" function from the character]]
local function _ChangePlayerTarget()
	--Changes the player target every 1.5 seconds by selecting a random player inside the game
	local PlayerTarget = Players:GetChildren()[math.random(1, #Players:GetChildren())]
	local character = PlayerTarget.Character
	if not character then
		warn("No humanoid root part found on " .. PlayerTarget.Name)
		return
	end
	local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then
		warn("No humanoid root part found on " .. PlayerTarget.Name)
		return
	end

	return HumanoidRootPart
end

--When called,
function TowerStateManager:Shooting()
	local HumanoidRootPart = _ChangePlayerTarget()

	if self:GetAttackState() == nil then
		self:UpdateState("idle")
		return
	end

	--Creates a new projectile by calling the _spawnAttack function. The object which _spawnAttack will create is specified by the name given
	local projectile = _spawnAttack(self.emitter, "projectile")

	--Adjusts the emitters CFrame to the character it's targetting
	self.emitter.CFrame = CFrame.new(self.emitter.Position, HumanoidRootPart.Position)

	--Using LinearVelocity to determine the speed and direction of the projectile. I use .Unit to make it more managable to adjust the speed by multiplying a constant
	--This also gives me the ability to use whole numbers instead of rational numbers which makes the code cleaner
	projectile.object.LinearVelocity.VectorVelocity = (HumanoidRootPart.Position - projectile.object.Position).Unit * 60
	projectile.object.Parent = workspace

	--Uses the debris service to destory the projectile after 3 seconds
	Debris:AddItem(projectile.object, 3)

	task.wait(0.05)
	--These are the points I talked about in the StartAttack function. I statically return a smaller number here so the attack can keep spawning new projectiles over longer periods of time
	--instead of having a larger number which will call the "Shooting" function fewer times
	return 0.06
end

--When called, picks a random number which is then later used to launch the bomb with a force
local function _fireBomb(bomb)
	bomb.Parent = workspace

	local RandomNumber = Random.new()

	--Uses VectorForce to apply a force on the bomb which acts positively in the Y-direction. This functions as custom gravity for the object
	bomb.VectorForce.Force = Vector3.new(0, 150, 0) * bomb:GetMass()

	--Sends a bomb at a random speed and angle in the 3D-space using AssemblyLinearVelocity
	bomb.AssemblyLinearVelocity = Vector3.new(
		RandomNumber:NextNumber(-2, 2),
		RandomNumber:NextNumber(1, 2),
		RandomNumber:NextNumber(-2, 2)
	) * bomb:GetMass()
end

--When called, creates a bomb object and launches it using the _fireBomb function. Then assigns a touched event to the bomb object which creates an explosion if the right conditions are met
function TowerStateManager:Eruption()
	if self.state ~= "attacking" then
		warn("Cannot shoot when not in attacking state")
		return
	end

	local bomb = _spawnAttack(self.emitter, "bomb")

	_fireBomb(bomb.object)

	--If bomb hits any object with the "CanHit" tag, then a new object (explosion) is created and parented (spawned) inside the workspace. The bomb object is then destroyed and erased from memory
	bomb.object.Touched:Connect(function(ObjectHit)
		if CollectionService:GetTags(ObjectHit)[1] ~= "CanHit" then
			return
		end

		local explosion = _spawnAttack(bomb.object, "explosion")

		explosion.object.Parent = workspace

		Debris:AddItem(explosion.object, 3)

		bomb.object:Destroy()
		bomb.object = nil
	end)

	task.wait(0.3)
	return 0.6
end

--When called, positions the IceSpike object relative to the tower's bottom part using sinus and cosine
local function _PositionIceSpike(self, IceSpike, angle, radius)
	--
	local radian = math.rad(angle)
	local sin = math.sin(radian) * radius
	local cos = math.cos(radian) * radius
	--Adding cosine onto the X-axis and sine to the Z-axis creates an invinsible 2D-circle. By adjusing the angle, and therefor the radian, sine and cosine,
	--the IceSpike's X and Z position will change along the arc of the circle
	local IceSpikeVector = Vector3.new(
		self.tower.BottomPart.Position.X + cos,
		self.tower.BottomPart.Position.Y + IceSpike.PrimaryPart.Size.Y / 2,
		self.tower.BottomPart.Position.Z + sin
	)

	--Since the IceSpike object is a pre-made model I made, PivotTo is used to move the model's PrimaryPart (and since everything is welded to the primary part, it moves all children of the model)

	IceSpike:PivotTo(CFrame.new(IceSpikeVector))

	IceSpike.Parent = workspace
end

--[[Creates 5 ice spikes by cloning the IceSpike model stored in ServerStorage.
Then it positions each spike by calling  _PositionIceSpikEach. 
The ice spikes will be positioned 72 degrees apart from eachother, which is determined by the ATTACK_VARIABLES.ANGLE. ]]

local function _spawnIceSpikes(self, radius, angle)
	for _ = 1, 5 do
		angle += ATTACK_VARIABLES.ANGLE

		--Clones a
		local IceSpike = ServerStorage.IceSpike:Clone()

		for _, member in pairs(IceSpike:GetChildren()) do
			member.Color = self.emitter.Color
		end
		Debris:AddItem(IceSpike, 1)

		_PositionIceSpike(self, IceSpike, angle, radius)
	end
end

--[[When called, creates 10 waves of ice spike formations traveling outwards determined by the radius and angle. 
	The newest wave will have a 5 studs longer radius than the previous wave.
	Notice that I have used math.random at to the determine the angle, creating unique patterns each attack.]]
local function _moveIceSpikes(self)
	local radius = 0
	for _ = 1, 10 do
		if self.state == nil then
			self.finishedAttacking = true
			break
		end

		local angle = math.random(0, 360 / 10)

		radius += 5

		_spawnIceSpikes(self, radius, angle)

		task.wait(0.2)
	end
end

--When called, uses tweenService to create a slam animation and then calls the _moveIceSpikes function. By splitting the functionality
--of the IceSpikes attackstate into smaller functions, it is easier to de-bug and makes the code more organized and easier to read
function TowerStateManager:IceSpikes()
	if self.state ~= "attacking" then
		warn("Cannot shoot when not in attacking state")
		return
	end

	self:ChangeTween(nil, self.tower.EmitterTopPosition.Position, nil, 1)

	self:ChangeTween(nil, self.tower.EmitterBottomPosition.Position, nil, 0.2)

	_moveIceSpikes(self)

	--Returns a high number, so fewer iterations of this attack will be performed before switching to the next attack
	return 3
end

return TowerStateManager
