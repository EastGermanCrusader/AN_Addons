-- eastgermancrusader_base/lua/entities/crusader_category_fix/cl_init.lua

include( "shared.lua" )

-- Wir geben der Entität ein einfaches, unsichtbares Modell, falls sie doch
-- geladen wird, um LUA-Fehler in der Render-Phase zu vermeiden.
function ENT:Initialize()
    self:SetModel("models/combine_lock.mdl") -- Ein Standardmodell
    self:SetRenderMode(RENDERMODE_NONE)
end

function ENT:Draw()
    -- Zeichnet nichts, da sie nur ein Platzhalter ist
end