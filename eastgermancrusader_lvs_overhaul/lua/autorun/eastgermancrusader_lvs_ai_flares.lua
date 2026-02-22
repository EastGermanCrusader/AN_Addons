-- EastGermanCrusader LVS Overhaul - KI Flare System
-- Lässt KI-Fahrzeuge automatisch Flares ausstoßen, wenn sie von Raketen verfolgt werden

if not LVS then return end

-- Funktion zum Prüfen, ob ein Fahrzeug Flares hat
local function VehicleHasFlares(vehicle)
	if not IsValid(vehicle) or not vehicle.LVS then return false end
	
	-- Prüfe Unity Flares System
	if vehicle.FlareSystem then
		return true
	end
	
	-- Prüfe Waffen auf Flare-Waffe
	if vehicle.WEAPONS then
		for podID, weapons in pairs(vehicle.WEAPONS) do
			if istable(weapons) then
				for weaponID, weapon in pairs(weapons) do
					if istable(weapon) then
						-- Prüfe ob es eine Flare-Waffe ist (Icon oder Name)
						local icon = weapon.Icon
						if icon then
							local iconPath = tostring(icon)
							if string.find(iconPath, "flare") or string.find(iconPath, "unitys_flares") then
								return true, podID, weaponID
							end
						end
					end
				end
			end
		end
	end
	
	return false
end

-- Funktion zum Ausstoßen von Flares
local function FireFlares(vehicle)
	if not IsValid(vehicle) then return false end
	
	-- Unity Flares System
	if vehicle.FlareSystem and vehicle.FlareSystem.Attack then
		-- Finde den Flare-Pod
		local flarePod = nil
		if vehicle.WEAPONS then
			for podID, weapons in pairs(vehicle.WEAPONS) do
				if istable(weapons) then
					for weaponID, weapon in pairs(weapons) do
						if weapon == vehicle.FlareSystem then
							flarePod = vehicle:GetPassengerSeats()[podID]
							break
						end
					end
				end
				if flarePod then break end
			end
		end
		
		if flarePod then
			vehicle.FlareSystem.Attack(flarePod)
			return true
		end
	end
	
	-- Prüfe Waffen auf Flare-Waffe
	if vehicle.WEAPONS then
		for podID, weapons in pairs(vehicle.WEAPONS) do
			if istable(weapons) then
				for weaponID, weapon in pairs(weapons) do
					if istable(weapon) and weapon.Attack then
						local icon = weapon.Icon
						if icon then
							local iconPath = tostring(icon)
							if string.find(iconPath, "flare") or string.find(iconPath, "unitys_flares") then
								-- Wähle die Waffe aus und feuere
								local pod = vehicle:GetPassengerSeats()[podID]
								if IsValid(pod) then
									local weaponEnt = pod:lvsGetWeapon()
									if IsValid(weaponEnt) then
										weaponEnt:SelectWeapon(weaponID)
										weapon.Attack(weaponEnt)
										return true
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	return false
end

