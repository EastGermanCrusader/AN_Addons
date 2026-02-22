-- EastGermanCrusader LVS Overhaul - Merr-Sonn AA-1 "Sunstrike" Waffe - OPTIMIERT
-- Schultergestützter Raketenwerfer mit wärmesuchender Rakete
-- PERFORMANCE OPTIMIERUNGEN:
-- - Think-Hook nur aktiv wenn Raketen existieren
-- - Gecachte Missile-Entities
-- - Reduziertes Client-HUD Drawing

if not LVS then return end

print("[EastGermanCrusader LVS Overhaul] Lade Merr-Sonn AA-1 'Sunstrike' Waffe - OPTIMIERT...")

local SUNSTRIKE_CONFIG = {
    Name = "Merr-Sonn AA-1 \"Sunstrike\"",
    Ammo = 8,
    Delay = 0,
    HeatRateUp = -0.3,
    HeatRateDown = 0.25,
    Model = "models/weapons/w_rocket_launcher.mdl",
    Icon = Material("lvs/weapons/missile.png"),
    FirePosition = Vector(0, 0, 0),
    TrackingCone = 30,
    TrackingRange = 12000,
    MissileSpeed = 2900,
    MissileDamage = 750,
    MissileRadius = 300,
    MissileForce = 5000,
    MissileThrust = 500,
    MissileTurnSpeed = 1.5,
    EnableSunTarget = true,
    SunHeatSignature = 200,
    SunDistance = 50000,
}

-- OPTIMIERT: Cache für Sonnen-Entity
local CachedSunEntity = nil

local function GetSunDirection()
    local sunDir = Vector(0, -0.2, 0.98):GetNormalized()
    
    if CLIENT and render and render.GetSkyboxAngle then
        local skyAng = render.GetSkyboxAngle()
        if skyAng then
            sunDir = skyAng:Forward()
        end
    end
    
    return sunDir
end

-- OPTIMIERT: Erstelle Sonnen-Entity nur einmal
local function GetSunTargetEntity()
    -- OPTIMIERT: Verwende Cache
    if IsValid(CachedSunEntity) then
        return CachedSunEntity
    end
    
    if SERVER then
        local sunEnt = ents.Create("prop_physics")
        if IsValid(sunEnt) then
            sunEnt:SetModel("models/hunter/misc/sphere025x025.mdl")
            sunEnt:SetMaterial("models/debug/debugwhite")
            sunEnt:SetColor(Color(255, 200, 0, 0))
            sunEnt:SetRenderMode(RENDERMODE_NONE)
            sunEnt:SetNoDraw(true)
            sunEnt:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
            sunEnt:SetMoveType(MOVETYPE_NONE)
            sunEnt:Spawn()
            sunEnt:Activate()
            sunEnt._IsSunTarget = true
            sunEnt._IsSun = true
            
            local sunDir = GetSunDirection()
            local sunPos = Vector(0, 0, 0) + sunDir * SUNSTRIKE_CONFIG.SunDistance
            sunEnt:SetPos(sunPos)
            
            -- OPTIMIERT: Cache speichern
            CachedSunEntity = sunEnt
            
            return sunEnt
        end
    end
    
    return NULL
end

