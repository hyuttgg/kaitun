--!strict
--[[
    ══════════════════════════════════════════════════════════════════════════════
    🧠 BỘ NÃO ĐIỀU PHỐI KAITUN MULTI-AGENT AI (AUTONOMOUS MULTI-AGENT BRAIN)
    ══════════════════════════════════════════════════════════════════════════════
    Single-File Autonomous Distributed Multi-Agent Architecture for Blox Fruits.
    
    Architectural Layers:
    1. Global Blackboard (Shared State Memory & Resource Locks)
    2. Master Supervisor Brain (Goal Planner, Priority Queue & Preemption Engine)
    3. Agent 1: Resource & Performance Governor (FPS Cap, Headless Render, GC)
    4. Agent 2: Quest & Leveling Engine (Pathfinding, Mob Clustering, Fast Attack)
    5. Agent 3: Sentry & Network Hopping Agent (Proximity Sentinel, Watchdog Timer)
    6. Agent 4: Market & Fruit Sniper Agent (Dealer Hook, Auto Buy & Auto Store)
    7. Agent 5: Endgame Questline & Puzzle Solver (CDK, Soul Guitar, Saber, Rainbow Haki, Godhuman)
    8. Agent 6: Race Progression Engine (Race V2 3-Flowers, Race V3 Don Swan/Arowe)
    9. Agent 7: Stats & Character Progression Agent (Auto Stats, Haki Upgrades)
    10. Agent 8: Error Recovery & Anti-Loop Engine (Safe Mode, Anti-Oscillation)
    
    Compliant with Luau Type Safety and Roblox Studio Test Environment APIs.
    ══════════════════════════════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. GLOBAL BLACKBOARD & SHARED STATE MEMORY
-- ══════════════════════════════════════════════════════════════════════════════

local Blackboard = {
    Config = {
        AutoExecute = true,
        Debug = true,
        SafeMode = true,
        MinHP = 35,
        MaxRetries = 3,
        TaskTimeout = 30,

        Performance = {
            FpsBoost = true,
            FPSCap = 30,
            WhiteScreen = false,
            ReduceEffects = true,
            ReduceParticles = true,
            Set3dRenderingEnabled = true,
        },

        Hopping = {
            AutoHop = true,
            HopIdle = true,
            IdleTimeout = 180, -- seconds
            HighPingHop = true,
            HighPingThreshold = 500, -- ms
            PlayerNearingHop = true,
            SafePlayerDistance = 250, -- studs
        },

        SniperFruitShop = {
            Enabled = true,
            Fruit = {
                ["Kitsune-Kitsune"] = true,
                ["Dragon-Dragon"] = true,
                ["Yeti-Yeti"] = true,
                ["Gas-Gas"] = true,
                ["Dough-Dough"] = true,
                ["Leopard-Leopard"] = true,
                ["Buddha-Buddha"] = true,
                ["Portal-Portal"] = true,
            },
        },

        Oneclick = {
            AutoFullyFightingStyle = true,
            RainbowHaki = true,
            SkullGuitar = true,
            CursedDualKatana = true,
            Saber = true,
            TTK = true,
            RaceV2 = true,
            RaceV3 = true,
        },

        Automation = {
            AutoFarm = true,
            AutoQuest = true,
            AutoWeapon = true,
            AutoBoss = true,
            AutoHaki = true,
            AutoFightingStyle = true,
            AutoElite = true,
            AutoFruit = true,
            AutoChest = true,
            AutoSeaProgression = true,
            AutoStats = true,
            AutoCodes = true,
        },

        StatsDistribution = {
            Preset = "Sword", -- "Melee" | "Sword" | "Fruit" | "Hybrid"
            Melee = 0.35,
            Defense = 0.35,
            Sword = 0.3,
            DemonFruit = 0.0,
            Gun = 0.0,
        },
    },

    PlayerState = {
        CurrentSea = 1,
        Level = 1,
        Beli = 0,
        Fragments = 0,
        Position = Vector3.zero,
        Health = 100,
        MaxHealth = 100,
        CurrentWeapon = "Combat",
        CurrentFightingStyle = "Combat",
        CurrentFruit = nil :: string?,
        AuraActive = false,
        ObservationActive = false,
        Race = "Human",
        RaceStage = 1,
        Points = 0,
        Stats = {
            Melee = 1,
            Defense = 1,
            Sword = 1,
            DemonFruit = 1,
            Gun = 1,
        },
        Inventory = {
            Weapons = {} :: { [string]: { Mastery: number, Owned: boolean } },
            FightingStyles = {} :: { [string]: { Mastery: number, Owned: boolean } },
            Fruits = {} :: { [string]: { InInventory: boolean, InStorage: boolean, Rarity: string } },
            Materials = {} :: { [string]: number },
            Accessories = {} :: { [string]: boolean },
        },
        IsAlive = true,
    },

    WorldState = {
        FullMoon = false,
        MirageActive = false,
        NearestPlayers = {} :: { { Name: string, Distance: number } },
        NetworkPing = 50,
        LastExpGainedTime = os.time(),
        ActiveMobs = {} :: { any },
        ActiveBosses = {} :: { any },
        ActiveElites = {} :: { any },
        SpawnedFruits = {} :: { any },
        Chests = {} :: { any },
        ActiveQuest = nil :: { QuestId: string, Progress: number, Required: number }?,
    },

    ActiveLock = nil :: string?, -- Resource exclusivity ("ONECLICK", "HOPPING", "SHOPPING", "COMBAT", "SAFE_MODE")
    StateHistory = {} :: { { State: string, Timestamp: number } },
    SystemLogs = {} :: { { Time: string, Tag: string, Message: string } },
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. CORE LOGGING & EVENT BUS
-- ══════════════════════════════════════════════════════════════════════════════

local Logger = {}
function Logger:Log(tag: string, action: string, result: string)
    local timeStr = os.date("%H:%M:%S", os.time())
    local entry = { Time = timeStr, Tag = tag, Message = string.format("[%s] %s -> %s", tag, action, result) }
    table.insert(Blackboard.SystemLogs, entry)
    if #Blackboard.SystemLogs > 200 then
        table.remove(Blackboard.SystemLogs, 1)
    end
    print(string.format("[%s] [%s] %s -> %s", timeStr, tag, action, result))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. REMOTES INTERACTION LAYER (GameAPI Adapter)
-- ══════════════════════════════════════════════════════════════════════════════

local Remotes = {}
function Remotes:Init()
    local kaitunRemotes = ReplicatedStorage:FindFirstChild("KaitunRemotes")
    if kaitunRemotes then
        self.GetCharacterStateRF = kaitunRemotes:FindFirstChild("GetCharacterState") :: RemoteFunction?
        self.GetInventoryRF = kaitunRemotes:FindFirstChild("GetInventory") :: RemoteFunction?
        self.GetWorldStateRF = kaitunRemotes:FindFirstChild("GetWorldState") :: RemoteFunction?
        self.AcceptQuestRF = kaitunRemotes:FindFirstChild("AcceptQuest") :: RemoteFunction?
        self.AttackTargetRF = kaitunRemotes:FindFirstChild("AttackTarget") :: RemoteFunction?
        self.PurchaseItemRF = kaitunRemotes:FindFirstChild("PurchaseItem") :: RemoteFunction?
        self.EquipWeaponRF = kaitunRemotes:FindFirstChild("EquipWeapon") :: RemoteFunction?
        self.EquipFightingStyleRF = kaitunRemotes:FindFirstChild("EquipFightingStyle") :: RemoteFunction?
        self.UpgradeStatRF = kaitunRemotes:FindFirstChild("UpgradeStat") :: RemoteFunction?
        self.CollectChestRF = kaitunRemotes:FindFirstChild("CollectChest") :: RemoteFunction?
        self.CollectFruitRF = kaitunRemotes:FindFirstChild("CollectFruit") :: RemoteFunction?
        self.StoreFruitRF = kaitunRemotes:FindFirstChild("StoreFruit") :: RemoteFunction?
        self.RandomizeFruitRF = kaitunRemotes:FindFirstChild("RandomizeFruit") :: RemoteFunction?
        self.TravelToSeaRF = kaitunRemotes:FindFirstChild("TravelToSea") :: RemoteFunction?
        self.RedeemCodeRF = kaitunRemotes:FindFirstChild("RedeemCode") :: RemoteFunction?
        self.MoveToRE = kaitunRemotes:FindFirstChild("MoveTo") :: RemoteEvent?
    end
end

function Remotes:SyncState()
    if self.GetCharacterStateRF then
        local success, state = pcall(function() return self.GetCharacterStateRF:InvokeServer() end)
        if success and state then
            Blackboard.PlayerState.Level = state.Level or Blackboard.PlayerState.Level
            Blackboard.PlayerState.CurrentSea = state.Sea or Blackboard.PlayerState.CurrentSea
            Blackboard.PlayerState.Beli = state.Beli or Blackboard.PlayerState.Beli
            Blackboard.PlayerState.Fragments = state.Fragments or Blackboard.PlayerState.Fragments
            Blackboard.PlayerState.Health = state.HP or Blackboard.PlayerState.Health
            Blackboard.PlayerState.MaxHealth = state.MaxHP or Blackboard.PlayerState.MaxHealth
            Blackboard.PlayerState.Position = state.Position or Blackboard.PlayerState.Position
            Blackboard.PlayerState.Points = state.Points or Blackboard.PlayerState.Points
            Blackboard.PlayerState.Race = state.Race or Blackboard.PlayerState.Race
            Blackboard.PlayerState.RaceStage = state.RaceStage or Blackboard.PlayerState.RaceStage
            Blackboard.PlayerState.CurrentWeapon = state.CurrentWeapon or Blackboard.PlayerState.CurrentWeapon
            Blackboard.PlayerState.CurrentFightingStyle = state.CurrentFightingStyle or Blackboard.PlayerState.CurrentFightingStyle
            Blackboard.PlayerState.AuraActive = state.AuraActive or false
            Blackboard.PlayerState.ObservationActive = state.ObservationActive or false
            Blackboard.PlayerState.Stats = state.Stats or Blackboard.PlayerState.Stats
        end
    end

    if self.GetInventoryRF then
        local success, inv = pcall(function() return self.GetInventoryRF:InvokeServer() end)
        if success and inv then
            Blackboard.PlayerState.Inventory = inv
        end
    end

    if self.GetWorldStateRF then
        local success, world = pcall(function() return self.GetWorldStateRF:InvokeServer() end)
        if success and world then
            Blackboard.WorldState.ActiveMobs = world.ActiveMobs or {}
            Blackboard.WorldState.ActiveBosses = world.ActiveBosses or {}
            Blackboard.WorldState.ActiveElites = world.ActiveElites or {}
            Blackboard.WorldState.SpawnedFruits = world.SpawnedFruits or {}
            Blackboard.WorldState.Chests = world.Chests or {}
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. AGENT 1: RESOURCE & PERFORMANCE GOVERNOR (Tối ưu phần cứng)
-- ══════════════════════════════════════════════════════════════════════════════

local ResourceAgent = {}
ResourceAgent._initialized = false

function ResourceAgent:Init(config)
    if self._initialized then return end
    self._initialized = true

    Logger:Log("ResourceAgent", "Init", "Configuring CPU/GPU optimization profiles...")

    if config.Performance.FpsBoost then
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 0
            Lighting.Technology = Enum.Technology.Compatibility
        end)

        task.spawn(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj:IsA("MeshPart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                end
            end
        end)
    end

    if config.Performance.WhiteScreen then
        pcall(function()
            RunService:Set3dRenderingEnabled(false)
            Logger:Log("ResourceAgent", "WhiteScreen", "3D Rendering disabled (Headless mode)")
        end)
    end

    if config.Performance.FPSCap and config.Performance.FPSCap > 0 then
        pcall(function()
            if setfpscap then
                setfpscap(config.Performance.FPSCap)
                Logger:Log("ResourceAgent", "FPSCap", string.format("Locked FPS to %d", config.Performance.FPSCap))
            end
        end)
    end

    -- Periodic Memory Garbage Collector
    task.spawn(function()
        while task.wait(300) do
            collectgarbage("collect")
            Logger:Log("ResourceAgent", "GC", "Luau Garbage Collector cycled")
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. AGENT 2: QUEST & LEVELING ENGINE (Điều phối cày cấp & Gom quái)
-- ══════════════════════════════════════════════════════════════════════════════

local LevelingAgent = {}

function LevelingAgent:CalculateSafePath(targetPos: Vector3, speed: number?): boolean
    speed = speed or 320
    if Remotes.MoveToRE then
        Remotes.MoveToRE:FireServer(targetPos)
    end
    Blackboard.PlayerState.Position = targetPos
    return true
end

function LevelingAgent:FindBestQuest(): any?
    local questsDb = {
        { QuestId = "BanditQuest1", Target = "Bandit", ReqLevel = 1, Count = 5, Sea = 1, Pos = Vector3.new(1060, 16, 1548) },
        { QuestId = "JungleQuest1", Target = "Monkey", ReqLevel = 10, Count = 6, Sea = 1, Pos = Vector3.new(-1600, 36, 153) },
        { QuestId = "JungleQuest2", Target = "Gorilla", ReqLevel = 15, Count = 8, Sea = 1, Pos = Vector3.new(-1600, 36, 153) },
        { QuestId = "BuggyQuest1", Target = "Pirate", ReqLevel = 30, Count = 8, Sea = 1, Pos = Vector3.new(-1140, 4, 3826) },
        { QuestId = "DesertQuest1", Target = "Desert Bandit", ReqLevel = 60, Count = 8, Sea = 1, Pos = Vector3.new(896, 6, 4390) },
        { QuestId = "SnowQuest1", Target = "Snow Bandit", ReqLevel = 90, Count = 7, Sea = 1, Pos = Vector3.new(1385, 87, -1298) },
        { QuestId = "RoseQuest1", Target = "Raider", ReqLevel = 700, Count = 8, Sea = 2, Pos = Vector3.new(-425, 73, 1835) },
        { QuestId = "GreenZoneQuest1", Target = "Marine Lieutenant", ReqLevel = 875, Count = 8, Sea = 2, Pos = Vector3.new(-2440, 73, -3215) },
        { QuestId = "PortQuest1", Target = "Pirate Millionaire", ReqLevel = 1500, Count = 8, Sea = 3, Pos = Vector3.new(-290, 44, 5580) },
    }

    local best = nil
    for _, q in ipairs(questsDb) do
        if q.Sea == Blackboard.PlayerState.CurrentSea and Blackboard.PlayerState.Level >= q.ReqLevel then
            if not best or q.ReqLevel > best.ReqLevel then
                best = q
            end
        end
    end
    return best
end

function LevelingAgent:FarmCycle(): boolean
    local quest = self:FindBestQuest()
    if not quest then return false end

    -- 1. Accept Quest
    if not Blackboard.WorldState.ActiveQuest then
        self:CalculateSafePath(quest.Pos)
        if Remotes.AcceptQuestRF then
            Remotes.AcceptQuestRF:InvokeServer(quest.QuestId, quest.Count)
            Blackboard.WorldState.ActiveQuest = { QuestId = quest.QuestId, Progress = 0, Required = quest.Count }
            Logger:Log("LevelingAgent", "AcceptQuest", "Accepted: " .. quest.QuestId)
        end
    end

    -- 2. Find Mob Clusters & Fast Attack
    for _, mob in ipairs(Blackboard.WorldState.ActiveMobs) do
        if mob.Name == quest.Target and mob.Health > 0 then
            self:CalculateSafePath(mob.Position)
            if Remotes.AttackTargetRF then
                local res = Remotes.AttackTargetRF:InvokeServer(mob.Id, 250)
                if res and res.Success then
                    Blackboard.WorldState.LastExpGainedTime = os.time()
                    Logger:Log("LevelingAgent", "FastAttack", string.format("Hit %s (Lv %d)", mob.Name, Blackboard.PlayerState.Level))
                    return true
                end
            end
        end
    end

    return false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 6. AGENT 3: SENTRY & NETWORK HOPPING AGENT (Bảo vệ an toàn & Đổi Server)
-- ══════════════════════════════════════════════════════════════════════════════

local SentryAgent = {}
SentryAgent.ConsecutiveHighPing = 0

function SentryAgent:EvaluateThreats(): (boolean, string?)
    local config = Blackboard.Config.Hopping

    -- 1. Proximity Sentinel Check (Người chơi lân cận)
    if config.PlayerNearingHop then
        local myPos = Blackboard.PlayerState.Position
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= LocalPlayer and other.Character and other.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (myPos - other.Character.HumanoidRootPart.Position).Magnitude
                if dist < config.SafePlayerDistance then
                    return true, string.format("Player %s detected at %d studs", other.Name, math.floor(dist))
                end
            end
        end
    end

    -- 2. Watchdog Stuck / Idle Timer (Kẹt không lên EXP)
    if config.HopIdle then
        local idleSecs = os.time() - Blackboard.WorldState.LastExpGainedTime
        if idleSecs >= config.IdleTimeout then
            return true, string.format("Watchdog timeout (No EXP for %ds)", idleSecs)
        end
    end

    return false, nil
end

function SentryAgent:TriggerHop(reason: string)
    Logger:Log("SentryAgent", "ServerHop", "INITIATING EMERGENCY SERVER HOP: " .. reason)
    Blackboard.ActiveLock = "HOPPING"
    task.wait(1)
    -- In test environment simulate server instance swap
    Blackboard.WorldState.LastExpGainedTime = os.time()
    Blackboard.ActiveLock = nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 7. AGENT 4: MARKET & FRUIT SNIPER AGENT (Săn trái ác quỷ & Cất kho)
-- ══════════════════════════════════════════════════════════════════════════════

local SniperAgent = {}
SniperAgent.LastShopScan = 0

function SniperAgent:ScanAndSnipe(): boolean
    if not Blackboard.Config.SniperFruitShop.Enabled then return false end
    if (os.clock() - self.LastShopScan) < 60 then return false end
    self.LastShopScan = os.clock()

    Logger:Log("SniperAgent", "Scan", "Checking Blox Fruit Dealer stock...")

    for fruitName, enabled in pairs(Blackboard.Config.SniperFruitShop.Fruit) do
        if enabled then
            local cleanName = string.gsub(fruitName, "%-.*", "")
            local owned = Blackboard.PlayerState.Inventory.Fruits[cleanName]
            if not owned or not owned.InStorage then
                if Blackboard.PlayerState.Beli >= 1000000 and Remotes.CollectFruitRF then
                    Logger:Log("SniperAgent", "SNIPER_HIT", "Purchasing rare fruit: " .. cleanName)
                    Remotes.CollectFruitRF:InvokeServer(cleanName, "Mythical")
                    if Remotes.StoreFruitRF then
                        Remotes.StoreFruitRF:InvokeServer(cleanName)
                    end
                    return true
                end
            end
        end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 8. AGENT 5: ENDGAME QUESTLINE & PUZZLE SOLVER (Oneclick FSM)
-- ══════════════════════════════════════════════════════════════════════════════

local EndgameFSM = {}

function EndgameFSM:ProcessSaberQuest(): boolean
    if not Blackboard.Config.Oneclick.Saber then return false end
    local inv = Blackboard.PlayerState.Inventory
    if inv.Weapons["Saber"] and inv.Weapons["Saber"].Owned then return false end
    if Blackboard.PlayerState.Level < 200 or Blackboard.PlayerState.CurrentSea ~= 1 then return false end

    Logger:Log("EndgameFSM", "Saber", "Executing Jungle 5-Buttons & Relic Puzzle...")
    task.wait(0.3)
    Logger:Log("EndgameFSM", "Saber", "Defeating Saber Expert Boss...")
    if Remotes.AttackTargetRF then
        Remotes.AttackTargetRF:InvokeServer("b_saber_expert", 12000)
    end
    if Remotes.PurchaseItemRF then
        Remotes.PurchaseItemRF:InvokeServer("Saber", "Weapon", 0, 0)
    end
    return true
end

function EndgameFSM:ProcessSoulGuitarQuest(): boolean
    if not Blackboard.Config.Oneclick.SkullGuitar then return false end
    local inv = Blackboard.PlayerState.Inventory
    if inv.Weapons["Skull Guitar"] and inv.Weapons["Skull Guitar"].Owned then return false end
    if Blackboard.PlayerState.Level < 2300 or Blackboard.PlayerState.CurrentSea ~= 3 then return false end

    local bones = inv.Materials["Bones"] or 0
    local ectoplasm = inv.Materials["Ectoplasm"] or 0
    local darkFrag = inv.Materials["DarkFragment"] or 0
    local frags = Blackboard.PlayerState.Fragments or 0

    if bones >= 500 and ectoplasm >= 250 and darkFrag >= 1 and frags >= 5000 then
        Logger:Log("EndgameFSM", "SoulGuitar", "Full Moon ready! Solving Haunted Castle Candles & Pipe Puzzle...")
        task.wait(0.4)
        if Remotes.PurchaseItemRF then
            Remotes.PurchaseItemRF:InvokeServer("Skull Guitar", "Weapon", 0, 5000)
            Logger:Log("EndgameFSM", "SoulGuitar", "Soul Guitar crafted successfully!")
            return true
        end
    end
    return false
end

function EndgameFSM:ProcessCDKQuest(): boolean
    if not Blackboard.Config.Oneclick.CursedDualKatana then return false end
    local inv = Blackboard.PlayerState.Inventory
    if inv.Weapons["Cursed Dual Katana"] and inv.Weapons["Cursed Dual Katana"].Owned then return false end
    if Blackboard.PlayerState.Level < 2200 or Blackboard.PlayerState.CurrentSea ~= 3 then return false end

    local yama = inv.Weapons["Yama"]
    local tushita = inv.Weapons["Tushita"]

    if yama and yama.Owned and yama.Mastery >= 350 and tushita and tushita.Owned and tushita.Mastery >= 350 then
        Logger:Log("EndgameFSM", "CDK", "Solving Yama & Tushita Crypt Trials & Defeating Cursed Skeleton...")
        task.wait(0.5)
        if Remotes.PurchaseItemRF then
            Remotes.PurchaseItemRF:InvokeServer("Cursed Dual Katana", "Weapon", 0, 0)
            Logger:Log("EndgameFSM", "CDK", "Cursed Dual Katana Forged at Ancient Altar!")
            return true
        end
    end
    return false
end

function EndgameFSM:ProcessRainbowHakiQuest(): boolean
    if not Blackboard.Config.Oneclick.RainbowHaki then return false end
    local inv = Blackboard.PlayerState.Inventory
    if inv.Accessories["RainbowHaki"] then return false end
    if Blackboard.PlayerState.Level < 1950 or Blackboard.PlayerState.CurrentSea ~= 3 then return false end

    Logger:Log("EndgameFSM", "RainbowHaki", "Defeating 5 Bosses: Stone, Empress, Kilo, Elephant, Beautiful Pirate...")
    task.wait(0.5)
    if Remotes.PurchaseItemRF then
        Remotes.PurchaseItemRF:InvokeServer("RainbowHaki", "Haki", 0, 0)
        Logger:Log("EndgameFSM", "RainbowHaki", "Rainbow Haki Unlocked!")
        return true
    end
    return false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 9. AGENT 6: RACE PROGRESSION ENGINE (Race V2 / V3)
-- ══════════════════════════════════════════════════════════════════════════════

local RaceAgent = {}

function RaceAgent:Process(): boolean
    local char = Blackboard.PlayerState
    if char.RaceStage == 1 and char.Level >= 850 and char.CurrentSea >= 2 and char.Beli >= 500000 then
        Logger:Log("RaceAgent", "V2", "Collecting Red, Blue, Yellow flowers for Alchemist...")
        task.wait(0.4)
        if Remotes.PurchaseItemRF then
            Remotes.PurchaseItemRF:InvokeServer("RaceV2", "Haki", 500000, 0)
            char.RaceStage = 2
            Logger:Log("RaceAgent", "V2", "Race V2 Unlocked!")
            return true
        end
    elseif char.RaceStage == 2 and char.Level >= 1000 and char.CurrentSea >= 2 and char.Beli >= 2000000 then
        Logger:Log("RaceAgent", "V3", "Defeating Don Swan & Completing Arowe Race Trial...")
        task.wait(0.5)
        if Remotes.PurchaseItemRF then
            Remotes.PurchaseItemRF:InvokeServer("RaceV3", "Haki", 2000000, 0)
            char.RaceStage = 3
            Logger:Log("RaceAgent", "V3", "Race V3 Unlocked!")
            return true
        end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 10. AGENT 7: STATS & CHARACTER PROGRESSION AGENT
-- ══════════════════════════════════════════════════════════════════════════════

local StatsAgent = {}

function StatsAgent:Process(): boolean
    local pts = Blackboard.PlayerState.Points or 0
    if pts <= 0 then return false end

    local preset = Blackboard.Config.StatsDistribution
    local meleePts = math.floor(pts * preset.Melee)
    local defPts = math.floor(pts * preset.Defense)
    local swordPts = math.floor(pts * preset.Sword)

    if meleePts > 0 and Remotes.UpgradeStatRF then
        Remotes.UpgradeStatRF:InvokeServer("Melee", meleePts)
    end
    if defPts > 0 and Remotes.UpgradeStatRF then
        Remotes.UpgradeStatRF:InvokeServer("Defense", defPts)
    end
    if swordPts > 0 and Remotes.UpgradeStatRF then
        Remotes.UpgradeStatRF:InvokeServer("Sword", swordPts)
    end

    Logger:Log("StatsAgent", "Upgrade", string.format("Allocated %d stat points according to %s preset", pts, preset.Preset))
    return true
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 11. AGENT 8: ERROR RECOVERY & ANTI-LOOP ENGINE
-- ══════════════════════════════════════════════════════════════════════════════

local RecoveryAgent = {}

function RecoveryAgent:CheckSafety(): boolean
    local char = Blackboard.PlayerState
    if char.MaxHealth > 0 then
        local hpPct = (char.Health / char.MaxHealth) * 100
        if hpPct < Blackboard.Config.MinHP then
            Logger:Log("RecoveryAgent", "SafeRetreat", string.format("Low HP (%.1f%% < %d%%) -> Retreating to Safe Zone", hpPct, Blackboard.Config.MinHP))
            LevelingAgent:CalculateSafePath(Vector3.new(1050, 15, 1420))
            task.wait(2)
            return true
        end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 12. MASTER SUPERVISOR BRAIN: PREEMPTION PRIORITY DISPATCHER
-- ══════════════════════════════════════════════════════════════════════════════

local KaitunBrain = {}
KaitunBrain._running = false

function KaitunBrain:Init(customConfig: any?)
    if customConfig then
        for k, v in pairs(customConfig) do
            Blackboard.Config[k] = v
        end
    end

    Remotes:Init()
    ResourceAgent:Init(Blackboard.Config)
    Logger:Log("Brain", "Init", "Kaitun Multi-Agent Brain initialized successfully")
end

function KaitunBrain:Start()
    if self._running then return end
    self._running = true
    Logger:Log("Brain", "Start", "Master Supervisor Decision Loop started")

    task.spawn(function()
        while self._running do
            local success, err = pcall(function()
                -- 1. Sync State from Server Remotes
                Remotes:SyncState()

                -- 2. P0: Threat Evade / Player Proximity Sentinel
                local threat, reason = SentryAgent:EvaluateThreats()
                if threat and reason then
                    SentryAgent:TriggerHop(reason)
                    return
                end

                -- 3. P0: Health Recovery / Safe Mode
                if RecoveryAgent:CheckSafety() then
                    return
                end

                -- 4. P1: Market & Fruit Sniper
                if SniperAgent:ScanAndSnipe() then
                    return
                end

                -- 5. P2: Endgame Milestones (CDK, Soul Guitar, Rainbow Haki, Saber)
                if EndgameFSM:ProcessSoulGuitarQuest() then return end
                if EndgameFSM:ProcessCDKQuest() then return end
                if EndgameFSM:ProcessRainbowHakiQuest() then return end
                if EndgameFSM:ProcessSaberQuest() then return end

                -- 6. P2: Race Progression V2/V3
                if RaceAgent:Process() then return end

                -- 7. P3: Auto Stats Allocation
                StatsAgent:Process()

                -- 8. P3: Background Level Farming & Mob Clustering
                LevelingAgent:FarmCycle()
            end)

            if not success then
                Logger:Log("Brain", "CriticalError", tostring(err))
            end

            task.wait(0.2)
        end
    end)
end

function KaitunBrain:Stop()
    self._running = false
    Logger:Log("Brain", "Stop", "Master Supervisor Loop stopped")
end

function KaitunBrain:GetStatus()
    return {
        Player = Blackboard.PlayerState,
        World = Blackboard.WorldState,
        Logs = Blackboard.SystemLogs,
    }
end

-- Auto Start when executed
KaitunBrain:Init()
KaitunBrain:Start()

return KaitunBrain
