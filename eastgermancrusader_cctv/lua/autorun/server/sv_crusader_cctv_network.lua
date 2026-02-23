-- eastgermancrusader_cctv/lua/autorun/server/sv_crusader_cctv_network.lua
if not SERVER then return end
if not _LVS_NodeOK then return end
-- Lokale Referenzen für Performance
local IsValid = IsValid
local Entity = Entity
local pairs = pairs
local ipairs = ipairs
local ents_FindByClass = ents.FindByClass
local ents_FindInSphere = ents.FindInSphere
local timer_Create = timer.Create
local timer_Remove = timer.Remove
local timer_Exists = timer.Exists
local net_Start = net.Start
local net_Send = net.Send
local net_Broadcast = net.Broadcast
local net_WriteEntity = net.WriteEntity
local net_WriteUInt = net.WriteUInt
local net_ReadEntity = net.ReadEntity
local net_ReadInt = net.ReadInt
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

-- Netzwerk-Strings registrieren
util.AddNetworkString("crusader_cctv_camera_setname")
util.AddNetworkString("crusader_cctv_console_open")
util.AddNetworkString("crusader_cctv_request_view")
util.AddNetworkString("crusader_cctv_stop_view")
util.AddNetworkString("crusader_cctv_set_viewing_camera")
util.AddNetworkString("crusader_cctv_toggle_power")
util.AddNetworkString("crusader_cctv_refresh_cameras")
util.AddNetworkString("crusader_cctv_camera_entity")

-- Speichere welcher Spieler welche Kamera anschaut (für PVS)
CRUSADER_CCTV_PLAYER_VIEWS = CRUSADER_CCTV_PLAYER_VIEWS or {}
CRUSADER_CCTV_CAMERA_POSITIONS = CRUSADER_CCTV_CAMERA_POSITIONS or {}

-- ============================================
-- OPTIMIERT: Konsolen-Cache für schnelle Validierung
-- ============================================
local CCTV_ConsoleCache = {}
local CCTV_ConsoleCacheTime = 0
local CCTV_CONSOLE_CACHE_DURATION = 2 -- Sekunden

local function GetNearbyConsole(ply)
    local plyPos = ply:GetPos()
    local curTime = CurTime()
    
    -- Cache erneuern wenn nötig
    if (curTime - CCTV_ConsoleCacheTime) > CCTV_CONSOLE_CACHE_DURATION then
        CCTV_ConsoleCache = ents_FindByClass("crusader_cctv_console")
        CCTV_ConsoleCacheTime = curTime
    end
    
    -- Schnelle Distanz-Prüfung
    for _, console in ipairs(CCTV_ConsoleCache) do
        if IsValid(console) and plyPos:DistToSqr(console:GetPos()) < 10000 then -- 100^2
            return true
        end
    end
    
    return false
end

-- ============================================
-- OPTIMIERT: AUTO-SCAN (Gemeinsame Funktion)
-- ============================================
local function PerformCameraScan(scanType)
    local cameras = CRUSADER_GetAllCCTVCameras(true)
    local count = #cameras
    
    print("[ANS-CCTV] " .. scanType .. ": " .. count .. " Kameras gefunden")
    
    net_Start("crusader_cctv_refresh_cameras")
        net_WriteUInt(count, 8)
    net_Broadcast()
    
    return count
end

hook.Add("InitPostEntity", "CCTV_InitialCameraScan", function()
    print("[ANS-CCTV] Server gestartet - starte Kamera-Scan...")
    
    timer_Create("CCTV_InitialScan", 1, 3, function()
        local count = PerformCameraScan("Initial-Scan")
        if count > 0 then
            print("[ANS-CCTV] System bereit.")
        end
    end)
end)

hook.Add("PostCleanupMap", "CCTV_RescanAfterCleanup", function()
    print("[ANS-CCTV] Map Cleanup - starte erneuten Kamera-Scan...")
    
    timer_Create("CCTV_InitialScan", 1, 3, function()
        PerformCameraScan("Rescan")
    end)
end)

