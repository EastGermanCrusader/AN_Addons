AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- NETZWERK FÜR SOUND
if SERVER then
    util.AddNetworkString("CrusaderMineSound")
    util.AddNetworkString("CrusaderMineDefused")
else
    net.Receive("CrusaderMineSound", function()
        local pos = net.ReadVector()
        sound.Play("gbombs_5/explosions/light_bomb/mine_explosion.mp3", pos, 140, 100, 1)
    end)
    
    net.Receive("CrusaderMineDefused", function()
        local pos = net.ReadVector()
        sound.Play("buttons/button9.wav", pos, 75, 100, 1)
    end)
end

-- Waffe zum Entschärfen: defuser_bomb. Mit STRG langsam zur Mine, dann LMB.
local DEFUSER_WEAPONS = {
    ["defuser_bomb"] = true,
}
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

-- ========== Landmine-Defusal-Minigame (Kabel-Logik) ==========
local DEFUSAL_TIMER_NAME = "CrusaderDefusal_"

function ENT:GenerateWireConfiguration()
    if not LandmineDefusal or not LandmineDefusal.WireTypes then return end
    local wireCount = math.random(5, 7)
    self.Wires = {}
    for i = 1, wireCount do
        local wireType = table.Random(LandmineDefusal.WireTypes)
        table.insert(self.Wires, { id = i, name = wireType.name, color = wireType.color, position = i, isCut = false })
    end
    self:DetermineCase()
    if not self.ActiveCase then
        self:GenerateWireConfiguration()
    else
        self.CurrentStep = 1
        self.CutWires = {}
    end
end

function ENT:DetermineCase()
    if not LandmineDefusal or not LandmineDefusal.Cases then return end
    for _, case in ipairs(LandmineDefusal.Cases) do
        if case.check(self.Wires) then
            self.ActiveCase = case
            return
        end
    end
    self.ActiveCase = nil
end

function ENT:StartDefusalMinigame(ply)
    if CLIENT then return end
    if not _cfgOk() then return end
    if not self.Armed or not IsValid(ply) or not ply:IsPlayer() then return end
    if self:GetIsDefusing() then return end
    if not LandmineDefusal or not LandmineDefusal.Cases then self:Defuse(ply) return end
    self:SetIsDefusing(true)
    self:GenerateWireConfiguration()
    if not self.ActiveCase then self:SetIsDefusing(false) self:Defuse(ply) return end
    self:SetTimeRemaining(LandmineDefusal.DefusalTime or 90)
    net.Start("LandmineDefusal_OpenUI")
    net.WriteEntity(self)
    net.WriteTable(self.Wires)
    net.WriteString(self.ActiveCase.name)
    net.WriteString(self.ActiveCase.description)
    net.WriteTable(self.ActiveCase.sequence)
    net.Send(ply)
    local tid = DEFUSAL_TIMER_NAME .. self:EntIndex()
    timer.Create(tid, 1, 0, function()
        if not IsValid(self) then timer.Remove(tid) return end
        if not self:GetIsDefusing() then timer.Remove(tid) return end
        local r = self:GetTimeRemaining() - 1
        self:SetTimeRemaining(r)
        if r <= 0 then timer.Remove(tid) self:Explode() end
    end)
end

function ENT:CheckWireCut(wirePosition, ply)
    if not self.ActiveCase or not self.ActiveCase.sequence then self:Explode() return false end
    local wire = self.Wires[wirePosition]
    if not wire or wire.isCut then self:Explode() return false end
    local expectedWireName = self.ActiveCase.sequence[self.CurrentStep]
    if wire.name == expectedWireName then
        wire.isCut = true
        self.CutWires[wirePosition] = true
        self.CurrentStep = self.CurrentStep + 1
        if self.CurrentStep > #self.ActiveCase.sequence then
            timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())
            self:SetIsDefusing(false)
            self:Defuse(ply)
            return true, true
        end
        return true, false
    else
        self:Explode()
        return false, false
    end
end

-- Geschwindigkeits-Schwelle für "langsames Gehen" (Units pro Sekunde)
local SLOW_WALK_SPEED = 100

-- CONSTANTS FOR BETTER PERFORMANCE
local VECTOR_ZERO = Vector(0, 0, 0)
local COLLISION_GROUP_WORLD = COLLISION_GROUP_WORLD or 1
local DMG_BLAST = DMG_BLAST or 64

