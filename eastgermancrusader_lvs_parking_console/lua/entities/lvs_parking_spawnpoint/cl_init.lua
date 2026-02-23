-- eastgermancrusader_base/lua/entities/lvs_parking_spawnpoint/cl_init.lua

include("shared.lua")

-- =================================================================
-- EINSTELLUNGEN (HIER KANNST DU FARBEN ÄNDERN)
-- =================================================================

-- Die Hauptfarbe für das Holo-Blau
local COLOR_REP_BLUE = Color(0, 180, 255)
-- Hintergrundfarbe der Admin-Box
local COLOR_REP_BG = Color(10, 30, 50, 220)
-- Helle Akzentfarbe (Türkis)
local COLOR_REP_ACCENT = Color(0, 255, 255)
-- Farbe des unsichtbaren Models (für Admins)
local COLOR_MODEL_GHOST = Color(0, 150, 255, 100)
-- Das Material für die Laser-Strahlen
local MAT_BEAM = Material("sprites/physbeama")

-- HIER EINSTELLEN: Wie weit man das Holo sehen kann (in Units)
-- 2500000 entspricht etwa einer mittleren Distanz. Größer = weiter sichtbar.
local VIEW_DISTANCE_SQR = 2500000 


function ENT:Initialize()
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetColor(Color(255, 255, 255, 0)) -- Model unsichtbar machen
end

local function IsHoldingPhysgun()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) then return false end
    return weapon:GetClass() == "weapon_physgun" or weapon:GetClass() == "gmod_tool"
end

