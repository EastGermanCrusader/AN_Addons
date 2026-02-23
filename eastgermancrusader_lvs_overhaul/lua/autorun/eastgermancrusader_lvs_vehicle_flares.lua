-- EastGermanCrusader LVS Overhaul - Vehicle Flare System
-- Fügt Flares zu verschiedenen LVS Fahrzeugen hinzu
-- Unterstützte Fahrzeuge: LAAT, Dropship, Gunship, V-Wing, N1, Rho-Class

if not LVS then return end

print("[EGC Vehicle Flares] Lade... (" .. (SERVER and "SERVER" or "CLIENT") .. ")")

-- ============================================
-- FAHRZEUG-KONFIGURATIONEN
-- ============================================

local VEHICLE_FLARE_CONFIGS = {
	-- LAAT/i Gunship (normale Version)
	["lvs_repulsorlift_gunship"] = {
		Ammo = 24,
		Delay = 1.5,
		BurstAmount = 6,
		FlareHeatSignature = 60,
		Positions = {
			{ pos = Vector(-100, -80, -20), dir = Vector(-1, -0.5, 0.3) },
			{ pos = Vector(-100, 80, -20), dir = Vector(-1, 0.5, 0.3) },
			{ pos = Vector(-100, -80, -40), dir = Vector(-1, -0.5, -0.3) },
			{ pos = Vector(-100, 80, -40), dir = Vector(-1, 0.5, -0.3) },
		}
	},
	
	-- LAAT/c Dropship
	["lvs_repulsorlift_dropship"] = {
		Ammo = 20,
		Delay = 1.5,
		BurstAmount = 5,
		FlareHeatSignature = 55,
		Positions = {
			{ pos = Vector(-120, -60, -15), dir = Vector(-1, -0.5, 0.2) },
			{ pos = Vector(-120, 60, -15), dir = Vector(-1, 0.5, 0.2) },
			{ pos = Vector(-120, -60, -35), dir = Vector(-1, -0.5, -0.2) },
			{ pos = Vector(-120, 60, -35), dir = Vector(-1, 0.5, -0.2) },
		}
	},
	
	-- V-Wing Starfighter
	["lvs_starfighter_vwing"] = {
		Ammo = 12,
		Delay = 2,
		BurstAmount = 4,
		FlareHeatSignature = 45,
		Positions = {
			{ pos = Vector(-30, -25, 0), dir = Vector(-1, -0.6, 0.2) },
			{ pos = Vector(-30, 25, 0), dir = Vector(-1, 0.6, 0.2) },
			{ pos = Vector(-30, -25, -10), dir = Vector(-1, -0.6, -0.2) },
			{ pos = Vector(-30, 25, -10), dir = Vector(-1, 0.6, -0.2) },
		}
	},
	
	-- N1 Starfighter
	["lvs_starfighter_n1"] = {
		Ammo = 12,
		Delay = 2,
		BurstAmount = 4,
		FlareHeatSignature = 45,
		Positions = {
			{ pos = Vector(-40, -20, 5), dir = Vector(-1, -0.5, 0.3) },
			{ pos = Vector(-40, 20, 5), dir = Vector(-1, 0.5, 0.3) },
			{ pos = Vector(-40, -20, -5), dir = Vector(-1, -0.5, -0.3) },
			{ pos = Vector(-40, 20, -5), dir = Vector(-1, 0.5, -0.3) },
		}
	},
	
	-- Rho-Class Shuttle (alle Varianten)
	["lvs_repulsorlift_rho_class_imperial"] = {
		Ammo = 16,
		Delay = 2,
		BurstAmount = 4,
		FlareHeatSignature = 50,
		Positions = {
			{ pos = Vector(-80, -40, 0), dir = Vector(-1, -0.4, 0.2) },
			{ pos = Vector(-80, 40, 0), dir = Vector(-1, 0.4, 0.2) },
			{ pos = Vector(-80, -40, -20), dir = Vector(-1, -0.4, -0.2) },
			{ pos = Vector(-80, 40, -20), dir = Vector(-1, 0.4, -0.2) },
		}
	},
	["lvs_repulsorlift_rho_class"] = {
		Ammo = 16,
		Delay = 2,
		BurstAmount = 4,
		FlareHeatSignature = 50,
		Positions = {
			{ pos = Vector(-80, -40, 0), dir = Vector(-1, -0.4, 0.2) },
			{ pos = Vector(-80, 40, 0), dir = Vector(-1, 0.4, 0.2) },
			{ pos = Vector(-80, -40, -20), dir = Vector(-1, -0.4, -0.2) },
			{ pos = Vector(-80, 40, -20), dir = Vector(-1, 0.4, -0.2) },
		}
	},
	["lvs_repulsorlift_rho_class_medical_2"] = {
		Ammo = 16,
		Delay = 2,
		BurstAmount = 4,
		FlareHeatSignature = 50,
		Positions = {
			{ pos = Vector(-80, -40, 0), dir = Vector(-1, -0.4, 0.2) },
			{ pos = Vector(-80, 40, 0), dir = Vector(-1, 0.4, 0.2) },
			{ pos = Vector(-80, -40, -20), dir = Vector(-1, -0.4, -0.2) },
			{ pos = Vector(-80, 40, -20), dir = Vector(-1, 0.4, -0.2) },
		}
	},
	["lvs_repulsorlift_rho_class_medical"] = {
		Ammo = 16,
		Delay = 2,
		BurstAmount = 4,
		FlareHeatSignature = 50,
		Positions = {
			{ pos = Vector(-80, -40, 0), dir = Vector(-1, -0.4, 0.2) },
			{ pos = Vector(-80, 40, 0), dir = Vector(-1, 0.4, 0.2) },
			{ pos = Vector(-80, -40, -20), dir = Vector(-1, -0.4, -0.2) },
			{ pos = Vector(-80, 40, -20), dir = Vector(-1, 0.4, -0.2) },
		}
	},
	["lvs_repulsorlift_rho_class_republic"] = {
		Ammo = 16,
		Delay = 2,
		BurstAmount = 4,
		FlareHeatSignature = 50,
		Positions = {
			{ pos = Vector(-80, -40, 0), dir = Vector(-1, -0.4, 0.2) },
			{ pos = Vector(-80, 40, 0), dir = Vector(-1, 0.4, 0.2) },
			{ pos = Vector(-80, -40, -20), dir = Vector(-1, -0.4, -0.2) },
			{ pos = Vector(-80, 40, -20), dir = Vector(-1, 0.4, -0.2) },
		}
	},
	["lvs_repulsorlift_rho_class_republic_2"] = {
		Ammo = 16,
		Delay = 2,
		BurstAmount = 4,
		FlareHeatSignature = 50,
		Positions = {
			{ pos = Vector(-80, -40, 0), dir = Vector(-1, -0.4, 0.2) },
			{ pos = Vector(-80, 40, 0), dir = Vector(-1, 0.4, 0.2) },
			{ pos = Vector(-80, -40, -20), dir = Vector(-1, -0.4, -0.2) },
			{ pos = Vector(-80, 40, -20), dir = Vector(-1, 0.4, -0.2) },
		}
	},
	
	-- LAAT Space Versionen
	["lvs_space_laat_arc"] = {
		Ammo = 24,
		Delay = 1.5,
		BurstAmount = 6,
		FlareHeatSignature = 60,
		Positions = {
			{ pos = Vector(-100, -70, -10), dir = Vector(-1, -0.5, 0.3) },
			{ pos = Vector(-100, 70, -10), dir = Vector(-1, 0.5, 0.3) },
			{ pos = Vector(-100, -70, -30), dir = Vector(-1, -0.5, -0.3) },
			{ pos = Vector(-100, 70, -30), dir = Vector(-1, 0.5, -0.3) },
		}
	},
	["lvs_space_laat"] = {
		Ammo = 24,
		Delay = 1.5,
		BurstAmount = 6,
		FlareHeatSignature = 60,
		Positions = {
			{ pos = Vector(-100, -70, -10), dir = Vector(-1, -0.5, 0.3) },
			{ pos = Vector(-100, 70, -10), dir = Vector(-1, 0.5, 0.3) },
			{ pos = Vector(-100, -70, -30), dir = Vector(-1, -0.5, -0.3) },
			{ pos = Vector(-100, 70, -30), dir = Vector(-1, 0.5, -0.3) },
		}
	},
}

