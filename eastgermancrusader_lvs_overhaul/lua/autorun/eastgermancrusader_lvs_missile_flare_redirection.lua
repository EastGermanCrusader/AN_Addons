-- EastGermanCrusader LVS Overhaul - Missile Flare Redirection
-- Überschreibt/ergänzt die Missile-Redirection-Logik für 80% Ablenkungswahrscheinlichkeit
-- Diese Datei erweitert das Unity Flares System aus dem Workshop-Addon
-- ALLE Raketen-Typen priorisieren Flares!

if not LVS then return end

print("[EastGermanCrusader LVS Overhaul] Lade Missile Flare Redirection System...")

-- ============================================
-- KONFIGURATION
-- ============================================

local FlareConfig = {
	-- Ablenkungswahrscheinlichkeit (0-1)
	RedirectChance = 0.8,
	
	-- Flare-Stärke für maximale Ablenkung
	FlareStrengthThreshold = 200,
	
	-- Kegel-Winkel für Flare-Erkennung (Grad)
	ConeAngle = 60,
	
	-- Maximale Reichweite für Flare-Erkennung
	MaxRange = 10000,
	
	-- Prüf-Intervall (Sekunden)
	CheckInterval = 0.1,
	
	-- Raketen-Klassen die Flares priorisieren sollen
	MissileClasses = {
		"lvs_missile",
		"lvs_concussionmissile",
		"lvs_protontorpedo",
		"lvs_buzzdroid_missile",
	},
}

-- ============================================
-- FLARE REDIRECTION LOGIK
-- ============================================

-- Zentrale Funktion für Flare-Redirection (kann von allen Raketen genutzt werden)
local function CheckFlareRedirection(missile)
	if not IsValid(missile) then return end
	if CLIENT then return end
	
	-- Prüfe ob Unity Flares System verfügbar ist
	if not UF or not UF.GetFlares then return end
	
	-- Hole aktuelles Ziel
	local target = nil
	if missile.GetNWTarget then
		target = missile:GetNWTarget()
	elseif missile.GetTarget then
		target = missile:GetTarget()
	end
	
	if not IsValid(target) then return end
	
	-- Prüfe nur wenn Ziel kein Flare ist
	if target:GetClass() == "unity_flare" then return end
	
	-- Prüfe alle Flares
	local flares = UF:GetFlares()
	if not istable(flares) or #flares == 0 then return end
	
	local missilePos = missile:GetPos()
	local missileForward = missile:GetForward()
	local coneAngleRad = math.sin(FlareConfig.ConeAngle / 180 * math.pi)
	
	local redirectFlare = nil
	local bestFlareStrength = 0
	local bestDistance = math.huge
	
	for _, flare in ipairs(flares) do
		if not IsValid(flare) then continue end
		
		local flarePos = flare:GetPos()
		local dist = missilePos:Distance(flarePos)
		
		-- Maximale Reichweite prüfen
		if dist > FlareConfig.MaxRange then continue end
		
		-- Prüfe ob Flare im Kegel vor der Rakete ist
		local isInCone = util.IsPointInCone(
			flarePos,
			missilePos,
			missileForward,
			coneAngleRad,
			FlareConfig.MaxRange
		)
		
		if not isInCone then continue end
		
		-- Berechne Flare-Stärke
		local flareStrength = 0
		if flare.GetFlareStrength then
			flareStrength = flare:GetFlareStrength()
		elseif flare._heatSignature then
			flareStrength = 4 * (flare._heatSignature or 50)
		else
			flareStrength = FlareConfig.FlareStrengthThreshold -- Standard-Wert
		end
		
		-- Berechne Ablenkungswahrscheinlichkeit
		local redirectChance = math.min(flareStrength / (FlareConfig.FlareStrengthThreshold * 1.25), 1.0)
		
		-- Wenn Flare-Stärke >= Threshold, dann volle Chance
		if flareStrength >= FlareConfig.FlareStrengthThreshold then
			redirectChance = FlareConfig.RedirectChance
		end
		
		-- Zufällige Entscheidung basierend auf Wahrscheinlichkeit
		if math.random() <= redirectChance then
			-- Prüfe ob dieser Flare besser ist (näher oder stärker)
			if flareStrength > bestFlareStrength or (flareStrength == bestFlareStrength and dist < bestDistance) then
				redirectFlare = flare
				bestFlareStrength = flareStrength
				bestDistance = dist
			end
		end
	end
	
	-- Wenn ein Flare gefunden wurde, leite die Rakete um
	if IsValid(redirectFlare) then
		if missile.SetTarget then
			missile:SetTarget(redirectFlare)
		elseif missile.SetNWTarget then
			missile:SetNWTarget(redirectFlare)
		end
		return true
	end
	
	return false
