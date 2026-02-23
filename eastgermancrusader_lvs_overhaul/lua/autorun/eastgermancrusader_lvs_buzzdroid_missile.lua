--[[
	Buzz Droid Missile System für Vulture Droid (Blue)
	
	Diese Modifikation ersetzt die normalen Concussion Missiles des
	Vulture Droid Blue durch Buzz Droid Missiles.
	
	Die Rakete überholt das Ziel und verwandelt sich vor dem Ziel
	in eine Wolke aus 8 Buzz Droids (wie im Film "Revenge of the Sith").
	
	Autor: EastGermanCrusader
]]--

-- Nur Server-seitig
if CLIENT then return end

-- Warte bis das Entity-System vollständig geladen ist
hook.Add("InitPostEntity", "EGC_BuzzDroidMissile_Init", function()
	timer.Simple(1, function()
		EGC_BuzzDroidMissile_Override()
	end)
end)

-- Auch bei Hot-Reload
timer.Simple(0, function()
	EGC_BuzzDroidMissile_Override()
end)

function EGC_BuzzDroidMissile_Override()
	-- Finde die Vulture Droid Blue Entity-Klasse
	local VultureBlue = scripted_ents.GetStored("lvs_starfighter_vulturedroid_blue")
	
	if not VultureBlue or not VultureBlue.t then
		print("[EGC] Vulture Droid Blue nicht gefunden - Buzz Droid Missile Override übersprungen")
		return
	end
	
	-- Speichere die Original-Funktion
	local OriginalInitWeapons = VultureBlue.t.InitWeapons
	
	-- Überschreibe InitWeapons
	VultureBlue.t.InitWeapons = function(self)
		-- Feuerposition für die Waffen
		self.FirePositions = {
			Vector(56.82, 105.6, 4),
			Vector(56.82, -105.6, -4),
			Vector(56.82, 105.6, -4),
			Vector(56.82, -105.6, 4)
		}

		-- Primärwaffe: Laser (unverändert)
		local weapon = {}
		weapon.Icon = Material("lvs/weapons/mg.png")
		weapon.Ammo = 1200
		weapon.Delay = 0.1
		weapon.HeatRateUp = 0.25
		weapon.HeatRateDown = 1
		weapon.Attack = function(ent)
			ent.NumPrim = ent.NumPrim and ent.NumPrim + 1 or 1
			if ent.NumPrim > #ent.FirePositions then ent.NumPrim = 1 end

			local pod = ent:GetDriverSeat()
			if not IsValid(pod) then return end

			local startpos = pod:LocalToWorld(pod:OBBCenter())
			local trace = util.TraceHull({
				start = startpos,
				endpos = (startpos + ent:GetForward() * 50000),
				mins = Vector(-10, -10, -10),
				maxs = Vector(10, 10, 10),
				filter = ent:GetCrosshairFilterEnts()
			})

			local bullet = {}
			bullet.Src = ent:LocalToWorld(ent.FirePositions[ent.NumPrim])
			bullet.Dir = (trace.HitPos - bullet.Src):GetNormalized()
			bullet.Spread = Vector(0.02, 0.02, 0)
			bullet.TracerName = "lvs_laser_red"
			bullet.Force = 10
			bullet.HullSize = 40
			bullet.Damage = 10
			bullet.Velocity = 60000
			bullet.Attacker = ent:GetDriver()
			bullet.Callback = function(att, tr, dmginfo)
				local effectdata = EffectData()
				effectdata:SetStart(Vector(255, 50, 50))
				effectdata:SetOrigin(tr.HitPos)
				effectdata:SetNormal(tr.HitNormal)
				util.Effect("lvs_laser_impact", effectdata)
			end
			ent:LVSFireBullet(bullet)

			local effectdata = EffectData()
			effectdata:SetStart(Vector(255, 50, 50))
			effectdata:SetOrigin(bullet.Src)
			effectdata:SetNormal(ent:GetForward())
			effectdata:SetEntity(ent)
			util.Effect("lvs_muzzle_colorable", effectdata)

			ent:TakeAmmo()

			ent.PrimarySND:PlayOnce(100 + math.cos(CurTime() + ent:EntIndex() * 1337) * 5 + math.Rand(-1, 1), 1)
		end
		weapon.OnSelect = function(ent) ent:EmitSound("physics/metal/weapon_impact_soft3.wav") end
		weapon.OnOverheat = function(ent) ent:EmitSound("lvs/overheat.wav") end
		self:AddWeapon(weapon)

		-- BUZZ DROID MISSILES - Modifizierte Sekundärwaffe
		local weapon = {}
		weapon.Icon = Material("lvs/weapons/protontorpedo.png")
		weapon.Ammo = 4
		weapon.Delay = 0
		weapon.HeatRateUp = -0.5
		weapon.HeatRateDown = 0.25
		weapon.Attack = function(ent)
			local T = CurTime()

			if IsValid(ent._BuzzDroidMissile) then
				if (ent._nextMissleTracking or 0) > T then return end

				ent._nextMissleTracking = T + 0.1

				ent._BuzzDroidMissile:FindTarget(ent:GetPos(), ent:GetForward(), 30, 10000)

				return
			end

			if (ent._nextMissle or 0) > T then return end

			ent._nextMissle = T + 0.5

			ent._swapMissile = not ent._swapMissile

			local Pos = Vector(56.82, (ent._swapMissile and -105.6 or 105.6), 0)

			local Driver = self:GetDriver()

			-- Verwende die neue Buzz Droid Missile statt Concussion Missile
			local projectile = ents.Create("lvs_buzzdroid_missile")
			
			-- Fallback falls Entity nicht existiert
			if not IsValid(projectile) then
				projectile = ents.Create("lvs_concussionmissile")
			end
			
			if IsValid(projectile) then
				projectile:SetPos(ent:LocalToWorld(Pos))
				projectile:SetAngles(ent:GetAngles())
				projectile:SetParent(ent)
				projectile:Spawn()
				projectile:Activate()
				projectile:SetAttacker(IsValid(Driver) and Driver or self)
				projectile:SetEntityFilter(ent:GetCrosshairFilterEnts())

				ent._BuzzDroidMissile = projectile

				ent:SetNextAttack(CurTime() + 0.1)
			end
		end
		weapon.FinishAttack = function(ent)
			if not IsValid(ent._BuzzDroidMissile) then return end

			local projectile = ent._BuzzDroidMissile

			projectile:Enable()
			projectile:EmitSound("lvs/vehicles/vulturedroid/fire_missile.mp3", 125)
			ent:TakeAmmo()

			ent._BuzzDroidMissile = nil

			local NewHeat = ent:GetHeat() + 0.75

			ent:SetHeat(NewHeat)
			if NewHeat >= 1 then
				ent:SetOverheated(true)
			end
		end
		weapon.OnSelect = function(ent) ent:EmitSound("physics/metal/weapon_impact_soft3.wav") end
		weapon.OnOverheat = function(ent) ent:EmitSound("lvs/overheat.wav") end
		self:AddWeapon(weapon)

		-- Tertiärwaffe: Dual Laser (unverändert)
		local weapon = {}
		weapon.Icon = Material("lvs/weapons/dual_mg.png")
		weapon.Ammo = 400
		weapon.Delay = 0.15
		weapon.HeatRateUp = 0.5
		weapon.HeatRateDown = 1
		weapon.Attack = function(ent)
			local bullet = {}
			bullet.Dir = ent:GetForward()
			bullet.Spread = Vector(0.015, 0.015, 0)
			bullet.TracerName = "lvs_laser_red"
			bullet.Force = 10
			bullet.HullSize = 25
			bullet.Damage = 20
			bullet.Velocity = 60000
			bullet.Attacker = ent:GetDriver()
			bullet.Callback = function(att, tr, dmginfo)
				local effectdata = EffectData()
				effectdata:SetStart(Vector(255, 50, 50))
				effectdata:SetOrigin(tr.HitPos)
				effectdata:SetNormal(tr.HitNormal)
				util.Effect("lvs_laser_impact", effectdata)
			end

			for i = -1, 1, 2 do
				bullet.Src = ent:LocalToWorld(Vector(30, 15.2 * i, 6.5))

				local effectdata = EffectData()
				effectdata:SetStart(Vector(255, 50, 50))
				effectdata:SetOrigin(bullet.Src)
				effectdata:SetNormal(ent:GetForward())
				effectdata:SetEntity(ent)
				util.Effect("lvs_muzzle_colorable", effectdata)

				ent:LVSFireBullet(bullet)
			end

			ent:TakeAmmo()

			ent.SecondarySND:PlayOnce(100 + math.cos(CurTime() + ent:EntIndex() * 1337) * 5 + math.Rand(-1, 1), 1)
		end
		weapon.OnSelect = function(ent) ent:EmitSound("physics/metal/weapon_impact_soft3.wav") end
		weapon.OnOverheat = function(ent) end
		self:AddWeapon(weapon)
	end
	
	print("[EGC] Buzz Droid Missile System für Vulture Droid Blue aktiviert!")
end

-- Konsolenbefehl zum manuellen Neuladen
concommand.Add("egc_reload_buzzdroid_missiles", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	
	EGC_BuzzDroidMissile_Override()
	
	if IsValid(ply) then
		ply:ChatPrint("[EGC] Buzz Droid Missile System neu geladen!")
	end
	print("[EGC] Buzz Droid Missile System neu geladen!")
end)
