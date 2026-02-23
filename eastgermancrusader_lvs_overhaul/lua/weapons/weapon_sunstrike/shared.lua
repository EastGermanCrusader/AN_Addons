-- ============================================================================
-- Merr-Sonn AA-1 "Sunstrike" - High-Intensity Thermal Interceptor
-- MANPADS (Man-Portable Air Defense System)
-- ============================================================================
-- "Wenn er schreit, stirbt etwas. Hoffen wir einfach, dass es der Feind ist."
--                                      — Unbekannter Klon-Soldat der 501. Legion
-- ============================================================================

SWEP.Base = "weapon_crusader_base"
SWEP.PrintName = "Merr-Sonn AA-1 \"Sunstrike\""
SWEP.Author = "EastGermanCrusader"
SWEP.Instructions = "Primärfeuer: Rakete abfeuern (nur bei Lock-On)\nSekundärfeuer: Zielerfassung aktivieren\n\nAchte auf die Mode-Anzeige - wenn sie schreit, ist das Ziel erfasst!"
SWEP.Category = "EastGermanCrusader"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 4
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "RPG_Round"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 4
SWEP.SlotPos = 1
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/v_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"
SWEP.HoldType = "rpg"

SWEP.UseHands = true

-- Sunstrike Konfiguration
SWEP.SunstrikeConfig = {
    -- Sensorik
    TrackingCone = 25,           -- Grad für Zielerfassung (enger als Fahrzeug-Version)
    TrackingRange = 10000,       -- 10km Reichweite (erhöht)
    LockOnTime = 1.5,            -- Sekunden bis Lock-On
    
    -- Rakete
    MissileSpeed = 2900,         -- 200 km/h Geschwindigkeit
    MissileDamage = 750,         -- Hochexplosive Splitter-Brandladung
    MissileRadius = 350,         -- Proxy-Zünder Radius
    MissileForce = 8000,
    MissileThrust = 800,
    MissileTurnSpeed = 2.0,      -- Sehr wendig
    
    -- Mode Frequenzen (Hz für Ton-Pitch)
    GrowlPitchLow = 60,          -- Tiefes Knurren (Suche)
    GrowlPitchMid = 120,         -- Mittleres Knurren (Ziel erkannt)
    GrowlPitchHigh = 200,        -- Hohes Kreischen (Lock-On nah)
    GrowlPitchLock = 280,        -- Schriller Dauerton (Locked)
}

-- ============================================================================
-- SHARED FUNKTIONEN
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Tracking")
    self:NetworkVar("Bool", 1, "LockedOn")
    self:NetworkVar("Entity", 0, "Target")
    self:NetworkVar("Float", 0, "LockProgress")
    self:NetworkVar("Float", 1, "TargetHeat")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:SetTracking(false)
    self:SetLockedOn(false)
    self:SetTarget(NULL)
    self:SetLockProgress(0)
    self:SetTargetHeat(0)
end

-- Berechne Hitzesignatur eines Ziels
function SWEP:GetHeatSignature(ent)
    if not IsValid(ent) then return 0 end
    
    -- LVS Fahrzeuge mit Heat Signature System
    if ent.GetHeatSignature then
        return ent:GetHeatSignature()
    end
    
    -- LVS Fahrzeuge ohne Heat Signature System (Fallback)
    if ent.LVS then
        local heat = 15 -- Basis
        
        if ent.GetEngineActive and ent:GetEngineActive() then
            heat = heat + 40
            if ent.GetThrottle then
                heat = heat + (ent:GetThrottle() * 30)
            end
        end
        
        -- Afterburner
        if ent.GetBoost and ent:GetBoost() > 0 then
            heat = heat + 50
        end
        
        return heat
    end
    
    -- Andere Fahrzeuge (HL2, Simfphys, etc.)
    if ent:IsVehicle() then
        return 25
    end
    
    -- NPCs
    if ent:IsNPC() then
        return 10
    end
    
    -- Props mit Feuer-Effekten
    if ent:IsOnFire() then
        return 80
    end
    
    return 0
