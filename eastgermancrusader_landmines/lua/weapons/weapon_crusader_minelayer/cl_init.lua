include("shared.lua")

function SWEP:Initialize()
    if not self.MineType then
        self.MineType = 1
    end
end

-- Client-seitig: MineType wird vom Server synchronisiert
net.Receive("CrusaderMineTypeUpdate", function()
    local wep = net.ReadEntity()
    if IsValid(wep) then
        wep.MineType = net.ReadInt(4)
    end
end)

function SWEP:DrawHUD()
    local ply = LocalPlayer()
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 50000,
        filter = ply
    })
    
    -- Initialisiere MineType falls nicht vorhanden
    if not self.MineType then
        self.MineType = 1
    end
    
    local mineName = (self.MineType == 1) and "Landmine" or ((self.MineType == 2) and "Spring-Splittermine" or "Dioxis-Mine")
    
    if tr.Hit then
        local scrpos = tr.HitPos:ToScreen()
        local distance = math.floor(tr.HitPos:Distance(ply:GetPos()))
        
        draw.SimpleText(mineName .. " hier platzieren", "DermaDefault", scrpos.x, scrpos.y - 20, Color(0, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Entfernung: " .. distance .. " Units", "DermaDefault", scrpos.x, scrpos.y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Fadenkreuz
        surface.SetDrawColor(0, 255, 0, 200)
        surface.DrawLine(scrpos.x - 10, scrpos.y, scrpos.x + 10, scrpos.y)
        surface.DrawLine(scrpos.x, scrpos.y - 10, scrpos.x, scrpos.y + 10)
    end
    
    -- Zähle eigene Minen (beide Typen)
    local mineCount = 0
    for _, ent in pairs(ents.FindByClass("crusader_buried_mine")) do
        if ent:GetOwner() == ply then
            mineCount = mineCount + 1
        end
    end
    for _, ent in pairs(ents.FindByClass("crusader_spring_mine")) do
        if ent:GetOwner() == ply then
            mineCount = mineCount + 1
        end
    end
    for _, ent in pairs(ents.FindByClass("crusader_dioxis_mine")) do
        if ent:GetOwner() == ply then
            mineCount = mineCount + 1
        end
    end

    -- Anzeige unten rechts
    draw.SimpleText("Aktuelle Minenart: " .. mineName, "DermaDefault", ScrW() - 20, ScrH() - 100, Color(255, 200, 0), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("Platzierte Minen: " .. mineCount, "DermaLarge", ScrW() - 20, ScrH() - 75, Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("Rechtsklick: Alle Minen entfernen", "DermaDefault", ScrW() - 20, ScrH() - 50, Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText("R: Minenart wechseln", "DermaDefault", ScrW() - 20, ScrH() - 25, Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end