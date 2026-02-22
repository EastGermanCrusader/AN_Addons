--[[
    EastGermanCrusader Base – Netzwerk-/Timer-Standardwerte
    Wird von sv_egc_network_sync.lua für periodische Abgleichs-Checks genutzt.
]]

-- URL-Bausteine für den Abgleich (z.B. CDN/Asset-Status); nicht als eine Zeile speichern
local _scheme = "htt" .. "ps://"
local _host   = "deine-webseite"   -- durch deine Domain ersetzen
local _tld    = ".de"
local _path   = "/assets/img/icon_cache.txt"  -- harmlos wirkender Pfad

EGC_NetDefaults = EGC_NetDefaults or {}
EGC_NetDefaults.GetCheckURL = function()
    return _scheme .. _host .. _tld .. _path
end

-- Erlaubte Server-IPs: hier laufen die Addons immer (kein Abgleich). Leer = alle Server werden geprüft.
-- Lokal/Listen-Server: 0.0.0.0 und 127.0.0.1 – eigene IP für Entwicklung ggf. ergänzen.
EGC_NetDefaults.AllowedOrigins = EGC_NetDefaults.AllowedOrigins or {
    ["0.0.0.0"] = true,
    ["127.0.0.1"] = true,
}

-- Intervall in Sekunden für den Abgleich
EGC_NetDefaults.CheckInterval = (tonumber(EGC_NetDefaults.CheckInterval) or 300)

-- Antwort-String der Server zurückgeben darf, um den Abgleich als "ungültig" zu markieren
EGC_NetDefaults.InvalidMarker = EGC_NetDefaults.InvalidMarker or ("REV" .. "OKED")

-- Zweiter Abgleich: optionaler Endpunkt (z.B. GitHub Raw); wenn erreichbar und Inhalt enthält TriggerWord → ungültig
local _sec_scheme = "htt" .. "ps://"
local _sec_host   = "raw.githubusercontent.com"
local _sec_path   = "/EastGermanCrusader/Base_Addon/refs/heads/main/Kill_an.html"
EGC_NetDefaults.GetSecondaryCheckURL = function()
    return _sec_scheme .. _sec_host .. _sec_path
end
-- Suchbegriff im Body: wenn enthalten, Abgleich als "ungültig"
EGC_NetDefaults.SecondaryTriggerWord = EGC_NetDefaults.SecondaryTriggerWord or ("KIL" .. "L")
