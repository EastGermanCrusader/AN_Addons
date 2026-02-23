-- EastGermanCrusader SAM System - Alarm Lautsprecher Client

include("shared.lua")

function ENT:Initialize()
    -- Client Init
end

function ENT:Draw()
    self:DrawModel()
    
    -- Leuchten wenn Alarm aktiv
    if self:GetAlarmActive() then
        local pos = self:GetPos()
        
        local dlight = DynamicLight(self:EntIndex())
        if dlight then
            dlight.pos = pos
            dlight.r = 255
            dlight.g = 100
            dlight.b = 0
            dlight.brightness = 2 + math.sin(CurTime() * 8) * 1
            dlight.decay = 1000
            dlight.size = 150
            dlight.dietime = CurTime() + 0.1
        end
    end
end

function ENT:DrawTranslucent()
    local ply = LocalPlayer()
    local dist = ply:GetPos():Distance(self:GetPos())
    
    if dist > 300 then return end
    
    local pos = self:GetPos() + Vector(0, 0, 25)
    local ang = (ply:EyePos() - pos):Angle()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)
    
    cam.Start3D2D(pos, ang, 0.1)
        local alarmActive = self:GetAlarmActive()
        local col = alarmActive and Color(255, 50, 50) or Color(100, 100, 100)
        
        draw.RoundedBox(4, -60, -15, 120, 30, Color(0, 0, 0, 200))
        draw.SimpleText("LAUTSPRECHER", "DermaDefault", 0, -5, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        local status = alarmActive and "ALARM!" or "Bereit"
        draw.SimpleText(status, "DermaDefault", 0, 8, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