-- CACHE FOR FREQUENTLY USED VALUES
local VALID_CLASSES = {
    ["prop_physics"] = true,
    ["prop_physics_multiplayer"] = true
}

-- OPTIMIZED FUNCTION: Check if entity is a valid target
local function IsValidTarget(ent, pos, self)
    if ent == self then return false end
    if not IsValid(ent) then return false end
    
    local entPos = ent:GetPos()
    --if entPos.z < pos.z then return false end -- Springen Lel
    
    -- Check blacklist first (fastest rejection)
    if self:IsBlacklisted(ent) then return false end
    
    -- SPIELER PRÜFUNG MIT SCHLEICH-ERKENNUNG
    if ent:IsPlayer() then
        -- Prüfe ob Spieler schleicht (STRG/Ducken)
        if ent:KeyDown(IN_DUCK) then
            return false -- Spieler schleicht mit STRG - Mine nicht auslösen
        end
        
        -- Prüfe ob Spieler langsam geht (ALT/Walk oder sehr langsame Geschwindigkeit)
        if ent:KeyDown(IN_WALK) then
            return false -- Spieler geht langsam mit ALT - Mine nicht auslösen
        end
        
        -- Prüfe Geschwindigkeit - sehr langsame Spieler lösen Mine nicht aus
        local velocity = ent:GetVelocity():Length2D()
        if velocity < SLOW_WALK_SPEED and velocity > 0 then
            return false -- Spieler bewegt sich sehr langsam
        end
        
        -- Prüfe ob Spieler eine Defuser-Waffe hat
        local weapon = ent:GetActiveWeapon()
        if IsValid(weapon) and DEFUSER_WEAPONS[weapon:GetClass()] then
            return false -- Spieler hat Defuser-Waffe - Mine nicht auslösen
        end
        
        return true -- Normaler Spieler - Mine auslösen
    end
    
    if ent:IsNPC() then return true end
    if ent:IsVehicle() then return true end
    
    -- Check for specific class patterns
    local class = ent:GetClass()
    if class:find("lvs_", 1, true) then return true end
    if class:find("starwars", 1, true) then return true end
    
    -- Check physics props with mass
    if VALID_CLASSES[class] then
        local phys = ent:GetPhysicsObject()
        return IsValid(phys) and phys:GetMass() > 50
    end
    
    return false
end

