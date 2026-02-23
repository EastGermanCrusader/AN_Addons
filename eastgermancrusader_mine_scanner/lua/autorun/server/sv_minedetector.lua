if CLIENT then return end
if not _LVS_NodeOK then return end

util.AddNetworkString("MineDetector_Toggle")
util.AddNetworkString("MineDetector_Update")
util.AddNetworkString("MineDetector_AdminCommand")
util.AddNetworkString("MineDetector_UpdateEntities")
util.AddNetworkString("MineDetector_Request")
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

local dataFile = "mine_detector/entities.json"

-- Load data
local function LoadMineDetectorEntities()
    local json = file.Read(dataFile, "DATA")

    if not json or json == "" then
        return {
            -- HL2 Mines
            ["npc_tripmine"] = true,
            ["ent_mine"] = true,
            ["custom_mine"] = true,
            ["combine_mine"] = true,
            
            -- Slam
            ["npc_satchel"] = true,
            
            -- Detpack
            ["cod-c4"] = true,

            -- HBOMBS
            ["hb_main_500lb"] = true,
            ["hb_main_blu82"] = true,
            ["hb_main_clusterbomb"] = true,
            ["hb_misc_combinebomb"] = true,
            ["hb_main_fab"] = true,
            ["hb_main_fusionbomb"] = true,
            ["hb_main_gasleakbomb"] = true,
            ["hb_main_thermobaric"] = true,
            ["hb_main_implosionbomb"] = true,
            ["hb_main_bigjdam"] = true,
            ["hb_main_napalm"] = true,
            ["hb_main_moab"] = true,
            ["hb_misc_volcano"] = true,
            ["hb_emp"] = true,
            ["hb_nuclear_propellant"] = true,
            ["hb_nuclear_castlebravo"] = true,
            ["hb_nuclear_castlebravo_noflash"] = true,
            ["hb_nuclear_clusternuke"] = true,
            ["hb_nuclear_davycrockett"] = true,
            ["hb_nuclear_davycrockett_noflash"] = true,
            ["hb_nuclear_fatman"] = true,
            ["hb_nuclear_fatman_noflash"] = true,
            ["hb_nuclear_trinity"] = true,
            ["hb_nuclear_trinity_noflash"] = true,
            ["hb_nuclear_ionbomb"] = true,
            ["hb_nuclear_ivyking"] = true,
            ["hb_nuclear_ivyking_noflash"] = true,
            ["hb_nuclear_ivymike"] = true,
            ["hb_nuclear_ivymike_noflash"] = true,
            ["hb_nuclear_littleboy"] = true,
            ["hb_nuclear_littleboy_noflash"] = true,
            ["hb_nuclear_megatonbomb"] = true,
            ["hb_nuclear_megatonbomb_noflash"] = true,
            ["hb_nuclear_grable"] = true,
            ["hb_nuclear_grable_noflash"] = true,
            ["hb_nuclear_slownuke"] = true,
            ["hb_nuclear_slownuke_noflash"] = true,
            ["hb_sp_spacenuke"] = true,
            ["hb_nuclear_tsarbomba"] = true,
            ["hb_nuclear_tsarbomba_noflash"] = true,
            ["hb_proj_v2_small"] = true,

            -- [StarWars] Bomben
            ["developerbombe"] = true,
            ["gasbombe"] = true,
            ["gasbombe_mk2"] = true,
            ["grossebombe"] = true,
            ["grossebombe_mk2"] = true,
            ["kleinebombe"] = true,
            ["kleinebombe_mk2"] = true,
            ["megabombe"] = true,
            ["megabombe_mk2"] = true,
            ["mittlerebombe_mk2"] = true,
            ["mittlerebombe"] = true,
            ["trainingsbombe"] = true,
            ["trainingsbombe_mk2"] = true,

            -- Star Wars Mines
            ["ls_ap_mine"] = true,
            ["ls_vehicle_mine"] = true,

            -- Eternal's defusable bombs
            ["big_bomb"] = true,
            ["medium_bomb"] = true,
            ["mega_bomba"] = true,
            ["small_bomb"] = true,
            ["training_bomb"] = true,
            ["big_bomb_mkii"] = true,
            ["medium_bomb_mkii"] = true,
            ["small_bomb_mkii"] = true,
            ["training_bomb_mkii"] = true,

            -- Crusader Buried Mine (dein Addon)
            ["crusader_buried_mine"] = true,
            ["crusader_spring_mine"] = true,

            -- "joe Bomben
            ["joe_bomb"] = true,
            ["joe_train_bomb"] = true,
            -- Star Wars Minen
            ["arccw_k_nade_antitankmine"] = true,
        }
    end

    local tbl = util.JSONToTable(json)
    return tbl or {}
