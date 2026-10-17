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

-- [START] BOX 1: CHECK GEMS
local CheckGemsToggle
local AutoSearchToggle
local CheckGemsLoopToken = 0

local function GetMyDiamonds()
    local leaderstats = Player:FindFirstChild("leaderstats")
    if not leaderstats then
        return nil
    end

    for _, stat in ipairs(leaderstats:GetChildren()) do
        if stat.Name:find("Diamonds", 1, true)
            and (stat:IsA("IntValue") or stat:IsA("NumberValue")) then
            return stat.Value
        end
    end

    return nil
end

local function GetMinimumGems()
    local config = _G.DyuBoothSniper
    if type(config) ~= "table" then
        return 0
    end

    local minimum = tonumber(config.MinimumGems)
    return minimum or 0
end

local function HasEnoughGems()
    local diamonds = GetMyDiamonds()
    if diamonds == nil then
        return false, nil
    end

    return diamonds >= GetMinimumGems(), diamonds
end

local function StopAutoSearch(reason)
    Settings.AutoSearch = false
    SaveConfig()

    if AutoSearchToggle then
        AutoSearchToggle:UpdateState(false)
    end

    if reason then
        warn("[DYU Booth] Auto Search da dung: " .. reason)
    end
end

local function StartCheckGemsLoop()
    CheckGemsLoopToken += 1
    local myToken = CheckGemsLoopToken

    task.spawn(function()
        while Settings.CheckGems and myToken == CheckGemsLoopToken do
            local enough, diamonds = HasEnoughGems()

            if not enough then
                local minimum = GetMinimumGems()
                if diamonds == nil then
                    StopAutoSearch("khong doc duoc Diamonds")
                else
                    StopAutoSearch(("Diamonds %d < MinimumGems %d"):format(diamonds, minimum))
                end
            end

            task.wait(0.5)
        end
    end)
end

CheckGemsToggle = BoothTab:CreateToggle({
    Name = "Check Gem",
    CurrentValue = Settings.CheckGems,
    Callback = function(Value)
        Settings.CheckGems = Value
        SaveConfig()

        CheckGemsLoopToken += 1
        if Value then
            StartCheckGemsLoop()
        end
    end
})

-- [END] BOX 1: CHECK GEMS

-- [START] Toggle Auto Search
AutoSearchToggle = BoothTab:CreateToggle({
    Name = "Auto Search",
    CurrentValue = Settings.AutoSearch,
    Callback = function(Value)
        if Value then
            local enough, diamonds = HasEnoughGems()
            if not enough then
                Settings.AutoSearch = false
                SaveConfig()
                if AutoSearchToggle then
                    AutoSearchToggle:UpdateState(false)
                end

                if diamonds == nil then
                    warn("[DYU Booth] Khong bat Auto Search: khong doc duoc Diamonds.")
                else
                    warn(("[DYU Booth] Khong bat Auto Search: Diamonds %d < MinimumGems %d.")
                        :format(diamonds, GetMinimumGems()))
                end
                return
            end
        end

        Settings.AutoSearch = Value
        SaveConfig()
    end
})

-- [END] Toggle Auto Search


-- [START] BOX 2: TIM ITEM DU DIEU KIEN
-- TODO: Chua them chuc nang.
-- Muc dich: Quet listing, nhan dien ten item, gia, ListingID,
-- BoothID va Quantity; doi chieu voi cau hinh nguoi dung.
-- [END] BOX 2: TIM ITEM DU DIEU KIEN


-- [START] BOX 3: PURCHASE
-- TODO: Chua them chuc nang.
-- Muc dich: Khu vuc xu ly mua listing da duoc xac minh.
-- [END] BOX 3: PURCHASE


-- [START] BOX 4: SERVER HOP
-- TODO: Chua them chuc nang.
-- Muc dich: Khu vuc xu ly doi server khi khong con listing
-- nao dat dieu kien sau mot luot quet thanh cong.
-- [END] BOX 4: SERVER HOP
