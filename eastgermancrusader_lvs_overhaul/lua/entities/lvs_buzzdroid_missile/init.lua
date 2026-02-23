AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Buzz Droid Konfiguration
-- Der Buzz Droid ist ein npc_manhack mit einem speziellen Model
EGC_BuzzDroidModel = "models/loic_buzzdroid/buzzdroid.mdl"

-- Überschreibe Geschwindigkeit für Überholmanöver
function ENT:GetSpeed()
	return (self._speed or self.OvershootSpeed)
end

function ENT:GetThrust()
	return (self._thrust or 800)
end

function ENT:GetTurnSpeed()
	return (self._turnspeed or 1.5) * 100
end

-- Hauptlogik für das Verfolgen und Überholen
function ENT:Think()
	local T = CurTime()

	self:NextThink(T)

	if not self.SpawnTime then return true end

	-- Nach 15 Sekunden ohne Treffer selbst zerstören
	if (self.SpawnTime + 15) < T then
		self:DeployBuzzDroids(self:GetPos())
		return true
	end

	-- Prüfe ob wir ein Ziel haben und ob wir es überholt haben
	local Target = self:GetTarget()
	
	if IsValid(Target) and self.IsEnabled then
		local myPos = self:GetPos()
		local targetPos = self:GetTargetPos()
		local targetVel = IsValid(Target) and Target:GetVelocity() or Vector(0,0,0)
		
		-- Berechne die relative Position zum Ziel
		local toTarget = targetPos - myPos
		local distToTarget = toTarget:Length()
		local dirToTarget = toTarget:GetNormalized()
		
		-- Berechne ob wir VOR dem Ziel sind (Rakete hat das Ziel überholt)
		local myForward = self:GetForward()
		local dotProduct = myForward:Dot(dirToTarget)
		
		-- Wenn wir nahe genug sind UND das Ziel hinter uns ist (wir haben überholt)
		-- ODER wenn wir sehr nah am Ziel sind
		if distToTarget < self.DeployDistance then
			-- Wenn die Rakete das Ziel überholt hat (Ziel ist jetzt hinter der Rakete)
			if dotProduct < 0.3 or distToTarget < 300 then
				self:DeployBuzzDroids(myPos)
				return true
			end
		end
	end

	return true
end

-- Spawne die Buzz Droids in einer Wolkenformation
function ENT:DeployBuzzDroids(pos)
	if self.Deployed then return end
	self.Deployed = true

	local attacker = self:GetAttacker()
	local Target = self:GetTarget()
	
	-- Sound-Effekt beim Deployment
	self:EmitSound("ambient/machines/thumper_dust.wav", 100, 120)
	
	-- Kleiner visueller Effekt
	local effectdata = EffectData()
	effectdata:SetOrigin(pos)
	effectdata:SetScale(0.5)
	util.Effect("cball_explode", effectdata, true, true)

	-- Spawne 8 Buzz Droids in einer Wolkenformation
	for i = 1, self.BuzzDroidCount do
		-- Berechne Position im Kreis mit etwas Zufälligkeit
		local angle = (i / self.BuzzDroidCount) * 360
		local rad = math.rad(angle)
		local radius = math.Rand(50, 150)
		local heightOffset = math.Rand(-100, 100)
		
		local offset = Vector(
			math.cos(rad) * radius,
			math.sin(rad) * radius,
			heightOffset
		)
		
		local spawnPos = pos + offset
		
		-- Trace um sicherzustellen, dass wir nicht in einer Wand spawnen
		local tr = util.TraceLine({
			start = pos,
			endpos = spawnPos,
			mask = MASK_SOLID_BRUSHONLY
		})
		
		if tr.Hit then
			spawnPos = tr.HitPos - tr.HitNormal * 10
		end
		
		-- Erstelle den Buzz Droid NPC (npc_manhack mit Buzz Droid Model)
		local capturedTarget = Target
		local capturedAttacker = attacker
		
		timer.Simple(i * 0.05, function()
			-- Erstelle npc_manhack mit Buzz Droid Model
			local buzzDroid = ents.Create("npc_manhack")
			
			if IsValid(buzzDroid) then
				buzzDroid:SetPos(spawnPos)
				buzzDroid:SetAngles(Angle(0, angle, 0))
				buzzDroid:Spawn()
				buzzDroid:Activate()
				
				-- Model NACH Spawn setzen (npc_manhack überschreibt es sonst)
				buzzDroid:SetModel(EGC_BuzzDroidModel)
				
				-- Setze den Besitzer/Attacker wenn möglich
				if IsValid(capturedAttacker) then
					if buzzDroid.SetOwner then
						buzzDroid:SetOwner(capturedAttacker)
					end
				end
				
				-- Gib dem Buzz Droid eine Anfangsgeschwindigkeit in Richtung Ziel
				if IsValid(capturedTarget) then
					local physObj = buzzDroid:GetPhysicsObject()
					if IsValid(physObj) then
						local dirToTarget = (capturedTarget:GetPos() - spawnPos):GetNormalized()
						physObj:SetVelocity(dirToTarget * 500)
					end
					
					-- Setze das Ziel als Feind
					if buzzDroid.AddEntityRelationship then
						buzzDroid:AddEntityRelationship(capturedTarget, D_HT, 99)
					end
				end
				
				-- Visueller Spawn-Effekt pro Droid
				local fxData = EffectData()
				fxData:SetOrigin(spawnPos)
				fxData:SetScale(0.3)
				util.Effect("ManhackSparks", fxData, true, true)
			end
		end)
	end

	-- Entferne die Rakete nach dem Deployment
	SafeRemoveEntityDelayed(self, 0.5)
end

-- Überschreibe Detonate um stattdessen Buzz Droids zu spawnen
function ENT:Detonate(target)
	if not self.IsEnabled or self.IsDetonated then return end

	self.IsDetonated = true

	local pos = self:GetPos()
	
	-- Bei Kollision auch Buzz Droids spawnen
	self:DeployBuzzDroids(pos)
end
