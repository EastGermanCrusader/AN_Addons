-- eastgermancrusader_cctv/lua/autorun/sh_crusader_cctv_config.lua
-- ============================================
-- OPTIMIERTE SHARED CONFIG & HILFSFUNKTIONEN
-- Performance-optimiert für Mehrspieler
-- ============================================

-- Schadensstufen (shared für UI-Anzeige)
CCTV_HEALTH_MAX = 100
CCTV_HEALTH_VIDEO_THRESHOLD = 60
CCTV_HEALTH_AUDIO_THRESHOLD = 40
CCTV_HEALTH_DESTROYED = 0

-- ============================================
-- PERFORMANCE: Lokale Referenzen für häufig verwendete Funktionen
-- ============================================
local ents_FindByClass = ents.FindByClass
local IsValid = IsValid
local table_insert = table.insert
local ipairs = ipairs

-- ============================================
-- OPTIMIERTE Kamera-Such-Funktion mit Caching
-- ============================================
local CCTV_CameraCache = {}
local CCTV_CacheTime = 0
local CCTV_CACHE_DURATION = 0.5 -- Cache für 0.5 Sekunden

function CRUSADER_GetAllCCTVCameras(forceRefresh)
    local curTime = CurTime()
    
    -- Cache nutzen wenn noch gültig
    if not forceRefresh and (curTime - CCTV_CacheTime) < CCTV_CACHE_DURATION and #CCTV_CameraCache > 0 then
        return CCTV_CameraCache
    end
    
    -- Cache erneuern
    CCTV_CameraCache = {}
    
    for _, ent in ipairs(ents_FindByClass("crusader_cctv_camera")) do
        if IsValid(ent) then
            table_insert(CCTV_CameraCache, ent)
        end
    end
    
    for _, ent in ipairs(ents_FindByClass("crusader_cctv_camera_v2")) do
        if IsValid(ent) then
            table_insert(CCTV_CameraCache, ent)
        end
    end
    
    CCTV_CacheTime = curTime
    return CCTV_CameraCache
end

-- ============================================
-- GEMEINSAME KAMERA-LOGIK (Reduziert Code-Duplikation)
-- ============================================
CRUSADER_CCTV_SHARED = CRUSADER_CCTV_SHARED or {}

-- Gemeinsame UpdateDamageState Funktion
function CRUSADER_CCTV_SHARED.UpdateDamageState(ent)
    local health = ent:GetCameraHealth()
    local math_random = math.random
    
    if health <= CCTV_HEALTH_DESTROYED then
        ent:SetIsActive(false)
        ent:SetVideoActive(false)
        ent:SetAudioActive(false)
    elseif health <= CCTV_HEALTH_AUDIO_THRESHOLD then
        ent:SetIsActive(true)
        
        local factor = health / CCTV_HEALTH_AUDIO_THRESHOLD
        local videoActive = math_random() < factor + 0.3
        local audioActive = math_random() < factor + 0.2
        
        -- Mindestens eines aktiv wenn health > 0
        if not videoActive and not audioActive and health > 0 then
            if math_random() > 0.5 then
                videoActive = true
            else
                audioActive = true
            end
        end
        
        ent:SetVideoActive(videoActive)
        ent:SetAudioActive(audioActive)
    elseif health <= CCTV_HEALTH_VIDEO_THRESHOLD then
        ent:SetIsActive(true)
        ent:SetAudioActive(true)
        
        local factor = (health - CCTV_HEALTH_AUDIO_THRESHOLD) / (CCTV_HEALTH_VIDEO_THRESHOLD - CCTV_HEALTH_AUDIO_THRESHOLD)
        ent:SetVideoActive(math_random() < factor + 0.5)
    else
        ent:SetIsActive(true)
        ent:SetVideoActive(true)
        ent:SetAudioActive(true)
    end
end

-- Gemeinsame RepairCamera Funktion
function CRUSADER_CCTV_SHARED.RepairCamera(ent, amount, ply)
    local currentHealth = ent:GetCameraHealth()
    
    if currentHealth >= CCTV_HEALTH_MAX then
        return false
    end
    
    local newHealth = math.min(CCTV_HEALTH_MAX, currentHealth + amount)
    ent:SetCameraHealth(newHealth)
    
    CRUSADER_CCTV_SHARED.UpdateDamageState(ent)
    
    if newHealth >= CCTV_HEALTH_MAX and IsValid(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ANS-CCTV] Kamera " .. ent:GetCameraName() .. ": VOLLSTÄNDIG REPARIERT")
    end
    
    return true
end

-- Gemeinsame OnTakeDamage Funktion
function CRUSADER_CCTV_SHARED.OnTakeDamage(ent, dmginfo)
    local damage = dmginfo:GetDamage()
    local currentHealth = ent:GetCameraHealth()
    local newHealth = math.max(0, currentHealth - damage)
    
    ent:SetCameraHealth(newHealth)
    ent:EmitSound("physics/metal/metal_box_impact_bullet" .. math.random(1, 3) .. ".wav", 75, math.random(90, 110))
    
    CRUSADER_CCTV_SHARED.UpdateDamageState(ent)
    
    -- Feedback für Angreifer
    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and attacker:IsPlayer() then
        local name = ent:GetCameraName()
        if newHealth <= 0 and currentHealth > 0 then
            attacker:PrintMessage(HUD_PRINTCONSOLE, "[ANS-CCTV] Kamera " .. name .. ": ZERSTÖRT")
        elseif newHealth <= CCTV_HEALTH_AUDIO_THRESHOLD and currentHealth > CCTV_HEALTH_AUDIO_THRESHOLD then
            attacker:PrintMessage(HUD_PRINTCONSOLE, "[ANS-CCTV] Kamera " .. name .. ": SCHWER BESCHÄDIGT")
        elseif newHealth <= CCTV_HEALTH_VIDEO_THRESHOLD and currentHealth > CCTV_HEALTH_VIDEO_THRESHOLD then
            attacker:PrintMessage(HUD_PRINTCONSOLE, "[ANS-CCTV] Kamera " .. name .. ": BESCHÄDIGT")
        end
    end
end
