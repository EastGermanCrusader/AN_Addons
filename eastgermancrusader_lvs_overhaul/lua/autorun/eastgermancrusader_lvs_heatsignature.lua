-- EastGermanCrusader LVS Overhaul - Hitzesignatur System - OPTIMIERT
-- Dieses Addon fügt allen LVS Fahrzeugen eine Hitzesignatur hinzu
-- PERFORMANCE OPTIMIERUNGEN:
-- - Eliminiert kontinuierlichen Think-Hook mit ents.GetAll()
-- - Verwendet effiziente Entity-Hooks für Funktions-Injection
-- - Keine wiederholten Funktions-Zuweisungen

if not LVS then return end

HeatSignatureConfig = HeatSignatureConfig or {
	Default = {
		H_base = 10,
		M = 50,
		W_multiplier = 30,
		HeatUpRate = 0.15,
		CoolDownRate = 0.08,
	},
}

-- Funktion zur Berechnung der Gesamtwaffenhitze
local function CalculateWeaponHeat(vehicle)
	if not IsValid(vehicle) or not vehicle.LVS then return 0 end
	if not vehicle.WEAPONS then return 0 end
	
	local totalWeaponHeat = 0
	
	for podID, weapons in pairs(vehicle.WEAPONS) do
		if istable(weapons) then
			for weaponID, weapon in pairs(weapons) do
				if istable(weapon) and weapon._CurHeat then
					totalWeaponHeat = totalWeaponHeat + (weapon._CurHeat or 0)
				end
			end
		end
	end
	
	return totalWeaponHeat
end

-- Funktion zur Berechnung der Ziel-Hitzesignatur (ohne Abkühlung)
local function CalculateTargetHeatSignature(vehicle)
	if not IsValid(vehicle) or not vehicle.LVS then return 0 end
	
	local config = HeatSignatureConfig[vehicle:GetClass()] or HeatSignatureConfig.Default
	
	local H_base = config.H_base or 10
	local M = config.M or 50
	local W_multiplier = config.W_multiplier or 30
	
	local E = vehicle:GetEngineActive() and 1 or 0
	
	local T = 0
	if vehicle.GetThrottle then
		T = math.Clamp(vehicle:GetThrottle(), 0, 1)
	end
	
	local W_ges = CalculateWeaponHeat(vehicle)
	
	local H_ges = 0
	if E == 1 then
		H_ges = H_base + (E * T * M) + (W_ges * W_multiplier)
	else
		H_ges = W_ges * W_multiplier
	end
	
	return H_ges
end

-- Funktion zur Berechnung der aktuellen Hitzesignatur (mit Abkühlung)
local function CalculateHeatSignature(vehicle)
	if not IsValid(vehicle) or not vehicle.LVS then return 0 end
	
	if not vehicle._heatSignatureCurrent then
		vehicle._heatSignatureCurrent = 0
		vehicle._heatSignatureLastUpdate = CurTime()
	end
	
	local targetHeat = CalculateTargetHeatSignature(vehicle)
	
	local config = HeatSignatureConfig[vehicle:GetClass()] or HeatSignatureConfig.Default
	local heatUpRate = config.HeatUpRate or 0.15
	local coolDownRate = config.CoolDownRate or 0.08
	
	local currentTime = CurTime()
	local deltaTime = currentTime - (vehicle._heatSignatureLastUpdate or currentTime)
	vehicle._heatSignatureLastUpdate = currentTime
	
	deltaTime = math.min(deltaTime, 0.1)
	
	local lerpRate = 0
	if targetHeat > vehicle._heatSignatureCurrent then
		lerpRate = heatUpRate * deltaTime
	else
		lerpRate = coolDownRate * deltaTime
	end
	
	local diff = targetHeat - vehicle._heatSignatureCurrent
	vehicle._heatSignatureCurrent = vehicle._heatSignatureCurrent + diff * lerpRate
	
	vehicle._heatSignatureCurrent = math.max(0, vehicle._heatSignatureCurrent)
	
	return vehicle._heatSignatureCurrent
end

-- Funktion zur Berechnung der Flare-Stärke für 80% Ablenkung
local function CalculateFlareStrength(vehicle)
	local H_ges = CalculateHeatSignature(vehicle)
	return 4 * H_ges
end

-- OPTIMIERT: Einmalige Funktions-Zuweisung
local function AddHeatSignatureFunctions(vehicle)
	if not IsValid(vehicle) then return false end
	if not vehicle.LVS then return false end
	
	-- OPTIMIERT: Prüfe ob Funktionen bereits existieren
	if vehicle.GetHeatSignature and vehicle.GetFlareStrength then
		return false -- Bereits vorhanden
	end
	
	vehicle.GetHeatSignature = function(self)
		return CalculateHeatSignature(self)
	end
	
	vehicle.GetFlareStrength = function(self)
		return CalculateFlareStrength(self)
	end
	
	return true