end

-- Initialisation
MineDetectorEntities = LoadMineDetectorEntities()

-- Save data
local function SaveMineDetectorEntities()
    file.CreateDir("mine_detector")
    file.Write(dataFile, util.TableToJSON(MineDetectorEntities, true))
end

-- Send detectable entities
local function SendMineDetectorEntities(ply)
    if not istable(MineDetectorEntities) then return end

    local count = table.Count(MineDetectorEntities)
    net.Start("MineDetector_UpdateEntities")
    net.WriteUInt(count, 8)
    for class, _ in pairs(MineDetectorEntities) do
        net.WriteString(class)
    end

    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

-- Admin commands
local function CheckAdminRights(ply)
    if not IsValid(ply) or not ply:IsAdmin() then
        if IsValid(ply) then
            ply:ChatPrint("[MineDetector] Permission denied.")
        end
        return false
    end
    return true 
end

local function HandleAdd(ply, class)
    if not CheckAdminRights(ply) then return end
    if not class or class == "" then
        ply:ChatPrint("[MineDetector] Usage : mine_detector_add <class_name>")
        return
    end

    if MineDetectorEntities[class] then
        ply:ChatPrint("[MineDetector] '" .. class .. "' already exists.")
    else
        MineDetectorEntities[class] = true
        SaveMineDetectorEntities()
        SendMineDetectorEntities()
        ply:ChatPrint("[MineDetector] '" .. class .. "' added.")
    end
end

local function HandleRemove(ply, class)
    if not CheckAdminRights(ply) then return end

    if not class or class == "" then
        ply:ChatPrint("[MineDetector] Usage : mine_detector_remove <class_name>")
        return
    end

    if MineDetectorEntities[class] then
        MineDetectorEntities[class] = nil
        SaveMineDetectorEntities()
        SendMineDetectorEntities()
        ply:ChatPrint("[MineDetector] '" .. class .. "' removed.")
    else
        ply:ChatPrint("[MineDetector] '" .. class .. "' not found.")
    end
end

local function HandleList(ply)
    if not CheckAdminRights(ply) then return end

    ply:ChatPrint("[MineDetector] Detectable entities :")
        for k, _ in pairs(MineDetectorEntities) do
            ply:ChatPrint(" - " .. k)
    end
end

concommand.Add("mine_detector_add", function(ply, cmd, args)
    HandleAdd(ply, args[1])
end)

concommand.Add("mine_detector_remove", function(ply, cmd, args)
    HandleRemove(ply, args[1])
end)

concommand.Add("mine_detector_list", function(ply, cmd, args)
    HandleList(ply)
end)

-- Check if player has the mine detector
local function PlayerHasMineDetectorSWEP(ply)
    return IsValid(ply:GetWeapon("weapon_sh_detector"))
end

-- Send detectable entities to client
hook.Add("PlayerInitialSpawn", "MineDetector_SendEntities", function(ply)
    if not _cfgOk() then return end
    timer.Simple(1, function()
        if IsValid(ply) then
            SendMineDetectorEntities(ply)
        end
    end)
end)

-- Send all detected entities in radius
local function GetNearbyMines(ply, radius)
    if not IsValid(ply) then return {} end

    -- 1024 is default value for client too
    radius = radius or 1024

    local pos = ply:GetPos()
    local mines = {}

    for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
        if IsValid(ent) and MineDetectorEntities[ent:GetClass()] then
            table.insert(mines, ent:GetPos())
        end
    end

    return mines
end

net.Receive("MineDetector_Request", function(_, ply)
    if not _cfgOk() then return end
    if not IsValid(ply) or not PlayerHasMineDetectorSWEP(ply) then return end
    
    local radius = net.ReadUInt(11)

    local mines = GetNearbyMines(ply, radius)

    net.Start("MineDetector_Update")
    net.WriteUInt(#mines, 8)
    for _, v in ipairs(mines) do
        net.WriteVector(v)
    end
    net.Send(ply)
end)