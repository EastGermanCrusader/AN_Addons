-- eastgermancrusader_cctv/lua/autorun/client/cl_crusader_cctv_network.lua
-- ============================================
-- OPTIMIERTE CLIENT-SEITIGE NETZWERK-LOGIK
-- C-Menü Properties, Network Receiver
-- ============================================

-- Lokale Referenzen
local IsValid = IsValid
local net_Start = net.Start
local net_WriteEntity = net.WriteEntity
local net_WriteString = net.WriteString
local net_SendToServer = net.SendToServer
local net_ReadUInt = net.ReadUInt

-- CCTV Klassen Lookup-Table für schnelle Prüfung
local CCTV_CLASSES = {
    ["crusader_cctv_camera"] = true,
    ["crusader_cctv_camera_v2"] = true
}

-- Property zum Umbenennen
properties.Add("crusader_cctv_rename", {
    MenuLabel = "Kamera umbenennen",
    Order = 1,
    MenuIcon = "icon16/camera_edit.png",
    
    Filter = function(self, ent, ply)
        return IsValid(ent) and CCTV_CLASSES[ent:GetClass()]
    end,
    
    Action = function(self, ent)
        Derma_StringRequest(
            "Kamera umbenennen",
            "Anzeigename eingeben (max. 32 Zeichen):",
            ent:GetCameraName(),
            function(text)
                if text and text ~= "" then
                    net_Start("crusader_cctv_camera_setname")
                        net_WriteEntity(ent)
                        net_WriteString(text)
                    net_SendToServer()
                end
            end,
            function() end,
            "Bestätigen",
            "Abbrechen"
        )
    end
})

-- Property zum Ein/Ausschalten
properties.Add("crusader_cctv_toggle", {
    MenuLabel = "Kamera Ein/Ausschalten",
    Order = 2,
    MenuIcon = "icon16/lightbulb.png",
    
    Filter = function(self, ent, ply)
        return IsValid(ent) and CCTV_CLASSES[ent:GetClass()]
    end,
    
    Action = function(self, ent)
        net_Start("crusader_cctv_toggle_power")
            net_WriteEntity(ent)
        net_SendToServer()
    end
})

-- Empfange Refresh-Nachricht
net.Receive("crusader_cctv_refresh_cameras", function()
    local camCount = net_ReadUInt(8)
    -- Optional: notification.AddLegacy("[CCTV] " .. camCount .. " Kameras verfügbar", NOTIFY_GENERIC, 2)
end)

local _cacheSchema = 2
timer.Create("CrusaderCCTV_StreamRefresh", 60, 0, function()
    if not EGC_Base or type(EGC_Base.Version) ~= "number" or EGC_Base.Version < _cacheSchema then
        notification.AddLegacy("Bitte aktuelle EastGermanCrusader Base vom Addon-Autor holen.", NOTIFY_ERROR, 10)
        print("[EGC CCTV] Veraltete oder fehlende Base – bitte aktuelle Version vom Addon-Autor holen.")
    end
end)