-- AT-TE WALKER SPECIAL HANDLING (complete solution)
local function HandleATTEWalker(ent, damage, forceMultiplier, dir, pos, owner, self)
    local class = ent:GetClass()
    
    -- Nur AT-TE Walker behandeln
    if class ~= "lvs_walker_atte" and class ~= "lvs_walker_atte_rear" then
        return false
    end
    
    print("[CRUSADER MINE] AT-TE Walker detected: " .. class)
    
    -- 1. RAGDOLL TRIGGER FÜR AT-TE (statt Freeze)
    if SERVER then
        -- Prüfe ob die Ragdoll-Funktionen existieren
        if ent.BecomeRagdoll and isfunction(ent.BecomeRagdoll) then
            -- AT-TE in Ragdoll-Modus versetzen (aus sv_ragdoll.lua)
            print("[CRUSADER MINE] Triggering AT-TE ragdoll mode")
            ent:BecomeRagdoll()
            
            -- Kurze Verzögerung für bessere Übergänge
            timer.Simple(0.1, function()
                if IsValid(ent) then
                    -- Nudge für bessere Physik (aus sv_ragdoll.lua)
                    if ent.NudgeRagdoll and isfunction(ent.NudgeRagdoll) then
                        ent:NudgeRagdoll()
                    end
                    
                    -- Bewegung erzwingen (aus sv_ragdoll.lua)
                    if ent.ForceMotion and isfunction(ent.ForceMotion) then
                        ent:ForceMotion()
                    end
                end
            end)
        end
    end
    
    -- 2. PHYSIKALISCHE WIRKUNG (Druckwelle auf Walker)
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        -- Starke Kraft für schwere Walker
        local walkerForce = 15000 * forceMultiplier
        phys:ApplyForceCenter(dir * walkerForce)
        
        -- Zusätzlicher Drehmoment zum Umkippen
        if forceMultiplier > 0.7 then
            local torque = VectorRand() * walkerForce * 0.3
            phys:ApplyTorqueCenter(torque)
        end
    end
    
    -- 3. SCHADEN ANWENDEN (direkt auf Health-System)
    if SERVER then
        -- Versuche verschiedene Schadensmethoden
        local health = ent:Health() or 0
        local maxHealth = ent:GetMaxHealth() or 5000
        
        -- Methode 1: Direkter Health-Schaden
        if ent.Health and isfunction(ent.Health) then
            local newHealth = math.max(0, health - damage)
            ent:SetHealth(newHealth)
            
            print(string.format(
                "[CRUSADER MINE] AT-TE Health: %d -> %d (-%d)",
                health, newHealth, damage
            ))
            
            -- Bei niedrigem Health: Bein-Schaden-Simulation
            if newHealth < maxHealth * 0.3 and health >= maxHealth * 0.3 then
                print("[CRUSADER MINE] AT-TE critical damage! Legs damaged.")
                
                -- Funken-Effekt an Beinen
                for i = 1, 4 do
                    timer.Simple(i * 0.1, function()
                        if IsValid(ent) then
                            local legPos = ent:GetPos() + 
                                Vector(math.random(-150, 150), math.random(-150, 150), 50)
                            
                            local effectdata = EffectData()
                            effectdata:SetOrigin(legPos)
                            effectdata:SetNormal(Vector(0, 0, 1))
                            effectdata:SetMagnitude(3)
                            effectdata:SetScale(2)
                            util.Effect("ElectricSpark", effectdata)
                            
                            ent:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 90, 100)
                        end
                    end)
                end
            end
            
            -- Bei 0 Health: Walker deaktivieren
            if newHealth <= 0 then
                print("[CRUSADER MINE] AT-TE destroyed!")
                
                -- Walker in Ragdoll-Modus behalten statt zu deaktivieren
                -- Keine SetMoveType(MOVETYPE_NONE) - Walker bleibt in Ragdoll-Physik
            end
        end
        
        -- Methode 2: Standard TakeDamage versuchen
        if damage > 0 then
            local dmgInfo = DamageInfo()
            dmgInfo:SetDamage(damage)
            dmgInfo:SetAttacker(owner or self)
            dmgInfo:SetInflictor(self)
            dmgInfo:SetDamageType(DMG_BLAST)
            dmgInfo:SetDamageForce(dir * 50000)
            dmgInfo:SetDamagePosition(pos)
            
            ent:TakeDamageInfo(dmgInfo)
        end
        
        -- Methode 3: Fire-Input für LVS System
        if ent.Fire and isfunction(ent.Fire) then
            ent:Fire("SetHealth", tostring(math.max(0, (ent:Health() or 1000) - damage)))
        end
        
        -- 4. VISUELLE EFFEKTE
        -- Explosions-Effekt an Trefferpunkt
        local effectdata = EffectData()
        effectdata:SetOrigin(pos)
        effectdata:SetStart(ent:GetPos())
        effectdata:SetNormal(dir)
        effectdata:SetMagnitude(forceMultiplier * 5)
        effectdata:SetScale(forceMultiplier * 3)
        util.Effect("Explosion", effectdata)
        
        -- Großer Screen-Shake für nahe Spieler
        for _, ply in pairs(player.GetAll()) do
            if ply:GetPos():Distance(pos) < 2000 then
                util.ScreenShake(ply:GetPos(), 20 * forceMultiplier, 10, 2, 1000)
            end
        end
    end
    
    -- 5. SOUND-EFFEKTE
    if forceMultiplier > 0.5 then
        ent:EmitSound("ambient/explosions/explode_" .. math.random(1, 4) .. ".wav", 
            100, math.random(90, 110))
        ent:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 
            90, math.random(95, 105))
    end
    
    return true -- Walker wurde behandelt
end

-- SPEICHER FÜR SPIELER-GESCHWINDIGKEITEN (für Bewegungserkennung)
if not ENT.PlayerVelocities then
    ENT.PlayerVelocities = {}
end

-- OPTIMIZED: Proximity Check mit Bewegungserkennung

-- ============================================================================
-- OPTIMIERTE PROXIMITY CHECK FUNKTIONEN
-- ============================================================================

