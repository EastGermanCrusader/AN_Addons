AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Waffe zum Entschärfen: defuser_bomb. Mit STRG langsam zur Mine, dann LMB.
local DEFUSER_WEAPONS = {
    ["defuser_bomb"] = true,
}
local DEFUSAL_TIMER_NAME = "CrusaderDefusal_"
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

function ENT:GenerateWireConfiguration()
    if not LandmineDefusal or not LandmineDefusal.WireTypes then return end
    local wireCount = math.random(5, 7)
    self.Wires = {}
    for i = 1, wireCount do
        local wireType = table.Random(LandmineDefusal.WireTypes)
        table.insert(self.Wires, { id = i, name = wireType.name, color = wireType.color, position = i, isCut = false })
    end
    self:DetermineCase()
    if not self.ActiveCase then self:GenerateWireConfiguration() else self.CurrentStep = 1 self.CutWires = {} end
end
function ENT:DetermineCase()
    if not LandmineDefusal or not LandmineDefusal.Cases then return end
    for _, case in ipairs(LandmineDefusal.Cases) do if case.check(self.Wires) then self.ActiveCase = case return end end
    self.ActiveCase = nil
end
function ENT:StartDefusalMinigame(ply)
    if CLIENT then return end
    if not self.Armed or not IsValid(ply) or not ply:IsPlayer() then return end
    if self:GetIsDefusing() then return end
    if not LandmineDefusal or not LandmineDefusal.Cases then self:Defuse(ply) return end
    self:SetIsDefusing(true)
    self:GenerateWireConfiguration()
    if not self.ActiveCase then self:SetIsDefusing(false) self:Defuse(ply) return end
    self:SetTimeRemaining(LandmineDefusal.DefusalTime or 90)
    net.Start("LandmineDefusal_OpenUI") net.WriteEntity(self) net.WriteTable(self.Wires) net.WriteString(self.ActiveCase.name) net.WriteString(self.ActiveCase.description) net.WriteTable(self.ActiveCase.sequence) net.Send(ply)
    local tid = DEFUSAL_TIMER_NAME .. self:EntIndex()
    timer.Create(tid, 1, 0, function()
        if not IsValid(self) then timer.Remove(tid) return end
        if not self:GetIsDefusing() then timer.Remove(tid) return end
        local r = self:GetTimeRemaining() - 1
        self:SetTimeRemaining(r)
        if r <= 0 then timer.Remove(tid) self:Trigger() end
    end)
end
function ENT:CheckWireCut(wirePosition, ply)
    if not self.ActiveCase or not self.ActiveCase.sequence then self:Trigger() return false end
    local wire = self.Wires[wirePosition]
    if not wire or wire.isCut then self:Trigger() return false end
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
        self:Trigger()
        return false, false
    end
end

-- Globaler Hook für Spring-Mine-Kugeln: Verhindere Tod, nur Verletzungen (aber nicht für den Auslöser)
if SERVER then
    hook.Add("EntityTakeDamage", "CrusaderSpringMineBulletDamage", function(target, dmg)
        local attacker = dmg:GetAttacker()
        
        -- Prüfe ob der Schaden von einer Spring-Mine kommt
        if IsValid(attacker) and attacker:GetClass() == "crusader_spring_mine" then
            if target:IsPlayer() or target:IsNPC() then
                -- WICHTIG: Wenn das Ziel der Auslöser ist, lasse den Schaden durch (Tod erlaubt)
                if attacker.Triggerer == target then
                    return -- Keine Begrenzung für den Auslöser
                end
                
                local currentHealth = target:Health()
                
                -- Wenn der Spieler/NPC nach dem Schaden sterben würde, begrenze den Schaden
                if currentHealth - dmg:GetDamage() <= 0 then
                    -- Setze Schaden so, dass genau 1 HP übrig bleibt
                    dmg:SetDamage(math.max(0, currentHealth - 1))
                end
            end
        end
    end)
end

