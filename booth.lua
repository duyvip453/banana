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
-- [START] BOX 2 STATUS LABEL
local Tab1 = BoothTab
local function Box2_DisplayValue(value)
    if value == nil then return "nil" end
    return tostring(value)
end
local Box2StatusLabel = Tab1:CreateLabel({
    Text = "boothid: nil | itemid: nil | quantity: nil",
    Style = 2
})
-- [END] BOX 2 STATUS LABEL


-- [START] BOX 0: AUTO SNIPER BOOTH
local RunBox1, StopBox0, Box2_FindEligibleItems, Box3_PurchaseCurrentListing, Box4_ServerHop
local function Box0_AutoSniperBooth()
    local running = false
    local toggle

    StopBox0 = function()
        if not running and not Settings.AutoSearch then return end
        running = false
        Settings.AutoSearch = false
        boothid, itemid, quantity = nil, nil, nil
        SaveConfig()
        if toggle then toggle:UpdateState(false) end
    end

    local function Start()
        if running then return end
        running = true
        Settings.AutoSearch = true
        SaveConfig()

        -- Box 1 doc lap: kiem tra Gems moi 2 giay.
        task.spawn(function()
            while running do
                local ok, err = pcall(RunBox1)
                if not ok then
                    warn("[Booth][Box 1] " .. tostring(err))
                end
                task.wait(2)
            end
        end)

        -- Box 2 doc lap: cap nhat listing moi 0.5 giay.
        print("[Booth][Box 0] Auto Sniper Booth BAT - khoi dong worker Box 2")
        task.spawn(function()
            while running do
                if type(Box2_FindEligibleItems) == "function" then
                    local ok, err = pcall(Box2_FindEligibleItems)
                    if not ok then
                        warn("[Booth][Box 2] Loi khi quet: " .. tostring(err))
                    end
                else
                    warn("[Booth][Box 2] Ham Box2_FindEligibleItems chua duoc khoi tao")
                end
                task.wait(0.5)
            end
            print("[Booth][Box 2] Worker da dung")
        end)


        -- Box 3: goi ham mua tu khu vuc Box 3, chi khi Box 0 dang bat.
        task.spawn(function()
            while running and Settings.AutoSearch do
                local ok, err = pcall(Box3_PurchaseCurrentListing)
                if not ok then
                    warn("[Booth][Box 3] " .. tostring(err))
                end
                task.wait(0.5)
            end
        end)

    end

    toggle = BoothTab:CreateToggle({
        Name = "Auto Sniper Booth",
        CurrentValue = false,
        Callback = function(value)
            if value then
                print("[Booth][Box 0] Toggle duoc BAT")
                Start()
            else
                print("[Booth][Box 0] Toggle duoc TAT")
                StopBox0()
            end
        end
    })
end
-- [END] BOX 0: AUTO SNIPER BOOTH

-- [START] BOX 1: CHECK GEMS
RunBox1 = function()
    if not Settings.AutoSearch then return end

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
end
-- [END] BOX 1: CHECK GEMS

-- [START] BOX 2: TIM ITEM DU DIEU KIEN
-- Du lieu dung chung cho Box 3; Box 2 cap nhat lai sau moi lan quet.
boothid = nil
itemid = nil
quantity = nil

local Box2_ExhaustedItems = {}
local Box2_PetsDirectory
local Box2_ServerHopRequested = false

