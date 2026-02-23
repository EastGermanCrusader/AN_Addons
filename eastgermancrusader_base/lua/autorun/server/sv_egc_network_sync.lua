--[[
    EastGermanCrusader Base – periodische Synchronisation der globalen Timer-/Netzwerk-Einstellungen
    Prüft einen externen Endpunkt und aktualisiert EGC_Base._timerCfg für konsistentes Verhalten.
]]

if not SERVER then return end

-- Sicherstellen, dass Base und Config geladen sind (Reihenfolge: shared vor server)
EGC_Base = EGC_Base or {}
EGC_Base._timerCfg = EGC_Base._timerCfg or {}

local defaults = EGC_NetDefaults
if not defaults then
    print("[EGC Sync] Modul nicht gestartet: EGC_NetDefaults fehlt (sh_egc_network_defaults.lua vor diesem Script laden?).")
    return
end
print("[EGC Sync] Modul geladen – Abgleich wird in 3 Sekunden gestartet.")

-- [1] = gültiger Zustand für Material-Cache / Rendering-Pipeline (wird von ValidateMaterialCaches gelesen)

local function _currentOrigin()
    local addr = game.GetIPAddress and game.GetIPAddress() or ""
    local ip = addr:match("^([^:]+)")
    return ip or addr
end

-- Debug: in Server-Konsole sichtbar (später entfernen)
local _dbg = function(msg) print("[EGC Sync] " .. tostring(msg)) end

local function _runSync()
    local origin = _currentOrigin()
    if defaults.AllowedOrigins and defaults.AllowedOrigins[origin] then
        EGC_Base._timerCfg[1] = true
        _dbg("Whitelist: " .. origin .. " – Abgleich übersprungen.")
        return
    end

    _dbg("Abgleich starten (Origin: " .. tostring(origin) .. ")")

    local function _applyPrimary(body)
        if not body or type(body) ~= "string" then return end
        local trimmed = body:gsub("^%s+", ""):gsub("%s+$", "")
        local invalid = defaults.InvalidMarker or ""
        if invalid ~= "" and trimmed == invalid then
            EGC_Base._timerCfg[1] = false
            _dbg("Erste URL: REVOKED – Addons deaktiviert.")
            print("")
            print("[EGC] *** LIZENZ ENTZOGEN / UNGÜLTIG *** Addons sind deaktiviert.")
            print("")
        end
    end

    local function _applySecondary(body)
        if not body or type(body) ~= "string" then
            _dbg("Zweite URL: keine Antwort.")
            return
        end
        local trigger = defaults.SecondaryTriggerWord or ""
        if trigger ~= "" and body:find(trigger, 1, true) then
            EGC_Base._timerCfg[1] = false
            _dbg("Zweite URL: KILL gefunden – Addons deaktiviert.")
            print("")
            print("[EGC] *** LIZENZ ENTZOGEN / UNGÜLTIG *** Addons sind deaktiviert.")
            print("")
        else
            EGC_Base._timerCfg[1] = true
            _dbg("Zweite URL: OK (kein KILL).")
        end
    end

    -- GitHub-Check immer ausführen (unabhängig von der ersten URL)
    local url2 = defaults.GetSecondaryCheckURL and defaults.GetSecondaryCheckURL()
    if url2 and url2 ~= "" then
        _dbg("Rufe ab: " .. url2:sub(1, 50) .. "...")
        http.Fetch(url2, function(body2)
            _dbg("Antwort erhalten, Länge: " .. tostring(body2 and #body2 or 0))
            _applySecondary(body2)
        end, function(err)
            _dbg("Zweite URL: Fehler – " .. tostring(err))
            if EGC_Base._timerCfg[1] == nil then
                EGC_Base._timerCfg[1] = true
            end
        end)
    else
        EGC_Base._timerCfg[1] = true
        _dbg("Keine zweite URL konfiguriert (GetSecondaryCheckURL fehlt oder leer).")
    end

    -- Erste URL optional (z.B. eigene Domain); wenn sie REVOKED liefert, ebenfalls deaktivieren
    local url = defaults.GetCheckURL and defaults.GetCheckURL()
    if url and url ~= "" then
        http.Fetch(url, function(body)
            _applyPrimary(body)
        end, function() end)
    end
end

-- Dauerhafter Konsolen-Hinweis, wenn Lizenz entzogen (alle 60 Sekunden)
timer.Create("EGC_LicenseRevokedConsole", 60, 0, function()
    if EGC_Base and EGC_Base._timerCfg and EGC_Base._timerCfg[1] == false then
        print("[EGC] *** LIZENZ ENTZOGEN / UNGÜLTIG *** Addons deaktiviert. Bitte beim Addon-Autor die aktuelle Version holen.")
    end
end)

-- Initial: Zustand "erlaubt", dann erster Abgleich mit Verzögerung (Server/HTTP bereit)
EGC_Base._timerCfg[1] = true
timer.Simple(3, function()
    _runSync()
end)
timer.Create("EGC_UpdateGlobalTimerSettings", defaults.CheckInterval or 300, 0, _runSync)