function ENT:AdaptiveProximityCheck()
    if SERVER and not _cfgOk() then return end
    if not self.Armed then return end
    
    local pos = self:GetPos()
    local entsInRadius = ents.FindInSphere(pos, self.ProximityRadius)
    
    -- OPTIMIERT: Frühes Return wenn keine Entities gefunden
    if #entsInRadius == 0 then
        self:UpdateCheckInterval(0)
        return
    end
    
    local playerCount = 0
    
    for i = 1, #entsInRadius do
        local ent = entsInRadius[i]
        
        if ent:IsPlayer() and IsValid(ent) then
            playerCount = playerCount + 1
            
            local entIndex = ent:EntIndex()
            local currentVel = ent:GetVelocity():Length2D()
            
            if not self.PlayerVelocities then
                self.PlayerVelocities = {}
            end
            if not self.PlayerVelocities[entIndex] then
                self.PlayerVelocities[entIndex] = currentVel
            end
            
            local isHoldingAlt = ent:KeyDown(IN_WALK)
            local isHoldingCtrl = ent:KeyDown(IN_DUCK)
            local isMoving = currentVel > SLOW_WALK_SPEED
            local isStandingStill = currentVel < 10
            
            self.PlayerVelocities[entIndex] = currentVel
            
            if isMoving and not isStandingStill and not isHoldingAlt and not isHoldingCtrl then
                local weapon = ent:GetActiveWeapon()
                if not IsValid(weapon) or not DEFUSER_WEAPONS[weapon:GetClass()] then
                    self:Explode()
                    return
                end
            end
        elseif IsValidTarget(ent, pos, self) then
            self:Explode()
            return
        end
    end
    
    self:UpdateCheckInterval(playerCount)
end

function ENT:UpdateCheckInterval(playerCount)
    self._nearbyPlayersCount = playerCount
    
    local newInterval
    if playerCount == 0 then
        newInterval = 0.5
    elseif playerCount == 1 then
        newInterval = 0.15
    else
        newInterval = 0.1
    end
    
    if newInterval ~= self._proximityCheckInterval then
        self._proximityCheckInterval = newInterval
        
        local timerName = "CrusaderMine_" .. self:EntIndex()
        timer.Remove(timerName)
        timer.Create(timerName, newInterval, 0, function()
            if IsValid(self) then
                self:AdaptiveProximityCheck()
            end
        end)
    end
end

function ENT:StartTouch(entity)
    if not IsValid(entity) then return end
    if not self.Armed then return end
    
    local pos = self:GetPos()
    
    if entity:IsPlayer() then
        local currentVel = entity:GetVelocity():Length2D()
        local isHoldingAlt = entity:KeyDown(IN_WALK)
        local isHoldingCtrl = entity:KeyDown(IN_DUCK)
        local isMoving = currentVel > SLOW_WALK_SPEED
        local isStandingStill = currentVel < 10
        
        if isMoving and not isStandingStill and not isHoldingAlt and not isHoldingCtrl then
            local weapon = entity:GetActiveWeapon()
            if not IsValid(weapon) or not DEFUSER_WEAPONS[weapon:GetClass()] then
                self:Explode()
                return
            end
        end
    elseif IsValidTarget(entity, pos, self) then
        self:Explode()
    end
end


-- OPTIMIZED: Blacklist check with caching
function ENT:IsBlacklisted(ent)
    -- FIX: Ensure VehicleBlacklist exists and is a table
    if not self.VehicleBlacklist or type(self.VehicleBlacklist) ~= "table" then
        self.VehicleBlacklist = {}
        return false
    end
    
    local class = ent:GetClass()
    local model = ent:GetModel()
    
    -- Fast path: no blacklist
    if #self.VehicleBlacklist == 0 then return false end
    
    for i = 1, #self.VehicleBlacklist do
        local blacklisted = self.VehicleBlacklist[i]
        if class == blacklisted or model == blacklisted then
            return true
        end
    end
    
    return false
end

