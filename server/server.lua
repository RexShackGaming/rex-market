local RSGCore = exports['rsg-core']:GetCoreObject()
local PropsLoaded = false
lib.locale()

----------------------------
-- create unique id
----------------------------
local function CreateMarketId()
    local UniqueFound = false
    local MarketId = nil
    while not UniqueFound do
        MarketId = 'market_' .. math.random(11111111, 99999999)
        local query = "%" .. MarketId .. "%"
        local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM rex_market WHERE marketid LIKE ?", { query })
        if result == 0 then
            UniqueFound = true
        end
    end
    return MarketId
end

---------------------------------------------
-- use prop
---------------------------------------------
RSGCore.Functions.CreateUseableItem('marketstall', function(source)
    local src = source
    TriggerClientEvent('rex-market:client:createprop', src, Config.MarketProp, 'marketstall')
end)

---------------------------------------------
-- count props
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-market:server:countprop', function(source, cb, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM rex_market WHERE citizenid = ? AND item = ?", { citizenid, item })
    if result then
        cb(result)
    else
        cb(nil)
    end
end)

---------------------------------------------
-- cash callback
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-market:server:cashcallback', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local playercash = Player.PlayerData.money['cash']
    if playercash then
        cb(playercash)
    else
        cb(nil)
    end
end)

