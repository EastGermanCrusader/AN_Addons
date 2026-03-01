include("shared.lua")

local DETECT_RANGE = 100
local DETECT_COS_HALF_ANGLE = math.cos(math.rad(22.5))

local EXPLOSIVE_CLASSES = {
    ["crusader_buried_mine"] = true,
    ["crusader_dioxis_mine"] = true,
    ["crusader_spring_mine"] = true,
    ["grenade_ar2"] = true,
    ["grenade_frag"] = true,
    ["npc_grenade_frag"] = true,
    ["prop_combine_ball"] = true,
    ["npc_handgrenade"] = true,
}

local function IsExplosiveEntity(ent)
    if not IsValid(ent) then return false end
    local c = ent:GetClass()
    if EXPLOSIVE_CLASSES[c] then return true end
    if c:match("^gb5_") or c:match("^hb_") then return true end
    return false
end

local function GetExplosivesInCone(eyePos, aimVec, range, cosHalfAngle)
    local list = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsExplosiveEntity(ent) then
            local pos = ent:GetPos()
            local dist = eyePos:Distance(pos)
            if dist <= range then
                local dir = (pos - eyePos):GetNormalized()
                if dir:Dot(aimVec) >= cosHalfAngle then
                    list[#list + 1] = ent
                end
            end
        end
    end
    return list
end

function SWEP:Initialize()
    self.DetectedExplosives = {}
    self.ScannerActive = false
end

function SWEP:GetViewModelPosition(pos, ang)
    pos = pos + ang:Right() * 35 + ang:Forward() * -5 - ang:Up() * 8
    return pos, ang
end

function SWEP:Think()
    if not CLIENT then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetActiveWeapon() ~= self then
        self.DetectedExplosives = {}
        self:NextThink(CurTime() + 0.1)
        return true
    end
    if not self.ScannerActive then
        self.DetectedExplosives = {}
        self:NextThink(CurTime() + 0.1)
        return true
    end
    local eyePos = ply:EyePos()
    local aimVec = ply:GetAimVector()
    self.DetectedExplosives = GetExplosivesInCone(eyePos, aimVec, DETECT_RANGE, DETECT_COS_HALF_ANGLE)
    self:NextThink(CurTime() + 0.05)
    return true
end
