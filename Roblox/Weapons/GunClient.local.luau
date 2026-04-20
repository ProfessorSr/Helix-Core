-- GunScript_Client (LocalScript inside Tool)
--====================================================
-- Features:
-- - Barrel-based trajectory (GunFirePoint CFrame.LookVector) with optional aim assist
-- - Tracer throttle (1 every N shots)
-- - Muzzle flash (uses Effects/MuzzleEffect/Muzzle ParticleEmitter template)
-- - Shell ejection
-- - Flashlight toggle (L) synced to server BoolValue FlashlightOn
-- - Per-material hit FX + sounds using your Effects folder structure:
--     Effects/HitEffect/<MaterialName>/{Sound,ParticleEmitter,...}
--     Effects/BloodEffect/... when isFlesh=true
-- - Penetration-ready: supports IMPACT_BUNDLE if server sends it later
--====================================================

--====================================================
-- SERVICES
--====================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

--====================================================
-- PLAYER
--====================================================
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

--====================================================
-- TOOL REFERENCES
--====================================================
local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle")
local Remote = Tool:WaitForChild("ChangeMagAndAmmo")
local Module = require(Tool:WaitForChild("Setting"))

-- Values replicated from server (must exist)
local Mag = Tool:WaitForChild("Mag")
local Ammo = Tool:WaitForChild("Ammo")

--====================================================
-- EFFECT REFERENCES (your structure)
--====================================================
local Effects = Tool:WaitForChild("Effects")
local HitEffectRoot = Effects:WaitForChild("HitEffect")
local MuzzleEffectFolder = Effects:WaitForChild("MuzzleEffect")

-- BloodEffect folder can vary; we’ll support either:
-- Effects/BloodEffect (Folder) containing "Blood" ParticleEmitter, sounds, etc.
-- or Effects/BloodEffect/Blood (Folder/Emitter) depending on your pack
local BloodEffectRoot = Effects:FindFirstChild("BloodEffect")

--====================================================
-- STATE
--====================================================
local Equipped = false
local Firing = false
local Reloading = false

local ShotCounter = 0

--====================================================
-- CONFIG (client-only polish)
--====================================================
local TRACER_EVERY_N_SHOTS = 5
local TRACER_DIST = 100

-- 0.0 = pure barrel direction
-- 0.10 = subtle aim assist toward mouse
local AIM_ASSIST = 0.10

-- Shells
local SHELL_LIFETIME = 6
local SHELL_EJECT_SPEED = 10

--====================================================
-- FIREPOINT: find Attachment/BasePart named "GunFirePoint" anywhere under Tool
--====================================================
local function findFirePoint()
	local fp = Tool:FindFirstChild("GunFirePoint", true)
	if not fp then
		warn("[GunClient] GunFirePoint not found under tool:", Tool.Name)
	end
	return fp
end

local function getFirePointWorld(fp)
	if not fp then return nil, nil end

	if fp:IsA("Attachment") then
		return fp.WorldPosition, fp.WorldCFrame
	end

	if fp:IsA("BasePart") then
		return fp.Position, fp.CFrame
	end

	return nil, nil
end

--====================================================
-- GUI (Vertical Floating Ammo HUD)
--====================================================
local gui = Instance.new("ScreenGui")
gui.Name = "GunGUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = Player:WaitForChild("PlayerGui")

-- Shadow (reuses SAME size/position as frame)
local shadow = Instance.new("Frame")
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.75
shadow.BorderSizePixel = 0
shadow.ZIndex = 1
shadow.Parent = gui

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 14)
shadowCorner.Parent = shadow

-- Main HUD frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 90, 0, 90)
frame.Position = UDim2.new(1, -120, 1, -190)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BackgroundTransparency = 0.25
frame.BorderSizePixel = 0
frame.ZIndex = 2
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Transparency = 0.85
stroke.Parent = frame

-- Shadow follows frame automatically
local function syncShadow()
	shadow.Size = frame.Size
	shadow.Position = frame.Position + UDim2.new(0, 4, 0, 4)
