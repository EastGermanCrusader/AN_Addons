-- eastgermancrusader_cff/lua/weapons/sw_kus_binocular/cl_init.lua
-- KUS Artillerie Binocular - Client

include("shared.lua")

DEFINE_BASECLASS("weapon_base")

local lastRequestTime = 0
local lastAV7Check = 0
local hasAV7Cached = false
local AV7_CHECK_INTERVAL = 2.0

local function HasUnmannedAV7OnField()
    if (CurTime() - lastAV7Check) < AV7_CHECK_INTERVAL then
        return hasAV7Cached
    end
    
    hasAV7Cached = false
    for _, ent in ipairs(ents.FindByClass("lvs_av7")) do
        if IsValid(ent) and not IsValid(ent:GetDriver()) then
            hasAV7Cached = true
            break
        end
    end
    
    lastAV7Check = CurTime()
    return hasAV7Cached
end

function SWEP:DrawViewModel() end

function SWEP:DrawWorldModel()
    if IsValid(self:GetOwner()) then
        local owner = self:GetOwner()
        local handID = owner:LookupAttachment("anim_attachment_rh")
        if handID then
            local attachment = owner:GetAttachment(handID)
            if attachment then
                local pos = attachment.Pos + attachment.Ang:Forward() * 3 + attachment.Ang:Right() * 2
                local ang = attachment.Ang
                ang:RotateAroundAxis(ang:Up(), 90)
                ang:RotateAroundAxis(ang:Forward(), 15)
                
                self:SetRenderOrigin(pos)
                self:SetRenderAngles(ang)
                self:DrawModel()
                self:SetRenderOrigin()
                self:SetRenderAngles()
                return
            end
        end
    end
    self:DrawModel()
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    if CLIENT then
        self:SendKUSArtilleryRequest()
    end
end

function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    self:ToggleIronSights()
    self:SetNextSecondaryFire(CurTime() + 0.3)
end

function SWEP:Think()
    if CLIENT then
        self:UpdateHUD()
        
        local owner = self:GetOwner()
        if IsValid(owner) and owner == LocalPlayer() then
            if input.IsKeyDown(KEY_F) and not self._lastFKeyState then
                self._lastFKeyState = true
                self:SendKUSArtilleryRequest()
            elseif not input.IsKeyDown(KEY_F) then
                self._lastFKeyState = false
            end
            
            if input.IsKeyDown(KEY_Z) and not self._lastZKeyState then
                self._lastZKeyState = true
                self:ToggleIronSights()
            elseif not input.IsKeyDown(KEY_Z) then
                self._lastZKeyState = false
            end
            
            local inIronSights = self.GetIronSights and self:GetIronSights() or self:GetNWBool("IronSights", false)
            
            if inIronSights then
                local baseFOV = owner:GetInfoNum("fov_desired", 75)
                owner:SetFOV(baseFOV / 15, 0.3)
            else
                owner:SetFOV(0, 0.3)
            end
        end
    end
    
    if BaseClass and BaseClass.Think then
        BaseClass.Think(self)
    end
end

function SWEP:ToggleIronSights()
    local owner = self:GetOwner()
    if IsValid(owner) and owner:IsPlayer() then
        if self.SetIronSights and self.GetIronSights then
            self:SetIronSights(not self:GetIronSights())
        else
            self:SetNWBool("IronSights", not self:GetNWBool("IronSights", false))
        end
    end
end

function SWEP:OnRemove()
    if CLIENT then
        local owner = self:GetOwner()
        if IsValid(owner) and owner == LocalPlayer() then
            owner:SetFOV(0, 0.3)
        end
    end
end

function SWEP:Holster()
    if CLIENT then
        local owner = self:GetOwner()
        if IsValid(owner) and owner == LocalPlayer() then
            owner:SetFOV(0, 0.3)
        end
    end
    return true
end

