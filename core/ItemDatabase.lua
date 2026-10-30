-- OmniUI Item Database & Description Resolver
-- Provides canonical Pokémon item descriptions, categories, dynamic TM/HM move resolution,
-- and extensible provider hooks for mods and cross-gen engines.

local MoveDatabase = require("mods.omni_ui.core.MoveDatabase")

local ItemDatabase = {}

local registeredItems = {}
local itemDescriptionProviders = {}

--- Registers a custom item definition or override from a mod.
--- @param itemId string Unique item identifier (e.g., "MEGA_BRACELET" or "EXP_CHARM")
--- @param itemDef table { name=string, description=string, category=string, machine=table|nil }
function ItemDatabase.registerItem(itemId, itemDef)
  if not itemId or not itemDef then return false end
  registeredItems[tostring(itemId):upper()] = itemDef
  return true
end

--- Batch registers custom item definitions.
--- @param itemsTable table Table of itemId -> itemDef
function ItemDatabase.registerItems(itemsTable)
  if type(itemsTable) ~= "table" then return false end
  for k, v in pairs(itemsTable) do
    ItemDatabase.registerItem(k, v)
  end
  return true
end

--- Registers a dynamic item description provider hook.
--- @param providerFn function(itemId, itemDef, game): string|nil
function ItemDatabase.registerDescriptionProvider(providerFn)
  if type(providerFn) == "function" then
    itemDescriptionProviders[#itemDescriptionProviders + 1] = providerFn
    return true
  end
  return false
end

local CANONICAL_DESCRIPTIONS = {
  -- Key Items
  TOWN_MAP = "A detailed travel map of the region that can be viewed anytime to check your current location.",
  BICYCLE = "A folding bike that enables rapid travel at double walking speed.",
  OLD_ROD = "Use by any body of water to fish for wild water Pokémon like Magikarp.",
  GOOD_ROD = "A decent fishing rod capable of hooking a variety of aquatic Pokémon.",
  SUPER_ROD = "An awesome fishing rod that hooks the strongest wild Pokémon in the depths.",
  SILPH_SCOPE = "A high-tech scope by Silph Co. that reveals the true identity of unidentifiable ghosts in Pokémon Tower.",
  POKE_FLUTE = "A sweet-sounding flute that awakens any sleeping Pokémon immediately.",
  CARD_KEY = "An electronic keycard that unlocks security doors inside the Silph Co. headquarters.",
  LIFT_KEY = "An elevator key for accessing restricted floors in the Team Rocket Hideout.",
  SECRET_KEY = "The key that unlocks the front door of the Cinnabar Island Pokémon Gym.",
  S_S_TICKET = "A luxury cruise ticket required to board the S.S. Anne in Vermilion City harbor.",
  OAKS_PARCEL = "A parcel containing custom Poké Balls to deliver to Professor Oak in Pallet Town.",
  GOLD_TEETH = "A set of false gold teeth dropped by the Safari Zone Warden in Fuchsia City.",
  COIN_CASE = "A sturdy coin case that holds up to 9,999 Game Corner casino coins.",
  HELIX_FOSSIL = "A fossil of an ancient, spiral-shelled sea Pokémon. Can be regenerated into Omanyte.",
  DOME_FOSSIL = "A fossil of an ancient, dome-shelled sea Pokémon. Can be regenerated into Kabuto.",
  OLD_AMBER = "A piece of ancient amber containing prehistoric DNA. Can be regenerated into Aerodactyl.",
  EXP_ALL = "A device that divides battle experience points among all party Pokémon.",
  ITEMFINDER = "A sensor that beeps and lights up when unseeable hidden items are nearby.",
  BIKE_VOUCHER = "A voucher exchangeable for a brand-new bicycle at the Cerulean Bike Shop.",

  -- Poké Balls
  POKE_BALL = "A standard capsule device used for catching wild Pokémon.",
  GREAT_BALL = "A high-performance Ball with a 1.5x higher catch rate than a standard Poké Ball.",
  ULTRA_BALL = "An ultra-performance Ball with a 2.0x higher catch rate than a standard Poké Ball.",
  MASTER_BALL = "The ultimate Ball that catches any wild Pokémon without fail.",
  SAFARI_BALL = "A specialized Ball used exclusively inside the Safari Zone.",
  NET_BALL = "A Ball that works particularly well on Water- and Bug-type Pokémon.",
  DIVE_BALL = "A Ball that works better on Pokémon encountered in the sea or underwater.",
  NEST_BALL = "A Ball that works better on weaker Pokémon with lower levels.",
  REPEAT_BALL = "A Ball that works better on Pokémon species you have caught before.",
  TIMER_BALL = "A Ball that becomes more effective the more turns a battle takes.",
  LUXURY_BALL = "A comfortable Ball that makes a captured Pokémon quickly grow friendly.",
  PREMIER_BALL = "A rare commemorative Ball made to celebrate a special occasion.",

  -- Healing & Recovery
  POTION = "A spray-type medicine that restores 20 HP to a single Pokémon.",
  SUPER_POTION = "A spray-type medicine that restores 50 HP to a single Pokémon.",
  HYPER_POTION = "A spray-type medicine that restores 200 HP to a single Pokémon.",
  MAX_POTION = "A spray-type medicine that completely restores all HP to a single Pokémon.",
  FULL_RESTORE = "A miraculous medicine that fully restores HP and cures all status ailments.",
  REVIVE = "A medicine that revives a fainted Pokémon with half of its maximum HP.",
  MAX_REVIVE = "A medicine that revives a fainted Pokémon and completely restores full HP.",
  ANTIDOTE = "A spray-type medicine that cures a poisoned Pokémon.",
  BURN_HEAL = "A soothing ointment that heals a Pokémon of burns.",
  ICE_HEAL = "A warm defrosting medicine that thaws a frozen Pokémon.",
  AWAKENING = "A medicine that awakens a sleeping Pokémon.",
  PARALYZ_HEAL = "A medicine that cures a Pokémon of paralysis.",
  FULL_HEAL = "A versatile spray medicine that cures all status conditions of a single Pokémon.",
  ETHER = "Restores 10 PP to a single selected move of a Pokémon.",
  MAX_ETHER = "Fully restores all PP to a single selected move of a Pokémon.",
  ELIXER = "Restores 10 PP to all four moves of a Pokémon.",
  MAX_ELIXER = "Fully restores all PP to all four moves of a Pokémon.",
  FRESH_WATER = "Clean, refreshing mineral water that restores 50 HP to a Pokémon.",
  SODA_POP = "A fizzy, bubbly soda that restores 60 HP to a Pokémon.",
  LEMONADE = "A sweet, delicious juice that restores 80 HP to a Pokémon.",
  MOOMOO_MILK = "Highly nutritious milk that restores 100 HP to a Pokémon.",
  ENERGYPOWDER = "A bitter medicinal powder that restores 50 HP to a Pokémon.",
  ENERGY_ROOT = "An extremely bitter root that restores 200 HP to a Pokémon.",
  HEAL_POWDER = "A bitter medicinal powder that cures all status conditions.",
  REVIVAL_HERB = "A very bitter herb that revives a fainted Pokémon to full HP.",
  SACRED_ASH = "Revives all fainted Pokémon in your party to complete, full HP.",

  -- Berries
  BERRY = "A self-use item that restores 10 HP when consumed or held in battle.",
  CHERI_BERRY = "A self-use berry that cures paralysis when held or consumed.",
  CHESTO_BERRY = "A self-use berry that awakens a Pokémon from sleep.",
  PECHA_BERRY = "A self-use berry that cures poison when held or consumed.",
  RAWST_BERRY = "A self-use berry that heals burns when held or consumed.",
  ASPEAR_BERRY = "A self-use berry that thaws a frozen Pokémon.",
  LEPPA_BERRY = "A self-use berry that restores 10 PP to a depleted move.",
  ORAN_BERRY = "A self-use berry that restores 10 HP to the holder.",
  PERSIM_BERRY = "A self-use berry that snaps a Pokémon out of confusion.",
  LUM_BERRY = "A self-use berry that cures any status ailment.",
  SITRUS_BERRY = "A self-use berry that restores 30 HP to the holder.",

  -- Evolution Stones & Vitamins
  RARE_CANDY = "A concentrated candy that instantly raises a Pokémon's level by 1.",
  HP_UP = "A nutritious drink that permanently raises the base HP stat of a Pokémon.",
  PROTEIN = "A nutritious drink that permanently raises the base Attack stat of a Pokémon.",
  IRON = "A nutritious drink that permanently raises the base Defense stat of a Pokémon.",
  CARBOS = "A nutritious drink that permanently raises the base Speed stat of a Pokémon.",
  CALCIUM = "A nutritious drink that permanently raises the base Special stat of a Pokémon.",
  ZINC = "A nutritious drink that permanently raises the base Sp. Def stat of a Pokémon.",
  PP_UP = "Permanently increases the maximum PP of a selected move by 20%.",
  PP_MAX = "Maximizes the PP of a selected move to its absolute upper limit.",
  FIRE_STONE = "A peculiar stone that causes certain species of Pokémon to evolve.",
  THUNDER_STONE = "A peculiar stone that causes certain species of Pokémon to evolve.",
  WATER_STONE = "A peculiar stone that causes certain species of Pokémon to evolve.",
  LEAF_STONE = "A peculiar stone that causes certain species of Pokémon to evolve.",
  MOON_STONE = "A peculiar stone that causes certain species of Pokémon to evolve.",
  SUN_STONE = "A peculiar stone that causes certain species of Pokémon to evolve.",
  SHINY_STONE = "A dazzling stone that makes certain species of Pokémon evolve.",
  DUSK_STONE = "A dark stone that makes certain species of Pokémon evolve.",
  DAWN_STONE = "A sparkling stone that makes certain species of Pokémon evolve.",

  -- Field, Battle, & Held Items
  ESCAPE_ROPE = "A sturdy, long rope for escaping immediately from caves or dungeons.",
  REPEL = "Prevents weak wild Pokémon from attacking for 100 steps.",
  SUPER_REPEL = "Prevents weak wild Pokémon from attacking for 200 steps.",
  MAX_REPEL = "Prevents weak wild Pokémon from attacking for 250 steps.",
  POKE_DOLL = "An attractive doll that distracts wild Pokémon, allowing guaranteed escape.",
  X_ATTACK = "Temporarily boosts the Attack stat of the active Pokémon in battle.",
  X_DEFEND = "Temporarily boosts the Defense stat of the active Pokémon in battle.",
  X_SPEED = "Temporarily boosts the Speed stat of the active Pokémon in battle.",
  X_SPECIAL = "Temporarily boosts the Special stat of the active Pokémon in battle.",
  X_ACCURACY = "Temporarily boosts the Accuracy of the active Pokémon in battle.",
  DIRE_HIT = "Greatly boosts the critical-hit ratio of the active Pokémon in battle.",
  GUARD_SPEC = "Protects the active Pokémon's stats from being lowered for 5 turns.",
  NUGGET = "A nugget of pure, sparkling gold. It can be sold at Poké Marts for a high price.",
  PEARL = "A pretty, shiny pearl that can be sold for a modest price.",
  BIG_PEARL = "A large, lovely pearl that can be sold for a high price.",
  STARDUST = "Red, sparkling sand that can be sold at a decent price.",
  STAR_PIECE = "A shard of a red gem that can be sold at a very high price.",
  LEFTOVERS = "An item to be held by a Pokémon that gradually restores a little HP every turn.",
  EXP_SHARE = "An item to be held by a Pokémon that grants half of all gained experience.",
  QUICK_CLAW = "An item to be held by a Pokémon that occasionally allows it to strike first.",
  FOCUS_BAND = "An item to be held by a Pokémon that may prevent fainting with 1 HP remaining.",
  KINGS_ROCK = "An item to be held by a Pokémon that may cause the foe to flinch on hit.",
  SOOTHE_BELL = "A bell with a comforting chime that calms the holder and makes it friendly.",
  CLEANSE_TAG = "An item to be held by a Pokémon that helps repel weak wild Pokémon.",
  AMULET_COIN = "Doubles the prize money received after winning a trainer battle.",
  EVERSTONE = "A peculiar stone that prevents the holder from evolving.",
  MIRACLE_SEED = "An item to be held by a Pokémon that boosts the power of Grass-type moves.",
  CHARCOAL = "An item to be held by a Pokémon that boosts the power of Fire-type moves.",
  MYSTIC_WATER = "An item to be held by a Pokémon that boosts the power of Water-type moves.",
  MAGNET = "An item to be held by a Pokémon that boosts the power of Electric-type moves.",
  BLACK_BELT = "An item to be held by a Pokémon that boosts the power of Fighting-type moves.",
  SHARP_BEAK = "An item to be held by a Pokémon that boosts the power of Flying-type moves.",
  POISON_BARB = "An item to be held by a Pokémon that boosts the power of Poison-type moves.",
  SOFT_SAND = "An item to be held by a Pokémon that boosts the power of Ground-type moves.",
  HARD_STONE = "An item to be held by a Pokémon that boosts the power of Rock-type moves.",
  SILK_SCARF = "An item to be held by a Pokémon that boosts the power of Normal-type moves.",
  BLACKGLASSES = "An item to be held by a Pokémon that boosts the power of Dark-type moves.",
  METAL_COAT = "An item to be held by a Pokémon that boosts the power of Steel-type moves.",
  DRAGON_FANG = "An item to be held by a Pokémon that boosts the power of Dragon-type moves.",
  DRAGON_SCALE = "A thick, tough scale that enables certain Dragon-type Pokémon to evolve.",
  UPGRADE = "A transparent device produced by Silph Co. used to evolve Porygon.",
}

function ItemDatabase.getDescription(itemId, def, game)
  if not itemId then return "A useful item stored in your inventory." end
  local idStr = tostring(itemId)
  local upperId = idStr:upper()

  -- 1. Custom Provider Hooks registered by mods
  for _, prov in ipairs(itemDescriptionProviders) do
    local ok, desc = pcall(prov, itemId, def, game)
    if ok and desc and type(desc) == "string" and desc ~= "" then
      return desc:gsub("\n", " "):gsub("%s+", " ")
    end
  end

  -- 2. Explicit description in item definition
  if def and (def.description or def.flavorText or def.desc) then
    local d = def.description or def.flavorText or def.desc
    if type(d) == "table" then d = table.concat(d, " ") end
    if type(d) == "string" and d ~= "" then
      d = d:gsub("<NEXT>", " "):gsub("<LINE>", " "):gsub("<PAGE>", " "):gsub("\n", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      return d
    end
  end

  -- 3. Mod-registered item table lookup
  if registeredItems[upperId] then
    local r = registeredItems[upperId]
    local d = r.description or r.flavorText or r.desc
    if type(d) == "string" and d ~= "" then
      d = d:gsub("<NEXT>", " "):gsub("<LINE>", " "):gsub("<PAGE>", " "):gsub("\n", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      return d
    end
  end

  -- 4. Canonical direct item match
  if CANONICAL_DESCRIPTIONS[upperId] then
    return CANONICAL_DESCRIPTIONS[upperId]
  end

  local cleanId = upperId:gsub("^ITEM_", "")
  if CANONICAL_DESCRIPTIONS[cleanId] then
    return CANONICAL_DESCRIPTIONS[cleanId]
  end

  -- 5. Dynamic TM/HM Move Lookup via MoveDatabase
  local moveKey = nil
  local machineLabel = nil

  if def and def.machine and def.machine.move then
    moveKey = def.machine.move
    machineLabel = def.name or def.machine.kind or "TM"
  elseif game and game.data and game.data.items then
    -- Try finding matching TM/HM in game data
    local directDef = game.data.items[itemId]
    if directDef and directDef.machine and directDef.machine.move then
      moveKey = directDef.machine.move
      machineLabel = directDef.name or "TM"
    else
      for k, itm in pairs(game.data.items) do
        if (itm.name == idStr or k == upperId) and itm.machine and itm.machine.move then
          moveKey = itm.machine.move
          machineLabel = itm.name or "TM"
          break
        end
      end
    end
  end

  if moveKey then
    local moveName = moveKey:gsub("_", " ")
    local mDef = game and game.data and game.data.moves and game.data.moves[moveKey]
    if mDef and mDef.name then moveName = mDef.name end
    local moveDesc = MoveDatabase.getDescription(moveKey, mDef, game)
    if moveDesc and not moveDesc:find("A attack technique") then
      return ("Teaches the move %s.\n%s"):format(moveName, moveDesc)
    else
      return ("Technical machine that teaches the move %s to compatible Pokémon."):format(moveName)
    end
  end

  -- 6. Fallback TM/HM regex detection (e.g. TM34, HM02)
  local tmNum = upperId:match("^TM_?(%d+)$")
  local hmNum = upperId:match("^HM_?(%d+)$")
  if tmNum or hmNum then
    local label = tmNum and ("TM" .. tmNum) or ("HM" .. hmNum)
    if game and game.data and game.data.items then
      for k, itm in pairs(game.data.items) do
        if itm.name == label and itm.machine and itm.machine.move then
          local mKey = itm.machine.move
          local mDef = game.data.moves and game.data.moves[mKey]
          local mDesc = MoveDatabase.getDescription(mKey, mDef, game)
          return ("Teaches %s (%s).\n%s"):format(label, (mDef and mDef.name) or mKey:gsub("_", " "), mDesc)
        end
      end
    end
    return ("Technical machine %s. Teaches a combat move to compatible Pokémon."):format(label)
  end

  return "Item stored safely within the Pokémon terminal system."
end

return ItemDatabase
