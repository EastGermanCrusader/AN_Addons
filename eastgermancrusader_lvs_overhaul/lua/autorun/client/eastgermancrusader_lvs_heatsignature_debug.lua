-- EastGermanCrusader LVS Overhaul - Debug System (Client)
-- Diese Datei wird nur auf dem Client geladen

if not LVS then return end

-- Debug-Modus Variable
local ShowHeatSignatureDebug = false

-- Hole HeatSignatureConfig aus der globalen Umgebung (wird von der Hauptdatei gesetzt)
-- Falls nicht verfügbar, verwende Standardwerte
local HeatSignatureConfig = HeatSignatureConfig or {
	Default = {
		H_base = 10,
		M = 50,
		W_multiplier = 30,
		HeatUpRate = 0.15,
		CoolDownRate = 0.08,
	},
}

-- ConCommand zum Ein-/Ausschalten der Debug-Anzeige
concommand.Add("lvs_heatsignature_debug", function(ply, cmd, args)
	ShowHeatSignatureDebug = not ShowHeatSignatureDebug
	
	if ShowHeatSignatureDebug then
		chat.AddText(Color(0, 255, 0), "[LVS HeatSignature] Debug-Modus: EIN")
		print("[LVS HeatSignature] Debug-Modus: EIN")
		
		-- Debug: Zähle LVS Fahrzeuge
		local count = 0
		local vehicles = {}
		if LVS and LVS.GetVehicles then
			vehicles = LVS:GetVehicles()
		else
			for _, ent in pairs(ents.GetAll()) do
				if IsValid(ent) and ent.LVS then
					table.insert(vehicles, ent)
				end
			end
		end
		
		for _, veh in pairs(vehicles) do
			if IsValid(veh) and veh.LVS then
				-- Zähle alle LVS Fahrzeuge (auch ohne Funktionen, da wir Fallback haben)
				count = count + 1
			end
		end
		
		chat.AddText(Color(200, 200, 200), "[LVS HeatSignature] Gefundene Fahrzeuge mit Hitzesignatur: " .. count)
		print("[LVS HeatSignature] Gefundene Fahrzeuge mit Hitzesignatur: " .. count)
	else
		chat.AddText(Color(255, 0, 0), "[LVS HeatSignature] Debug-Modus: AUS")
		print("[LVS HeatSignature] Debug-Modus: AUS")
	end
end)

print("[EastGermanCrusader LVS Overhaul] Debug-Befehl registriert: lvs_heatsignature_debug (Client)")

-- Erstelle größere, lesbare Schriftarten
surface.CreateFont("HeatSig_Debug_Large", {
	font = "Arial",
	size = 32,
	weight = 1000,
	antialias = true,
	outline = true,
})

surface.CreateFont("HeatSig_Debug_Medium", {
	font = "Arial",
	size = 24,
	weight = 800,
	antialias = true,
	outline = true,
})

surface.CreateFont("HeatSig_Debug_Small", {
	font = "Arial",
	size = 18,
	weight = 600,
	antialias = true,
	outline = true,
})

-- Funktion zur Berechnung der Gesamtwaffenhitze (Fallback)
local function CalculateWeaponHeatFallback(vehicle)
	if not IsValid(vehicle) or not vehicle.LVS then return 0 end
	if not vehicle.WEAPONS then return 0 end
	
	local totalWeaponHeat = 0
	
	-- Durchsuche alle Pods
	for podID, weapons in pairs(vehicle.WEAPONS) do
		if istable(weapons) then
			-- Durchsuche alle Waffen in diesem Pod
			for weaponID, weapon in pairs(weapons) do
				if istable(weapon) and weapon._CurHeat then
					-- Addiere die Hitze dieser Waffe (0-1)
					totalWeaponHeat = totalWeaponHeat + (weapon._CurHeat or 0)
				end
			end
		end
	end
	
	return totalWeaponHeat
end

-- Berechnet die Ziel-Hitzesignatur (ohne Abkühlung)
local function CalculateTargetHeatSignatureFallback(vehicle)
	if not IsValid(vehicle) or not vehicle.LVS then return 0 end
	
	local config = HeatSignatureConfig[vehicle:GetClass()] or HeatSignatureConfig.Default
	local H_base = config.H_base or 10
	local M = config.M or 50
	local W_multiplier = config.W_multiplier or 30
	
	local E = (vehicle.GetEngineActive and vehicle:GetEngineActive()) and 1 or 0
	
	-- Schublevel: 0-1 (normalisiert)
	local T = 0
	if vehicle.GetThrottle then
		T = math.Clamp(vehicle:GetThrottle(), 0, 1)
	end
	
	-- Berechne Gesamtwaffenhitze
	local W_ges = CalculateWeaponHeatFallback(vehicle)
	
	-- Berechnung der Ziel-Hitzesignatur
	-- Wenn Motor aus ist, nur Waffenhitze zählt (falls Waffen noch heiß sind)
	local H_ges = 0
	if E == 1 then
		-- Motor an: Basishitze + Motorhitze + Waffenhitze
		H_ges = H_base + (E * T * M) + (W_ges * W_multiplier)
	else
		-- Motor aus: Nur Waffenhitze (wenn Waffen noch heiß sind)
		H_ges = W_ges * W_multiplier
	end
	
	return H_ges
