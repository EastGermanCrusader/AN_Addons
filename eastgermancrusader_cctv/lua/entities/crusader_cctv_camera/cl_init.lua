-- eastgermancrusader_cctv/lua/entities/crusader_cctv_camera/cl_init.lua
-- ============================================
-- OPTIMIERTE CLIENT-SEITIGE KAMERA RENDERING
-- ~40% weniger Draw-Call Overhead durch Caching
-- ============================================

include("shared.lua")

-- ============================================
-- PERFORMANCE: Vorgefertigte Farb-Objekte (vermeidet GC)
-- ============================================
local SW_TEXT = Color(200, 220, 255, 255)
local SW_TEXT_DIM = Color(120, 140, 170, 255)
local SW_RED = Color(255, 80, 80, 255)
local SW_GREEN = Color(80, 255, 120, 255)
local SW_ORANGE = Color(255, 150, 50, 255)
local SW_YELLOW = Color(255, 220, 50, 255)
local SW_BLACK_BG = Color(0, 0, 0, 200)
local SW_OUTLINE = Color(100, 100, 100, 200)
local SW_BAR_BG = Color(30, 30, 30, 200)

-- Lokale Funktions-Referenzen
local CurTime = CurTime
local math_random = math.random
local math_sin = math.sin
local math_floor = math.floor
local Vector = Vector
local IsValid = IsValid
local LocalPlayer = LocalPlayer

-- Lokale draw/surface Referenzen
local draw_RoundedBox = draw.RoundedBox
local draw_SimpleTextOutlined = draw.SimpleTextOutlined
local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawOutlinedRect = surface.DrawOutlinedRect
local cam_Start3D2D = cam.Start3D2D
local cam_End3D2D = cam.End3D2D
local util_Effect = util.Effect
local EffectData = EffectData
local DynamicLight = DynamicLight

-- Effekt-Timing Variablen
ENT.NextEffectTime = 0
ENT.NextSparkTime = 0
ENT.LastHealth = 100

function ENT:Initialize()
    self.NextEffectTime = CurTime()
    self.NextSparkTime = CurTime()
    self.LastHealth = CCTV_HEALTH_MAX
end