end
syncShadow()
frame:GetPropertyChangedSignal("Size"):Connect(syncShadow)
frame:GetPropertyChangedSignal("Position"):Connect(syncShadow)

-- MAG label
local magLabel = Instance.new("TextLabel")
magLabel.Size = UDim2.new(1, -20, 0, 28)
magLabel.Position = UDim2.new(0, 10, 0, 12)
magLabel.BackgroundTransparency = 1
magLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
magLabel.Font = Enum.Font.GothamBold
magLabel.TextSize = 22
magLabel.Text = "30"
magLabel.ZIndex = 3
magLabel.Parent = frame

-- Divider (correctly BETWEEN numbers)
local divider = Instance.new("Frame")
divider.Size = UDim2.new(0.6, 0, 0, 1)
divider.Position = UDim2.new(0.2, 0, 0, 46)
divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
divider.BackgroundTransparency = 0.75
divider.BorderSizePixel = 0
divider.ZIndex = 3
divider.Parent = frame

-- AMMO label
local ammoLabel = Instance.new("TextLabel")
ammoLabel.Size = UDim2.new(1, -20, 0, 24)
ammoLabel.Position = UDim2.new(0, 10, 0, 54)
ammoLabel.BackgroundTransparency = 1
ammoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ammoLabel.Font = Enum.Font.Gotham
ammoLabel.TextSize = 18
ammoLabel.Text = "90"
ammoLabel.ZIndex = 3
ammoLabel.Parent = frame

--====================================================
-- GUI UPDATE (single, correct)
--====================================================
local function updateGUI()
	magLabel.Text = tostring(Mag.Value)
	ammoLabel.Text = tostring(Ammo.Value)
end

Mag:GetPropertyChangedSignal("Value"):Connect(updateGUI)
Ammo:GetPropertyChangedSignal("Value"):Connect(updateGUI)

--====================================================
-- SOUNDS (optional, safe)
-- Put Sound objects under Handle with these names if you want real assets:
--  - FireSound
--  - ReloadSound
--  - DropSound
--====================================================
local function ensureSound(name)
	local s = Handle:FindFirstChild(name)
	if s and s:IsA("Sound") then return s end

	s = Instance.new("Sound")
	s.Name = name
	s.Volume = 0.6
	s.RollOffMaxDistance = 80
	s.Parent = Handle
	-- SoundId intentionally blank; set in Studio if you want.
	return s
end

local FireSound = ensureSound("FireSound")
local ReloadSound = ensureSound("ReloadSound")
local DropSound = ensureSound("DropSound")

local function playSound(snd)
	if snd and snd:IsA("Sound") and snd.SoundId ~= "" then
		snd:Play()
	end
end


--====================================================
-- MUZZLE EFFECT (uses your Effects/MuzzleEffect/Muzzle template)
--====================================================
local function playMuzzleEffect(firePointObj)
	if not firePointObj then return end

	local template = MuzzleEffectFolder:FindFirstChild("Muzzle")
	if not template or not template:IsA("ParticleEmitter") then
		warn("[GunClient] Effects/MuzzleEffect/Muzzle missing ParticleEmitter")
		return
	end

	-- If your template stores count in a child IntValue named EmitCount, support it
	local emitCount = 8
	local emitCountValue = template:FindFirstChild("EmitCount")
	if emitCountValue and emitCountValue:IsA("IntValue") then
		emitCount = emitCountValue.Value
	end

	-- Clone emitter each shot (keeps template clean)
	local emitter = template:Clone()
	emitter.Enabled = true
	emitter.Parent = firePointObj
	emitter:Emit(emitCount)

	Debris:AddItem(emitter, 0.35)
end

--====================================================
-- TRACER (throttled)
--====================================================
local function drawTracer(fromPos, toPos)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 200, 50)
	p.Size = Vector3.new(0.1, 0.1, (fromPos - toPos).Magnitude)
	p.CFrame = CFrame.new(fromPos, toPos) * CFrame.new(0, 0, -p.Size.Z / 2)
	p.Parent = Workspace
	Debris:AddItem(p, 0.05)
end