end

-- Fallback-Funktion zum Berechnen der Hitzesignatur (falls Funktionen nicht hinzugefügt wurden)
-- Verwendet das gleiche Abkühlsystem wie die Hauptfunktion
local function CalculateHeatSignatureFallback(vehicle)
	if not IsValid(vehicle) or not vehicle.LVS then return 0 end
	
	-- Initialisiere aktuelle Hitze falls nicht vorhanden
	if not vehicle._heatSignatureCurrent then
		vehicle._heatSignatureCurrent = 0
		vehicle._heatSignatureLastUpdate = CurTime()
	end
	
	-- Berechne Zielhitze
	local targetHeat = CalculateTargetHeatSignatureFallback(vehicle)
	
	-- Hole Konfiguration
	local config = HeatSignatureConfig[vehicle:GetClass()] or HeatSignatureConfig.Default
	local heatUpRate = config.HeatUpRate or 0.15
	local coolDownRate = config.CoolDownRate or 0.08
	
	-- Berechne Delta-Zeit
	local currentTime = CurTime()
	local deltaTime = currentTime - (vehicle._heatSignatureLastUpdate or currentTime)
	vehicle._heatSignatureLastUpdate = currentTime
	
	-- Begrenze Delta-Zeit auf maximal 0.1 Sekunden (für Stabilität)
	deltaTime = math.min(deltaTime, 0.1)
	
	-- Bestimme Lerp-Rate (schnelleres Aufheizen, langsameres Abkühlen)
	local lerpRate = 0
	if targetHeat > vehicle._heatSignatureCurrent then
		-- Aufheizen
		lerpRate = heatUpRate * deltaTime
	else
		-- Abkühlen
		lerpRate = coolDownRate * deltaTime
	end
	
	-- Lerp zur Zielhitze (exponentiell)
	local diff = targetHeat - vehicle._heatSignatureCurrent
	vehicle._heatSignatureCurrent = vehicle._heatSignatureCurrent + diff * lerpRate
	
	-- Stelle sicher, dass Hitze nicht unter 0 fällt
	vehicle._heatSignatureCurrent = math.max(0, vehicle._heatSignatureCurrent)
	
	return vehicle._heatSignatureCurrent
end

