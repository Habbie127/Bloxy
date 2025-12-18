local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Shared:WaitForChild("Packages").Knit)
local Utils = require(Shared:WaitForChild("Utils"))
local Ore = require(Shared:WaitForChild("Data"):WaitForChild("Ore"))
local lv = Workspace:WaitForChild("Living")

local currentMonster = nil
local currentRock = nil
local flyBodyGyro = nil
local flyBodyVelocity = nil
local noClipConnection = nil
local antiJitterConnection = nil
local holdPositionConnection = nil

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local ForgeHooks = loadstring(game:HttpGet("https://raw.githubusercontent.com/rhuda21/Main/3c3f7721b8ea922ed9909e30f22aff5e0ba28386/FS/Hooks.lua"))()

local Window = WindUI:CreateWindow({
    Title = "CentuDox | Forge",
    Icon = "door-open",
    Author = "MeeTsuo",
    Folder = "MeeTsuo",
    
    Size = UDim2.fromOffset(580, 460),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 200,
    BackgroundImageTransparency = 0.42,
    HideSearchBar = true,
    ScrollBarEnabled = false,
    Background = "rbxassetid://17784624382" -- rbxassetid
})

local SettingTab = Window:Tab({
    Title = "Settings",
    Icon = "lucide:bolt",
    Locked = false,
})
local MobsTab = Window:Tab({
    Title = "Mobs Farm",
    Icon = "lucide:swords",
    Locked = false,
})
local OresTab = Window:Tab({
    Title = "Ores Farm",
    Icon = "lucide:pickaxe",
    Locked = false,
})

local ForgeTab = Window:Tab({
    Title = "Auto Forge",
    Icon = "lucide:anvil",
    Locked = false,
})

local mobFarm = {
	enabled = false,
	oresenabled = false,
	autoforge = false,
	heavyattack = false,
	espEnabled = false,
	isCameraNoClipEnabled = false,
	selectedMonsterType = "Zombie",
	selectedRockType = "Pebble",
	fightMode = "Below Mob",
	selectedOresTypes = {},
	espCache = {},
	espConnections = {},
	FarmOresLookup = {},
	playersSkip = 10,
	attackdistance = 10,
}

local FIGHTMODE = {
    ["Above Mob"]  = Vector3.new(0, 8, 0),
    ["Below Mob"]  = Vector3.new(0, -6, 0),
}

local MonsterTypes = {
    "Zombie",
    "EliteZombie",
    "Delver Zombie",
    "Brute Zombie",
    "Bomber",
    "Skeleton Rogue",
    "Axe Skeleton",
    "Deathaxe Skeleton",
    "Slime",
    "Elite Rogue Skeleton",
    "Elite Deathaxe Skeleton",
    "Reaper",
    "Blazing Slime"
}

local FarmTypes = {
    "Pebble",
    "Rock",
    "Boulder",
    "Lucky Block",
    "Basalt Rock",
    "Basalt Core",
    "Basalt Vein",
    "Volcanic Rock",
    "Earth Crystal",
    "Cyan Crystal",
    "Crimson Crystal",
    "Violet Crystal",
    "Light Crystal"
}

local FarmOresTypes = {
    "Stone",
    "Sand Stone",
    "Copper",
    "Iron",
    "Poopite",
    "Tin",
    "Silver",
    "Bananite",
    "Cardboardite",
    "Mushroomite",
    "Gold",
    "Platinum",
    "Aite",
    "Fichillium",
    "Fichilliugeromoriteite",
    "Cobalt",
    "Titanium",
    "Lapis Lazuli",
    "Eye Ore",
    "Quartz",
    "Amethyst",
    "Topaz",
    "Diamond",
    "Sapphire",
    "Cuprite",
    "Emerald",
    "Ruby",
    "Rivalite",
    "Uranium",
    "Mythril",
    "Lightite",
    "Volcanic Rock",
    "Obsidian",
    "Fireite",
    "Magmaite",
    "Demonite",
    "Darkryte",
    "Blue Crystal",
    "Crimson Crystal",
    "Green Crystal",
    "Magenta Crystal",
    "Orange Crystal",
    "Rainbow Crystal",
    "Arcane Crystal",
}

local function getRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function playUISound(id, volume)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. id
    s.Volume = volume or 1
    s.Parent = SoundService
    s:Play()
    s.Ended:Connect(function()
        s:Destroy()
    end)
end

local function copy(text)
    (setclipboard or toclipboard or (Clipboard and Clipboard.set) or function() end)(text)
