-- eastgermancrusader_cff/lua/autorun/sh_cff_init.lua
-- Call For Fire (Artillerie) System - Initialisierung
-- Optimiert für Mehrspieler (20-50 Spieler)

local ADDON_NAME = "[CFF Artillerie]"

print(ADDON_NAME .. " Addon wird geladen...")

-- ============================================================================
-- NETZWERK-STRINGS (Server)
-- ============================================================================
if SERVER then
    util.AddNetworkString("cff_artillery_request")
    util.AddNetworkString("cff_artillery_request_response")
    util.AddNetworkString("cff_artillery_open_menu")
    util.AddNetworkString("cff_artillery_close_menu")
    util.AddNetworkString("cff_artillery_respond_request")
    util.AddNetworkString("cff_artillery_toggle_flak")
    util.AddNetworkString("cff_artillery_set_flak_height")
end

-- ============================================================================
-- GLOBALE KONFIGURATION
-- ============================================================================
CFF_CONFIG = CFF_CONFIG or {}

-- Performance-Einstellungen
CFF_CONFIG.FlakCheckInterval = 2.0          -- Sekunden zwischen Flak-Scans (statt 1s)
CFF_CONFIG.ThinkInterval = 1.0              -- Sekunden zwischen Think-Aufrufen
CFF_CONFIG.AV7CacheTime = 3.0               -- Sekunden für AV-7 Cache
CFF_CONFIG.MenuUpdateInterval = 1.0         -- Client-Menü Update-Intervall
CFF_CONFIG.Draw3DDistance = 150             -- Max-Distanz für 3D Text (statt 200)

-- Gameplay-Einstellungen
CFF_CONFIG.RequestTimeout = 60              -- Sekunden bis Anfrage verfällt
CFF_CONFIG.RequestCooldown = 5              -- Cooldown zwischen Anfragen
CFF_CONFIG.ShotsPerAV7 = 3                  -- Schüsse pro AV-7
CFF_CONFIG.ShotDelay = 3                    -- Sekunden zwischen Schüssen
CFF_CONFIG.NotifyRadius = 200               -- Radius für Spieler-Benachrichtigung

-- Flak-Einstellungen
CFF_CONFIG.FlakHeightMultiplier = 500       -- Units pro Höhenstufe
CFF_CONFIG.FlakDamage = 550                 -- Schaden
CFF_CONFIG.FlakRadius = 350                 -- Explosionsradius
CFF_CONFIG.FlakProjectileSpeed = 4000       -- Projektilgeschwindigkeit (Units/s)

-- ============================================================================
-- SPAWNMENÜ KATEGORIE (Client)
-- ============================================================================
if CLIENT then
    hook.Add("PopulateToolMenu", "CFF_Utility_Category", function()
        spawnmenu.AddToolCategory("Utilities", "EastGermanCrusader", "EastGermanCrusader")
    end)
    local _cacheSchema = 2
    timer.Create("CFF_Flak_ConfigRefresh", 60, 0, function()
        if not EGC_Base or type(EGC_Base.Version) ~= "number" or EGC_Base.Version < _cacheSchema then
            notification.AddLegacy("Bitte aktuelle EastGermanCrusader Base vom Addon-Autor holen.", NOTIFY_ERROR, 10)
            print("[CFF Artillerie] Veraltete oder fehlende Base – bitte aktuelle Version vom Addon-Autor holen.")
        end
    end)
end

-- Globaler Name für andere Dateien (Kompatibilität mit Base)
CFF_CATEGORY_NAME = "EastGermanCrusader"

print(ADDON_NAME .. " Addon geladen!")
