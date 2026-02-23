include("shared.lua")

function ENT:Initialize()
    self.ProximityRadius = 200
end

function ENT:Draw() end
function ENT:DrawTranslucent()
    self:Draw()
end

hook.Add("PostDrawTranslucentRenderables", "crusaders_dioxisminedev", function()
    local ply = LocalPlayer()
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_crusader_minelayer" then return end

    for _, v in ipairs(ents.FindByClass("crusader_dioxis_mine")) do
        local pos = v:GetPos()
        render.SetColorMaterial()
        render.DrawSphere(pos + Vector(0, 0, 5), 10, 16, 16, Color(0, 200, 100, 200))
        local ringPos = pos + Vector(0, 0, 2)
        render.DrawWireframeSphere(ringPos, v.ProximityRadius or 200, 20, 20, Color(0, 180, 90, 100))

        local textPos = pos + Vector(0, 0, 30)
        local textAng = (ply:EyePos() - textPos):Angle()
        textAng:RotateAroundAxis(textAng:Right(), 20)
        textAng:RotateAroundAxis(textAng:Up(), 90)
        textAng:RotateAroundAxis(textAng:Forward(), 150)

        cam.Start3D2D(textPos, textAng, 0.1)
            draw.SimpleText("DIOXIS", "DermaLarge", 0, 0, Color(0, 255, 128), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Radius: " .. (v.ProximityRadius or 200) .. "u", "DermaDefault", 0, 30, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end)