-- ============================================
-- ICON MATERIAL
-- ============================================

local FLARE_ICON = Material("unitys_flares/flares.png")
if FLARE_ICON:IsError() then
	FLARE_ICON = Material("lvs/weapons/smoke_launcher.png")
end

-- ============================================
-- FLARE WAFFE ERSTELLEN
-- ============================================

local function CreateFlareWeapon(config)
	local weapon = {}
	weapon._isEGCVehicleFlare = true
	weapon.Icon = FLARE_ICON
	weapon.Ammo = config.Ammo
	weapon.Delay = config.Delay
	weapon.HeatRateUp = 0
	weapon.HeatRateDown = 0
	weapon.UseableByAI = false
	
	weapon.Attack = function(veh)
		if not SERVER then return end
		if not IsValid(veh) then return end
		
		-- Sound-Emitter erstellen
		if not IsValid(veh.SNDFlare) then
			veh.SNDFlare = veh:AddSoundEmitter(Vector(0,0,0), "unitys_flares/flare_deploy_ext.mp3", "unitys_flares/flare_deploy_ext.mp3")
			if IsValid(veh.SNDFlare) then veh.SNDFlare:SetSoundLevel(110) end
		end
		
		if not IsValid(veh.SNDFlareInterface) then
			veh.SNDFlareInterface = veh:AddSoundEmitter(Vector(0,0,0), nil, "unitys_flares/flare_deploy_int.mp3")
			if IsValid(veh.SNDFlareInterface) then veh.SNDFlareInterface:SetSoundLevel(160) end
		end
		
		if IsValid(veh.SNDFlareInterface) then
			veh.SNDFlareInterface:PlayOnce(100 + math.Rand(-3,3), 1)
		end
		
		local timerName = "EGC_VehicleFlares_" .. veh:EntIndex() .. "_" .. math.floor(CurTime() * 1000)
		
		timer.Create(timerName, 0.1, config.BurstAmount, function()
			if not IsValid(veh) then return end
			
			for _, data in ipairs(config.Positions) do
				local flare = nil
				if scripted_ents.GetStored("unity_flare") then
					flare = ents.Create("unity_flare")
				end
				
				if IsValid(flare) then
					flare:SetPos(veh:LocalToWorld(data.pos))
					flare:SetAngles(Angle())
					flare:Spawn()
					flare:Activate()
					
					if flare.SetEntityFilter and veh.GetCrosshairFilterEnts then
						flare:SetEntityFilter(veh:GetCrosshairFilterEnts())
					end
					
					flare._heatSignature = config.FlareHeatSignature
					flare.GetHeatSignature = function(s) return s._heatSignature or 50 end
					flare.GetFlareStrength = function(s) return 4 * (s._heatSignature or 50) end
					
					local phys = flare:GetPhysicsObject()
					if IsValid(phys) then
						local worldDir = veh:LocalToWorldAngles(data.dir:Angle()):Forward()
						phys:SetVelocity(veh:GetVelocity() + worldDir * 800 + VectorRand() * 50)
					end
					
					flare:SetCollisionGroup(COLLISION_GROUP_NONE)
				else
					-- Fallback visueller Effekt
					local effectdata = EffectData()
					effectdata:SetOrigin(veh:LocalToWorld(data.pos))
					util.Effect("MuzzleFlash", effectdata)
				end
			end
			
			if IsValid(veh.SNDFlare) then
				veh.SNDFlare:PlayOnce(100 + math.Rand(-3, 3), 1)
			end
			
			veh:TakeAmmo()
		end)
	end
	
	weapon.OnSelect = function(ent)
		if IsValid(ent) then
			ent:EmitSound("physics/metal/weapon_impact_soft3.wav")
		end
	end
	
	weapon.OnOverheat = function(ent)
		if IsValid(ent) then
			ent:EmitSound("lvs/overheat.wav")
		end
	end
	
	return weapon
