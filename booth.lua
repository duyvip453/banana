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
local RunBox1, StopBox0, Box2_FindEligibleItems, Box4_ServerHop
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
        task.spawn(function()
            while running do
                if type(Box2_FindEligibleItems) == "function" then
                    local ok, err = pcall(Box2_FindEligibleItems)
                    if not ok then
                        warn("[Booth][Box 2] " .. tostring(err))
                    end
                end
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
    local config = _G.DyuBoothSniper
    if type(config) ~= "table" then
        boothid, itemid, quantity = nil, nil, nil
        warn("[Booth][Box 2] Config _G.DyuBoothSniper khong ton tai/khong phai table")
        print("[Booth][Box 2][OUTPUT]", boothid, itemid, quantity)
        return nil
    end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    if not Box2_PetsDirectory then
        local library = ReplicatedStorage:FindFirstChild("Library")
        local directory = library and library:FindFirstChild("Directory")
        local petsModule = directory and directory:FindFirstChild("Pets")
        if not petsModule then
            boothid, itemid, quantity = nil, nil, nil
            warn("[Booth][Box 2] Khong tim thay ReplicatedStorage.Library.Directory.Pets")
            print("[Booth][Box 2][OUTPUT]", boothid, itemid, quantity)
            return nil
        end

        local ok, pets = pcall(require, petsModule)
        if not ok or type(pets) ~= "table" then
            boothid, itemid, quantity = nil, nil, nil
            warn("[Booth][Box 2] require(Pets) that bai hoac khong tra ve table:", pets)
            print("[Booth][Box 2][OUTPUT]", boothid, itemid, quantity)
            return nil
        end
        Box2_PetsDirectory = pets
    end

    local things = workspace:FindFirstChild("__THINGS")
    local booths = things and things:FindFirstChild("Booths")
    if not booths then
        boothid, itemid, quantity = nil, nil, nil
        warn("[Booth][Box 2] Khong tim thay workspace.__THINGS.Booths")
        print("[Booth][Box 2][OUTPUT]", boothid, itemid, quantity)
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
        print("[Booth][Box 2][RULE]", rule.item, "targetAssetId=", targetAssetId, "maxPrice=", maxPrice)
        if not targetAssetId or not maxPrice then
            warn("[Booth][Box 2] Rule thieu item thumbnail ID hoac maxprice khong hop le:", rule.item, rule.maxprice)
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
                            print("[Booth][Box 2][PRICE CHECK]", "pet=", rule.item, "listing=", listing.Name, "price=", price, "maxPrice=", maxPrice)
                        else
                            print("[Booth][Box 2][PRICE ERROR] Khong doc duoc Cost", "pet=", rule.item, "listing=", listing.Name)
                        end

                        if price ~= nil and price <= maxPrice then
                            local ownerId = booth:GetAttribute("Owner")
                            local listingQuantity = listing:GetAttribute("Quantity")
                            print("[Booth][Box 2][CANDIDATE]", "ownerId=", ownerId, "listingId=", listing.Name, "quantity=", listingQuantity)
                            if ownerId ~= nil and listing.Name ~= "" and listingQuantity ~= nil then
                                return ownerId, listing.Name, listingQuantity
                            else
                                warn("[Booth][Box 2] Listing dung gia nhung thieu Owner/Name/Quantity")
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

    -- Chi tra ve mot listing. Neu khong tim thay, danh dau item het hang
    -- va chuyen ngay sang item tiep theo trong cung lan quet.
    for index = 1, maxIndex do
        local key = "Items_" .. index
        local rule = config[key]

        if not Box2_ExhaustedItems[key] and type(rule) == "table"
            and type(rule.item) == "string" and rule.item ~= "" then
            local foundBoothId, foundItemId, foundQuantity = FindListingForRule(rule)

            if foundBoothId ~= nil then
                boothid = foundBoothId
                itemid = foundItemId
                quantity = foundQuantity
                print("[Booth][Box 2][FOUND]", "item=", rule.item, "boothid=", boothid, "itemid=", itemid, "quantity=", quantity)
                print("[Booth][Box 2][OUTPUT]", boothid, itemid, quantity)
                return {
                    boothid = boothid,
                    itemid = itemid,
                    quantity = quantity,
                    item = rule.item,
                }
            end

            warn("[Booth][Box 2] Khong tim thay listing cho rule:", key, rule.item, "maxprice=", rule.maxprice, "- danh dau exhausted")
            Box2_ExhaustedItems[key] = true
            boothid, itemid, quantity = nil, nil, nil
        end
    end

    boothid, itemid, quantity = nil, nil, nil
    print("[Booth][Box 2][OUTPUT] Khong tim thay listing:", boothid, itemid, quantity)
    if not Box2_ServerHopRequested then
        Box2_ServerHopRequested = true
        if type(Box4_ServerHop) == "function" then
            Box4_ServerHop()
        end
    end
    return nil
end
-- [END] BOX 2: TIM ITEM DU DIEU KIEN

Box0_AutoSniperBooth()


-- [START] BOX 3: PURCHASE
-- Box 3 doc lap: chuan bi args mua moi 0.5 giay khi AutoSearch dang bat.
task.spawn(function()
    while true do
        if Settings.AutoSearch then
            local ownerId = boothid
            local listingId = itemid
            local listingQuantity = quantity

            -- Chi tao args khi Box 2 da tim duoc listing hop le.
            if ownerId ~= nil
                and listingId ~= nil
                and tonumber(listingQuantity) ~= nil then

                local args = {
                    ownerId,
                    {
                        [listingId] = listingQuantity
                    }
                }

                print("[Booth][Box 3][ARGS READY]", "ownerId=", ownerId, "listingId=", listingId, "quantity=", listingQuantity)
                print("[Booth][Box 3][ARGS]", args)

                -- TODO: Dan lenh goi Remote mua listing cua ban vao day.
                -- Vi du: <RemoteCuaBan>:FireServer(unpack(args))
                -- Thay dong vi du bang lenh goi Remote chinh xac cua game.
            else
                print("[Booth][Box 3][WAITING]", "ownerId=", ownerId, "listingId=", listingId, "quantity=", listingQuantity)
            end
        end

        task.wait(0.5)
    end
end)
-- [END] BOX 3: PURCHASE


-- [START] BOX 4: SERVER HOP
-- TODO: Chua them chuc nang.
-- Muc dich: Khu vuc xu ly doi server khi khong con listing
-- nao dat dieu kien sau mot luot quet thanh cong.
-- [END] BOX 4: SERVER HOP
