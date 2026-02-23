--[[
    EGC Ship Shield System - Client Autorun
    Initialisierung und globale Client-Hooks
]]

if not CLIENT then return end

EGC_SHIP = EGC_SHIP or {}
EGC_SHIP.Generators = EGC_SHIP.Generators or {}

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
end)

print("[EGC Ship Shield System] Client Autorun geladen")