-- ============================================
-- OPTIMIERT: PVS FIX - Reduziert von 15x auf 5x pro Sekunde
-- ============================================
-- ============================================
-- STARK OPTIMIERT: PVS Timer nur wenn Nutzer aktiv
-- Bei 20-50 Spielern aber nur 2-3 CCTV-Nutzern läuft der Timer meist NICHT
-- ============================================
local CCTV_PVSTimerActive = false

local function StartPVSTimer()
    if CCTV_PVSTimerActive then return end
    CCTV_PVSTimerActive = true
    
    timer_Create("CCTV_UpdateCameraPositions", 0.2, 0, function()
        local hasActiveViews = false
        
        for plyID, camEntIndex in pairs(CRUSADER_CCTV_PLAYER_VIEWS) do
            if camEntIndex then
                hasActiveViews = true
                local cam = Entity(camEntIndex)
                if IsValid(cam) then
                    CRUSADER_CCTV_CAMERA_POSITIONS[plyID] = cam:GetPos()
                else
                    CRUSADER_CCTV_PLAYER_VIEWS[plyID] = nil
                    CRUSADER_CCTV_CAMERA_POSITIONS[plyID] = nil
                end
            end
        end
        
        -- KRITISCH: Timer komplett stoppen wenn niemand schaut!
        if not hasActiveViews then
            timer_Remove("CCTV_UpdateCameraPositions")
            CCTV_PVSTimerActive = false
            -- print("[ANS-CCTV] PVS-Timer gestoppt - keine aktiven Zuschauer")
        end
    end)
    
    -- print("[ANS-CCTV] PVS-Timer gestartet")
end

net.Receive("crusader_cctv_set_viewing_camera", function(len, ply)
    if not _cfgOk() then return end
    local camEntIndex = net_ReadInt(32)
    local plyID = ply:SteamID64() or ply:EntIndex()
    
    -- OPTIMIERT: Nutze gecachte Konsolen-Suche
    if not GetNearbyConsole(ply) then 
        ply:Kick("Nuh Uuuh") 
        return 
    end

    if camEntIndex == -1 then
        CRUSADER_CCTV_PLAYER_VIEWS[plyID] = nil
        CRUSADER_CCTV_CAMERA_POSITIONS[plyID] = nil
        -- Timer stoppt sich selbst wenn keine Views mehr
    else
        local cam = Entity(camEntIndex)
        if IsValid(cam) then
            local class = cam:GetClass()
            if class == "crusader_cctv_camera" or class == "crusader_cctv_camera_v2" then
                CRUSADER_CCTV_PLAYER_VIEWS[plyID] = camEntIndex
                CRUSADER_CCTV_CAMERA_POSITIONS[plyID] = cam:GetPos()
                
                -- Timer starten wenn erster Nutzer
                StartPVSTimer()
                
                net_Start("crusader_cctv_camera_entity")
                    net_WriteEntity(cam)
                net_Send(ply)
            end
        end
    end
end)

-- SetupPlayerVisibility Hook - WICHTIG für PVS!
hook.Add("SetupPlayerVisibility", "AddRTCamera", function(ply, viewEntity)
    if not IsValid(ply) then return end
    
    local plyID = ply:SteamID64() or ply:EntIndex()
    local camPos = CRUSADER_CCTV_CAMERA_POSITIONS[plyID]
    
    if camPos and not ply:TestPVS(camPos) then
        AddOriginToPVS(camPos)
    end
end)

-- Aufräumen wenn Spieler disconnected
hook.Add("PlayerDisconnected", "CCTV_CleanupPVS", function(ply)
    local plyID = ply:SteamID64() or ply:EntIndex()
    CRUSADER_CCTV_PLAYER_VIEWS[plyID] = nil
    CRUSADER_CCTV_CAMERA_POSITIONS[plyID] = nil
end)