end

-- ============================================
-- HAUPTFUNKTION: Flare-Waffe hinzufügen
-- ============================================

local ProcessedVehicles = {}

local function SetupVehicleFlares(vehicle)
	if not IsValid(vehicle) then return false end
	if not vehicle.LVS then return false end
	
	local class = vehicle:GetClass()
	local config = VEHICLE_FLARE_CONFIGS[class]
	
	if not config then return false end
	
	local entIndex = vehicle:EntIndex()
	if ProcessedVehicles[entIndex] then return false end
	
	-- Warte bis WEAPONS initialisiert ist
	if not vehicle.WEAPONS then 
		return false 
	end
	
	-- Finde den ersten Waffen-Slot (normalerweise für den Piloten)
	local weaponSlot = 1
	if not vehicle.WEAPONS[weaponSlot] then
		vehicle.WEAPONS[weaponSlot] = {}
	end
	
	-- Prüfe ob das WEAPONS-Array leer ist (noch nicht initialisiert)
	if #vehicle.WEAPONS[weaponSlot] == 0 then
		return false -- Noch nicht bereit
	end
	
	-- Prüfe ob bereits eine Flare-Waffe existiert
	local foundFlare = false
	for i, weapon in ipairs(vehicle.WEAPONS[weaponSlot]) do
		if weapon._isEGCVehicleFlare then
			foundFlare = true
			weapon.Icon = FLARE_ICON
			break
		end
	end
	
	-- Wenn keine Flare-Waffe gefunden, füge eine hinzu
	if not foundFlare then
		local flareWeapon = CreateFlareWeapon(config)
		
		if vehicle.AddWeapon then
			vehicle:AddWeapon(flareWeapon, weaponSlot)
			if SERVER then
				print("[EGC Vehicle Flares] Flares zu " .. class .. " hinzugefügt (AddWeapon)")
			end
		else
			table.insert(vehicle.WEAPONS[weaponSlot], flareWeapon)
			if SERVER then
				print("[EGC Vehicle Flares] Flares zu " .. class .. " hinzugefügt (table.insert)")
			end
		end
	end
	
	ProcessedVehicles[entIndex] = true
	return true
