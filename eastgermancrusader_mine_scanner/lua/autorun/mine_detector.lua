if CLIENT then
    resource.AddFile("resource/fonts/aurebesh.ttf")
    surface.CreateFont("LordAurebeshFont", {
        font = "Aurebesh",
        size = 12,
        weight = 600,
        antialias = true,
        extended = true
    })
end

if SERVER then
    resource.AddFile("sound/beep.wav")
    resource.AddFile("sound/warden_deploy.wav")
end

