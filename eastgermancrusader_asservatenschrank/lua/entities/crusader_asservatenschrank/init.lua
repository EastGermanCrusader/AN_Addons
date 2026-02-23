-- crusader_asservatenschrank/lua/entities/crusader_asservatenschrank/init.lua

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Globale Tabelle für gespeicherte Waffen pro Spieler
-- Format: CrusaderStoredWeapons[SteamID][EntityIndex] = { weapons = {...}, ammo = {...} }
if not CrusaderStoredWeapons then
    CrusaderStoredWeapons = {}
end
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

function ENT:Initialize()
    self:SetModel("models/lt_c/sci_fi/box_crate.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    local ply = activator
    local steamID = ply:SteamID()
    local entIndex = self:EntIndex()
    
    -- Initialisiere Tabellen falls nötig
    CrusaderStoredWeapons[steamID] = CrusaderStoredWeapons[steamID] or {}
    
    -- Prüfe ob der Spieler bereits Waffen in diesem Schrank hat
    if CrusaderStoredWeapons[steamID][entIndex] and #CrusaderStoredWeapons[steamID][entIndex].weapons > 0 then
        -- Waffen zurückgeben
        self:ReturnWeapons(ply, steamID, entIndex)
    else
        -- Waffen abgeben
        self:StoreWeapons(ply, steamID, entIndex)
    end
end

function ENT:StoreWeapons(ply, steamID, entIndex)
    local weapons = ply:GetWeapons()
    local storedWeapons = {}
    local storedAmmo = {}
    
    -- Speichere alle Munitionstypen
    for i = 1, 50 do
        local ammoCount = ply:GetAmmoCount(i)
        if ammoCount > 0 then
            storedAmmo[i] = ammoCount
        end
    end
    
    -- Durchgehe alle Waffen und speichere/entferne sie
    for _, wep in ipairs(weapons) do
        if IsValid(wep) then
            local weaponClass = wep:GetClass()
            
            -- Prüfe ob die Waffe erlaubt ist (nicht entfernt werden soll)
            if not self.AllowedWeapons[weaponClass] then
                -- Speichere Waffendaten
                local weaponData = {
                    class = weaponClass,
                    clip1 = wep:Clip1(),
                    clip2 = wep:Clip2(),
                }
                table.insert(storedWeapons, weaponData)
            end
        end
    end
    
    -- Entferne die Waffen (nach dem Speichern, um Konflikte zu vermeiden)
    for _, weaponData in ipairs(storedWeapons) do
        ply:StripWeapon(weaponData.class)
    end
    
    -- Entferne die Munition
    for ammoType, _ in pairs(storedAmmo) do
        ply:RemoveAmmo(ply:GetAmmoCount(ammoType), ammoType)
    end
    
    -- Speichere die Daten
    CrusaderStoredWeapons[steamID][entIndex] = {
        weapons = storedWeapons,
        ammo = storedAmmo
    }
    
    -- Wähle die Hände aus, falls vorhanden
    if ply:HasWeapon("mvp_perfecthands") then
        ply:SelectWeapon("mvp_perfecthands")
    end
    
    -- Sound abspielen
    self:EmitSound("doors/door_metal_medium_close1.wav", 75, 100)
    
end

function ENT:ReturnWeapons(ply, steamID, entIndex)
    local data = CrusaderStoredWeapons[steamID][entIndex]
    
    if not data then return end
    
    local weaponCount = 0
    
    -- Gib alle Waffen zurück
    for _, weaponData in ipairs(data.weapons) do
        local wep = ply:Give(weaponData.class, true) -- true = keine Munition
        if IsValid(wep) then
            -- Setze die Clip-Munition zurück
            if weaponData.clip1 and weaponData.clip1 >= 0 then
                wep:SetClip1(weaponData.clip1)
            end
            if weaponData.clip2 and weaponData.clip2 >= 0 then
                wep:SetClip2(weaponData.clip2)
            end
            weaponCount = weaponCount + 1
        end
    end
    
    -- Gib die Reserve-Munition zurück
    for ammoType, amount in pairs(data.ammo) do
        ply:GiveAmmo(amount, ammoType, true) -- true = kein Sound
    end
    
    -- Lösche die gespeicherten Daten
    CrusaderStoredWeapons[steamID][entIndex] = nil
    
    -- Sound abspielen
    self:EmitSound("doors/door_metal_medium_open1.wav", 75, 100)
end

-- Cleanup wenn Entity entfernt wird
function ENT:OnRemove()
    local entIndex = self:EntIndex()
    
    for steamID, schraenke in pairs(CrusaderStoredWeapons) do
        if schraenke[entIndex] then
            -- Finde den Spieler
            for _, ply in ipairs(player.GetAll()) do
                if ply:SteamID() == steamID then
                    self:ReturnWeapons(ply, steamID, entIndex)
                    break
                end
            end
        end
    end
end

-- Cleanup wenn Spieler den Server verlässt
hook.Add("PlayerDisconnected", "CrusaderAsservatenschrank_Cleanup", function(ply)
    if not _cfgOk() then return end
    local steamID = ply:SteamID()
    if CrusaderStoredWeapons[steamID] then
        CrusaderStoredWeapons[steamID] = nil
    end
end)
