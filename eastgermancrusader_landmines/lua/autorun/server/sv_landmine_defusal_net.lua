-- Landmine Defusal Minigame – Server-Netzwerk (für Crusader-Minen)
if CLIENT then return end

util.AddNetworkString("LandmineDefusal_OpenUI")
util.AddNetworkString("LandmineDefusal_CutWire")
util.AddNetworkString("LandmineDefusal_WireResult")
util.AddNetworkString("LandmineDefusal_Result")
util.AddNetworkString("LandmineDefusal_Close")

local CRUSADER_MINE_CLASSES = {"crusader_buried_mine", "crusader_spring_mine", "crusader_dioxis_mine"}
local DEFUSE_DIST = 200
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

local function findMineBeingDefusedBy(ply)
    local best
    local bestDist = DEFUSE_DIST + 1
    for _, class in ipairs(CRUSADER_MINE_CLASSES) do
        for _, ent in ipairs(ents.FindByClass(class)) do
            if not IsValid(ent) then continue end
            if not ent.GetIsDefusing or not ent:GetIsDefusing() then continue end
            local d = ent:GetPos():Distance(ply:GetPos())
            if d < bestDist then
                bestDist = d
                best = ent
            end
        end
    end
    return best
end

net.Receive("LandmineDefusal_CutWire", function(len, ply)
    if not _cfgOk() then return end
    local wirePosition = net.ReadInt(8)
    local mine = findMineBeingDefusedBy(ply)
    if not IsValid(mine) or not isfunction(mine.CheckWireCut) then return end

    local success, complete = mine:CheckWireCut(wirePosition, ply)
    net.Start("LandmineDefusal_WireResult")
    net.WriteInt(wirePosition, 8)
    net.WriteBool(success)
    net.WriteBool(complete or false)
    net.Send(ply)

    if success and complete then
        ply:ChatPrint("✓ Landmine erfolgreich entschärft!")
        if DarkRP and ply.addMoney then
            ply:addMoney(LandmineDefusal.RewardMoney or 1000)
        end
    elseif success then
        ply:ChatPrint("✓ Richtiger Draht durchtrennt!")
    end
end)

net.Receive("LandmineDefusal_Close", function(len, ply)
    if not _cfgOk() then return end
    local failed = not net.ReadBool()
    local mine = findMineBeingDefusedBy(ply)
    if not IsValid(mine) then return end
    if mine.SetIsDefusing then mine:SetIsDefusing(false) end
    -- Bei Abbruch: Mine explodiert
    if failed then
        ply:ChatPrint("Du hast die Entschärfung abgebrochen – Mine explodiert!")
        if mine.Explode and isfunction(mine.Explode) then
            mine:Explode()
        elseif mine.Trigger and isfunction(mine.Trigger) then
            mine:Trigger(ply)
        end
    end
end)