end

-- Finde bestes Wärmeziel
function SWEP:FindHeatTarget()
    local owner = self:GetOwner()
    if not IsValid(owner) then return NULL, 0 end
    
    local eyePos = owner:EyePos()
    local eyeAng = owner:EyeAngles()
    local forward = eyeAng:Forward()
    
    local config = self.SunstrikeConfig
    local bestTarget = NULL
    local bestScore = 0
    local bestHeat = 0
    
    -- Suche LVS Fahrzeuge
    local targets = {}
    
    -- LVS Fahrzeuge
    for _, ent in pairs(ents.FindByClass("lvs_*")) do
        if IsValid(ent) and ent.LVS then
            table.insert(targets, ent)
        end
    end
    
    -- Alle anderen Fahrzeuge
    for _, ent in pairs(ents.GetAll()) do
        if IsValid(ent) and (ent:IsVehicle() or ent:IsNPC()) then
            table.insert(targets, ent)
        end
    end
    
    for _, ent in pairs(targets) do
        if not IsValid(ent) then continue end
        if ent == owner then continue end
        if ent:GetParent() == owner then continue end
        
        -- Prüfe ob Spieler im Fahrzeug der Owner ist
        if ent.GetDriver and IsValid(ent:GetDriver()) and ent:GetDriver() == owner then
            continue
        end
        
        local entPos = ent:LocalToWorld(ent:OBBCenter())
        local dir = (entPos - eyePos):GetNormalized()
        local dist = eyePos:Distance(entPos)
        
        -- Distanz-Check
        if dist > config.TrackingRange then continue end
        
        -- Winkel-Check (Cone)
        local dot = forward:Dot(dir)
        local angle = math.deg(math.acos(math.Clamp(dot, -1, 1)))
        
        if angle > config.TrackingCone then continue end
        
        -- Sichtlinien-Check
        local tr = util.TraceLine({
            start = eyePos,
            endpos = entPos,
            filter = {owner, self},
            mask = MASK_SHOT
        })
        
        if tr.Entity ~= ent and tr.Fraction < 0.95 then continue end
        
        -- Hitzesignatur berechnen
        local heat = self:GetHeatSignature(ent)
        
        if heat < 5 then continue end -- Minimale Signatur erforderlich
        
        -- Score berechnen (Hitze hat höchste Priorität)
        local heatScore = math.min(heat / 100, 1)
        local distScore = 1 - (dist / config.TrackingRange)
        local angScore = 1 - (angle / config.TrackingCone)
        
        local score = (heatScore * 0.7) + (distScore * 0.15) + (angScore * 0.15)
        
        if score > bestScore then
            bestTarget = ent
            bestScore = score
            bestHeat = heat
        end
    end
    
    return bestTarget, bestHeat
end

-- ============================================================================
-- SERVER FUNKTIONEN
-- ============================================================================

