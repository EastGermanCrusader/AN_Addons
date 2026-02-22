-- EastGermanCrusader SAM System - Transponder Receiver Client

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
    
    if self:GetDestroyed() then
        -- Zerstörtes Gerät - visuelles Feedback
        local pos = self:GetPos() + self:GetUp() * 50
        
        local dlight = DynamicLight(self:EntIndex())
        if dlight then
            dlight.pos = pos
            dlight.r = 255
            dlight.g = 50
            dlight.b = 50
            dlight.brightness = 1
            dlight.decay = 1000
            dlight.size = 50
            dlight.dietime = CurTime() + 0.1
        end
    end
end

function ENT:DrawTranslucent()
    local ply = LocalPlayer()
    local dist = ply:GetPos():Distance(self:GetPos())
    
    if dist > 300 then return end
    
    local pos = self:GetPos() + Vector(0, 0, 80)
    local ang = (ply:EyePos() - pos):Angle()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)
    
    cam.Start3D2D(pos, ang, 0.1)
        local bgCol = self:GetDestroyed() and Color(60, 0, 0, 220) or Color(0, 40, 0, 200)
        draw.RoundedBox(4, -80, -20, 160, 40, bgCol)
        
        local textCol = self:GetDestroyed() and Color(255, 100, 100) or Color(100, 255, 100)
        local text = self:GetDestroyed() and "ZERSTÖRT" or "TRANSPONDER"
        draw.SimpleText(text, "DermaDefault", 0, 0, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
