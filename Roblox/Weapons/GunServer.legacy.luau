-- GunScript_Server (Script inside Tool)
--====================================================
-- Responsibilities:
-- - Authoritative ammo + reload handling
-- - Authoritative raycast
-- - Humanoid damage + headshot multiplier
-- - Vehicle damage (VehicleHealth attribute on VehicleSeat/DriveSeat)
-- - Detachable part damage with controlled bleed-through
--====================================================

--====================================================
-- SAFETY
--====================================================
local Tool = script.Parent
assert(Tool:IsA("Tool"), "GunScript_Server must be inside a Tool")
local GUNSERVER_VERSION = "layered-hitbounds-v2"

print(string.format("✅ [GunServer] Script started for tool: %s | Version=%s", Tool.Name, GUNSERVER_VERSION))

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

--====================================================
-- SERVICES
--====================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

--====================================================
-- MODULES & REMOTES
--====================================================
local Module = require(Tool:WaitForChild("Setting"))
local Remote = Tool:WaitForChild("ChangeMagAndAmmo")

local RuntimeEntrypoint = nil
local BootState = nil
do
	local ok, runtimeOrErr = pcall(function()
		return require(
			ServerScriptService
				:WaitForChild("Helix")
				:WaitForChild("Runtime")
				:WaitForChild("RuntimeEntrypoint")
		)
	end)
	if ok and type(runtimeOrErr) == "table" then
		RuntimeEntrypoint = runtimeOrErr
	else
		warn("[GunServer] Helix RuntimeEntrypoint unavailable, falling back to Workspace:Raycast")
	end
end

do
	local ok, bootOrErr = pcall(function()
		return require(
			ServerScriptService
				:WaitForChild("Helix")
				:WaitForChild("Runtime")
				:WaitForChild("BootState")
		)
	end)
	if ok and type(bootOrErr) == "table" then
		BootState = bootOrErr
	end
end

local function ensureHelixRuntimeReady(timeoutSeconds)
	if not BootState or not BootState.WaitForReady then
		return RuntimeEntrypoint ~= nil
	end
	local ok, err = BootState:WaitForReady(timeoutSeconds or 10)
	if not ok then
		warn("[GunServer] Helix runtime not ready:", tostring(err))
		return false
	end
	return RuntimeEntrypoint ~= nil
end

--====================================================
-- SERVER-OWNED VALUES
--====================================================
local Mag = Tool:WaitForChild("Mag")
local Ammo = Tool:WaitForChild("Ammo")

local FlashlightOn = Tool:FindFirstChild("FlashlightOn")
if not FlashlightOn then
	FlashlightOn = Instance.new("BoolValue")
	FlashlightOn.Name = "FlashlightOn"
	FlashlightOn.Parent = Tool
end

--====================================================
-- INITIAL STATE
--====================================================
Mag.Value = Module.AmmoPerMag or 30
Ammo.Value = (Module.LimitedAmmoEnabled and Module.Ammo) or 0
FlashlightOn.Value = false

--====================================================
-- HUD SYNC (NON-GAMEPLAY)
--====================================================
local function syncHUD()
	local ammoPerMag = Module.AmmoPerMag or Mag.Value
	local currentAmmo = Mag.Value
	local reserveAmmo = Ammo.Value

	Tool:SetAttribute("AmmoPerMag", ammoPerMag)
	Tool:SetAttribute("CurrentAmmo", currentAmmo)
	Tool:SetAttribute("ReserveAmmo", reserveAmmo)

	print(string.format(
		"[GunServer HUD SYNC] %s | AmmoPerMag=%d | CurrentAmmo=%d | ReserveAmmo=%d",
		Tool.Name,
		ammoPerMag,
		currentAmmo,
		reserveAmmo
		))
end

-- initial sync
syncHUD()

-- re-sync on equip (client-safe)
Tool.Equipped:Connect(syncHUD)

--====================================================
-- DEBUG
--====================================================
local DEBUG_PRINT_HITS = true
local DEBUG_PRINT_NO_HIT = true
local DEBUG_ALLOW_SELF_HIT = false
local DEBUG_DRAW_HELIX_BOUNDS = true

--====================================================
-- DETACH CONFIG
--====================================================
local DEFAULT_DETACH_HP = 60
local DETACH_IMPULSE = 35
local BLEED_THROUGH = Module.VehicleBleedThrough or 0.35
--====================================================
-- BULLET MARK CONFIG
--====================================================


