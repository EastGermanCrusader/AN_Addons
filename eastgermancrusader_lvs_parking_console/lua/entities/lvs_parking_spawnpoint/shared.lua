--[[
    REPUBLIC LOGISTICS DATABASE
    FILE: SPAWNPOINT_SHARED.LUA
    ACCESS: COMMANDER LEVEL
    
    SYSTEM: LVS LANDING ZONE MARKER
]]--

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

-- Tech-Designation
ENT.PrintName = "GAR Lande-Signal"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminOnly = true

-- Militärisches Protokoll in der Beschreibung
ENT.Instructions = "Erfordert Holo-Scanner (Physgun) zur Visualisierung. C-Menü für Sektor-Kalibrierung."
ENT.Purpose = "Definiert Lande-Vektoren für republikanische LVS Einheiten."

-- Netzwerk-Protokolle (PermaProp Kompatibilität)
function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "SpawnPointName")
    
    if SERVER then
        -- Standard Sektor-Name
        self:SetSpawnPointName("LZ Alpha")
    end
end