local Core = {
    Services = {
        Players = game:GetService("Players"),
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
        HttpService = game:GetService("HttpService"),
        TeleportService = game:GetService("TeleportService"),
    },
    Player = game:GetService("Players").LocalPlayer,
}

local Features = {}

Features.BoothSniper = {
    Enabled = false,
    Thread = nil,
    Blacklist = {},
    ToggleRef = nil,

    GetBoothTable = function(self)
        if type(filtergc) == "function" then
            local funcs = filtergc("function", { Name = "PromptPurchase2" }, false)
            for _, f in ipairs(funcs) do
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
        print("BUG_CORE: Cannot hook booth table")
        return nil
    end,

    GetFullName = function(self, d, baseId)
        if not d then return baseId end
        local isG, isR, isS = (d.pt == 1), (d.pt == 2), (d.sh == true)
        if isS and isR then return "Shiny Rainbow " .. baseId end
        if isS and isG then return "Shiny Golden " .. baseId end
        if isR then return "Rainbow " .. baseId end
        if isG then return "Golden " .. baseId end
        if isS then return "Shiny " .. baseId end
        return baseId
    end,

    Step1_CheckGems = function(self)
        local leaderstats = Core.Player:FindFirstChild("leaderstats")
        local diam = leaderstats and (leaderstats:FindFirstChild("💎 Diamonds") or leaderstats:FindFirstChild("Diamonds"))
        local currentGems = diam and diam.Value or 0
        local minGems = _G.DyuBoothSniper and tonumber(_G.DyuBoothSniper.MinimumGems) or 0

        if minGems >= currentGems then
            print("BUG_STEP1: Current gems (" .. tostring(currentGems) .. ") <= MinimumGems (" .. tostring(minGems) .. "), stopping sniper")
            self:Stop()
            return false
        end
        return true
    end,

    Step2_ScanItem = function(self)
        local targets = {}
        if _G.DyuBoothSniper then
            for k, v in pairs(_G.DyuBoothSniper) do
                if type(k) == "string" and k:lower():find("items_") and type(v) == "table" then
                    local name = v.item or v.Item or v.name or v.Name
                    local maxp = tonumber(v.maxprice or v.MaxPrice or v.price or v.Price)
                    if name and maxp then
                        table.insert(targets, { name = tostring(name):lower(), maxPrice = maxp })
                    end
                end
            end
        end

        local boothTable = self:GetBoothTable()
        if not boothTable then
            print("BUG_STEP2: Booth table nil")
            return nil
        end

        for player, data in pairs(boothTable) do
            if data.Listings then
                local sellerId = typeof(player) == "Instance" and player.UserId or (player.UserId or 0)
                for uid, l in pairs(data.Listings) do
                    if not self.Blacklist[uid] then
                        local d = l.Item and l.Item._data
                        local baseId = d and d.id or (l.Item and l.Item.id) or "Unknown"
                        local fullName = self:GetFullName(d, baseId)
                        local amt = (d and d._am) or 1
                        local cost = l.DiamondCost or 0
                        local unitCost = cost / amt

                        for _, tgt in ipairs(targets) do
                            if (fullName:lower():find(tgt.name, 1, true) or baseId:lower():find(tgt.name, 1, true)) and unitCost <= tgt.maxPrice then
                                return {
                                    sellerId = sellerId,
                                    uid = uid,
                                    amount = amt,
                                    cost = cost,
                                    fullName = fullName
                                }
                            end
                        end
                    end
                end
            end
        end

        print("BUG_STEP2: No target items left in server")
        return nil
    end,

    Step3_BuyItem = function(self, item)
        if not item then
            print("BUG_STEP3: Item is nil")
            return
        end
        self.Blacklist[item.uid] = true

        local remote = Core.Services.ReplicatedStorage:FindFirstChild("Network") and Core.Services.ReplicatedStorage.Network:FindFirstChild("Booths_RequestPurchase")
        if not remote then
            print("BUG_STEP3: Remote Booths_RequestPurchase not found")
            return
        end

        for i = 1, 3 do
            task.spawn(function()
                local ok, res = pcall(function()
                    return remote:InvokeServer(item.sellerId, {
                        [item.uid] = item.amount
                    })
                end)
                if not ok then
                    print("BUG_STEP3: Spam buy failed " .. tostring(res))
                end
            end)
        end
    end,

    Step4_HopServer = function(self)
        local req = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
        if not req then
            print("BUG_STEP4: No executor request function found")
            return
        end

        local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100", tostring(game.PlaceId))
        local ok, res = pcall(function()
            return req({ Url = url, Method = "GET" })
        end)

        if not ok or not res or not res.Body then
            print("BUG_STEP4: Failed to fetch server list")
            return
        end

        local jsonOk, data = pcall(function()
            return Core.Services.HttpService:JSONDecode(res.Body)
        end)

        if not jsonOk or not data or not data.data then
            print("BUG_STEP4: Failed to parse server list JSON")
            return
        end

        for _, s in ipairs(data.data) do
            if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing <= (s.maxPlayers - 2) then
                local hopOk, hopErr = pcall(function()
                    Core.Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, Core.Player)
                end)
                if not hopOk then
                    print("BUG_STEP4: Teleport error " .. tostring(hopErr))
                else
                    task.wait(3)
                end
            end
        end

        print("BUG_STEP4: All candidates tried, looping again")
    end,

    Start = function(self)
        if self.Enabled then return end
        self.Enabled = true
        self.Blacklist = {}

        self.Thread = task.spawn(function()
            while self.Enabled do
                if not self:Step1_CheckGems() then
                    break
                end

                local targetItem = self:Step2_ScanItem()
                if targetItem then
                    self:Step3_BuyItem(targetItem)
                    task.wait(0.05)
                else
                    self:Step4_HopServer()
                    task.wait(1)
                end
            end
        end)
    end,

    Stop = function(self)
        self.Enabled = false
        if self.Thread then
            task.cancel(self.Thread)
            self.Thread = nil
        end
        if self.ToggleRef and type(self.ToggleRef.Set) == "function" then
            self.ToggleRef:Set(false)
        end
        print("BUG_CORE: Features.BoothSniper stopped")
    end,
}

local Controller = {}

function Controller:Toggle(featureName, state, toggleRef)
    local f = Features[featureName]
    if not f then
        print("BUG_CONTROLLER: Feature not found " .. tostring(featureName))
        return
    end
    if toggleRef then
        f.ToggleRef = toggleRef
    end
    if state then
        f:Start()
    else
        f:Stop()
    end
end

_G.DYU_Controller = Controller
_G.DYU_Features = Features

return Controller
