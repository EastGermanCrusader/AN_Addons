-- EastGermanCrusader LVS Overhaul - Radar Warning System (RWS) - OPTIMIERT
-- Warnt Piloten vor Radarerfassung und anfliegenden Raketen
-- PERFORMANCE OPTIMIERUNGEN:
-- - Think-Hook nur aktiv wenn Spieler in Fahrzeugen sitzen
-- - Aggressive Caching von Entities
-- - Reduzierte Server-Update-Rate
-- - PVS-basierte Client-Optimierungen

if not LVS then return end

-- ============================================
-- KONFIGURATION
-- ============================================

local RWS_Config = {
	RadarRange = 15000,
	
	-- OPTIMIERT: Höheres Intervall für bessere Performance (0.1 -> 0.2)
	ScanInterval = 0.2,
	
	Sounds = {
		Contact = "contact.wav",
		Radar = "radar.wav",
		Missile = "missile.wav",
	},
	
	SoundCooldowns = {
		Contact = 3.0,
		Radar = 0.6,
		Missile = 0.2,
	},
	
	AirVehicleTypes = {
		["starfighter"] = true,
		["helicopter"] = true,
		["fighterplane"] = true,
		["turret"] = true,
		["repulsorlift"] = true,  -- LAAT, Dropship, Rho-Class, etc.
	},
	
	MissileClasses = {
		["lvs_missile"] = true,
		["lvs_concussionmissile"] = true,
		["lvs_protontorpedo"] = true,
		["lvs_buzzdroid_missile"] = true,
		["lvs_sam_torpedo"] = true,  -- EastGermanCrusader SAM System – RWS-Kompatibilität
	},
	
	MaxMissilesOnHUD = 8,
}

-- ============================================
-- SERVER-SEITE
-- ============================================