local BULLET_INSET = 0.005
local BULLET_LIFETIME = 60

-- ReplicatedStorage/BulletMarks/
--   ├─ BulletHole (Decal)
--   └─ GlassCrack (Decal)
local BulletAssets =
	game:GetService("ReplicatedStorage"):WaitForChild("BulletMarks")


--====================================================
-- VALIDATION
--====================================================
local function ownsTool(player)
	return player and player.Character and Tool.Parent == player.Character
end

--====================================================
-- TAG RESOLUTION (RECURSIVE)
--====================================================
local function hasTagRecursive(part, tag)
	local current = part
	while current do
		if CollectionService:HasTag(current, tag) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isGlassLikePart(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if string.lower(part.Name) == "front windshield_basepart" then
		-- Explicit collision proxy: must block shots, never treated as pass-through glass.
		return false
	end
	local lowerName = string.lower(part.Name)
	if hasTagRecursive(part, "Damage_Glass") then
		return true
	end
	if part.Material == Enum.Material.Glass then
		return true
	end
	if string.find(lowerName, "glass", 1, true) or string.find(lowerName, "windshield", 1, true) then
		return true
	end
	return false
end

local function isWindshieldProxyPart(part)
	return part
		and part:IsA("BasePart")
		and string.lower(part.Name) == "front windshield_basepart"
end

local function findWindshieldProxyInModel(part)
	if not part then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local proxy = model:FindFirstChild("Front Windshield_BasePart", true)
	if proxy and proxy:IsA("BasePart") then
		return proxy
	end
	return nil
end

local function findVisualWindshieldMeshForProxy(proxyPart)
	if not proxyPart then
		return nil
	end
	local model = proxyPart:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end

	local exact = model:FindFirstChild("Front Windshield", true)
	if exact and exact:IsA("MeshPart") then
		return exact
	end

	local descendants = model:GetDescendants()
	for i = 1, #descendants do
		local inst = descendants[i]
		if inst:IsA("MeshPart") then
			local n = string.lower(inst.Name)
			if string.find(n, "windshield", 1, true) ~= nil
				and string.find(n, "_basepart", 1, true) == nil then
				return inst
			end
		end
	end

	return nil
end

local function rayIntersectProxyOBB(part, origin, unitDirection, maxDistance)
	if not part or not part:IsA("BasePart") then
		return nil
	end

	local localOrigin = part.CFrame:PointToObjectSpace(origin)
	local localDir = part.CFrame:VectorToObjectSpace(unitDirection)
	local half = part.Size * 0.5

	local tMin = 0
	local tMax = maxDistance
	local hitAxis = nil
	local hitSign = 0

	local function slab(axisName, o, d, h)
		if math.abs(d) < 1e-6 then
			if o < -h or o > h then
				return false
			end
			return true
		end

		local inv = 1 / d
		local t1 = (-h - o) * inv
		local t2 = (h - o) * inv
		local nearT = math.min(t1, t2)
		local farT = math.max(t1, t2)
		local nearSign = (t1 < t2) and -1 or 1

		if nearT > tMin then
			tMin = nearT
			hitAxis = axisName
			hitSign = nearSign
		end
		tMax = math.min(tMax, farT)
		if tMin > tMax then
			return false
		end
		return true
	end

	if not slab("X", localOrigin.X, localDir.X, half.X) then
		return nil
	end
	if not slab("Y", localOrigin.Y, localDir.Y, half.Y) then
		return nil
	end
	if not slab("Z", localOrigin.Z, localDir.Z, half.Z) then
		return nil
	end
	if tMax < 0 then
		return nil
	end

	local hitDistance = tMin
	if hitDistance < 0 then
		hitDistance = tMax
	end
	if hitDistance < 0 or hitDistance > maxDistance then
		return nil
	end

	local localNormal
	if hitAxis == "X" then
		localNormal = Vector3.new(hitSign, 0, 0)
	elseif hitAxis == "Y" then
		localNormal = Vector3.new(0, hitSign, 0)
	else
		localNormal = Vector3.new(0, 0, hitSign)
	end

	local worldPos = origin + unitDirection * hitDistance
	local worldNormal = part.CFrame:VectorToWorldSpace(localNormal)
	return {
		Distance = hitDistance,
		Position = worldPos,
		Normal = worldNormal.Unit,
	}
end

local function raycastProxyOnly(proxyPart, origin, unitDirection, maxDistance)
	if not proxyPart or not proxyPart:IsA("BasePart") then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { proxyPart }
	params.IgnoreWater = true
	return Workspace:Raycast(origin, unitDirection * maxDistance, params)
end
--====================================================
-- BULLET MARK CLEANUP ON DETACH
--====================================================
local function bindDetachCleanup(part, decal)
	if part:GetAttribute("Detached") then
		decal:Destroy()
		return
	end

	part:GetAttributeChangedSignal("Detached"):Connect(function()
		if part:GetAttribute("Detached") then
			decal:Destroy()
		end
	end)
end


local function createBulletHole(hitPart, hitPos, hitNormal, isFlesh)
	if not hitPart:IsA("BasePart") then return end
	if hitPart.Transparency >= 1 then return end

	-- Decide glass vs solid
	local isGlass =
		hasTagRecursive(hitPart, "Damage_Glass")
		or hitPart.Material == Enum.Material.Glass

	local template

	if isFlesh then
		template = BulletAssets:FindFirstChild("FleshHit")
		print("🔍 [createBulletHole] Looking for FleshHit template")
	else
		template =
			isGlass and BulletAssets:FindFirstChild("GlassCrack")
			or BulletAssets:FindFirstChild("BulletHole")
		print("🔍 [createBulletHole] Looking for template - isGlass:", isGlass)
	end

	if not template then
		warn("⚠️ Bullet decal template missing")
		return
	end
	
	print("✅ [createBulletHole] Template found:", template.Name)
	print("🎯 [createBulletHole] Raycast hit position:", hitPos)
	print("📐 [createBulletHole] Hit normal:", hitNormal)
	print("📦 [createBulletHole] Hit part size:", hitPart.Size)
	if hitPart:IsA("MeshPart") then
		print("🧱 [createBulletHole] Hit CollisionFidelity:", tostring(hitPart.CollisionFidelity))
	end

	-- Invisible anchor that sticks to the surface.
	local anchor = Instance.new("Part")
	anchor.Name = "BulletMarkAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false

	-- Random rotation so marks don’t repeat
	local randomRoll = math.rad(math.random(0, 360))

	-- Place slightly above the surface to avoid z-fighting.
	local offset = hitNormal * 0.002
	local lookDirection = hitNormal
	anchor.CFrame = CFrame.lookAt(hitPos + offset, hitPos + offset + lookDirection)
		* CFrame.fromAxisAngle(Vector3.new(0, 0, 1), randomRoll)

	anchor.Parent = hitPart

	-- Weld anchor to the vehicle part
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = hitPart
	weld.Parent = anchor

	-- Clone decal
	local decal = template:Clone()
	decal.Face = Enum.NormalId.Front
	decal.Parent = anchor
	
	print("✅ [createBulletHole] Decal created and parented to anchor")
	print("📍 [createBulletHole] Anchor position:", anchor.Position)
	print("🎯 [createBulletHole] Hit part:", hitPart.Name, "Material:", hitPart.Material.Name)

	-- Cleanup
	--	Debris:AddItem(anchor, BULLET_LIFETIME)
	bindDetachCleanup(hitPart, decal)
	
	print("🏁 [createBulletHole] Function completed successfully")
end

--====================================================
-- VEHICLE HELPERS
--====================================================
local function getVehicleSeatFromPart(part)
	local current = part
	while current do
		if current:IsA("Model") then
			for _, d in ipairs(current:GetChildren()) do
				if d:IsA("VehicleSeat") or d.Name == "DriveSeat" then
					return d
				end
			end
		end
		current = current.Parent
	end
	return nil
end



--====================================================
-- RAYCAST
--====================================================
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true
local weaponBallisticsConfigured = false
local weaponBallisticsRetryScheduled = false

local function configureWeaponBallistics()
	if not ensureHelixRuntimeReady(10) then
		return false, "runtime_not_ready"
	end
	if not RuntimeEntrypoint or not RuntimeEntrypoint.ConfigureWeaponBallistics then
		return false, "runtime_unavailable"
	end

	local ok, err = RuntimeEntrypoint:ConfigureWeaponBallistics(Tool.Name, {
		Capacity = 512,
		Speed = Module.BulletSpeed or 3000,
		MaxDistance = Module.Range or 5000,
		StepDistance = Module.BallisticStepDistance or 0.5,
	})
	if not ok then
		warn(string.format("[GunServer] Failed to configure Helix ballistics for %s: %s", Tool.Name, tostring(err)))
		return false, err
	end
	weaponBallisticsConfigured = true
	print(string.format("[GunServer] Helix ballistics configured for %s", Tool.Name))
	return true, nil
end

local function ensureWeaponBallisticsConfigured()
	if weaponBallisticsConfigured then
		return
	end
	local ok = configureWeaponBallistics()
	if ok then
		return
	end
	if weaponBallisticsRetryScheduled then
		return
	end
	weaponBallisticsRetryScheduled = true
	task.spawn(function()
		for _ = 1, 10 do
			task.wait(0.5)
			local retryOk = configureWeaponBallistics()
			if retryOk then
				break
			end
		end
		weaponBallisticsRetryScheduled = false
	end)
end

ensureWeaponBallisticsConfigured()

local function auditMeshHitBounds()
	if not RuntimeEntrypoint or not RuntimeEntrypoint.GetHelixBoundsForInstance then
		return
	end
	ensureHelixRuntimeReady(0)
	local missing = {}
	local checked = 0
	local descendants = Workspace:GetDescendants()
	for i = 1, #descendants do
		local inst = descendants[i]
		if inst:IsA("MeshPart") and inst.CanQuery == true then
			checked += 1
			local info = RuntimeEntrypoint:GetHelixBoundsForInstance(inst)
			local hitShape = info and info.HitBounds and info.HitBounds.Shape or nil
			if hitShape ~= "TriangleMesh" and hitShape ~= "Compound" then
				missing[#missing + 1] = inst:GetFullName()
			end
		end
	end
	print(string.format(
		"🧭 [GunServer][%s] HitBounds audit checked=%d missing_or_invalid=%d",
		GUNSERVER_VERSION,
		checked,
		#missing
	))
	local limit = math.min(#missing, 25)
	for i = 1, limit do
		print(string.format("🧭 [GunServer] Missing/invalid HitBounds: %s", missing[i]))
	end
	if #missing > limit then
		print(string.format("🧭 [GunServer] ...and %d more", #missing - limit))
	end
end

task.delay(6, auditMeshHitBounds)

--====================================================
-- PROTECT VEHICLE CONTROL PARTS FROM BULLETS
--====================================================
local function isProtectedVehiclePart(part)
	if not part then return false end

	-- Never allow bullets to affect the seat directly
	if part:IsA("VehicleSeat") or part.Name == "DriveSeat" then
		return true
	end

	-- Protect anything welded to the seat
	local weld = part:FindFirstAncestorWhichIsA("WeldConstraint")
	if weld then
		local p0 = weld.Part0
		local p1 = weld.Part1
		if p0 and (p0:IsA("VehicleSeat") or p0.Name == "DriveSeat") then
			return true
		end
		if p1 and (p1:IsA("VehicleSeat") or p1.Name == "DriveSeat") then
			return true
		end
	end

	-- Protect dashboard / gauges / scripts
	if part:FindFirstAncestor("Dashboard")
		or part:FindFirstAncestor("Gauges")
		or part:FindFirstAncestor("InstrumentCluster") then
		return true
	end

	return false
end

--====================================================
-- BULLET PROCESSING
--====================================================
local function processBullet(player, origin, direction)
	ensureWeaponBallisticsConfigured()
	local unitDirection = direction.Unit
	local baseFilter = DEBUG_ALLOW_SELF_HIT and { Tool } or { Tool, player.Character }
	local activeFilter = table.clone(baseFilter)
	local maxDistance = Module.Range or 5000

	local function raycastWithHelixOrFallback(filterList)
		RayParams.FilterDescendantsInstances = filterList
		if RuntimeEntrypoint and RuntimeEntrypoint.FireWeaponBallistics then
			local result, err = RuntimeEntrypoint:FireWeaponBallistics(Tool.Name, {
				Origin = origin,
				Direction = unitDirection,
				MaxDistance = maxDistance,
				RaycastParams = RayParams,
			})
			if result then
				if result.Hit then
					return {
						Instance = result.Instance,
						Position = result.Position,
						Normal = result.Normal,
						Material = result.Material,
					}
				end
				return nil
			end
			warn("[GunServer] FireWeaponBallistics failed, fallback to Workspace:Raycast:", tostring(err))
		end
		return Workspace:Raycast(origin, unitDirection * maxDistance, RayParams)
	end

	local result = raycastWithHelixOrFallback(activeFilter)
	if not result then
		if DEBUG_PRINT_NO_HIT then
			print("❌ [GunServer] Raycast hit NOTHING")
		end
		return
	end

	local hitPart = result.Instance
	local visualHitPart = hitPart
	local remappedToWindshieldProxy = false

	-- Proxy override:
	-- If Workspace raycast sees an explicit windshield proxy first, force that hit.
	-- This keeps shots from tunneling to interior geometry when Helix hit data is stale/missing.
	do
		local workspaceResult = Workspace:Raycast(origin, unitDirection * maxDistance, RayParams)
		if workspaceResult and workspaceResult.Instance and isWindshieldProxyPart(workspaceResult.Instance) then
			result = workspaceResult
			hitPart = workspaceResult.Instance
			print("🎯 [GunServer] Forced windshield proxy hit:", hitPart:GetFullName())
		end
	end

	-- Geometry-forced proxy hit:
	-- If current hit is inside a vehicle and the ray crosses windshield proxy before
	-- current impact distance, force proxy as the hit target.
	do
		local proxy = findWindshieldProxyInModel(hitPart)
		if proxy and not isWindshieldProxyPart(hitPart) then
			local currentDist = maxDistance
			if result and result.Position then
				currentDist = (result.Position - origin).Magnitude
			end

			-- Deterministic override: direct raycast against proxy only.
			local proxyRay = raycastProxyOnly(proxy, origin, unitDirection, maxDistance)
			if proxyRay and proxyRay.Position then
				local proxyDist = (proxyRay.Position - origin).Magnitude
				if proxyDist <= currentDist + 0.01 then
					hitPart = proxy
					result = {
						Instance = proxy,
						Position = proxyRay.Position,
						Normal = proxyRay.Normal,
						Material = proxy.Material,
					}
					print("🎯 [GunServer] Proxy-only forced windshield hit:", proxy:GetFullName())
					currentDist = proxyDist
				end
			end

			local proxyHit = rayIntersectProxyOBB(proxy, origin, unitDirection, maxDistance)
			if proxyHit and proxyHit.Distance <= currentDist + 0.01 then
				hitPart = proxy
				result = {
					Instance = proxy,
					Position = proxyHit.Position,
					Normal = proxyHit.Normal,
					Material = proxy.Material,
				}
				print("🎯 [GunServer] Geometry-forced windshield proxy hit:", proxy:GetFullName())
			end
		end
	end

	-- Create a list of problematic parts to ignore
	local problematicParts = {
		"Side Body Panels",
		"ClickDet"
	}
	
	-- Check if we hit a problematic part
	local isProblematic = false
	for _, partName in pairs(problematicParts) do
		if string.find(hitPart.Name, partName) then
			isProblematic = true
			break
		end
	end
	
	-- Also ignore small indicator parts
	if string.find(hitPart.Name, "Indicators") or string.find(hitPart.Name, "LN") then
		isProblematic = true
	end
	
	-- If we hit a problematic part, filter it out and retry
		if isProblematic then
			table.insert(activeFilter, hitPart)
			local retryResult = raycastWithHelixOrFallback(activeFilter)
			if retryResult then
				result = retryResult
				hitPart = retryResult.Instance
				visualHitPart = hitPart
				print("🎯 [GunServer] Ignored problematic part, hit:", hitPart.Name)
			else
			print("❌ [GunServer] No alternative hit found after filtering")
			return
		end
	end
	
	-- Final check: if we still hit something problematic, try one more time with a more aggressive filter
	if string.find(hitPart.Name, "Side Body Panels") or string.find(hitPart.Name, "ClickDet") then
		local carModel = hitPart:FindFirstAncestorOfClass("Model")
		if carModel then
			-- Filter out ALL problematic parts from this car
			local aggressiveFilter = table.clone(RayParams.FilterDescendantsInstances)
			for _, descendant in pairs(carModel:GetDescendants()) do
				if descendant:IsA("BasePart") then
					if string.find(descendant.Name, "Side Body Panels") or 
					   string.find(descendant.Name, "ClickDet") or
					   string.find(descendant.Name, "Indicators") or
					   string.find(descendant.Name, "LN") then
						aggressiveFilter[#aggressiveFilter + 1] = descendant
					end
				end
			end
			
				local finalResult = raycastWithHelixOrFallback(aggressiveFilter)
				if finalResult then
					result = finalResult
					hitPart = finalResult.Instance
					visualHitPart = hitPart
					print("🎯 [GunServer] Aggressive filter successful, hit:", hitPart.Name)
				else
				print("❌ [GunServer] Even aggressive filter failed")
				return
			end
		end
	end

	-- Windshield trim resolver:
	-- If we hit trim first, cast through that part once to find actual glass behind it.
	do
		local hitNameLower = string.lower(hitPart.Name)
		if isWindshieldProxyPart(hitPart) then
			hitNameLower = ""
		end
		local isTrimProxy = string.find(hitNameLower, "trim", 1, true) ~= nil
			and (string.find(hitNameLower, "windshield", 1, true) ~= nil or string.find(hitNameLower, "glass", 1, true) ~= nil)
		if isTrimProxy and not isGlassLikePart(hitPart) then
			local passFilter = table.clone(activeFilter)
			passFilter[#passFilter + 1] = hitPart
			local passResult = raycastWithHelixOrFallback(passFilter)
				if passResult and passResult.Instance and isGlassLikePart(passResult.Instance) then
					result = passResult
					hitPart = passResult.Instance
					visualHitPart = hitPart
					activeFilter = passFilter
					print("🎯 [GunServer] Windshield trim pass-through hit:", hitPart:GetFullName())
				end
		end
	end

	-- Hard remap fallback:
	-- If a windshield-related mesh is hit but model has explicit windshield proxy,
	-- use proxy for collision/damage while keeping visual target for decals.
	do
		local lower = string.lower(hitPart.Name)
		local windshieldLike = string.find(lower, "windshield", 1, true) ~= nil
			or string.find(lower, "glassfint", 1, true) ~= nil
		if windshieldLike and not isWindshieldProxyPart(hitPart) then
			local proxy = findWindshieldProxyInModel(hitPart)
			if proxy then
				visualHitPart = hitPart
				hitPart = proxy
				remappedToWindshieldProxy = true
				print("🎯 [GunServer] Remapped hit to windshield proxy:", proxy:GetFullName())
			end
		end
	end
	
	local hitHumanoid =
		hitPart:FindFirstAncestorOfClass("Model")
		and hitPart:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")
	
	-- 🚫 HARD STOP: bullets may NOT affect control parts
	if isProtectedVehiclePart(hitPart) then
		if DEBUG_PRINT_HITS then
			print("🛡️ [GunServer] Protected vehicle part hit, ignoring:", hitPart:GetFullName())
		end
		return
	end
	local hitPos = result.Position
	local hitNormal = result.Normal
	local refinedHit = false

	-- Refine hit point/normal against Helix triangle mesh bounds when available.
	-- This keeps decals aligned to baked hull triangles instead of box proxies.
	if RuntimeEntrypoint and RuntimeEntrypoint.RefineHitOnHelixBounds then
		local refined, refineErr = RuntimeEntrypoint:RefineHitOnHelixBounds(
			hitPart,
			origin,
			unitDirection,
			maxDistance
		)
		if refined and refined.Position and refined.Normal then
			hitPos = refined.Position
			hitNormal = refined.Normal
			refinedHit = true
			print(string.format(
				"🧭 [GunServer] Refined hit on Helix mesh hull: %s (dist=%.3f)",
				hitPart:GetFullName(),
				tonumber(refined.Distance) or -1
			))
		elseif refineErr then
			print(string.format(
				"🧭 [GunServer] Helix hit refine unavailable for %s (%s)",
				hitPart:GetFullName(),
				tostring(refineErr)
			))
		end
	end

	if DEBUG_DRAW_HELIX_BOUNDS and RuntimeEntrypoint then
		ensureHelixRuntimeReady(0)
		if RuntimeEntrypoint.GetHelixBoundsForInstance then
			local info, infoErr = RuntimeEntrypoint:GetHelixBoundsForInstance(hitPart)
			if info and (type(info.HitBounds) == "table" or type(info.Bounds) == "table") then
				local shape = tostring((info.Bounds and info.Bounds.Shape) or "nil")
				local hitShape = tostring((info.HitBounds and info.HitBounds.Shape) or "nil")
				local decomp = info.HostMeta and info.HostMeta.HasDecomposition == true
				local fallback = info.HostMeta and info.HostMeta.UsingFallbackBounds == true
				print(string.format(
					"🧭 [GunServer][%s] HelixBounds Part=%s EntityId=%s Shape=%s HitShape=%s Decomp=%s Fallback=%s",
					GUNSERVER_VERSION,
					hitPart:GetFullName(),
					tostring(info.EntityId),
					shape,
					hitShape,
					tostring(decomp),
					tostring(fallback)
				))
			else
				print(string.format(
					"🧭 [GunServer] HelixBounds missing for %s (%s)",
					hitPart:GetFullName(),
					tostring(infoErr)
				))
			end
		end
		if RuntimeEntrypoint.DebugDrawHelixBoundsForInstance then
			local drawOk, drawErr = RuntimeEntrypoint:DebugDrawHelixBoundsForInstance(hitPart, 2.5)
			if not drawOk then
				print(string.format(
					"🧭 [GunServer] HelixBounds draw failed for %s (%s)",
					hitPart:GetFullName(),
					tostring(drawErr)
				))
			end
		end
	end

	local isFlesh = hitHumanoid ~= nil
	local decalPart = hitPart
	local usingProxyForDecal = false
	if isWindshieldProxyPart(hitPart) then
		local visualMesh = findVisualWindshieldMeshForProxy(hitPart)
		if visualMesh then
			decalPart = visualMesh
			usingProxyForDecal = true
		elseif visualHitPart and visualHitPart ~= hitPart then
			decalPart = visualHitPart
			usingProxyForDecal = true
		end
	end
	local shouldPlaceDecal = true
	if decalPart:IsA("MeshPart") and not isFlesh and not refinedHit and not remappedToWindshieldProxy and not usingProxyForDecal then
		-- Strict mesh decal policy:
		-- do not place bullet marks on mesh parts unless HitBounds refinement succeeds.
		shouldPlaceDecal = false
		print(string.format(
			"🧭 [GunServer] Skipping decal on mesh part without refined HitBounds: %s",
			decalPart:GetFullName()
		))
	end
	if shouldPlaceDecal then
		createBulletHole(decalPart, hitPos, hitNormal, isFlesh)
	end

	if DEBUG_PRINT_HITS then
		print("🎯 [GunServer] Hit:", hitPart:GetFullName())
	end

	local hitModel = hitPart:FindFirstAncestorOfClass("Model")
	local hitHumanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
	
	local function spawnBloodFX(position, normal)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.CFrame = CFrame.new(position, position + normal)
		part.Parent = workspace

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(140, 0, 0))
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0)
		})
		emitter.Lifetime = NumberRange.new(0.15, 0.3)
		emitter.Speed = NumberRange.new(6, 10)
		emitter.Rate = 0
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = part

		emitter:Emit(8)
		Debris:AddItem(part, 0.5)
	end

	--==============================
	-- HUMANOID DAMAGE
	--==============================
	if hitHumanoid and hitHumanoid.Health > 0 then
		local baseDamage = Module.Damage or 25
		local isHeadshot = (hitPart.Name == "Head")

		local damage = isHeadshot and baseDamage * 2 or baseDamage
		local oldHP = hitHumanoid.Health

		hitHumanoid:TakeDamage(damage)
		spawnBloodFX(hitPos, hitNormal)
		
		local newHP = math.max(0, hitHumanoid.Health)

		local targetPlayer = Players:GetPlayerFromCharacter(hitModel)
		local targetName = targetPlayer and targetPlayer.Name or hitModel.Name

		print(string.format(
			"🩸 [HUMANOID HIT] %s | Hit=%s | -%.0f HP (%.0f → %.0f)",
			targetName,
			hitPart.Name,
			damage,
			oldHP,
			newHP
			))

		if newHP <= 0 then
			print("💀 [HUMANOID DEAD]", targetName)
		end

		return -- ⛔ DO NOT continue into vehicle logic
	end
	
	

	--==============================
	-- VEHICLE RESOLUTION
	--==============================
	local seat = getVehicleSeatFromPart(hitPart)
	if not seat then return end

	-- Ensure vehicle HP exists
	if typeof(seat:GetAttribute("VehicleHealth")) ~= "number" then
		local maxHP = seat:GetAttribute("VehicleHealthMax") or 2000
		seat:SetAttribute("VehicleHealthMax", maxHP)
		seat:SetAttribute("VehicleHealth", maxHP)

		print("⚠️ [GunServer] VehicleHealth initialized to", maxHP)
	end

	local baseDamage = Module.VehicleDamage or 15
	local vehicleHP = seat:GetAttribute("VehicleHealth")

	--==============================
	-- DETACHABLE PART DAMAGE
	--==============================
	if hasTagRecursive(hitPart, "Detachable") then
		local partHP = hitPart:GetAttribute("DetachHealth")
		if typeof(partHP) ~= "number" then
			partHP = DEFAULT_DETACH_HP
			hitPart:SetAttribute("DetachHealth", partHP)
		end

		partHP -= baseDamage
		hitPart:SetAttribute("DetachHealth", partHP)

		print(string.format(
			"🧩 [DETACHABLE HIT] %s | PartHP=%d",
			hitPart.Name,
			partHP
			))

		-- Detach if depleted
		if partHP <= 0 and not hitPart:GetAttribute("Detached") then
			hitPart:SetAttribute("Detached", true)
			hitPart:BreakJoints()
			hitPart.Anchored = false
			hitPart.CanCollide = true

			local impulse = Instance.new("BodyVelocity")
			impulse.Velocity = Vector3.new(
				math.random(-DETACH_IMPULSE, DETACH_IMPULSE),
				DETACH_IMPULSE,
				math.random(-DETACH_IMPULSE, DETACH_IMPULSE)
			)
			impulse.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			impulse.Parent = hitPart
			Debris:AddItem(impulse, 0.15)

			print("💥 [DETACHED]", hitPart:GetFullName())
		end

		--==============================
		-- VEHICLE BLEED-THROUGH
		--==============================
		local bleedDamage = baseDamage * BLEED_THROUGH
		local newVehicleHP = math.max(0, vehicleHP - bleedDamage)
		seat:SetAttribute("VehicleHealth", newVehicleHP)

		print(string.format(
			"🚗 [VEHICLE BLEED] %s | -%.1f HP (%.0f → %.0f)",
			seat.Parent and seat.Parent.Name or "Vehicle",
			bleedDamage,
			vehicleHP,
			newVehicleHP
			))

		-- 🔥 VEHICLE DEATH TRIGGER (RESTORED)
		if newVehicleHP <= 0 then
			local carModel = seat:FindFirstAncestorOfClass("Model")
			if carModel then
				carModel:SetAttribute("ForceBurn", true)
				print("🔥 [VEHICLE DESTROYED]", carModel.Name)
			end
		end

		return
	end

	--==============================
	-- NON-DETACHABLE VEHICLE HIT
	--==============================
	local newHP = math.max(0, vehicleHP - baseDamage)
	seat:SetAttribute("VehicleHealth", newHP)

	local carModel = seat:FindFirstAncestorOfClass("Model")
	if carModel then
		carModel:SetAttribute("HullHealth", newHP)

		local maxHP = seat:GetAttribute("VehicleHealthMax") or 2000
		carModel:SetAttribute(
			"PowerMultiplier",
			math.clamp(newHP / maxHP, 0.15, 1)
		)
	end

	local carModel = seat:FindFirstAncestorOfClass("Model")
	if carModel then
		carModel:SetAttribute("HullHealth", newHP) -- keep CarDamage visuals alive
		local maxHP = seat:GetAttribute("VehicleHealthMax") or 2000
		carModel:SetAttribute("PowerMultiplier", math.clamp(newHP / maxHP, 0.15, 1))
	end

	print(string.format(
		"🚗 [VEHICLE DIRECT HIT] %s | %.0f → %.0f",
		seat.Parent and seat.Parent.Name or "Vehicle",
		vehicleHP,
		newHP
		))

	if newHP <= 0 then
		local carModel = seat:FindFirstAncestorOfClass("Model")
		if carModel then
			carModel:SetAttribute("ForceBurn", true)
			print("🔥 [VEHICLE DESTROYED]", carModel.Name)
		end
	end
end

--====================================================
-- REMOTE HANDLER
--====================================================
Remote.OnServerEvent:Connect(function(player, action, data)
	if not ownsTool(player) then return end

	if action == "FIRE" then
		if Mag.Value <= 0 then return end
		Mag.Value -= 1
		syncHUD() -- 🔹 ADD THIS
		processBullet(player, data.origin, data.direction.Unit)

	elseif action == "RELOAD" then
		local magMax = Module.AmmoPerMag or 30
		if Ammo.Value <= 0 or Mag.Value >= magMax then return end
		local used = math.min(magMax - Mag.Value, Ammo.Value)
		Mag.Value += used
		Ammo.Value -= used
		syncHUD() -- 🔹 ADD THIS

	elseif action == "FLASHLIGHT" then
		if typeof(data) == "boolean" then
			FlashlightOn.Value = data
		end
	end
end)
