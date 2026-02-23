include("shared.lua")

function ENT:Draw()
    -- Stelle sicher, dass der Bolzen sichtbar ist
    if not self:GetNoDraw() then
        self:DrawModel()
        
        -- Optional: Zusätzliche visuelle Hilfe (kleine Glüh-Effekt)
        if self:GetVelocity():Length() > 100 then
            render.SetMaterial(Material("sprites/light_glow02_add"))
            render.DrawSprite(self:GetPos(), 5, 5, Color(255, 200, 100, 200))
        end
    end
end

function ENT:DrawTranslucent()
    self:Draw()
end