end

-- OPTIMIERT: Verwende PreRegisterSENT für saubere Integration
hook.Add("PreRegisterSENT", "EGC_HeatSignature", function(ent, class)
	if not ent.LVS then return end
	
	local OldPostInitialize = ent.PostInitialize
	
	ent.PostInitialize = function(self, PObj, ...)
		if OldPostInitialize then
			OldPostInitialize(self, PObj, ...)
		end
		
		AddHeatSignatureFunctions(self)
	end
end)

-- OPTIMIERT: Fallback für bereits gespawnte Entities (nur einmalig beim Laden)
hook.Add("OnEntityCreated", "EGC_HeatSignature_Fallback", function(ent)
	-- OPTIMIERT: Nur für LVS Entities, und nur einmalig
	timer.Simple(0.1, function()
		if not IsValid(ent) then return end
		if not ent.LVS then return end
		AddHeatSignatureFunctions(ent)
	end)
end)

-- OPTIMIERT: LVS-spezifischer Hook (wenn verfügbar)
hook.Add("LVS:PostInitialize", "EGC_HeatSignature_LVS", function(vehicle)
	if not IsValid(vehicle) then return end
	AddHeatSignatureFunctions(vehicle)
end)

-- OPTIMIERT: Einmaliger Setup beim Server-Start für bereits existierende Entities
if SERVER then
	hook.Add("Initialize", "EGC_HeatSignature_InitialSetup", function()
		-- OPTIMIERT: Nur EINMAL beim Server-Start, nicht wiederholt
		timer.Simple(1, function()
			local count = 0
			local totalLVS = 0
			
			-- Finde alle LVS Fahrzeuge EINMALIG
			for _, ent in pairs(ents.GetAll()) do
				if IsValid(ent) and ent.LVS then
					totalLVS = totalLVS + 1
					if AddHeatSignatureFunctions(ent) then
						count = count + 1
					end
				end
			end
			
			if totalLVS > 0 then
				print("[EGC Heat Signature] " .. count .. "/" .. totalLVS .. " LVS Fahrzeuge mit Hitzesignatur-Funktionen versehen")
			end
		end)
	end)
end

print("[EastGermanCrusader LVS Overhaul] Hitzesignatur System geladen - OPTIMIERT!")

-- ============================================
-- DEBUG SYSTEM
-- ============================================

if SERVER then
	AddCSLuaFile("autorun/client/eastgermancrusader_lvs_heatsignature_debug.lua")
	
	concommand.Add("lvs_heatsignature_debug", function(ply, cmd, args)
		if not IsValid(ply) then 
			print("=== HITZESIGNATUR DEBUG ===")
			print("Befehl muss von einem Spieler ausgeführt werden.")
			return 
		end
		
		local vehicle = ply:GetVehicle()
		if not IsValid(vehicle) then 
			ply:ChatPrint("Du sitzt in keinem Fahrzeug!")
			return 
		end
		
		local baseEnt = vehicle.LVSBaseEnt
		if not IsValid(baseEnt) then 
			ply:ChatPrint("Fahrzeug hat keine LVS Base Entity!")
			return 
		end
		if not baseEnt.LVS then 
			ply:ChatPrint("Dies ist kein LVS Fahrzeug!")
			return 
		end
		if not baseEnt.GetHeatSignature then 
			ply:ChatPrint("Hitzesignatur-Funktion nicht verfügbar!")
			return 
		end
		
		local heatSig = baseEnt:GetHeatSignature()
		local flareStr = baseEnt:GetFlareStrength()
		
		ply:ChatPrint("=== HITZESIGNATUR DEBUG ===")
		ply:ChatPrint("Fahrzeug: " .. baseEnt:GetClass())
		ply:ChatPrint("Hitzesignatur: " .. string.format("%.2f", heatSig))
		ply:ChatPrint("Flare-Stärke (80%): " .. string.format("%.2f", flareStr))
		ply:ChatPrint("Motor: " .. (baseEnt:GetEngineActive() and "AN" or "AUS"))
		
		if baseEnt.GetThrottle then
			local throttle = math.Clamp(baseEnt:GetThrottle(), 0, 1)
			ply:ChatPrint("Schub: " .. string.format("%.1f%%", throttle * 100))
		end
	end)
	
	print("[EGC Heat Signature] Debug-Befehl registriert: lvs_heatsignature_debug")
end
