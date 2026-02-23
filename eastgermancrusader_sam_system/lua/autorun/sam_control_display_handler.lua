if (CLIENT) then
	AddCSLuaFile("sam_control_gui/imgui.lua")

	local imgui = include("sam_control_gui/imgui.lua")

	sam_control_entities = sam_control_entities or {}
	local viewDist = 800
	local viewDistSqr = viewDist * viewDist
	local fadeDist = 600

	local baseWidth = 900
	local baseHeight = 600
	local displayMaterial = Material("sprites/lfs_display_image.png")
	if not displayMaterial or displayMaterial:IsError() then
		-- Fallback: Einfaches schwarzes Material
		displayMaterial = Material("vgui/black")
	end
	local start_ang = Angle(0,90,90)

	local start_x = -baseWidth / 2
	local start_y = -baseHeight / 2

	local border = 5

	-- Schriftarten
	surface.CreateFont( "SAM_Control_Display_Font_1", {
	    font = "roboto",
	    italic = true,
	    size = 40,
	    weight = 1000,
	    antialias = true,
	} )

	surface.CreateFont( "SAM_Control_Display_Font_2", {
	    font = "roboto",
	    italic = true,
	    size = 24,
	    weight = 1000,
	    antialias = true,
	} )

	surface.CreateFont( "SAM_Control_Display_Font_3", {
	    font = "roboto",
	    italic = true,
	    size = 18,
	    weight = 500,
	    antialias = true,
	} )

	-- Initialisiere Entities beim Start
	hook.Add("Initialize", "SAM_Control_Entity_Init", function()
		timer.Simple(1, function()
			sam_control_entities = ents.FindByClass("lvs_sam_control")
		end)
	end)
	
	hook.Add( "OnEntityCreated", "SAM_Control_Entity_Create", function( ent )
		timer.Simple(.1, function()
			if (!IsValid(ent)) then return end
			if (ent:GetClass() == "lvs_sam_control") then
				sam_control_entities = ents.FindByClass("lvs_sam_control")
				return
			end
		end)
	end)

	-- Aktualisiere Entity-Liste jeden Frame (für sofortige Updates)
	hook.Add("Think", "SAM_Control_Entity_Update", function()
		-- Aktualisiere Entity-Liste jeden Frame für sofortige Updates
		sam_control_entities = ents.FindByClass("lvs_sam_control")
	end)
	
	-- Cooldown für Button-Clicks (verhindert Doppelklicks)
	local buttonCooldowns = {}
	
	hook.Add("PostDrawOpaqueRenderables", "SAM_Control_Display_Drawer", function()
		local ply = LocalPlayer()
		
		-- Aktualisiere Entity-Liste jeden Frame (wird bereits in Think gemacht, aber hier als Fallback)
		if #sam_control_entities == 0 then
			sam_control_entities = ents.FindByClass("lvs_sam_control")
		end
		
		if (#sam_control_entities == 0 or !IsValid(ply) or imgui == nil) then
			return
		end

		local ang = start_ang

		local filtered_entities = {}
		local ply_pos = ply:GetPos()
		for _, v in ipairs(sam_control_entities) do
			if IsValid(v) and v:GetActive() and v:GetPos():DistToSqr(ply_pos) < viewDistSqr then
				table.insert(filtered_entities, v)
			end
		end
		if #filtered_entities == 0 then return end

		-- Loop through our control stations
		for k,v in ipairs(sam_control_entities) do
			if (IsValid(v)) then
				-- Get cached data from the entity
				local vlsList = v._cachedVLSList or {}
				local targetList = v._cachedTargetList or {}
				local isArmed = v:GetArmed()
				local salvoSize = v:GetSalvoSize()
				local totalMissiles = v:GetTotalMissiles()
				local activeMissiles = v:GetActiveMissiles()
				local selectedTarget = v:GetSelectedTarget()
				

	            if imgui.Entity3D2D(v, v:GetForward() + v:GetUp() * 78, ang, 0.1, viewDist, fadeDist) then
					-- Display Background
					surface.SetDrawColor( 0, 0, 0, 255 )
		        	if displayMaterial and not displayMaterial:IsError() then
		        		surface.SetMaterial(displayMaterial)
		        		surface.DrawTexturedRect(start_x, start_y, baseWidth,baseHeight)
		        	else
		        		-- Fallback: Schwarzer Hintergrund
		        		surface.DrawRect(start_x, start_y, baseWidth,baseHeight)
		        	end
		        	surface.SetDrawColor( 255, 255, 255, 255 )

		        	-- Title
		        	local titleCol = isArmed and Color(255, 50, 50, 255) or Color(0, 255, 0, 255)
		        	draw.SimpleText( "TORPEDO KONTROLLSTATION", "SAM_Control_Display_Font_1", 0, start_y + 20, titleCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	
		        	if isArmed then
		        		local blink = math.sin(CurTime() * 6) > 0
		        		local armCol = blink and Color(255, 100, 100, 255) or Color(200, 50, 50, 255)
		        		draw.SimpleText( "⚠ WAFFEN SCHARF ⚠", "SAM_Control_Display_Font_2", 0, start_y + 65, armCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	end

		        	-- Border
		        	surface.DrawOutlinedRect(start_x + border, start_y + 90, baseWidth - (border*2), baseHeight - 100, 2)

		        	-- Left Panel: VLS Status mit Auswahl-Buttons
		        	local vlsPanelX = start_x + border + 10
		        	local vlsPanelY = start_y + 100
		        	local vlsPanelW = 280
		        	local vlsPanelH = 250  -- Erhöht für Buttons
		        	
		        	surface.DrawOutlinedRect(vlsPanelX, vlsPanelY, vlsPanelW, vlsPanelH, 2)
		        	draw.SimpleText("CONTAINER (VLS)", "SAM_Control_Display_Font_2", vlsPanelX + vlsPanelW/2, vlsPanelY + 8, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	draw.SimpleText("Klicke zum Auswählen", "SAM_Control_Display_Font_3", vlsPanelX + vlsPanelW/2, vlsPanelY + 28, Color(180, 180, 180, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	
		        	local vlsY = vlsPanelY + 48
		        	
		        	-- Zeige "Keine VLS gefunden" wenn Liste leer
		        	if #vlsList == 0 then
		        		draw.SimpleText("Keine VLS gefunden", "SAM_Control_Display_Font_3", vlsPanelX + vlsPanelW/2, vlsY, Color(150, 150, 150, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	else
		        		for i, vls in ipairs(vlsList) do
		        			if i > 4 then break end -- Max 4 VLS anzeigen
		        			
		        			-- Prüfe ob VLS ausgewählt ist
		        			local isSelected = false
		        			if IsValid(vls.entity) then
		        				local vlsID = vls.entity:EntIndex()
		        				for _, selectedID in ipairs(v._selectedVLS or {}) do
		        					if selectedID == vlsID then
		        						isSelected = true
		        						break
		        					end
		        				end
		        			end
		        			
		        			local vlsCol = vls.missiles > 0 and Color(0, 255, 100, 255) or Color(255, 100, 100, 255)
		        			local btnCol = isSelected and Color(255, 200, 0, 255) or Color(100, 100, 100, 255)
		        			local btnHoverCol = isSelected and Color(255, 220, 100, 255) or Color(150, 150, 150, 255)
		        			
		        			-- VLS-Button (klickbarer Bereich)
		        			local btnX = vlsPanelX + 5
		        			local btnY = vlsY - 5
		        			local btnW = vlsPanelW - 10
		        			local btnH = 40
		        			
		        			-- Button-Click mit Cooldown (verhindert Doppelklicks)
		        			local buttonKey = "vls_" .. (IsValid(vls.entity) and vls.entity:EntIndex() or i) .. "_" .. v:EntIndex()
		        			local lastClick = buttonCooldowns[buttonKey] or 0
		        			local canClick = CurTime() - lastClick > 0.3  -- 0.3 Sekunden Cooldown
		        			
		        			if imgui.xButton(btnX, btnY, btnW, btnH, 2, btnCol, btnHoverCol, Color(255, 255, 255, 255)) and canClick then
		        				if IsValid(vls.entity) then
		        					buttonCooldowns[buttonKey] = CurTime()
		        					net.Start("EGC_SAM_ToggleVLS")
		        					net.WriteEntity(v)
		        					net.WriteEntity(vls.entity)
		        					net.SendToServer()
		        					surface.PlaySound("buttons/button14.wav")
		        				end
		        			end
		        			
		        			-- VLS-Info anzeigen (mit Nickname falls vorhanden)
		        			local statusText = isSelected and "✓ " or ""
		        			local vlsName = "VLS #" .. i
		        			if IsValid(vls.entity) then
		        				local nickname = vls.entity:GetNickname()
		        				if nickname and nickname ~= "" then
		        					vlsName = nickname
		        				end
		        			end
		        			draw.SimpleText(statusText .. string.format("%s: %d Torpedos", vlsName, vls.missiles or 0), "SAM_Control_Display_Font_3", vlsPanelX + 10, vlsY, vlsCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		        			
		        			vlsY = vlsY + 45
		        		end
		        	end
		        	
		        	if #vlsList == 0 then
		        		draw.SimpleText("Keine VLS gefunden", "SAM_Control_Display_Font_3", vlsPanelX + vlsPanelW/2, vlsPanelY + vlsPanelH/2, Color(150, 150, 150, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		        	end

		        	-- Center Panel: Targets
		        	local targetPanelX = vlsPanelX + vlsPanelW + 10
		        	local targetPanelY = start_y + 100
		        	local targetPanelW = 300
		        	local targetPanelH = 350
		        	
		        	surface.DrawOutlinedRect(targetPanelX, targetPanelY, targetPanelW, targetPanelH, 2)
		        	draw.SimpleText("RADAR - ZIELE", "SAM_Control_Display_Font_2", targetPanelX + targetPanelW/2, targetPanelY + 10, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	
		        	local targetY = targetPanelY + 40
		        	for i, target in ipairs(targetList) do
		        		if i > 6 then break end -- Max 6 Ziele anzeigen
		        		local isSelected = IsValid(selectedTarget) and selectedTarget == target.entity
		        		local targetCol = isSelected and Color(255, 255, 0, 255) or (target.visible and Color(255, 100, 100, 255) or Color(150, 150, 150, 255))
		        		
		        		local targetBoxX = targetPanelX + 5
		        		local targetBoxY = targetY - 5
		        		local targetBoxW = targetPanelW - 10
		        		local targetBoxH = 45
		        		
		        		-- Klickbarer Bereich für Zielauswahl (mit Cooldown)
		        		local targetButtonKey = "target_" .. (IsValid(target.entity) and target.entity:EntIndex() or i) .. "_" .. v:EntIndex()
		        		local targetLastClick = buttonCooldowns[targetButtonKey] or 0
		        		local targetCanClick = CurTime() - targetLastClick > 0.3
		        		
		        		if imgui.xButton(targetBoxX, targetBoxY, targetBoxW, targetBoxH, 2, isSelected and Color(255, 255, 0, 255) or Color(100, 100, 100, 255), Color(150, 150, 150, 255), Color(200, 200, 200, 255)) and targetCanClick then
		        			if IsValid(target.entity) then
		        				buttonCooldowns[targetButtonKey] = CurTime()
		        				net.Start("EGC_SAM_SelectTarget")
		        				net.WriteEntity(v)
		        				net.WriteEntity(target.entity)
		        				net.SendToServer()
		        				surface.PlaySound("buttons/button14.wav")
		        			end
		        		end
		        		
		        		-- Name anzeigen - wenn nicht identifiziert, grau
		        		local nameCol = targetCol
		        		if target.identified == false then
		        			nameCol = Color(150, 150, 150, 255)
		        		end
		        		draw.SimpleText(string.format("%s", string.sub(target.name or "Unknown", 1, 20)), "SAM_Control_Display_Font_3", targetPanelX + 10, targetY, nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		        		draw.SimpleText(string.format("Dist: %.0fm | Alt: %.0fm", target.distance or 0, target.altitude or 0), "SAM_Control_Display_Font_3", targetPanelX + 10, targetY + 18, Color(200, 200, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		        		
		        		if isSelected then
		        			draw.SimpleText("►", "SAM_Control_Display_Font_2", targetPanelX + 5, targetY + 9, Color(255, 255, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		        		end
		        		
		        		targetY = targetY + 50
		        	end
		        	
		        	if #targetList == 0 then
		        		draw.SimpleText("Keine Ziele erfasst", "SAM_Control_Display_Font_3", targetPanelX + targetPanelW/2, targetPanelY + targetPanelH/2, Color(150, 150, 150, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		        	end

		        	-- Right Panel: Controls
		        	local controlPanelX = targetPanelX + targetPanelW + 10
		        	local controlPanelY = start_y + 100
		        	local controlPanelW = 280
			local controlPanelH = 400  -- Angepasst für neue VLS-Auswahl
		        	
		        	surface.DrawOutlinedRect(controlPanelX, controlPanelY, controlPanelW, controlPanelH, 2)
		        	draw.SimpleText("WAFFENKONTROLLE", "SAM_Control_Display_Font_2", controlPanelX + controlPanelW/2, controlPanelY + 10, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		        	-- 1) Torpedo-Art (oben): Spreng / Ionen (EMP) / Übung (Training)
		        	local torpedoTypeY = controlPanelY + 38
		        	local torpedoTypeW = (controlPanelW - 30) / 3
		        	local torpedoTypeH = 32
		        	local currentType = v:GetTorpedoType()
		        	local type0Col = currentType == 0 and Color(255, 200, 100, 255) or Color(100, 100, 100, 255)
		        	local type1Col = currentType == 1 and Color(100, 200, 255, 255) or Color(100, 100, 100, 255)
		        	local type2Col = currentType == 2 and Color(255, 120, 120, 255) or Color(100, 100, 100, 255)
		        	local tKey0, tKey1, tKey2 = "torpedotype_0_" .. v:EntIndex(), "torpedotype_1_" .. v:EntIndex(), "torpedotype_2_" .. v:EntIndex()
		        	local tClick = function(k) return CurTime() - (buttonCooldowns[k] or 0) > 0.3 end
		        	if imgui.xTextButton("SPRENG", "SAM_Control_Display_Font_3", controlPanelX + 5, torpedoTypeY, torpedoTypeW, torpedoTypeH, 2, type0Col, Color(255, 220, 120, 255), Color(255, 255, 255, 255)) and tClick(tKey0) then
		        		buttonCooldowns[tKey0] = CurTime()
		        		net.Start("EGC_SAM_SetTorpedoType") net.WriteEntity(v) net.WriteUInt(0, 8) net.SendToServer()
		        		surface.PlaySound("buttons/button14.wav")
		        	end
		        	if imgui.xTextButton("IONEN", "SAM_Control_Display_Font_3", controlPanelX + 10 + torpedoTypeW, torpedoTypeY, torpedoTypeW, torpedoTypeH, 2, type1Col, Color(150, 220, 255, 255), Color(255, 255, 255, 255)) and tClick(tKey1) then
		        		buttonCooldowns[tKey1] = CurTime()
		        		net.Start("EGC_SAM_SetTorpedoType") net.WriteEntity(v) net.WriteUInt(1, 8) net.SendToServer()
		        		surface.PlaySound("buttons/button14.wav")
		        	end
		        	if imgui.xTextButton("ÜBUNG", "SAM_Control_Display_Font_3", controlPanelX + 15 + torpedoTypeW * 2, torpedoTypeY, torpedoTypeW, torpedoTypeH, 2, type2Col, Color(255, 160, 160, 255), Color(255, 255, 255, 255)) and tClick(tKey2) then
		        		buttonCooldowns[tKey2] = CurTime()
		        		net.Start("EGC_SAM_SetTorpedoType") net.WriteEntity(v) net.WriteUInt(2, 8) net.SendToServer()
		        		surface.PlaySound("buttons/button14.wav")
		        	end
		        	draw.SimpleText("Torpedo-Art", "SAM_Control_Display_Font_3", controlPanelX + controlPanelW/2, torpedoTypeY + torpedoTypeH + 2, Color(180, 180, 180, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

		        	-- 2) Container-Auswahl (AUSGEWÄHLTE VLS) direkt unter Torpedo-Art
		        	local selectedVLSY = torpedoTypeY + torpedoTypeH + 28
		        	local selectedCount = #(v._selectedVLS or {})
		        	draw.SimpleText("CONTAINER (VLS)", "SAM_Control_Display_Font_3", controlPanelX + 10, selectedVLSY, Color(200, 200, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		        	if selectedCount > 0 then
		        		draw.SimpleText(tostring(selectedCount) .. " ausgewählt", "SAM_Control_Display_Font_2", controlPanelX + controlPanelW/2, selectedVLSY + 20, Color(255, 200, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	else
		        		draw.SimpleText("Keine – links klicken", "SAM_Control_Display_Font_2", controlPanelX + controlPanelW/2, selectedVLSY + 20, Color(150, 150, 150, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	end

		        	-- 3) ZIEL
		        	local targetDisplayY = selectedVLSY + 58
		        	draw.SimpleText("ZIEL:", "SAM_Control_Display_Font_3", controlPanelX + 10, targetDisplayY, Color(200, 200, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		        	if IsValid(selectedTarget) then
		        		local name = selectedTarget.PrintName or selectedTarget:GetClass()
		        		draw.SimpleText(string.sub(name, 1, 25), "SAM_Control_Display_Font_2", controlPanelX + controlPanelW/2, targetDisplayY + 25, Color(255, 255, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	else
		        		draw.SimpleText("KEIN ZIEL", "SAM_Control_Display_Font_2", controlPanelX + controlPanelW/2, targetDisplayY + 25, Color(150, 150, 150, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	end

		        	-- 4) ARM / SAFE
		        	local armBtnY = targetDisplayY + 68
		        	local armBtnW = 120
		        	local armBtnH = 40
		        	local armButtonKey = "arm_" .. v:EntIndex()
		        	local safeButtonKey = "safe_" .. v:EntIndex()
		        	if imgui.xTextButton("ARM", "SAM_Control_Display_Font_2", controlPanelX + 10, armBtnY, armBtnW, armBtnH, 2, Color(255, 255, 255, 255), Color(255, 200, 200, 255), Color(255, 100, 100, 255)) and CurTime() - (buttonCooldowns[armButtonKey] or 0) > 0.3 then
		        		buttonCooldowns[armButtonKey] = CurTime()
		        		net.Start("EGC_SAM_ArmMissiles") net.WriteEntity(v) net.SendToServer()
		        		surface.PlaySound("buttons/button17.wav")
		        	end
		        	if imgui.xTextButton("SAFE", "SAM_Control_Display_Font_2", controlPanelX + 140, armBtnY, armBtnW, armBtnH, 2, Color(255, 255, 255, 255), Color(200, 255, 200, 255), Color(100, 255, 100, 255)) and CurTime() - (buttonCooldowns[safeButtonKey] or 0) > 0.3 then
		        		buttonCooldowns[safeButtonKey] = CurTime()
		        		net.Start("EGC_SAM_DisarmMissiles") net.WriteEntity(v) net.SendToServer()
		        		surface.PlaySound("buttons/button19.wav")
		        	end

		        	-- 5) FEUER
		        	local fireBtnY = armBtnY + 52
		        	local fireBtnW = controlPanelW - 20
		        	local fireBtnH = 60
		        	local hasSelectedVLS = selectedCount > 0
		        	local canFire = isArmed and IsValid(selectedTarget) and hasSelectedVLS
		        	local fireCol = canFire and Color(255, 100, 100, 255) or Color(100, 100, 100, 255)
		        	
		        	-- FEUER Button (mit Cooldown)
		        	local fireButtonKey = "fire_" .. v:EntIndex()
		        	local fireLastClick = buttonCooldowns[fireButtonKey] or 0
		        	local fireCanClick = CurTime() - fireLastClick > 0.3
		        	if imgui.xTextButton("▼ FEUER ▼", "SAM_Control_Display_Font_1", controlPanelX + 10, fireBtnY, fireBtnW, fireBtnH, 3, fireCol, Color(255, 150, 150, 255), Color(255, 200, 200, 255)) and fireCanClick then
		        		buttonCooldowns[fireButtonKey] = CurTime()
		        		if canFire then
		        			net.Start("EGC_SAM_FireSalvo")
		        			net.WriteEntity(v)
		        			net.SendToServer()
		        			surface.PlaySound("buttons/button9.wav")
		        		else
		        			surface.PlaySound("buttons/button10.wav")
		        		end
		        	end

		        	-- Abort Button (mit Cooldown)
		        	local abortBtnY = fireBtnY + fireBtnH + 10
		        	local abortBtnW = controlPanelW - 20
		        	local abortBtnH = 50
		        	local hasActiveMissiles = activeMissiles > 0
		        	local abortCol = hasActiveMissiles and Color(255, 200, 0, 255) or Color(150, 130, 80, 255)
		        	
		        	local abortButtonKey = "abort_" .. v:EntIndex()
		        	local abortLastClick = buttonCooldowns[abortButtonKey] or 0
		        	local abortCanClick = CurTime() - abortLastClick > 0.3
		        	if imgui.xTextButton("ABORT", "SAM_Control_Display_Font_2", controlPanelX + 10, abortBtnY, abortBtnW, abortBtnH, 2, abortCol, Color(255, 220, 100, 255), Color(255, 240, 150, 255)) and abortCanClick then
		        		buttonCooldowns[abortButtonKey] = CurTime()
		        		net.Start("EGC_SAM_AbortMissiles")
		        		net.WriteEntity(v)
		        		net.SendToServer()
		        		surface.PlaySound("buttons/button10.wav")
		        	end
		        	
		        	if hasActiveMissiles then
		        		draw.SimpleText(string.format("Aktive Raketen: %d", activeMissiles), "SAM_Control_Display_Font_3", controlPanelX + controlPanelW/2, abortBtnY + abortBtnH + 5, Color(255, 200, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		        	end

		        	-- Status Panel (Bottom)
		        	local statusPanelY = controlPanelY + controlPanelH + 10
		        	local statusPanelW = baseWidth - (border*2) - 20
		        	local statusPanelH = 80
		        	
		        	surface.DrawOutlinedRect(start_x + border + 10, statusPanelY, statusPanelW, statusPanelH, 2)
		        	draw.SimpleText("SYSTEM STATUS", "SAM_Control_Display_Font_2", start_x + border + 20, statusPanelY + 10, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		        	
		        	local totalMissiles = 0
		        	for _, vls in ipairs(vlsList) do
		        		totalMissiles = totalMissiles + (vls.missiles or 0)
		        	end
		        	
		        	draw.SimpleText(string.format("VLS: %d | Torpedos: %d | Ziele: %d", #vlsList, totalMissiles, #targetList), "SAM_Control_Display_Font_3", start_x + border + 20, statusPanelY + 35, Color(200, 200, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		        	
		        	local statusText = isArmed and "SCHARF" or "GESICHERT"
		        	local statusCol = isArmed and Color(255, 100, 100, 255) or Color(100, 200, 100, 255)
		        	draw.SimpleText("Status: " .. statusText, "SAM_Control_Display_Font_3", start_x + border + 20, statusPanelY + 55, statusCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		        	
		        	if activeMissiles > 0 then
		        		draw.SimpleText(string.format("Fliegende Raketen: %d", activeMissiles), "SAM_Control_Display_Font_3", start_x + border + statusPanelW - 20, statusPanelY + 35, Color(255, 200, 0, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		        	end

		        	-- Cursor
		        	imgui.xCursor()
		        imgui.End3D2D()
		    	end
			end
		end
	end)

	-- Netzwerk-Empfänger für Display-Daten
	net.Receive("EGC_SAM_UpdateVLSStatus", function()
		local station = net.ReadEntity()
		if not IsValid(station) then return end
		
		-- Leere Liste vor dem Befüllen
		station._cachedVLSList = {}
		
		local count = net.ReadInt(8)
		
		for i = 1, count do
			local vlsEntity = net.ReadEntity()
			local missiles = net.ReadInt(8)
			local locked = net.ReadBool()
			local distance = net.ReadFloat()
			
			if IsValid(vlsEntity) then
				table.insert(station._cachedVLSList, {
					entity = vlsEntity,
					missiles = missiles,
					locked = locked,
					distance = distance,
				})
			end
		end
		
		-- Empfange ausgewählte VLS-IDs
		station._selectedVLS = {}
		local selectedCount = net.ReadInt(8)
		for i = 1, selectedCount do
			local vlsID = net.ReadInt(32)
			table.insert(station._selectedVLS, vlsID)
		end
		
		-- Debug: Zeige empfangene Daten (reduziert)
		if count > 0 and (not station._lastVLSDebug or CurTime() - station._lastVLSDebug > 5) then
			station._lastVLSDebug = CurTime()
			print("[SAM Display] VLS-Status empfangen: " .. count .. " VLS-Systeme, " .. selectedCount .. " ausgewählt")
		end
	end)

	net.Receive("EGC_SAM_UpdateTargets", function()
		local station = net.ReadEntity()
		if not IsValid(station) then return end
		
		-- Initialisiere Liste falls nicht vorhanden
		if not station._cachedTargetList then
			station._cachedTargetList = {}
		else
			station._cachedTargetList = {}
		end
		
		local count = net.ReadInt(16)
		
		for i = 1, count do
			local targetEntity = net.ReadEntity()
			local targetName = net.ReadString()
			local distance = net.ReadFloat()
			local altitude = net.ReadFloat()
			local velocity = net.ReadFloat()
			local heatSignature = net.ReadFloat()
			local visible = net.ReadBool()
			local identified = net.ReadBool()
			
			-- Nur hinzufügen wenn Entity gültig ist
			if IsValid(targetEntity) then
				table.insert(station._cachedTargetList, {
					entity = targetEntity,
					name = targetName,
					distance = distance,
					altitude = altitude,
					velocity = velocity,
					heatSignature = heatSignature,
					visible = visible,
					identified = identified,
				})
			end
		end
		
		-- Debug: Zeige empfangene Daten
		if count > 0 then
			print("[SAM Display] Ziele empfangen: " .. count .. " Ziele")
		end
	end)

	-- E-Taste Funktion: Ziel auswählen wenn man auf ein LVS-Fahrzeug zeigt
	hook.Add("PlayerButtonDown", "SAM_Control_SelectTargetWithE", function(ply, button)
		if button ~= KEY_E then return end
		if not IsValid(ply) or not ply:IsPlayer() then return end
		
		-- Prüfe ob Spieler auf ein Entity zeigt
		local tr = ply:GetEyeTrace()
		if not IsValid(tr.Entity) then return end
		
		local targetEntity = tr.Entity
		
		-- Prüfe ob es ein LVS-Fahrzeug ist
		if not LVS or not LVS.GetVehicles then return end
		local isLVSVehicle = false
		local vehicles = LVS:GetVehicles()
		for _, vehicle in pairs(vehicles) do
			if vehicle == targetEntity then
				isLVSVehicle = true
				break
			end
		end
		
		if not isLVSVehicle then return end
		
		-- Finde die nächste Torpedostation
		local stations = ents.FindByClass("lvs_sam_control")
		local nearestStation = nil
		local nearestDist = math.huge
		
		for _, station in pairs(stations) do
			if IsValid(station) and station:GetActive() then
				local dist = ply:GetPos():Distance(station:GetPos())
				if dist < nearestDist and dist < 1000 then
					nearestDist = dist
					nearestStation = station
				end
			end
		end
		
		if not IsValid(nearestStation) then return end
		
		-- Prüfe ob das Fahrzeug in der Ziel-Liste ist
		local targetList = nearestStation._cachedTargetList or {}
		local isInTargetList = false
		
		for _, target in ipairs(targetList) do
			if IsValid(target.entity) and target.entity == targetEntity then
				isInTargetList = true
				break
			end
		end
		
		if not isInTargetList then return end
		
		-- Ziel auswählen
		net.Start("EGC_SAM_SelectTarget")
		net.WriteEntity(nearestStation)
		net.WriteEntity(targetEntity)
		net.SendToServer()
		
		surface.PlaySound("buttons/button14.wav")
		ply:ChatPrint("[Torpedo Control] Ziel ausgewählt: " .. (targetEntity.PrintName or targetEntity:GetClass()))
	end)
end