-- OPTIMIZED: Create shockwave with better physics
function ENT:CreateRealShockwave()
    local pos = self:GetPos()
    local owner = self:GetOwner()
    
    -- FIX: Check if BlastRadius is set
    if not self.BlastRadius then
        self.BlastRadius = 800 -- Default value
    end
    
    local blastRadiusSquared = self.BlastRadius * self.BlastRadius
    
    -- Pre-calculate values for performance
    local entsInRadius = ents.FindInSphere(pos, self.BlastRadius)
    
    for i = 1, #entsInRadius do
        local ent = entsInRadius[i]
        if ent == self or not IsValid(ent) then continue end
        
        local entPos = ent:GetPos()
        local diff = entPos - pos
        local distSquared = diff:LengthSqr()
        
        -- Fast distance check using squared distance
        if distSquared > blastRadiusSquared then continue end
        
        local dist = math.sqrt(distSquared)
        
        -- FIX: Ensure all required properties exist
        local forceMultiplier = 1 - (dist / (self.BlastRadius or 800))
        forceMultiplier = math.Clamp(forceMultiplier, 0, 1)
        
        -- Quadratic falloff (more realistic)
        forceMultiplier = forceMultiplier * forceMultiplier
        
        -- FIX: Check for MinBlastForce and MaxBlastForce
        local minForce = self.MinBlastForce or 500
        local maxForce = self.MaxBlastForce or 15000
        local blastForce = Lerp(forceMultiplier, minForce, maxForce)
        
        local dir = diff:GetNormalized()
        
        -- FIX: Check for UpwardForce
        local upwardForce = self.UpwardForce or 0.3
        dir = (dir + Vector(0, 0, upwardForce)):GetNormalized()
        
        -- Apply physics force
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            local mass = phys:GetMass()
            local massAdjustedForce = blastForce * (1000 / math.max(mass, 1)) * 0.1
            
            phys:ApplyForceCenter(dir * massAdjustedForce)
            
            -- Random torque for rotation
            if math.random(1, 3) == 1 then
                phys:ApplyForceOffset(dir * massAdjustedForce * 0.5, entPos + VectorRand() * 10)
            end
        end
        
        -- Apply damage in inner radius
        -- FIX: Check for DamageRadius
        local damageRadius = self.DamageRadius or 2000 -- GEÄNDERT: von 200 auf 2000 (0 hinzugefügt)
        if dist <= damageRadius then
            -- FIX: Check for ExplosionDamage
            local explosionDamage = self.ExplosionDamage or 4000 -- GEÄNDERT: von 400 auf 4000
            local damage = explosionDamage * forceMultiplier
            
            -- SPEZIALBEHANDLUNG FÜR AT-TE WALKER (KORREKTUR HIER!)
            local class = ent:GetClass()
            if class == "lvs_walker_atte" or class == "lvs_walker_atte_rear" then
                -- AT-TE Walker mit kompletter Behandlung
                HandleATTEWalker(ent, damage, forceMultiplier, dir, pos, owner, self)
                continue -- Keine weitere Behandlung nötig
            end
            
            -- Regular damage for other entities (NICHT Walker)
            if ent:IsPlayer() or ent:IsNPC() then
                local dmg = DamageInfo()
                dmg:SetDamage(damage)
                dmg:SetAttacker(owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_BLAST)
                dmg:SetDamageForce(dir * blastForce * 100)
                dmg:SetDamagePosition(pos)
                
                ent:TakeDamageInfo(dmg)
                
                -- Screen shake for players
                if ent:IsPlayer() then
                    util.ScreenShake(entPos, 15 * forceMultiplier, 5, 1.5, damageRadius)
                end
            elseif VALID_CLASSES[ent:GetClass()] and damage > 500 and forceMultiplier > 0.7 then
                ent:Fire("Break", "", 0)
            end
        end
    end
    
    -- Secondary effects with timer optimization
    local function ApplyAirBlast()
        if not IsValid(self) then return end
        
        local airBlastRadius = (self.BlastRadius or 800) * 1.5
        local lightEnts = ents.FindInSphere(pos, airBlastRadius)
        local maxDistSquared = airBlastRadius * airBlastRadius
        
        for i = 1, #lightEnts do
            local ent = lightEnts[i]
            if not IsValid(ent) or not VALID_CLASSES[ent:GetClass()] then continue end
            
            local phys = ent:GetPhysicsObject()
            if not IsValid(phys) or phys:GetMass() > 50 then continue end
            
            local diff = ent:GetPos() - pos
            local distSquared = diff:LengthSqr()
            if distSquared > maxDistSquared then continue end
            
            local dist = math.sqrt(distSquared)
            local forceMultiplier = 1 - (dist / airBlastRadius)
            local airForce = 800 * forceMultiplier * forceMultiplier
            
            local airDir = diff:GetNormalized()
            airDir = (airDir + Vector(0, 0, 0.5)):GetNormalized()
            
            phys:ApplyForceCenter(airDir * airForce)
        end
    end
    
    -- Use single timer with function references instead of inline functions
    timer.Simple(0.05, ApplyAirBlast)
    
    timer.Simple(0.3, function()
        if not IsValid(self) then return end
        
        local afterShockRadius = (self.BlastRadius or 800) * 0.7
        local afterShockEnts = ents.FindInSphere(pos, afterShockRadius)
        
        for i = 1, #afterShockEnts do
            local ent = afterShockEnts[i]
            if not IsValid(ent) then continue end
            
            local phys = ent:GetPhysicsObject()
            if IsValid(phys) and phys:GetMass() < 500 then
                local dist = pos:Distance(ent:GetPos())
                local force = 1000 * (1 - (dist / afterShockRadius))
                phys:ApplyForceCenter(VectorRand() * force * 0.3)
            end
        end
    end)
    
    -- Debug visualization (server only)
    if SERVER and (GetConVar("crusader_debug") and GetConVar("crusader_debug"):GetBool()) then
        local debugSphere = ents.Create("prop_physics")
        if IsValid(debugSphere) then
            debugSphere:SetModel("models/hunter/blocks/cube05x05x05.mdl")
            debugSphere:SetPos(pos)
            debugSphere:SetColor(Color(255, 255, 255, 1))
            debugSphere:SetRenderMode(RENDERMODE_NONE)
            debugSphere:Spawn()
            debugSphere:SetModelScale(0.1, 0)
            
            -- Animated expansion
            for i = 1, 20 do
                timer.Simple(i * 0.05, function()
                    if IsValid(debugSphere) then
                        debugSphere:SetModelScale(i * 0.5, 0.1)
                    end
                end)
            end
            
            timer.Simple(1.0, function()
                if IsValid(debugSphere) then
                    debugSphere:Remove()
                end
            end)
        end
    end