Box2_FindEligibleItems = function()
    print("[Booth][Box 2] Bat dau quet config _G.DyuBoothSniper")
    local config = _G.DyuBoothSniper
    if type(config) ~= "table" then
        warn("[Booth][Box 2] Khong co config table _G.DyuBoothSniper; kiem tra script config chay truoc Booth")
        boothid, itemid, quantity = nil, nil, nil
        return nil
    end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    if not Box2_PetsDirectory then
        local library = ReplicatedStorage:FindFirstChild("Library")
        local directory = library and library:FindFirstChild("Directory")
        local petsModule = directory and directory:FindFirstChild("Pets")
        if not petsModule then
            warn("[Booth][Box 2] Khong tim thay ReplicatedStorage.Library.Directory.Pets")
            boothid, itemid, quantity = nil, nil, nil
            return nil
        end

        local ok, pets = pcall(require, petsModule)
        if not ok or type(pets) ~= "table" then
            warn("[Booth][Box 2] require Pets that bai: " .. tostring(pets))
            boothid, itemid, quantity = nil, nil, nil
            return nil
        end
        Box2_PetsDirectory = pets
    end

    local things = workspace:FindFirstChild("__THINGS")
    local booths = things and things:FindFirstChild("Booths")
    if not booths then
        warn("[Booth][Box 2] Khong tim thay workspace.__THINGS.Booths")
        boothid, itemid, quantity = nil, nil, nil
        return nil
    end

    local function ParsePrice(value)
        if type(value) == "number" then return value end
        if type(value) ~= "string" then return nil end

        local text = value:lower():gsub(",", ""):gsub("%s+", "")
        local number, suffix = text:match("^(%d+%.?%d*)([kmb]?)$")
        number = tonumber(number)
        if not number then return nil end
        local multiplier = ({ k = 1e3, m = 1e6, b = 1e9 })[suffix] or 1
        return number * multiplier
    end

    local function ReadCost(cost)
        if not cost then return nil end
        if cost:IsA("IntValue") or cost:IsA("NumberValue") then
            return cost.Value
        elseif cost:IsA("StringValue") then
            return ParsePrice(cost.Value)
        elseif cost:IsA("TextLabel") or cost:IsA("TextButton") then
            return ParsePrice(cost.Text)
        end

        for _, child in ipairs(cost:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                local parsed = ParsePrice(child.Text)
                if parsed ~= nil then return parsed end
            elseif child:IsA("IntValue") or child:IsA("NumberValue") then
                return child.Value
            elseif child:IsA("StringValue") then
                local parsed = ParsePrice(child.Value)
                if parsed ~= nil then return parsed end
            end
        end
        return nil
    end

    local function GetPetAssetId(petName)
        local pet = Box2_PetsDirectory[petName]
        if type(pet) ~= "table" or type(pet.thumbnail) ~= "string" then
            return nil
        end
        return pet.thumbnail:match("%d+")
    end

    local function FindListingForRule(rule)
        local targetAssetId = GetPetAssetId(rule.item)
        local maxPrice = tonumber(rule.maxprice)
        if not targetAssetId or not maxPrice then
            return nil
        end

        for _, booth in ipairs(booths:GetChildren()) do
            local pets = booth:FindFirstChild("Pets")
            local top = pets and pets:FindFirstChild("BoothTop")
            local scroll = top and (top:FindFirstChild("PetScroll") or top:FindFirstChild("PetScroll", true))

            if scroll then
                for _, listing in ipairs(scroll:GetChildren()) do
                    local icon = listing:FindFirstChild("Icon", true)
                    local image = icon and icon:IsA("ImageLabel") and icon.Image

                    if type(image) == "string" and image:match("%d+") == targetAssetId then
                        local buy = listing:FindFirstChild("Buy", true)
                        local price = ReadCost(buy and buy:FindFirstChild("Cost", true))

                        if price ~= nil then
                        else
                        end

                        if price ~= nil and price <= maxPrice then
                            local ownerId = booth:GetAttribute("Owner")
                            local listingQuantity = listing:GetAttribute("Quantity")
                            if ownerId ~= nil and listing.Name ~= "" and listingQuantity ~= nil then
                                return ownerId, listing.Name, listingQuantity
                            else
                            end
                        end
                    end
                end
            end
        end
        return nil
    end

    -- Duyet Items_1, Items_2... theo thu tu so, khong gioi han so luong item.
    local maxIndex = 0
    for key in pairs(config) do
        if type(key) == "string" then
            local index = tonumber(key:match("^Items_(%d+)$"))
            if index and index > maxIndex then maxIndex = index end
        end
    end

    print("[Booth][Box 2] So muc Items_N phat hien: " .. tostring(maxIndex))
    if maxIndex == 0 then
        warn("[Booth][Box 2] Config khong co key Items_1, Items_2... hop le")
    end

    -- Chi tra ve mot listing. Neu khong tim thay, danh dau item het hang
    -- va chuyen ngay sang item tiep theo trong cung lan quet.
    for index = 1, maxIndex do
        local key = "Items_" .. index
        local rule = config[key]

        if not Box2_ExhaustedItems[key] and type(rule) == "table"
            and type(rule.item) == "string" and rule.item ~= "" then
            local targetAssetId = GetPetAssetId(rule.item)
            print(string.format(
                "[Booth][Box 2] Dang quet %s | item=%s | assetId=%s | maxprice=%s",
                key,
                rule.item,
                tostring(targetAssetId),
                tostring(rule.maxprice)
            ))

            local foundBoothId, foundItemId, foundQuantity = FindListingForRule(rule)

            if foundBoothId ~= nil then
                boothid = foundBoothId
                itemid = foundItemId
                quantity = foundQuantity
                print(string.format(
                    "[Booth][Box 2] TIM THAY | item=%s | boothid=%s | itemid=%s | quantity=%s",
                    rule.item,
                    tostring(boothid),
                    tostring(itemid),
                    tostring(quantity)
                ))
                return {
                    boothid = boothid,
                    itemid = itemid,
                    quantity = quantity,
                    item = rule.item,
                }
            end
            print(string.format(
                "[Booth][Box 2] Chua tim thay listing dat dieu kien cho %s",
                rule.item
            ))
            Box2_ExhaustedItems[key] = true
            boothid, itemid, quantity = nil, nil, nil
        end
    end

    boothid, itemid, quantity = nil, nil, nil
    if not Box2_ServerHopRequested then
        Box2_ServerHopRequested = true
        if type(Box4_ServerHop) == "function" then
            Box4_ServerHop()
        end
    end
    return nil
end
-- [END] BOX 2: TIM ITEM DU DIEU KIEN




-- [START] BOX 3: PURCHASE
-- Box 3 duoc khai bao rieng; Box 0 chi dieu phoi viec goi ham khi toggle ON.
Box3_PurchaseCurrentListing = function()
    if not Settings.AutoSearch then return end

    local ownerId = boothid
    local listingId = itemid
    local listingQuantity = quantity
    if ownerId == nil or listingId == nil or tonumber(listingQuantity) == nil then
        return
    end

    local args = {
        ownerId,
        {
            [listingId] = listingQuantity
        },
        {
            Caller = {
                LineNumber = 527,
                ScriptClass = "ModuleScript",
                Variadic = false,
                Traceback = "ReplicatedStorage.Library.Client.BoothCmds:527 function PromptPurchase2\\nReplicatedStorage.Library.Client.BoothCmds:654 function promptOtherPlayerBooth2\\nReplicatedStorage.Library.Client.BoothCmds:157",
                ScriptPath = "ReplicatedStorage.Library.Client.BoothCmds",
                FunctionName = "PromptPurchase2",
                Handle = "function: 0x4afa980d0c15edc1",
                ScriptType = "Instance",
                ParameterCount = 2,
                SourceIdentifier = "ReplicatedStorage.Library.Client.BoothCmds"
            }
        }
    }

    game:GetService("ReplicatedStorage")
        :WaitForChild("Network")
        :WaitForChild("Booths_RequestPurchase")
        :InvokeServer(unpack(args))
end
-- [END] BOX 3: PURCHASE




-- [START] BOX 4: SERVER HOP
-- Ham rieng cua Box 4. Chua co logic doi server nen hien tai chi kiem tra toggle.
Box4_ServerHop = function()
    if not Settings.AutoSearch then return end
    -- TODO: Them logic doi server tai day.
end
-- [END] BOX 4: SERVER HOP

Box0_AutoSniperBooth()

-- [START] BOX 2 DISPLAY UPDATE
task.spawn(function()
    while true do
        Box2StatusLabel:Set(
            "boothid: " .. Box2_DisplayValue(boothid)
            .. " | itemid: " .. Box2_DisplayValue(itemid)
            .. " | quantity: " .. Box2_DisplayValue(quantity)
        )
        task.wait(0.1)
    end
end)
-- [END] BOX 2 DISPLAY UPDATE