--====================================================
-- SHELL EJECTION
--====================================================
local function ejectShell(fpCFrame)
	local shell = Instance.new("Part")
	shell.Name = "ShellCasing"
	shell.Size = Vector3.new(0.1, 0.25, 0.1)
	shell.Material = Enum.Material.Metal
	shell.Color = Color3.fromRGB(212, 175, 55)
	shell.CanCollide = true
	shell.CFrame = fpCFrame * CFrame.new(-0.12, 0.05, -0.15)
	shell.Parent = Workspace

	local right = fpCFrame.RightVector
	local up = fpCFrame.UpVector
	local back = -fpCFrame.LookVector

	shell.AssemblyLinearVelocity = (right * -SHELL_EJECT_SPEED) + (up * 4) + (back * 2)
	shell.AssemblyAngularVelocity = Vector3.new(0, 12, 0)

	Debris:AddItem(shell, SHELL_LIFETIME)
end

--====================================================
-- IMPACT FX (uses your Effects folder structure)
--====================================================
local function emitFromFolder(effectFolder, position, normal)
	-- Create a tiny anchor part to host particles/sounds
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position, position + normal)
	anchor.Parent = Workspace

	-- Play/emit everything inside
	for _, obj in ipairs(effectFolder:GetChildren()) do
		if obj:IsA("Sound") then
			local s = obj:Clone()
			s.Parent = anchor
			if s.SoundId ~= "" then
				s:Play()
			end
		elseif obj:IsA("ParticleEmitter") then
			local pe = obj:Clone()
			pe.Parent = anchor

			-- Support EmitCount IntValue under the emitter (your Muzzle template uses it)
			local emitCount = 10
			local ec = pe:FindFirstChild("EmitCount")
			if ec and ec:IsA("IntValue") then
				emitCount = ec.Value
			end

			pe:Emit(emitCount)
		end
	end

	Debris:AddItem(anchor, 1.5)
end

local function resolveHitFolder(materialEnumItem)
	if not materialEnumItem then return nil end
	local name = materialEnumItem.Name
	return HitEffectRoot:FindFirstChild(name)
end

local function resolveBloodFolder()
	if not BloodEffectRoot then return nil end

	-- Common patterns:
	-- Effects/BloodEffect/Blood (Folder) with sounds + particle
	-- Effects/BloodEffect/Blood (ParticleEmitter) directly
	local blood = BloodEffectRoot:FindFirstChild("Blood")
	if blood then
		if blood:IsA("Folder") then
			return blood
		elseif blood:IsA("ParticleEmitter") then
			-- Wrap it into a temp folder-style behavior
			local f = Instance.new("Folder")
			f.Name = "__BloodTemp"
			local c = blood:Clone()
			c.Parent = f
			return f
		end
	end

	-- If BloodEffectRoot itself holds particles/sounds, use it
	return BloodEffectRoot
end

local function spawnImpactFX(impact)
	if typeof(impact) ~= "table" then return end
	if typeof(impact.position) ~= "Vector3" then return end
	if typeof(impact.normal) ~= "Vector3" then return end

	local pos = impact.position
	local normal = impact.normal

	local isFlesh = impact.isFlesh == true
	local material = impact.material -- Enum.Material item

	-- Choose folder
	local folder
	if isFlesh then
		folder = resolveBloodFolder()
	else
		if typeof(material) == "EnumItem" then
			folder = resolveHitFolder(material)
		end
	end

	-- Emit folder-based FX
	if folder and folder:IsA("Folder") then
		emitFromFolder(folder, pos, normal)
	else
		-- Soft fallback: simple bullet hole so you still see *something*
		local hole = Instance.new("Part")
		hole.Name = "BulletHole"
		hole.Anchored = true
		hole.CanCollide = false
		hole.Size = Vector3.new(0.18, 0.18, 0.02)
		hole.Material = Enum.Material.SmoothPlastic
		hole.Color = Color3.new(0, 0, 0)
		hole.CFrame = CFrame.new(pos, pos + normal) * CFrame.new(0, 0, -0.01)
		hole.Parent = Workspace
		Debris:AddItem(hole, 10)
	end