-- Hook: Prüfe in der KI-Think-Funktion auf verfolgende Raketen
hook.Add("Think", "EastGermanCrusader_LVS_AI_Flares", function()
	if CLIENT then return end
	
	local T = CurTime()
	
	-- Prüfe alle LVS Fahrzeuge
	for _, vehicle in pairs(LVS:GetVehicles() or {}) do
		if not IsValid(vehicle) then continue end
		if not vehicle:GetAI() then continue end
		if not VehicleHasFlares(vehicle) then continue end
		
		-- Cooldown für Flares (verhindert Spam)
		if (vehicle._lastAIFlareTime or 0) > T then continue end
		
		-- Prüfe auf Raketen in der Nähe
		local vehiclePos = vehicle:GetPos()
		local vehicleForward = vehicle:GetForward()
		local hasMissileThreat = false
		local closestMissile = nil
		local closestDist = math.huge
		
		-- Durchsuche alle Entities nach Raketen
		for _, ent in pairs(ents.GetAll()) do
			if not IsValid(ent) then continue end
			
			-- Prüfe ob es eine Rakete ist
			local isMissile = false
			local missileClass = ent:GetClass()
			if missileClass == "lvs_missile" or 
			   string.find(missileClass, "missile") or 
			   string.find(missileClass, "torpedo") or
			   string.find(missileClass, "rocket") then
				isMissile = true
			end
			
			if not isMissile then continue end
			
			-- Prüfe ob die Rakete aktiv ist
			if ent.IsEnabled and not ent.IsEnabled then continue end
			if ent.IsDetonated then continue end
			
			-- Prüfe ob die Rakete dieses Fahrzeug als Ziel hat
			local missileTarget = nil
			if ent.GetNWTarget then
				missileTarget = ent:GetNWTarget()
			elseif ent.GetTarget then
				missileTarget = ent:GetTarget()
			end
			
			if missileTarget == vehicle then
				-- Rakete verfolgt dieses Fahrzeug
				local dist = vehiclePos:Distance(ent:GetPos())
				
				-- Prüfe ob Rakete von hinten kommt (in einem 90° Kegel)
				local dirToMissile = (ent:GetPos() - vehiclePos):GetNormalized()
				local angle = math.deg(math.acos(math.Clamp(vehicleForward:Dot(-dirToMissile), -1, 1)))
				
				if angle < 90 and dist < 5000 then
					hasMissileThreat = true
					if dist < closestDist then
						closestDist = dist
						closestMissile = ent
					end
				end
			else
				-- Prüfe auch Raketen, die in der Nähe sind und sich auf das Fahrzeug zubewegen
				local dist = vehiclePos:Distance(ent:GetPos())
				if dist < 3000 then
					local dirToMissile = (ent:GetPos() - vehiclePos):GetNormalized()
					local angle = math.deg(math.acos(math.Clamp(vehicleForward:Dot(-dirToMissile), -1, 1)))
					
					-- Prüfe ob Rakete sich auf Fahrzeug zubewegt
					local missileVel = ent:GetVelocity()
					if missileVel:Length() > 0 then
						local missileDir = missileVel:GetNormalized()
						local dirToVehicle = (vehiclePos - ent:GetPos()):GetNormalized()
						local approachAngle = math.deg(math.acos(math.Clamp(missileDir:Dot(dirToVehicle), -1, 1)))
						
						if approachAngle < 45 and angle < 90 then
							hasMissileThreat = true
							if dist < closestDist then
								closestDist = dist
								closestMissile = ent
							end
						end
					end
				end
			end
		end
		
		-- Wenn eine Raketen-Bedrohung erkannt wurde, stoße Flares aus
		if hasMissileThreat and closestMissile then
			-- Prüfe Munition
			local hasAmmo = false
			if vehicle.FlareSystem then
				-- Unity Flares System
				hasAmmo = true -- Unity System verwaltet Munition intern
			else
				-- Prüfe Waffen-Munition
				if vehicle.WEAPONS then
					for podID, weapons in pairs(vehicle.WEAPONS) do
						if istable(weapons) then
							for weaponID, weapon in pairs(weapons) do
								if istable(weapon) and weapon.Attack then
									local icon = weapon.Icon
									if icon then
										local iconPath = tostring(icon)
										if string.find(iconPath, "flare") or string.find(iconPath, "unitys_flares") then
											local pod = vehicle:GetPassengerSeats()[podID]
											if IsValid(pod) then
												local weaponEnt = pod:lvsGetWeapon()
												if IsValid(weaponEnt) and weaponEnt:GetAmmo() > 0 then
													hasAmmo = true
													break
												end
											end
										end
									end
								end
							end
						end
						if hasAmmo then break end
					end
				end
			end
			
			if hasAmmo then
				-- Stoße Flares aus
				FireFlares(vehicle)
				
				-- Setze Cooldown (2-4 Sekunden, abhängig von Entfernung)
				local cooldown = math.Clamp(closestDist / 1000, 2, 4)
				vehicle._lastAIFlareTime = T + cooldown
			end
		end
	end
end)

print("[EastGermanCrusader LVS Overhaul] KI Flare System geladen!")
