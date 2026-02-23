-- eastgermancrusader_cctv/lua/autorun/server/sv_cctv_permaprops_integration.lua
-- ============================================
-- OPTIMIERTE CCTV PERSISTENZ-INTEGRATION
-- Unterstützt PermaPropsSystem, Duplicator, AdvDupe2
-- ============================================

if not SERVER then return end
if not _LVS_NodeOK then return end
-- Lokale Referenzen
local IsValid = IsValid
local timer_Simple = timer.Simple

-- ============================================
-- OPTIMIERT: Gemeinsame Restore-Funktion
-- ============================================
local function RestoreCameraData(ent, data)
    if not IsValid(ent) then return end
    
    if data.camera_name and data.camera_name ~= "" then
        ent:SetCameraName(data.camera_name)
    end
    
    if data.camera_health then
        ent:SetCameraHealth(data.camera_health)
    end
    
    if data.is_active ~= nil then
        ent:SetIsActive(data.is_active)
    end
    if data.video_active ~= nil then
        ent:SetVideoActive(data.video_active)
    end
    if data.audio_active ~= nil then
        ent:SetAudioActive(data.audio_active)
    end
    
    if ent.UpdateDamageState then
        ent:UpdateDamageState()
    end
end

-- ============================================
-- DUPLICATOR SUPPORT (Fallback für alle Systeme)
-- ============================================
local CCTV_CLASSES = {
    ["crusader_cctv_camera"] = true,
    ["crusader_cctv_camera_v2"] = true
}

local function RegisterDuplicatorSupport(className)
    duplicator.RegisterEntityModifier(className .. "_cctv_data", function(ply, ent, data)
        timer_Simple(0.1, function()
            RestoreCameraData(ent, data)
        end)
    end)
end

RegisterDuplicatorSupport("crusader_cctv_camera")
RegisterDuplicatorSupport("crusader_cctv_camera_v2")

-- ============================================
-- HOOK: Daten speichern wenn Entity kopiert wird
-- ============================================
hook.Add("EntityCopy", "CCTV_SaveDuplicatorData", function(ent, save)
    local class = ent:GetClass()
    
    if not CCTV_CLASSES[class] then return end
    
    local data = {
        camera_name = ent:GetCameraName(),
        camera_health = ent:GetCameraHealth(),
        is_active = ent:GetIsActive(),
        video_active = ent:GetVideoActive(),
        audio_active = ent:GetAudioActive()
    }
    
    duplicator.StoreEntityModifier(ent, class .. "_cctv_data", data)
end)

-- ============================================
-- PERMAPROPS SYSTEM INTEGRATION
-- ============================================
local function SetupPermaPropsHooks()
    if not PermaPropsSystem then
        return false
    end
    
    hook.Add("PermaProps.OnAdd", "CCTV_PermaProps_OnAdd", function(ent, data, ply)
        local class = ent:GetClass()
        
        if not CCTV_CLASSES[class] then return end
        
        data.cctv_display_name = ent:GetCameraName()
        data.cctv_health = ent:GetCameraHealth()
        data.cctv_is_active = ent:GetIsActive()
        data.cctv_video_active = ent:GetVideoActive()
        data.cctv_audio_active = ent:GetAudioActive()
    end)
    
    hook.Add("PermaProps.PostSpawn", "CCTV_PermaProps_PostSpawn", function(ent, data)
        local class = ent:GetClass()
        
        if not CCTV_CLASSES[class] then return end
        
        timer_Simple(0.1, function()
            if not IsValid(ent) then return end
            
            local currentName = ent:GetCameraName()
            if (currentName == "Kamera" or currentName == "") and data.cctv_display_name then
                ent:SetCameraName(data.cctv_display_name)
            end
            
            RestoreCameraData(ent, {
                camera_health = data.cctv_health,
                is_active = data.cctv_is_active,
                video_active = data.cctv_video_active,
                audio_active = data.cctv_audio_active
            })
        end)
    end)
    
    return true
end

if SetupPermaPropsHooks() then
    print("[ANS-CCTV] PermaPropsSystem-Integration aktiv")
else
    hook.Add("InitPostEntity", "CCTV_DelayedPermaPropsSetup", function()
        timer_Simple(1, function()
            if SetupPermaPropsHooks() then
                print("[ANS-CCTV] PermaPropsSystem-Integration aktiv (verzögert)")
            else
                print("[ANS-CCTV] Kein PermaPropsSystem gefunden - Duplicator-Support aktiv")
            end
        end)
    end)
end

print("[ANS-CCTV] Persistenz-Integration geladen (OPTIMIERT)")