end

-- ============================================
-- THINK HOOK FÜR ALLE RAKETEN
-- ============================================

if SERVER then
	-- Globaler Think-Hook der ALLE Raketen prüft
	local NextFlareCheck = 0
	local ProcessedMissiles = {}
	
	hook.Add("Think", "EGC_FlareRedirection_AllMissiles", function()
		local T = CurTime()
		if T < NextFlareCheck then return end
		NextFlareCheck = T + FlareConfig.CheckInterval
		
		-- Prüfe ob Unity Flares System verfügbar ist
		if not UF or not UF.GetFlares then return end
		
		-- Hole alle Flares (wenn keine da sind, können wir aufhören)
		local flares = UF:GetFlares()
		if not istable(flares) or #flares == 0 then return end
		
		-- Durchsuche ALLE Entities nach Raketen
		for _, ent in pairs(ents.GetAll()) do
			if not IsValid(ent) then continue end
			
			local class = ent:GetClass()
			local isMissile = false
			
			-- Prüfe ob es eine bekannte Raketen-Klasse ist
			for _, missileClass in ipairs(FlareConfig.MissileClasses) do
				if class == missileClass then
					isMissile = true
					break
				end
			end
			
			-- Fallback: String-Prüfung
			if not isMissile then
				if string.find(class, "missile") or string.find(class, "torpedo") or string.find(class, "rocket") then
					isMissile = true
				end
			end
			
			if not isMissile then continue end
			
			-- Prüfe ob die Rakete aktiv ist (abgefeuert)
			local isActive = false
			if ent.GetActive then
				isActive = ent:GetActive()
			elseif ent.IsEnabled then
				isActive = ent.IsEnabled
			elseif not IsValid(ent:GetParent()) then
				isActive = true -- Kein Parent = abgefeuert
			end
			
			if not isActive then continue end
			
			-- Führe Flare-Redirection durch
			CheckFlareRedirection(ent)
		end
	end)
end

-- ============================================
-- PREREG HOOK FÜR BASIS-KLASSE (Backup)
-- ============================================

-- Hook: Erweitere lvs_missile Think-Funktion für bessere Flare-Redirection
hook.Add("PreRegisterSENT", "EastGermanCrusader_Missile_Flare_Redirection", function(ent, class)
	-- Prüfe ob es eine Raketen-Klasse ist
	local isMissile = false
	for _, missileClass in ipairs(FlareConfig.MissileClasses) do
		if class == missileClass then
			isMissile = true
			break
		end
	end
	
	if not isMissile then
		if string.find(class, "missile") or string.find(class, "torpedo") then
			isMissile = true
		end
	end
	
	if not isMissile then return end
	
	print("[Missile Flare Redirection] PreRegisterSENT Hook ausgeführt für " .. class)
	
	-- Erweitere GetAvailableTargets um Flares
	local OldGetAvailableTargets = ent.GetAvailableTargets
	ent.GetAvailableTargets = function(self)
		local targets = {}
		
		-- Rufe ursprüngliche Funktion auf falls vorhanden
		if OldGetAvailableTargets then
			targets = OldGetAvailableTargets(self)
		else
			targets = {
				[1] = player.GetAll(),
				[2] = LVS:GetVehicles() or {},
				[3] = LVS:GetNPCs() or {},
			}
		end
		
		-- Füge Flares hinzu
		if UF and UF.GetFlares then
			targets[4] = UF:GetFlares()
		end
		
		return targets
	end
end)

print("[EastGermanCrusader LVS Overhaul] Missile Flare Redirection System geladen!")