function SWEP:SendKUSArtilleryRequest()
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end
    
    if not HasUnmannedAV7OnField() then
        owner:ChatPrint("❌ Keine unbemannte AV-7 verfügbar!")
        return
    end
    
    local cfg = CFF_CONFIG or {}
    local cooldown = cfg.RequestCooldown or 5
    
    if CurTime() - lastRequestTime < cooldown then
        owner:ChatPrint("⏳ Bitte warten...")
        return
    end
    
    -- KUS Command Center finden
    local commandCenter = nil
    local minDist = math.huge
    
    for _, ent in ipairs(ents.FindByClass("sw_kus_command_center")) do
        if IsValid(ent) and ent:GetIsActive() then
            local dist = owner:GetPos():Distance(ent:GetPos())
            if dist < minDist then
                minDist = dist
                commandCenter = ent
            end
        end
    end
    
    if not IsValid(commandCenter) then
        owner:ChatPrint("❌ Kein KUS Command Center gefunden!")
        return
    end
    
    local trace = owner:GetEyeTrace()
    local targetPos = trace.HitPos
    local requestId = "kus_req_" .. owner:SteamID64() .. "_" .. CurTime()
    
    net.Start("cff_kus_request")
    net.WriteEntity(commandCenter)
    net.WriteString(requestId)
    net.WriteEntity(owner)
    net.WriteVector(targetPos)
    net.WriteString("Artillerie")
    net.WriteBool(false)
    net.WriteInt(1, 8)
    net.SendToServer()
    
    lastRequestTime = CurTime()
    owner:ChatPrint("📡 KUS Anfrage gesendet! Ziel: " .. math.Round(targetPos.x) .. ", " .. math.Round(targetPos.y) .. ", " .. math.Round(targetPos.z))
end

function SWEP:UpdateHUD()
    local inIronSights = self.GetIronSights and self:GetIronSights() or self:GetNWBool("IronSights", false)
    if not inIronSights then return end
    
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    
    local trace = owner:GetEyeTrace()
    self.TargetDistance = owner:GetShootPos():Distance(trace.HitPos)
    self.TargetPosition = trace.HitPos
end

function SWEP:DrawHUD()
    local inIronSights = self.GetIronSights and self:GetIronSights() or self:GetNWBool("IronSights", false)
    if not inIronSights then return end
    
    local scrW, scrH = ScrW(), ScrH()
    local centerX, centerY = scrW / 2, scrH / 2
    
    surface.SetDrawColor(255, 100, 100, 255)
    surface.DrawLine(centerX - 20, centerY, centerX - 5, centerY)
    surface.DrawLine(centerX + 5, centerY, centerX + 20, centerY)
    surface.DrawLine(centerX, centerY - 20, centerX, centerY - 5)
    surface.DrawLine(centerX, centerY + 5, centerX, centerY + 20)
    
    if self.TargetDistance then
        draw.SimpleText("Distanz: " .. math.Round(self.TargetDistance) .. " Units", "DermaDefault", centerX, centerY + 40, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
    
    draw.SimpleText("LMB/F: Anfrage | RMB/Z: Zoom", "DermaDefault", centerX, scrH - 50, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    
    local cfg = CFF_CONFIG or {}
    local cooldown = cfg.RequestCooldown or 5
    
    if CurTime() - lastRequestTime < cooldown then
        local remaining = cooldown - (CurTime() - lastRequestTime)
        draw.SimpleText("Cooldown: " .. math.Round(remaining) .. "s", "DermaDefault", centerX, scrH - 30, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end

net.Receive("cff_kus_request_response", function()
    local requestId = net.ReadString()
    local accepted = net.ReadBool()
    local targetPos = net.ReadVector()
    
    local owner = LocalPlayer()
    if not IsValid(owner) then return end
    
    if accepted then
        owner:ChatPrint("✓ KUS ANGENOMMEN! Ziel: " .. math.Round(targetPos.x) .. ", " .. math.Round(targetPos.y) .. ", " .. math.Round(targetPos.z))
    else
        owner:ChatPrint("✗ KUS ABGELEHNT.")
    end
end)