if SERVER then
    function SWEP:PrimaryAttack()
        if not self:CanPrimaryAttack() then return end
        if not self:GetLockedOn() then 
            -- Kein Lock-On - Fehlerton abspielen
            self:EmitSound("buttons/button10.wav", 75, 100)
            return 
        end
        
        local target = self:GetTarget()
        if not IsValid(target) then
            self:SetLockedOn(false)
            self:EmitSound("buttons/button10.wav", 75, 100)
            return
        end
        
        self:FireMissile(target)
        
        self:TakePrimaryAmmo(1)
        self:SetNextPrimaryFire(CurTime() + 1.5)
        
        -- Reset Tracking nach Schuss
        self:SetTracking(false)
        self:SetLockedOn(false)
        self:SetTarget(NULL)
        self:SetLockProgress(0)
    end
    
    function SWEP:SecondaryAttack()
        -- Toggle Tracking
        local tracking = not self:GetTracking()
        self:SetTracking(tracking)
        
        if not tracking then
            self:SetLockedOn(false)
            self:SetTarget(NULL)
            self:SetLockProgress(0)
        end
        
        self:SetNextSecondaryFire(CurTime() + 0.3)
    end
    
    function SWEP:Think()
        if not self:GetTracking() then return end
        
        local owner = self:GetOwner()
        if not IsValid(owner) then return end
        
        local target, heat = self:FindHeatTarget()
        local currentTarget = self:GetTarget()
        
        -- Ziel gewechselt?
        if target ~= currentTarget then
            self:SetTarget(target)
            self:SetLockProgress(0)
            self:SetLockedOn(false)
        end
        
        self:SetTargetHeat(heat)
        
        -- Seek-Sound abspielen wenn nach Ziel gesucht wird
        if not IsValid(target) then
            if (self._nextSeekSound or 0) <= CurTime() then
                self:EmitSound("seek.wav", 60, 100)
                self._nextSeekSound = CurTime() + 0.5 -- Alle 0.5 Sekunden
            end
        end
        
        if IsValid(target) then
            -- Lock-On Fortschritt
            local progress = self:GetLockProgress()
            local lockSpeed = heat / 100 -- Heißere Ziele = schnelleres Lock
            lockSpeed = math.Clamp(lockSpeed, 0.3, 1.5)
            
            progress = progress + (FrameTime() * lockSpeed)
            
            if progress >= self.SunstrikeConfig.LockOnTime then
                progress = self.SunstrikeConfig.LockOnTime
                if not self:GetLockedOn() then
                    self:SetLockedOn(true)
                    -- Lock-On Sound
                    self:EmitSound("lock.wav", 75, 100)
                end
            end
            
            self:SetLockProgress(progress)
        else
            self:SetLockProgress(0)
            self:SetLockedOn(false)
        end
        
        self:NextThink(CurTime())
        return true
    end
    
    function SWEP:FireMissile(target)
        local owner = self:GetOwner()
        if not IsValid(owner) then return end
        
        local config = self.SunstrikeConfig
        
        -- Versuche LVS Rakete zu erstellen
        local useLVS = LVS and ents.Create("lvs_missile")
        
        if IsValid(useLVS) then
            local missile = useLVS
            
            local eyePos = owner:EyePos()
            local eyeAng = owner:EyeAngles()
            
            missile:SetPos(eyePos + eyeAng:Forward() * 50 + eyeAng:Up() * -10)
            missile:SetAngles(eyeAng)
            missile:Spawn()
            missile:Activate()
            
            missile:SetAttacker(owner)
            missile:SetSpeed(config.MissileSpeed)
            missile:SetDamage(config.MissileDamage)
            missile:SetRadius(config.MissileRadius)
            missile:SetForce(config.MissileForce)
            missile:SetThrust(config.MissileThrust)
            missile:SetTurnSpeed(config.MissileTurnSpeed)
            
            if missile.SetTarget then
                missile:SetTarget(target)
            end
            
            missile:Enable()
            
            -- HUD für Spieler
            net.Start("lvs_missile_hud", true)
                net.WriteEntity(missile)
            net.Send(owner)
        else
            -- Fallback: Standard HL2 RPG Rakete
            local missile = ents.Create("rpg_missile")
            if not IsValid(missile) then return end
            
            local eyePos = owner:EyePos()
            local eyeAng = owner:EyeAngles()
            
            missile:SetPos(eyePos + eyeAng:Forward() * 50)
            missile:SetAngles(eyeAng)
            missile:SetOwner(owner)
            missile:Spawn()
            missile:Activate()
            
            -- Setze Geschwindigkeit
            local phys = missile:GetPhysicsObject()
            if IsValid(phys) then
                phys:SetVelocity(eyeAng:Forward() * config.MissileSpeed)
            end
        end
        
        -- Feuer-Sound und Animation
        self:EmitSound("weapons/rpg/rocketfire1.wav", 100, 100)
        self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
        owner:SetAnimation(PLAYER_ATTACK1)
        
        -- Rückstoß
        owner:ViewPunch(Angle(-5, 0, 0))
    end
    
    function SWEP:Reload()
        if self:Clip1() >= self.Primary.ClipSize then return end
        if self:Ammo1() <= 0 then return end
        
        self:DefaultReload(ACT_VM_RELOAD)
        
        -- Stoppe Tracking während Reload
        self:SetTracking(false)
        self:SetLockedOn(false)
        self:SetTarget(NULL)
        self:SetLockProgress(0)
    end
