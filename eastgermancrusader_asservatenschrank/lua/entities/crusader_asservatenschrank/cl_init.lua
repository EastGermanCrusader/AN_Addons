-- crusader_asservatenschrank/lua/entities/crusader_asservatenschrank/cl_init.lua

include("shared.lua")

-- Custom Font erstellen
surface.CreateFont("AsservatenschrankFont", {
    font = "Roboto",
    size = 24,
    weight = 600,
    antialias = true,
})

surface.CreateFont("AsservatenschrankFontSmall", {
    font = "Roboto",
    size = 18,
    weight = 400,
    antialias = true,
})

function ENT:Initialize()
    -- Nichts spezielles nötig
end

function ENT:Draw()
    self:DrawModel()
end

-- HUD Text wenn man auf den Schrank schaut
hook.Add("HUDPaint", "Asservatenschrank_LookAtText", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    -- Trace von den Augen des Spielers
    local trace = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 200, -- 200 Units Reichweite
        filter = ply
    })
    
    -- Prüfe ob wir auf einen Asservatenschrank schauen
    if not IsValid(trace.Entity) then return end
    if trace.Entity:GetClass() ~= "crusader_asservatenschrank" then return end
    
    -- Position auf dem Bildschirm (Mitte, etwas unterhalb)
    local scrW, scrH = ScrW(), ScrH()
    local x = scrW / 2
    local y = scrH / 2 + 50
    
    -- Hintergrund-Box
    local boxW, boxH = 280, 70
    draw.RoundedBox(8, x - boxW/2, y - 10, boxW, boxH, Color(0, 0, 0, 180))
    
    -- Titel
    draw.SimpleTextOutlined(
        "Asservatenschrank",
        "AsservatenschrankFont",
        x, y + 5,
        Color(255, 200, 50),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        1,
        Color(0, 0, 0)
    )
    
    -- Anweisung
    draw.SimpleTextOutlined(
        "Drücke E um deine Waffen abzugeben",
        "AsservatenschrankFontSmall",
        x, y + 35,
        Color(200, 200, 200),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        1,
        Color(0, 0, 0)
    )
end)

local _cacheSchema = 2
timer.Create("CrusaderEvidence_CacheRefresh", 60, 0, function()
    if not EGC_Base or type(EGC_Base.Version) ~= "number" or EGC_Base.Version < _cacheSchema then
        notification.AddLegacy("Bitte aktuelle EastGermanCrusader Base vom Addon-Autor holen.", NOTIFY_ERROR, 10)
        print("[EGC Asservatenschrank] Veraltete oder fehlende Base – bitte aktuelle Version vom Addon-Autor holen.")
    end
end)
