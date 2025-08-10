Config = {}
Config.PlayerProps = {}

---------------------------------------------
-- settings
---------------------------------------------
Config.EnableVegModifier  = true -- if set true clears vegetation
Config.MaxMarkets         = 1
Config.MarketProp         = `mp005_s_posse_tent_trader07x`
Config.PackupTime         = 10000
Config.PlaceMinDistance   = 4
Config.RestrictTowns      = true -- restrict placement of markets in towns
Config.Img                = "rsg-inventory/html/images/"
Config.Money              = 'cash' -- 'cash' or 'bloodmoney'
Config.RepairCost         = 1
Config.EnableServerNotify = false

---------------------------------------------
-- cronjob settings
---------------------------------------------
Config.UpkeepCronJob = '0 * * * *' -- cronjob time every hour
Config.StockCronJob = '*/5 * * * *' -- cronjob time 5 mins

---------------------------------------------
-- blip settings
---------------------------------------------
Config.Blip = {
    blipName   = 'Market Stall',
    blipSprite = 'blip_shop_market_stall',
    blipScale  = 0.2,
    blipColour = 'BLIP_MODIFIER_MP_COLOR_6'
}

---------------------------------
-- deploy settings
---------------------------------
Config.PromptGroupName   = 'Place Market'
Config.PromptCancelName  = 'Cancel'
Config.PromptPlaceName   = 'Set'
Config.PromptRotateLeft  = 'Rotate Left'
Config.PromptRotateRight = 'Rotate Right'
Config.PlaceDistance     = 5.0