---------------------------------------------
-- get all trap data
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-market:server:getallmarketdata', function(source, cb, marketid)
    MySQL.query('SELECT * FROM rex_market WHERE marketid = ?', { marketid }, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

---------------------------------------------
-- check stock
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-market:server:checkstock', function(source, cb, marketid)
    MySQL.query('SELECT * FROM rex_market_stock WHERE marketid = ?', { marketid }, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

---------------------------------------------
-- get market data
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-market:server:getmarketstalldata', function(source, cb, marketid)
    MySQL.query('SELECT * FROM rex_market WHERE marketid = ?', { marketid }, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

---------------------------------------------
-- new prop
---------------------------------------------
RegisterServerEvent('rex-market:server:newProp') -- proptype, location, heading, hash
AddEventHandler('rex-market:server:newProp', function(propmodel, item, coords, heading)
    local src = source
    local marketid = CreateMarketId()
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local owner = firstname .. ' ' .. lastname

    local PropData =
    {
        id = marketid,
        item = item,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = heading,
        propmodel = propmodel,
        citizenid = citizenid,
        owner = owner,
        buildttime = os.time()
    }

    local PropCount = 0

    for _, v in pairs(Config.PlayerProps) do
        if v.citizenid == Player.PlayerData.citizenid then
            PropCount = PropCount + 1
        end
    end

    if PropCount >= Config.MaxMarkets then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lang_10'), type = 'inform', duration = 5000 })
    else
        table.insert(Config.PlayerProps, PropData)
        Player.Functions.RemoveItem(item, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', 1)
        TriggerEvent('rex-market:server:saveProp', PropData, marketid, citizenid, owner, item)
        TriggerEvent('rex-market:server:updateProps')
    end
end)

---------------------------------------------
-- save props
---------------------------------------------
RegisterServerEvent('rex-market:server:saveProp')
AddEventHandler('rex-market:server:saveProp', function(data, marketid, citizenid, owner, item)
    local datas = json.encode(data)

    MySQL.Async.execute('INSERT INTO rex_market (properties, marketid, citizenid, owner, item) VALUES (@properties, @marketid, @citizenid, @owner, @item)',
    {
        ['@properties'] = datas,
        ['@marketid'] = marketid,
        ['@citizenid'] = citizenid,
        ['@owner'] = owner,
        ['@item'] = item
    })
end)

---------------------------------------------
-- update props
---------------------------------------------
RegisterServerEvent('rex-market:server:updateProps')
AddEventHandler('rex-market:server:updateProps', function()
    local src = source
    TriggerClientEvent('rex-market:client:updatePropData', src, Config.PlayerProps)
end)

---------------------------------------------
-- update prop data
---------------------------------------------
CreateThread(function()
    while true do
        Wait(5000)
        if PropsLoaded then
            TriggerClientEvent('rex-market:client:updatePropData', -1, Config.PlayerProps)
        end
    end
end)

---------------------------------------------
-- get props
---------------------------------------------
CreateThread(function()
    TriggerEvent('rex-market:server:getProps')
    PropsLoaded = true
end)

---------------------------------------------
-- get props
---------------------------------------------
RegisterServerEvent('rex-market:server:getProps')
AddEventHandler('rex-market:server:getProps', function()
    local result = MySQL.query.await('SELECT * FROM rex_market')

    if not result[1] then return end

    for i = 1, #result do
        local propData = json.decode(result[i].properties)
        print('loading '..propData.item..' owned by: '..propData.owner)
        table.insert(Config.PlayerProps, propData)
    end
end)

---------------------------------------------
-- distory prop
---------------------------------------------
RegisterServerEvent('rex-market:server:destroyProp')
AddEventHandler('rex-market:server:destroyProp', function(marketid, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    for k, v in pairs(Config.PlayerProps) do
        if v.id == marketid then
            table.remove(Config.PlayerProps, k)
        end
    end

    TriggerClientEvent('rex-market:client:removePropObject', src, marketid)
    TriggerEvent('rex-market:server:PropRemoved', marketid)
    TriggerEvent('rex-market:server:updateProps')
    Player.Functions.AddItem(item, 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', 1)
end)

---------------------------------------------
-- remove props
---------------------------------------------
RegisterServerEvent('rex-market:server:PropRemoved')
AddEventHandler('rex-market:server:PropRemoved', function(marketid)
    local result = MySQL.query.await('SELECT * FROM rex_market')

    if not result then return end

    for i = 1, #result do
        local propData = json.decode(result[i].properties)

        if propData.id == marketid then
            for k, v in pairs(Config.PlayerProps) do
                if v.id == marketid then
                    table.remove(Config.PlayerProps, k)
                end
            end
            MySQL.Async.execute('DELETE FROM rex_market WHERE marketid = ?', { marketid })
            MySQL.Async.execute('DELETE FROM rex_market_stock WHERE marketid = ?', { marketid })
        end
    end
end)

---------------------------------------------
-- buy item amount / add to market money
---------------------------------------------
RegisterNetEvent('rex-market:server:buyitemamount', function(amount, item, newstock, price, label, marketid)

    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local money = Player.PlayerData.money[Config.Money]

    local totalcost = (price * amount)

    if money >= totalcost then
        MySQL.update('UPDATE rex_market_stock SET stock = ? WHERE marketid = ? AND item = ?', {newstock, marketid, item})

        Player.Functions.RemoveMoney(Config.Money, totalcost)
        Player.Functions.AddItem(item, amount)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', amount)

        MySQL.query('SELECT * FROM rex_market WHERE marketid = ?', { marketid }, function(data2)
            local moneyupdate = (data2[1].money + totalcost)
            MySQL.update('UPDATE rex_market SET money = ? WHERE marketid = ?',{moneyupdate, marketid})
        end)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lang_3')..Config.Money, type = 'error', duration = 7000 })
    end

end)

---------------------------------------------
-- update stock or add new stock
---------------------------------------------
RegisterNetEvent('rex-market:server:newstockitem', function(marketid, item, amount, price)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local itemcount = MySQL.prepare.await("SELECT COUNT(*) as count FROM rex_market_stock WHERE marketid = ? AND item = ?", { marketid, item })
    if itemcount == 0 then
        MySQL.Async.execute('INSERT INTO rex_market_stock (marketid, item, stock, price) VALUES (@marketid, @item, @stock, @price)',
        {
            ['@marketid'] = marketid,
            ['@item'] = item,
            ['@stock'] = amount,
            ['@price'] = price
        })
        Player.Functions.RemoveItem(item, amount)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
    else
        MySQL.query('SELECT * FROM rex_market_stock WHERE marketid = ? AND item = ?', { marketid, item }, function(data)
            local stockupdate = (amount + data[1].stock)
            MySQL.update('UPDATE rex_market_stock SET stock = ? WHERE marketid = ? AND item = ?',{stockupdate, marketid, item})
            MySQL.update('UPDATE rex_market_stock SET price = ? WHERE marketid = ? AND item = ?',{price, marketid, item})
            Player.Functions.RemoveItem(item, amount)
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
        end)
    end
end)

---------------------------------------------
-- remove stock item
---------------------------------------------
RegisterNetEvent('rex-market:server:removestockitem', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    MySQL.query('SELECT * FROM rex_market_stock WHERE marketid = ? AND item = ?', { data.marketid, data.item }, function(result)
        Player.Functions.AddItem(result[1].item, result[1].stock)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[result[1].item], 'add', result[1].stock)
        MySQL.Async.execute('DELETE FROM rex_market_stock WHERE id = ?', { result[1].id })
    end)
end)

---------------------------------------------
-- get market money
---------------------------------------------
RSGCore.Functions.CreateCallback('rex-market:server:getmoney', function(source, cb, marketid)
    MySQL.query('SELECT * FROM rex_market WHERE marketid = ?', { marketid }, function(result)
        if result[1] then
            cb(result[1])
        else
            cb(nil)
        end
    end)
end)

---------------------------------------------
-- withdraw market money
---------------------------------------------
RegisterNetEvent('rex-market:server:withdrawfunds', function(amount, marketid)

    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    MySQL.query('SELECT * FROM rex_market WHERE marketid = ?',{marketid} , function(result)
        if result[1] ~= nil then
            if result[1].money >= amount then
                local updatemoney = (result[1].money - amount)
                MySQL.update('UPDATE rex_market SET money = ? WHERE marketid = ?', { updatemoney, marketid })
                Player.Functions.AddMoney(Config.Money, amount)
            end
        end
    end)
end)

---------------------------------------------
-- repair market stall
---------------------------------------------
RegisterNetEvent('rex-market:server:repairmarketstall', function(marketid, repaircost)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    Player.Functions.RemoveMoney(Config.Money, repaircost)
    MySQL.update('UPDATE rex_market SET quality = ? WHERE marketid = ?', {100, marketid})
end)

---------------------------------------------
-- market upkeep system
---------------------------------------------
lib.cron.new(Config.UpkeepCronJob, function ()

    local result = MySQL.query.await('SELECT * FROM rex_market')

    if not result then goto continue end

    for i = 1, #result do

        local marketid = result[i].marketid
        local quality = result[i].quality
        local owner = result[i].owner

        -- check market maintanance
        if quality > 0 then
            MySQL.update('UPDATE rex_market SET quality = ? WHERE marketid = ?', {quality-1, marketid})
        else
            TriggerEvent('rex-market:server:PropRemoved', marketid)
            TriggerClientEvent('rex-market:client:removePropObject', -1, marketid)
            TriggerEvent('rex-market:server:updateProps')
            TriggerEvent('rsg-log:server:CreateLog', 'rexmarket', locale('sv_lang_4'), 'red', locale('sv_lang_5')..marketid..locale('sv_lang_6')..owner..locale('sv_lang_7'))
        end

    end

    ::continue::

    if Config.EnableServerNotify then
        print(locale('sv_lang_8'))
    end

end)

---------------------------------------------
-- market stock system
---------------------------------------------
lib.cron.new(Config.StockCronJob, function ()

    local result = MySQL.query.await('SELECT * FROM rex_market_stock')

    if not result then goto continue end
    
    for i = 1, #result do

        local marketid = result[i].marketid
        local item = result[i].item
        local stock = result[i].stock

        -- check stock at zero and remove
        if stock == 0 then
            MySQL.Async.execute('DELETE FROM rex_market_stock WHERE marketid = ? AND item = ?', { marketid, item })
        end

    end

    ::continue::

    if Config.EnableServerNotify then
        print(locale('sv_lang_9'))
    end

end)