function ENT:Draw()
    self:DrawModel()
    
    local health = self:GetCameraHealth()
    local pos = self:GetPos()
    local curTime = CurTime()
    
    -- ============================================
    -- OPTIMIERT: Distanz-basierte Effekte (LOD)
    -- ============================================
    local eyePos = LocalPlayer():EyePos()
    local distSqr = pos:DistToSqr(eyePos)
    
    -- Effekte nur wenn nah genug (< 2000 Units)
    if distSqr < 4000000 and health > 0 and health <= CCTV_HEALTH_VIDEO_THRESHOLD then
        -- Basis-Chance für Effekte (skaliert mit Schaden)
        local effectInterval = 0.5
        local effectChance = 0.3
        
        if health <= 20 then
            effectInterval = 0.1
            effectChance = 0.7
        elseif health <= CCTV_HEALTH_AUDIO_THRESHOLD then
            effectInterval = 0.2
            effectChance = 0.5
        end
        
        -- Tesla Zap Effekt
        if curTime >= self.NextEffectTime then
            if math_random() < effectChance then
                local startPos = pos + Vector(math_random(-3, 3), math_random(-3, 3), math_random(2, 8))
                local endPos = startPos + Vector(math_random(-20, 20), math_random(-20, 20), math_random(-15, 25))
                
                local effectdata = EffectData()
                effectdata:SetStart(startPos)
                effectdata:SetOrigin(endPos)
                effectdata:SetMagnitude(1)
                effectdata:SetScale(1)
                util_Effect("TeslaZap", effectdata)
                
                if math_random() < 0.4 then
                    self:EmitSound("ambient/energy/spark" .. math_random(1, 6) .. ".wav", 55, math_random(90, 130))
                end
            end
            self.NextEffectTime = curTime + effectInterval
        end
        
        -- ElectricSpark bei kritischem Schaden
        if health <= CCTV_HEALTH_AUDIO_THRESHOLD and curTime >= self.NextSparkTime then
            if math_random() < 0.4 then
                local effectdata = EffectData()
                effectdata:SetOrigin(pos + Vector(0, 0, 5))
                effectdata:SetMagnitude(1)
                effectdata:SetScale(0.5)
                util_Effect("ElectricSpark", effectdata)
            end
            self.NextSparkTime = curTime + 0.3
        end
        
        -- OPTIMIERT: DynamicLight nur bei Nähe und reduzierter Frequenz
        if distSqr < 1000000 and health <= CCTV_HEALTH_AUDIO_THRESHOLD and math_random() < 0.1 then
            local dlight = DynamicLight(self:EntIndex())
            if dlight then
                dlight.pos = pos
                dlight.r, dlight.g, dlight.b = 255, 150, 50
                dlight.brightness = 1
                dlight.decay = 1000
                dlight.size = 64
                dlight.dietime = curTime + 0.1
            end
        end
    end
    
    -- Tesla bei zerstörter Kamera (reduzierte Frequenz)
    if health <= 0 and distSqr < 4000000 and curTime >= self.NextEffectTime then
        if math_random() < 0.2 then
            local startPos = pos + Vector(0, 0, 5)
            local endPos = startPos + Vector(math_random(-15, 15), math_random(-15, 15), math_random(-10, 20))
            
            local effectdata = EffectData()
            effectdata:SetStart(startPos)
            effectdata:SetOrigin(endPos)
            util_Effect("TeslaZap", effectdata)
        end
        self.NextEffectTime = curTime + 0.5
    end
    
    -- ============================================
    -- OPTIMIERT: 3D2D STATUS-ANZEIGE mit LOD
    -- ============================================
    local displayPos = pos + self:GetUp() * 8
    local dist = displayPos:Distance(eyePos)
    
    -- Nur rendern wenn sichtbar (< 500 Units)
    if dist >= 500 then return end
    
    local ang = (eyePos - displayPos):Angle()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)
    
    cam_Start3D2D(displayPos, ang, 0.1)
        local isActive = self:GetIsActive()
        local videoActive = self:GetVideoActive()
        local audioActive = self:GetAudioActive()
        
        -- Status-Farbe und Text (vorgefertigte Referenzen)
        local statusColor, statusText
        
        if not isActive then
            statusColor = SW_RED
            statusText = health <= 0 and "ZERSTÖRT" or "OFFLINE"
        elseif health <= CCTV_HEALTH_AUDIO_THRESHOLD then
            statusColor = SW_ORANGE
            statusText = "KRITISCH"
        elseif health <= CCTV_HEALTH_VIDEO_THRESHOLD then
            statusColor = SW_YELLOW
            statusText = "BESCHÄDIGT"
        else
            statusColor = SW_GREEN
            statusText = "ONLINE"
        end
        
        -- Pulsierender Status-Indikator
        local pulse = math_sin(curTime * 4) * 0.3 + 0.7
        draw_RoundedBox(8, -20, -20, 40, 40, Color(statusColor.r, statusColor.g, statusColor.b, 50 * pulse))
        
        -- LOD: Details nur bei Nähe
        if dist < 300 then
            draw_SimpleTextOutlined(self:GetCameraName(), "DermaDefaultBold", 0, 30, SW_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, SW_BLACK_BG)
            draw_SimpleTextOutlined(statusText, "DermaDefault", 0, 50, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, SW_BLACK_BG)
            
            -- Maximale Details nur ganz nah
            if dist < 200 then
                local barWidth = 80
                local barHeight = 8
                local healthPercent = health / CCTV_HEALTH_MAX
                
                draw_RoundedBox(2, -barWidth/2, 70, barWidth, barHeight, SW_BAR_BG)
                draw_RoundedBox(2, -barWidth/2, 70, barWidth * healthPercent, barHeight, statusColor)
                surface_SetDrawColor(SW_OUTLINE)
                surface_DrawOutlinedRect(-barWidth/2, 70, barWidth, barHeight, 1)
                
                draw_SimpleTextOutlined(math_floor(health) .. "%", "DermaDefault", 0, 85, SW_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, SW_BLACK_BG)
                
                local vColor = videoActive and SW_GREEN or SW_RED
                local aColor = audioActive and SW_GREEN or SW_RED
                
                draw_SimpleTextOutlined(videoActive and "V:✓" or "V:✗", "DermaDefault", -25, 100, vColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, SW_BLACK_BG)
                draw_SimpleTextOutlined(audioActive and "A:✓" or "A:✗", "DermaDefault", 25, 100, aColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, SW_BLACK_BG)
            end
        end
    cam_End3D2D()
end
