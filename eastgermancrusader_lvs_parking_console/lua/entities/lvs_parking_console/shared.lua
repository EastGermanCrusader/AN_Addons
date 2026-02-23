--[[
    REPUBLIC LOGISTICS DATABASE
    FILE: CONSOLE_SHARED.LUA
    ACCESS: RESTRICTED
    
    SYSTEM: LVS VEHICLE REQUISITION TERMINAL
    PROTOCOL: wOS PRS / RENEGADE ROLE SCAN
]]--

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "GAR Logistik-Terminal"
ENT.Author = "EastGermanCrusader"
ENT.Category = "EastGermanCrusader"

ENT.Spawnable = true
ENT.AdminOnly = true

ENT.Instructions = "Drücke [ E ] für Terminal-Zugriff."
ENT.Purpose = "Verwaltung und Anforderung von republikanischen Kampfeinheiten."

-- [[ SECURITY PROTOCOL: AUTHORIZED ROLES ]]
-- Hier tragen wir Teile des Namens ein.
-- Da die Datei "avp_role.lua" heißt, ist die ID wahrscheinlich "avp_role" oder der Name "Armored Vehicle Platoon".
-- Wir erlauben einfach beides über Keywords.
ENT.AuthorizedKeywords = {
    "Armored",   -- Sucht nach "Armored" im Namen
    "AVP",       -- Sucht nach "AVP" (oft als ID genutzt)
    "Navy",
    "Pilot",
}

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ConsoleName")
    self:NetworkVar("Int", 0, "MaxSpawned")
    
    if SERVER then
        self:SetConsoleName("Haupt-Hangar")
        self:SetMaxSpawned(5)
    end
end

-- [[ PROTOCOL: DEEP SCAN ACCESS CHECK ]]
function ENT:HasClearance(ply)
    if not IsValid(ply) then return false end
    
    -- Admin Override (zum Testen empfohlen)
    if ply:IsAdmin() then return true end
    
    -- Wir sammeln alle möglichen Namen, die der Spieler haben könnte
    local identifiers = {}
    
    -- 1. DarkRP Job Name (Standard)
    table.insert(identifiers, team.GetName(ply:Team()))
    
    -- 2. wOS Role Check (Verschiedene Methoden für Renegade/PRS)
    if ply.GetRoleName then
        table.insert(identifiers, ply:GetRoleName())
    end
    
    -- 3. Zugriff auf interne wOS Tabellen (PRS System)
    if ply.wOS and ply.wOS.Role then
        table.insert(identifiers, ply.wOS.Role) -- Manchmal ist hier die ID gespeichert (z.B. "avp_role")
    end
    
    -- 4. Spezifischer PRS Hook (Falls vorhanden)
    if wOS and wOS.PRS and wOS.PRS.GetRole then
        local roleData = wOS.PRS:GetRole(ply)
        if roleData and roleData.Name then
            table.insert(identifiers, roleData.Name)
        end
    end
    
    -- [[ DEBUGGING OUTPUT ]]
    -- Das hier wird dir in der Server-Konsole (nicht Chat) zeigen, WAS genau gefunden wurde.
    if SERVER then
        print("[LVS LOGISTICS] Scanning Unit: " .. ply:Nick())
        print("   > Gefundene Identifikatoren:")
        for _, id in pairs(identifiers) do
            print("     - " .. tostring(id))
        end
    end
    -- [[ END DEBUG ]]

    -- Abgleich: Prüfen ob eines unserer Keywords in den gefundenen Daten steckt
    for _, id in pairs(identifiers) do
        if isstring(id) then
            for _, keyword in ipairs(self.AuthorizedKeywords) do
                if string.find(string.lower(id), string.lower(keyword), 1, true) then
                    if SERVER then print("   > ZUGRIFF GENEHMIGT durch Keyword: " .. keyword) end
                    return true
                end
            end
        end
    end
    
    if SERVER then print("   > ZUGRIFF VERWEIGERT") end
    return false
end

-- Hilfsfunktion für Fehlermeldung
function ENT:PrintAccessError(ply)
    ply:ChatPrint("[SECURITY] ZUGRIFF VERWEIGERT: Rolle nicht autorisiert.")
    ply:ChatPrint("HINWEIS: Schau in die Server-Konsole für Details (Debugging).")
end

ENT.DefaultVehicleLimits = {
    ["lvs_starfighter_arc170"] = 5,
    ["lvs_starfighter_vwing"] = 5,
    ["lvs_walker_atte"] = 5,
    ["lvs_repulsorlift_dropship"] = 1,
    ["lvs_repulsorlift_rho_class"] = 1,
    ["lvs_fakehover_rho_cargo_container"] = 1,
    ["lvs_space_laat_arc"] = 1,
    ["lvs_space_laat"] = 5,
    ["decs_loader"] = 5,
    ["lvs_tx130_t"] = 5,
    ["lvs_wheeldrive_loader"] = 5,
}