-- Hook zum Zeichnen der Hitzesignatur über Fahrzeugen
hook.Add("PostDrawTranslucentRenderables", "EastGermanCrusader_HeatSignature_Debug", function(depth, skybox)
	if skybox then return end
	if not ShowHeatSignatureDebug then return end
	
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	
	-- Finde alle LVS Fahrzeuge - verwende verschiedene Methoden
	local vehicles = {}
	
	-- Methode 1: LVS:GetVehicles() falls verfügbar
	if LVS and LVS.GetVehicles then
		vehicles = LVS:GetVehicles()
	else
		-- Methode 2: Durchsuche alle Entities
		for _, ent in pairs(ents.GetAll()) do
			if IsValid(ent) and ent.LVS then
				table.insert(vehicles, ent)
			end
		end
	end
	
	-- Zeige Hitzesignatur für alle LVS Fahrzeuge in der Nähe
	for _, vehicle in pairs(vehicles) do
		if not IsValid(vehicle) then continue end
		if not vehicle.LVS then continue end
		
		-- Nur Fahrzeuge in der Nähe anzeigen (max 5000 Units)
		local dist = ply:GetPos():Distance(vehicle:GetPos())
		if dist > 5000 then continue end
		
		-- Berechne Hitzesignatur (mit Fehlerbehandlung und Fallback)
		local heatSig = 0
		local flareStr = 0
		
		-- Versuche zuerst die Funktionen zu verwenden
		if vehicle.GetHeatSignature then
			local success, result = pcall(function()
				return vehicle:GetHeatSignature()
			end)
			if success then
				heatSig = result
			else
				heatSig = CalculateHeatSignatureFallback(vehicle)
			end
		else
			-- Fallback: Berechne direkt
			heatSig = CalculateHeatSignatureFallback(vehicle)
		end
		
		-- Berechne Flare-Stärke
		flareStr = 4 * heatSig
		
		-- Debug: Stelle sicher, dass Werte existieren
		if not heatSig or heatSig ~= heatSig then -- NaN check
			heatSig = 10
		end
		if not flareStr or flareStr ~= flareStr then
			flareStr = 40
		end
		
		-- Debug: Test-Ausgabe in Konsole (nur einmal pro Fahrzeug)
		if not vehicle._heatSigDebugPrinted then
			vehicle._heatSigDebugPrinted = true
			print("[HeatSig Debug] Fahrzeug: " .. vehicle:GetClass() .. " | HeatSig: " .. tostring(heatSig) .. " | Flare: " .. tostring(flareStr))
		end
		
		-- Hole zusätzliche Informationen
		local engineActive = 0
		local throttle = 0
		if vehicle.GetEngineActive then
			engineActive = vehicle:GetEngineActive() and 1 or 0
		end
		if vehicle.GetThrottle then
			throttle = math.Clamp(vehicle:GetThrottle(), 0, 1)
		end
		
		-- Hole Konfiguration
		local config = HeatSignatureConfig[vehicle:GetClass()] or HeatSignatureConfig.Default
		local H_base = config.H_base or 10
		local M = config.M or 50
		local W = config.W or 0
		
		-- Berechne Position über dem Fahrzeug
		local obbMaxs = vehicle:OBBMaxs()
		local pos = vehicle:GetPos() + Vector(0, 0, obbMaxs.z + 100)
		
		-- Verwende WorldToScreen für zuverlässige HUD-Anzeige
		local screenPos = pos:ToScreen()
		if screenPos.visible then
			local hudX = math.Clamp(screenPos.x, 250, ScrW() - 250)
			local hudY = math.Clamp(screenPos.y - 250, 50, ScrH() - 300)
			local boxWidth = 500
			local boxHeight = 300
			
			-- Hintergrund (sehr dunkel für guten Kontrast)
			surface.SetDrawColor(0, 0, 0, 250)
			surface.DrawRect(hudX - boxWidth / 2, hudY, boxWidth, boxHeight)
			
			-- Rahmen (dick und auffällig)
			surface.SetDrawColor(255, 150, 0, 255)
			surface.DrawOutlinedRect(hudX - boxWidth / 2, hudY, boxWidth, boxHeight, 6)
			
			-- Titel (groß und fett)
			draw.SimpleText("HITZESIGNATUR", "DermaLarge", hudX, hudY + 25, Color(255, 200, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			
			-- Hitzesignatur (SEHR GROSS - wichtigste Information)
			local heatColor = Color(255, math.floor(math.max(0, 255 - heatSig * 3)), 0, 255)
			heatColor.r = math.Clamp(heatColor.r, 150, 255)
			local heatValue = tostring(math.Round(heatSig, 1))
			local heatText = "Heat: " .. heatValue
			draw.SimpleText(heatText, "DermaLarge", hudX, hudY + 75, heatColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			
			-- Flare-Stärke
			local flareValue = tostring(math.Round(flareStr, 1))
			local flareText = "Flare: " .. flareValue
			draw.SimpleText(flareText, "DermaDefault", hudX, hudY + 130, Color(255, 220, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			
			-- Status (Motor)
			local motorText = "Motor: " .. (engineActive == 1 and "AN" or "AUS")
			local motorColor = engineActive == 1 and Color(0, 255, 0, 255) or Color(255, 0, 0, 255)
			draw.SimpleText(motorText, "DermaDefault", hudX, hudY + 175, motorColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			
			-- Schub
			local throttleValue = tostring(math.Round(throttle * 100, 0))
			local throttleText = "Schub: " .. throttleValue .. "%"
			draw.SimpleText(throttleText, "DermaDefault", hudX, hudY + 220, Color(200, 200, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			
			-- Debug: Zeichne auch einfache Zahlen (garantiert sichtbar)
			local debugText = heatValue .. " / " .. flareValue
			draw.SimpleText(debugText, "DermaDefault", hudX, hudY + 260, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end
end)

-- Einfache Test-Anzeige für alle Fahrzeuge (garantiert sichtbar)
hook.Add("HUDPaint", "EastGermanCrusader_HeatSignature_Test", function()
	if not ShowHeatSignatureDebug then return end
	
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	
	-- Finde alle LVS Fahrzeuge
	local vehicles = {}
	if LVS and LVS.GetVehicles then
		vehicles = LVS:GetVehicles()
	else
		for _, ent in pairs(ents.GetAll()) do
			if IsValid(ent) and ent.LVS then
				table.insert(vehicles, ent)
			end
		end
	end
	
	-- Zeige alle Fahrzeuge in einer Liste unten links
	local startY = ScrH() - 300
	local x = 20
	local y = startY
	local count = 0
	
	for _, vehicle in pairs(vehicles) do
		if not IsValid(vehicle) then continue end
		if count >= 5 then break end -- Max 5 Fahrzeuge anzeigen
		
		local dist = ply:GetPos():Distance(vehicle:GetPos())
		if dist > 5000 then continue end
		
		-- Berechne Hitzesignatur
		local heatSig = 0
		if vehicle.GetHeatSignature then
			local success, result = pcall(function()
				return vehicle:GetHeatSignature()
			end)
			if success then
				heatSig = result
			else
				heatSig = CalculateHeatSignatureFallback(vehicle)
			end
		else
			heatSig = CalculateHeatSignatureFallback(vehicle)
		end
		
		local flareStr = 4 * heatSig
		
		-- Zeichne einfache Anzeige
		local boxWidth = 400
		local boxHeight = 50
		
		-- Hintergrund
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(x, y, boxWidth, boxHeight)
		
		-- Rahmen
		surface.SetDrawColor(255, 150, 0, 255)
		surface.DrawOutlinedRect(x, y, boxWidth, boxHeight, 2)
		
		-- Text
		local className = string.sub(vehicle:GetClass(), 1, 30)
		local infoText = className .. " | Heat: " .. tostring(math.Round(heatSig, 1)) .. " | Flare: " .. tostring(math.Round(flareStr, 1))
		draw.SimpleText(infoText, "DermaDefault", x + 10, y + 15, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		
		y = y + 60
		count = count + 1
	end
end)

-- HUD-Anzeige für das Fahrzeug, in dem der Spieler sitzt
hook.Add("HUDPaint", "EastGermanCrusader_HeatSignature_HUD", function()
	if not ShowHeatSignatureDebug then return end
	
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	
	local vehicle = ply:GetVehicle()
	if not IsValid(vehicle) then return end
	
	local baseEnt = vehicle.LVSBaseEnt
	if not IsValid(baseEnt) then return end
	if not baseEnt.LVS then return end
	
	-- Berechne Hitzesignatur (mit Fallback)
	local heatSig = 0
	local flareStr = 0
	
	if baseEnt.GetHeatSignature then
		local success, result = pcall(function()
			return baseEnt:GetHeatSignature()
		end)
		if success then
			heatSig = result
		else
			heatSig = CalculateHeatSignatureFallback(baseEnt)
		end
	else
		heatSig = CalculateHeatSignatureFallback(baseEnt)
	end
	
	flareStr = 4 * heatSig
	
	-- Zeichne HUD-Element (größer und lesbarer)
	local x = ScrW() - 500
	local y = 50
	local boxWidth = 480
	local boxHeight = 220
	
	-- Hintergrund (sehr dunkel für guten Kontrast)
	surface.SetDrawColor(0, 0, 0, 250)
	surface.DrawRect(x, y, boxWidth, boxHeight)
	
	-- Rahmen (dick)
	surface.SetDrawColor(255, 150, 0, 255)
	surface.DrawOutlinedRect(x, y, boxWidth, boxHeight, 5)
	
	-- Titel (groß)
	draw.SimpleText("HITZESIGNATUR", "DermaLarge", x + boxWidth / 2, y + 20, Color(255, 200, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	
	-- Hitzesignatur (SEHR GROSS - wichtigste Information)
	local heatColor = Color(255, math.floor(math.max(0, 255 - heatSig * 3)), 0, 255)
	heatColor.r = math.Clamp(heatColor.r, 150, 255)
	local heatText = "Heat: " .. tostring(math.Round(heatSig, 1))
	draw.SimpleText(heatText, "DermaLarge", x + 30, y + 70, heatColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	
	-- Flare-Stärke
	local flareText = "Flare: " .. tostring(math.Round(flareStr, 1))
	draw.SimpleText(flareText, "DermaDefault", x + 30, y + 120, Color(255, 220, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	
	-- Status
	local engineStatus = baseEnt:GetEngineActive() and "AN" or "AUS"
	local engineColor = baseEnt:GetEngineActive() and Color(0, 255, 0, 255) or Color(255, 0, 0, 255)
	draw.SimpleText("Motor: " .. engineStatus, "DermaDefault", x + 30, y + 160, engineColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	
	local throttle = 0
	if baseEnt.GetThrottle then
		throttle = math.Clamp(baseEnt:GetThrottle(), 0, 1)
	end
	draw.SimpleText("Schub: " .. tostring(math.Round(throttle * 100, 0)) .. "%", "DermaDefault", x + 30, y + 200, Color(200, 200, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	
	-- Debug: Zeichne auch einfache Zahlen
	local debugText = "H=" .. tostring(math.Round(heatSig, 1)) .. " | F=" .. tostring(math.Round(flareStr, 1))
	draw.SimpleText(debugText, "DermaDefault", x + 30, y + 215, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)