function ENT:Initialize()
    -- Unsichtbares Platzhalter-Modell (vergraben)
    self:SetModel("models/hunter/blocks/cube05x05x05.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end
    
    -- Unsichtbar machen (vergraben)
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetRenderMode(RENDERMODE_NONE)
    
    -- Aktiviere USE-Funktion für Entschärfung
    self:SetUseType(SIMPLE_USE)
    self:SetHealth(1) -- Für Entschärfung
    
    -- Mine-Eigenschaften
    self.Armed = true
    self.ProximityRadius = 120 -- Erkennungsradius (verkleinert)
    self.ExplosionDamage = 150 -- Explosionsschaden (erhöht)
    self.ExplosionRadius = 180 -- Explosionsradius (vergrößert)
    self.BlastRadius = 250 -- Physikalische Druckwelle (größer als Explosionsradius)
    self.BlastForce = 5000 -- Kraft für Props
    self.BoltCount = 30 -- Anzahl der Kugeln (erhöht von 16 auf 30)
    self.SpringHeight = 30 -- Höhe beim Hochspringen (reduziert)
    self.TraceLength = 200 -- Für Effekt-Erkennung (Boden/Luft)
    self.Triggerer = nil -- Spieler, der die Mine auslöst
    
    -- Proximity-Check Timer
    local timerName = "CrusaderSpringMine_" .. self:EntIndex()
    timer.Create(timerName, 0.1, 0, function()
        if IsValid(self) then
            self:ProximityCheck()
        else
            timer.Remove(timerName)
        end
    end)
end

function ENT:ProximityCheck()
    if SERVER and not _cfgOk() then return end
    if not self.Armed then return end
    
    local pos = self:GetPos()
    local entsInRadius = ents.FindInSphere(pos, self.ProximityRadius)
    
    for _, ent in ipairs(entsInRadius) do
        if not IsValid(ent) or ent == self then continue end
        
        -- Prüfe ob es ein gültiges Ziel ist
        if ent:IsPlayer() then
            -- Spieler schleicht nicht
            if not ent:KeyDown(IN_DUCK) and not ent:KeyDown(IN_WALK) then
                local velocity = ent:GetVelocity():Length2D()
                if velocity > 100 then -- Spieler bewegt sich
                    self.Triggerer = ent -- Speichere den Auslöser
                    self:Trigger(ent)
                    return
                end
            end
        elseif ent:IsNPC() or ent:IsVehicle() then
            self:Trigger(ent)
            return
        end
    end
end

function ENT:Trigger(triggerer)
    if SERVER and not _cfgOk() then return end
    if not self.Armed then return end
    local wasDefusing = self.GetIsDefusing and self:GetIsDefusing()
    self.Armed = false
    if self.SetIsDefusing then self:SetIsDefusing(false) end
    timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())
    if wasDefusing and SERVER then
        net.Start("LandmineDefusal_Result") net.WriteBool(false) net.Broadcast()
    end

    -- Speichere den Auslöser
    if IsValid(triggerer) then
        self.Triggerer = triggerer
    end
    
    local pos = self:GetPos()
    
    -- Stoppe Proximity-Check
    local timerName = "CrusaderSpringMine_" .. self:EntIndex()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    
    -- Zeige Modell (Mine springt hoch)
    -- Setze das gewünschte Modell
    local modelPath = "models/blu/lvsmine.mdl"
    
    -- Setze Modell ZUERST
    self:SetModel(modelPath)
    
    -- Warte kurz, damit Modell geladen wird
    timer.Simple(0.01, function()
        if not IsValid(self) then return end
        
        -- Physik neu initialisieren nach Modell-Wechsel
        self:PhysicsInit(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:EnableMotion(true)
            phys:SetVelocity(Vector(0, 0, self.SpringHeight * 8)) -- Niedriger springen
        end
        
        -- Jetzt sichtbar machen (NACH Modell und Physik)
        self:SetNoDraw(false)
        self:DrawShadow(true)
        self:SetRenderMode(RENDERMODE_NORMAL)
        
        -- Stelle sicher, dass Modell auch auf Client sichtbar ist
        self:SetIsVisible(true)
        
        -- Prüfe ob Modell korrekt geladen wurde (Fallback)
        timer.Simple(0.1, function()
            if not IsValid(self) then return end
            
            -- Prüfe ob Modell existiert durch BoundingBox
            local mins, maxs = self:GetModelBounds()
            if mins:Distance(maxs) < 1 then
                -- Modell wurde nicht geladen, verwende Fallback
                print("[Spring Mine] Modell " .. modelPath .. " nicht gefunden, verwende Fallback")
                self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
                self:PhysicsInit(SOLID_VPHYSICS)
                local phys = self:GetPhysicsObject()
                if IsValid(phys) then
                    phys:Wake()
                    phys:EnableMotion(true)
                end
                self:SetNoDraw(false)
                self:DrawShadow(true)
                self:SetRenderMode(RENDERMODE_NORMAL)
                self:SetIsVisible(true)
            end
        end)
    end)
    
    -- Kurze Verzögerung, dann Explosion und Bolzen
    timer.Simple(0.2, function()
        if not IsValid(self) then return end
        
        local minePos = self:GetPos()
        
        -- GB5 Nitro Explosions-Effekt (wie gb5_light_b_nitro)
        -- Prüfe ob Mine auf dem Boden oder in der Luft ist
        local trace = util.TraceLine({
            start = minePos,
            endpos = minePos - Vector(0, 0, self.TraceLength or 200),
            filter = self
        })
        
        local effectName = trace.HitWorld and "nitro_main_m9k" or "nitro_air"
        
        -- Partikel-Effekt
        ParticleEffect(effectName, minePos, Angle(0, 0, 0), nil)
        
        -- Explosions-Sound (wie gb5 Schrapnell-Mine)
        self:EmitSound("gbombs_5/explosions/light_bomb/mine_explosion.mp3", 140, 100)
        
        -- Physikalische Druckwelle für Props (größerer Radius)
        local owner = IsValid(self:GetOwner()) and self:GetOwner() or self
        local blastRadius = self.BlastRadius or 250
        
        -- Props durch Druckwelle beeinflussen
        for _, ent in ipairs(ents.FindInSphere(minePos, blastRadius)) do
            if not IsValid(ent) or ent == self then continue end
            
            -- Nur Props mit Physik
            if ent:GetClass():find("prop_", 1, true) then
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    local dist = minePos:Distance(ent:GetPos())
                    local forceMultiplier = 1 - (dist / blastRadius)
                    forceMultiplier = math.Clamp(forceMultiplier, 0, 1)
                    
                    local dir = (ent:GetPos() - minePos):GetNormalized()
                    local force = self.BlastForce * forceMultiplier
                    
                    phys:Wake()
                    phys:ApplyForceCenter(dir * force)
                end
            end
        end
        
        -- Schaden in kleinem Radius (Auslöser stirbt, andere nur verletzt)
        local entsInRadius = ents.FindInSphere(minePos, self.ExplosionRadius)
        
        for _, ent in ipairs(entsInRadius) do
            if not IsValid(ent) or ent == self then continue end
            
            if ent:IsPlayer() or ent:IsNPC() then
                local dist = minePos:Distance(ent:GetPos())
                local damageMultiplier = 1 - (dist / self.ExplosionRadius)
                damageMultiplier = math.Clamp(damageMultiplier, 0, 1)
                local damage = self.ExplosionDamage * damageMultiplier
                
                -- Auslöser stirbt, andere nur verletzt
                if ent == self.Triggerer then
                    -- Auslöser: Tödlicher Schaden (garantiert Tod)
                    -- Verwende sehr hohen Schaden und setze HP direkt auf 0
                    local dmg = DamageInfo()
                    dmg:SetDamage(99999) -- Extrem hoher Schaden, garantiert Tod
                    dmg:SetAttacker(owner)
                    dmg:SetInflictor(self)
                    dmg:SetDamageType(DMG_BLAST)
                    dmg:SetDamagePosition(minePos)
                    ent:TakeDamageInfo(dmg)
                    
                    -- Stelle sicher, dass der Auslöser wirklich stirbt
                    if ent:IsPlayer() then
                        timer.Simple(0.01, function()
                            if IsValid(ent) and ent:Health() > 0 then
                                ent:SetHealth(0)
                                ent:Kill()
                            end
                        end)
                    end
                else
                    -- Andere: Nur verletzen (HP bleibt bei mindestens 1)
                    local currentHealth = ent:Health()
                    if currentHealth > 1 then
                        local dmg = DamageInfo()
                        dmg:SetDamage(damage)
                        dmg:SetAttacker(owner)
                        dmg:SetInflictor(self)
                        dmg:SetDamageType(DMG_BLAST)
                        dmg:SetDamagePosition(minePos)
                        ent:TakeDamageInfo(dmg)
                        
                        -- Stelle sicher, dass der Spieler nicht stirbt
                        if ent:Health() <= 0 then
                            ent:SetHealth(1)
                        end
                    end
                end
            end
        end
        
        -- 30 Pistolenkugeln in alle Richtungen schießen (gleichmäßig verteilt)
        local owner = IsValid(self:GetOwner()) and self:GetOwner() or self
        
        -- Erstelle temporären Shooter (NPC oder verwende Owner wenn Player)
        local shooter = nil
        if owner:IsPlayer() then
            shooter = owner
        else
            -- Erstelle temporären NPC als Shooter
            shooter = ents.Create("npc_gman")
            if IsValid(shooter) then
                shooter:SetPos(minePos)
                shooter:SetKeyValue("spawnflags", "1048576") -- Kein NPC-Verhalten
                shooter:Spawn()
                shooter:SetNoDraw(true)
                shooter:SetNotSolid(true)
                shooter:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
            end
        end
        
        if not IsValid(shooter) then
            shooter = self -- Fallback auf Mine selbst
        end
        
        for i = 1, self.BoltCount do
            -- Gleichmäßige Verteilung in alle Richtungen
            -- Verwende goldenen Winkel für gleichmäßige Verteilung
            local goldenAngle = 137.508 -- Grad
            local angle = (i * goldenAngle) % 360 -- Horizontaler Winkel
            
            -- Vertikaler Winkel: gleichmäßig von -45 bis 45 Grad verteilt
            local pitch = -45 + ((i - 1) / (self.BoltCount - 1)) * 90
            if self.BoltCount == 1 then pitch = 0 end
            
            local dir = Angle(pitch, angle, 0):Forward()
            
            -- Pistolenkugel mit FireBullets abfeuern (Hitscan)
            local bullet = {}
            bullet.Num = 1                         -- Anzahl der Kugeln pro Schuss
            bullet.Src = minePos                    -- Startpunkt (Position der Mine)
            bullet.Dir = dir                        -- Richtung (berechnet aus Winkel)
            bullet.Spread = Vector(0, 0, 0)        -- Keine Streuung, genau in die Richtung
            bullet.Tracer = 1                       -- Zeige Tracer bei jedem Schuss
            bullet.TracerName = "Tracer"            -- Standard Tracer-Effekt
            bullet.Force = 5                        -- Wucht, mit der Props weggestoßen werden
            bullet.Damage = 20                      -- Schaden pro Kugel (nur verletzen, nicht töten)
            bullet.AmmoType = "Pistol"              -- Munitionstyp für Effekte
            bullet.Attacker = owner                 -- Angreifer (Minenbesitzer)
            bullet.Callback = function(attacker, tr, dmgInfo)
                -- Stelle sicher, dass der Spieler nicht stirbt (maximal auf 1 HP reduzieren)
                local hitEnt = tr.Entity
                if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC()) then
                    local currentHealth = hitEnt:Health()
                    if currentHealth - dmgInfo:GetDamage() <= 0 then
                        -- Setze Schaden so, dass genau 1 HP übrig bleibt
                        dmgInfo:SetDamage(math.max(0, currentHealth - 1))
                    end
                end
            end
            
            -- Versuche FireBullets auf dem Shooter
            if shooter.FireBullets then
                shooter:FireBullets(bullet)
            else
                -- Fallback: Verwende util.TraceLine für manuellen Schuss
                local tr = util.TraceLine({
                    start = minePos,
                    endpos = minePos + dir * 10000,
                    filter = {self, shooter}
                })
                
                if tr.Hit then
                    -- Schaden anwenden
                    local hitEnt = tr.Entity
                    if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC()) then
                        local currentHealth = hitEnt:Health()
                        if currentHealth > 1 then
                            local dmg = DamageInfo()
                            dmg:SetDamage(20)
                            dmg:SetAttacker(owner)
                            dmg:SetInflictor(self)
                            dmg:SetDamageType(DMG_BULLET)
                            dmg:SetDamagePosition(tr.HitPos)
                            
                            hitEnt:TakeDamageInfo(dmg)
                            
                            -- Stelle sicher, dass der Spieler nicht stirbt
                            if hitEnt:Health() <= 0 then
                                hitEnt:SetHealth(1)
                            end
                        end
                    end
                    
                    -- Impact-Effekt
                    local effectdata = EffectData()
                    effectdata:SetOrigin(tr.HitPos)
                    effectdata:SetNormal(tr.HitNormal)
                    util.Effect("Impact", effectdata)
                end
                
                -- Tracer-Effekt
                local tracerdata = EffectData()
                tracerdata:SetStart(minePos)
                tracerdata:SetOrigin(tr.HitPos)
                util.Effect("Tracer", tracerdata)
            end
            
            -- VFire für visuellen Effekt (Feuer/Flammen) an der Mündung
            local firePos = minePos + dir * 10
            local effectdata = EffectData()
            effectdata:SetOrigin(firePos)
            effectdata:SetNormal(dir)
            effectdata:SetScale(0.5)
            util.Effect("VFire", effectdata)
        end
        
        -- Entferne temporären Shooter nach kurzer Zeit
        if IsValid(shooter) and shooter ~= owner and shooter ~= self then
            timer.Simple(0.5, function()
                if IsValid(shooter) then
                    shooter:Remove()
                end
            end)
        end
        
        -- Mine schneller entfernen (Modell verschwindet schneller)
        timer.Simple(0.3, function()
            if IsValid(self) then
                self:SetNoDraw(true) -- Modell sofort unsichtbar machen
                self:DrawShadow(false)
            end
        end)
        
        timer.Simple(0.5, function()
            if IsValid(self) then
                self:Remove()
            end
        end)
    end)
