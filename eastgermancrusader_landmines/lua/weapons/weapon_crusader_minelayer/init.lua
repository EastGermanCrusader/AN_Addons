AddCSLuaFile("shared.lua")
include("shared.lua")

local function _cfgOk()
    return EGC_Base and EGC_Base.UpdateGlobalTimerSettings and EGC_Base.UpdateGlobalTimerSettings()
end

-- Synchronisiere MineType beim Equip
function SWEP:Equip(newOwner)
    if CLIENT then return end
    
    if IsValid(newOwner) and newOwner:IsPlayer() then
        timer.Simple(0.1, function()
            if IsValid(self) and IsValid(newOwner) then
                if not self.MineType then
                    self.MineType = 1
                end
                net.Start("CrusaderMineTypeUpdate")
                    net.WriteEntity(self)
                    net.WriteInt(self.MineType, 4)
                net.Send(newOwner)
            end
        end)
    end
end

function SWEP:PrimaryAttack()
    if CLIENT then return end
    if not _cfgOk() then return end
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    
    -- Initialisiere MineType falls nicht vorhanden
    if not self.MineType then
        self.MineType = 1
    end
    
    -- Unbegrenzte Reichweite
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 50000,
        filter = ply
    })
    
    if tr.Hit then
        -- Wähle Minentyp basierend auf self.MineType
        local mineClass, mineName
        if self.MineType == 1 then
            mineClass = "crusader_buried_mine"
            mineName = "Landmine"
        elseif self.MineType == 2 then
            mineClass = "crusader_spring_mine"
            mineName = "Spring-Splittermine"
        else
            mineClass = "crusader_dioxis_mine"
            mineName = "Dioxis-Mine"
        end
        
        local mine = ents.Create(mineClass)
        if IsValid(mine) then
            mine:SetPos(tr.HitPos + tr.HitNormal * 2)
            mine:SetAngles(Angle(0, 0, 0))
            mine:Spawn()
            mine:SetOwner(ply)
            
            self:EmitSound("weapons/slam/buttonclick.wav")
            ply:ChatPrint("[Crusader] " .. mineName .. " platziert! (" .. math.floor(tr.HitPos:Distance(ply:GetPos())) .. " Units)")
            
            self:SetNextPrimaryFire(CurTime() + 0.3)
        end
    else
        ply:ChatPrint("[Crusader] Keine gültige Oberfläche gefunden!")
    end
end

function SWEP:SecondaryAttack()
    if CLIENT then return end
    
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    
    -- Entferne alle Minen des Spielers (beide Typen)
    local count = 0
    
    -- Normale Minen
    for _, ent in pairs(ents.FindByClass("crusader_buried_mine")) do
        if ent:GetOwner() == ply then
            ent:Remove()
            count = count + 1
        end
    end
    
    -- Spring-Minen
    for _, ent in pairs(ents.FindByClass("crusader_spring_mine")) do
        if ent:GetOwner() == ply then
            ent:Remove()
            count = count + 1
        end
    end

    -- Dioxis-Minen
    for _, ent in pairs(ents.FindByClass("crusader_dioxis_mine")) do
        if ent:GetOwner() == ply then
            ent:Remove()
            count = count + 1
        end
    end
    
    if count > 0 then
        self:EmitSound("buttons/button15.wav")
        ply:ChatPrint("[Crusader] " .. count .. " Mine(n) entfernt!")
    else
        ply:ChatPrint("[Crusader] Keine Minen zum Entfernen gefunden!")
    end
    
    self:SetNextSecondaryFire(CurTime() + 1)
end

-- R-Taste: Wechsel zwischen Minenarten (mit Puffer - einmal R = einmal wechseln)
function SWEP:Think()
    if CLIENT then return end
    
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    
    -- Initialisiere Variablen falls nicht vorhanden
    if not self.MineType then
        self.MineType = 1
    end
    if not self.LastReloadKeyState then
        self.LastReloadKeyState = false
    end
    
    -- Prüfe ob R-Taste aktuell gedrückt ist
    local reloadKeyDown = ply:KeyDown(IN_RELOAD)
    
    -- Nur wechseln wenn Taste gerade gedrückt wurde (nicht beim Halten)
    -- Puffer: Wechsle nur wenn Taste von "nicht gedrückt" zu "gedrückt" wechselt
    if reloadKeyDown and not self.LastReloadKeyState then
        -- Wechsle zwischen Minenarten: 1 -> 2 -> 3 -> 1
        self.MineType = (self.MineType % 3) + 1

        local mineName = (self.MineType == 1) and "Landmine" or ((self.MineType == 2) and "Spring-Splittermine" or "Dioxis-Mine")
        
        self:EmitSound("buttons/blip1.wav")
        ply:ChatPrint("[Crusader] Minenart gewechselt: " .. mineName)
        
        -- Synchronisiere MineType mit Client
        net.Start("CrusaderMineTypeUpdate")
            net.WriteEntity(self)
            net.WriteInt(self.MineType, 4)
        net.Send(ply)
    end
    
    -- Speichere aktuellen Tastenstatus für nächsten Frame (Puffer)
    self.LastReloadKeyState = reloadKeyDown
    
    -- Wichtig: Think-Funktion muss aufgerufen werden
    self:NextThink(CurTime() + 0.05) -- Prüfe alle 0.05 Sekunden
    return true
end