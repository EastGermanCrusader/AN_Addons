--[[
    EGC Shield Sector - Client
    mesh.Begin-Darstellung des Poly-Shields (Low-Poly-Schildblase).
]]

include("shared.lua")

function ENT:Draw()
    local meshes = EGC_SHIP and EGC_SHIP._sectorMeshes
    local tris = meshes and meshes[self:EntIndex()]
    local cfg = EGC_SHIP and EGC_SHIP.Config or {}
    local drawMesh = cfg.DrawShieldSectors

    if not drawMesh or not tris or #tris == 0 then return end

    local col = cfg.ShieldColor or Color(60, 150, 255, 80)
    local mat = Material("models/debug/debugwhite")
    if not mat or mat:IsError() then mat = Material("engine/white") end

    mesh.Begin(mat, MATERIAL_TRIANGLES, #tris)
    for _, tri in ipairs(tris) do
        if #tri >= 3 then
            mesh.Position(tri[1])
            mesh.Color(col.r, col.g, col.b, col.a)
            mesh.AdvanceVertex()
            mesh.Position(tri[2])
            mesh.Color(col.r, col.g, col.b, col.a)
            mesh.AdvanceVertex()
            mesh.Position(tri[3])
            mesh.Color(col.r, col.g, col.b, col.a)
            mesh.AdvanceVertex()
        end
    end
    mesh.End()
end
