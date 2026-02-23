--[[
    REPUBLIC LOGISTICS COMMAND - TERMINAL INIT
    UNIT: VEHICLE REQUISITION CONSOLE (SERVER)
    CLEARANCE: GENERAL ACCESS
    
    PROTOCOL: LVS DEPLOYMENT SYSTEM
]]--

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Comm-Link Channels
util.AddNetworkString("LVS_Parking_OpenMenu")
util.AddNetworkString("LVS_Parking_SpawnVehicle")
util.AddNetworkString("LVS_Parking_UpdateConfig")
util.AddNetworkString("LVS_Parking_SyncSpawnPoints")
util.AddNetworkString("LVS_Parking_RequestConfig")
util.AddNetworkString("LVS_Parking_SendConfig")
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

function ENT:Initialize()
    self:SetModel("models/reizer_props/alysseum_project/console/security_console_01/security_console_01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
    
    -- Deployment Tracking: [SteamID] = {vehicle = Entity, class = string}
    self.SpawnedVehicles = {}
    
    -- System Konfiguration laden
    self.VehicleLimits = table.Copy(self.DefaultVehicleLimits)
    
    -- Flotten-Manifest laden (Verzögert für Entity-Initialisierung)
    timer.Simple(0.1, function()
        if IsValid(self) then
            self:LoadAvailableVehicles()
        end
    end)
    
    -- Duplicator Support für PermaProp (Datenbank-Persistenz)
    self:SetupDuplicatorSupport()
end

function ENT:SetupDuplicatorSupport()
    duplicator.RegisterEntityModifier(self:GetClass(), "LVS_Parking_Data", function(ply, ent, data)
        if IsValid(ent) and ent.ApplyDuplicatorData then
            ent:ApplyDuplicatorData(data)
        end
    end)
end

function ENT:ApplyDuplicatorData(data)
    if data.ConsoleName then self:SetConsoleName(data.ConsoleName) end
    if data.MaxSpawned then self:SetMaxSpawned(data.MaxSpawned) end
    if data.VehicleLimits then self.VehicleLimits = data.VehicleLimits end
end

function ENT:PreEntityCopy()
    local data = {
        ConsoleName = self:GetConsoleName(),
        MaxSpawned = self:GetMaxSpawned(),
        VehicleLimits = self.VehicleLimits,
    }
    
    duplicator.StoreEntityModifier(self, "LVS_Parking_Data", data)
end

function ENT:PostEntityPaste(ply, ent, createdEntities)
    -- Protokoll abgeschlossen
end

function ENT:LoadAvailableVehicles()
    self.AvailableVehicles = {}
    
    -- [[ REPUBLIC FLEET MANIFEST ]]
    local allowedVehicles = {
        {class = "lvs_starfighter_arc170", name = "ARC-170 Starfighter", category = "Starfighter"},
        {class = "lvs_starfighter_vwing", name = "V-Wing", category = "Starfighter"},
        {class = "lvs_walker_atte", name = "AT-TE Walker", category = "Walker"},
        {class = "lvs_repulsorlift_dropship", name = "Republic Dropship", category = "Transport"},
        {class = "lvs_repulsorlift_rho_class", name = "Rho-Class Shuttle", category = "Transport"},
        {class = "lvs_fakehover_rho_cargo_container", name = "Rho Cargo Container", category = "Transport"},
        {class = "lvs_space_laat_arc", name = "LAAT/arc", category = "LAAT"},
        {class = "lvs_space_laat", name = "LAAT", category = "LAAT"},
        {class = "decs_loader", name = "Loader", category = "Logistik"},
        {class = "lvs_tx130_t", name = "TX-130 Saber Tank", category = "Panzer"},
        {class = "lvs_wheeldrive_loader", name = "Loader Automatischer Magnet nicht für SCHIFFE", category = "Logistik"},
    }
    
    for _, veh in ipairs(allowedVehicles) do
        self.AvailableVehicles[veh.class] = {
            name = veh.name,
            class = veh.class,
            category = veh.category
        }
        
        -- Standard-Limit setzen falls nicht vorhanden
        if not self.VehicleLimits[veh.class] then
            self.VehicleLimits[veh.class] = 2
        end
    end
    
    print("[LVS LOGISTICS] " .. table.Count(self.AvailableVehicles) .. " Einheiten im System registriert.")
end

-- Scan nach aktiven Landezonen (Spawn Points)
function ENT:GetAllSpawnPoints()
    local spawnPoints = {}
    
    for _, ent in ipairs(ents.FindByClass("lvs_parking_spawnpoint")) do
        if IsValid(ent) then
            table.insert(spawnPoints, {
                entity = ent,
                name = ent:GetSpawnPointName(),
                pos = ent:GetPos(),
                ang = ent:GetAngles()
            })
        end
    end
    
    return spawnPoints
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    -- [[ SECURITY CHECK ]]
    if not self:HasClearance(activator) then
        activator:EmitSound("buttons/combine_button_locked.wav")
        activator:ChatPrint("[SECURITY] ZUGRIFF VERWEIGERT: Unzureichende Sicherheitsfreigabe.")
        return
    end
    
    local steamID = activator:SteamID()
    
    -- Prüfen ob Trooper bereits ein Fahrzeug hat
    if self.SpawnedVehicles[steamID] and IsValid(self.SpawnedVehicles[steamID].vehicle) then
        self:DespawnVehicle(activator)
        activator:ChatPrint("[LOGISTICS] " .. self:GetConsoleName() .. ": Einheit erfolgreich in den Hangar rückgeführt.")
        return
    end
    
    -- Sektoren scannen
    local spawnPoints = self:GetAllSpawnPoints()
    local spawnPointData = {}
    for _, sp in ipairs(spawnPoints) do
        table.insert(spawnPointData, {
            entIndex = sp.entity:EntIndex(),
            name = sp.name
        })
    end
    
    -- Interface Uplink starten
    net.Start("LVS_Parking_OpenMenu")
        net.WriteEntity(self)
        net.WriteString(self:GetConsoleName())
        net.WriteTable(self.AvailableVehicles or {})
        net.WriteTable(self.VehicleLimits)
        net.WriteTable(self:GetCurrentCounts())
        net.WriteUInt(self:GetMaxSpawned(), 8)
        net.WriteUInt(self:GetTotalSpawned(), 8)
        net.WriteTable(spawnPointData)
    net.Send(activator)
end

function ENT:GetCurrentCounts()
    local counts = {}
    for steamID, data in pairs(self.SpawnedVehicles) do
        if IsValid(data.vehicle) then
            counts[data.class] = (counts[data.class] or 0) + 1
        end
    end
    return counts
end

function ENT:GetTotalSpawned()
    local count = 0
    for steamID, data in pairs(self.SpawnedVehicles) do
        if IsValid(data.vehicle) then
            count = count + 1
        end
    end
    return count
end

function ENT:CanSpawnVehicle(ply, vehicleClass)
    local steamID = ply:SteamID()
    
    -- Security Double Check
    if not self:HasClearance(ply) then
        return false, "SICHERHEITSVERLETZUNG: Zugriff verweigert."
    end
    
    if self.SpawnedVehicles[steamID] and IsValid(self.SpawnedVehicles[steamID].vehicle) then
        return false, "NEGATIV: Sie haben bereits eine aktive Einheit im Feld."
    end
    
    if self:GetTotalSpawned() >= self:GetMaxSpawned() then
        return false, "HANGAR STATUS: Maximale Kapazität erreicht. Warten auf Rückläufer."
    end
    
    local counts = self:GetCurrentCounts()
    local limit = self.VehicleLimits[vehicleClass] or 1
    if (counts[vehicleClass] or 0) >= limit then
        return false, "BEGRENZUNG: Maximale Anzahl dieses Typs bereits im Einsatz."
    end
    
    return true
end

function ENT:SpawnVehicle(ply, vehicleClass, spawnPointEnt)
    local canSpawn, reason = self:CanSpawnVehicle(ply, vehicleClass)
    if not canSpawn then
        ply:ChatPrint("[LOGISTICS] " .. self:GetConsoleName() .. ": " .. reason)
        return false
    end
    
    -- Prüfen ob die Entity-Klasse existiert
    if not scripted_ents.Get(vehicleClass) then
        ply:ChatPrint("[SYSTEM ERROR] " .. self:GetConsoleName() .. ": Bauplan '" .. vehicleClass .. "' nicht gefunden.")
        return false
    end
    
    -- Vektor-Berechnung
    local pos, ang
    if IsValid(spawnPointEnt) then
        pos = spawnPointEnt:GetPos() + Vector(0, 0, 20) -- Repulsor-Lift Offset
        ang = spawnPointEnt:GetAngles()
    else
        -- Fallback: Notfall-Deployment vor Konsole
        pos = self:GetPos() + self:GetForward() * 200 + self:GetUp() * 50
        ang = self:GetAngles()
    end
    
    local vehicle = ents.Create(vehicleClass)
    if not IsValid(vehicle) then
        ply:ChatPrint("[SYSTEM ERROR] " .. self:GetConsoleName() .. ": Replikationsfehler beim Erstellen der Einheit!")
        return false
    end
    
    vehicle:SetPos(pos)
    vehicle:SetAngles(ang)
    vehicle:Spawn()
    vehicle:Activate()
    
    -- DNA-Sperre / Besitzer Zuweisung
    vehicle.LVS_Parking_Owner = ply
    vehicle.LVS_Parking_OwnerSteamID = ply:SteamID()
    vehicle.LVS_Parking_Console = self
    
    -- CPPI Protokolle
    if vehicle.CPPISetOwner then
        vehicle:CPPISetOwner(ply)
    end
    
    -- Tracking Update
    self.SpawnedVehicles[ply:SteamID()] = {
        vehicle = vehicle,
        class = vehicleClass
    }
    
    local spawnName = IsValid(spawnPointEnt) and spawnPointEnt:GetSpawnPointName() or "Notfall-Sektor"
    ply:ChatPrint("[LOGISTICS] " .. self:GetConsoleName() .. ": Einheit bereitgestellt an Sektor '" .. spawnName .. "'. Guten Flug, SOLDAT.")
    
    return true
end

function ENT:DespawnVehicle(ply)
    local steamID = ply:SteamID()
    
    if not self.SpawnedVehicles[steamID] then return false end
    
    local data = self.SpawnedVehicles[steamID]
    if IsValid(data.vehicle) then
        -- Despawn Visualisierung
        local effectData = EffectData()
        effectData:SetOrigin(data.vehicle:GetPos())
        util.Effect("entity_remove", effectData)
        
        data.vehicle:Remove()
    end
    
    self.SpawnedVehicles[steamID] = nil
    return true
end

function ENT:OnRemove()
    -- Protokoll: Notabschaltung - Alle Einheiten zurückrufen
    for steamID, data in pairs(self.SpawnedVehicles) do
        if IsValid(data.vehicle) then
            data.vehicle:Remove()
        end
    end
end

-- Signalverlust (Disconnect): Einheit bergen
hook.Add("PlayerDisconnected", "LVS_Parking_PlayerDisconnect", function(ply)
    if not _cfgOk() then return end
    local steamID = ply:SteamID()
    
    for _, ent in ipairs(ents.FindByClass("lvs_parking_console")) do
        if ent.SpawnedVehicles and ent.SpawnedVehicles[steamID] then
            if IsValid(ent.SpawnedVehicles[steamID].vehicle) then
                ent.SpawnedVehicles[steamID].vehicle:Remove()
            end
            ent.SpawnedVehicles[steamID] = nil
        end
    end
end)

-- [[ NETZWERK EMPFÄNGER ]]

net.Receive("LVS_Parking_SpawnVehicle", function(len, ply)
    if not _cfgOk() then return end
    local console = net.ReadEntity()
    local vehicleClass = net.ReadString()
    local spawnPointIndex = net.ReadUInt(16)
    
    if not IsValid(console) or console:GetClass() ~= "lvs_parking_console" then return end
    
    local spawnPointEnt = Entity(spawnPointIndex)
    
    console:SpawnVehicle(ply, vehicleClass, spawnPointEnt)
end)

net.Receive("LVS_Parking_UpdateConfig", function(len, ply)
    if not ply:IsAdmin() then return end
    
    local console = net.ReadEntity()
    if not IsValid(console) or console:GetClass() ~= "lvs_parking_console" then return end
    
    local configType = net.ReadString()
    
    if configType == "name" then
        console:SetConsoleName(net.ReadString())
    elseif configType == "maxspawned" then
        console:SetMaxSpawned(net.ReadUInt(8))
    elseif configType == "vehiclelimit" then
        local vehicleClass = net.ReadString()
        local limit = net.ReadUInt(8)
        console.VehicleLimits[vehicleClass] = limit
    end
end)

-- Config-Anfrage (Kommando-Ebene)
net.Receive("LVS_Parking_RequestConfig", function(len, ply)
    if not _cfgOk() then return end
    if not ply:IsAdmin() then return end
    
    local console = net.ReadEntity()
    if not IsValid(console) or console:GetClass() ~= "lvs_parking_console" then return end
    
    -- Manifest Prüfung
    if not console.AvailableVehicles or table.Count(console.AvailableVehicles) == 0 then
        console:LoadAvailableVehicles()
    end
    
    net.Start("LVS_Parking_SendConfig")
        net.WriteEntity(console)
        net.WriteTable(console.AvailableVehicles or {})
        net.WriteTable(console.VehicleLimits or {})
    net.Send(ply)
end)