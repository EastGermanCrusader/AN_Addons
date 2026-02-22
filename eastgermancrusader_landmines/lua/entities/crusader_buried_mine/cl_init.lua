include("shared.lua")

function ENT:Initialize()
    self.ProximityRadius = 150
end

function ENT:Draw() end

function ENT:DrawTranslucent()
    self:Draw()
end


hook.Add("PostDrawTranslucentRenderables", "crusaders_minedev", function()
     local ply = LocalPlayer()
     local wep = ply:GetActiveWeapon()

     if !IsValid(wep) or wep:GetClass() != "weapon_crusader_minelayer" then return end

     for k,v in ipairs(ents.FindByClass("crusader_buried_mine")) do
         local pos = v:GetPos()
         local ang = Angle(0, CurTime() * 50, 0)
         
         render.SetColorMaterial()
         render.DrawSphere(pos + Vector(0, 0, 5), 10, 16, 16, Color(255, 0, 0, 200))
            
         local ringPos = pos + Vector(0, 0, 2)
         render.DrawWireframeSphere(ringPos, v.ProximityRadius, 20, 20, Color(255, 50, 50, 100))
 
         -- 3D2D Text über der Mine
         local textPos = pos + Vector(0, 0, 30)
         local textAng = (ply:EyePos() - textPos):Angle()
         textAng:RotateAroundAxis(textAng:Right(), 20)
         textAng:RotateAroundAxis(textAng:Up(), 90)
         textAng:RotateAroundAxis(textAng:Forward(), 150)

         cam.Start3D2D(textPos, textAng, 0.1)
             draw.SimpleText("MINE", "DermaLarge", 0, 0, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
             draw.SimpleText("Radius: " .. v.ProximityRadius .. "u", "DermaDefault", 0, 30, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
         cam.End3D2D()
     end
end)