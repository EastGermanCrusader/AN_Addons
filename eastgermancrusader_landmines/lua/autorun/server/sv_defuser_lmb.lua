-- Entschärfen per Rechtsklick: Mit STRG gedrückt langsam zur Mine, dann Rechtsklick mit defuser_bomb
local DEFUSER_CLASS = "defuser_bomb"
local SLOW_WALK_SPEED = 100
local DEFUSE_TRACE_DIST = 150
local MINE_CLASSES = {
    ["crusader_buried_mine"] = true,
    ["crusader_spring_mine"] = true,
    ["crusader_dioxis_mine"] = true,
}

local lastKeys = {}
local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

hook.Add("Think", "CrusaderDefuserLMB", function()
    if not _cfgOk() then return end
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= DEFUSER_CLASS then
            lastKeys[ply:EntIndex()] = nil
            continue
        end

        local lmbDown = ply:KeyDown(IN_ATTACK)
        local rmbDown = ply:KeyDown(IN_ATTACK2)
        local last = lastKeys[ply:EntIndex()] or {}
        local justLMB = lmbDown and not last.lmb
        local justRMB = rmbDown and not last.rmb
        local justPressed = justLMB or justRMB
        lastKeys[ply:EntIndex()] = { lmb = lmbDown, rmb = rmbDown }

        if not justPressed then continue end

        -- Nur entschärfen wenn: STRG (Duck) und langsam bewegen
        if not ply:KeyDown(IN_DUCK) then continue end
        local vel = ply:GetVelocity():Length2D()
        if vel > SLOW_WALK_SPEED and not ply:KeyDown(IN_WALK) then continue end

        local startPos = ply:EyePos()
        local aimVec = ply:GetAimVector()
        local endPos = startPos + aimVec * DEFUSE_TRACE_DIST

        local tr = util.TraceLine({
            start = startPos,
            endpos = endPos,
            filter = ply,
        })

        local ent = tr.Entity
        if not IsValid(ent) or not MINE_CLASSES[ent:GetClass()] then continue end
        if not ent.Armed then continue end
        if isfunction(ent.StartDefusalMinigame) then
            ent:StartDefusalMinigame(ply)
        elseif isfunction(ent.Defuse) then
            ent:Defuse(ply)
        end
    end
end)
