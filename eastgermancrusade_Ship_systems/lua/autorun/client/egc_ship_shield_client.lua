--[[
    EGC Ship Shield System - Client Autorun
    Initialisierung und globale Client-Hooks
]]

if not CLIENT then return end

EGC_SHIP = EGC_SHIP or {}
EGC_SHIP.Generators = EGC_SHIP.Generators or {}
EGC_SHIP._sectorMeshes = EGC_SHIP._sectorMeshes or {}  -- [entIndex] = { {v1,v2,v3}, ... }

net.Receive("EGC_Shield_SectorMesh", function()
    local entIndex = net.ReadUInt(16)
    local numTris = net.ReadUInt(16)
    local triangles = {}
    for i = 1, numTris do
        local v1 = net.ReadVector()
        local v2 = net.ReadVector()
        local v3 = net.ReadVector()
        table.insert(triangles, { v1, v2, v3 })
    end
    EGC_SHIP._sectorMeshes[entIndex] = triangles
end)

-- ============================================================================
-- INITIALISIERUNG
-- ============================================================================

hook.Add("InitPostEntity", "EGC_Shield_ClientInit", function()
    print("[EGC Ship Shield System] Client initialisiert")
    
    -- Sync anfordern
    timer.Simple(1, function()
        net.Start("EGC_Shield_RequestSync")
        net.SendToServer()
    end)
end)

-- ============================================================================
-- CLEANUP WENN GENERATOR ENTFERNT
-- ============================================================================

hook.Add("EntityRemoved", "EGC_Shield_CleanupGenerator", function(ent)
    if not IsValid(ent) then return end

    local entIndex = ent:EntIndex()
    if EGC_SHIP.Generators[entIndex] then
        EGC_SHIP.Generators[entIndex] = nil
    end
    if EGC_SHIP._sectorMeshes and EGC_SHIP._sectorMeshes[entIndex] then
        EGC_SHIP._sectorMeshes[entIndex] = nil
    end
end)

print("[EGC Ship Shield System] Client Autorun geladen")
