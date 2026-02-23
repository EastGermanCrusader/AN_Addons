-- EastGermanCrusader SAM System - Alarm Lampe Client

include("shared.lua")

function ENT:Initialize()
    -- Client Init
end

function ENT:Draw()
    self:DrawModel()
    
    -- Rotes Licht wenn Alarm aktiv
    if self:GetAlarmActive() then
        local pos = self:GetPos()
        local pulse = math.sin(CurTime() * 6) * 0.5 + 0.5
        
        -- Haupt-Licht (rot, pulsierend)
        local dlight = DynamicLight(self:EntIndex())
        if dlight then
            dlight.pos = pos + self:GetUp() * 10
            dlight.r = 255
            dlight.g = 20
            dlight.b = 20
            dlight.brightness = self.LightBrightness * (0.6 + pulse * 0.4)
            dlight.decay = 1000
            dlight.size = self.LightRadius
            dlight.dietime = CurTime() + 0.1
        end
        
        -- Zusätzliches Licht für mehr Helligkeit
        local dlight2 = DynamicLight(self:EntIndex() + 50000)
        if dlight2 then
            dlight2.pos = pos + self:GetUp() * 5
            dlight2.r = 255
            dlight2.g = 50
            dlight2.b = 50
            dlight2.brightness = self.LightBrightness * 0.5 * (0.6 + pulse * 0.4)
            dlight2.decay = 1000
            dlight2.size = self.LightRadius * 1.5
            dlight2.dietime = CurTime() + 0.1
        end
        
        -- Glow Sprite
        render.SetMaterial(Material("sprites/light_glow02_add"))
        local glowSize = 30 + pulse * 20
        render.DrawSprite(pos + self:GetUp() * 10, glowSize, glowSize, Color(255, 50, 50, 200))
    end
end

function ENT:DrawTranslucent()
    local ply = LocalPlayer()
    local dist = ply:GetPos():Distance(self:GetPos())
    
    if dist > 400 then return end
    
    local pos = self:GetPos() + Vector(0, 0, 30)
    local ang = (ply:EyePos() - pos):Angle()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)
    
    cam.Start3D2D(pos, ang, 0.08)
        local alarmActive = self:GetAlarmActive()
        local col = alarmActive and Color(255, 50, 50) or Color(80, 80, 80)
        local bgCol = alarmActive and Color(60, 0, 0, 220) or Color(20, 20, 20, 200)
        
        draw.RoundedBox(4, -70, -20, 140, 40, bgCol)
        
        if alarmActive then
            -- Blinkendes "ALARM"
            local blink = math.sin(CurTime() * 8) > 0
            if blink then
                draw.SimpleText("!! ALARM !!", "DermaDefaultBold", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText("!! ALARM !!", "DermaDefaultBold", 0, 0, Color(255, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        else
            draw.SimpleText("STANDBY", "DermaDefault", 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end