end

local function findAllMonsters()
    local monsters = {}
    local livingFolder = Workspace:FindFirstChild("Living")
    if livingFolder then
        for _, child in pairs(livingFolder:GetChildren()) do
            local monsterName = child.Name:gsub("%d+", "")
            if monsterName == mobFarm.selectedMonsterType then
                table.insert(monsters, child)
            end
        end
    end
    return monsters
end

local function findAllRocks()
    local rocks = {}
    local rocksFolder = Workspace:FindFirstChild("Rocks")
    if rocksFolder then
        for _, child in pairs(rocksFolder:GetDescendants()) do
            if child.Name == mobFarm.selectedRockType and (child:IsA("BasePart") or child:IsA("Model")) then
                table.insert(rocks, child)
            end
        end
    end
    if #rocks == 0 then
        for _, child in pairs(Workspace:GetDescendants()) do
            if child.Name == mobFarm.selectedRockType and (child:IsA("BasePart") or child:IsA("Model")) then
                table.insert(rocks, child)
            end
        end
    end
    return rocks
end

local function isValidOre(instance)
    if not (instance:IsA("Model") or instance:IsA("BasePart")) then
        return false
    end
    local oreAttr = instance:GetAttribute("Ore")
    if typeof(oreAttr) ~= "string" then
        return false
    end
    if not mobFarm.FarmOresLookup[oreAttr] then
        return false
    end
    return mobFarm.selectedOresTypes[oreAttr] == true
end

local function getRockPosition(rock)
    if rock:IsA("Model") then
        local primaryPart = rock.PrimaryPart or rock:FindFirstChildWhichIsA("BasePart")
        if primaryPart then
            return primaryPart.Position
        end
    elseif rock:IsA("BasePart") then
        return rock.Position
    end
    return nil
end

local function getRockPart(rock)
    if rock:IsA("Model") then
        return rock.PrimaryPart or rock:FindFirstChildWhichIsA("BasePart")
    elseif rock:IsA("BasePart") then
        return rock
    end
    return nil
end
local function IsRockBeingMined(rock)
    if not rock then return false end
    local lastHitPlayer = rock:GetAttribute("LastHitPlayer")
    local lastHitTime = rock:GetAttribute("LastHitTime")
    if not lastHitPlayer or not lastHitTime then
        return false
    end
    if lastHitPlayer == LocalPlayer.Name then
        return false
    end
    local currentTime = Workspace:GetServerTimeNow() -- Use server time for accuracy
    local timeSinceHit = currentTime - lastHitTime
    if timeSinceHit <= ROCK_OCCUPY_TIMEOUT then
        return true
    end
    return false
end

local function getRockHP(rock)
    local infoFrame = rock:FindFirstChild("infoFrame")
    if not infoFrame then return nil end
    local frame = infoFrame:FindFirstChild("Frame")
    if not frame then return nil end
    local rockHP = frame:FindFirstChild("rockHP")
    if not rockHP then return nil end
    local hpText = rockHP.Text
    if hpText then
        local hp = tonumber(hpText:match("%d+"))
        return hp
    end
    return nil
end

local function isRockValid(rock)
    if rock == nil then return false end
    if not rock.Parent then return false end
    local hp = getRockHP(rock)
    if hp ~= nil and hp <= 0 then
        return false
    end
    return true
end

local function isNearRock(character, rock)
    local root = getRoot(character)
    if not root or not rock then return false end
    local rockPos = getRockPosition(rock)
    if not rockPos then return false end
    return (root.Position - rockPos).Magnitude <= mobFarm.attackdistance
end

local function findNearestRock()
    local rocks = findAllRocks()
    local character = LocalPlayer.Character
    if not character then return nil end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    local playerPos = humanoidRootPart.Position
    local nearestRock = nil
    local nearestDistance = math.huge
    for _, rock in pairs(rocks) do
	    if isRockValid(rock) then
	        local rockPos = getRockPosition(rock)
	        if rockPos then
	            if not isOtherPlayerNearRock(rock) then
	                local distance = (rockPos - playerPos).Magnitude
	                if distance < nearestDistance then
	                    nearestDistance = distance
	                    nearestRock = rock
	                end
	            end
	        end
		end
    end
    return nearestRock
end

