-- EastGermanCrusader SAM System - VLS Torpedo
-- Große wärmegelenkte Rakete mit blauem Antrieb

AddCSLuaFile()

ENT.Base = "lvs_missile"

ENT.Type = "anim"

ENT.PrintName = "SAM Torpedo"
ENT.Author = "EastGermanCrusader"
ENT.Information = "VLS Surface-to-Air Torpedo - Wärmegelenkt"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminOnly = false

-- Effekte (JDAM Style)
ENT.ExplosionEffect = "h_shockwave"
ENT.ExplosionEffectAir = "h_shockwave_airburst"
ENT.ExplosionEffectWater = "h_water_huge"
ENT.GlowColor = Color(50, 150, 255, 255) -- Blaues Leuchten

-- JDAM Explosions-Sounds
local ExploSnds = {
    "gbombs_5/explosions/heavy_bomb/explosion_big_6.mp3",
    "gbombs_5/explosions/heavy_bomb/explosion_big_7.mp3"
}

-- Netzwerk für Sound-Übertragung
if SERVER then
    util.AddNetworkString("SAM_TorpedoExplosion")
end

-- Client empfängt und spielt Sound ab
if CLIENT then
    net.Receive("SAM_TorpedoExplosion", function()
        local pos = net.ReadVector()
        local sndIndex = net.ReadUInt(8)
        local snd = ExploSnds[sndIndex] or ExploSnds[1]
        
        -- JDAM Explosions-Sound an Position abspielen
        sound.Play(snd, pos, 140, 100, 1)
    end)
end

-- Torpedo Einstellungen - BALLISTISCHE FLUGBAHN
ENT.BoostTime = 2.0            -- Sekunden vertikal nach oben
ENT.ArcTime = 2.0              -- Sekunden für Bogen zum Ziel
ENT.FlightSpeed = 2500         -- Fluggeschwindigkeit

-- SAM Torpedo Schaden
ENT.ExplosionDamage = 10000      -- 10000 HP Schaden
ENT.ExplosionRadius = 800        -- Reduzierter Radius
ENT.PhysicsForce = 15000         -- Moderate Druckwelle

