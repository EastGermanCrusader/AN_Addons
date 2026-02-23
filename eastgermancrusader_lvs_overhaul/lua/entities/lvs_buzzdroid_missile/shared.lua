AddCSLuaFile()

ENT.Base = "lvs_missile"

ENT.Type = "anim"

ENT.PrintName = "Buzz Droid Missile"
ENT.Author = "EastGermanCrusader"
ENT.Information = "Deploys Buzz Droids ahead of target"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = false
ENT.AdminOnly = true

ENT.ExplosionEffect = "lvs_concussion_explosion"
ENT.GlowColor = Color(200, 150, 50, 255) -- Gelblich-orange für Buzz Droids

ENT.BuzzDroidCount = 8
ENT.DeployDistance = 500 -- Entfernung vor dem Ziel wo Buzz Droids spawnen
ENT.OvershootSpeed = 6000 -- Schneller als normale Raketen um zu überholen

if CLIENT then
	ENT.GlowMat = Material("sprites/light_glow02_add")

	function ENT:Enable()
		if self.IsEnabled then return end

		self.IsEnabled = true

		self.snd = CreateSound(self, "npc/combine_gunship/gunship_crashing1.wav")
		self.snd:SetSoundLevel(80)
		self.snd:Play()

		local effectdata = EffectData()
		effectdata:SetOrigin(self:GetPos())
		effectdata:SetEntity(self)
		util.Effect("lvs_concussion_trail", effectdata)
	end

	function ENT:Draw()
		if not self:GetActive() then return end

		self:DrawModel()

		render.SetMaterial(self.GlowMat)

		local pos = self:GetPos()
		local dir = self:GetForward()

		for i = 0, 30 do
			local Size = ((30 - i) / 30) ^ 2 * 100

			render.DrawSprite(pos - dir * i * 5, Size, Size, self.GlowColor)
		end
	end
end