local function enablePlatformStand(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
    end
end

local function disablePlatformStand(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
    end
end

local function enableCameraNoClip()
    pcall(function()
        local sc = (debug and debug.setconstant) or setconstant
        local gc = (debug and debug.getconstants) or getconstants
        if not sc or not getgc or not gc then
            Library:Notify({Title = "Error", Content = "Exploit không hỗ trợ camera noclip", Duration = 3})
            return
        end
        local speaker = LocalPlayer
        local pop = speaker.PlayerScripts.PlayerModule.CameraModule.ZoomController.Popper
        for _, v in pairs(getgc()) do
            if type(v) == "function" and getfenv(v).script == pop then
                for i, v1 in pairs(gc(v)) do
                    if tonumber(v1) == 0.25 then
                        sc(v, i, 0)
                    end
                end
            end
        end
        mobFarm.isCameraNoClipEnabled = true
    end)
end

local function disableCameraNoClip()
    pcall(function()
        local sc = (debug and debug.setconstant) or setconstant
        local gc = (debug and debug.getconstants) or getconstants
        if not sc or not getgc or not gc then return end
        local speaker = LocalPlayer
        local pop = speaker.PlayerScripts.PlayerModule.CameraModule.ZoomController.Popper
        for _, v in pairs(getgc()) do
            if type(v) == "function" and getfenv(v).script == pop then
                for i, v1 in pairs(gc(v)) do
                    if tonumber(v1) == 0 then
                        sc(v, i, 0.25)
                    end
                end
            end
        end
        mobFarm.isCameraNoClipEnabled = false
    end)
end

local function enableFly(character)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    if flyBodyGyro then flyBodyGyro:Destroy() end
    if flyBodyVelocity then flyBodyVelocity:Destroy() end
    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyBodyGyro.P = 1000000
    flyBodyGyro.D = 100
    flyBodyGyro.Parent = humanoidRootPart
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.Parent = humanoidRootPart
end

local function disableFly()
    if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
    if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
end

local function enableNoClip(character)
    if noClipConnection then noClipConnection:Disconnect() end
    noClipConnection = RunService.Stepped:Connect(function()
        if character and character:FindFirstChild("Humanoid") then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function disableNoClip()
    if noClipConnection then noClipConnection:Disconnect() noClipConnection = nil end
end

local function enableAntiJitter(character)
    if antiJitterConnection then antiJitterConnection:Disconnect() end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    antiJitterConnection = RunService.RenderStepped:Connect(function()
        if humanoidRootPart and humanoidRootPart.Parent then
            humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
            humanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
        end
    end)
end

local function disableAntiJitter()
    if antiJitterConnection then antiJitterConnection:Disconnect() antiJitterConnection = nil end
end

local function getMonsterPosition(monster)
    if monster:IsA("Model") then
        local hrp = monster:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
        local primaryPart = monster.PrimaryPart or monster:FindFirstChildWhichIsA("BasePart")
        if primaryPart then return primaryPart.Position end
    elseif monster:IsA("BasePart") then
        return monster.Position
    end
    return nil
end

local function getMonsterHP(monster)
    local hrp = monster:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local infoFrame = hrp:FindFirstChild("infoFrame")
    if not infoFrame then return nil end
    local frame = infoFrame:FindFirstChild("Frame")
    if not frame then return nil end
    local rockHP = frame:FindFirstChild("rockHP")
    if not rockHP then return nil end
    local hpText = rockHP.Text
    if hpText then
        local hp = tonumber(hpText:match("[%d%.]+"))
        return hp
    end
    return nil
end

local function isMonsterValid(monster)
    if monster == nil then return false end
    if not monster.Parent then return false end
    local hp = getMonsterHP(monster)
    if hp ~= nil and hp <= 0 then
        return false
    end
    return true
end

local function findNearestMonster()
    local monsters = findAllMonsters()
    local character = LocalPlayer.Character
    if not character then return nil end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    local playerPos = humanoidRootPart.Position
    local nearestMonster = nil
    local nearestDistance = math.huge
    for _, monster in pairs(monsters) do
        if isMonsterValid(monster) then
            local monsterPos = getMonsterPosition(monster)
            if monsterPos then
                local distance = (monsterPos - playerPos).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestMonster = monster
                end
            end
        end
    end
    return nearestMonster
end

local function createOreESP(ore)
    if mobFarm.espCache[ore] then return end
    local adornee =
        ore:IsA("Model") and (ore.PrimaryPart or ore:FindFirstChildWhichIsA("BasePart"))
        or ore
    if not adornee then return end
    local oreName = ore:GetAttribute("Ore")
    if not oreName then return end
    local gui = Instance.new("BillboardGui")
    gui.Name = "OreESP"
    gui.Adornee = adornee
    gui.Size = UDim2.fromOffset(70, 20)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.AlwaysOnTop = true
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Text = oreName
    label.TextColor3 = Color3.fromRGB(0, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = gui
    gui.Parent = ore
    mobFarm.espCache[ore] = gui
end

local function removeOreESP()
    for ore, gui in pairs(mobFarm.espCache) do
        if gui then gui:Destroy() end
    end
    table.clear(mobFarm.espCache)
end

local function removeESP(monster)
    if mobFarm.espConnections[monster] then
        mobFarm.espConnections[monster]:Disconnect()
        mobFarm.espConnections[monster] = nil
    end
    if mobFarm.espCache[monster] then
        mobFarm.espCache[monster]:Destroy()
        mobFarm.espCache[monster] = nil
    end
end

local function isPlayerCharacter(model)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == model then
            return true
        end
    end
    return false
end

local function detectNearbyMobOnly(range)
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local living = Workspace:FindFirstChild("Living")
    if not living then return nil end
    for _, model in ipairs(living:GetChildren()) do
        if model:IsA("Model") and not isPlayerCharacter(model) then
            local mobHRP = model:FindFirstChild("HumanoidRootPart")
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if mobHRP and humanoid and humanoid.Health > 0 then
                local dist = (mobHRP.Position - hrp.Position).Magnitude
                if dist <= range then
                    return model
                end
            end
        end
    end
    return nil
end

local function createESP(monster)
    if mobFarm.espCache[monster] then return end
    if not monster:IsA("Model") then return end
    local hrp = monster:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MobESP"
    billboard.Adornee = hrp
    billboard.Size = UDim2.fromOffset(140, 34)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextScaled = true
    text.TextStrokeTransparency = 0
    text.TextStrokeColor3 = Color3.new(0,0,0)
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = Color3.fromRGB(255, 80, 80)
    text.Text = monster.Name:gsub("%d+", "")
    text.Parent = billboard
    billboard.Parent = hrp
    mobFarm.espCache[monster] = billboard
    mobFarm.espConnections[monster] = RunService.Heartbeat:Connect(function()
        if not mobFarm.espEnabled then
            removeESP(monster)
            return
        end
        if not monster.Parent then
            removeESP(monster)
            return
        end
        local hp = getMonsterHP(monster)
        if hp and hp <= 0 then
            removeESP(monster)
        end
    end)
end

local function updateESP()
	local living = Workspace:WaitForChild("Living")
    if not living then return end
    for _, monster in ipairs(living:GetChildren()) do
        local cleanName = monster.Name:gsub("%d+", "")
        if mobFarm.espEnabled and cleanName == mobFarm.selectedMonsterType then
            createESP(monster)
        else
            removeESP(monster)
        end
    end
end

lv.ChildAdded:Connect(function(monster)
    task.wait(0.1)
    if not mobFarm.espEnabled then return end
    local cleanName = monster.Name:gsub("%d+", "")
    if cleanName == mobFarm.selectedMonsterType then
        createESP(monster)
    end
end)

lv.ChildRemoved:Connect(function(monster)
    removeESP(monster)
end)

local function tweenToMonster(monster)
    local character = LocalPlayer.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local monsterPos = getMonsterPosition(monster)
    if not monsterPos then return false end
    local offset = FIGHTMODE[mobFarm.fightMode] or Vector3.new(0, -6, 0)
    local targetPos = monsterPos + offset
    local distance = (targetPos - hrp.Position).Magnitude
    local tweenTime = distance / 50
    local lookCFrame = CFrame.new(targetPos, monsterPos)
    local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {
        CFrame = lookCFrame
    })
    tween:Play()
    tween.Completed:Wait()
    return true
end

local function tweenToRock(rock)
    local character = LocalPlayer.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return false end
    local rockPos = getRockPosition(rock)
    if not rockPos then return false end
    local targetCFrame = CFrame.new(rockPos + Vector3.new(0, 3, 0))
    local distance = (rockPos - hrp.Position).Magnitude
    local tweenTime = distance / 50
    local tween = TweenService:Create(
        hrp,
        TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
        { CFrame = targetCFrame }
    )
    tween:Play()
    tween.Completed:Wait()
    return true
end

local function holdPositionRock(rock)
    if holdPositionConnection then holdPositionConnection:Disconnect() end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    holdPositionConnection = RunService.Heartbeat:Connect(function()
        if not mobFarm.oresenabled or not isRockValid(rock) then
            if holdPositionConnection then holdPositionConnection:Disconnect() holdPositionConnection = nil end
            return
        end
        local rockPos = getRockPosition(rock)
        if rockPos then
            local lookUpCFrame = CFrame.new(rockPos + Vector3.new(0, 3, 0))
            humanoidRootPart.CFrame = lookUpCFrame
            if flyBodyGyro then
                flyBodyGyro.CFrame = lookUpCFrame
            end
        end
    end)
end

local function holdPositionOnMonster(monster)
    if holdPositionConnection then
        holdPositionConnection:Disconnect()
    end
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    holdPositionConnection = RunService.Heartbeat:Connect(function()
        if not mobFarm.enabled or not isMonsterValid(monster) then
            if holdPositionConnection then holdPositionConnection:Disconnect() holdPositionConnection = nil end
            return
        end
        local monsterPos = getMonsterPosition(monster)
        if monsterPos then
            local offset = FIGHTMODE[mobFarm.fightMode] or Vector3.new(0, -6, 0)
            local targetPos = monsterPos + offset
            local lookCFrame = CFrame.new(targetPos, monsterPos)
            hrp.CFrame = lookCFrame
            if flyBodyGyro then
                flyBodyGyro.CFrame = lookCFrame
            end
        end
    end)
end

local function stopHoldPosition()
    if holdPositionConnection then
		holdPositionConnection:Disconnect()
		holdPositionConnection = nil
	end
end

local function onCharacterAdded(character)
    task.wait(1)
    currentMonster = nil
    currentRock = nil
    stopHoldPosition()
    if mobFarm.enabled or mobFarm.oresenabled then
        enableFly(character)
        enableNoClip(character)
        enableAntiJitter(character)
        enablePlatformStand(character)
    end
end

local function NormalAttack()
    pcall(function()
        local args = {"Weapon"}
        ReplicatedStorage:WaitForChild("Shared")
            :WaitForChild("Packages")
            :WaitForChild("Knit")
            :WaitForChild("Services")
            :WaitForChild("ToolService")
            :WaitForChild("RF")
            :WaitForChild("ToolActivated")
            :InvokeServer(unpack(args))
    end)
end

local function HeavyAttack()
    pcall(function()
        local args = {"Weapon", true}
        ReplicatedStorage
            :WaitForChild("Shared")
            :WaitForChild("Packages")
            :WaitForChild("Knit")
            :WaitForChild("Services")
            :WaitForChild("ToolService")
            :WaitForChild("RF")
            :WaitForChild("ToolActivated")
            :InvokeServer(unpack(args))
    end)
end

local function PickaxeAttack()
    pcall(function()
        local args = {"Pickaxe"}
        ReplicatedStorage:WaitForChild("Shared")
            :WaitForChild("Packages")
            :WaitForChild("Knit")
            :WaitForChild("Services")
            :WaitForChild("ToolService")
            :WaitForChild("RF")
            :WaitForChild("ToolActivated")
            :InvokeServer(unpack(args))
    end)
end

local function WeaponEquipped()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t.Name == "Weapon" then
			return t
		end
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if not backpack then return nil end
	local weapon = backpack:FindFirstChild("Weapon")
	if not (weapon and weapon:IsA("Tool")) then return nil end
	pcall(function()
		if hum then
			hum:EquipTool(weapon)
		else
			weapon.Parent = char
		end
	end)
	task.wait(0.1)
	return weapon
end

local function PickaxeEquipped()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") and t.Name == "Pickaxe" then
			return t
		end
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if not backpack then return nil end
	local weapon = backpack:FindFirstChild("Pickaxe")
	if not (weapon and weapon:IsA("Tool")) then return nil end
	if hum then
		hum:EquipTool(weapon)
	else
		weapon.Parent = char
	end
	task.wait(0.1)
	return weapon
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

task.spawn(function()
    while true do
        task.wait(0.1)
        if mobFarm.enabled then
            pcall(function()
                local character = LocalPlayer.Character
                if character then
	                enablePlatformStand(character)
                end
                if not currentMonster or not isMonsterValid(currentMonster) then
                    stopHoldPosition()
                    currentMonster = findNearestMonster()
                    if currentMonster then
                        tweenToMonster(currentMonster)
                        holdPositionOnMonster(currentMonster)
                        task.wait(0.2)
                    end
                end
                if isMonsterValid(currentMonster) then
	                WeaponEquipped()
		            if mobFarm.heavyattack then		                
		                HeavyAttack()
		            else
	                    NormalAttack()
					end
                end
            end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if mobFarm.oresenabled then
            local character = LocalPlayer.Character
            if character then
                enablePlatformStand(character)
            end            
            if not currentRock or not isRockValid(currentRock) then
                stopHoldPosition()
                currentRock = findNearestRock()
                if currentRock then
                    tweenToRock(currentRock)
                    holdPositionRock(currentRock)
                    task.wait(0.2)
                end
                continue
            end
            if not isNearRock(character, currentRock) then
	            stopHoldPosition()
	            tweenToRock(currentRock)
	            holdPositionRock(currentRock)
				task.wait(0.2)
	            continue
	        end
            local nearbyMonster = detectNearbyMobOnly(mobFarm.attackdistance)
			if nearbyMonster then
			    WeaponEquipped()
			    if mobFarm.heavyattack then
			        HeavyAttack()
			    else
			        NormalAttack()
			    end
			else
			    PickaxeEquipped()
			    PickaxeAttack()
			end
		end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if not mobFarm.espEnabled then
            removeOreESP()
            continue
        end
        local rocksFolder = Workspace:FindFirstChild("Rocks")
        if not rocksFolder then continue end
        for _, obj in ipairs(rocksFolder:GetDescendants()) do
            if isValidOre(obj) then
                createOreESP(obj)
            end
        end
    end
end)
    
local ForgeButton = SettingTab:Button({
    Title = "Centu Sherman Discord Server!",
    Desc = "Report Any Bugs/Suggestions!",
    Locked = false,
    Callback = function()
	    playUISound(103307955424380, 0.7)
        copy("https://discord.gg/pj2DjURHT")	    
    end
})

local AttackModeDropdown = SettingTab:Dropdown({
    Title = "Attack Mode",
    Desc = "Position relative to monster",
    Values = {"Above Mob", "Below Mob"},
    Value = "Below Mob",
    Multi = false,
    Callback = function(v)
        mobFarm.fightMode = v
    end
})

local HeavyAttackToggle = SettingTab:Toggle({
    Title = "Heavy Attack",
    Desc = "Ignored Basic Attack",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(v) 
        mobFarm.heavyattack = v
        if v then
            playUISound(9120102763, 0.8)
        else
            playUISound(74602744737986, 0.8)
        end
    end
})

local SelectMobsDropdown = MobsTab:Dropdown({
    Title = "Select Mobs",
    Desc = "For AutoFarm Mobs",
    Values = MonsterTypes,
    Value = "Zombie",
    Multi = false,
    Callback = function(opts) 
        mobFarm.selectedMonsterType = opts
        updateESP()
    end
})

local AutoFarmMobsToggle = MobsTab:Toggle({
    Title = "AutoFarm Mobs",
    Desc = "Must Select Mobs",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(v) 
        mobFarm.enabled = v
        if v then
            playUISound(9120102763, 0.8)
        else
            playUISound(74602744737986, 0.8)
        end
		local character = LocalPlayer.Character
	    if mobFarm.enabled then
	        enableCameraNoClip()
	        if character then
	            enableFly(character)
	            enableNoClip(character)
	            enablePlatformStand(character)
	            enableAntiJitter(character)
	        end
	    else
	        currentMonster = nil
	        stopHoldPosition()
	        disableFly()
	        disableNoClip()
	        disableAntiJitter()
	        if character then
	            disablePlatformStand(character)
	        end
	        disableCameraNoClip()
	    end
    end
})

local ESPToggle = MobsTab:Toggle({
    Title = "Mobs ESP Name",
    Desc = "Selected Mobs Esp",
    Icon = "eye",
    Type = "Checkbox",
    Value = false,
    Callback = function(v)
        mobFarm.espEnabled = v
        updateESP()
        if v then
            playUISound(9120102763, 0.8)
        else
            playUISound(74602744737986, 0.8)
        end
    end
})

local SelectMobsDropdown = OresTab:Dropdown({
    Title = "Select Rocks",
    Desc = "For Rocks Farm",
    Values = FarmTypes,
    Value = "Pebble",
    Multi = false,
    Callback = function(opts) 
        mobFarm.selectedRockType = opts
    end
})

local OresDropdown = OresTab:Dropdown({
    Title = "Select Ores (Multi)",
    Desc = "Select multiple ores for ESP",
    Values = FarmOresTypes,
    Multi = true,
    Callback = function(selected)
    local lookup = {}
    for _, oreName in ipairs(selected) do
        lookup[oreName] = true
    end
    mobFarm.selectedOresTypes = lookup
    removeOreESP()
end
})

local AutoOresToggle = OresTab:Toggle({
	Title = "Rocks Farm",
    Desc = "Must Select Rocks",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(v) 
        mobFarm.oresenabled = v
        if v then
            playUISound(9120102763, 0.8)
        else
            playUISound(74602744737986, 0.8)
        end
        local character = LocalPlayer.Character
	    if mobFarm.oresenabled then
	        enableCameraNoClip()
	        if character then
	            enableFly(character)
	            enableNoClip(character)
	            enablePlatformStand(character)
	            enableAntiJitter(character)
	        end
	    else
	        currentRock = nil
	        stopHoldPosition()
	        disableFly()
	        disableNoClip()
	        disableAntiJitter()
	        if character then
	            disablePlatformStand(character)
	        end
	        disableCameraNoClip()
	    end
    end
})

local OreESPToggle = OresTab:Toggle({
    Title = "Ore ESP (Name)",
    Desc = "Show ore names above ores",
    Value = false,
    Callback = function(v)
        mobFarm.espEnabled = v
        if v then
            playUISound(9120102763, 0.8)
        else
            playUISound(74602744737986, 0.8)
        end
        if not v then
            removeOreESP()
        end
    end
})

local ForgeButton = ForgeTab:Button({
    Title = "Open Forge Ui",
    Desc = "No Need To Go Near Forge!",
    Locked = false,
    Callback = function()
	    playUISound(103307955424380, 0.7)
        local ForgeOpen = Workspace:FindFirstChild("Proximity")
        if ForgeOpen then
            ForgeOpen = ForgeOpen:FindFirstChild("Forge")
        end
        local PP = ForgeOpen:FindFirstChildOfClass("ProximityPrompt", true)
        fireproximityprompt(PP)
    end
})

local ForgeToggle = ForgeTab:Toggle({
    Title = "Auto Forge",
    Desc = "Automatically completes Melt, Pour and Hammer minigames",
    Icon = "bird",
    Type = "Checkbox",
    Value = false,
    Callback = function(v)
	    if v then
            playUISound(9120102763, 0.8)
        else
            playUISound(74602744737986, 0.8)
        end
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            UserInputService.MouseIconEnabled = not v
        end
        mobFarm.autoforge = v
    end
})

local function getHammerMinigameUI()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return nil end
    local forgeGui = pGui:FindFirstChild("Forge")
    if not forgeGui then return nil end
    local hammer = forgeGui:FindFirstChild("HammerMinigame")
    if hammer and hammer:IsA("GuiObject") then
        return hammer
    end
    return nil
end

local clickedNotes = {} 
local getMeltMinigameUI, getPourMinigameUI

local function performHammerAction()
    pcall(function()
        local hammerUI = getHammerMinigameUI()
        local debris = Workspace:FindFirstChild("Debris")
        if debris then
            for _, child in pairs(debris:GetChildren()) do
                if child.Name == "Mold" and child:FindFirstChild("ClickDetector") then
                     fireclickdetector(child.ClickDetector)
                     task.wait(0.05) 
                end
            end
        end
        if not hammerUI or not hammerUI.Visible then 
            clickedNotes = {} 
            return 
        end            
        for _, child in pairs(hammerUI:GetChildren()) do
            if child:IsA("GuiObject") and child.Name ~= "Timer" and child.Visible then
                if not clickedNotes[child] then
                    local frame = child:FindFirstChild("Frame")
                    if frame then
                        local circle = frame:FindFirstChild("Circle")
                        if circle and circle:IsA("ImageLabel") then
                            local circleScale = circle.Size.X.Scale
                            if circleScale <= 0.99 and circleScale >= 0.88 then
                                clickedNotes[child] = true
                                local success = pcall(function()
                                    if firesignal then
                                        firesignal(child.MouseButton1Click)
                                    elseif fireclickdetector then
                                        child.MouseButton1Click:Fire()
                                    end
                                end)
                                if not success then
                                    local absPos = child.AbsolutePosition
                                    local absSize = child.AbsoluteSize
                                    local centerX = absPos.X + (absSize.X / 2)
                                    local centerY = absPos.Y + (absSize.Y / 2)
                                    local guiInset = game:GetService("GuiService"):GetGuiInset()
                                    local trueY = centerY + guiInset.Y
                                    VirtualInputManager:SendMouseButtonEvent(centerX, trueY, 0, true, game, 1)
                                    VirtualInputManager:SendMouseButtonEvent(centerX, trueY, 0, false, game, 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end
function getMeltMinigameUI()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    local forgeGui = playerGui:FindFirstChild("Forge")
    if not forgeGui then return nil end
    local melt = forgeGui:FindFirstChild("MeltMinigame")
    if melt and melt:IsA("GuiObject") then
        return melt
    end
    return nil
end   
local function performMeltAction()
    pcall(function()
        local meltUI = getMeltMinigameUI()
        if not meltUI or not meltUI.Visible then return end            
        local heater = meltUI:FindFirstChild("Heater")
        if not heater then return end            
        local top = heater:FindFirstChild("Top")
        local bottom = heater:FindFirstChild("Bottom")            
        if top and bottom then
            local guiInset = game:GetService("GuiService"):GetGuiInset()
            local topPos = top.AbsolutePosition
            local topSize = top.AbsoluteSize
            local bottomPos = bottom.AbsolutePosition                
            local startX = topPos.X + (topSize.X / 2)
            local startY = topPos.Y + (topSize.Y / 2) + guiInset.Y
            local endY = bottomPos.Y + guiInset.Y                
            VirtualInputManager:SendMouseMoveEvent(startX, startY, game)
            VirtualInputManager:SendMouseButtonEvent(startX, startY, 0, true, game, 1)                
            local steps = 4
            local stepY = (endY - startY) / steps               
            for i = 1, steps do
                local currentTargetY = startY + (stepY * i)
                VirtualInputManager:SendMouseMoveEvent(startX, currentTargetY, game)
                task.wait(0.02)
            end                
            VirtualInputManager:SendMouseButtonEvent(startX, endY, 0, false, game, 1)
            task.wait(0.05) 
        end
    end)
end
isPourHolding = false
function getPourMinigameUI()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return nil end
    local fGui = pGui:FindFirstChild("Forge")
    if not fGui then return nil end
    local pour = fGui:FindFirstChild("PourMinigame")
    if pour and pour:IsA("GuiObject") then
        return pour
    end
    return nil
end
local function performPourAction()
    pcall(function()
        local pourUI = getPourMinigameUI()
        if not pourUI or not pourUI.Visible then
            if isPourHolding then
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                isPourHolding = false
            end
            return
        end
        local frame = pourUI:FindFirstChild("Frame")
        if not frame then return end
        local line = frame:FindFirstChild("Line")
        local area = frame:FindFirstChild("Area")
        if not (line and area) then return end
        local lineY = line.Position.Y.Scale
        local areaTop = area.Position.Y.Scale
        local areaBottom = areaTop + area.Size.Y.Scale
        local areaCenter = (areaTop + areaBottom) / 2
        local absPos = frame.AbsolutePosition
        local absSize = frame.AbsoluteSize
        local centerX = absPos.X + absSize.X / 2
        local centerY = absPos.Y + absSize.Y / 2
        local guiInset = game:GetService("GuiService"):GetGuiInset()
        local trueY = centerY + guiInset.Y
        if lineY > areaBottom then
            if not isPourHolding then
                VirtualInputManager:SendMouseMoveEvent(centerX, trueY, game)
                VirtualInputManager:SendMouseButtonEvent(centerX, trueY, 0, true, game, 1)
                isPourHolding = true
            end
        elseif lineY < areaTop then
            if isPourHolding then
                VirtualInputManager:SendMouseButtonEvent(centerX, trueY, 0, false, game, 1)
                isPourHolding = false
            end
        else
	        if lineY > areaCenter then
                if not isPourHolding then
                    VirtualInputManager:SendMouseMoveEvent(centerX, trueY, game)
                    VirtualInputManager:SendMouseButtonEvent(centerX, trueY, 0, true, game, 1)
                    isPourHolding = true
                end
            else
                if isPourHolding then
                    VirtualInputManager:SendMouseButtonEvent(centerX, trueY, 0, false, game, 1)
                    isPourHolding = false
                end
            end
        end
    end)
end
task.spawn(function()
    while true do
        task.wait(0.1)
        if mobFarm.autoforge then
            performMeltAction()
            performPourAction()
        end
    end
end)
task.spawn(function()
    RunService.RenderStepped:Connect(function()	        
        if mobFarm.autoforge then
             performHammerAction()
        end
    end)
end)

WindUI:Notify({
    Title = "Loaded Successfully In Forge",
    Content = "Welcome to Forge! Your journey begins here.",
    Duration = 5,
    Icon = "lucide:bell-ring",
})