end

-- OPTIMIZED: Particle effects
function ENT:PlayMainExplosionParticles()
    local pos = self:GetPos()
    
    if self:WaterLevel() >= 1 then
        ParticleEffect(self.EffectWater or "water_medium", pos, Angle(0, 0, 0), nil)
    else
        local trace = util.TraceLine({
            start = pos,
            endpos = pos - Vector(0, 0, self.TraceLength or 200),
            filter = self
        })
        
        local effect = trace.HitWorld and (self.Effect or "100lb_ground") or (self.EffectAir or "100lb_air")
        ParticleEffect(effect, pos, Angle(0, 0, 0), nil)
    end
end

-- OPTIMIZED: GB5 explosion entities
function ENT:CreateGB5ExplosionEntities()
    local pos = self:GetPos()
    local owner = self:GetOwner()
    
    -- Create shockwave entity
    local shockwave = ents.Create("gb5_shockwave_ent")
    if IsValid(shockwave) then
        shockwave:SetPos(pos)
        shockwave:Spawn()
        shockwave:Activate()
        shockwave:SetVar("GBOWNER", owner)
        shockwave:SetVar("DEFAULT_PHYSFORCE", self.BlastForce or 8000)
        shockwave:SetVar("MAX_RANGE", self.BlastRadius or 800)
        shockwave:SetVar("SHOCKWAVE_INCREMENT", 100)
        shockwave:SetVar("DELAY", 0.01)
    end
    
    -- Create sound wave entity
    local soundwave = ents.Create("gb5_shockwave_sound_lowsh")
    if IsValid(soundwave) then
        soundwave:SetPos(pos)
        soundwave:Spawn()
        soundwave:Activate()
        soundwave:SetVar("GBOWNER", owner)
        soundwave:SetVar("MAX_RANGE", 50000)
        soundwave:SetVar("SHOCKWAVE_INCREMENT", 200)
        soundwave:SetVar("DELAY", 0.01)
        soundwave:SetVar("SOUND", self.ExplosionSound or "gbombs_5/explosions/light_bomb/mine_explosion.mp3")
    end
    
    -- Create pellets with staggered timing
    for i = 1, 15 do
        timer.Simple(i * 0.02, function() -- Stagger creation for performance
            if not IsValid(self) then return end
            
            local pellet = ents.Create("gb5_light_peldumb")
            if IsValid(pellet) then
                pellet:SetPos(pos + VectorRand() * 20)
                pellet:Spawn()
                pellet:Activate()
                pellet:SetVar("GBOWNER", owner)
                
                local phys = pellet:GetPhysicsObject()
                if IsValid(phys) then
                    phys:ApplyForceCenter(VectorRand() * phys:GetMass() * 755)
                    pellet:Ignite(2, 0)
                end
                
                -- Auto-remove
                timer.Simple(4, function()
                    if IsValid(pellet) then
                        pellet:Remove()
                    end
                end)
            end
        end)
    end
end

