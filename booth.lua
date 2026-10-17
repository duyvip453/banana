-- [START] Khởi tạo dịch vụ và cấu hình riêng cho Booth
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local ConfigFileName = "DYUHUB_Booth_" .. game.PlaceId .. "_" .. Player.UserId .. ".json"

local Settings = {
    AutoSearch = false,
    CheckGems = false,
}

local function SaveConfig()
    if type(writefile) ~= "function" then
        return false
    end

    local ok = pcall(function()
        writefile(ConfigFileName, HttpService:JSONEncode(Settings))
    end)
    return ok
end

local function LoadConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return
    end

    local existsOk, exists = pcall(function()
        return isfile(ConfigFileName)
    end)
    if not existsOk then
        return
    end

    if not exists then
        SaveConfig()
        return
    end

    local readOk, data = pcall(function()
        return HttpService:JSONDecode(readfile(ConfigFileName))
    end)
    if not readOk or type(data) ~= "table" then
        return
    end

    for key, value in pairs(data) do
        if Settings[key] ~= nil and type(value) == type(Settings[key]) then
            Settings[key] = value
        end
    end
end

LoadConfig()
-- [END] Khởi tạo dịch vụ và cấu hình riêng cho Booth

-- [START] Tải module giao diện dùng chung của DYU Hub
local bgUrl = "https://raw.githubusercontent.com/duyvip453/dyu-Hub/refs/heads/main/backgroud.lua?v=" .. math.random(1, 100000)
local success, rawCode = pcall(function()
    return game:HttpGet(bgUrl)
end)
if not success or type(rawCode) ~= "string" or rawCode == "" then
    return
end

local compileUI = loadstring(rawCode)
if type(compileUI) ~= "function" then
    return
end

local moduleOk, UIModule = pcall(compileUI)
if not moduleOk or type(UIModule) ~= "table" or type(UIModule.Init) ~= "function" then
    return
end

local initOk, Window = pcall(function()
    return UIModule:Init({
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "DYU_HUB",
            FileName = "Booth"
        }
    })
end)
if not initOk or type(Window) ~= "table" or type(Window.CreateTab) ~= "function" then
    return
end
-- [END] Tải module giao diện dùng chung của DYU Hub

-- [START] Tab Booth / Plaza
local BoothTab = Window:CreateTab({
    Name = "Booth",
    Icon = "search",
    ImageSource = "Material",
    ShowTitle = true
})

BoothTab:CreateSection("Tìm đồ trong Plaza")

-- [START] BOX 0: AUTO SNIPER BOOTH
local RunBox1, StopBox0
local function Box0_AutoSniperBooth()
    local running = false
    local toggle

    StopBox0 = function()
        running = false
        Settings.AutoSearch = false
        SaveConfig()
        if toggle then toggle:UpdateState(false) end
    end

    local function Start()
        if running then return end
        running = true
        Settings.AutoSearch = true
        SaveConfig()
        task.spawn(function()
            while running do
                RunBox1()
                task.wait(0.5)
            end
        end)
    end

    toggle = BoothTab:CreateToggle({
        Name = "Auto Sniper Booth",
        CurrentValue = false,
        Callback = function(value)
            if value then Start() else StopBox0() end
        end
    })
end
-- [END] BOX 0: AUTO SNIPER BOOTH

-- [START] BOX 1: CHECK GEMS
RunBox1 = function()
    local stats = Player:FindFirstChild("leaderstats")
    local gems
    if stats then
        for _, value in ipairs(stats:GetChildren()) do
            if value.Name:find("Diamonds", 1, true)
                and (value:IsA("IntValue") or value:IsA("NumberValue")) then
                gems = value.Value
                break
            end
        end
    end

    local config = _G.DyuBoothSniper
    local minimum = type(config) == "table" and tonumber(config.MinimumGems) or 0
    if gems == nil or gems < minimum then
        StopBox0()
        return
    end

    Box2_FindEligibleItems()
end
-- [END] BOX 1: CHECK GEMS

-- [START] BOX 2: TIM ITEM DU DIEU KIEN
local function Box2_FindEligibleItems()
    -- Chua them logic quet listing.
end
-- [END] BOX 2: TIM ITEM DU DIEU KIEN

Box0_AutoSniperBooth()


-- [START] BOX 3: PURCHASE
-- TODO: Chua them chuc nang.
-- Muc dich: Khu vuc xu ly mua listing da duoc xac minh.
-- [END] BOX 3: PURCHASE


-- [START] BOX 4: SERVER HOP
-- TODO: Chua them chuc nang.
-- Muc dich: Khu vuc xu ly doi server khi khong con listing
-- nao dat dieu kien sau mot luot quet thanh cong.
-- [END] BOX 4: SERVER HOP
