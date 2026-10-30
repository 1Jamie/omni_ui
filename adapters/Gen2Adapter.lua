-- OmniUI Gen 2 Adapter (Gold / Silver / Crystal)
-- Bridges Gen 2 memory layouts, DVs, RTC, 4-pocket bags, split special, genders, Unown forms, Pokérus, and field moves.

local BaseAdapter = require("mods.omni_ui.adapters.BaseAdapter")

local Gen2Adapter = setmetatable({}, { __index = BaseAdapter })
Gen2Adapter.__index = Gen2Adapter

function Gen2Adapter.new(game)
  local self = BaseAdapter.new(game)
  self.generation = 2
  self.region = "JOHTO"
  setmetatable(self, Gen2Adapter)
  return self
end

-- -------------------------------------------------------------------------
-- Gen 2 Field Moves Registry
-- -------------------------------------------------------------------------
local GEN2_FIELD_MOVES = {
  CUT = true, FLY = true, SURF = true, STRENGTH = true,
  FLASH = true, WATERFALL = true, WHIRLPOOL = true, HEADBUTT = true,
  ROCK_SMASH = true, DIG = true, TELEPORT = true, SOFTBOILED = true,
  MILK_DRINK = true, SWEET_SCENT = true,
}

-- -------------------------------------------------------------------------
-- Helper: GSC Shininess from DVs
-- -------------------------------------------------------------------------
local function isGscShiny(dvs)
  if not dvs then return false end
  local atk = dvs.attack or dvs.atk or 0
  local def = dvs.defense or dvs.def or 0
  local spd = dvs.speed or dvs.spe or 0
  local spc = dvs.special or dvs.spc or 0
  local validAtk = (atk == 2 or atk == 3 or atk == 6 or atk == 7 or atk == 10 or atk == 11 or atk == 14 or atk == 15)
  return validAtk and def == 10 and spd == 10 and spc == 10
end

-- -------------------------------------------------------------------------
-- Helper: Egg Incubation Flavor Text (Matching src/ui/gen2/SummaryMenu.lua)
-- -------------------------------------------------------------------------
local function getEggFlavor(cycles)
  cycles = tonumber(cycles) or 0
  if cycles < 0x6 then
    return "It's making sounds inside. It's going to hatch soon!"
  elseif cycles < 0xb then
    return "It moves around inside sometimes. It must be close to hatching."
  elseif cycles < 0x29 then
    return "Wonder what's inside? It needs more time, though."
  else
    return "This EGG needs a lot more time to hatch."
  end
end

-- -------------------------------------------------------------------------
-- Helper: Unown Letter Form Derivation (Middle 2 bits of all 4 DVs)
-- -------------------------------------------------------------------------
local UNOWN_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function deriveUnownLetter(dvs)
  if not dvs then return "A" end
  local atk = math.floor((dvs.attack or dvs.atk or 0) / 2) % 4
  local def = math.floor((dvs.defense or dvs.def or 0) / 2) % 4
  local spd = math.floor((dvs.speed or dvs.spe or 0) / 2) % 4
  local spc = math.floor((dvs.special or dvs.spc or 0) / 2) % 4
  local packed = (atk * 64) + (def * 16) + (spd * 4) + spc
  local letterIndex = math.floor(packed / 10) + 1
  if letterIndex < 1 or letterIndex > 26 then letterIndex = 1 end
  return UNOWN_ALPHABET:sub(letterIndex, letterIndex)
end

