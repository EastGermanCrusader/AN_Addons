-- EastGermanCrusader LVS Overhaul - ARC-170 Flare System
-- Fügt Flares mit X-Form zum ARC-170 hinzu und korrigiert das Icon

print("[ARC-170 Flares] Lade... (" .. (SERVER and "SERVER" or "CLIENT") .. ")")

-- ============================================
-- KONFIGURATION
-- ============================================

local FLARE_CONFIG = {
    Ammo = 16,
    Delay = 2,
    BurstAmount = 5,
    FlareHeatSignature = 50,
    -- X-Form Positionen und Richtungen
    Positions = {
        { pos = Vector(-41, -150, -30), dir = Vector(-1, -0.5, 0.3) },   -- Links-Oben
        { pos = Vector(-41, 150, -30), dir = Vector(-1, 0.5, 0.3) },     -- Rechts-Oben
        { pos = Vector(-41, -150, -50), dir = Vector(-1, -0.5, -0.3) },  -- Links-Unten
        { pos = Vector(-41, 150, -50), dir = Vector(-1, 0.5, -0.3) },    -- Rechts-Unten
    }
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

local function CreateFlareWeapon()
    local weapon = {}
    weapon._isEGCFlare = true
    weapon.Icon = FLARE_ICON
    weapon.Ammo = FLARE_CONFIG.Ammo
    weapon.Delay = FLARE_CONFIG.Delay
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
        
        local timerName = "EGC_Flares_" .. veh:EntIndex() .. "_" .. math.floor(CurTime() * 1000)
        
        timer.Create(timerName, 0.1, FLARE_CONFIG.BurstAmount, function()
            if not IsValid(veh) then return end
            
            for _, data in ipairs(FLARE_CONFIG.Positions) do
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
                    
                    flare._heatSignature = FLARE_CONFIG.FlareHeatSignature
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
-- HAUPTFUNKTION: Flare-Waffe hinzufügen/korrigieren
-- ============================================

local ProcessedVehicles = {}

local function SetupARC170Flares(vehicle)
    if not IsValid(vehicle) then return false end
    if vehicle:GetClass() ~= "lvs_starfighter_arc170" then return false end
    
    local entIndex = vehicle:EntIndex()
    if ProcessedVehicles[entIndex] then return false end
    
    if not vehicle.WEAPONS then return false end
    if not vehicle.WEAPONS[1] then
        vehicle.WEAPONS[1] = {}
    end
    
    -- Suche nach existierender Flare-Waffe
    local foundFlare = false
    
    for i, weapon in ipairs(vehicle.WEAPONS[1]) do
        if weapon._isEGCFlare then
            foundFlare = true
            weapon.Icon = FLARE_ICON
        elseif weapon.Ammo == 16 and weapon.Delay == 2 then
            foundFlare = true
            weapon.Icon = FLARE_ICON
        end
    end
    
    -- Wenn keine Flare-Waffe gefunden, füge eine hinzu
    if not foundFlare then
        local flareWeapon = CreateFlareWeapon()
        
        if vehicle.AddWeapon then
            vehicle:AddWeapon(flareWeapon, 1)
        else
            table.insert(vehicle.WEAPONS[1], flareWeapon)
        end
    end
    
    ProcessedVehicles[entIndex] = true
    return true
end

-- ============================================
-- HOOKS
-- ============================================

hook.Add("OnEntityCreated", "EGC_ARC170_Flares", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "lvs_starfighter_arc170" then return end
    
    for i = 1, 10 do
        timer.Simple(i * 0.5, function()
            if IsValid(ent) then
                SetupARC170Flares(ent)
            end
        end)
    end
end)

hook.Add("InitPostEntity", "EGC_ARC170_Flares_Init", function()
    for i = 1, 10 do
        timer.Simple(i, function()
            if LVS and LVS.GetVehicles then
                for _, v in pairs(LVS:GetVehicles() or {}) do
                    if IsValid(v) and v:GetClass() == "lvs_starfighter_arc170" then
                        SetupARC170Flares(v)
                    end
                end
            end
        end)
    end
end)

local NextCheck = 0
hook.Add("Think", "EGC_ARC170_Flares_Think", function()
    if CurTime() < NextCheck then return end
    NextCheck = CurTime() + 5
    
    if LVS and LVS.GetVehicles then
        for _, v in pairs(LVS:GetVehicles() or {}) do
            if IsValid(v) and v:GetClass() == "lvs_starfighter_arc170" then
                SetupARC170Flares(v)
            end
        end
    end
end)

hook.Add("EntityRemoved", "EGC_ARC170_Cleanup", function(ent)
    if IsValid(ent) then
        ProcessedVehicles[ent:EntIndex()] = nil
    end
end)

-- ============================================
-- DEBUG BEFEHL
-- ============================================

if SERVER then
    concommand.Add("arc170_debug", function(ply)
        if not IsValid(ply) then return end
        
        ply:ChatPrint("=== ARC-170 DEBUG ===")
        
        if not LVS or not LVS.GetVehicles then
            ply:ChatPrint("ERROR: LVS nicht gefunden!")
            return
        end
        
        local vehicles = LVS:GetVehicles() or {}
        ply:ChatPrint("Gefundene LVS Fahrzeuge: " .. table.Count(vehicles))
        
        for _, v in pairs(vehicles) do
            if IsValid(v) and v:GetClass() == "lvs_starfighter_arc170" then
                ply:ChatPrint("ARC-170: " .. tostring(v))
                if v.WEAPONS and v.WEAPONS[1] then
                    ply:ChatPrint("  Waffen in Pod 1: " .. #v.WEAPONS[1])
                    for i, w in ipairs(v.WEAPONS[1]) do
                        local ammo = w.Ammo or "?"
                        local delay = w.Delay or "?"
                        local hasIcon = w.Icon and not w.Icon:IsError()
                        local isFlare = w._isEGCFlare or (w.Ammo == 16 and w.Delay == 2)
                        ply:ChatPrint("    [" .. i .. "] Ammo=" .. tostring(ammo) .. " Delay=" .. tostring(delay) .. " Icon=" .. (hasIcon and "OK" or "FEHLT") .. (isFlare and " <-- FLARE" or ""))
                    end
                else
                    ply:ChatPrint("  KEINE WAFFEN!")
                end
            end
        end
    end)
end

print("[ARC-170 Flares] Geladen!")
