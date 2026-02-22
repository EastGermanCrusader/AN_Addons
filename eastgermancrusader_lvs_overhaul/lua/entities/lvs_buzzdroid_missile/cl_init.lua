include("shared.lua")

-- Client-seitige Initialisierung
function ENT:Initialize()
	-- Nichts spezielles benötigt
end

-- Cleanup bei Entfernung
function ENT:OnRemove()
	if self.snd then
		self.snd:Stop()
	end
end

-- Think für Client-seitige Aktivierung
function ENT:Think()
	if self.snd then
		self.snd:ChangePitch(100 * self:CalcDoppler())
	end

	if self.IsEnabled then return end

	if self:GetActive() then
		self:Enable()
	end
end

-- Doppler-Effekt Berechnung (geerbt von Base)
function ENT:CalcDoppler()
	local Ent = LocalPlayer()
	local ViewEnt = Ent:GetViewEntity()

	if Ent:lvsGetVehicle() == self then
		if ViewEnt == Ent then
			Ent = self
		else
			Ent = ViewEnt
		end
	else
		Ent = ViewEnt
	end

	local sVel = self:GetVelocity()
	local oVel = Ent:GetVelocity()

	local SubVel = oVel - sVel
	local SubPos = self:GetPos() - Ent:GetPos()

	local DirPos = SubPos:GetNormalized()
	local DirVel = SubVel:GetNormalized()

	local A = math.acos(math.Clamp(DirVel:Dot(DirPos), -1, 1))

	return (1 + math.cos(A) * SubVel:Length() / 13503.9)
end

function ENT:SoundStop()
	if self.snd then
		self.snd:Stop()
	end
end
