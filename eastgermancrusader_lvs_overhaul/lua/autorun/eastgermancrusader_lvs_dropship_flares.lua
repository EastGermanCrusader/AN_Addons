-- EastGermanCrusader LVS Overhaul - LAAT Dropship Flare System
print("[LAAT Dropship Flares] Lade... (" .. (SERVER and "SERVER" or "CLIENT") .. ")")

local FLARE_CONFIG = {
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
}

local FLARE_ICON = Material("unitys_flares/flares.png")
if FLARE_ICON:IsError() then FLARE_ICON = Material("lvs/weapons/smoke_launcher.png") end

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
        
        if not IsValid(veh.SNDFlare) then
            veh.SNDFlare = veh:AddSoundEmitter(Vector(0,0,0), "unitys_flares/flare_deploy_ext.mp3", "unitys_flares/flare_deploy_ext.mp3")
            if IsValid(veh.SNDFlare) then veh.SNDFlare:SetSoundLevel(110) end
        end
        
        if not IsValid(veh.SNDFlareInterface) then
            veh.SNDFlareInterface = veh:AddSoundEmitter(Vector(0,0,0), nil, "unitys_flares/flare_deploy_int.mp3")
            if IsValid(veh.SNDFlareInterface) then veh.SNDFlareInterface:SetSoundLevel(160) end
        end
        
        if IsValid(veh.SNDFlareInterface) then veh.SNDFlareInterface:PlayOnce(100 + math.Rand(-3,3), 1) end
        
        local timerName = "EGC_Dropship_Flares_" .. veh:EntIndex() .. "_" .. math.floor(CurTime() * 1000)
        
        timer.Create(timerName, 0.1, FLARE_CONFIG.BurstAmount, function()
            if not IsValid(veh) then return end
            
            for _, data in ipairs(FLARE_CONFIG.Positions) do
                local flare = nil
                if scripted_ents.GetStored("unity_flare") then flare = ents.Create("unity_flare") end
                
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
                    local effectdata = EffectData()
                    effectdata:SetOrigin(veh:LocalToWorld(data.pos))
                    util.Effect("MuzzleFlash", effectdata)
                end
            end
            
            if IsValid(veh.SNDFlare) then veh.SNDFlare:PlayOnce(100 + math.Rand(-3, 3), 1) end
            veh:TakeAmmo()
        end)
    end
    
    weapon.OnSelect = function(ent) if IsValid(ent) then ent:EmitSound("physics/metal/weapon_impact_soft3.wav") end end
    weapon.OnOverheat = function(ent) if IsValid(ent) then ent:EmitSound("lvs/overheat.wav") end end
    
    return weapon
end

local ProcessedVehicles = {}

local function SetupFlares(vehicle)
    if not IsValid(vehicle) then return false end
    if vehicle:GetClass() ~= "lvs_repulsorlift_dropship" then return false end
    
    local entIndex = vehicle:EntIndex()
    if ProcessedVehicles[entIndex] then return false end
    
    if not vehicle.WEAPONS then return false end
    if not vehicle.WEAPONS[1] then vehicle.WEAPONS[1] = {} end
    
    local foundFlare = false
    for i, weapon in ipairs(vehicle.WEAPONS[1]) do
        if weapon._isEGCFlare then foundFlare = true weapon.Icon = FLARE_ICON end
    end
    
    if not foundFlare then
        local flareWeapon = CreateFlareWeapon()
        if vehicle.AddWeapon then vehicle:AddWeapon(flareWeapon, 1)
        else table.insert(vehicle.WEAPONS[1], flareWeapon) end
        if SERVER then print("[LAAT Dropship] Flares hinzugefügt") end
    end
    
    ProcessedVehicles[entIndex] = true
    return true
end

hook.Add("OnEntityCreated", "EGC_Dropship_Flares", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "lvs_repulsorlift_dropship" then return end
    for i = 1, 10 do timer.Simple(i * 0.5, function() if IsValid(ent) then SetupFlares(ent) end end) end
end)

hook.Add("InitPostEntity", "EGC_Dropship_Flares_Init", function()
    for i = 1, 10 do
        timer.Simple(i, function()
            if LVS and LVS.GetVehicles then
                for _, v in pairs(LVS:GetVehicles() or {}) do
                    if IsValid(v) and v:GetClass() == "lvs_repulsorlift_dropship" then SetupFlares(v) end
                end
            end
        end)
    end
end)

local NextCheck = 0
hook.Add("Think", "EGC_Dropship_Flares_Think", function()
    if CurTime() < NextCheck then return end
    NextCheck = CurTime() + 5
    
    if LVS and LVS.GetVehicles then
        for _, v in pairs(LVS:GetVehicles() or {}) do
            if IsValid(v) and v:GetClass() == "lvs_repulsorlift_dropship" then SetupFlares(v) end
        end
    end
end)

hook.Add("EntityRemoved", "EGC_Dropship_Cleanup", function(ent)
    if IsValid(ent) then ProcessedVehicles[ent:EntIndex()] = nil end
end)

print("[LAAT Dropship Flares] Geladen!")
