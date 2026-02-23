if SERVER then return end

LordMineDetector = LordMineDetector or {}

-- ConVars
function LordMineDetector.GetRadarPosX()
    return GetConVar("mine_detector_pos_x"):GetInt()
end

function LordMineDetector.GetRadarPosY()
    return GetConVar("mine_detector_pos_y"):GetInt()
end

function LordMineDetector.GetRadarSize()
    return GetConVar("mine_detector_size"):GetInt()
end

function LordMineDetector.GetPingVolume()
    return GetConVar("mine_detector_ping_volume"):GetFloat()
end

local MineDetectorStyleFrame

function LordMineDetector.OpenStyleMenu()
    if IsValid(MineDetectorStyleFrame) then
        MineDetectorStyleFrame:MakePopup()
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Radar Personnalisation")
    frame:SetSize(370, 210)
    frame:Center()
    frame:MakePopup()
    MineDetectorStyleFrame = frame

    local function AddSlider(text, min, max, decimals, value, posY, onChanged)
        local slider = vgui.Create("DNumSlider", frame)
        slider:SetPos(20, posY)
        slider:SetSize(330, 35)
        slider:SetText(text)
        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetDecimals(decimals)
        slider:SetValue(value)
        slider.OnValueChanged = onChanged
    end

    AddSlider("Position X", 0, ScrW(), 0, LordMineDetector.GetRadarPosX(), 30, function(_, val)
        RunConsoleCommand("mine_detector_pos_x", tostring(math.floor(val)))
    end)

    AddSlider("Position Y", 0, ScrH(), 0, LordMineDetector.GetRadarPosY(), 65, function(_, val)
        RunConsoleCommand("mine_detector_pos_y", tostring(math.floor(val)))
    end)

    AddSlider("Taille Radar", 50, 300, 0, LordMineDetector.GetRadarSize(), 100, function(_, val)
        RunConsoleCommand("mine_detector_size", tostring(math.floor(val)))
    end)

    AddSlider("Volume Bip", 0, 1, 2, LordMineDetector.GetPingVolume(), 135, function(_, val)
        RunConsoleCommand("mine_detector_ping_volume", tostring(val))
    end)

    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetText("Save")
    saveBtn:SetPos(130, 170)
    saveBtn:SetSize(100, 30)
    saveBtn.DoClick = function()
        frame:Close()
    end
end

concommand.Add("mine_detector_edit", function()
    LordMineDetector.OpenStyleMenu()
end)
