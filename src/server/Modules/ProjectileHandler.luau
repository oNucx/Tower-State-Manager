local CollectionService = game:GetService("CollectionService")
local ProjectileHandler = {}
ProjectileHandler.__index = ProjectileHandler

function ProjectileHandler.new(object, name, tag, size, position, color, anchored, material, shape)
	local self = setmetatable({}, ProjectileHandler)

	self.object = object:Clone()
	self.object.Name = name
	self.object.Size = size
	self.object.Position = position
	self.object.Color = color
	self.object.Anchored = anchored
	self.object.Material = material
	self.object.CanCollide = false
	self.object.Shape = shape

	CollectionService:AddTag(self.object, tag)

	local Attachment = Instance.new("Attachment")
	Attachment.Name = "ProjectileAttachment"
	Attachment.Parent = self.object

	if self.object.Name == "Projectile" then
		local LinearVelocity = Instance.new("LinearVelocity")
		LinearVelocity.Attachment0 = Attachment
		LinearVelocity.MaxForce = math.huge
		LinearVelocity.Parent = self.object
	elseif self.object.Name == "Bomb" then
		local VectorForce = Instance.new("VectorForce")
		VectorForce.Attachment0 = Attachment
		VectorForce.Parent = self.object
	end
	return self
end

return ProjectileHandler
