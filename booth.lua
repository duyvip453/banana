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

 local Controller = loadstring(game:HttpGet("https://raw.githubusercontent.com/duyvip453/banana/refs/heads/main/script.lua"))()

toggle = BoothTab:CreateToggle({
    Name = "Auto Sniper Booth",
    CurrentValue = false,
    Callback = function(value)
        Controller:Toggle("BoothSniper", value, toggle)
    end
})

BoothTab:CreateSection("DEBUG Tools")

local MIN_GEM_TEST = 1000000
local _gemThread = nil

local t1 = BoothTab:CreateToggle({
    Name = "[TEST 1] Gem Guard (min 1M)",
    CurrentValue = false,
    Callback = function(value)
        if value then
            local leaderstats = Player:FindFirstChild("leaderstats")
            local diam = nil
            if leaderstats then
                for _, c in ipairs(leaderstats:GetChildren()) do
                    if c.Name:find("Diamond") then diam = c break end
                end
            end
            local gems = diam and diam.Value or 0
            if gems < MIN_GEM_TEST then
                print("TEST1: Gem (" .. tostring(gems) .. ") < 1M, cannot enable")
                pcall(function() t1:Set(false) end)
                return
            end
            print("TEST1: Gem Guard ON | Current gems: " .. tostring(gems))
            _gemThread = task.spawn(function()
                while true do
                    task.wait(2)
                    local ls = Player:FindFirstChild("leaderstats")
                    local d = nil
                    if ls then
                        for _, c in ipairs(ls:GetChildren()) do
                            if c.Name:find("Diamond") then d = c break end
                        end
                    end
                    local g = d and d.Value or 0
                    print("TEST1: Gems = " .. tostring(g))
                    if g < MIN_GEM_TEST then
                        print("TEST1: Gem dropped below 1M! Disabling...")
                        pcall(function() t1:Set(false) end)
                        _gemThread = nil
                        break
                    end
                end
            end)
        else
            if _gemThread then task.cancel(_gemThread) _gemThread = nil end
            print("TEST1: Gem Guard OFF")
        end
    end
})

local _scanResult = { sellerId = nil, uid = nil, amount = nil }
local _scanThread = nil

local function getBoothTable()
    if type(filtergc) == "function" then
        for _, f in ipairs(filtergc("function", { Name = "PromptPurchase2" }, false)) do
            if debug.getinfo(f).source:find("BoothCmds") then
                return debug.getupvalue(f, 3)
            end
        end
    end
    if type(getgc) == "function" then
        for _, obj in ipairs(getgc(false)) do
            if type(obj) == "function" and islclosure(obj) then
                local info = debug.getinfo(obj)
                if info.name == "PromptPurchase2" and info.source:find("BoothCmds") then
                    return debug.getupvalue(obj, 3)
                end
            end
        end
    end
    return nil
end

local function getFullName(d, baseId)
    if not d then return baseId end
    local isG, isR, isS = (d.pt == 1), (d.pt == 2), (d.sh == true)
    if isS and isR then return "Shiny Rainbow " .. baseId end
    if isS and isG then return "Shiny Golden " .. baseId end
    if isR then return "Rainbow " .. baseId end
    if isG then return "Golden " .. baseId end
    if isS then return "Shiny " .. baseId end
    return baseId
end

local t2 = BoothTab:CreateToggle({
    Name = "[TEST 2] Scanner",
    CurrentValue = false,
    Callback = function(value)
        if value then
            _scanThread = task.spawn(function()
                while true do
                    local targets = {}
                    if _G.DyuBoothSniper then
                        for k, v in pairs(_G.DyuBoothSniper) do
                            if type(k) == "string" and k:lower():find("item") and type(v) == "table" then
                                local name = v.item or v.Item or v.name or v.Name
                                local maxp = tonumber(v.maxprice or v.MaxPrice or v.price or v.Price)
                                if name and maxp then
                                    table.insert(targets, { name = tostring(name):lower(), maxPrice = maxp })
                                end
                            end
                        end
                    end

                    local found = false
                    local boothTable = getBoothTable()
                    if boothTable and #targets > 0 then
                        for player, data in pairs(boothTable) do
                            if data.Listings then
                                local sId = typeof(player) == "Instance" and player.UserId or (player.UserId or 0)
                                if sId ~= Player.UserId then
                                    for uid, l in pairs(data.Listings) do
                                        local d = l.Item and l.Item._data
                                        local baseId = d and d.id or (l.Item and l.Item.id) or "Unknown"
                                        local fullName = getFullName(d, baseId)
                                        local amt = (d and d._am) or 1
                                        local price = l.DiamondCost or 0
                                        for _, tgt in ipairs(targets) do
                                            if (fullName:lower():find(tgt.name, 1, true) or baseId:lower():find(tgt.name, 1, true)) and price <= tgt.maxPrice then
                                                _scanResult.sellerId = sId
                                                _scanResult.uid = uid
                                                _scanResult.amount = amt
                                                print("TEST2: FOUND '" .. fullName .. "' | Price: " .. tostring(price) .. " | SellerID: " .. tostring(sId) .. " | UID: " .. uid .. " | Qty: " .. tostring(amt))
                                                found = true
                                                break
                                            end
                                        end
                                        if found then break end
                                    end
                                end
                            end
                            if found then break end
                        end
                    end

                    if not found then
                        _scanResult.sellerId = nil
                        _scanResult.uid = nil
                        _scanResult.amount = nil
                        print("TEST2: No matching item found")
                    end

                    task.wait(0.5)
                end
            end)
            print("TEST2: Scanner ON")
        else
            if _scanThread then task.cancel(_scanThread) _scanThread = nil end
            _scanResult.sellerId = nil
            _scanResult.uid = nil
            _scanResult.amount = nil
            print("TEST2: Scanner OFF")
        end
    end
})

local _buyThread = nil

local t3 = BoothTab:CreateToggle({
    Name = "[TEST 3] Buyer",
    CurrentValue = false,
    Callback = function(value)
        if value then
            local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Network") and game:GetService("ReplicatedStorage").Network:FindFirstChild("Booths_RequestPurchase")
            if not remote then
                print("TEST3: Remote not found, cannot enable")
                pcall(function() t3:Set(false) end)
                return
            end
            _buyThread = task.spawn(function()
                while true do
                    local sId = _scanResult.sellerId
                    local uid = _scanResult.uid
                    local amt = _scanResult.amount
                    if sId and uid and amt then
                        local ok, res = pcall(function()
                            return remote:InvokeServer(sId, { [uid] = amt })
                        end)
                        if ok then
                            print("TEST3: Buy OK | UID: " .. uid)
                        else
                            print("TEST3: Buy FAILED | " .. tostring(res))
                        end
                    else
                        print("TEST3: Waiting for TEST2 to find an item...")
                    end
                    task.wait(0.2)
                end
            end)
            print("TEST3: Buyer ON")
        else
            if _buyThread then task.cancel(_buyThread) _buyThread = nil end
            print("TEST3: Buyer OFF")
        end
    end
})