end

-- ============================================
-- HOOKS
-- ============================================

hook.Add("OnEntityCreated", "EGC_VehicleFlares_Created", function(ent)
	if not IsValid(ent) then return end
	
	-- Verzögerte Prüfung ob es ein LVS-Fahrzeug ist
	timer.Simple(0.1, function()
		if not IsValid(ent) then return end
		if not ent.LVS then return end
		
		local class = ent:GetClass()
		if not VEHICLE_FLARE_CONFIGS[class] then return end
		
		-- Verzögerte Setup-Versuche (länger warten für Server-Sync)
		for i = 1, 20 do
			timer.Simple(i * 0.5, function()
				if IsValid(ent) then
					SetupVehicleFlares(ent)
				end
			end)
		end
	end)
end)

hook.Add("InitPostEntity", "EGC_VehicleFlares_Init", function()
	for i = 1, 20 do
		timer.Simple(i, function()
			if LVS and LVS.GetVehicles then
				for _, v in pairs(LVS:GetVehicles() or {}) do
					if IsValid(v) then
						SetupVehicleFlares(v)
					end
				end
			end
		end)
	end
end)

-- Kontinuierliche Prüfung alle 3 Sekunden
local NextCheck = 0
hook.Add("Think", "EGC_VehicleFlares_Think", function()
	if CurTime() < NextCheck then return end
	NextCheck = CurTime() + 3
	
	if LVS and LVS.GetVehicles then
		for _, v in pairs(LVS:GetVehicles() or {}) do
			if IsValid(v) then
				SetupVehicleFlares(v)
			end
		end
	end
end)

hook.Add("EntityRemoved", "EGC_VehicleFlares_Cleanup", function(ent)
	if IsValid(ent) and ent:EntIndex() then
		ProcessedVehicles[ent:EntIndex()] = nil
	end
end)

