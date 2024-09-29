local scom = require "factions.spawn.lib.common"

local sllama      = scom.variants{
   { w=1,    s=ship.get("Llama") },
   { w=0.05, s=ship.get("Llama Voyager") },
}
local skoala   = scom.variants{
   { w=1,    s=ship.get("Koala") },
   { w=0.05, s=ship.get("Koala Armoured") },
}
local smule    = scom.variants{
   { w=1,   s=ship.get("Mule") },
   { w=0.2, s=ship.get("Mule Hardhat") },
}
local srhino   = ship.get("Rhino")

-- @brief Spawns a small group of miners
local function spawn_lone_miner ()
   local pilots = {}
   local r = rnd.rnd()
   if r < 0.4 then
      scom.addPilot( pilots, sllama, {name=_("Miner Llama"), ai="miner"} )
   elseif r < 0.7 then
      scom.addPilot( pilots, skoala, {name=_("Miner Koala"), ai="miner"} )
   elseif r < 0.9 then
      scom.addPilot( pilots, smule,  {name=_("Miner Mule"), ai="miner"} )
   else
      scom.addPilot( pilots, srhino, {name=_("Miner Rhino"), ai="miner"} )
   end

   return pilots
end

local fminer = faction.get("Miner")
-- @brief Creation hook.
function create ( max )
   local weights = {}

    -- Create weights for spawn table
   weights[ spawn_lone_miner  ] = 100

   return scom.init( fminer, weights, max )
end