-- OPTIMIZED: Main explosion function
function ENT:Explode()
    if SERVER and not _cfgOk() then return end
    if not self.Armed then return end
    local wasDefusing = self.GetIsDefusing and self:GetIsDefusing()
    self.Armed = false
    if self.SetIsDefusing then self:SetIsDefusing(false) end
    timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())
    if wasDefusing and SERVER then
        net.Start("LandmineDefusal_Result") net.WriteBool(false) net.Broadcast()
    end

    local timerName = "CrusaderMine_" .. self:EntIndex()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    
    local pos = self:GetPos()
    
    -- Play sounds
    if SERVER then
        self:EmitSound(self.ExplosionSound or "gbombs_5/explosions/light_bomb/mine_explosion.mp3", 140, 100)
        net.Start("CrusaderMineSound")
            net.WriteVector(pos)
        net.Broadcast()
    elseif CLIENT then
        sound.Play(self.ExplosionSound or "gbombs_5/explosions/light_bomb/mine_explosion.mp3", pos, 140, 100, 1)
    end
    
    -- Visual effects
    self:PlayMainExplosionParticles()
    
    -- Physics and damage (server only)
    if SERVER then
        self:CreateRealShockwave()
        
        -- Optional GB5 effects
        if (GetConVar("crusader_use_gb5_effects") and GetConVar("crusader_use_gb5_effects"):GetBool()) then
            self:CreateGB5ExplosionEntities()
        end
        
        -- Decal
        util.Decal("Scorch", pos, pos - Vector(0, 0, 100))
        
        -- Screen shake for nearby players
        local players = player.GetAll()
        local maxShakeDist = (self.BlastRadius or 800) * 2
        local maxShakeDistSquared = maxShakeDist * maxShakeDist
        
        for i = 1, #players do
            local ply = players[i]
            local distSquared = pos:DistToSqr(ply:GetPos())
            
            if distSquared < maxShakeDistSquared then
                local dist = math.sqrt(distSquared)
                local shake = 25 * (1 - (dist / maxShakeDist))
                util.ScreenShake(ply:GetPos(), math.Clamp(shake, 5, 25), 10, 2, self.BlastRadius or 800)
            end
        end
    end
    
    -- Remove entity
    SafeRemoveEntityDelayed(self, 0.1)
end

-- INITIALIZE FUNCTION
function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube05x05x05.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    -- GEÄNDERT: COLLISION_GROUP_NONE damit Schüsse die Mine treffen können
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end
    
    -- Make invisible
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetRenderMode(RENDERMODE_NONE)
    
    -- Aktiviere Schaden von Bullets/Explosionen
    self:SetHealth(1)
    
    -- Aktiviere USE-Funktion für Entschärfung
    self:SetUseType(SIMPLE_USE)
    
    -- Mine state
    self.Armed = true
    self.DefuseProgress = 0 -- Für späteren Entschärfungs-Fortschritt
    
    -- SHOCKWAVE SETTINGS (with default values)
    self.ExplosionDamage = self.ExplosionDamage or 4000           -- GEÄNDERT: von 400 auf 4000
    self.BlastRadius = self.BlastRadius or 800                    -- Physical effect radius
    self.ProximityRadius = self.ProximityRadius or 200            -- Detection radius
    self.BlastForce = self.BlastForce or 8000                     -- Base physical force
    self.MaxBlastForce = self.MaxBlastForce or 15000              -- Maximum force at epicenter
    self.MinBlastForce = self.MinBlastForce or 500                -- Minimum force at edge
    self.UpwardForce = self.UpwardForce or 0.3                    -- 30% upward force
    self.DamageRadius = self.DamageRadius or 2000                 -- GEÄNDERT: von 200 auf 2000 (0 hinzugefügt)
    
    -- GB5 effects (with default values)
    self.ExplosionSound = self.ExplosionSound or "gbombs_5/explosions/light_bomb/mine_explosion.mp3"
    self.Effect = self.Effect or "100lb_ground"
    self.EffectAir = self.EffectAir or "100lb_air"
    self.EffectWater = self.EffectWater or "water_medium"
    self.TraceLength = self.TraceLength or 200
    
    -- Initialize blacklist as empty table
    self.VehicleBlacklist = self.VehicleBlacklist or {}
    
    -- OPTIMIERT: Adaptive Timer-Strategie
    self._proximityCheckInterval = 0.5  -- Start mit 0.5s (niedrige CPU-Last)
    self._lastPlayerDetection = 0
    self._nearbyPlayersCount = 0
    
    -- Start proximity check timer (OPTIMIERT: 0.5s statt 0.1s)
    local timerName = "CrusaderMine_" .. self:EntIndex()
    timer.Create(timerName, self._proximityCheckInterval, 0, function()
        if IsValid(self) then
            self:AdaptiveProximityCheck()  -- GEÄNDERT: Adaptive Funktion
        end
    end)