function CreateSunstrikeWeapon(firePosition)
    local weapon = {}
    
    weapon._isSunstrike = true
    weapon.Name = SUNSTRIKE_CONFIG.Name
    weapon.Icon = SUNSTRIKE_CONFIG.Icon
    weapon.Ammo = SUNSTRIKE_CONFIG.Ammo
    weapon.Delay = SUNSTRIKE_CONFIG.Delay
    weapon.HeatRateUp = SUNSTRIKE_CONFIG.HeatRateUp
    weapon.HeatRateDown = SUNSTRIKE_CONFIG.HeatRateDown
    weapon.UseableByAI = true
    
    weapon._FirePosition = firePosition or SUNSTRIKE_CONFIG.FirePosition
    
    local function GetHeatSignature(ent)
        if not IsValid(ent) then return 0 end
        
        if ent._IsSun then
            return SUNSTRIKE_CONFIG.SunHeatSignature
        end
        
        if ent.GetHeatSignature then
            return ent:GetHeatSignature()
        end
        
        local heat = 10
        
        if ent.LVS then
            if ent:GetEngineActive() then
                local throttle = 0
                if ent.GetThrottle then
                    throttle = math.Clamp(ent:GetThrottle(), 0, 1)
                end
                heat = heat + (throttle * 50)
            end
            
            if ent.WEAPONS then
                local weaponHeat = 0
                for podID, weapons in pairs(ent.WEAPONS) do
                    if istable(weapons) then
                        for weaponID, weapon in pairs(weapons) do
                            if istable(weapon) and weapon._CurHeat then
                                weaponHeat = weaponHeat + (weapon._CurHeat or 0)
                            end
                        end
                    end
                end
                heat = heat + (weaponHeat * 30)
            end
        end
        
        if ent:IsVehicle() then
            heat = heat + 25
        end
        
        if ent:IsNPC() then
            heat = heat + 10
        end
        
        if ent:IsOnFire() then
            heat = heat + 80
        end
        
        return heat
    end
    
    local function FindHeatSeekingTarget(missile, pos, forward, cone_ang, cone_len, useFullCone)
        if not SERVER then return end
        if not IsValid(missile) then return end
        
        if useFullCone then
            cone_ang = 360
        end
        
        local targets = missile:GetAvailableTargets()
        local Attacker = missile:GetAttacker()
        local Parent = missile:GetParent()
        local Owner = missile:GetOwner()
        local BestTarget = NULL
        local BestScore = 0
        
        if SUNSTRIKE_CONFIG.EnableSunTarget then
            local sunDir = GetSunDirection()
            local sunPos = pos + sunDir * SUNSTRIKE_CONFIG.SunDistance
            local dirToSun = (sunPos - pos):GetNormalized()
            local distToSun = SUNSTRIKE_CONFIG.SunDistance
            
            local sunAngle = math.deg(math.acos(math.Clamp(forward:Dot(dirToSun), -1, 1)))
            local sunInCone = useFullCone or (sunAngle <= cone_ang)
            
            if sunInCone and distToSun <= cone_len then
                local sunHeat = SUNSTRIKE_CONFIG.SunHeatSignature
                local distScore = 0.1
                local heatScore = math.min(sunHeat / 100, 1)
                local angScore = useFullCone and 1 or math.max(0, 1 - (sunAngle / cone_ang))
                
                local sunScore = heatScore * 0.5 + angScore * 0.3 + distScore * 0.2
                
                if sunScore > BestScore then
                    BestScore = sunScore
                    BestTarget = GetSunTargetEntity()
                end
            end
        end
        
        for _, target in ipairs(targets) do
            if not IsValid(target) then continue end
            if target == Attacker or target == Parent or target == Owner then continue end
            if target == missile then continue end
            
            local targetPos = target:LocalToWorld(target:OBBCenter())
            local dirToTarget = (targetPos - pos):GetNormalized()
            local distToTarget = pos:Distance(targetPos)
            
            local angle = math.deg(math.acos(math.Clamp(forward:Dot(dirToTarget), -1, 1)))
            local inCone = useFullCone or (angle <= cone_ang)
            
            if not inCone then continue end
            if distToTarget > cone_len then continue end
            
            local heat = GetHeatSignature(target)
            
            local distScore = math.max(0, 1 - (distToTarget / cone_len))
            local heatScore = math.min(heat / 100, 1)
            local angScore = useFullCone and 1 or math.max(0, 1 - (angle / cone_ang))
            
            local score = heatScore * 0.5 + angScore * 0.3 + distScore * 0.2
            
            if score > BestScore then
                BestScore = score
                BestTarget = target
            end
        end
        
        if IsValid(BestTarget) then
            missile:SetNWTarget(BestTarget)
        end
    end
    
    weapon.OnThink = function(ent)
        -- Aktualisiere Hitze basierend auf Feuer-Status
        local heat = ent:GetHeat() or 0
        
        if ent:GetFireMode() and ent:GetAmmo() > 0 then
            heat = math.Clamp(heat + SUNSTRIKE_CONFIG.HeatRateUp, 0, 1)
        else
            heat = math.Clamp(heat + SUNSTRIKE_CONFIG.HeatRateDown, 0, 1)
        end
        
        ent:SetHeat(heat)
        
        -- Verhindere überhitzen (falls HeatRateUp zu negativ ist)
        if heat > 0.99 then
            if ent.OnOverheat then
                ent:OnOverheat()
            end
        end
    end
    
    weapon.OnFire = function(ent)
        if not SERVER then return end
        if not IsValid(ent) then return end
        
        local FirePos = ent:LocalToWorld(weapon._FirePosition)
        local FireDir = ent:GetAimVector()
        
        ent:EmitSound("lvs/weapons/missile_fire.wav")
        
        local missile = ents.Create("lvs_missile")
        
        if IsValid(missile) then
            missile._IsSunstrikeMissile = true
            missile._TrackingCone = SUNSTRIKE_CONFIG.TrackingCone
            missile._TrackingRange = SUNSTRIKE_CONFIG.TrackingRange
            
            missile:SetPos(FirePos)
            missile:SetAngles(FireDir:Angle())
            missile:Spawn()
            missile:Activate()
            
            missile:SetAttacker(ent)
            missile:SetOwner(ent)
            
            if missile.SetStartVelocity then
                missile:SetStartVelocity(FireDir * SUNSTRIKE_CONFIG.MissileSpeed)
            end
            if missile.SetDamage then
                missile:SetDamage(SUNSTRIKE_CONFIG.MissileDamage)
            end
            if missile.SetRadius then
                missile:SetRadius(SUNSTRIKE_CONFIG.MissileRadius)
            end
            if missile.SetForce then
                missile:SetForce(SUNSTRIKE_CONFIG.MissileForce)
            end
            if missile.SetThrust then
                missile:SetThrust(SUNSTRIKE_CONFIG.MissileThrust)
            end
            if missile.SetTurnSpeed then
                missile:SetTurnSpeed(SUNSTRIKE_CONFIG.MissileTurnSpeed)
            end
            
            FindHeatSeekingTarget(missile, FirePos, FireDir, SUNSTRIKE_CONFIG.TrackingCone, SUNSTRIKE_CONFIG.TrackingRange, false)
        end
    end
    
    if CLIENT then
        -- OPTIMIERT: Cache für Missile-Entities
        local MissileCache = {}
        local NextMissileUpdate = 0
        
        weapon.OnClientThink = function(ent)
            if not IsValid(ent) then return end
            
            local T = CurTime()
            
            -- OPTIMIERT: Update Missile-Cache nur alle 0.2 Sekunden
            if T >= NextMissileUpdate then
                NextMissileUpdate = T + 0.2
                MissileCache = {}
                
                for _, missile in pairs(ents.FindByClass("lvs_missile")) do
                    if not IsValid(missile) then continue end
                    if not missile._IsSunstrikeMissile then continue end
                    
                    local parent = missile:GetParent()
                    local attacker = missile:GetAttacker()
                    local owner = missile:GetOwner()
                    
                    local vehicle = ent.GetBase and ent:GetBase() or ent
                    
                    if parent == vehicle or attacker == vehicle or owner == vehicle then
                        table.insert(MissileCache, missile)
                    end
                end
            end
            
            -- Sound-Management
            local hasActiveMissiles = false
            
            for _, missileEnt in ipairs(MissileCache) do
                if IsValid(missileEnt) then
                    hasActiveMissiles = true
                    local target = missileEnt:GetNWTarget()
                    
                    if IsValid(target) then
                        if not ent._hasPlayedClientLockSound then
                            surface.PlaySound("lock.wav")
                            ent._hasPlayedClientLockSound = true
                        end
                    else
                        if (ent._nextClientSeekSound or 0) <= T then
                            surface.PlaySound("seek.wav")
                            ent._nextClientSeekSound = T + 0.5
                        end
                        ent._hasPlayedClientLockSound = false
                    end
                    break
                end
            end
            
            if not hasActiveMissiles then
                ent._hasPlayedClientLockSound = false
                ent._nextClientSeekSound = 0
            end
        end
        
        -- OPTIMIERT: HUD nur zeichnen wenn nötig
        local NextHUDUpdate = 0
        local CachedMissiles = {}
        
        weapon.OnClientDraw = function(ent)
            if not IsValid(ent) then return end
            
            local T = CurTime()
            local vehicle = ent.GetBase and ent:GetBase() or ent
            
            -- OPTIMIERT: Update nur alle 0.15 Sekunden
            if T >= NextHUDUpdate then
                NextHUDUpdate = T + 0.15
                CachedMissiles = {}
                
                for _, missileEnt in pairs(ents.FindByClass("lvs_missile")) do
                    if not IsValid(missileEnt) then continue end
                    
                    local parent = missileEnt:GetParent()
                    local attacker = missileEnt:GetAttacker()
                    local owner = missileEnt:GetOwner()
                    
                    if parent == vehicle or attacker == vehicle or owner == vehicle then
                        table.insert(CachedMissiles, missileEnt)
                    end
                end
            end
            
            -- OPTIMIERT: Zeichne nur wenn Missiles vorhanden
            if #CachedMissiles == 0 then return end
            
            for _, missile in ipairs(CachedMissiles) do
                local target = missile:GetNWTarget()
                if not IsValid(target) then continue end
                
                local targetPos = target:LocalToWorld(target:OBBCenter()):ToScreen()
                
                if not targetPos.visible then continue end
                
                local color_red = Color(255, 0, 0, 255)
                local font = "LVS_FONT"
                
                draw.DrawText("LOCKED", font, targetPos.x, targetPos.y - 30, color_red, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                draw.DrawText("LOCKED", font, targetPos.x, targetPos.y + 30, color_red, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                
                local radius = 40
                local segmentdist = 90
                local radius2 = radius + 1
                
                surface.SetDrawColor(255, 0, 0, 255)
                
                for ang = 0, 360, segmentdist do
                    local a = ang + (missile:EntIndex() * 1337 - T * 100)
                    local x1 = targetPos.x + math.cos(math.rad(a)) * radius
                    local y1 = targetPos.y - math.sin(math.rad(a)) * radius
                    local x2 = targetPos.x + math.cos(math.rad(a + segmentdist)) * radius
                    local y2 = targetPos.y - math.sin(math.rad(a + segmentdist)) * radius
                    
                    surface.DrawLine(x1, y1, x2, y2)
                    
                    local x1_2 = targetPos.x + math.cos(math.rad(a)) * radius2
                    local y1_2 = targetPos.y - math.sin(math.rad(a)) * radius2
                    local x2_2 = targetPos.x + math.cos(math.rad(a + segmentdist)) * radius2
                    local y2_2 = targetPos.y - math.sin(math.rad(a + segmentdist)) * radius2
                    
                    surface.DrawLine(x1_2, y1_2, x2_2, y2_2)
                end
            end
        end
    end
    
    weapon.OnSelect = function(ent)
        if IsValid(ent) then
            ent:EmitSound("physics/metal/weapon_impact_soft3.wav")
        end
    end
    
    weapon.OnDeselect = function(ent)
        if IsValid(ent._SunstrikeMissile) then
            ent._SunstrikeMissile:Remove()
            ent._SunstrikeMissile = nil
        end
    end
    
    weapon.OnOverheat = function(ent)
        if IsValid(ent) then
            ent:EmitSound("lvs/overheat.wav")
        end
    end
    
    return weapon
end

function AddSunstrikeWeaponToVehicle(vehicle, podID, firePosition)
    if not IsValid(vehicle) then return false end
    if not vehicle.LVS then return false end
    
    podID = podID or 1
    
    if not vehicle.WEAPONS then
        vehicle.WEAPONS = {}
    end
    
    if not vehicle.WEAPONS[podID] then
        vehicle.WEAPONS[podID] = {}
    end
    
    for i, weapon in ipairs(vehicle.WEAPONS[podID]) do
        if istable(weapon) and weapon._isSunstrike then
            return false
        end
    end
    
    local weapon = CreateSunstrikeWeapon(firePosition)
    
    if vehicle.AddWeapon then
        vehicle:AddWeapon(weapon, podID)
        print("[Sunstrike] Waffe hinzugefügt via AddWeapon zu: " .. tostring(vehicle))
    else
        table.insert(vehicle.WEAPONS[podID], weapon)
        print("[Sunstrike] Waffe hinzugefügt via table.insert zu: " .. tostring(vehicle))
    end
    
    return true
end

-- OPTIMIERT: Think-Hook nur wenn aktive Missiles existieren
if SERVER then
    -- OPTIMIERT: Cache für Sunstrike Missiles
    local ActiveMissiles = {}
    local NextMissileCheck = 0
    
    local function _cfgOk()
        return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
    end
    hook.Add("Think", "EGC_Sunstrike_MissileTracking", function()
        if not _cfgOk() then return end
        local T = CurTime()
        
        -- OPTIMIERT: Update Cache nur alle 0.3 Sekunden
        if T >= NextMissileCheck then
            NextMissileCheck = T + 0.3
            ActiveMissiles = {}
            
            for _, missile in pairs(ents.FindByClass("lvs_missile")) do
                if IsValid(missile) and missile._IsSunstrikeMissile then
                    if not (missile.IsDetonated and missile:IsDetonated()) then
                        table.insert(ActiveMissiles, missile)
                    end
                end
            end
        end
        
        -- OPTIMIERT: Wenn keine Missiles, überspringe
        if #ActiveMissiles == 0 then return end
        
        -- Sonnen-Position aktualisieren (wenn nötig)
        if SUNSTRIKE_CONFIG.EnableSunTarget and (T % 0.5 < 0.1) then
            local sunEnt = GetSunTargetEntity()
            -- Existenz prüfen reicht
        end
        
        -- OPTIMIERT: Nur aktive Missiles verarbeiten
        for i = #ActiveMissiles, 1, -1 do
            local missile = ActiveMissiles[i]
            
            if not IsValid(missile) then
                table.remove(ActiveMissiles, i)
                continue
            end
            
            local currentTarget = missile:GetNWTarget()
            local hasValidTarget = IsValid(currentTarget)
            
            if IsValid(currentTarget) and currentTarget._IsSun then
                local missilePos = missile:GetPos()
                local sunDir = GetSunDirection()
                local sunPos = missilePos + sunDir * SUNSTRIKE_CONFIG.SunDistance
                currentTarget:SetPos(sunPos)
            end
            
            if not hasValidTarget or (missile._TrackingCone and missile._TrackingRange) then
                local missilePos = missile:GetPos()
                local missileForward = missile:GetAngles():Forward()
                local cone = missile._TrackingCone or SUNSTRIKE_CONFIG.TrackingCone
                local range = missile._TrackingRange or SUNSTRIKE_CONFIG.TrackingRange
                
                local useFullCone = not hasValidTarget
                
                FindHeatSeekingTarget(missile, missilePos, missileForward, cone, range, useFullCone)
            end
        end
    end)
end

print("[EastGermanCrusader LVS Overhaul] Merr-Sonn AA-1 'Sunstrike' Waffe geladen - OPTIMIERT!")
print("[Sunstrike] Verwende: AddSunstrikeWeaponToVehicle(vehicle, podID, firePosition)")
print("[Sunstrike] Fire and Forget Modus aktiviert - Raketen suchen automatisch nach Zielen")