end

function ENT:OnTakeDamage(dmg)
    if dmg:GetDamage() > 0 and self.Armed then
        -- Speichere den Angreifer als Triggerer
        local attacker = dmg:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() then
            self:Trigger(attacker)
        else
            self:Trigger()
        end
    end
end

function ENT:OnRemove()
    timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())
    local timerName = "CrusaderSpringMine_" .. self:EntIndex()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
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

-- ENTSCHÄRFUNGS-LOGIK (genau wie bei der Standard-Mine)
function ENT:Defuse(defuser)
    if not self.Armed then return end
    self.Armed = false
    if self.SetIsDefusing then self:SetIsDefusing(false) end
    timer.Remove(DEFUSAL_TIMER_NAME .. self:EntIndex())

    local pos = self:GetPos()

    -- Timer stoppen
    local timerName = "CrusaderSpringMine_" .. self:EntIndex()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    
    -- Sound abspielen (Button-Sound)
    self:EmitSound("buttons/button9.wav", 75, 100)
    
    -- Dampf-Sound abspielen
    self:EmitSound("ambient/steam/steam_short" .. math.random(1, 2) .. ".wav", 75, 100)
    
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
    
    -- Nachricht an den entschärfenden Spieler
    if IsValid(defuser) and defuser:IsPlayer() then
        defuser:ChatPrint("[Mine] Spring-Mine erfolgreich entschärft!")
        print("[CRUSADER SPRING MINE] Mine entschärft von: " .. defuser:Nick())
    end
    
    -- Mine nach kurzer Verzögerung entfernen
    timer.Simple(0.5, function()
        if IsValid(self) then
            self:Remove()
        end
    end)
end