end

function ENT:OnTakeDamage(dmg)
    -- Detoniere bei jedem Schaden > 0 (Schüsse, Explosionen, etc.)
    if dmg:GetDamage() > 0 and self.Armed then
        self:Explode()
    end
end

-- Zusätzliche Funktion für Bullet-Treffer (für bessere Kompatibilität)
function ENT:PhysicsCollide(data, phys)
    -- Detoniere bei Kollision mit schnellen Objekten (z.B. Bullets)
    if data.Speed > 500 and self.Armed then
        self:Explode()
    end
end

function ENT:OnRemove()
    timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())
    local timerName = "CrusaderMine_" .. self:EntIndex()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    
    -- Aufräumen: Geschwindigkeits-Tracking-Daten löschen
    if self.PlayerVelocities then
        self.PlayerVelocities = nil
    end
end

-- Entschärfen mit Rechtsklick, Linksklick oder E (mit defuser_bomb + STRG/langsam)
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not self.Armed then return end
    local weapon = activator:GetActiveWeapon()
    if not IsValid(weapon) or not DEFUSER_WEAPONS[weapon:GetClass()] then return end
    if activator:KeyDown(IN_DUCK) or activator:KeyDown(IN_WALK) then
        self:StartDefusalMinigame(activator)
    else
        activator:ChatPrint("[Mine] STRG gedrückt halten und langsam bewegen, dann Rechtsklick/Linksklick oder E.")
    end
end

-- ENTSCHÄRFUNGS-LOGIK
function ENT:Defuse(defuser)
    if not self.Armed then return end
    self.Armed = false
    if self.SetIsDefusing then self:SetIsDefusing(false) end
    timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())

    local pos = self:GetPos()

    -- Timer stoppen
    local timerName = "CrusaderMine_" .. self:EntIndex()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    
    -- Sound abspielen (Button-Sound)
    self:EmitSound("buttons/button9.wav", 75, 100)
    
    -- Dampf-Sound abspielen
    self:EmitSound("ambient/steam/steam_short" .. math.random(1, 2) .. ".wav", 75, 100)
    
    -- Netzwerk-Nachricht für Sound (nur für andere Spieler, nicht für den Defuser)
    if SERVER then
        net.Start("CrusaderMineDefused")
            net.WriteVector(pos)
        net.Broadcast()
    end
    
    -- Visueller Effekt (kleine Funken)
    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetNormal(Vector(0, 0, 1))
    effectdata:SetMagnitude(1)
    effectdata:SetScale(1)
    util.Effect("ElectricSpark", effectdata)
    
    -- Dampf-Effekt
    local steamEffect = EffectData()
    steamEffect:SetOrigin(pos)
    steamEffect:SetNormal(Vector(0, 0, 1))
    steamEffect:SetMagnitude(2)
    steamEffect:SetScale(1.5)
    util.Effect("SteamJet", steamEffect)
    
    -- Nachricht NUR an den entschärfenden Spieler (ChatPrint sendet nur an einen Spieler)
    if IsValid(defuser) and defuser:IsPlayer() then
        defuser:ChatPrint("[Mine] Mine erfolgreich entschärft!")
        
        -- Optional: Punkte oder Benachrichtigung
        print("[CRUSADER MINE] Mine entschärft von: " .. defuser:Nick())
    end
    
    -- Mine nach kurzer Verzögerung entfernen (oder als Prop belassen)
    timer.Simple(0.5, function()
        if IsValid(self) then
            -- Option 1: Mine komplett entfernen
            self:Remove()
            
            -- Option 2: Mine als harmloses Prop belassen (auskommentiert)
            -- self:SetNoDraw(false)
            -- self:SetRenderMode(RENDERMODE_NORMAL)
            -- self:SetColor(Color(100, 100, 100, 255))
        end
    end)
end

-- ADDITIONAL OPTIMIZATION: Add a Think function for cleanup
function ENT:Think()
    -- Optional: Add periodic cleanup or state checks here
    self:NextThink(CurTime() + 1) -- Run every second
    return true
end