end

-- ============================================================================
-- CLIENT FUNKTIONEN - MODE SYSTEM
-- ============================================================================

if CLIENT then
    -- Sound-Variablen
    SWEP.GrowlSound = nil
    SWEP.LastGrowlPitch = 0
    
    function SWEP:Think()
        self:UpdateGrowlSound()
        self:UpdateClientSounds()
    end
    
    -- Client-Side Sounds für den Spieler
    function SWEP:UpdateClientSounds()
        local owner = self:GetOwner()
        if not IsValid(owner) or owner ~= LocalPlayer() then return end
        
        local tracking = self:GetTracking()
        local target = self:GetTarget()
        local lockedOn = self:GetLockedOn()
        
        if tracking then
            -- Seek-Sound abspielen wenn nach Ziel gesucht wird
            if not IsValid(target) then
                if (self._nextClientSeekSound or 0) <= CurTime() then
                    surface.PlaySound("seek.wav")
                    self._nextClientSeekSound = CurTime() + 0.5 -- Alle 0.5 Sekunden
                end
            end
            
            -- Lock-Sound abspielen wenn Lock-On erreicht wird
            if lockedOn and not self._hasPlayedClientLockSound then
                surface.PlaySound("lock.wav")
                self._hasPlayedClientLockSound = true
            elseif not lockedOn then
                self._hasPlayedClientLockSound = false
            end
        else
            -- Tracking beendet - stoppe alle Sounds
            self._hasPlayedClientLockSound = false
            self._nextClientSeekSound = 0 -- Reset Seek-Sound Timer
        end
    end
    
    function SWEP:UpdateGrowlSound()
        local owner = self:GetOwner()
        if not IsValid(owner) or owner ~= LocalPlayer() then return end
        
        local tracking = self:GetTracking()
        local target = self:GetTarget()
        local lockedOn = self:GetLockedOn()
        local progress = self:GetLockProgress()
        local heat = self:GetTargetHeat()
        local config = self.SunstrikeConfig
        
        -- Berechne Pitch basierend auf Status
        local targetPitch = 0
        
        if tracking then
            if lockedOn then
                -- Schriller Dauerton - LOCKED
                targetPitch = config.GrowlPitchLock
            elseif IsValid(target) then
                -- Interpoliere zwischen Mid und High basierend auf Progress
                local t = progress / config.LockOnTime
                targetPitch = Lerp(t, config.GrowlPitchMid, config.GrowlPitchHigh)
            else
                -- Tiefes Knurren - Suche
                targetPitch = config.GrowlPitchLow
            end
        end
        
        -- Smooth Pitch-Änderung
        self.LastGrowlPitch = Lerp(FrameTime() * 5, self.LastGrowlPitch or 0, targetPitch)
        
        -- Sound Management
        if self.LastGrowlPitch > 10 then
            if not self.GrowlSound then
                self.GrowlSound = CreateSound(owner, "ambient/energy/force_field_loop1.wav")
                self.GrowlSound:Play()
            end
            
            -- Pitch und Volume anpassen
            local pitch = math.Clamp(self.LastGrowlPitch, 50, 255)
            local volume = tracking and 0.6 or 0
            
            self.GrowlSound:ChangePitch(pitch, 0.1)
            self.GrowlSound:ChangeVolume(volume, 0.1)
        else
            if self.GrowlSound then
                self.GrowlSound:Stop()
                self.GrowlSound = nil
            end
        end
    end
    
    function SWEP:OnRemove()
        if self.GrowlSound then
            self.GrowlSound:Stop()
            self.GrowlSound = nil
        end
    end
    
    function SWEP:Holster()
        if self.GrowlSound then
            self.GrowlSound:Stop()
            self.GrowlSound = nil
        end
        
        self:SetTracking(false)
        return true
    end
    
    -- ========================================================================
    -- HUD ZEICHNEN
    -- ========================================================================
    
    local colorRed = Color(255, 50, 50, 255)
    local colorOrange = Color(255, 150, 50, 255)
    local colorYellow = Color(255, 255, 50, 255)
    local colorGreen = Color(50, 255, 50, 255)
    local colorWhite = Color(255, 255, 255, 255)
    local colorBG = Color(0, 0, 0, 150)
    
    function SWEP:DrawHUD()
        local owner = self:GetOwner()
        if not IsValid(owner) or owner ~= LocalPlayer() then return end
        
        local tracking = self:GetTracking()
        local target = self:GetTarget()
        local lockedOn = self:GetLockedOn()
        local progress = self:GetLockProgress()
        local heat = self:GetTargetHeat()
        local config = self.SunstrikeConfig
        
        local scrW, scrH = ScrW(), ScrH()
        local centerX, centerY = scrW / 2, scrH / 2
        
        -- Tracking Cone anzeigen
        if tracking then
            local coneRadius = 150
            local segments = 32
            
            surface.SetDrawColor(tracking and (lockedOn and colorRed or colorYellow) or colorWhite)
            
            for i = 0, segments do
                local a1 = math.rad((i / segments) * 360)
                local a2 = math.rad(((i + 1) / segments) * 360)
                
                local x1 = centerX + math.cos(a1) * coneRadius
                local y1 = centerY + math.sin(a1) * coneRadius
                local x2 = centerX + math.cos(a2) * coneRadius
                local y2 = centerY + math.sin(a2) * coneRadius
                
                surface.DrawLine(x1, y1, x2, y2)
            end
        end
        
        -- Ziel-Marker
        if IsValid(target) then
            local targetPos = target:LocalToWorld(target:OBBCenter()):ToScreen()
            
            if targetPos.visible then
                local markerSize = 40
                local color = lockedOn and colorRed or colorOrange
                
                -- Pulsierender Effekt
                local pulse = math.sin(CurTime() * (lockedOn and 15 or 5)) * 0.3 + 0.7
                color = Color(color.r, color.g, color.b, 255 * pulse)
                
                surface.SetDrawColor(color)
                
                -- Diamant-Form
                local points = {
                    {x = targetPos.x, y = targetPos.y - markerSize},
                    {x = targetPos.x + markerSize, y = targetPos.y},
                    {x = targetPos.x, y = targetPos.y + markerSize},
                    {x = targetPos.x - markerSize, y = targetPos.y},
                }
                
                for i = 1, 4 do
                    local p1 = points[i]
                    local p2 = points[i % 4 + 1]
                    surface.DrawLine(p1.x, p1.y, p2.x, p2.y)
                end
                
                -- Lock-On Text
                local status = lockedOn and "◆ LOCKED ◆" or "TRACKING..."
                draw.SimpleText(status, "DermaLarge", targetPos.x, targetPos.y - markerSize - 20, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                
                -- Hitzesignatur anzeigen
                local heatText = string.format("HEAT: %.0f°", heat)
                draw.SimpleText(heatText, "DermaDefault", targetPos.x, targetPos.y + markerSize + 10, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        end
        
        -- Status-Panel (unten rechts)
        local panelX = scrW - 250
        local panelY = scrH - 180
        local panelW = 230
        local panelH = 160
        
        -- Hintergrund
        draw.RoundedBox(8, panelX, panelY, panelW, panelH, colorBG)
        
        -- Titel
        draw.SimpleText("AA-1 SUNSTRIKE", "DermaDefaultBold", panelX + panelW/2, panelY + 10, colorWhite, TEXT_ALIGN_CENTER)
        
        -- Status
        local statusColor = colorWhite
        local statusText = "STANDBY"
        
        if tracking then
            if lockedOn then
                statusColor = colorGreen
                statusText = "◆ LOCK ACQUIRED ◆"
            elseif IsValid(target) then
                statusColor = colorYellow
                statusText = "ACQUIRING..."
            else
                statusColor = colorOrange
                statusText = "SEARCHING..."
            end
        end
        
        draw.SimpleText(statusText, "DermaDefault", panelX + panelW/2, panelY + 35, statusColor, TEXT_ALIGN_CENTER)
        
        -- Lock-On Progress Bar
        local barX = panelX + 15
        local barY = panelY + 55
        local barW = panelW - 30
        local barH = 15
        
        draw.RoundedBox(4, barX, barY, barW, barH, Color(30, 30, 30, 255))
        
        local progressFrac = progress / config.LockOnTime
        -- Manuelle Farbinterpolation (Orange zu Gelb)
        local progressColor = lockedOn and colorGreen or Color(
            Lerp(progressFrac, colorOrange.r, colorYellow.r),
            Lerp(progressFrac, colorOrange.g, colorYellow.g),
            Lerp(progressFrac, colorOrange.b, colorYellow.b),
            255
        )
        draw.RoundedBox(4, barX, barY, barW * progressFrac, barH, progressColor)
        
        draw.SimpleText("LOCK", "DermaDefault", barX + barW/2, barY + barH/2, colorWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Hitzesignatur-Anzeige
        draw.SimpleText("TARGET HEAT:", "DermaDefault", barX, panelY + 80, colorWhite, TEXT_ALIGN_LEFT)
        
        local heatBarY = panelY + 95
        draw.RoundedBox(4, barX, heatBarY, barW, barH, Color(30, 30, 30, 255))
        
        local heatFrac = math.Clamp(heat / 100, 0, 1)
        local heatColor = heat > 50 and colorRed or (heat > 25 and colorOrange or colorYellow)
        draw.RoundedBox(4, barX, heatBarY, barW * heatFrac, barH, heatColor)
        
        draw.SimpleText(string.format("%.0f°", heat), "DermaDefault", barX + barW/2, heatBarY + barH/2, colorWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Mode Indikator
        local growlY = panelY + 120
        local growlText = "MODE: "
        local growlStatus = "SILENT"
        local growlColor = colorWhite
        
        if tracking then
            if lockedOn then
                growlStatus = "♪♪♪ SCREAMING ♪♪♪"
                growlColor = colorRed
            elseif IsValid(target) then
                growlStatus = "♪♪ GROWLING ♪♪"
                growlColor = colorYellow
            else
                growlStatus = "♪ humming ♪"
                growlColor = colorOrange
            end
        end
        
        draw.SimpleText(growlText, "DermaDefault", barX, growlY, colorWhite, TEXT_ALIGN_LEFT)
        draw.SimpleText(growlStatus, "DermaDefault", barX + 80, growlY, growlColor, TEXT_ALIGN_LEFT)
        
        -- Anleitung
        local helpY = panelY + 140
        local helpText = tracking and "[RMB] Stop Tracking" or "[RMB] Start Tracking"
        draw.SimpleText(helpText, "DermaDefault", panelX + panelW/2, helpY, Color(150, 150, 150), TEXT_ALIGN_CENTER)
    end
    
    function SWEP:DrawHUDBackground()
        -- Nichts hier
    end
end