if SERVER then
    function ENT:GetDamage()
        return (self._dmg or self.ExplosionDamage)
    end
    
    function ENT:GetRadius()
        return (self._radius or self.ExplosionRadius)
    end
    
    function ENT:GetForce()
        return (self._force or self.PhysicsForce)
    end
    
    function ENT:Initialize()
        -- Größeres Modell (Propan-Kanister Größe)
        self:SetModel("models/props_junk/PropaneCanister001a.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        
        -- Skalierung für Raketen-Look
        self:SetModelScale(1.2, 0)
        
        -- VLS Variablen
        self._vlsLaunched = false
        self._vlsLaunchTime = 0
        
        -- Flugphasen: "boost" -> "climb" -> "cruise"
        self._vlsPhase = "boost"
        
        -- Gespeicherte Launch-Richtung (wird bei Enable gesetzt)
        self._launchDirection = nil
    end
    
    -- Externe Funktion zum Setzen der Launch-Richtung
    function ENT:SetLaunchDirection(dir)
        self._launchDirection = dir
    end
    
    function ENT:Enable()
        if self.IsEnabled then return end
        
        local Parent = self:GetParent()
        
        if IsValid(Parent) then
            self:SetOwner(Parent)
            self:SetParent(NULL)
        end
        
        -- Einfache Physik ohne MotionController
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
        
        self.IsEnabled = true
        
        local pObj = self:GetPhysicsObject()
        
        if not IsValid(pObj) then
            self:Remove()
            print("[SAM Torpedo] Fehler: Physik konnte nicht initialisiert werden")
            return
        end
        
        pObj:SetMass(50)
        pObj:EnableGravity(false)
        pObj:EnableMotion(true)
        pObj:EnableDrag(false)
        
        self:SetTrigger(true)
        
        -- Zeiten
        self.SpawnTime = CurTime()
        self.LaunchTime = CurTime()
        
        -- Phase: "boost", "arc", "terminal"
        self.Phase = "boost"
        
        -- Speichere Startposition
        self.StartPos = self:GetPos()
        
        -- Speichere Ziel
        local Target = self:GetTarget()
        if IsValid(Target) then
            self.TargetPos = Target:GetPos()
            self.TargetEntity = Target
        else
            self.TargetPos = self:GetPos() + Vector(3000, 0, 0)
        end
        
        -- Initiale Richtung: Basierend auf VLS-Modell Ausrichtung
        -- Verwende die Launch-Richtung vom VLS (falls gesetzt), sonst nach oben
        if self._launchDirection and isvector(self._launchDirection) and self._launchDirection:Length() > 0 then
            self.FlightDir = self._launchDirection:GetNormalized()
            self.LaunchDir = self._launchDirection:GetNormalized()  -- Speichern für Arc-Phase
            print("[SAM Torpedo] Launch-Richtung vom VLS: " .. tostring(self.FlightDir))
        else
            -- Fallback: Verwende die aktuelle Modell-Ausrichtung (Up-Vektor)
            self.FlightDir = self:GetUp()
            self.LaunchDir = self:GetUp()
            print("[SAM Torpedo] Verwende Entity-Up als Launch-Richtung: " .. tostring(self.FlightDir))
        end
        self:SetAngles(self.FlightDir:Angle())
        
        -- Starte Bewegung in Launch-Richtung
        pObj:SetVelocity(self.FlightDir * self.FlightSpeed)
        
        self:SetActive(true)
        
        -- Launch Sound
        self:EmitSound("ambient/explosions/explode_1.wav", 100, 130)
    end
    
    -- ============================================
    -- ABORT FUNKTION - Rakete selbstzerstören
    -- ============================================
    function ENT:Abort()
        if not self.IsEnabled or self.IsDetonated or self.IsAborted then return end
        
        self.IsAborted = true
        
        local Pos = self:GetPos()
        
        -- Kleinere Abort-Explosion (nicht voller Schaden)
        local effectdata = EffectData()
        effectdata:SetOrigin(Pos)
        effectdata:SetScale(2)
        util.Effect("Explosion", effectdata)
        
        -- Sound
        self:EmitSound("ambient/explosions/explode_4.wav", 100, 120)
        
        -- Screen Shake (kleiner)
        util.ScreenShake(Pos, 10, 5, 1, 1000)
        
        print("[SAM Torpedo] ABGEBROCHEN!")
        
        -- Entfernen
        SafeRemoveEntityDelayed(self, 0.1)
    end
    
    function ENT:Think()
        local T = CurTime()
        self:NextThink(T + 0.02)  -- 50 FPS Updates
        
        if not self.SpawnTime then return true end
        
        local Pos = self:GetPos()
        local pObj = self:GetPhysicsObject()
        if not IsValid(pObj) then return true end
        
        local timeSinceLaunch = T - self.LaunchTime
        
        -- Update Zielposition wenn Ziel sich bewegt
        if IsValid(self.TargetEntity) then
            self.TargetPos = self.TargetEntity:GetPos()
        end
        
        -- ==========================================
        -- PHASE 1: BOOST - In Launch-Richtung (2 Sekunden)
        -- ==========================================
        if self.Phase == "boost" then
            -- Halte Richtung basierend auf VLS-Modell Ausrichtung
            self.FlightDir = self.LaunchDir or Vector(0, 0, 1)
            
            if timeSinceLaunch >= self.BoostTime then
                self.Phase = "arc"
                self.ArcStartTime = T
                self:EmitSound("weapons/rpg/rocketfire1.wav", 110, 90)
            end
        end
        
        -- ==========================================
        -- PHASE 2: ARC - Sanfter Bogen zum Ziel (2 Sekunden)
        -- ==========================================
        if self.Phase == "arc" then
            local arcProgress = (T - self.ArcStartTime) / self.ArcTime
            arcProgress = math.Clamp(arcProgress, 0, 1)
            
            -- Interpoliere von Launch-Richtung zu Richtung Ziel
            local launchDir = self.LaunchDir or Vector(0, 0, 1)
            local toTarget = (self.TargetPos - Pos):GetNormalized()
            
            -- Smooth interpolation
            self.FlightDir = LerpVector(arcProgress, launchDir, toTarget)
            self.FlightDir:Normalize()
            
            if arcProgress >= 1 then
                self.Phase = "terminal"
            end
        end
        
        -- ==========================================
        -- PHASE 3: TERMINAL - Gerade zum Ziel
        -- ==========================================
        if self.Phase == "terminal" then
            -- Direkt auf Ziel zeigen
            self.FlightDir = (self.TargetPos - Pos):GetNormalized()
            
            local Distance = Pos:Distance(self.TargetPos)
            
            -- Näherungszündung
            if Distance < 250 then
                self:Detonate(self.TargetEntity)
                return true
            end
        end
        
        -- World-Kollisionsvermeidung: Prüfe vorausschauend auf World-Kollision
        local worldEntity = game.GetWorld()
        local lookAheadDist = 300  -- Prüfe 300 Einheiten voraus
        local avoidanceTrace = util.TraceLine({
            start = Pos,
            endpos = Pos + self.FlightDir * lookAheadDist,
            filter = function(ent)
                -- Ignoriere den Torpedo selbst und die World
                return ent ~= self and ent ~= worldEntity
            end
        })
        
        -- Wenn World-Kollision erkannt, korrigiere Flugrichtung nach oben/außen
        if avoidanceTrace.Hit and (avoidanceTrace.Entity == worldEntity or avoidanceTrace.HitWorld) then
            -- Berechne Ausweichrichtung: Kombination aus nach oben und seitlich
            local upDir = Vector(0, 0, 1)
            local rightDir = self.FlightDir:Cross(upDir):GetNormalized()
            if rightDir:Length() < 0.1 then
                rightDir = self.FlightDir:Cross(Vector(0, 1, 0)):GetNormalized()
            end
            
            -- Neue Richtung: 60% nach oben, 40% seitlich
            local avoidanceDir = (upDir * 0.6 + rightDir * 0.4):GetNormalized()
            
            -- Sanfte Korrektur der Flugrichtung
            self.FlightDir = LerpVector(0.15, self.FlightDir, avoidanceDir)
            self.FlightDir:Normalize()
        end
        
        -- Setze Velocity und Rotation
        pObj:SetVelocity(self.FlightDir * self.FlightSpeed)
        self:SetAngles(self.FlightDir:Angle())
        
        -- Kollision prüfen (ignoriere World)
        local trace = util.TraceLine({
            start = Pos,
            endpos = Pos + self.FlightDir * 150,
            filter = function(ent)
                -- Ignoriere den Torpedo selbst und die World
                return ent ~= self and ent ~= worldEntity
            end
        })
        if trace.Hit and trace.Entity ~= worldEntity and not trace.HitWorld then
            self:Detonate(self.TargetEntity)
            return true
        end
        
        -- Lebensdauer: 20 Sekunden
        if (self.SpawnTime + 20) < T then
            self:Detonate()
        end
        
        return true
    end
    
    -- PhysicsSimulate wird nicht verwendet - Steuerung erfolgt direkt in Think()
    function ENT:PhysicsSimulate(phys, deltatime)
        -- Nichts tun - wir steuern über SetVelocity in Think()
        return Vector(0,0,0), Vector(0,0,0), SIM_NOTHING
    end
    
    function ENT:Detonate(target)
        if not self.IsEnabled or self.IsDetonated then return end
        
        self.IsDetonated = true
        
        local Pos = self:GetPos()
        local attacker = self:GetAttacker()
        if not IsValid(attacker) then attacker = game.GetWorld() end
        
        -- ==========================================
        -- SAM Torpedo Explosion - 10000 HP Schaden
        -- ==========================================
        
        -- Haupt-Partikeleffekt (Shockwave)
        local tracedata = {}
        tracedata.start = Pos
        tracedata.endpos = Pos - Vector(0, 0, 400)
        tracedata.filter = self
        local trace = util.TraceLine(tracedata)
        
        if self:WaterLevel() >= 1 then
            -- Wasser-Explosion
            local trdata = {}
            trdata.start = Pos
            trdata.endpos = Pos + Vector(0, 0, 9000)
            trdata.filter = self
            local tr = util.TraceLine(trdata)
            
            local trdat2 = {}
            trdat2.start = tr.HitPos
            trdat2.endpos = Pos - Vector(0, 0, 9000)
            trdat2.filter = self
            trdat2.mask = MASK_WATER + CONTENTS_TRANSLUCENT
            local tr2 = util.TraceLine(trdat2)
            
            if tr2.Hit then
                ParticleEffect(self.ExplosionEffectWater, tr2.HitPos, Angle(0,0,0), nil)
            end
        elseif trace.HitWorld then
            ParticleEffect(self.ExplosionEffect, Pos, Angle(0,0,0), nil)
        else
            ParticleEffect(self.ExplosionEffectAir, Pos, Angle(0,0,0), nil)
        end
        
        -- Explosions-Effekte
        for i = 1, 3 do
            timer.Simple(i * 0.03, function()
                local offset = VectorRand() * 150
                local effectPos = Pos + offset
                
                local eff = EffectData()
                eff:SetOrigin(effectPos)
                eff:SetScale(3)
                util.Effect("cball_explode", eff)
            end)
        end
        
        -- Speichere Werte lokal
        local damage = self:GetDamage()
        local radius = self:GetRadius()
        local force = self:GetForce()
        
        -- ==========================================
        -- SCHILD-SCHADEN: 2500 Punkte vor dem Hauptschaden
        -- ==========================================
        local shieldDamage = 2500
        
        for _, ent in pairs(ents.FindInSphere(Pos, radius)) do
            if IsValid(ent) then
                -- Prüfe ob es ein LVS Fahrzeug mit Schild ist
                if ent.GetShield and ent.SetShield then
                    local currentShield = ent:GetShield() or 0
                    if currentShield > 0 then
                        local newShield = math.max(0, currentShield - shieldDamage)
                        ent:SetShield(newShield)
                        
                        -- Debug-Ausgabe
                        if EGC_SAM and EGC_SAM.Config and EGC_SAM.Config.Debug then
                            print("[SAM Torpedo] Schild-Schaden: " .. shieldDamage .. " -> " .. currentShield .. " zu " .. newShield)
                        end
                    end
                end
            end
        end
        
        -- HAUPT-SCHADEN (LVS System) - 10000 HP
        LVS:BlastDamage(Pos, self:GetForward(), attacker, self, damage, DMG_BLAST, radius, force)
        
        -- JDAM Explosions-Sound über Netzwerk
        local sndIndex = math.random(1, #ExploSnds)
        net.Start("SAM_TorpedoExplosion")
            net.WriteVector(Pos)
            net.WriteUInt(sndIndex, 8)
        net.Broadcast()
        
        -- Screen Shake für alle Spieler
        local shakeIntensity = 30
        local shakeRadius = 3000
        
        util.ScreenShake(Pos, shakeIntensity, 20, 5, shakeRadius)
        
        -- Leichtes Nachbeben
        timer.Simple(0.2, function()
            util.ScreenShake(Pos, shakeIntensity * 0.5, 10, 1, shakeRadius * 0.6)
        end)
        
        SafeRemoveEntityDelayed(self, FrameTime())
    end
    
    return
end

-- ============================================
-- CLIENT
-- ============================================

ENT.GlowMat = Material("sprites/light_glow02_add")
ENT.TrailMat = Material("trails/smoke")

function ENT:Initialize()
    self._lastParticle = 0
end

function ENT:Enable()
    if self.IsEnabled then return end
    
    self.IsEnabled = true
    self._enableTime = CurTime()
    
    -- Raketen-Sound
    self.snd = CreateSound(self, "npc/combine_gunship/gunship_crashing1.wav")
    self.snd:SetSoundLevel(90)
    self.snd:Play()
    
    -- Trail Effekt
    local effectdata = EffectData()
    effectdata:SetOrigin(self:GetPos())
    effectdata:SetEntity(self)
    util.Effect("lvs_proton_trail", effectdata)
end

function ENT:Think()
    if self.snd then
        -- Doppler-Effekt
        local pitch = 100 * self:CalcDoppler()
        
        -- Pitch erhöhen nach Pop-up Phase (1 Sekunde)
        if self._enableTime and (CurTime() - self._enableTime) > 1.0 then
            pitch = pitch * 1.3
        end
        
        self.snd:ChangePitch(math.Clamp(pitch, 50, 200))
    end
    
    if self.IsEnabled then return end
    
    if self:GetActive() then
        self:Enable()
    end
end

function ENT:CalcDoppler()
    local Ent = LocalPlayer()
    local ViewEnt = Ent:GetViewEntity()
    
    if Ent:lvsGetVehicle() == self then
        if ViewEnt == Ent then
            Ent = self
        else
            Ent = ViewEnt
        end
    else
        Ent = ViewEnt
    end
    
    local sVel = self:GetVelocity()
    local oVel = Ent:GetVelocity()
    
    local SubVel = oVel - sVel
    local SubPos = self:GetPos() - Ent:GetPos()
    
    local DirPos = SubPos:GetNormalized()
    local DirVel = SubVel:GetNormalized()
    
    local A = math.acos(math.Clamp(DirVel:Dot(DirPos), -1, 1))
    
    return (1 + math.cos(A) * SubVel:Length() / 13503.9)
end

function ENT:Draw()
    if not self:GetActive() then return end
    
    self:DrawModel()
    
    local pos = self:GetPos()
    local dir = self:GetForward()
    
    -- Blaues Glühen am Antrieb
    render.SetMaterial(self.GlowMat)
    
    -- DAUERHAFT konstante hohe Helligkeit
    local glowIntensity = 3.5 + math.sin(CurTime() * 10) * 0.5
    
    -- GROSSE blaue Antriebsflamme (dauerhaft)
    for i = 0, 60 do
        local Size = ((60 - i) / 60) ^ 1.5 * 350 * glowIntensity
        local alpha = ((60 - i) / 60) * 255
        
        render.DrawSprite(pos - dir * i * 8, Size, Size, Color(50, 150, 255, alpha))
    end
    
    -- Innerer heller Kern (weiß-blau) - dauerhaft hell
    local coreSize = 180 * glowIntensity
    render.DrawSprite(pos - dir * 5, coreSize, coreSize, Color(200, 230, 255, 255))
    render.DrawSprite(pos - dir * 15, coreSize * 0.8, coreSize * 0.8, Color(100, 180, 255, 255))
    render.DrawSprite(pos - dir * 30, coreSize * 0.5, coreSize * 0.5, Color(50, 150, 255, 200))
    
    -- Äußerer Glow-Ring
    local outerSize = 250 * glowIntensity
    render.DrawSprite(pos - dir * 20, outerSize, outerSize, Color(30, 100, 255, 120))
    
    -- DAUERHAFT helles blaues Licht
    local dlight = DynamicLight(self:EntIndex())
    if dlight then
        dlight.pos = pos - dir * 30
        dlight.r = 80
        dlight.g = 150
        dlight.b = 255
        dlight.brightness = 6
        dlight.decay = 1000
        dlight.size = 500
        dlight.dietime = CurTime() + 0.1
    end
    
    -- Zweites Licht für mehr Helligkeit
    local dlight2 = DynamicLight(self:EntIndex() + 10000)
    if dlight2 then
        dlight2.pos = pos
        dlight2.r = 100
        dlight2.g = 180
        dlight2.b = 255
        dlight2.brightness = 4
        dlight2.decay = 1000
        dlight2.size = 350
        dlight2.dietime = CurTime() + 0.1
    end
end

function ENT:DrawTranslucent()
    -- Blaue leuchtende Spur
    if not self:GetActive() then return end
    if not self._enableTime then return end
    
    local T = CurTime()
    if T - (self._lastParticle or 0) < 0.015 then return end
    self._lastParticle = T
    
    local pos = self:GetPos()
    local dir = self:GetForward()
    
    local emitter = ParticleEmitter(pos)
    if emitter then
        -- Blauer leuchtender Rauch (Hauptspur)
        local smoke = emitter:Add("sprites/light_glow02_add", pos - dir * 35)
        if smoke then
            smoke:SetVelocity(-dir * 200 + VectorRand() * 30)
            smoke:SetLifeTime(0)
            smoke:SetDieTime(1.2)
            smoke:SetStartAlpha(80) -- Leicht leuchtend
            smoke:SetEndAlpha(0)
            smoke:SetStartSize(40)
            smoke:SetEndSize(120)
            smoke:SetRoll(math.Rand(0, 360))
            smoke:SetRollDelta(math.Rand(-1, 1))
            smoke:SetColor(50, 120, 255) -- Blau
            smoke:SetGravity(Vector(0, 0, 30))
            smoke:SetAirResistance(50)
        end
        
        -- Zweite blaue Schicht (subtiler)
        local smoke2 = emitter:Add("particle/particle_smokegrenade", pos - dir * 40)
        if smoke2 then
            smoke2:SetVelocity(-dir * 150 + VectorRand() * 40)
            smoke2:SetLifeTime(0)
            smoke2:SetDieTime(2.0)
            smoke2:SetStartAlpha(60)
            smoke2:SetEndAlpha(0)
            smoke2:SetStartSize(30)
            smoke2:SetEndSize(100)
            smoke2:SetRoll(math.Rand(0, 360))
            smoke2:SetRollDelta(math.Rand(-1, 1))
            smoke2:SetColor(80, 140, 200) -- Hellblau
            smoke2:SetGravity(Vector(0, 0, 50))
            smoke2:SetAirResistance(80)
        end
        
        -- Blaue leuchtende Partikel (Funken)
        for j = 1, 4 do
            local spark = emitter:Add("sprites/light_glow02_add", pos - dir * 30 + VectorRand() * 15)
            if spark then
                spark:SetVelocity(-dir * 400 + VectorRand() * 80)
                spark:SetLifeTime(0)
                spark:SetDieTime(0.5)
                spark:SetStartAlpha(200)
                spark:SetEndAlpha(0)
                spark:SetStartSize(20)
                spark:SetEndSize(8)
                spark:SetColor(100, 180, 255) -- Hellblau
                spark:SetGravity(Vector(0, 0, -20))
            end
        end
        
        -- Kleine leuchtende Punkte in der Spur
        local glow = emitter:Add("sprites/light_glow02_add", pos - dir * 50 + VectorRand() * 20)
        if glow then
            glow:SetVelocity(-dir * 100 + VectorRand() * 20)
            glow:SetLifeTime(0)
            glow:SetDieTime(0.8)
            glow:SetStartAlpha(120)
            glow:SetEndAlpha(0)
            glow:SetStartSize(25)
            glow:SetEndSize(5)
            glow:SetColor(150, 200, 255) -- Weiß-blau
            glow:SetGravity(Vector(0, 0, 0))
        end
        
        emitter:Finish()
    end
end

function ENT:SoundStop()
    if self.snd then
        self.snd:Stop()
    end
end

function ENT:OnRemove()
    self:SoundStop()
end