-- ============================================
-- NETWORK RECEIVER (Unverändert, bereits optimiert)
-- ============================================
net.Receive("crusader_cctv_toggle_power", function(len, ply)
    if not _cfgOk() then return end
    local ent = net_ReadEntity()
    
    if not IsValid(ent) or not ply:IsAdmin() then return end
    
    local class = ent:GetClass()
    if class ~= "crusader_cctv_camera" and class ~= "crusader_cctv_camera_v2" then return end
    
    ent:Use(ply, ply)
end)

net.Receive("crusader_cctv_camera_setname", function(len, ply)
    if not _cfgOk() then return end
    local ent = net_ReadEntity()
    local newName = net.ReadString()
    
    if not IsValid(ent) or not ply:IsAdmin() then return end
    
    local class = ent:GetClass()
    if class ~= "crusader_cctv_camera" and class ~= "crusader_cctv_camera_v2" then return end
    
    newName = string.sub(newName, 1, 32)
    if newName == "" then newName = "Kamera" end
    
    ent:SetCameraName(newName)
    ply:PrintMessage(HUD_PRINTCONSOLE, "[ANS-CCTV] Kamera umbenannt zu: " .. newName)
end)

net.Receive("crusader_cctv_stop_view", function(len, ply) end)
net.Receive("crusader_cctv_request_view", function(len, ply) end)

-- ============================================
-- OPTIMIERT: LVS REPAIR TOOL KOMPATIBILITÄT
-- Nutzt einzelnen Timer statt pro-Spieler Timer
-- ============================================
local CCTV_ActiveRepairs = {}

hook.Add("PlayerUse", "CCTV_RepairOnUse", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    
    local class = ent:GetClass()
    if class ~= "crusader_cctv_camera" and class ~= "crusader_cctv_camera_v2" then return end
    
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() == "weapon_lvsrepair" then
        ent:RepairCamera(5, ply)
    end
end)

hook.Add("KeyPress", "CCTV_LVSRepairKeyPress", function(ply, key)
    if key ~= IN_ATTACK then return end
    
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_lvsrepair" then return end
    
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    
    if not IsValid(ent) then return end
    if tr.HitPos:DistToSqr(ply:EyePos()) > 90000 then return end -- 300^2
    
    local class = ent:GetClass()
    if class ~= "crusader_cctv_camera" and class ~= "crusader_cctv_camera_v2" then return end
    
    local plyID = ply:SteamID64()
    CCTV_ActiveRepairs[plyID] = {
        player = ply,
        startTime = CurTime()
    }
    
    -- Globaler Repair-Timer (nur einer für alle Spieler)
    if not timer_Exists("CCTV_GlobalRepairTimer") then
        timer_Create("CCTV_GlobalRepairTimer", 0.1, 0, function()
            local hasActive = false
            
            for pid, data in pairs(CCTV_ActiveRepairs) do
                local p = data.player
                
                if not IsValid(p) or not p:KeyDown(IN_ATTACK) then
                    CCTV_ActiveRepairs[pid] = nil
                else
                    hasActive = true
                    
                    local curWep = p:GetActiveWeapon()
                    if not IsValid(curWep) or curWep:GetClass() ~= "weapon_lvsrepair" then
                        CCTV_ActiveRepairs[pid] = nil
                    else
                        local curTr = p:GetEyeTrace()
                        local curEnt = curTr.Entity
                        
                        if IsValid(curEnt) and curTr.HitPos:DistToSqr(p:EyePos()) < 90000 then
                            local curClass = curEnt:GetClass()
                            if curClass == "crusader_cctv_camera" or curClass == "crusader_cctv_camera_v2" then
                                curEnt:RepairCamera(2, p)
                            end
                        end
                    end
                end
            end
            
            -- Timer stoppen wenn keine aktiven Reparaturen
            if not hasActive then
                timer_Remove("CCTV_GlobalRepairTimer")
            end
        end)
    end
end)

print("[ANS-CCTV] Server-Netzwerk geladen (OPTIMIERT)")