-- =================================================================
-- TEIL 1: ADMIN INFO (Nur sichtbar mit Physgun in der Hand)
-- =================================================================
function ENT:Draw()
    if not IsHoldingPhysgun() then return end 
    
    self:SetColor(COLOR_MODEL_GHOST)
    self:DrawModel()
    
    local pos = self:GetPos() + Vector(0, 0, 45)
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
    
    cam.Start3D2D(pos, ang, 0.1)
        draw.SimpleText("ADMIN CONFIG", "DermaDefault", 0, 0, Color(255,100,100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

function ENT:DrawTranslucent()
    self:Draw()
end


-- =================================================================
-- TEIL 2: HOLO BODEN PROJEKTION (Für alle Spieler sichtbar)
-- =================================================================
hook.Add("PostDrawTranslucentRenderables", "LVS_SpawnPoint_FloorProjection", function()
    
    for _, ent in ipairs(ents.FindByClass("lvs_parking_spawnpoint")) do
        if not IsValid(ent) then continue end
        
        -- Distanz-Check (Performance)
        if LocalPlayer():GetPos():DistToSqr(ent:GetPos()) > VIEW_DISTANCE_SQR then continue end
        
        local pos = ent:GetPos()
        local ang = ent:GetAngles()
        local forward = ang:Forward()
        local right = ang:Right()
        local up = ang:Up()
        local time = CurTime()
        
        -- =========================================================
        -- A) DER TEXT AUF DEM BODEN (Flachliegend)
        -- =========================================================
        
        -- 1. Winkel berechnen
        -- Wir nehmen den Winkel des Entities (ang.y)
        local textAng = Angle(-90, ang.y, 0)
        
        -- !!! WICHTIG: HIER DREHST DU DEN TEXT !!!
        -- "RotateAroundAxis(Right, 0)" -> Text steht aufrecht
        -- "RotateAroundAxis(Right, -90)" -> Text liegt flach auf dem Rücken (Lesbar von oben)
        textAng:RotateAroundAxis(textAng:Right(), -90) 
        
        -- "RotateAroundAxis(Up, 90)" -> Text dreht sich um die eigene Achse (Ausrichtung Norden/Osten/etc)
        textAng:RotateAroundAxis(textAng:Up(), 90)

        -- Pulsierender Effekt (Helligkeit geht an und aus)
        local pulse = 150 + math.sin(time * 3) * 50
        local colText = Color(0, 180, 255, pulse)
        
        -- HIER EINSTELLEN: Größe des Textes (0.15 = Normal, 0.3 = Riesig)
        local scale = 0.50
        
        -- Start3D2D startet das Zeichnen
        -- "pos + up * 2" bedeutet: 2 Einheiten über dem Boden, damit es nicht flackert (Z-Fighting)
        cam.Start3D2D(pos + up * 2, textAng, scale)
            
            -- Der eigentliche Name (z.B. "LZ 1")
            draw.SimpleText(ent:GetSpawnPointName(), "DermaLarge", 0, 0, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Der Rahmen um den Text
            surface.SetDrawColor(0, 255, 255, 100) -- Farbe (Türkis, transparent)
            surface.DrawOutlinedRect(-150, -40, 300, 80, 2) -- x, y, breite, höhe, dicke
            
            -- Deko-Vierecke am Rahmen
            surface.DrawRect(-150, -40, 20, 5) -- Links Oben
            surface.DrawRect(130, 35, 20, 5)   -- Rechts Unten
            
            -- Kleiner Untertitel
            draw.SimpleText("GAR LOGISTICS SYSTEM", "DermaDefault", 0, -55, Color(0, 100, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
        cam.End3D2D()


        -- =========================================================
        -- B) DIE TECH-PFEILE (Lauflicht)
        -- =========================================================
        
        -- Admin-Box nur anzeigen wenn Physgun gehalten wird
        if IsHoldingPhysgun() then
            render.SetColorMaterial()
            local mins = Vector(-100, -50, 0)
            local maxs = Vector(200, 50, 5)
            render.DrawWireframeBox(pos, ang, mins, maxs, Color(0, 150, 255, 50), false)
        end
        
        render.SetMaterial(MAT_BEAM) 
        
        local startPos = pos + up * 2
        local segmentCount = 5  -- Anzahl der Pfeile
        local segmentDist = 40  -- Abstand zwischen den Pfeilen
        
        for i = 1, segmentCount do
            -- Lauflicht-Animation berechnen
            local wave = math.sin(time * 3 - (i * 0.7)) 
            local alphaBase = math.max(0, wave)
            
            if alphaBase <= 0.05 then continue end

            -- Position berechnen (+60 schiebt die Pfeile weiter nach vorne, weg vom Text)
            local cPos = startPos + forward * (i * segmentDist + 60) 
            
            -- Form des Pfeils definieren
            local pTip = cPos + forward * 15               -- Spitze
            local pLeft = cPos - right * 40 - forward * 5  -- Linker Flügel
            local pRight = cPos + right * 40 - forward * 5 -- Rechter Flügel
            
            -- Farben für die Strahlen
            local colGlow = Color(0, 100, 255, alphaBase * 100)  -- Äußerer Schein
            local colCore = Color(200, 255, 255, alphaBase * 255) -- Heller Kern
            
            -- Zeichnen der Strahlen (Breit und Schmal für Glow-Effekt)
            render.DrawBeam(pTip, pLeft, 12, 0, 1, colGlow)
            render.DrawBeam(pTip, pRight, 12, 0, 1, colGlow)
            
            render.DrawBeam(pTip, pLeft, 4, 0, 1, colCore)
            render.DrawBeam(pTip, pRight, 4, 0, 1, colCore)
        end
    end
end)

-- =================================================================
-- C-MENÜ CONFIG (Unverändert)
-- =================================================================
properties.Add("lvs_spawnpoint_config", {
    MenuLabel = "Spawn Punkt Einstellungen",
    Order = 1001,
    MenuIcon = "icon16/arrow_out.png",
    Filter = function(self, ent, ply)
        if not IsValid(ent) then return false end
        if ent:GetClass() ~= "lvs_parking_spawnpoint" then return false end
        if not ply:IsAdmin() then return false end
        return true
    end,
    Action = function(self, ent)
        LVS_SpawnPoint_OpenConfigMenu(ent)
    end
})

function LVS_SpawnPoint_OpenConfigMenu(spawnPoint)
    if not IsValid(spawnPoint) then return end
    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 120)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    
    frame.Paint = function(self, w, h)
        surface.SetDrawColor(5, 15, 25, 250)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(COLOR_REP_BLUE)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        surface.SetDrawColor(0, 50, 100, 150)
        surface.DrawRect(2, 2, w-4, 25)
        draw.SimpleText("SPAWN POINT CONFIGURATION", "DermaDefaultBold", 10, 14, COLOR_REP_BLUE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(370, 5)
    closeBtn:SetSize(25, 20)
    closeBtn:SetText("X")
    closeBtn:SetTextColor(Color(255,100,100))
    closeBtn.Paint = function() end
    closeBtn.DoClick = function() frame:Close() end
    
    local nameLabel = vgui.Create("DLabel", frame)
    nameLabel:SetPos(20, 40)
    nameLabel:SetText("DESIGNATION (NAME):")
    nameLabel:SetFont("DermaDefaultBold")
    nameLabel:SetTextColor(Color(0, 200, 255))
    nameLabel:SizeToContents()
    
    local nameEntry = vgui.Create("DTextEntry", frame)
    nameEntry:SetPos(20, 65)
    nameEntry:SetSize(360, 30)
    nameEntry:SetValue(spawnPoint:GetSpawnPointName())
    nameEntry:SetFont("DermaDefault")
    nameEntry:SetDrawLanguageID(false)
    
    nameEntry.Paint = function(self, w, h)
        surface.SetDrawColor(0, 20, 40, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(COLOR_REP_BLUE)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(Color(255, 255, 255), Color(0, 200, 255), Color(255, 255, 255))
    end
    
    nameEntry.OnEnter = function(self)
        net.Start("LVS_SpawnPoint_UpdateName")
            net.WriteEntity(spawnPoint)
            net.WriteString(self:GetValue())
        net.SendToServer()
        frame:Close()
        surface.PlaySound("buttons/button14.wav")
    end
end