-- LVS-spezifischer Hook (wenn verfügbar)
hook.Add("LVS:PostInitialize", "EGC_VehicleFlares_LVSInit", function(vehicle)
	if not IsValid(vehicle) then return end
	
	local class = vehicle:GetClass()
	if not VEHICLE_FLARE_CONFIGS[class] then return end
	
	-- Sofort und verzögert versuchen
	SetupVehicleFlares(vehicle)
	
	for i = 1, 10 do
		timer.Simple(i * 0.5, function()
			if IsValid(vehicle) then
				SetupVehicleFlares(vehicle)
			end
		end)
	end
end)

-- ============================================
-- DEBUG BEFEHL
-- ============================================

if SERVER then
	concommand.Add("egc_flares_debug", function(ply)
		local function Output(msg)
			print(msg)
			if IsValid(ply) then
				ply:ChatPrint(msg)
			end
		end
		
		Output("=== EGC Vehicle Flares DEBUG ===")
		
		if not LVS or not LVS.GetVehicles then
			Output("ERROR: LVS nicht gefunden!")
			return
		end
		
		local vehicles = LVS:GetVehicles() or {}
		Output("Gefundene LVS Fahrzeuge: " .. table.Count(vehicles))
		
		for _, v in pairs(vehicles) do
			if IsValid(v) then
				local class = v:GetClass()
				local hasConfig = VEHICLE_FLARE_CONFIGS[class] ~= nil
				local processed = ProcessedVehicles[v:EntIndex()] == true
				
				Output(class .. ": Config=" .. (hasConfig and "JA" or "NEIN") .. ", Processed=" .. (processed and "JA" or "NEIN"))
				
				if v.WEAPONS then
					Output("  -> WEAPONS existiert: JA")
					if v.WEAPONS[1] then
						Output("  -> WEAPONS[1] Anzahl: " .. #v.WEAPONS[1])
						local hasFlare = false
						for i, w in ipairs(v.WEAPONS[1]) do
							if w._isEGCVehicleFlare then
								hasFlare = true
								Output("  -> Flare-Waffe gefunden an Position " .. i)
								break
							end
						end
						if not hasFlare then
							Output("  -> KEINE Flare-Waffe gefunden!")
						end
					else
						Output("  -> WEAPONS[1] nicht vorhanden!")
					end
				else
					Output("  -> WEAPONS nicht vorhanden!")
				end
			end
		end
		
		Output("Unterstützte Fahrzeuge:")
		for class, _ in pairs(VEHICLE_FLARE_CONFIGS) do
			Output("  - " .. class)
		end
	end)
	
	-- Force-Setup Befehl
	concommand.Add("egc_flares_force", function(ply)
		local function Output(msg)
			print(msg)
			if IsValid(ply) then
				ply:ChatPrint(msg)
			end
		end
		
		Output("=== EGC Vehicle Flares FORCE SETUP ===")
		
		-- Reset ProcessedVehicles
		ProcessedVehicles = {}
		
		if not LVS or not LVS.GetVehicles then
			Output("ERROR: LVS nicht gefunden!")
			return
		end
		
		local vehicles = LVS:GetVehicles() or {}
		local count = 0
		
		for _, v in pairs(vehicles) do
			if IsValid(v) then
				local class = v:GetClass()
				if VEHICLE_FLARE_CONFIGS[class] then
					if SetupVehicleFlares(v) then
						count = count + 1
						Output("Flares hinzugefügt zu: " .. class)
					else
						Output("Konnte keine Flares hinzufügen zu: " .. class)
					end
				end
			end
		end
		
		Output("Fertig! " .. count .. " Fahrzeuge mit Flares ausgestattet.")
	end)
end

print("[EGC Vehicle Flares] Geladen! (" .. (SERVER and "SERVER" or "CLIENT") .. ")")
print("[EGC Vehicle Flares] Unterstützte Fahrzeuge: " .. table.Count(VEHICLE_FLARE_CONFIGS))
