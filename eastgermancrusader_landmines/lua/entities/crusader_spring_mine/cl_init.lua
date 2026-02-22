include("shared.lua")

function ENT:Initialize()
    self.ProximityRadius = 120 -- Muss mit Server-Wert übereinstimmen
end

function ENT:Draw()
    -- Zeichne Modell nur wenn nicht vergraben
    -- Prüfe sowohl NoDraw als auch Netzwerk-Variable
    local isVisible = self:GetIsVisible()
    if not self:GetNoDraw() or isVisible then
        self:DrawModel()
    end
end

function ENT:DrawTranslucent()
    -- Zeichne auch in Translucent-Pass
    local isVisible = self:GetIsVisible()
    if not self:GetNoDraw() or isVisible then
        self:DrawModel()
    end
end

-- Anzeige-Logik genau wie bei der Standard-Mine
hook.Add("PostDrawTranslucentRenderables", "crusaders_springminedev", function()
     local ply = LocalPlayer()
     local wep = ply:GetActiveWeapon()

     if !IsValid(wep) or wep:GetClass() != "weapon_crusader_minelayer" then return end

     for k,v in ipairs(ents.FindByClass("crusader_spring_mine")) do
         local pos = v:GetPos()
         local ang = Angle(0, CurTime() * 50, 0)
         
         render.SetColorMaterial()
         render.DrawSphere(pos + Vector(0, 0, 5), 10, 16, 16, Color(255, 150, 0, 200))
            
         local ringPos = pos + Vector(0, 0, 2)
         render.DrawWireframeSphere(ringPos, v.ProximityRadius or 120, 20, 20, Color(255, 150, 50, 100))

         -- 3D2D Text über der Mine
         local textPos = pos + Vector(0, 0, 30)
         local textAng = (ply:EyePos() - textPos):Angle()
         textAng:RotateAroundAxis(textAng:Right(), 20)
         textAng:RotateAroundAxis(textAng:Up(), 90)
         textAng:RotateAroundAxis(textAng:Forward(), 150)

         cam.Start3D2D(textPos, textAng, 0.1)
             draw.SimpleText("SPRING MINE", "DermaLarge", 0, 0, Color(255, 150, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
             draw.SimpleText("Radius: " .. (v.ProximityRadius or 120) .. "u", "DermaDefault", 0, 30, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
         cam.End3D2D()
     end
end)