-- -------------------------------------------------------------------------
-- Pokémon Normalization
-- -------------------------------------------------------------------------
function Gen2Adapter:normalizeMon(mon, index)
  if not mon then return nil end

  local isEgg = (mon.isEgg == true)
      or (mon.species == "EGG" or mon.species == 253 or mon.species == "Egg")
      or (mon.name == "EGG" and mon.level == nil)

  if isEgg then
    local cycles = tonumber(mon.eggCycles or mon.eggSteps or mon.happiness or 0) or 0
    return {
      index = index or mon.index or 1,
      isEgg = true,
      eggCycles = cycles,
      eggFlavorText = getEggFlavor(cycles),
      species = "EGG",
      speciesId = "EGG",
      name = "POKéMON EGG",
      displayName = "POKéMON EGG",
      nickname = "POKéMON EGG",
      level = nil,
      hp = mon.hp or 0,
      currentHp = mon.hp or 0,
      maxHp = mon.maxHp or mon.hp or 0,
      status = nil,
      pokerus = nil,
      pokerusDays = 0,
      pokerusStrain = 0,
      gender = nil,
      heldItem = nil,
      isMail = false,
      isShiny = false,
      stats = { hp = 0, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0 },
      ivs = mon.dvs or mon.ivs or {},
      moves = {},
      fieldMoves = {},
      otName = mon.otName or mon.ot or "DAY-CARE",
      otId = tonumber(mon.otId or mon.id) or 0,
      exp = 0,
      expNext = 0,
      expPercent = 0.0,
      happiness = cycles,
      raw = mon,
    }
  end

  local norm = BaseAdapter.normalizeMon(self, mon, index)
  if not norm then return nil end

  local data = self.game and self.game.data
  local speciesId = norm.speciesId or mon.species or "UNKNOWN"
  norm.species = speciesId
  norm.name = norm.displayName or norm.nickname or speciesId
  local dvs = mon.dvs or mon.ivs or {}

  -- 1. Held Item & Mail Detection
  norm.heldItem = mon.item or mon.heldItem
  local okMail, Mail = pcall(require, "src.core.gen2.Mail")
  if okMail and Mail and Mail.INDEX and norm.heldItem then
    norm.isMail = (Mail.INDEX[norm.heldItem] ~= nil)
  else
    norm.isMail = false
  end

  -- 2. Gender Derivation
  if mon.gender then
    norm.gender = tostring(mon.gender):upper()
  else
    local okGender, Gender = pcall(require, "src.core.gen2.Gender")
    if okGender and Gender and speciesId then
      local speciesDef = data and data.pokemon and (data.pokemon[speciesId] or data.pokemon[norm.speciesId])
      local ratio = speciesDef and speciesDef.genderRatio
      if ratio == nil then
        local uSp = tostring(speciesId):upper()
        if uSp == "CYNDAQUIL" or uSp == "TOTODILE" or uSp == "CHIKORITA" or uSp == "BULBASAUR" or uSp == "CHARMANDER" or uSp == "SQUIRTLE" or uSp == "EEVEE" or uSp == "TOGEPI" then
          ratio = 0x1f
        elseif uSp == "MAGNEMITE" or uSp == "MAGNETON" or uSp == "VOLTORB" or uSp == "ELECTRODE" or uSp == "STARYU" or uSp == "STARMIE" or uSp == "DITTO" or uSp == "PORYGON" or uSp == "UNOWN" then
          ratio = 0xff
        else
          ratio = 0x7f
        end
      end
      local g = Gender.of(ratio, dvs)
      if g == "male" then
        norm.gender = "MALE"
      elseif g == "female" then
        norm.gender = "FEMALE"
      else
        norm.gender = nil
      end
    end
  end

  -- 3. Unown Form Derivation
  if speciesId == "UNOWN" then
    local okUnown, Unown = pcall(require, "src.core.gen2.Unown")
    if okUnown and Unown and Unown.letterFromDVs then
      local lNum = Unown.letterFromDVs(dvs)
      norm.form = Unown.name(lNum) or "A"
    else
      norm.form = deriveUnownLetter(dvs)
    end
  else
    norm.form = mon.form
  end

  -- 4. Pokérus Derivation (Active vs Cured)
  local okPkrs, Pokerus = pcall(require, "src.core.gen2.Pokerus")
  local rawPkrs = mon.pokerus or mon.pokerusStatus
  if okPkrs and Pokerus then
    norm.pokerusDays = Pokerus.days(mon) or 0
    norm.pokerusStrain = Pokerus.strain(mon) or 0
    if norm.pokerusStrain > 0 and norm.pokerusDays > 0 then
      norm.pokerus = "infected"
    elseif norm.pokerusStrain > 0 and norm.pokerusDays == 0 then
      norm.pokerus = "cured"
    else
      norm.pokerus = nil
    end
  elseif rawPkrs and rawPkrs > 0 then
    local strain = math.floor(rawPkrs / 16) % 16
    local days = rawPkrs % 16
    norm.pokerusStrain = strain
    norm.pokerusDays = days
    norm.pokerus = (strain > 0 and days > 0) and "infected" or ((strain > 0 and days == 0) and "cured" or nil)
  end

  -- 5. Shininess
  if mon.isShiny ~= nil then
    norm.isShiny = mon.isShiny
  else
    norm.isShiny = isGscShiny(dvs)
  end

  -- Ensure Stats are computed for Boxed Mons in Gen 2
  local okMon, Gen2Mon = pcall(require, "src.battle.gen2.Mon")
  if okMon and Gen2Mon and Gen2Mon.refreshStats and (not mon.stats or not mon.stats.attack or mon.stats.attack == 0) then
    pcall(Gen2Mon.refreshStats, mon, data)
  end

  -- 6. Split Special Stats & Full Stat Block
  norm.stats = mon.stats or norm.stats or {}
  local lvl = mon.level or 1
  norm.stats.attack = norm.stats.attack or (mon.stats and mon.stats.attack) or math.floor(lvl * 1.8 + 5)
  norm.stats.defense = norm.stats.defense or (mon.stats and mon.stats.defense) or math.floor(lvl * 1.8 + 5)
  norm.stats.speed = norm.stats.speed or (mon.stats and mon.stats.speed) or math.floor(lvl * 1.8 + 5)
  norm.stats.spAttack = (mon.stats and (mon.stats.spAttack or mon.stats.specialAttack or mon.stats.spa))
      or (mon.stats and mon.stats.special)
      or norm.stats.special
      or norm.stats.spAttack
      or math.floor(lvl * 1.8 + 5)
  norm.stats.spDefense = (mon.stats and (mon.stats.spDefense or mon.stats.specialDefense or mon.stats.spd))
      or (mon.stats and mon.stats.special)
      or norm.stats.special
      or norm.stats.spDefense
      or math.floor(lvl * 1.8 + 5)
  norm.maxHp = (mon.stats and mon.stats.hp) or mon.maxHp or mon.hp or math.floor(lvl * 2.5 + 10)

  -- 7. Gen 2 Field Moves
  norm.fieldMoves = {}
  local okField, G2Field = pcall(require, "src.world.gen2.FieldMoves")
  for _, move in ipairs(mon.moves or {}) do
    local moveId = (type(move) == "table" and (move.id or move.name)) or move
    if moveId and type(moveId) == "string" then
      local uId = moveId:upper()
      if GEN2_FIELD_MOVES[uId] or (okField and G2Field and G2Field.isFieldMove and G2Field.isFieldMove(moveId)) then
        norm.fieldMoves[#norm.fieldMoves + 1] = uId
      end
    end
  end

  return norm
end

-- -------------------------------------------------------------------------
-- Bag & 4-Pocket System (ITEMS, BALLS, KEY_ITEMS, TM_HM)
-- -------------------------------------------------------------------------
function Gen2Adapter:getBagPockets()
  local save = self.game and self.game.save or {}
  local data = self.game and self.game.data or {}
  local itemsData = data.items or {}
  local movesData = data.moves or {}

  local pockets = {
    { id = "ITEM", label = "ITEMS", items = {} },
    { id = "BALL", label = "POKé BALLS", items = {} },
    { id = "KEY_ITEM", label = "KEY ITEMS", items = {} },
    { id = "TM_HM", label = "TM/HM", items = {} },
  }

  local pocketMap = {
    ITEM = pockets[1],
    ITEMS = pockets[1],
    BALL = pockets[2],
    BALLS = pockets[2],
    KEY_ITEM = pockets[3],
    KEY_ITEMS = pockets[3],
    KEY = pockets[3],
    TM_HM = pockets[4],
    TM = pockets[4],
    TMS = pockets[4],
  }

  -- 1. Scan standard inventory
  local rawInv = save.inventory or (save.bag and save.bag.items) or save.items or {}
  for itemId, count in pairs(rawInv) do
    local id = (type(count) == "table" and count.id) or itemId
    local qty = (type(count) == "table" and count.count) or count
    if type(qty) == "number" and qty > 0 then
      local def = itemsData[id] or {}
      local pKey = def.pocket or "ITEM"
      local targetPocket = pocketMap[pKey] or pockets[1]

      if targetPocket.id == "TM_HM" or def.teaches then
        local moveId = def.teaches or def.moveId
        local moveDef = movesData[moveId] or {}
        pockets[4].items[#pockets[4].items + 1] = {
          id = id,
          label = def.name or id,
          count = qty,
          pocket = "TM_HM",
          desc = def.desc or (moveDef and moveDef.desc) or "",
          isTM = true,
          teaches = moveId,
          moveName = (moveDef and moveDef.name) or (moveId and moveId:gsub("_", " ")) or "UNKNOWN",
          moveType = (moveDef and moveDef.type) or "NORMAL",
          power = moveDef.power or 0,
          accuracy = moveDef.accuracy or 100,
          pp = moveDef.pp or 0,
        }
      else
        targetPocket.items[#targetPocket.items + 1] = {
          id = id,
          label = def.name or id,
          count = qty,
          pocket = targetPocket.id,
          desc = def.desc or "",
          isTM = false,
        }
      end
    end
  end

  -- 2. Scan dedicated TM register if present
  local tmBag = save.tmBag or (save.pockets and save.pockets.tm) or {}
  for tmId, qty in pairs(tmBag) do
    if type(qty) == "number" and qty > 0 then
      local def = itemsData[tmId] or {}
      local moveId = def.teaches or def.moveId or tmId
      local moveDef = movesData[moveId] or {}
      pockets[4].items[#pockets[4].items + 1] = {
        id = tmId,
        label = def.name or tmId,
        count = qty,
        pocket = "TM_HM",
        desc = def.desc or (moveDef and moveDef.desc) or "",
        isTM = true,
        teaches = moveId,
        moveName = (moveDef and moveDef.name) or (moveId and moveId:gsub("_", " ")) or "UNKNOWN",
        moveType = (moveDef and moveDef.type) or "NORMAL",
        power = moveDef.power or 0,
        accuracy = moveDef.accuracy or 100,
        pp = moveDef.pp or 0,
      }
    end
  end

  -- Sort each pocket alphabetically by label
  for _, p in ipairs(pockets) do
    table.sort(p.items, function(a, b) return (a.label or a.id) < (b.label or b.id) end)
  end

  return pockets
end

-- -------------------------------------------------------------------------
-- Player Info, Badges, RTC & Bank of Mom
-- -------------------------------------------------------------------------
function Gen2Adapter:getPlayerInfo()
  local info = BaseAdapter.getPlayerInfo(self)
  local save = self.game and self.game.save or {}

  -- 1. Dual-Region 16 Badges
  local jCount = 0
  local kCount = 0
  local jFlags = {}
  local kFlags = {}

  local jBadges = save.johtoBadges or save.badges or {}
  local kBadges = save.kantoBadges or {}

  info.johtoBadgeNames = { "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "MINERAL", "GLACIER", "RISING" }
  info.kantoBadgeNames = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH", "VOLCANO", "EARTH" }

  for i = 1, 8 do
    local jb = jBadges[i] or (type(jBadges) == "table" and jBadges[info.johtoBadgeNames[i]])
    jFlags[i] = (jb == true or (type(jb) == "number" and jb > 0))
    if jFlags[i] then jCount = jCount + 1 end

    local kb = kBadges[i] or (type(kBadges) == "table" and kBadges[info.kantoBadgeNames[i]])
    kFlags[i] = (kb == true or (type(kb) == "number" and kb > 0))
    if kFlags[i] then kCount = kCount + 1 end
  end

  info.badges = jCount + kCount
  info.johtoBadges = jCount
  info.kantoBadges = kCount
  info.johtoBadgeFlags = jFlags
  info.kantoBadgeFlags = kFlags
  info.maxBadges = 16
  info.region = "JOHTO"
  info.badgeNames = info.johtoBadgeNames

  -- 2. Bank of Mom & Wallet Money
  info.money = tonumber(save.money or (save.player and save.player.money) or info.money or 0) or 0
  info.momSavings = tonumber(save.momMoney or save.momSavings or (save.mom and save.mom.money) or 0) or 0
  info.momShopping = (save.momShopping == true or (save.mom and save.mom.shopping == true))

  -- 3. RTC & Time-of-Day
  local okClock, Clock = pcall(require, "src.core.gen2.Clock")
  local okPal, Palettes = pcall(require, "src.world.gen2.Palettes")
  local hour = (okClock and Clock and Clock.hour and Clock.hour(save)) or tonumber(os.date("%H")) or 10
  local minute = (okClock and Clock and Clock.minute and Clock.minute(save)) or tonumber(os.date("%M")) or 0
  local weekday = (okClock and Clock and Clock.weekday and Clock.weekday(save)) or tonumber(os.date("%w")) or 0
  local dayName = (okClock and Clock and Clock.weekdayName and Clock.weekdayName(weekday + 1)) or "SUNDAY"
  local timeOfDay = (okPal and Palettes and Palettes.clockDaytime and Palettes.clockDaytime(hour)) or "DAY"
  local daytimeLabel = (okClock and Clock and Clock.daytimeLabel and Clock.daytimeLabel(hour)) or timeOfDay

  info.rtc = {
    hour = hour,
    minute = minute,
    weekday = weekday,
    dayName = tostring(dayName):upper(),
    timeOfDay = timeOfDay,
    daytimeLabel = tostring(daytimeLabel):upper(),
  }

  return info
end

-- -------------------------------------------------------------------------
-- Bug-Catching Contest Info & Start Menu Integration
-- -------------------------------------------------------------------------
function Gen2Adapter:getBugContestInfo()
  local save = self.game and self.game.save or {}
  local contest = save.bugContest
  local okContest, BugContest = pcall(require, "src.core.gen2.BugContest")
  local isActive = (okContest and BugContest and BugContest.isActive and BugContest.isActive(save))
      or (contest and contest.active == true)

  if isActive then
    return {
      active = true,
      balls = (contest and (contest.balls or contest.parkBalls)) or (okContest and BugContest.BALLS) or 20,
      time = (contest and contest.time) or (okContest and BugContest.MINUTES) or 20,
      caughtMon = contest and contest.caughtMon,
    }
  end
  return nil
end

function Gen2Adapter:getStartMenuItems()
  local items = BaseAdapter.getStartMenuItems(self)
  local contest = self:getBugContestInfo()

  if contest and contest.active then
    local filtered = {}
    -- 1. Insert Bug Contest status card at the top
    filtered[#filtered + 1] = {
      id = "contest_status",
      label = "PARK BALLS",
      value = string.format("×%02d", contest.balls),
      isContest = true,
    }

    -- 2. Insert caught contest Pokémon inspector if one is caught
    if contest.caughtMon then
      filtered[#filtered + 1] = {
        id = "contest_mon",
        label = "CONTEST MON",
        value = (type(contest.caughtMon) == "table" and (contest.caughtMon.nickname or contest.caughtMon.species)) or "CAUGHT",
        isContest = true,
      }
    end

    -- 3. Filter normal items: hide pack and quit, replace save with quitContest
    for _, it in ipairs(items) do
      if it.id == "save" then
        filtered[#filtered + 1] = {
          id = "quitContest",
          label = "QUIT CONTEST",
          desc = "Quit and be judged.",
        }
      elseif it.id ~= "pack" and it.id ~= "quit" and it.id ~= "contest_status" then
        filtered[#filtered + 1] = it
      end
    end
    return filtered
  end

  return items
end

-- -------------------------------------------------------------------------
-- Pokédex Entries & Sort Modes (NEW, OLD, A-Z) & Unown Dex
-- -------------------------------------------------------------------------
function Gen2Adapter:getPokedexEntries(mode, searchType1, searchType2)
  local save = self.game and self.game.save or {}
  local data = self.game and self.game.data or {}
  local dexOwned = (save.pokedex and save.pokedex.owned) or {}
  local dexSeen = (save.pokedex and save.pokedex.seen) or {}

  local entries = {}
  local sortMode = mode or "NEW"

  for id, def in pairs(data.pokemon or {}) do
    if type(def) == "table" and id ~= "EGG" then
      local isSeen = dexSeen[id] == true or dexOwned[id] == true
      local isCaught = dexOwned[id] == true
      local jNum = def.johtoDex or def.newDex or def.id or 0
      local natNum = def.nationalDex or def.oldDex or def.id or 0

      local match = true
      if searchType1 and def.types and def.types[1] ~= searchType1 and def.types[2] ~= searchType1 then
        match = false
      end
      if searchType2 and def.types and def.types[1] ~= searchType2 and def.types[2] ~= searchType2 then
        match = false
      end

      if match then
        entries[#entries + 1] = {
          id = id,
          name = def.name or id,
          johtoNum = jNum,
          nationalNum = natNum,
          seen = isSeen,
          caught = isCaught,
          types = def.types or { "NORMAL" },
          height = def.height or "???",
          weight = def.weight or "???",
        }
      end
    end
  end

  if sortMode == "OLD" then
    table.sort(entries, function(a, b) return a.nationalNum < b.nationalNum end)
  elseif sortMode == "A-Z" then
    table.sort(entries, function(a, b) return a.name < b.name end)
  else
    table.sort(entries, function(a, b) return a.johtoNum < b.johtoNum end)
  end

  return entries
end

function Gen2Adapter:hasSeen(speciesId)
  local save = self.game and self.game.save or {}
  local dex = save.pokedex or {}
  local seenTbl = dex.seen or {}
  if seenTbl[speciesId] == true then return true end
  if type(speciesId) == "number" then
    if seenTbl[tostring(speciesId)] == true then return true end
  elseif type(speciesId) == "string" then
    local num = tonumber(speciesId)
    if num and seenTbl[num] == true then return true end
    if seenTbl[speciesId:upper()] == true then return true end
  end
  return self:hasCaught(speciesId)
end

function Gen2Adapter:hasCaught(speciesId)
  local save = self.game and self.game.save or {}
  local dex = save.pokedex or {}
  local ownedTbl = dex.owned or dex.caught or {}
  if ownedTbl[speciesId] == true then return true end
  if type(speciesId) == "number" then
    if ownedTbl[tostring(speciesId)] == true then return true end
  elseif type(speciesId) == "string" then
    local num = tonumber(speciesId)
    if num and ownedTbl[num] == true then return true end
    if ownedTbl[speciesId:upper()] == true then return true end
  end
  return false
end

function Gen2Adapter:isNationalDexUnlocked()
  local save = self.game and self.game.save or {}
  local dex = save.pokedex or {}
  if dex.unlockedOldDex == true or dex.modeIndex ~= nil then return true end
  local badges = save.badges or (save.player and save.player.badges) or 0
  if type(badges) == "number" and badges > 8 then return true end
  if type(badges) == "table" and #badges > 8 then return true end
  return true
end

function Gen2Adapter:getUnownDex()
  local save = self.game and self.game.save or {}
  local unownDex = save.unownDex or {}
  local okUnown, Unown = pcall(require, "src.core.gen2.Unown")
  local list = {}

  for i, letterIndex in ipairs(unownDex) do
    local letterChar = (okUnown and Unown and Unown.name and Unown.name(letterIndex))
        or UNOWN_ALPHABET:sub(letterIndex, letterIndex)
    list[#list + 1] = {
      order = i,
      index = letterIndex,
      letter = letterChar,
      form = letterChar,
    }
  end

  return list
end

-- -------------------------------------------------------------------------
-- Combat Cache & Weather Support
-- -------------------------------------------------------------------------
function Gen2Adapter:updateBattleInfo(outCache)
  local cache = outCache or self:getBattleCache()
  local battle, topState = self:getActiveBattle()
  if not battle then
    cache.isActive = false
    return cache
  end

  cache.isActive = true
  local data = self.game and self.game.data
  local screen = (battle.battle and battle) or (topState and topState.battle and topState) or topState or battle
  local model = (battle.battle) or (topState and topState.battle) or battle

  -- 1. Sync Player Battler
  local pBattler = model.player or battle.player
  local pMon = (pBattler and pBattler.mon) or pBattler
  if pMon and (pMon.species or pMon.speciesId) then
    local pSpecies = pMon.species or pMon.speciesId or "UNKNOWN"
    local pDef = data and data.pokemon and data.pokemon[pSpecies]
    cache.player.active = true
    cache.player.species = pSpecies
    cache.player.name = (pBattler and pBattler.name) or pMon.nickname or (pDef and pDef.name) or pSpecies
    cache.player.level = pMon.level or 1
    cache.player.maxHp = (pBattler and pBattler.maxHP) or (pMon.stats and pMon.stats.hp) or pMon.maxHp or pMon.hp or 1
    cache.player.shownHp = math.max(0, math.floor((screen and screen.shownHp and screen.shownHp.player) or (pBattler and pBattler.shownHP) or pMon.hp or 0))
    cache.player.hp = pMon.hp or (pBattler and pBattler.hp) or 0
    cache.player.shownPx = (pBattler and pBattler.shownPx) or (screen and screen.hudHpPixels and screen:hudHpPixels(pMon, "player")) or 0
    cache.player.hpRatio = cache.player.maxHp > 0 and math.max(0, math.min(1, cache.player.shownHp / cache.player.maxHp)) or 0
    cache.player.status = (screen and screen.shownStatus and screen.shownStatus.player) or (pBattler and pBattler.shownStatus) or pMon.status
    cache.player.shownStatus = cache.player.status
    cache.player.types = (pBattler and pBattler.curTypes) or (pDef and pDef.types) or { "NORMAL" }
    cache.player.exp = pMon.exp or 0
    cache.player.gender = pMon.gender
    cache.player.heldItem = pMon.item or pMon.heldItem
    cache.player.isShiny = pMon.isShiny or false

    -- Calculate expRatio
    if screen and screen.expPixels then
      local okExp, px = pcall(screen.expPixels, screen, pMon, pMon.level or 1, pMon.exp or 0)
      if okExp and px then
        cache.player.expRatio = math.max(0, math.min(1, px / 64))
      end
    end
    if not cache.player.expRatio then
      local okExp, Exp = pcall(require, "src.battle.Experience")
      if okExp and Exp and Exp.calcExpProgress and pDef and pDef.growthRate then
        cache.player.expRatio = Exp.calcExpProgress(pDef.growthRate, pMon.level or 1, pMon.exp or 0)
      else
        cache.player.expRatio = 0.5
      end
    end

    local party = (self.game and self.game.save and self.game.save.party) or (model and model.party) or {}
    for i = 1, 6 do
      local pm = party[i]
      if pm then
        if (pm.hp or 0) <= 0 then
          cache.player.partyBalls[i] = "fainted"
        elseif pm.status then
          cache.player.partyBalls[i] = "status"
        else
          cache.player.partyBalls[i] = "ok"
        end
      else
        cache.player.partyBalls[i] = "empty"
      end
    end
  else
    cache.player.active = false
  end

  -- 2. Sync Enemy Battler
  local eBattler = model.enemy or battle.enemy
  local eMon = (eBattler and eBattler.mon) or eBattler
  if eMon and (eMon.species or eMon.speciesId) then
    local eSpecies = eMon.species or eMon.speciesId or "UNKNOWN"
    local eDef = data and data.pokemon and data.pokemon[eSpecies]
    cache.enemy.active = true
    cache.enemy.species = eSpecies
    cache.enemy.name = (eBattler and eBattler.name) or (eDef and eDef.name) or eSpecies
    cache.enemy.level = eMon.level or 1
    cache.enemy.maxHp = (eBattler and eBattler.maxHP) or (eMon.stats and eMon.stats.hp) or eMon.maxHp or eMon.hp or 1
    cache.enemy.shownHp = math.max(0, math.floor((screen and screen.shownHp and screen.shownHp.enemy) or (eBattler and eBattler.shownHP) or eMon.hp or 0))
    cache.enemy.hp = eMon.hp or (eBattler and eBattler.hp) or 0
    cache.enemy.shownPx = (eBattler and eBattler.shownPx) or (screen and screen.hudHpPixels and screen:hudHpPixels(eMon, "enemy")) or 0
    cache.enemy.hpRatio = cache.enemy.maxHp > 0 and math.max(0, math.min(1, cache.enemy.shownHp / cache.enemy.maxHp)) or 0
    cache.enemy.status = (screen and screen.shownStatus and screen.shownStatus.enemy) or (eBattler and eBattler.shownStatus) or eMon.status
    cache.enemy.shownStatus = cache.enemy.status
    cache.enemy.types = (eBattler and eBattler.curTypes) or (eDef and eDef.types) or { "NORMAL" }
    cache.enemy.gender = eMon.gender
    cache.enemy.isShiny = eMon.isShiny or false

    local save = self.game and self.game.save
    cache.enemy.isCaught = (save and save.pokedex and save.pokedex.owned and save.pokedex.owned[eSpecies] == true) or false
  else
    cache.enemy.active = false
  end

  -- 3. Sync Moves
  local moves = (screen and screen.playerMoves and screen:playerMoves()) or (pMon and pMon.moves) or {}
  for i = 1, 4 do
    local slot = cache.moves[i]
    local mv = moves[i]
    if mv then
      local mId = (type(mv) == "table" and mv.id) or mv
      local mDef = data and data.moves and data.moves[mId]
      slot.id = mId
      slot.name = (mDef and mDef.name) or tostring(mId):gsub("_", " ")
      slot.type = (mDef and mDef.type) or "NORMAL"
      slot.pp = (type(mv) == "table" and mv.pp) or (mDef and mDef.pp) or 0
      slot.maxPP = (mDef and mDef.pp) or slot.pp or 1
      slot.power = (mDef and mDef.power) or 0
      slot.accuracy = (mDef and mDef.accuracy) or 100
      slot.effectiveness = 1.0
      slot.note = ""
    else
      slot.id = ""
      slot.name = "--"
      slot.type = "NORMAL"
      slot.pp = 0
      slot.maxPP = 0
      slot.power = 0
      slot.accuracy = 0
      slot.effectiveness = 1.0
      slot.note = ""
    end
  end

  -- 4. Actions and Phase Mapping
  cache.actions = {
    { id = "FIGHT", label = "FIGHT" },
    { id = "POKEMON", label = "POKÉMON" },
    { id = "BAG", label = (screen and screen.contest) and "PARK BALL" or "PACK" },
    { id = "RUN", label = "RUN" },
  }

  local sPhase = screen and screen.phase
  if sPhase == "moves" or sPhase == "choose-forget" then
    cache.phase = "move_select"
  elseif sPhase == "menu" then
    cache.phase = "action_select"
  elseif sPhase == "target" then
    cache.phase = "target_select"
  elseif sPhase == "stats-box" or sPhase == "stats_box" then
    cache.phase = "stats_box"
  else
    cache.phase = "messages"
  end

  cache.statsBoxMon = (screen and screen.statsBoxMon) or (topState and (topState.statsBoxMon or topState.mon))
  cache.selectedMove = (screen and screen.moveIndex) or 1
  cache.selectedAction = (screen and screen.menuIndex) or (battle.actionIndex) or 1
  cache.weather = (model and model.weather) or (battle and battle.weather)

  -- 5. Extract Visible Combat Dialogue
  local lines = nil
  if screen and screen.messageLines then
    local okLines, l = pcall(screen.messageLines, screen)
    if okLines and l and #l > 0 then
      lines = l
    end
  end
  if not lines then
    if topState and topState.visibleText then
      lines = topState:visibleText()
    elseif battle.visibleText then
      lines = battle:visibleText()
    elseif screen and screen.message then
      lines = { tostring(screen.message) }
    elseif battle.message then
      lines = { tostring(battle.message) }
    end
  end

  local joined = (lines and #lines > 0) and table.concat(lines, "\n") or ""
  if joined:match("%S") then
    cache.message = joined
  elseif cache.phase == "action_select" or cache.phase == "move_select" then
    cache.message = ("What will %s do?"):format(cache.player.name or "POKÉMON")
  else
    cache.message = ""
  end
  cache.waitingForA = (screen and screen.messageArrowVisible and screen:messageArrowVisible()) or (battle.msgWaiting == true or battle.msgPrompt == true)

  return cache
end

-- -------------------------------------------------------------------------
-- Atomic Storage Layer with Strict Mail Lockout
-- -------------------------------------------------------------------------
local Gen2Boxes = require("src.core.gen2.Boxes")

function Gen2Adapter:getBoxCount()
  return Gen2Boxes.NUM_BOXES or 14
end

function Gen2Adapter:getBoxCapacity()
  return Gen2Boxes.MONS_PER_BOX or 20
end

function Gen2Adapter:getCurrentBox()
  local save = self.game and self.game.save
  return (save and save.currentBox) or 1
end

function Gen2Adapter:setCurrentBox(boxId)
  local save = self.game and self.game.save
  return Gen2Boxes.setCurrent(save, boxId)
end

function Gen2Adapter:getBoxName(boxId)
  local save = self.game and self.game.save
  return Gen2Boxes.name(save, boxId or self:getCurrentBox())
end

function Gen2Adapter:setBoxName(boxId, name)
  local save = self.game and self.game.save
  return Gen2Boxes.rename(save, boxId, name)
end

function Gen2Adapter:getBoxData(boxId)
  local save = self.game and self.game.save
  if not save then return {} end
  local bId = boxId or save.currentBox or 1
  local box = Gen2Boxes.box(save, bId) or {}
  local list = {}
  for slot = 1, self:getBoxCapacity() do
    local mon = box[slot]
    list[slot] = mon and self:normalizeMon(mon, slot) or nil
  end
  return list
end

function Gen2Adapter:canDeposit(partySlot, targetBoxId)
  local save = self.game and self.game.save
  if not save then return false, "No save." end
  local party = save.party or {}
  local mon = party[partySlot]
  if not mon then return false, "No POKéMON selected." end
  if #party <= 1 then return false, "That's your last POKéMON!" end

  -- Strict Gen 2 Mail Lockout
  local held = mon.item or mon.heldItem
  local okMail, Mail = pcall(require, "src.core.gen2.Mail")
  if okMail and Mail and Mail.INDEX and held and Mail.INDEX[held] ~= nil then
    return false, "Please remove the MAIL before depositing."
  end

  local bId = targetBoxId or save.currentBox or 1
  local box = Gen2Boxes.box(save, bId) or {}
  local count = 0
  for slot = 1, self:getBoxCapacity() do
    if box[slot] then count = count + 1 end
  end
  if count >= self:getBoxCapacity() then
    return false, "The BOX is full."
  end
  return Gen2Boxes.canDeposit(save, partySlot, bId)
end

function Gen2Adapter:canWithdraw(boxId, boxSlot)
  local save = self.game and self.game.save
  if not save then return false, "No save." end
  local bId = boxId or save.currentBox or 1
  local box = Gen2Boxes.box(save, bId) or {}
  if not box[boxSlot] then return false, "There is no POKéMON there." end
  if #(save.party or {}) >= 6 then
    return false, "You can't take\nany more POKéMON."
  end
  return true
end

function Gen2Adapter:depositMon(partySlot, targetBoxId, targetSlot)
  local ok, reason = self:canDeposit(partySlot, targetBoxId)
  if not ok then return false, reason end

  local save = self.game and self.game.save
  local data = self.game and self.game.data
  local bId = targetBoxId or save.currentBox or 1
  local box = Gen2Boxes.box(save, bId)

  local mon = table.remove(save.party, partySlot)
  local okMail, Mail = pcall(require, "src.core.gen2.Mail")
  if okMail and Mail and Mail.removeSlot then
    Mail.removeSlot(save, partySlot)
  end
  Gen2Boxes.enterBox(mon, data)

  if targetSlot and targetSlot >= 1 and targetSlot <= self:getBoxCapacity() and not box[targetSlot] then
    box[targetSlot] = mon
  else
    for s = 1, self:getBoxCapacity() do
      if not box[s] then
        box[s] = mon
        break
      end
    end
  end
  return true, mon
end

function Gen2Adapter:withdrawMon(boxId, boxSlot, targetPartySlot)
  local save = self.game and self.game.save
  if not save then return false, "No save." end
  local bId = boxId or save.currentBox or 1
  local box = Gen2Boxes.box(save, bId)
  local mon = box[boxSlot]
  if not mon then return false, "There is no POKéMON there." end
  if #(save.party or {}) >= 6 then
    return false, "You can't take\nany more POKéMON."
  end

  box[boxSlot] = nil
  mon.status = nil
  mon.statusTurns = nil
  if mon.isEgg then
    mon.hp = 0
  else
    mon.hp = mon.maxHp or mon.hp
  end

  save.party = save.party or {}
  if targetPartySlot and targetPartySlot <= #save.party + 1 then
    table.insert(save.party, targetPartySlot, mon)
  else
    table.insert(save.party, mon)
  end
  return true, mon
end

function Gen2Adapter:swapSlots(sourceLoc, sourceSlot, targetLoc, targetSlot, sourceBoxId, targetBoxId)
  local save = self.game and self.game.save
  if not save then return false, "No save." end

  if sourceLoc == "party" and targetLoc == "party" then
    if sourceSlot == targetSlot then return true end
    if save.party[sourceSlot] and save.party[targetSlot] then
      save.party[sourceSlot], save.party[targetSlot] = save.party[targetSlot], save.party[sourceSlot]
      return true
    elseif save.party[sourceSlot] and not save.party[targetSlot] then
      local mon = table.remove(save.party, sourceSlot)
      local insertPos = math.min(#save.party + 1, math.max(1, targetSlot))
      table.insert(save.party, insertPos, mon)
      return true
    end
    return false, "Invalid party slots."
  elseif sourceLoc == "box" and targetLoc == "box" then
    local sB = Gen2Boxes.box(save, sourceBoxId or save.currentBox or 1)
    local tB = Gen2Boxes.box(save, targetBoxId or save.currentBox or 1)
    if not sB or not tB then return false, "Invalid box." end

    if sourceSlot == targetSlot and sB == tB then return true end
    sB[sourceSlot], tB[targetSlot] = tB[targetSlot], sB[sourceSlot]
    return true
  elseif sourceLoc == "party" and targetLoc == "box" then
    local tB = Gen2Boxes.box(save, targetBoxId or save.currentBox or 1)
    if not tB then return false, "Invalid box." end
    if tB[targetSlot] then
      local partyMon = save.party[sourceSlot]
      local boxMon = tB[targetSlot]
      if not partyMon or not boxMon then return false, "Invalid slot." end
      save.party[sourceSlot] = boxMon
      tB[targetSlot] = partyMon
      return true
    else
      return self:depositMon(sourceSlot, targetBoxId, targetSlot)
    end
  elseif sourceLoc == "box" and targetLoc == "party" then
    local sB = Gen2Boxes.box(save, sourceBoxId or save.currentBox or 1)
    if not sB then return false, "Invalid box." end
    if save.party[targetSlot] then
      local boxMon = sB[sourceSlot]
      local partyMon = save.party[targetSlot]
      if not boxMon or not partyMon then return false, "Invalid slot." end
      sB[sourceSlot] = partyMon
      save.party[targetSlot] = boxMon
      return true
    else
      return self:withdrawMon(sourceBoxId, sourceSlot, targetSlot)
    end
  end

  return false, "Unsupported swap operation."
end

function Gen2Adapter:releaseMon(loc, slot, boxId)
  local save = self.game and self.game.save
  if not save then return false, "No save." end
  if loc == "party" then
    return Gen2Boxes.releaseFromParty(save, slot)
  else
    local bId = boxId or save.currentBox or 1
    local box = Gen2Boxes.box(save, bId) or {}
    local mon = box[slot]
    if not mon then return false, "There is no POKéMON there." end
    box[slot] = nil
    return true, mon
  end
end

-- -------------------------------------------------------------------------
-- Item Storage Layer (Player PC)
-- -------------------------------------------------------------------------
function Gen2Adapter:getItemStorage()
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if okBag and Bag and Bag.pcRows and save then
    local rows = Bag.pcRows(save, data) or {}
    local res = {}
    for i, r in ipairs(rows) do
      local def = data and data.items and data.items[r.id]
      res[#res + 1] = {
        id = r.id,
        value = r.id,
        name = (def and def.name) or r.id,
        label = (def and def.name) or r.id,
        count = r.count or 1,
        slot = r.slot or i,
        def = def,
      }
    end
    return res
  end

  local pc = (save and save.pcItems) or {}
  local items = {}
  for id, count in pairs(pc) do
    if count and count > 0 then
      local def = data and data.items and data.items[id]
      items[#items + 1] = {
        id = id,
        value = id,
        name = (def and def.name) or id,
        label = (def and def.name) or id,
        count = count,
        slot = #items + 1,
        def = def,
      }
    end
  end
  table.sort(items, function(a, b) return a.name < b.name end)
  return items
end

function Gen2Adapter:getBagItems()
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if okBag and Bag and Bag.rows and save then
    local rows = Bag.rows(save, data) or {}
    local res = {}
    for i, r in ipairs(rows) do
      local def = data and data.items and data.items[r.id]
      res[#res + 1] = {
        id = r.id,
        value = r.id,
        name = (def and def.name) or r.id,
        label = (def and def.name) or r.id,
        count = r.count or 1,
        slot = r.slot or i,
        def = def,
      }
    end
    return res
  end

  local bag = (save and (save.inventory or save.bag or save.items)) or {}
  local items = {}
  if type(bag) == "table" then
    for id, count in pairs(bag) do
      if count and count > 0 then
        local def = data and data.items and data.items[id]
        items[#items + 1] = {
          id = id,
          value = id,
          name = (def and def.name) or id,
          label = (def and def.name) or id,
          count = count,
          slot = #items + 1,
          def = def,
        }
      end
    end
  end
  return items
end

function Gen2Adapter:withdrawItem(itemId, qty, slot)
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  if not save or not itemId then return false, "No save." end
  local amount = math.max(1, qty or 1)

  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if okBag and Bag and Bag.add and Bag.pcRemove then
    local ok = Bag.add(save, itemId, amount, data)
    if not ok then return false, "There's no room for more items in Bag." end
    Bag.pcRemove(save, itemId, amount, data, slot)
    return true
  end

  -- Fallback logic
  save.pcItems = save.pcItems or {}
  local stored = save.pcItems[itemId] or 0
  if stored < amount then return false, "Not enough in PC." end
  save.inventory = save.inventory or {}
  save.inventory[itemId] = (save.inventory[itemId] or 0) + amount
  save.pcItems[itemId] = stored - amount
  if save.pcItems[itemId] <= 0 then save.pcItems[itemId] = nil end
  return true
end

function Gen2Adapter:depositItem(itemId, qty, slot)
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  if not save or not itemId then return false, "No save." end
  local amount = math.max(1, qty or 1)

  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if okBag and Bag and Bag.pcAdd and Bag.remove then
    local ok = Bag.pcAdd(save, itemId, amount, data, 50)
    if not ok then return false, "PC Item storage is full (50 items)." end
    Bag.remove(save, itemId, amount, data, slot)
    return true
  end

  -- Fallback logic
  save.pcItems = save.pcItems or {}
  local pcCount = 0
  for _ in pairs(save.pcItems) do pcCount = pcCount + 1 end
  if not save.pcItems[itemId] and pcCount >= 50 then
    return false, "PC Item storage is full (50 items)."
  end
  save.inventory = save.inventory or {}
  local have = save.inventory[itemId] or 0
  if have < amount then return false, "Item not in Bag." end
  save.pcItems[itemId] = (save.pcItems[itemId] or 0) + amount
  save.inventory[itemId] = have - amount
  if save.inventory[itemId] <= 0 then save.inventory[itemId] = nil end
  return true
end

function Gen2Adapter:tossItem(itemId, qty, slot)
  local save = self.game and self.game.save
  local data = self.game and self.game.data
  if not save or not itemId then return false, "No save." end
  local amount = math.max(1, qty or 1)

  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if okBag and Bag and Bag.pcRemove then
    Bag.pcRemove(save, itemId, amount, data, slot)
    return true
  end

  save.pcItems = save.pcItems or {}
  local stored = save.pcItems[itemId] or 0
  if stored < amount then return false, "Not enough in PC." end
  save.pcItems[itemId] = stored - amount
  if save.pcItems[itemId] <= 0 then save.pcItems[itemId] = nil end
  return true
end

function Gen2Adapter:getBagCapacity()
  local data = self.game and self.game.data or (require("src.core.Data"))
  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if okBag and Bag and Bag.capacity then
    local itemCap = Bag.capacity(data, "ITEM") or 20
    local ballCap = Bag.capacity(data, "BALL") or 12
    local keyCap = Bag.capacity(data, "KEY_ITEM") or 25
    local tmCap = Bag.capacity(data, "TM_HM") or 57
    return itemCap + ballCap + keyCap + tmCap
  end
  if data and data.constants and data.constants.bagSize then
    return math.floor(data.constants.bagSize)
  end
  return 114
end

function Gen2Adapter:getPcCapacity()
  local data = self.game and self.game.data or (require("src.core.Data"))
  if data and data.field and data.field.pcItemCap then
    return data.field.pcItemCap
  end
  if data and data.constants and data.constants.pcItemCap then
    return data.constants.pcItemCap
  end
  return 50
end

function Gen2Adapter:getDexEntry(speciesId)
  local data = self.game and self.game.data or {}
  local pokemon = data.pokemon or {}
  local def = pokemon[speciesId]
  if not def and type(speciesId) == "number" then
    for k, d in pairs(pokemon) do
      if type(d) == "table" and d.dex == speciesId then
        def = d
        speciesId = k
        break
      end
    end
  end

  local dexData = data.gen2Pokedex or data.pokedex or {}
  local entry = dexData.entries and (dexData.entries[speciesId] or (def and dexData.entries[def.id]) or (def and dexData.entries[def.species])) or (def and def.dexEntry) or {}

  local dexNum = (entry and entry.dex) or (def and def.dex) or (type(speciesId) == "number" and speciesId) or 1
  local name = (def and (def.name or def.species)) or tostring(speciesId or "POKÉMON"):upper()
  local kind = (entry and entry.kind) or (def and (def.kind or (def.dexEntry and def.dexEntry.kind))) or ""

  local rawTypes = (def and def.types) or { "NORMAL" }
  local types = {}
  local seenTypes = {}
  for _, t in ipairs(rawTypes) do
    local clean = tostring(t):upper():gsub("_TYPE$", "")
    if clean ~= "" and not seenTypes[clean] then
      seenTypes[clean] = true
      types[#types + 1] = clean
    end
  end
  if #types == 0 then types = { "NORMAL" } end

  -- Format Gen 2 Height (e.g. 204 -> 2'04", 607 -> 6'07", or standard heightFt/heightIn)
  local heightStr = "---"
  if entry.heightFt ~= nil then
    heightStr = ("%d'%02d\""):format(entry.heightFt or 0, entry.heightIn or 0)
  elseif entry.heightM ~= nil then
    heightStr = ("%.1f m"):format(entry.heightM)
  elseif type(entry.height) == "number" then
    if entry.height >= 100 then
      local ft = math.floor(entry.height / 100)
      local inch = entry.height % 100
      heightStr = ("%d'%02d\""):format(ft, inch)
    else
      local ft = math.floor(entry.height / 12)
      local inch = entry.height % 12
      heightStr = ("%d'%02d\""):format(ft, inch)
    end
  end

  -- Format Gen 2 Weight (e.g. 141 -> 14.1 lbs, 60 -> 6.0 lbs, 1880 -> 188.0 lbs)
  local weightStr = "---"
  if entry.weightKg ~= nil then
    weightStr = ("%.1f kg"):format(entry.weightKg)
  elseif type(entry.weight) == "number" then
    weightStr = ("%.1f lbs"):format(entry.weight / 10)
  end

  -- Format Gen 2 multi-page description (text + text2)
  local desc = nil
  if entry.text or entry.text2 then
    local t1 = tostring(entry.text or ""):gsub("<NEXT>", " ")
    local t2 = tostring(entry.text2 or ""):gsub("<NEXT>", " ")
    local combined = (t1 .. " " .. t2):gsub("[\f\v\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    if combined and #combined > 0 then desc = combined end
  end
  if not desc and entry.description then
    desc = entry.description
  end
  if not desc and entry.text and data.text then
    desc = data.text[entry.text]
  end
  if not desc and def and def.description then
    desc = def.description
  end
  if type(desc) == "table" then desc = table.concat(desc, " ") end
  desc = tostring(desc or "A wild POKÉMON discovered across the region."):gsub("[\f\v\n]+", " "):gsub("%s+", " ")

  return {
    species = speciesId,
    dex = dexNum,
    name = name,
    types = types,
    kind = kind,
    height = heightStr,
    weight = weightStr,
    description = desc,
    def = def,
  }
end

function Gen2Adapter:getAreaInfo(speciesId, requestedRegion)
  local data = self.game and self.game.data or {}
  local save = self.game and self.game.save or {}
  local pokemon = data.pokemon or {}

  local def = pokemon[speciesId]
  local canonicalSpecies = speciesId
  if not def and type(speciesId) == "number" then
    for k, d in pairs(pokemon) do
      if type(d) == "table" and d.dex == speciesId then
        def = d
        canonicalSpecies = (type(k) == "string" and k) or d.species or d.name
        break
      end
    end
  elseif def then
    canonicalSpecies = (type(speciesId) == "string" and speciesId) or def.species or def.name or def.id or speciesId
  end

  local okHof, HallOfFame = pcall(require, "src.core.gen2.HallOfFame")
  local isKantoUnlocked = not not ((okHof and HallOfFame and HallOfFame.hasEntered(save))
    or (save.kantoBadges and #save.kantoBadges > 0)
    or (save.hasVisitedKanto == true)
    or (save.johtoBadges and #save.johtoBadges >= 8))

  local activeRegion = (requestedRegion == "kanto" and isKantoUnlocked) and "kanto" or "johto"

  local okNests, Nests = pcall(require, "src.core.gen2.Nests")
  local nests = {}
  if okNests and Nests and Nests.find then
    local landmarkIndices = Nests.find(data, canonicalSpecies, activeRegion, save)
    for _, idx in ipairs(landmarkIndices) do
      local mark = Nests.landmark(data, idx)
      if mark then
        local rawName = mark.name or ("LANDMARK " .. idx)
        local flatName = tostring(rawName):gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
        nests[#nests + 1] = {
          id = idx,
          name = flatName or rawName,
          x = mark.x,
          y = mark.y,
          landmark = idx,
        }
      end
    end
  end

  return {
    region = activeRegion,
    canSwapRegion = isKantoUnlocked,
    availableRegions = isKantoUnlocked and { "johto", "kanto" } or { "johto" },
    nests = nests,
  }
end

--- Attaches dialogue controls for Gen 2: native TextBox is fully self-contained.
function Gen2Adapter:attachDialogueControls(state)
  if not state or state.isTextBox then return end
  return BaseAdapter.attachDialogueControls(self, state)
end

return Gen2Adapter
