local RSGCore = exports['rsg-core']:GetCoreObject()
local SpawnedProps = {}
local isBusy = false
local canPlace = false
local fx_group = "scr_dm_ftb"
local fx_name = "scr_mp_chest_spawn_smoke"
local fx_scale = 1.0
lib.locale()

---------------------------------------------
-- check to see if prop can be place here
---------------------------------------------
local function CanPlacePropHere(pos)
    local canPlace = true
    if Config.RestrictTowns then
        local ZoneTypeId = 1
        local x,y,z =  table.unpack(GetEntityCoords(PlayerPedId()))
        local town = Citizen.InvokeNative(0x43AD8FC02B429D33, x,y,z, ZoneTypeId)
        if town ~= false then
            canPlace = false
        end
    end
    for i = 1, #Config.PlayerProps do
        local checkprops = vector3(Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z)
        local dist = #(pos - checkprops)
        if dist < Config.PlaceMinDistance then
            canPlace = false
        end
    end
    return canPlace
end

---------------------------------------------
-- spawn props
---------------------------------------------
Citizen.CreateThread(function()
    while true do
        Wait(150)

        local pos = GetEntityCoords(cache.ped)
        local InRange = false

        for i = 1, #Config.PlayerProps do
            local prop = vector3(Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z)
            local dist = #(pos - prop)
            if dist >= 50.0 then goto continue end

            local hasSpawned = false
            InRange = true

            for z = 1, #SpawnedProps do
                local p = SpawnedProps[z]

                if p.id == Config.PlayerProps[i].id then
                    hasSpawned = true
                end
            end

            if hasSpawned then goto continue end

            local modelHash = Config.PlayerProps[i].propmodel
            local data = {}
            
            if not HasModelLoaded(modelHash) then
                RequestModel(modelHash)
                while not HasModelLoaded(modelHash) do
                    Wait(1)
                end
            end

            data.obj = CreateObject(modelHash, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z -1.2, false, false, false)
            SetEntityHeading(data.obj, Config.PlayerProps[i].h)
            SetEntityAsMissionEntity(data.obj, true)
            PlaceObjectOnGroundProperly(data.obj)
            Wait(1000)
            FreezeEntityPosition(data.obj, true)
            SetModelAsNoLongerNeeded(data.obj)
            
            -- set data objects
            data.id = Config.PlayerProps[i].id
            data.citizenid = Config.PlayerProps[i].citizenid
            data.owner = Config.PlayerProps[i].owner

            -- veg modifiy
            local veg_modifier_sphere = 0
            
            if veg_modifier_sphere == nil or veg_modifier_sphere == 0 then
                local veg_radius = 5.0
                local veg_Flags =  1 + 2 + 4 + 8 + 16 + 32 + 64 + 128 + 256
                local veg_ModType = 1
                veg_modifier_sphere = Citizen.InvokeNative(0xFA50F79257745E74, Config.PlayerProps[i].x, Config.PlayerProps[i].y, Config.PlayerProps[i].z, veg_radius, veg_ModType, veg_Flags, 0)
            else
                Citizen.InvokeNative(0x9CF1836C03FB67A2, Citizen.PointerValueIntInitialized(veg_modifier_sphere), 0)
                veg_modifier_sphere = 0
            end

            if Config.PlayerProps[i].item == 'marketstall' then
                local blip = BlipAddForEntity(1664425300, data.obj)
                SetBlipSprite(blip, joaat(Config.Blip.blipSprite), true)
                SetBlipName(blip, Config.PlayerProps[i].owner..locale('cl_lang_49'))
                SetBlipScale(blip, Config.Blip.blipScale)
                BlipAddModifier(blip, joaat(Config.Blip.blipColour))
            end

            SpawnedProps[#SpawnedProps + 1] = data
            hasSpawned = false

            -- create target for the entity
            exports.ox_target:addLocalEntity(data.obj, {
                {
                    name = 'rex_market',
                    icon = 'far fa-eye',
                    label = data.owner..locale('cl_lang_45'),
                    onSelect = function()
                        TriggerEvent('rex-market:client:openmarket', data.id, data.citizenid, data.obj)
                    end,
                    distance = 5.0
                }
            })
            -- end of target

            ::continue::
        end

        if not InRange then
            Wait(5000)
        end
    end
end)

---------------------------------------------
-- get correct menu
---------------------------------------------
RegisterNetEvent('rex-market:client:openmarket', function(marketid, owner_citizenid, entity)
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local player_citizenid = PlayerData.citizenid
    if player_citizenid == owner_citizenid then
        TriggerEvent('rex-market:client:openownermenu', marketid, entity)
    else
        TriggerEvent('rex-market:client:customerviewshopitems', marketid)
    end
end)

---------------------------------------------
-- owner menu
---------------------------------------------
RegisterNetEvent('rex-market:client:openownermenu', function(marketid, entity)
    lib.registerContext({
        id = 'market_owner_menu',
        title = 'Market Owner Menu',
        options = {
            {
                title = locale('cl_lang_5'),
                icon = 'fa-solid fa-store',
                event = 'rex-market:client:ownerviewshopitems',
                args = { 
                    marketid = marketid,
                },
                arrow = true
            },
            {
                title = locale('cl_lang_6'),
                icon = 'fa-solid fa-circle-plus',
                iconColor = 'green',
                event = 'rex-market:client:newstockitem',
                args = {
                    marketid = marketid
                },
                arrow = true
            },
            {
                title = locale('cl_lang_7'),
                icon = 'fa-solid fa-circle-minus',
                iconColor = 'red',
                event = 'rex-market:client:removestockitem',
                args = {
                    marketid = marketid
                },
                arrow = true
            },
            {
                title = locale('cl_lang_8'),
                icon = 'fa-solid fa-sack-dollar',
                event = 'rex-market:client:checkmoney',
                args = {
                    marketid = marketid
                },
                arrow = true
            },
            {
                title = locale('cl_lang_9'),
                icon = 'fa-solid fa-circle-info',
                event = 'rex-market:client:maintenance',
                args = {
                    marketid = marketid
                },
                arrow = true
            },
            {
                title = locale('cl_lang_10'),
                icon = 'fa-solid fa-box',
                event = 'rex-market:client:packupmarket',
                args = {
                    marketid = marketid,
                    entity = entity
                },
                arrow = true
            }
        }
    })
    lib.showContext('market_owner_menu')
end)

-------------------------------------------------------------------------------------------
-- owner view shop items
-------------------------------------------------------------------------------------------
RegisterNetEvent('rex-market:client:ownerviewshopitems', function(data)

    RSGCore.Functions.TriggerCallback('rex-market:server:checkstock', function(result)
        if result == nil then
            lib.registerContext({
                id = 'market_no_inventory',
                title = locale('cl_lang_13'),
                menu = 'market_owner_menu',
                options = {
                    {
                        title = locale('cl_lang_14'),
                        icon = 'fa-solid fa-box',
                        disabled = true,
                        arrow = false
                    }
                }
            })
            lib.showContext('market_no_inventory')
        else
            local options = {}
            for k,v in ipairs(result) do
                options[#options + 1] = {
                    title = RSGCore.Shared.Items[result[k].item].label..' ('..string.format("$%.2f", result[k].price)..')',
                    description = locale('cl_lang_15')..result[k].stock,
                    icon = 'fa-solid fa-box',
                    event = 'rex-market:client:buyshopitem',
                    icon = "nui://" .. Config.Img .. RSGCore.Shared.Items[tostring(result[k].item)].image,
                    image = "nui://" .. Config.Img .. RSGCore.Shared.Items[tostring(result[k].item)].image,
                    args = {
                        item = result[k].item,
                        stock = result[k].stock,
                        price = result[k].price,
                        label = RSGCore.Shared.Items[result[k].item].label,
                        marketid = result[k].marketid
                    },
                    arrow = true,
                }
            end
            lib.registerContext({
                id = 'market_inv_menu',
                title = locale('cl_lang_16'),
                menu = 'market_owner_menu',
                position = 'top-right',
                options = options
            })
            lib.showContext('market_inv_menu')
        end
    end, data.marketid)

end)

-------------------------------------------------------------------------------------------
-- customer view shop items
-------------------------------------------------------------------------------------------
RegisterNetEvent('rex-market:client:customerviewshopitems', function(marketid)

    RSGCore.Functions.TriggerCallback('rex-market:server:checkstock', function(result)
        if result == nil then
            lib.registerContext({
                id = 'market_no_inventory',
                title = locale('cl_lang_13'),
                options = {
                    {
                        title = locale('cl_lang_14'),
                        icon = 'fa-solid fa-box',
                        disabled = true,
                        arrow = false
                    }
                }
            })
            lib.showContext('market_no_inventory')
        else
            local options = {}
            for k,v in ipairs(result) do
                options[#options + 1] = {
                    title = RSGCore.Shared.Items[result[k].item].label..' ('..string.format("$%.2f", result[k].price)..')',
                    description = locale('cl_lang_15')..result[k].stock,
                    icon = 'fa-solid fa-box',
                    event = 'rex-market:client:buyshopitem',
                    icon = "nui://" .. Config.Img .. RSGCore.Shared.Items[tostring(result[k].item)].image,
                    image = "nui://" .. Config.Img .. RSGCore.Shared.Items[tostring(result[k].item)].image,
                    args = {
                        item = result[k].item,
                        stock = result[k].stock,
                        price = result[k].price,
                        label = RSGCore.Shared.Items[result[k].item].label,
                        marketid = result[k].marketid
                    },
                    arrow = true,
                }
            end
            lib.registerContext({
                id = 'market_inv_menu',
                title = locale('cl_lang_16'),
                position = 'top-right',
                options = options
            })
            lib.showContext('market_inv_menu')
        end
    end, marketid)

end)

-------------------------------------------------------------------
-- sort table function
-------------------------------------------------------------------
local function compareNames(a, b)
    return a.value < b.value
end

-------------------------------------------------------------------
-- add / update stock item
-------------------------------------------------------------------
RegisterNetEvent('rex-market:client:newstockitem', function(data)

    local items = {}

    for k,v in pairs(RSGCore.Functions.GetPlayerData().items) do
        local content = { value = v.name, label = v.label..' ('..v.amount..')' }
        items[#items + 1] = content
    end

    table.sort(items, compareNames)

    local item = lib.inputDialog(locale('cl_lang_20'), {
        { 
            type = 'select',
            options = items,
            label = locale('cl_lang_21'),
            required = true
        },
        { 
            type = 'input',
            label = locale('cl_lang_22'),
            placeholder = '0',
            icon = 'fa-solid fa-hashtag',
            required = true
        },
        { 
            type = 'input',
            label = locale('cl_lang_23'),
            placeholder = '0.00',
            icon = 'fa-solid fa-dollar-sign',
            required = true
        },
    })
    
    if not item then 
        return 
    end
    
    local hasItem = RSGCore.Functions.HasItem(item[1], tonumber(item[2]))
    
    if hasItem then
        TriggerServerEvent('rex-market:server:newstockitem', data.marketid, item[1], tonumber(item[2]), tonumber(item[3]))
    else
        lib.notify({ title = locale('cl_lang_24'), type = 'error', duration = 7000 })
    end

end)

-------------------------------------------------------------------------------------------
-- remove stock item
-------------------------------------------------------------------------------------------
RegisterNetEvent('rex-market:client:removestockitem', function(data)

    RSGCore.Functions.TriggerCallback('rex-market:server:checkstock', function(result)
        if result == nil then
            lib.registerContext({
                id = 'market_no_stock',
                title = locale('cl_lang_25'),
                menu = 'market_owner_menu',
                options = {
                    {
                        title = locale('cl_lang_26'),
                        icon = 'fa-solid fa-box',
                        disabled = true,
                        arrow = false
                    }
                }
            })
            lib.showContext('market_no_stock')
        else
            local options = {}
            for k,v in ipairs(result) do
                options[#options + 1] = {
                    title = RSGCore.Shared.Items[result[k].item].label,
                    description = locale('cl_lang_27')..result[k].stock,
                    icon = 'fa-solid fa-box',
                    serverEvent = 'rex-market:server:removestockitem',
                    icon = "nui://" .. Config.Img .. RSGCore.Shared.Items[tostring(result[k].item)].image,
                    image = "nui://" .. Config.Img .. RSGCore.Shared.Items[tostring(result[k].item)].image,
                    args = {
                        item = result[k].item,
                        marketid = result[k].marketid
                    },
                    arrow = true,
                }
            end
            lib.registerContext({
                id = 'market_stock_menu',
                title = locale('cl_lang_28'),
                menu = 'market_owner_menu',
                position = 'top-right',
                options = options
            })
            lib.showContext('market_stock_menu')
        end
    end, data.marketid)

end)

---------------------------------------------
-- buy item amount
---------------------------------------------
RegisterNetEvent('rex-market:client:buyshopitem', function(data)

    local input = lib.inputDialog(locale('cl_lang_17')..data.label, {
        { 
            label = locale('cl_lang_18'),
            type = 'input',
            required = true,
            icon = 'fa-solid fa-hashtag'
        },
    })
    
    if not input then
        return
    end
    
    local amount = tonumber(input[1])
    
    if data.stock >= amount then
        local newstock = (data.stock - amount)
        TriggerServerEvent('rex-market:server:buyitemamount', amount, data.item, newstock, data.price, data.label, data.marketid)
    else
        lib.notify({ title = locale('cl_lang_19'), type = 'error', duration = 7000 })
    end

end)

-------------------------------------------------------------------------------------------
-- withdraw market money 
-------------------------------------------------------------------------------------------
RegisterNetEvent('rex-market:client:checkmoney', function(data)
    RSGCore.Functions.TriggerCallback('rex-market:server:getmoney', function(data)
        local input = lib.inputDialog(locale('cl_lang_29'), {
            { 
                type = 'input',
                label = locale('cl_lang_30')..data.money,
                icon = 'fa-solid fa-dollar-sign',
                required = true
            },
        })
        
        if not input then
            return
        end

        local withdraw = tonumber(input[1])

        if withdraw <= data.money then
            TriggerServerEvent('rex-market:server:withdrawfunds', withdraw, data.marketid)
        else
            lib.notify({ title = locale('cl_lang_31'), type = 'error', duration = 7000 })
        end

    end, data.marketid)
end)

---------------------------------------------
-- market maintenance
---------------------------------------------
RegisterNetEvent('rex-market:client:maintenance', function(data)
    RSGCore.Functions.TriggerCallback('rex-market:server:getmarketstalldata', function(result)

        local quality = result[1].quality
        local repaircost = (100 - result[1].quality) * Config.RepairCost
        local colorScheme = nil
        
        if quality > 50 then 
            colorScheme = 'green'
        end
        
        if quality <= 50 and quality > 10 then
            colorScheme = 'yellow'
        end
        
        if quality <= 10 then
            colorScheme = 'red'
        end
    
        lib.registerContext({
            id = 'market_maintenance',
            title = locale('cl_lang_32'),
            menu = 'market_owner_menu',
            options = {
                {
                    title = locale('cl_lang_33')..quality..locale('cl_lang_34'),
                    progress = quality,
                    colorScheme = colorScheme,
                },
                {
                    title = locale('cl_lang_35')..repaircost..locale('cl_lang_36'),
                    icon = 'fa-solid fa-screwdriver-wrench',
                    event = 'rex-market:client:repairmarketstall',
                    args = { 
                        marketid = data.marketid,
                        repaircost = repaircost
                    },
                    arrow = true
                }
            }
        })
        lib.showContext('market_maintenance')

    end, data.marketid)

end)

---------------------------------------------
-- repair market stall
---------------------------------------------
RegisterNetEvent('rex-market:client:repairmarketstall', function(data)

    -- confirm repair action
    local input = lib.inputDialog(locale('cl_lang_37'), {
        {
            label = locale('cl_lang_38'),
            description = locale('cl_lang_43')..data.repaircost,
            type = 'select',
            options = {
                { value = 'yes', label = locale('cl_lang_40') },
                { value = 'no',  label = locale('cl_lang_41') }
            },
            required = true
        },
    })
        
    if not input then
        return
    end
    
    if input[1] == 'no' then
        return
    end

    -- progress bar
    LocalPlayer.state:set("inv_busy", true, true)
    lib.progressBar({
        duration = (1000 * data.repaircost),
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disableControl = true,
        disable = {
            move = true,
            mouse = true,
        },
        label = locale('cl_lang_44'),
    })
    LocalPlayer.state:set("inv_busy", false, true)

    TriggerServerEvent('rex-market:server:repairmarketstall', data.marketid, data.repaircost)
end)

---------------------------------------------
-- pickup market stall
---------------------------------------------
RegisterNetEvent('rex-market:client:packupmarket', function(data)

    RSGCore.Functions.TriggerCallback('rex-market:server:getallmarketdata', function(result)
    
        -- confirm action
        local input = lib.inputDialog(locale('cl_lang_37'), {
            {
                label = locale('cl_lang_38'),
                description = locale('cl_lang_39'),
                type = 'select',
                options = {
                    { value = 'yes', label = locale('cl_lang_40') },
                    { value = 'no',  label = locale('cl_lang_41') }
                },
                required = true
            },
        })
            
        if not input then
            return
        end
        
        if input[1] == 'no' then
            return
        end

        local quality = result[1].quality

        if quality ~= 100 then
            lib.notify({ title = locale('cl_lang_46'), type = 'info', duration = 7000 })
            return
        end

        LocalPlayer.state:set("inv_busy", true, true) -- lock inventory
        lib.progressBar({
            duration = Config.PackupTime,
            position = 'bottom',
            useWhileDead = false,
            canCancel = false,
            disableControl = true,
            disable = {
                move = true,
                mouse = true,
            },
            label = locale('cl_lang_42'),
        })
        LocalPlayer.state:set("inv_busy", false, true) -- unlock inventory

        local propcoords = GetEntityCoords(data.entity)
        local fxcoords = vector3(propcoords.x, propcoords.y, propcoords.z)
        UseParticleFxAsset(fx_group)
        smoke = StartParticleFxNonLoopedAtCoord(fx_name, fxcoords, 0.0, 0.0, 0.0, fx_scale, false, false, false, true)

        TriggerServerEvent('rex-market:server:destroyProp', data.marketid, 'marketstall')

    end, data.marketid)

end)

---------------------------------------------
-- place prop
---------------------------------------------
RegisterNetEvent('rex-market:client:placenewprop')
AddEventHandler('rex-market:client:placenewprop', function(propmodel, item, coords, heading)

    RSGCore.Functions.TriggerCallback('rex-market:server:countprop', function(result)

        local playercoords = GetEntityCoords(cache.ped)
        if #(playercoords - coords) > Config.PlaceDistance then
            lib.notify({ title = locale('cl_lang_47'), description = locale('cl_lang_48'), type = 'error', duration = 5000 })
            return
        end

        if item == 'marketstall' and result >= Config.MaxMarkets then
            lib.notify({ title = locale('cl_lang_1'), type = 'error', duration = 7000 })
            return
        end
        
        if not CanPlacePropHere(playercoords) then
            lib.notify({ title = locale('cl_lang_2'), type = 'error', duration = 7000 })
            return
        end

        if not isBusy then

            isBusy = true
            LocalPlayer.state:set("inv_busy", true, true) -- lock inventory
            local anim1 = `WORLD_HUMAN_CROUCH_INSPECT`
            FreezeEntityPosition(cache.ped, true)
            TaskStartScenarioInPlace(cache.ped, anim1, 0, true)
            Wait(10000)
            ClearPedTasks(cache.ped)
            FreezeEntityPosition(cache.ped, false)
            TriggerServerEvent('rex-market:server:newProp', propmodel, item, coords, heading)
            LocalPlayer.state:set("inv_busy", false, true) -- unlock inventory
            isBusy = false

        else
            lib.notify({ title = locale('cl_lang_3'), type = 'error', duration = 7000 })
        end

    end, item)

end)

---------------------------------------------
-- update props
---------------------------------------------
RegisterNetEvent('rex-market:client:updatePropData')
AddEventHandler('rex-market:client:updatePropData', function(data)
    Config.PlayerProps = data
end)

---------------------------------------------
-- remove prop object
---------------------------------------------
RegisterNetEvent('rex-market:client:removePropObject')
AddEventHandler('rex-market:client:removePropObject', function(prop)
    for i = 1, #SpawnedProps do
        local o = SpawnedProps[i]

        if o.id == prop then
            SetEntityAsMissionEntity(o.obj, false)
            FreezeEntityPosition(o.obj, false)
            DeleteObject(o.obj)
        end
    end
end)

---------------------------------------------
-- clean up
---------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #SpawnedProps do
        local props = SpawnedProps[i].obj

        SetEntityAsMissionEntity(props, false)
        FreezeEntityPosition(props, false)
        DeleteObject(props)
    end
end)