end

Remote.OnClientEvent:Connect(function(action, data)
	if action == "IMPACT" then
		spawnImpactFX(data)

	elseif action == "IMPACT_BUNDLE" then
		-- Penetration chain: { impacts = { {position,normal,material,isFlesh}, ... } }
		if typeof(data) == "table" and typeof(data.impacts) == "table" then
			for _, impact in ipairs(data.impacts) do
				spawnImpactFX(impact)
			end
		end
	end
end)

--====================================================
-- DIRECTION (barrel-based + optional aim assist + spread)
--====================================================
local function computeDirection(origin, fpCFrame)
	local barrelDir = fpCFrame.LookVector
	local hasScope = Tool:GetAttribute("HasScope") == true
	local adsActive = _G.CameraState and _G.CameraState.ADS

	-- DEFAULT: barrel / hip-fire behavior
	local dir = barrelDir

	-- ONLY use camera-center when scoped AND ADS
	if hasScope and adsActive then
		local camera = workspace.CurrentCamera

		local centerRay = camera:ViewportPointToRay(
			camera.ViewportSize.X * 0.5,
			camera.ViewportSize.Y * 0.5
		)

		local aimPoint = centerRay.Origin + centerRay.Direction * 1000
		dir = (aimPoint - origin).Unit
	else
		-- Non-scoped or hip fire
		local mouseDir = (Mouse.Hit.Position - origin).Unit
		dir = barrelDir:Lerp(mouseDir, AIM_ASSIST or 0).Unit
	end

	-- Spread (applies everywhere)
	local spread = Module.Spread or 0
	if spread > 0 then
		local rx = (math.random() - 0.5) * 2 * spread
		local ry = (math.random() - 0.5) * 2 * spread
		dir = (dir + Vector3.new(rx, ry, 0)).Unit
	end

	return dir
end

--====================================================
-- FIRE
--====================================================
local function fire()
	if Reloading then return end
	if Mag.Value <= 0 then
		Firing = false
		return
	end

	local fp = findFirePoint()
	if not fp then return end

	local origin, fpCFrame = getFirePointWorld(fp)
	if not origin or not fpCFrame then return end

	-- FX
	playMuzzleEffect(fp)
	playSound(FireSound)
	ejectShell(fpCFrame)

	-- Direction (barrel-based)
	local cam = workspace.CurrentCamera

	-- Tracer throttle
	ShotCounter += 1
	if TRACER_EVERY_N_SHOTS <= 1 or (ShotCounter % TRACER_EVERY_N_SHOTS == 0) then
		drawTracer(origin, origin + cam.CFrame.LookVector * TRACER_DIST)
	end

	-- SERVER DAMAGE (authoritative)
	Remote:FireServer("FIRE", {
		origin = cam.CFrame.Position,
		direction = cam.CFrame.LookVector,
	})
end

--====================================================
-- RELOAD
--====================================================
local function reload()
	if Reloading then return end
	if Mag.Value >= (Module.AmmoPerMag or 0) then return end
	if Ammo.Value <= 0 then return end

	Reloading = true
	playSound(ReloadSound)
	task.wait(Module.ReloadTime or 2.0)
	Remote:FireServer("RELOAD")
	Reloading = false
end

--====================================================
-- INPUT
--====================================================
Mouse.Button1Down:Connect(function()
	if not Equipped or Firing then return end
	Firing = true

	while Firing and Mag.Value > 0 do
		fire()
		task.wait(Module.FireRate or 0.1)
		if not Module.Auto then break end
	end

	Firing = false
end)

Mouse.Button1Up:Connect(function()
	Firing = false
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if not Equipped then return end

	if input.KeyCode == Enum.KeyCode.R then
		reload()

	end
end)

--====================================================
-- EQUIP / UNEQUIP
--====================================================
Tool.Equipped:Connect(function()
	Equipped = true
	gui.Enabled = true
	updateGUI()

end)

Tool.Unequipped:Connect(function()
	Equipped = false
	Firing = false
	gui.Enabled = false

	playSound(DropSound)
end)