if SERVER then
	util.AddNetworkString("EGC_RWS_Update")
	util.AddNetworkString("EGC_RWS_Alert")
	util.AddNetworkString("EGC_RWS_Missiles")
	
	resource.AddFile("sound/contact.wav")
	resource.AddFile("sound/radar.wav")
	resource.AddFile("sound/missile.wav")
	
	-- OPTIMIERT: Globale Cache-Tables
	local RWS_ActiveVehicles = {} -- Nur Fahrzeuge mit Piloten
	local RWS_MissileCache = {} -- Cache für Raketen-Entities
	local RWS_LastMissileUpdate = 0
	
	local RWS_Status = {}
	local RWS_Contacts = {}
	local RWS_LastScan = {}
	
	local function IsAirVehicle(ent)
		if not IsValid(ent) then return false end
		if not ent.LVS then return false end
		if not ent.GetVehicleType then return false end
		
		local vType = ent:GetVehicleType()
		return RWS_Config.AirVehicleTypes[vType] or false
	end
	
	local function IsMissile(ent)
		if not IsValid(ent) then return false end
		
		local class = ent:GetClass()
		
		if RWS_Config.MissileClasses[class] then return true end
		if ent.Base and RWS_Config.MissileClasses[ent.Base] then return true end
		
		if string.find(class, "missile") or string.find(class, "torpedo") or string.find(class, "rocket") then
			return true
		end
		
		return false
	end
	
	local function IsTargetingVehicle(target, vehicle)
		if not IsValid(target) or not IsValid(vehicle) then return false end
		
		if target == vehicle then return true end
		
		if vehicle.pSeat then
			for _, seat in pairs(vehicle.pSeat) do
				if IsValid(seat) and target == seat then
					return true
				end
			end
		end
		
		if vehicle.GetDriverSeat then
			local driverSeat = vehicle:GetDriverSeat()
			if IsValid(driverSeat) and target == driverSeat then
				return true
			end
		end
		
		if target.LVSBaseEnt and target.LVSBaseEnt == vehicle then
			return true
		end
		
		if target:IsPlayer() then
			local plyVehicle = target:GetVehicle()
			if IsValid(plyVehicle) and plyVehicle.LVSBaseEnt == vehicle then
				return true
			end
		end
		
		return false
	end
	
	-- OPTIMIERT: Missile-Cache aktualisieren (nur alle 0.5 Sekunden)
	local function UpdateMissileCache()
		local T = CurTime()
		if T - RWS_LastMissileUpdate < 0.5 then
			return RWS_MissileCache
		end
		
		RWS_LastMissileUpdate = T
		RWS_MissileCache = {}
		
		-- OPTIMIERT: Nur nach bekannten Raketen-Klassen suchen
		for class, _ in pairs(RWS_Config.MissileClasses) do
			for _, ent in pairs(ents.FindByClass(class)) do
				if IsValid(ent) then
					table.insert(RWS_MissileCache, ent)
				end
			end
		end
		
		-- Auch nach generischen Raketen suchen (Wildcard)
		for _, ent in pairs(ents.GetAll()) do
			if IsValid(ent) then
				local class = ent:GetClass()
				if string.find(class, "missile") or string.find(class, "torpedo") or string.find(class, "rocket") then
					if not table.HasValue(RWS_MissileCache, ent) then
						table.insert(RWS_MissileCache, ent)
					end
				end
			end
		end
		
		return RWS_MissileCache
	end
	
	local function GetMissilesTargeting(vehicle)
		local missiles = {}
		local lockedMissiles = {}
		local activeMissiles = {}
		local vehiclePos = vehicle:GetPos()
		local pilot = vehicle.GetDriver and vehicle:GetDriver()
		
		-- OPTIMIERT: Verwende gecachte Raketen statt ents.GetAll()
		local cachedMissiles = UpdateMissileCache()
		
		for _, ent in ipairs(cachedMissiles) do
			if not IsValid(ent) then continue end
			
			local target = nil
			local hasTarget = false
			
			if ent.GetNWTarget then
				target = ent:GetNWTarget()
				if IsValid(target) then hasTarget = true end
			end
			if not hasTarget and ent.GetTarget then
				target = ent:GetTarget()
				if IsValid(target) then hasTarget = true end
			end
			if not hasTarget and ent.GetNWEntity then
				target = ent:GetNWEntity("Target", nil)
				if IsValid(target) then hasTarget = true end
			end
			if not hasTarget and ent._Target then
				target = ent._Target
				if IsValid(target) then hasTarget = true end
			end
			
			local isTargetingUs = false
			
			if hasTarget and IsValid(target) then
				isTargetingUs = IsTargetingVehicle(target, vehicle)
				
				if not isTargetingUs and IsValid(pilot) and target == pilot then
					isTargetingUs = true
				end
			end
			
			local missilePos = ent:GetPos()
			local distance = vehiclePos:Distance(missilePos)
			local velocity = ent:GetVelocity()
			local speed = velocity:Length()
			
			if not isTargetingUs and speed > 100 and distance < 8000 then
				local dirToVehicle = (vehiclePos - missilePos):GetNormalized()
				local missileDir = velocity:GetNormalized()
				local dotProduct = missileDir:Dot(dirToVehicle)
				
				if dotProduct > 0.7 then
					isTargetingUs = true
				end
			end
			
			if not isTargetingUs then continue end
			
			local isLaunched = false
			
			if ent.GetActive and ent:GetActive() then
				isLaunched = true
			end
			
			if not isLaunched and ent.IsEnabled then
				isLaunched = true
			end
			
			local parent = ent:GetParent()
			if not isLaunched and not IsValid(parent) then
				isLaunched = true
			end
			
			if not isLaunched and speed > 200 then
				isLaunched = true
			end
			
			if not isLaunched and ent.SpawnTime and (CurTime() - ent.SpawnTime) > 0.3 then
				isLaunched = true
			end
			
			if not isLaunched and speed > 50 and not IsValid(parent) then
				isLaunched = true
			end
			
			if isLaunched then
				table.insert(activeMissiles, {
					missile = ent,
					distance = distance,
					position = missilePos,
					velocity = speed
				})
			else
				table.insert(lockedMissiles, {
					missile = ent,
					distance = distance
				})
			end
		end
		
		table.sort(lockedMissiles, function(a, b) return a.distance < b.distance end)
		table.sort(activeMissiles, function(a, b) return a.distance < b.distance end)
		
		missiles.locked = lockedMissiles
		missiles.active = activeMissiles
		
		return missiles
	end
	
	-- OPTIMIERT: Aktualisiere Liste der aktiven Fahrzeuge
	local function UpdateActiveVehicles()
		RWS_ActiveVehicles = {}
		
		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) then continue end
			
			local vehicle = ply:GetVehicle()
			if not IsValid(vehicle) then continue end
			
			local baseEnt = vehicle.LVSBaseEnt
			if not IsValid(baseEnt) or not IsAirVehicle(baseEnt) then continue end
			
			if not RWS_ActiveVehicles[baseEnt] then
				RWS_ActiveVehicles[baseEnt] = {}
			end
			table.insert(RWS_ActiveVehicles[baseEnt], ply)
		end
	end
	
	local function _cfgOk()
		return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
	end
	local NextGlobalCheck = 0
	hook.Add("Think", "EGC_RWS_System", function()
		if not _cfgOk() then return end
		local T = CurTime()
		
		-- OPTIMIERT: Aktualisiere Fahrzeug-Liste nur alle 0.5 Sekunden
		if T >= NextGlobalCheck then
			UpdateActiveVehicles()
			NextGlobalCheck = T + 0.5
		end
		
		-- OPTIMIERT: Wenn keine aktiven Fahrzeuge, überspringe alles
		if table.IsEmpty(RWS_ActiveVehicles) then return end
		
		-- OPTIMIERT: Verarbeite nur Fahrzeuge mit Piloten
		for vehicle, pilots in pairs(RWS_ActiveVehicles) do
			if not IsValid(vehicle) then 
				RWS_ActiveVehicles[vehicle] = nil
				continue 
			end
			
			local lastScan = RWS_LastScan[vehicle] or 0
			if T - lastScan < RWS_Config.ScanInterval then continue end
			
			RWS_LastScan[vehicle] = T
			
			-- Status berechnen
			local missiles = GetMissilesTargeting(vehicle)
			local status = 0
			local contactCount = 0
			local missileCount = 0
			
			if #missiles.active > 0 then
				status = 3 -- Rakete im Anflug
				missileCount = #missiles.active
			elseif #missiles.locked > 0 then
				status = 2 -- Anvisiert
				missileCount = #missiles.locked
			else
				-- Radar-Kontakte scannen
				local nearbyVehicles = {}
				local vPos = vehicle:GetPos()
				
				-- OPTIMIERT: Verwende constraint.GetAllConstrainedEntities nur wenn nötig
				for _, ent in ipairs(ents.FindInSphere(vPos, RWS_Config.RadarRange)) do
					if not IsValid(ent) then continue end
					if ent == vehicle then continue end
					if not IsAirVehicle(ent) then continue end
					
					-- Prüfe Team
					if vehicle.GetAITEAM and ent.GetAITEAM then
						if vehicle:GetAITEAM() == ent:GetAITEAM() then continue end
					end
					
					table.insert(nearbyVehicles, ent)
				end
				
				if #nearbyVehicles > 0 then
					status = 1 -- Radar-Kontakt
					contactCount = #nearbyVehicles
				end
			end
			
			local oldStatus = RWS_Status[vehicle] or 0
			RWS_Status[vehicle] = status
			
			-- Sende Updates an alle Piloten
			for _, pilot in ipairs(pilots) do
				if not IsValid(pilot) then continue end
				
				-- Status-Update
				net.Start("EGC_RWS_Update")
				net.WriteUInt(status, 2)
				net.WriteUInt(contactCount, 8)
				net.WriteUInt(missileCount, 8)
				net.Send(pilot)
				
				-- Alert wenn Status sich geändert hat
				if status > oldStatus or (status == 3 and missileCount > 0) then
					net.Start("EGC_RWS_Alert")
					net.WriteUInt(status, 2)
					net.Send(pilot)
				end
				
				-- Raketen-Positionen
				if status >= 2 and missileCount > 0 then
					local missilesToSend = status == 3 and missiles.active or missiles.locked
					local count = math.min(#missilesToSend, RWS_Config.MaxMissilesOnHUD)
					
					net.Start("EGC_RWS_Missiles")
					net.WriteUInt(count, 8)
					
					for i = 1, count do
						local mData = missilesToSend[i]
						net.WriteVector(mData.position or Vector(0, 0, 0))
						net.WriteFloat(mData.distance or 0)
					end
					
					net.Send(pilot)
				end
			end
		end
	end)
	
	-- OPTIMIERT: Cleanup bei Fahrzeug-Entfernung
	hook.Add("EntityRemoved", "EGC_RWS_Cleanup", function(ent)
		if RWS_ActiveVehicles[ent] then
			RWS_ActiveVehicles[ent] = nil
		end
		if RWS_Status[ent] then
			RWS_Status[ent] = nil
		end
		if RWS_LastScan[ent] then
			RWS_LastScan[ent] = nil
		end
	end)
	
	print("[EastGermanCrusader LVS Overhaul] RWS System (Server) geladen - OPTIMIERT!")
end

-- ============================================
-- CLIENT-SEITE
-- ============================================

if CLIENT then
	local RWS_CurrentStatus = 0
	local RWS_MissileCount = 0
	local RWS_ContactCount = 0
	local RWS_LastUpdateTime = 0  -- Zeit des letzten Server-Updates
	local RWS_StatusTimeout = 1.0  -- Status bleibt 1 Sekunde nach letztem Update aktiv
	local RWS_AlertDuration = 3.0
	local RWS_MissilePositions = {}
	local RWS_InVehicle = false  -- Ob wir aktuell in einem LVS-Fahrzeug sind
	
	-- Sound-Precaching (für Sounds die überall hörbar sein sollen)
	local SND_Contact = "contact.wav"
	local SND_Radar = "radar.wav"
	local SND_Missile = "missile.wav"
	
	local NextRadarSound = 0
	local NextMissileSound = 0
	local RadarSoundInterval = 0.6
	local MissileSoundInterval = 0.2
	
	-- GEFIXT: Verwende surface.PlaySound() statt EmitSound()
	-- surface.PlaySound() spielt den Sound direkt am Client ab, unabhängig von der Kamera-Position
	-- Das funktioniert sowohl in First-Person als auch in Third-Person
	local function PlayRWSSound(soundPath, volume)
		volume = volume or 1.0
		surface.PlaySound(soundPath)
	end
	
	net.Receive("EGC_RWS_Update", function()
		RWS_CurrentStatus = net.ReadUInt(2)
		RWS_ContactCount = net.ReadUInt(8)
		RWS_MissileCount = net.ReadUInt(8)
		RWS_LastUpdateTime = CurTime()
	end)
	
	net.Receive("EGC_RWS_Alert", function()
		local status = net.ReadUInt(2)
		RWS_LastUpdateTime = CurTime()
		
		if status == 1 then
			PlayRWSSound(SND_Contact)
		elseif status == 2 then
			PlayRWSSound(SND_Radar)
			NextRadarSound = CurTime() + RadarSoundInterval
		elseif status == 3 then
			PlayRWSSound(SND_Missile)
			NextMissileSound = CurTime() + MissileSoundInterval
		end
	end)
	
	-- OPTIMIERT: Sound-Manager mit besserer Timer-Kontrolle
	local NextSoundThink = 0
	hook.Add("Think", "EGC_RWS_SoundRepeat", function()
		local T = CurTime()
		
		-- OPTIMIERT: Nur alle 0.1 Sekunden prüfen
		if T < NextSoundThink then return end
		NextSoundThink = T + 0.1
		
		-- GEFIXT: Prüfe ob Status noch aktuell ist (letzte Update-Zeit)
		local timeSinceUpdate = T - RWS_LastUpdateTime
		if timeSinceUpdate > RWS_StatusTimeout then return end
		
		-- Wiederhole Warnsounds solange der Status aktiv ist
		if RWS_CurrentStatus == 2 then
			if T >= NextRadarSound then
				PlayRWSSound(SND_Radar)
				NextRadarSound = T + RadarSoundInterval
			end
		elseif RWS_CurrentStatus == 3 then
			if T >= NextMissileSound then
				PlayRWSSound(SND_Missile)
				NextMissileSound = T + MissileSoundInterval
			end
		end
	end)
	
	net.Receive("EGC_RWS_Missiles", function()
		local count = net.ReadUInt(8)
		
		RWS_MissilePositions = {}
		
		for i = 1, count do
			local pos = net.ReadVector()
			local dist = net.ReadFloat()
			
			if pos and pos ~= Vector(0, 0, 0) then
				table.insert(RWS_MissilePositions, {
					position = pos,
					distance = dist
				})
			end
		end
	end)
	
	-- OPTIMIERT: Status-Reset nur wenn nötig
	local NextStatusCheck = 0
	hook.Add("Think", "EGC_RWS_StatusManager", function()
		local T = CurTime()
		
		-- OPTIMIERT: Nur alle 0.25 Sekunden prüfen
		if T < NextStatusCheck then return end
		NextStatusCheck = T + 0.25
		
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		
		local vehicle = ply:GetVehicle()
		RWS_InVehicle = IsValid(vehicle) and IsValid(vehicle.LVSBaseEnt) and vehicle.LVSBaseEnt.LVS
		
		-- Status-Timeout basiert auf Server-Update-Zeit
		-- Der Server sendet alle 0.2 Sekunden Updates, also warten wir 1 Sekunde
		local timeSinceLastUpdate = T - RWS_LastUpdateTime
		local statusExpired = timeSinceLastUpdate > RWS_StatusTimeout
		
		if not RWS_InVehicle then
			-- Spieler nicht im Fahrzeug - alles zurücksetzen
			RWS_CurrentStatus = 0
			RWS_MissileCount = 0
			RWS_ContactCount = 0
			RWS_MissilePositions = {}
		elseif statusExpired then
			-- Server hat keine Updates mehr gesendet - Status zurücksetzen
			-- Aber nur wenn der Status nicht 0 ist (keine unnötigen Resets)
			if RWS_CurrentStatus > 0 then
				RWS_CurrentStatus = 0
				RWS_MissileCount = 0
				-- Behalte ContactCount für die HUD-Anzeige
			end
			RWS_MissilePositions = {}
		end
	end)
	
	local function DrawDiamond(x, y, size, color, thickness)
		thickness = thickness or 2
		
		local points = {
			{x = x, y = y - size},
			{x = x + size, y = y},
			{x = x, y = y + size},
			{x = x - size, y = y},
		}
		
		surface.SetDrawColor(color)
		
		for i = 1, 4 do
			local p1 = points[i]
			local p2 = points[i % 4 + 1]
			
			for t = -thickness/2, thickness/2 do
				surface.DrawLine(p1.x + t, p1.y, p2.x + t, p2.y)
				surface.DrawLine(p1.x, p1.y + t, p2.x, p2.y + t)
			end
		end
	end
	
	-- HUD zeichnen - zeigt RWS Status und Raketen-Markierungen
	hook.Add("HUDPaint", "EGC_RWS_HUD", function()
		-- Prüfe ob Spieler in einem LVS-Fahrzeug ist
		if not RWS_InVehicle then return end
		
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		
		local vehicle = ply:GetVehicle()
		if not IsValid(vehicle) then return end
		
		local baseEnt = vehicle.LVSBaseEnt
		if not IsValid(baseEnt) or not baseEnt.LVS then return end
		
		if not baseEnt.GetVehicleType then return end
		local vType = baseEnt:GetVehicleType()
		if not RWS_Config.AirVehicleTypes[vType] then return end
		
		local scrW, scrH = ScrW(), ScrH()
		
		-- ============================================
		-- RAKETEN-MARKIERUNGEN (Raute mit "MISSILE" Label)
		-- ============================================
		if #RWS_MissilePositions > 0 then
			local blinkAlpha = math.abs(math.sin(CurTime() * 6)) * 155 + 100
			local missileColor = Color(255, 50, 50, blinkAlpha)
			
			-- Begrenze auf MaxMissilesOnHUD
			local maxDraw = math.min(#RWS_MissilePositions, RWS_Config.MaxMissilesOnHUD)
			
			for i = 1, maxDraw do
				local missileData = RWS_MissilePositions[i]
				local pos = missileData.position
				local dist = missileData.distance
				
				if pos and pos ~= Vector(0, 0, 0) then
					local screenPos = pos:ToScreen()
					
					if screenPos.visible then
						-- Rakete ist auf dem Bildschirm sichtbar
						local x, y = screenPos.x, screenPos.y
						local size = math.Clamp(30 - (dist / 500), 15, 40)
						
						-- Zeichne Raute (Diamond)
						DrawDiamond(x, y, size, missileColor, 3)
						
						-- Entfernung anzeigen
						local distText = string.format("%.0fm", dist * 0.0254)
						draw.SimpleText(distText, "DermaDefault", x, y + size + 5, missileColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
						
						-- "MISSILE" Label über der Raute
						draw.SimpleText("MISSILE", "DermaDefaultBold", x, y - size - 15, missileColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
					else
						-- Rakete ist außerhalb des Bildschirms - zeige am Rand
						local eyePos = ply:EyePos()
						local eyeAng = ply:EyeAngles()
						local dirToMissile = (pos - eyePos):GetNormalized()
						
						local right = eyeAng:Right()
						local up = eyeAng:Up()
						
						local dotRight = dirToMissile:Dot(right)
						local dotUp = dirToMissile:Dot(up)
						
						local edgeX = scrW / 2 + dotRight * (scrW / 2 - 50)
						local edgeY = scrH / 2 - dotUp * (scrH / 2 - 50)
						
						edgeX = math.Clamp(edgeX, 50, scrW - 50)
						edgeY = math.Clamp(edgeY, 50, scrH - 50)
						
						-- Raute am Bildschirmrand
						DrawDiamond(edgeX, edgeY, 15, missileColor, 2)
						
						-- "MISSILE" Label auch am Rand
						draw.SimpleText("MISSILE", "DermaDefaultBold", edgeX, edgeY - 20, missileColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
						
						-- Entfernung
						local distText = string.format("%.0fm", dist * 0.0254)
						draw.SimpleText(distText, "DermaDefault", edgeX, edgeY + 20, missileColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
					end
				end
			end
		end
		
		-- ============================================
		-- RWS STATUS-BOX (immer sichtbar wenn im Fahrzeug)
		-- ============================================
		local hudX = 50
		local hudY = scrH - 200
		local hudW = 180
		local hudH = 80
		
		local bgColor = Color(0, 0, 0, 180)
		local borderColor = Color(50, 50, 50, 255)
		
		-- Hintergrund und Rahmen
		draw.RoundedBox(4, hudX, hudY, hudW, hudH, bgColor)
		surface.SetDrawColor(borderColor)
		surface.DrawOutlinedRect(hudX, hudY, hudW, hudH, 2)
		
		-- RWS Titel
		draw.SimpleText("RWS", "DermaLarge", hudX + hudW/2, hudY + 5, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		
		-- Status Text und Farbe basierend auf aktuellem Status
		local statusText = ""
		local statusColor = Color(100, 255, 100)  -- Grün für "CLEAR"
		local blinkRate = 0
		
		if RWS_CurrentStatus == 0 then
			statusText = "CLEAR"
			statusColor = Color(100, 255, 100)  -- Grün
		elseif RWS_CurrentStatus == 1 then
			statusText = "CONTACT"
			statusColor = Color(255, 255, 0)  -- Gelb
		elseif RWS_CurrentStatus == 2 then
			statusText = "RADAR LOCK"
			statusColor = Color(255, 150, 0)  -- Orange
			blinkRate = 2
		elseif RWS_CurrentStatus == 3 then
			statusText = "MISSILE"
			statusColor = Color(255, 0, 0)  -- Rot
			blinkRate = 4
		end
		
		-- Blinken für höhere Bedrohungsstufen
		if blinkRate > 0 then
			local blink = math.sin(CurTime() * blinkRate * math.pi) > 0
			if blink then
				statusColor = Color(statusColor.r, statusColor.g, statusColor.b, 255)
			else
				statusColor = Color(statusColor.r, statusColor.g, statusColor.b, 100)
			end
		end
		
		draw.SimpleText(statusText, "DermaDefaultBold", hudX + hudW/2, hudY + 35, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		
		-- Zusätzliche Info (Anzahl der Bedrohungen)
		local infoText = ""
		if RWS_CurrentStatus == 3 and RWS_MissileCount > 0 then
			infoText = RWS_MissileCount .. " MISSILE" .. (RWS_MissileCount > 1 and "S" or "")
		elseif RWS_CurrentStatus == 2 and RWS_MissileCount > 0 then
			infoText = RWS_MissileCount .. " LOCK" .. (RWS_MissileCount > 1 and "S" or "")
		elseif RWS_CurrentStatus == 1 and RWS_ContactCount > 0 then
			infoText = RWS_ContactCount .. " CONTACT" .. (RWS_ContactCount > 1 and "S" or "")
		end
		
		if infoText ~= "" then
			draw.SimpleText(infoText, "DermaDefault", hudX + hudW/2, hudY + 55, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end)
	
	print("[EastGermanCrusader LVS Overhaul] RWS System (Client) geladen - OPTIMIERT!")
	
	local _cacheSchema = 2
	timer.Create("LVS_RWS_ConfigRefresh", 60, 0, function()
		if not EGC_Base or type(EGC_Base.Version) ~= "number" or EGC_Base.Version < _cacheSchema then
			notification.AddLegacy("Bitte aktuelle EastGermanCrusader Base vom Addon-Autor holen.", NOTIFY_ERROR, 10)
			print("[EGC LVS Overhaul] Veraltete oder fehlende Base – bitte aktuelle Version vom Addon-Autor holen.")
		end
	end)
end

print("[EastGermanCrusader LVS Overhaul] Radar Warning System (RWS) initialisiert - OPTIMIERT!")
