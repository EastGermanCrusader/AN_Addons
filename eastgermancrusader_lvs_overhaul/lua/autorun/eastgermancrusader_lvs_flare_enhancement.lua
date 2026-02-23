-- EastGermanCrusader LVS Overhaul - Flare Enhancement
-- Erweitert die Unity Flare-Entity um Hitzesignatur und Kollisionserkennung
-- Diese Datei erweitert das Unity Flares System aus dem Workshop-Addon

if not LVS then return end

print("[EastGermanCrusader LVS Overhaul] Lade Flare Enhancement System...")

-- Hook: Erweitere unity_flare Entity
hook.Add("PreRegisterSENT", "EastGermanCrusader_Flare_Enhancement", function(ent, class)
	if class ~= "unity_flare" then return end
	
	print("[Flare Enhancement] PreRegisterSENT Hook ausgeführt für unity_flare")
	
	-- Speichere die ursprüngliche Initialize-Funktion
	local OldInitialize = ent.Initialize
	
	-- Überschreibe Initialize um Hitzesignatur und Kollisionserkennung hinzuzufügen
	ent.Initialize = function(self)
		-- Rufe ursprüngliche Initialize-Funktion auf
		if OldInitialize then
			OldInitialize(self)
		end
		
		-- Setze Kollisionsgruppe auf NONE, damit Raketen Flares erkennen können
		self:SetCollisionGroup(COLLISION_GROUP_NONE)
		self:SetTrigger(true)
		
		-- Setze hohe Hitzesignatur für 80% Ablenkungswahrscheinlichkeit
		-- Flare-Stärke = 4 * Hitzesignatur, für 80% brauchen wir ~200 Flare-Stärke
		-- Das bedeutet Hitzesignatur = 50
		self._heatSignature = 50
		self.GetHeatSignature = function(self) return self._heatSignature or 50 end
		self.GetFlareStrength = function(self) return 4 * (self._heatSignature or 50) end
		
		print("[Flare Enhancement] Flare initialisiert mit Hitzesignatur: " .. (self._heatSignature or 50))
	end
	
	-- Erweitere StartTouch um Raketen-Detonation
	local OldStartTouch = ent.StartTouch
	ent.StartTouch = function(self, entity)
		if not IsValid(entity) then return end
		if self.EntsFilter and self.EntsFilter[entity] then return end
		
		-- Wenn eine Rakete die Flare berührt, lass die Rakete detonieren
		if entity:GetClass() == "lvs_missile" or string.find(entity:GetClass(), "missile") or string.find(entity:GetClass(), "torpedo") then
			if entity.Detonate then
				entity:Detonate(self)
			end
			self:Remove()
			return
		end
		
		-- Rufe ursprüngliche StartTouch-Funktion auf
		if OldStartTouch then
			OldStartTouch(self, entity)
		end
	end
	
	-- Erweitere PhysicsCollide um Raketen-Detonation
	local OldPhysicsCollide = ent.PhysicsCollide
	ent.PhysicsCollide = function(self, data, entity)
		local hitEnt = entity:GetEntity()
		if not IsValid(hitEnt) then return end
		
		if self.EntsFilter and (self.EntsFilter[hitEnt] or hitEnt:GetClass() == "trigger_teleport") then return end
		
		-- Wenn eine Rakete die Flare trifft, lass die Rakete detonieren
		if hitEnt:GetClass() == "lvs_missile" or string.find(hitEnt:GetClass(), "missile") or string.find(hitEnt:GetClass(), "torpedo") then
			if hitEnt.Detonate then
				hitEnt:Detonate(self)
			end
		end
		
		-- Rufe ursprüngliche PhysicsCollide-Funktion auf
		if OldPhysicsCollide then
			OldPhysicsCollide(self, data, entity)
		end
	end
end)

print("[EastGermanCrusader LVS Overhaul] Flare Enhancement System geladen!")
