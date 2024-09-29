local scom = require "factions.spawn.lib.common"

local sschroedinger= ship.get("Schroedinger")
local sllama      = ship.get("Llama")
local sgawain     = ship.get("Gawain")
local skoala      = ship.get("Koala")
local squicksilver = scom.variants{
   { w=1,    s=ship.get("Quicksilver") },
   { w=0.05, s=ship.get("Quicksilver Mercury") },
}
local smule       = scom.variants{
   { w=1,    s=ship.get("Mule")},
   { w=0.05, s=ship.get("Mule Hardhat")},
}
local shyena      = ship.get("Hyena")
local sshark      = ship.get("Shark")
local sancestor   = ship.get("Ancestor")
local stristan    = ship.get("Tristan")
local slancelot   = ship.get("Lancelot")
local svendetta   = ship.get("Vendetta")
local sphalanx    = ship.get("Phalanx")
local sadmonisher = ship.get("Admonisher")
local sstarbridge = scom.variants{
   { w=1,    ship.get("Starbridge") },
   { w=0.05, ship.get("Starbridge Sigma") },
}
local svigilance  = ship.get("Vigilance")
local sbedivere   = ship.get("Bedivere")
local spacifier   = ship.get("Pacifier")
local skestrel    = ship.get("Kestrel")
local shawking    = ship.get("Hawking")
local sgoddard    = ship.get("Goddard")

local frontier

-- Make pilot more visible
local function _advert( p )
   -- They want to be seen
   p:intrinsicSet( "ew_hide", 300 )
   p:intrinsicSet( "ew_signature", 300 )
end

local function spawn_advert ()
   local pilots = {}
   local civships = {
      sschroedinger,
      sllama,
      sgawain,
      shyena,
   }
   local shp = civships[ rnd.rnd(1, #civships) ]
   scom.addPilot( pilots, shp, {ai="advertiser", postprocess=_advert} )
   return pilots
end


-- @brief Spawns a small patrol fleet.
local function spawn_solitary_civilians ()
   return scom.doTable( {}, {
      { w=0.25, sllama },
      { w=0.45, shyena },
      { w=0.6,  squicksilver },
      { w=0.75, skoala },
      { w=0.85, smule },
      { w=0.9,  sgawain },
      { sschroedinger },
   } )
end

local function spawn_bounty_hunter( shiplist )
   local pilots = {}
   local params = {name=_("Bounty Hunter"), ai="mercenary"}
   local shp    = shiplist[ rnd.rnd(1,#shiplist) ]
   scom.addPilot( pilots, shp, params )
   return pilots
end

local function spawn_bounty_hunter_sml ()
   local ships = {
         shyena,
         sshark,
         slancelot,
         svendetta,
         sancestor,
      }
   if frontier then
      table.insert( ships, stristan )
   end
   return spawn_bounty_hunter( ships )
end
local function spawn_bounty_hunter_med ()
   local ships = {
      sadmonisher,
      sphalanx,
      sstarbridge,
      svigilance,
      spacifier,
   }
   if frontier then
      table.insert( ships, sbedivere )
   end
   return spawn_bounty_hunter(ships)
end
local function spawn_bounty_hunter_lrg ()
   return spawn_bounty_hunter{
      skestrel,
      shawking,
      sgoddard,
   }
end

local findependent = faction.get("Independent")
return function ( t, max )
   -- Hostiles (namely pirates atm)
   local host = 0
   local total = 0
   local csys = system.cur()
   for f,v in pairs(csys:presences()) do
      if findependent:areEnemies(f) then
         host = host + v
      end
      total = total + v
   end
   local hostnorm = host / total

   frontier = csys:presences()["Frontier"]

   -- Solitary civilians
   t.solitary = { f=spawn_solitary_civilians, w=max }

   -- Lone bounty hunters
   t.bounty_hunter_sml = { f=spawn_bounty_hunter_sml, w=math.min( 0.3*max, 50 ) }
   t.bounty_hunter_med = { f=spawn_bounty_hunter_med, w=math.min( 0.2*max, math.max(1, -150 + host ) ) }
   t.bounty_hunter_lrg = { f=spawn_bounty_hunter_lrg, w=math.min( 0.1*max, math.max(1, -300 + host ) ) }

   -- The more hostiles, the less advertisers
   -- The modifier should be 0.15 at 10% hostiles, 0.001 at 100% hostiles, and
   -- 1 at 0% hostiles
   t.advert = { f=spawn_advert, w=0.1*max*math.exp(-hostnorm*5) }
end, 10
