-- OmniUI Gen 3 Adapter (FireRed / LeafGreen / Emerald)
-- Bridges Gen 3 abilities, natures, contest stats, ribbons, and bags.

local BaseAdapter = require("mods.omni_ui.adapters.BaseAdapter")

local Gen3Adapter = setmetatable({}, { __index = BaseAdapter })
Gen3Adapter.__index = Gen3Adapter

function Gen3Adapter.new(game)
  local self = BaseAdapter.new(game)
  self.generation = 3
  local version = game and (game.gameVersion or (game.cart and game.cart.gameVersion) or game.version or (game.save and game.save.version))
  local session = game and (game.session or (game.save and game.save.session))
  local gameCode = session and (session.gameCode or session.game_code)
  local okGV, GV = pcall(require, "src.core.GameVersion")
  if okGV and GV and GV.get and (not version or version == "") then
    version = GV.get()
  end
  local isHoenn = false
  if version and version ~= "" then
    local v = version:lower()
    if v == "emerald" or v == "ruby" or v == "sapphire" then
      isHoenn = true
    elseif v == "firered" or v == "leafgreen" then
      isHoenn = false
    end
  else
    isHoenn = (gameCode and (gameCode == "BPEE" or gameCode == "AXVE" or gameCode == "AXPE"))
      or (session and session.region == "HOENN")
      or (game and game.region == "HOENN")
      or (package and package.loaded and package.loaded["src.ui.game3.rse.pokedex"] and package.loaded["src.ui.game3.rse.pokedex"].active and package.loaded["src.ui.game3.rse.pokedex"].active() ~= nil)
  end
  if isHoenn then
    self.region = "HOENN"
  else
    self.region = "KANTO"
  end
  setmetatable(self, Gen3Adapter)
  return self
end

local function gen3MoveNumber(moveRef)
  local id = moveRef
  if type(moveRef) == "table" then
    id = moveRef.moveId or moveRef.id or moveRef.move or moveRef[1]
  end
  local num = tonumber(id)
  if num and num > 0 then return num end
  if type(id) ~= "string" or id == "" then return nil end
  local ok, Moves = pcall(require, "src.core.game3.battle.moves")
  if ok and Moves and Moves.numForName then
    return tonumber(Moves.numForName(id))
  end
  return nil
end

local function gen3BasePp(moveRef)
  local num = gen3MoveNumber(moveRef)
  if not num then return nil end
  local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
  if ok and Pokemon and Pokemon.movePp then
    local pp = tonumber(Pokemon.movePp(num))
    if pp and pp > 0 then return pp end
  end
  local okM, Moves = pcall(require, "src.core.game3.battle.moves")
  if okM and Moves and Moves.get then
    local okG, def = pcall(Moves.get, num)
    if okG and type(def) == "table" then
      local pp = tonumber(def.pp)
      if pp and pp > 0 then return pp end
    end
  end
  return nil
end

--- Current and max PP for one Gen 3 move slot. Party and battle mons keep PP
--- in parallel arrays; the move id itself is not a Gen 1 move record.
function Gen3Adapter.resolveMovePp(mon, index, moveRef)
  index = tonumber(index) or 1
  local base = gen3BasePp(moveRef)
  local bonus = 0
  if type(mon) == "table" then
    if type(mon.ppBonuses) == "table" and mon.ppBonuses[index] ~= nil then
      bonus = tonumber(mon.ppBonuses[index]) or 0
    else
      local packed = tonumber(mon.ppBonusesPacked or mon.ppBonus) or 0
      bonus = math.floor(packed / (4 ^ (index - 1))) % 4
    end
  end
  local maxPP = type(mon) == "table" and type(mon.maxPp) == "table" and tonumber(mon.maxPp[index]) or nil
  if not maxPP or maxPP <= 0 then
    if base and base > 0 then
      maxPP = base + math.floor(base * 20 * bonus / 100)
    else
      maxPP = 0
    end
  end
  local cur = nil
  if type(mon) == "table" and type(mon.pp) == "table" and mon.pp[index] ~= nil then
    cur = tonumber(mon.pp[index])
  end
  if cur == nil and type(moveRef) == "table" and moveRef.pp ~= nil then
    cur = tonumber(moveRef.pp)
  end
  if cur == nil or (cur == 0 and maxPP > 0 and not (type(mon) == "table" and type(mon.pp) == "table" and mon.pp[index] ~= nil)) then
    cur = maxPP
  end
  if maxPP <= 0 and cur and cur > 0 then maxPP = cur end
  return cur or 0, maxPP or 0
end

local GEN3_NATURES = {
  "HARDY", "LONELY", "BRAVE", "ADAMANT", "NAUGHTY",
  "BOLD", "DOCILE", "RELAXED", "IMPISH", "LAX",
  "TIMID", "HASTY", "SERIOUS", "JOLLY", "NAIVE",
  "MODEST", "MILD", "QUIET", "BASHFUL", "RASH",
  "CALM", "GENTLE", "SASSY", "CAREFUL", "QUIRKY",
}

local GEN3_TYPES = {
  [0]  = "NORMAL",
  [1]  = "FIGHTING",
  [2]  = "FLYING",
  [3]  = "POISON",
  [4]  = "GROUND",
  [5]  = "ROCK",
  [6]  = "BUG",
  [7]  = "GHOST",
  [8]  = "STEEL",
  [9]  = "???",
  [10] = "FIRE",
  [11] = "WATER",
  [12] = "GRASS",
  [13] = "ELECTRIC",
  [14] = "PSYCHIC",
  [15] = "ICE",
  [16] = "DRAGON",
  [17] = "DARK",
}

local GEN3_GROWTH_RATES = {
  [0] = "MEDIUM_FAST",
  [1] = "ERRATIC",
  [2] = "FLUCTUATING",
  [3] = "MEDIUM_SLOW",
  [4] = "FAST",
  [5] = "SLOW",
}

-- Nature stat deltas: [natureId] (0..24) -> boosted, lowered
local NATURE_STAT_BOOST = {
  [1] = "attack", [2] = "attack", [3] = "attack", [4] = "attack",
  [5] = "defense", [7] = "defense", [8] = "defense", [9] = "defense",
  [10] = "speed", [11] = "speed", [13] = "speed", [14] = "speed",
  [15] = "spAttack", [16] = "spAttack", [17] = "spAttack", [19] = "spAttack",
  [20] = "spDefense", [21] = "spDefense", [22] = "spDefense", [23] = "spDefense",
}

local NATURE_STAT_LOWER = {
  [1] = "defense", [2] = "speed", [3] = "spAttack", [4] = "spDefense",
  [5] = "attack", [7] = "speed", [8] = "spAttack", [9] = "spDefense",
  [10] = "attack", [11] = "defense", [13] = "spAttack", [14] = "spDefense",
  [15] = "attack", [16] = "defense", [17] = "speed", [19] = "spDefense",
  [20] = "attack", [21] = "defense", [22] = "speed", [23] = "spAttack",
}

local STAT_SHORT_KEYS = {
  attack = "atk",
  defense = "def",
  speed = "spe",
  spAttack = "spa",
  spDefense = "spd",
  hp = "hp",
}

local function getGen3MoveCategory(typeId, power, customCategory)
  if customCategory and (customCategory == "PHYSICAL" or customCategory == "SPECIAL" or customCategory == "STATUS") then
    return customCategory
  end
  if not power or power == 0 then
    return "STATUS"
  end
  local tid = tonumber(typeId) or 0
  if tid >= 0 and tid <= 8 then
    return "PHYSICAL"
  elseif tid >= 10 and tid <= 17 then
    return "SPECIAL"
  else
    return "STATUS"
  end
end

local function deriveUnownLetterGen3(pid)
  pid = tonumber(pid) or 0
  if type(bit) ~= "table" or not bit.band then return "A" end
  local b1 = bit.band(pid, 3)
  local b2 = bit.band(bit.rshift(pid, 8), 3)
  local b3 = bit.band(bit.rshift(pid, 16), 3)
  local b4 = bit.band(bit.rshift(pid, 24), 3)
  local formIdx = bit.bor(b1, bit.lshift(b2, 2), bit.lshift(b3, 4), bit.lshift(b4, 6)) % 28
  if formIdx < 26 then
    return string.char(65 + formIdx)
  elseif formIdx == 26 then
    return "!"
  else
    return "?"
  end
end

local function deriveDeoxysFormGen3(version)
  local v = tostring(version or ""):lower()
  if v:find("fire") then
    return 1 -- Attack Form
  elseif v:find("leaf") then
    return 2 -- Defense Form
  elseif v:find("emerald") then
    return 3 -- Speed Form
  else
    return 0 -- Normal Form (Ruby / Sapphire)
  end
end

local GEN3_FIELD_MOVES = {
  FLASH = true, CUT = true, FLY = true, STRENGTH = true,
  SURF = true, ROCK_SMASH = true, WATERFALL = true, DIVE = true,
  TELEPORT = true, DIG = true, MILK_DRINK = true, SOFTBOILED = true,
  SWEET_SCENT = true,
}

local function getGen3EggFlavor(cycles)
  cycles = tonumber(cycles) or 0
  if cycles < 6 then
    return "It's making sounds. It's almost ready to hatch!"
  elseif cycles < 11 then
    return "It moves occasionally. It should hatch soon."
  elseif cycles < 41 then
    return "What will hatch from this? It will take some time."
  else
    return "An odd POKéMON EGG found by the DAY-CARE couple."
  end
end

local function isGen3Shiny(mon)
  if not mon then return false end
  if mon.isShiny ~= nil then return mon.isShiny == true end
  local pid = tonumber(mon.personality or mon.pid) or 0
  local full = tonumber(mon.otId or mon.trainerId or mon.id) or 0
  local otId = full % 65536
  local rawSid = tonumber(mon.otSecretId or mon.secretId or mon.sid)
  local secretId = rawSid and (rawSid % 65536) or (math.floor(full / 65536) % 65536)
  if type(bit) == "table" and bit.bxor then
    local pLow = pid % 65536
    local pHigh = math.floor(pid / 65536) % 65536
    local trainerXor = bit.bxor(otId, secretId)
    local pidXor = bit.bxor(pHigh, pLow)
    return bit.bxor(trainerXor, pidXor) < 8
  end
  local okSummary, SummaryData = pcall(require, "src.core.game3.summary_data")
  if okSummary and SummaryData and SummaryData.isShiny then
    local okS, s = pcall(SummaryData.isShiny, mon)
    if okS and s ~= nil then return s == true end
  end
  return false
end

function Gen3Adapter:getSession()
  local session = (self.game and self.game.session)
    or (type(self.game) == "table" and self.game._session)
    or (self.game and self.game.save and self.game.save.session)
  if not session then
    local BagMenu = package.loaded["src.ui.game3.bag_menu"] or package.loaded["src.ui.game3.rse.bag_menu"]
    if BagMenu and BagMenu._session then
      session = BagMenu._session
    end
  end
  if not session then
    local ItemPc = package.loaded["src.ui.game3.item_pc"]
    if ItemPc and ItemPc._session then
      session = ItemPc._session
    end
  end
  if not session then
    local RseItemStorage = package.loaded["src.ui.game3.rse.item_storage"]
    if RseItemStorage and RseItemStorage._session then
      session = RseItemStorage._session
    end
  end
  if not session then
    local PartyMenu = package.loaded["src.ui.game3.party_menu"]
    if PartyMenu and PartyMenu._session then
      session = PartyMenu._session
    end
  end
  if not session then
    local RsePokedex = package.loaded["src.ui.game3.rse.pokedex"]
    if RsePokedex and RsePokedex.active and RsePokedex.active() then
      local s = RsePokedex.active()
      if s and s.session then session = s.session end
    end
  end
  if not session then
    local BoxStorageUI = package.loaded["src.ui.game3.box_storage_ui"]
    if BoxStorageUI and BoxStorageUI._session then
      session = BoxStorageUI._session
    end
  end
  if not session then
    local PcMenu = package.loaded["src.ui.game3.pc_menu"]
    if PcMenu and PcMenu._session then
      session = PcMenu._session
    end
  end
  if not session then
    local okRt, Rt = pcall(require, "src.core.game3.runtime")
    if okRt and Rt then
      if Rt.getSession then session = Rt.getSession() end
      if not session and Rt.session then session = Rt.session end
    end
  end
  return session
end

function Gen3Adapter:getPartyData()
  return self:getParty()
end

function Gen3Adapter:getParty()
  local session = self:getSession()
  local party = (session and session.party)
    or (package.loaded["src.ui.game3.party_menu"] and package.loaded["src.ui.game3.party_menu"]._party)
    or (self.game and self.game.save and self.game.save.party)
    or {}
  local list = {}
  for i, mon in ipairs(party) do
    list[#list + 1] = self:normalizeMon(mon, i)
  end
  return list
end

function Gen3Adapter:getMon(index)
  local session = self:getSession()
  local party = (session and session.party)
    or (package.loaded["src.ui.game3.party_menu"] and package.loaded["src.ui.game3.party_menu"]._party)
    or (self.game and self.game.save and self.game.save.party)
    or {}
  local mon = party[index]
  return mon and self:normalizeMon(mon, index) or nil
end

function Gen3Adapter:normalizeMon(mon, index)
  if not mon then return nil end
  if mon.normalized == true then return mon end

  -- Immediate guard: SPECIES_NONE / empty slot
  local rawSpecies = mon.species or mon.speciesId
  if (not rawSpecies or rawSpecies == 0 or rawSpecies == "0") and not mon.isEgg then
    return nil
  end

  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  local isRawEgg = (mon.isEgg == true)
    or (mon.species == "EGG" or mon.species == 253 or mon.species == "Egg" or mon.species == 412)
    or (mon.name == "POKéMON EGG" or (mon.name == "EGG" and mon.level == nil))
    or (okP and Pokemon and Pokemon.isEgg and Pokemon.isEgg(mon))

  local speciesNum = tonumber(mon.species or mon.speciesId)
  if not speciesNum and okP and Pokemon and Pokemon.speciesOf then
    speciesNum = Pokemon.speciesOf(mon)
  end
  if not speciesNum and mon.raw then
    speciesNum = tonumber(mon.raw.species or mon.raw.speciesId)
  end

  -- 1. Egg Masking Contract
  if isRawEgg then
    local cycles = tonumber(mon.eggCycles or mon.eggSteps or mon.friendship or mon.happiness or 0) or 0
    return {
      index = index or mon.index or 1,
      normalized = true,
      isEgg = true,
      eggCycles = cycles,
      eggFlavorText = getGen3EggFlavor(cycles),
      species = 412,
      speciesId = 412,
      speciesName = "POKéMON EGG",
      name = "POKéMON EGG",
      displayName = "POKéMON EGG",
      nickname = "POKéMON EGG",
      level = nil,
      hp = 0,
      currentHp = 0,
      maxHp = 0,
      types = {},
      status = nil,
      gender = nil,
      heldItem = nil,
      isShiny = false,
      stats = { hp = 0, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0, atk = 0, def = 0, spa = 0, spd = 0, spe = 0 },
      moves = {},
      fieldMoves = {},
      otName = mon.otName or mon.ot or "DAY-CARE",
      otId = tonumber(mon.otId or mon.id) or 0,
      exp = 0,
      happiness = cycles,
      raw = mon,
    }
  end

  local okSummary, SummaryData = pcall(require, "src.core.game3.summary_data")
  local data = self.game and self.game.data
  local pid = tonumber(mon.personality or mon.pid) or 0

  local norm = {}
  norm.index = index or mon.index or 1
  norm.raw = mon
  norm.normalized = true

  -- 2. Species Name & Nickname Resolution
  local defaultName = nil
  if speciesNum and okP and Pokemon and Pokemon.name then
    local okN, n = pcall(Pokemon.name, speciesNum)
    if okN and n and n ~= "" then defaultName = n end
  end
  if not defaultName and mon.name and mon.name ~= "" and type(mon.name) == "string" then
    defaultName = mon.name
  end
  if not defaultName then
    defaultName = tostring(speciesNum or mon.species or "POKÉMON")
  end

  local nick = defaultName
  if mon.nickname and type(mon.nickname) == "string" and mon.nickname ~= "" and mon.nickname ~= defaultName then
    nick = mon.nickname
  end

  norm.species = speciesNum or mon.species or "UNKNOWN"
  norm.speciesId = norm.species
  norm.speciesName = defaultName
  norm.displayName = nick
  norm.nickname = nick
  norm.name = nick

  -- 3. Canonical Types Translation & Deduplication
  local t1Str, t2Str = nil, nil
  if speciesNum and okP and Pokemon and Pokemon.types then
    local okT, t = pcall(Pokemon.types, speciesNum)
    if okT and type(t) == "table" and #t > 0 then
      local t1Num = tonumber(t[1]) or 0
      local t2Num = tonumber(t[2]) or t1Num
      t1Str = GEN3_TYPES[t1Num] or "NORMAL"
      t2Str = GEN3_TYPES[t2Num] or t1Str
    end
  end
  if not t1Str and mon.types and type(mon.types) == "table" and #mon.types > 0 then
    local t1 = mon.types[1]
    local t2 = mon.types[2] or t1
    t1Str = type(t1) == "number" and (GEN3_TYPES[t1] or "NORMAL") or tostring(t1):upper()
    t2Str = type(t2) == "number" and (GEN3_TYPES[t2] or t1Str) or tostring(t2):upper()
  end
  t1Str = t1Str or "NORMAL"
  t2Str = t2Str or t1Str
  if t1Str == t2Str then
    norm.types = { t1Str }
  else
    norm.types = { t1Str, t2Str }
  end

  -- 4. Held Item
  local rawItem = mon.heldItem or mon.item or mon.held_item
  if rawItem and rawItem ~= 0 and rawItem ~= "" then
    local okItemsData, ItemsData = pcall(require, "src.core.game3.items_data")
    if okItemsData and ItemsData then
      if type(rawItem) == "number" then
        norm.heldItem = ItemsData.displayName(rawItem) or ItemsData.keyOf(rawItem) or tostring(rawItem)
      else
        norm.heldItem = tostring(rawItem)
      end
    else
      norm.heldItem = tostring(rawItem)
    end
  else
    norm.heldItem = nil
  end

  -- 5. Nature & Dual-Key Stat Modifiers
  local natureId = (pid % 25)
  local natureName = GEN3_NATURES[natureId + 1] or "HARDY"
  if mon.nature and type(mon.nature) == "string" and mon.nature ~= "" then
    natureName = tostring(mon.nature):upper()
    for idx, nName in ipairs(GEN3_NATURES) do
      if nName == natureName then natureId = idx - 1; break end
    end
  end
  local boosted = NATURE_STAT_BOOST[natureId]
  local lowered = NATURE_STAT_LOWER[natureId]
  norm.nature = natureName
  norm.natureBoosted = boosted
  norm.natureLowered = lowered
  norm.natureData = {
    name = natureName,
    id = natureId,
    boosted = boosted,
    lowered = lowered,
    boostedShort = STAT_SHORT_KEYS[boosted],
    loweredShort = STAT_SHORT_KEYS[lowered],
  }

  -- 6. Shininess (32-bit PID XOR)
  norm.isShiny = isGen3Shiny(mon)

  -- 7. Ability Name & Description
  local abilityId = tonumber(mon.abilityId)
  local abilityName = nil
  if not abilityId and okP and Pokemon and Pokemon.abilityId and speciesNum then
    local okAid, aId = pcall(Pokemon.abilityId, speciesNum, pid)
    if okAid and aId and aId > 0 then abilityId = aId end
  end
  if abilityId and okP and Pokemon and Pokemon.abilityName then
    local okAn, aName = pcall(Pokemon.abilityName, abilityId)
    if okAn and aName and aName ~= "" and aName ~= "-------" then
      abilityName = tostring(aName)
    end
  end
  if not abilityName and mon.ability and tostring(mon.ability) ~= "" and tostring(mon.ability) ~= "0" then
    abilityName = tostring(mon.ability)
  end
  if not abilityName and data and data.pokemon and data.pokemon[norm.species] then
    local pDef = data.pokemon[norm.species]
    abilityName = pDef.ability or (pDef.abilities and pDef.abilities[1])
  end
  norm.ability = abilityName
  norm.abilityId = abilityId
  if okSummary and SummaryData and SummaryData.abilityDescription and abilityId and abilityName then
    norm.abilityDesc = SummaryData.abilityDescription(abilityId, abilityName)
  end

  -- 8. Gender (PID Threshold Check via ROM Gender Ratio)
  local gender = nil
  local ratio = nil
  if speciesNum and okP and Pokemon then
    if Pokemon.genderRatio then
      local okGr, gr = pcall(Pokemon.genderRatio, speciesNum)
      if okGr and gr ~= nil then ratio = tonumber(gr) end
    end
    if ratio == nil and Pokemon.speciesMeta then
      local meta = Pokemon.speciesMeta(speciesNum)
      if meta and meta.genderRatio ~= nil then ratio = tonumber(meta.genderRatio) end
    end
  end

  if ratio ~= nil then
    if ratio == 255 or ratio == 0xFF then
      gender = nil
    elseif ratio == 254 or ratio == 0xFE then
      gender = "F"
    elseif ratio == 0 or ratio == 0x00 then
      gender = "M"
    else
      local pidByte = pid % 256
      if pidByte >= ratio then
        gender = "M"
      else
        gender = "F"
      end
    end
  elseif mon.gender ~= nil then
    if mon.gender == "M" or mon.gender == "MALE" or mon.gender == 0 then
      gender = "M"
    elseif mon.gender == "F" or mon.gender == "FEMALE" or mon.gender == 1 then
      gender = "F"
    end
  elseif okP and Pokemon and Pokemon.gender and speciesNum then
    local okG, g = pcall(Pokemon.gender, speciesNum, pid)
    if okG and g ~= nil then
      gender = (g == "M" or g == 0 or g == "MALE") and "M" or ((g == "F" or g == 1 or g == "FEMALE") and "F" or nil)
    end
  elseif okSummary and SummaryData and SummaryData.gender then
    local g = SummaryData.gender(mon)
    gender = (g == "M" or g == "MALE") and "M" or ((g == "F" or g == "FEMALE") and "F" or nil)
  end
  norm.gender = gender
  norm.genderFull = gender == "M" and "MALE" or (gender == "F" and "FEMALE" or nil)

  -- 9. Form Derivation (Unown PID / Deoxys Game Version)
  if speciesNum == 201 then
    norm.form = deriveUnownLetterGen3(pid)
  elseif speciesNum == 386 or speciesNum == 410 then
    local v = (self.game and self.game.gameVersion) or (self.region == "HOENN" and "emerald" or "firered")
    local fId = deriveDeoxysFormGen3(v)
    norm.form = (fId == 1 and "Attack") or (fId == 2 and "Defense") or (fId == 3 and "Speed") or "Normal"
  else
    norm.form = mon.form
  end

  -- 10. Growth Rate, Level & BoxPokemon Dynamic Stat Reconstruction
  local growthRateIdx = (okP and Pokemon and Pokemon.growthRate and speciesNum and Pokemon.growthRate(speciesNum)) or 0
  local growthRate = GEN3_GROWTH_RATES[growthRateIdx] or "MEDIUM_FAST"
  norm.growthRate = growthRate

  local curExp = tonumber(mon.exp) or 0
  local level = tonumber(mon.level)
  if not level or level < 1 then
    if okSummary and SummaryData and SummaryData.expForLevel then
      level = 1
      while level <= 100 and SummaryData.expForLevel(growthRateIdx, level) <= curExp do
        level = level + 1
      end
      level = math.max(1, level - 1)
    else
      level = 1
    end
  end
  norm.level = level
  norm.exp = curExp

  if okSummary and SummaryData and SummaryData.expProgress then
    local prog = SummaryData.expProgress(mon, growthRateIdx)
    norm.expProgress = prog.expProgress
    norm.expNeeded = prog.expNeeded
    norm.expNext = prog.nextLevelExp
    norm.curLevelExp = prog.curLevelExp
    norm.expPercent = prog.progressPercent
  end

  if okP and Pokemon and Pokemon.expYield and speciesNum then
    norm.baseExp = Pokemon.expYield(speciesNum)
  end

  local mStats = mon.stats
  if mStats and (mStats.attack or mStats.atk or mStats.hp) then
    local hpVal = tonumber(mStats.hp or mon.maxHp or mon.hp or 1) or 1
    local atkVal = tonumber(mStats.attack or mStats.atk or 0) or 0
    local defVal = tonumber(mStats.defense or mStats.def or 0) or 0
    local spaVal = tonumber(mStats.spAttack or mStats.spAtk or mStats.specialAttack or mStats.special or 0) or 0
    local spdVal = tonumber(mStats.spDefense or mStats.spDef or mStats.specialDefense or mStats.special or 0) or 0
    local speVal = tonumber(mStats.speed or mStats.spe or 0) or 0
    norm.stats = {
      hp = hpVal,
      attack = atkVal, atk = atkVal,
      defense = defVal, def = defVal,
      spAttack = spaVal, spa = spaVal, spAtk = spaVal,
      spDefense = spdVal, spd = spdVal, spDef = spdVal,
      speed = speVal, spe = speVal,
    }
    norm.maxHp = tonumber(mon.maxHp) or hpVal or 1
    local cur = tonumber(mon.hp)
    if cur == nil then cur = tonumber(mon.currentHp) end
    norm.currentHp = cur or norm.maxHp
    norm.hp = norm.currentHp
  elseif okP and Pokemon and Pokemon.calcStats and speciesNum then
    local ivs = mon.ivs or {}
    local evs = mon.evs or {}
    local st = Pokemon.calcStats(speciesNum, level, ivs, evs, pid)
    norm.stats = {
      hp = st.maxHp,
      attack = st.attack, atk = st.attack,
      defense = st.defense, def = st.defense,
      spAttack = st.spAtk, spa = st.spAtk, spAtk = st.spAtk,
      spDefense = st.spDef, spd = st.spDef, spDef = st.spDef,
      speed = st.speed, spe = st.speed,
    }
    norm.maxHp = st.maxHp
    local cur = tonumber(mon.hp)
    if cur == nil then cur = tonumber(mon.currentHp) end
    norm.currentHp = cur or st.maxHp
    norm.hp = norm.currentHp
  else
    norm.stats = {
      hp = 1, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0,
      atk = 0, def = 0, spa = 0, spd = 0, spe = 0,
    }
    norm.maxHp = 1
    norm.currentHp = 1
    norm.hp = 1
  end

  -- 11. Status Ailment & Pokérus
  if okSummary and SummaryData and SummaryData.statusAilment then
    local code = SummaryData.statusAilment(mon)
    local CODE_NAMES = { [1] = "PSN", [2] = "PRZ", [3] = "SLP", [4] = "FRZ", [5] = "BRN", [6] = "PKRS", [7] = "FNT" }
    norm.status = CODE_NAMES[code]
  elseif mon.status then
    norm.status = tostring(mon.status):upper()
  end
  if okP and Pokemon and Pokemon.hasPokerus and Pokemon.hasHadPokerus then
    if Pokemon.hasPokerus(mon) then
      norm.pokerus = "infected"
    elseif Pokemon.hasHadPokerus(mon) then
      norm.pokerus = "cured"
    end
  end

  -- 12. Moves Normalization (Integer Max PP Math + Pre-Gen 4 Category)
  norm.moves = {}
  norm.fieldMoves = {}
  local G3Field = package.loaded["src.world.game3.field_moves"]

  for idx, mv in ipairs(mon.moves or {}) do
    local mId = (type(mv) == "table" and (mv.id or mv.name or mv.moveId or mv.move)) or mv
    if mId and tostring(mId) ~= "" and mId ~= 0 and mId ~= "-------" then
      local mNum = tonumber(mId)
      local bMove = (okP and Pokemon and Pokemon.battleMove and mNum and Pokemon.battleMove(mNum)) or {}
      local mName = nil
      if okP and Pokemon and Pokemon.moveName then
        mName = Pokemon.moveName(mId)
      end
      if not mName or mName == "" or mName:find("^MOVE ") then
        if type(mId) == "string" then mName = mId:gsub("_", " ") else mName = tostring(mId) end
      end
      local uId = tostring(mName):upper():gsub("%s+", "_")

      local curPP, maxPP = Gen3Adapter.resolveMovePp(mon, idx, mNum or mv)

      local moveTypeNum = tonumber(bMove.type or (type(mv) == "table" and mv.type))
      if not moveTypeNum and type(mv) == "table" and type(mv.type) == "string" then
        for tIdx, tName in pairs(GEN3_TYPES) do
          if tName == mv.type:upper() then moveTypeNum = tIdx; break end
        end
      end
      moveTypeNum = moveTypeNum or 0
      local moveTypeStr = GEN3_TYPES[moveTypeNum] or "NORMAL"
      local pwr = tonumber(bMove.power or (type(mv) == "table" and mv.power)) or 0
      local acc = tonumber(bMove.accuracy or (type(mv) == "table" and mv.accuracy)) or 100
      local customCat = type(mv) == "table" and mv.category
      local category = getGen3MoveCategory(moveTypeNum, pwr, customCat)

      local desc = nil
      if okSummary and SummaryData and SummaryData.moveDescription and mNum then
        desc = SummaryData.moveDescription(mNum, mName)
      end

      local slotMove = {
        id = uId,
        name = mName,
        type = moveTypeStr,
        typeId = moveTypeNum,
        pp = curPP,
        maxPP = maxPP,
        maxPp = maxPP,
        power = pwr,
        accuracy = acc,
        category = category,
        desc = desc,
        raw = mv,
      }
      norm.moves[#norm.moves + 1] = slotMove

      if GEN3_FIELD_MOVES[uId] or (G3Field and G3Field.isFieldMove and G3Field.isFieldMove(uId)) then
        norm.fieldMoves[#norm.fieldMoves + 1] = uId
      end
    end
  end

  -- 13. OT & Trainer Memo
  local session = self:getSession()
  norm.otName = mon.otName or mon.ot or (session and (session.playerName or session.name)) or "TRAINER"
  local rawOtId = tonumber(mon.otId or mon.id) or 0
  norm.otId = rawOtId % 65536
  norm.trainerId = norm.otId
  norm.metLevel = mon.metLevel or mon.caughtLevel or 0

  local metLoc = mon.metLocation or mon.met or mon.caughtLocation or mon.location
  norm.metLocation = metLoc
  if okSummary and SummaryData and SummaryData.formatTrainerMemo then
    local okMemo, memoLines = pcall(SummaryData.formatTrainerMemo, mon, session)
    if okMemo and type(memoLines) == "table" and #memoLines > 0 then
      norm.originDesc = table.concat(memoLines, " ")
    end
  end
  if not norm.originDesc or norm.originDesc == "" then
    if norm.metLocation then
      if norm.metLevel and norm.metLevel > 0 then
        norm.originDesc = ("Met at %s (Lv. %d)"):format(tostring(norm.metLocation), tonumber(norm.metLevel))
      else
        norm.originDesc = ("Met at %s"):format(tostring(norm.metLocation))
      end
    else
      norm.originDesc = ("%s nature."):format(norm.nature or "Hardy")
    end
  end

  local okRibbons, Ribbons = pcall(require, "src.core.game3.rse.ribbons")
  if okRibbons and Ribbons and Ribbons.count then
    norm.ribbons = Ribbons.count(mon)
  end

  return norm
end

function Gen3Adapter:getPlayerInfo()
  local info = BaseAdapter.getPlayerInfo(self)
  local session = self:getSession()
  
  if session then
    if session.playerName or session.name then info.name = session.playerName or session.name end
    if session.trainerId or session.id then info.id = session.trainerId or session.id end
    if session.money then info.money = session.money end
    if session.gender ~= nil then info.gender = (session.gender == 0 or session.gender == "MALE") and "MALE" or "FEMALE" end

    -- Play time
    if session.playHours ~= nil or session.playMinutes ~= nil then
      local h = tonumber(session.playHours) or 0
      local m = tonumber(session.playMinutes) or 0
      local s = tonumber(session.playSeconds) or 0
      info.playTime = { hours = h, minutes = m, seconds = s, totalSeconds = h * 3600 + m * 60 + s }
      info.playTimeString = ("%02d:%02d"):format(h, m)
    end
  end

  local okFlags, Flags = pcall(require, "src.core.game3.scripting.flags")
  if okFlags and Flags and Flags.countBadges then
    local okSave, SaveMenu = pcall(require, "src.ui.game3.save_menu")
    if okSave and SaveMenu and SaveMenu.flagStore then
      local okCount, bCount = pcall(Flags.countBadges, SaveMenu.flagStore(session))
      if okCount and type(bCount) == "number" then info.badges = bCount end
    end
  end

  local okTC, G3TrainerCard = pcall(require, "src.ui.game3.trainer_card")
  if okTC and G3TrainerCard and G3TrainerCard.isBadgeUnlocked then
    info.badgeFlags = {}
    for i = 1, 8 do
      local okB, earned = pcall(G3TrainerCard.isBadgeUnlocked, i)
      info.badgeFlags[i] = (okB and earned == true)
    end
  end

  local ver = (self.game and self.game.gameVersion) or (session and session.version)
  if not ver then pcall(function() ver = require("src.core.GameVersion").get() end) end
  local isRse = (self.region == "HOENN") or (ver == "emerald" or ver == "ruby" or ver == "sapphire")
  info.gameVersion = ver
  info.maxBadges = 8
  info.region = isRse and "HOENN" or "KANTO"
  if isRse then
    info.badgeNames = { "STONE", "KNUCKLE", "DYNAMO", "HEAT", "BALANCE", "FEATHER", "MIND", "RAIN" }
  else
    info.badgeNames = { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH", "VOLCANO", "EARTH" }
  end

  info.pokedex = self:getPokedexCounts()

  local hasPlace = session and (session.map or session.mapName or session.currentMapSec or session.mapSec or session.regionMapSectionId)
  local okSave, SaveMenu = pcall(require, "src.ui.game3.save_menu")
  if hasPlace and okSave and SaveMenu and SaveMenu.locationName then
    local okLoc, place = pcall(SaveMenu.locationName, session)
    if okLoc and type(place) == "string" and place ~= "" then
      info.location = place
    end
  end

  return info
end

function Gen3Adapter:getSafariInfo()
  local session = self:getSession()
  local okSafari, Safari = pcall(require, "src.core.game3.safari")
  if okSafari and Safari and Safari.isActive and Safari.isActive(session) then
    local steps = Safari.steps and Safari.steps(session) or 0
    local balls = Safari.balls and Safari.balls(session) or 0
    return {
      active = true,
      steps = steps,
      maxSteps = Safari.STEPS or 500,
      balls = balls,
    }
  end
  return nil
end

function Gen3Adapter:getActiveBattle()
  local okBattle, Battle = pcall(require, "src.core.game3.battle")
  if okBattle and Battle and Battle.isActive and Battle.isActive() and Battle.getState then
    local st = Battle.getState()
    if st then
      local states = (self.game and self.game.stack and self.game.stack.states) or {}
      return st, states[#states]
    end
  end
  local BaseAdapter = require("mods.omni_ui.adapters.BaseAdapter")
  return BaseAdapter.getActiveBattle(self)
end

local function moveLabel(mId, mDef)
  if mDef and mDef.name then return mDef.name end
  if type(mId) == "string" then return (mId:gsub("_", " ")) end
  if mId == nil then return "--" end
  return tostring(mId)
end

--- Name, stats, and description for a Gen 3 move id. The battle mon stores the
--- number; the panels need the display name and a real description.
local function gen3MoveFacts(moveRef)
  local num = gen3MoveNumber(moveRef)
  local def
  if num then
    local okM, Moves = pcall(require, "src.core.game3.battle.moves")
    if okM and Moves and Moves.get then
      local okG, row = pcall(Moves.get, num)
      if okG and type(row) == "table" then def = row end
    end
  end

  local name
  if num then
    local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
    if okP and Pokemon and Pokemon.moveName then
      local okN, shown = pcall(Pokemon.moveName, num)
      if okN and type(shown) == "string" and shown ~= "" and shown ~= "-------" and not shown:find("^MOVE ") then
        name = shown
      end
    end
  end
  if (not name or name == "") and def and type(def.name) == "string" then
    local raw = def.name
    if raw ~= "" and not raw:find("%$") and raw ~= "-$$$$$$" then
      name = raw
    end
  end
  if not name or name == "" then
    name = moveLabel(type(moveRef) == "table" and (moveRef.id or moveRef.move) or moveRef, def)
  end

  local constId = tostring(name):upper():gsub("%s+", "_"):gsub("[^%w_]", "")
  local typeName = def and def.type
  if type(typeName) == "number" then
    typeName = GEN3_TYPES[typeName] or "NORMAL"
  elseif type(typeName) == "string" and typeName ~= "" then
    typeName = typeName:upper()
  else
    typeName = "NORMAL"
  end

  local desc
  if num then
    local okS, SummaryData = pcall(require, "src.core.game3.summary_data")
    if okS and SummaryData and SummaryData.moveDescription then
      local okD, text = pcall(SummaryData.moveDescription, num, name)
      if okD and type(text) == "string" then
        local clean = text:gsub("\n", " "):gsub("%s+", " ")
        if clean ~= "" and clean ~= "---" and clean ~= "--" then
          desc = clean
        end
      end
    end
  end

  return {
    id = (constId ~= "" and constId) or tostring(num or moveRef or ""),
    name = name,
    type = typeName,
    power = def and tonumber(def.power) or 0,
    accuracy = def and tonumber(def.accuracy) or 0,
    effect = def and def.effect or nil,
    desc = desc,
  }
end

local function isSpeciesNumber(value)
  return tostring(value or ""):match("^%d+$") ~= nil
end

--- Nicknames stay as written. A numeric species id is resolved through the
--- Gen 3 species table so the HUD does not print "228".
local function gen3BattlerName(battler, mon, speciesKey)
  local function usable(value)
    return type(value) == "string" and value ~= "" and not isSpeciesNumber(value)
  end
  if mon and usable(mon.nickname) then return mon.nickname end
  if battler and usable(battler.name) then return battler.name end
  if mon and usable(mon.name) then return mon.name end

  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if okP and Pokemon then
    if mon and Pokemon.displayName then
      local okD, shown = pcall(Pokemon.displayName, mon)
      if okD and usable(shown) and shown ~= "?????" then return shown end
    end
    local num = tonumber(speciesKey) or (battler and tonumber(battler.species)) or (mon and tonumber(mon.species))
    if num and Pokemon.name then
      local okN, n = pcall(Pokemon.name, num)
      if okN and usable(n) and n ~= "?????" then return n end
    end
  end
  if usable(speciesKey) then return speciesKey end
  return "POKéMON"
end

local function fillBattleSlot(slot, battler, data)
  local mon = battler and (battler.mon or battler.pokemon)
  if not mon then
    slot.active = false
    return
  end
  local speciesKey = mon.species or battler.species
  local def = data and data.pokemon and data.pokemon[speciesKey]
  slot.active = true
  slot.species = speciesKey or "UNKNOWN"
  slot.name = gen3BattlerName(battler, mon, (def and def.name) or speciesKey)
  slot.level = mon.level or 1
  slot.maxHp = battler.maxHP or (mon.stats and mon.stats.hp) or mon.maxHp or mon.hp or 1
  slot.shownHp = math.max(0, math.floor(battler.shownHP or mon.hp or 0))
  slot.hp = mon.hp or 0
  slot.hpRatio = slot.maxHp > 0 and math.max(0, math.min(1, slot.shownHp / slot.maxHp)) or 0
  slot.status = battler.shownStatus or mon.status
  slot.shownStatus = battler.shownStatus
  slot.types = battler.curTypes or (def and def.types) or { "NORMAL" }
  slot.gender = mon.gender
  slot.ability = mon.ability or battler.ability or (def and def.ability)
  slot.heldItem = mon.heldItem or mon.item or battler.item
  slot.exp = mon.exp or 0
end

function Gen3Adapter:updateBattleInfo(outCache)
  local cache = outCache or self:getBattleCache()
  local battle, topState = self:getActiveBattle()
  if not battle then
    cache.isActive = false
    return cache
  end

  cache.isActive = true
  local data = self.game and self.game.data

  -- 1. Sync battlers from the live fight, including double partners.
  local pBattler = battle.player or battle.battler1
  local pMon = pBattler and (pBattler.mon or pBattler.pokemon)
  fillBattleSlot(cache.player, pBattler, data)

  local eBattler = battle.enemy or battle.opponent or battle.battler2
  fillBattleSlot(cache.enemy, eBattler, data)

  local battlers = battle.battlers
  if battlers then
    fillBattleSlot(cache.player2, battlers[2], data)
    fillBattleSlot(cache.enemy2, battlers[3], data)
  else
    cache.player2.active = false
    cache.enemy2.active = false
  end

  -- 3. Double Battle Detection & 2v2 Targets
  cache.isDouble = (battle.double == true or battle.isDouble == true or battle.isDoubleBattle == true or battle.battler3 ~= nil or (battlers and battlers[3] ~= nil))
  if cache.isDouble then
    cache.validTargets = {
      { index = 1, label = "FOE 1", battler = "enemy", valid = true, isSpread = false },
      { index = 2, label = "FOE 2", battler = "enemy2", valid = true, isSpread = false },
      { index = 3, label = "ALLY", battler = "player2", valid = true, isSpread = false },
      { index = 4, label = "SELF", battler = "player", valid = false, isSpread = false },
    }
  else
    cache.validTargets = {
      { index = 1, label = "FOE", battler = "enemy", valid = true, isSpread = false },
    }
  end

  -- 4. Sync Moves
  local moves = pMon and pMon.moves or {}
  for i = 1, 4 do
    local slot = cache.moves[i]
    local mv = moves[i]
    if mv then
      local mId = (type(mv) == "table" and mv.id) or mv
      local facts = gen3MoveFacts(mId)
      slot.id = facts.id
      slot.name = facts.name
      slot.type = facts.type
      slot.source = "gen3"
      local curPP, maxPP = Gen3Adapter.resolveMovePp(pMon, i, mId)
      slot.pp = curPP
      slot.maxPP = maxPP
      slot.power = facts.power or 0
      slot.accuracy = facts.accuracy or 0
      slot.effect = facts.effect
      if facts.desc then
        slot.desc = facts.desc
        slot.description = facts.desc
      else
        slot.desc = nil
        slot.description = nil
      end
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

  -- 5. Sync Phase & Selected Indices from the battle UI the engine is showing.
  local liveFight = false
  local okBattle, Battle = pcall(require, "src.core.game3.battle")
  if okBattle and Battle and Battle.getState and Battle.getState() == battle then
    liveFight = true
  end
  local Ui = liveFight and package.loaded["src.core.game3.battle.ui"] or nil
  if liveFight and not Ui then
    local okUi, loaded = pcall(require, "src.core.game3.battle.ui")
    if okUi then Ui = loaded end
  end
  local mode = Ui and Ui._mode
  if liveFight and mode == "moves" then
    cache.phase = "move_select"
  elseif liveFight and mode == "target" then
    cache.phase = "target_select"
  elseif liveFight and mode == "menu" or (topState and topState.isChoiceBox) then
    cache.phase = "action_select"
  elseif liveFight then
    cache.phase = "messages"
  else
    cache.phase = "action_select"
  end
  cache.selectedAction = (liveFight and Ui and Ui._menuIndex) or battle.actionIndex or battle.menuIndex or 1
  cache.selectedMove = (liveFight and Ui and Ui._moveIndex) or battle.menuIndex or 1
  cache.selectedTarget = battle.targetIndex or 1

  return cache
end

-- =========================================================================
-- Atomic Storage Layer (Bill's PC & Player PC - Gen 3)
-- =========================================================================

local G3Storage = require("src.core.game3.storage")

function Gen3Adapter:getBoxCount()
  return G3Storage.TOTAL_BOXES_COUNT or 14
end

function Gen3Adapter:getPcCapacity()
  local session = self:getSession()
  local ok, n = pcall(G3Storage.pcItemsCount, session)
  if ok and type(n) == "number" and n > 0 then return n end
  return 50
end

function Gen3Adapter:getBoxCapacity()
  return G3Storage.IN_BOX_COUNT or 30
end

function Gen3Adapter:getCurrentBox()
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  return (storage and storage.currentBox) or 1
end

function Gen3Adapter:setCurrentBox(boxId)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  if storage then
    storage.currentBox = math.max(1, math.min(self:getBoxCount(), boxId or 1))
    return true
  end
  return false
end

function Gen3Adapter:getBoxName(boxId)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  local bId = boxId or (storage and storage.currentBox) or 1
  if storage and storage.boxes and storage.boxes[bId] and storage.boxes[bId].name then
    return storage.boxes[bId].name
  end
  return ("BOX %d"):format(bId)
end

function Gen3Adapter:setBoxName(boxId, name)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  if storage and storage.boxes and storage.boxes[boxId] then
    storage.boxes[boxId].name = name
    return true
  end
  return false
end

function Gen3Adapter:getBoxData(boxId)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  if not storage or not storage.boxes then return {} end
  local bId = boxId or storage.currentBox or 1
  local box = storage.boxes[bId]
  local list = {}
  for slot = 1, self:getBoxCapacity() do
    local mon = box and box.mons and box.mons[slot]
    list[slot] = mon and self:normalizeMon(mon, slot) or nil
  end
  return list
end

function Gen3Adapter:canDeposit(partySlot, targetBoxId)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  local party = (session and session.party) or {}
  local mon = party[partySlot]
  if not mon then return false, "No Pokémon in that slot." end

  local okRs, RsStorage = pcall(require, "src.ui.game3.rs.storage_policy")
  if okRs and RsStorage and RsStorage.matches and RsStorage.matches(session) and RsStorage.depositError then
    local err = RsStorage.depositError(session, partySlot)
    if err then
      local text = (RsStorage.text and RsStorage.text(err)) or err
      return false, text
    end
  end

  local bId = targetBoxId or (storage and storage.currentBox) or 1
  local box = storage and storage.boxes and storage.boxes[bId]
  local count = 0
  for slot = 1, self:getBoxCapacity() do
    if box and box.mons and box.mons[slot] then count = count + 1 end
  end
  if count >= self:getBoxCapacity() then
    return false, ("BOX %d is full."):format(bId)
  end

  if not (okRs and RsStorage and RsStorage.matches and RsStorage.matches(session)) then
    local healthy = 0
    for _, m in ipairs(party) do
      if (m.hp or 0) > 0 and not m.isEgg then healthy = healthy + 1 end
    end
    if (mon.hp or 0) > 0 and not mon.isEgg and healthy <= 1 then
      return false, "You can't deposit your last battle-ready Pokémon!"
    end
  end

  return true
end

function Gen3Adapter:canWithdraw(boxId, boxSlot)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  local party = (session and session.party) or {}
  if #party >= 6 then
    return false, "Your party is full (6/6)."
  end

  local bId = boxId or (storage and storage.currentBox) or 1
  local box = storage and storage.boxes and storage.boxes[bId]
  if not (box and box.mons and box.mons[boxSlot]) then
    return false, "No Pokémon in that storage slot."
  end

  return true
end

function Gen3Adapter:depositMon(partySlot, targetBoxId, targetSlot)
  local ok, reason = self:canDeposit(partySlot, targetBoxId)
  if not ok then return false, reason end

  local session = self:getSession()
  local success, boxIdOrErr, slot = G3Storage.deposit(session, partySlot, targetBoxId, targetSlot)
  if not success then
    if boxIdOrErr == "last_pokemon" then
      return false, "You can't deposit your last battle-ready Pokémon!"
    end
    if boxIdOrErr == "box_full" then
      return false, ("BOX %d is full."):format(targetBoxId or 1)
    end
    if boxIdOrErr == "invalid_party_mon" then
      return false, "No Pokémon in that slot."
    end
    return false, tostring(boxIdOrErr or "Deposit failed.")
  end

  local storage = G3Storage.ensure(session)
  local box = storage and storage.boxes and storage.boxes[boxIdOrErr]
  local mon = box and box.mons and box.mons[slot]
  return true, mon
end

function Gen3Adapter:withdrawMon(boxId, boxSlot, targetPartySlot)
  local ok, reason = self:canWithdraw(boxId, boxSlot)
  if not ok then return false, reason end

  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  local party = session.party
  local bId = boxId or (storage and storage.currentBox) or 1
  local box = storage.boxes[bId]

  local mon = box.mons[boxSlot]
  box.mons[boxSlot] = nil
  G3Storage.fullHealMon(mon)

  if targetPartySlot and targetPartySlot <= #party + 1 then
    table.insert(party, targetPartySlot, mon)
  else
    table.insert(party, mon)
  end
  return true, mon
end

function Gen3Adapter:swapSlots(sourceLoc, sourceSlot, targetLoc, targetSlot, sourceBoxId, targetBoxId)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  if not storage then return false, "No storage." end

  if sourceLoc == "party" and targetLoc == "party" then
    if session.party[sourceSlot] and session.party[targetSlot] then
      session.party[sourceSlot], session.party[targetSlot] = session.party[targetSlot], session.party[sourceSlot]
      return true
    end
    return false, "Invalid party slots."
  elseif sourceLoc == "box" and targetLoc == "box" then
    local sB = storage.boxes[sourceBoxId or storage.currentBox or 1]
    local tB = storage.boxes[targetBoxId or storage.currentBox or 1]
    if not sB or not tB then return false, "Invalid box." end

    sB.mons[sourceSlot], tB.mons[targetSlot] = tB.mons[targetSlot], sB.mons[sourceSlot]
    return true
  elseif sourceLoc == "party" and targetLoc == "box" then
    local tB = storage.boxes[targetBoxId or storage.currentBox or 1]
    if not tB then return false, "Invalid box." end
    if tB.mons[targetSlot] then
      local partyMon = session.party[sourceSlot]
      local boxMon = tB.mons[targetSlot]
      G3Storage.fullHealMon(partyMon)
      G3Storage.fullHealMon(boxMon)
      session.party[sourceSlot] = boxMon
      tB.mons[targetSlot] = partyMon
      return true
    else
      return self:depositMon(sourceSlot, targetBoxId, targetSlot)
    end
  elseif sourceLoc == "box" and targetLoc == "party" then
    local sB = storage.boxes[sourceBoxId or storage.currentBox or 1]
    if not sB then return false, "Invalid box." end
    if session.party[targetSlot] then
      local boxMon = sB.mons[sourceSlot]
      local partyMon = session.party[targetSlot]
      G3Storage.fullHealMon(partyMon)
      G3Storage.fullHealMon(boxMon)
      sB.mons[sourceSlot] = partyMon
      session.party[targetSlot] = boxMon
      return true
    else
      return self:withdrawMon(sourceBoxId, sourceSlot, targetSlot)
    end
  end

  return false, "Unsupported swap operation."
end

function Gen3Adapter:releaseMon(loc, slot, boxId)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  if loc == "party" then
    local party = session and session.party or {}
    local mon = party[slot]
    if not mon then return false, "No Pokémon in that slot." end
    local healthy = 0
    for _, m in ipairs(party) do
      if (m.hp or 0) > 0 and not m.isEgg then healthy = healthy + 1 end
    end
    if (mon.hp or 0) > 0 and not mon.isEgg and healthy <= 1 then
      return false, "Cannot release your last healthy Pokémon!"
    end
    return true, table.remove(party, slot)
  else
    local bId = boxId or (storage and storage.currentBox) or 1
    local box = storage and storage.boxes and storage.boxes[bId]
    if not (box and box.mons and box.mons[slot]) then
      return false, "No Pokémon in that storage slot."
    end
    local mon = box.mons[slot]
    box.mons[slot] = nil
    return true, mon
  end
end

function Gen3Adapter:getItemStorage()
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  local items = {}
  local data = self.game and self.game.data
  local rawItems = (storage and storage.items) or {}
  local okItemsData, ItemsData = pcall(require, "src.core.game3.items_data")

  for i, it in ipairs(rawItems) do
    if it and it.id and (it.qty or it.count or 0) > 0 then
      local itemId = it.id
      local dName = nil
      if okItemsData and ItemsData and ItemsData.displayName then
        local okDn, resDn = pcall(ItemsData.displayName, itemId)
        if okDn and resDn and resDn ~= "" then dName = resDn end
      end
      local def = data and data.items and (data.items[itemId] or data.items[tostring(itemId)])
      if not dName and def then dName = def.name end
      dName = dName or tostring(itemId)

      local desc = nil
      if okItemsData and ItemsData and ItemsData.description then
        local okDe, resDe = pcall(ItemsData.description, itemId)
        if okDe and resDe and resDe ~= "" then desc = resDe end
      end
      if not desc and def then desc = def.description end

      items[#items + 1] = {
        id = itemId,
        value = itemId,
        slot = i,
        name = dName,
        label = dName,
        count = it.qty or it.count or 1,
        qty = it.qty or it.count or 1,
        desc = desc,
        description = desc,
        def = def,
      }
    end
  end
  return items
end

function Gen3Adapter:withdrawItem(itemId, qty, slot)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  if not storage or not itemId then return false, "No storage." end

  local itemEntry = nil
  local itemIdx = nil
  for i, it in ipairs(storage.items or {}) do
    if it.id == itemId or (slot and i == slot) then
      itemEntry = it
      itemIdx = i
      break
    end
  end
  if not itemEntry then return false, "Item not in PC." end

  local count = itemEntry.qty or itemEntry.count or 1
  local amount = math.max(1, math.min(count, qty or 1))

  local bag = (session and (session.bag or session.inventory))
    or (self.game and self.game.save and (self.game.save.bag or self.game.save.inventory))
  if not bag then return false, "No bag." end

  local Bag = require("src.core.game3.bag")
  if not Bag.canAdd(bag, itemId, amount) then return false, "Bag is full." end
  local okAdd = Bag.add(bag, itemId, amount)
  if not okAdd then return false, "Could not add to bag." end

  itemEntry.qty = count - amount
  if itemEntry.qty <= 0 then
    table.remove(storage.items, itemIdx)
  end
  return true
end

function Gen3Adapter:depositItem(itemId, qty, slot)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  if not storage or not itemId then return false, "No storage." end

  local bag = (session and (session.bag or session.inventory))
    or (self.game and self.game.save and (self.game.save.bag or self.game.save.inventory))
  if not bag then return false, "No bag." end

  local Bag = require("src.core.game3.bag")
  local available = Bag.get(bag, itemId) or 0
  if available <= 0 then return false, "Item not in Bag." end

  local amount = math.max(1, math.min(available, qty or 1))
  local maxCap = (session and G3Storage.pcItemsCount(session)) or 30

  local existing = nil
  for _, it in ipairs(storage.items or {}) do
    if it.id == itemId then existing = it break end
  end
  if not existing and #(storage.items or {}) >= maxCap then
    return false, ("PC Item storage is full (%d items)."):format(maxCap)
  end

  Bag.remove(bag, itemId, amount)
  if existing then
    existing.qty = (existing.qty or 1) + amount
  else
    table.insert(storage.items, { id = itemId, qty = amount })
  end
  return true
end

function Gen3Adapter:tossItem(itemId, qty, slot)
  local session = self:getSession()
  local storage = G3Storage.ensure(session)
  if not storage or not itemId then return false, "No storage." end

  local itemEntry = nil
  local itemIdx = nil
  for i, it in ipairs(storage.items or {}) do
    if it.id == itemId or (slot and i == slot) then
      itemEntry = it
      itemIdx = i
      break
    end
  end
  if not itemEntry then return false, "Item not in PC." end

  local count = itemEntry.qty or itemEntry.count or 1
  local amount = math.max(1, math.min(count, qty or 1))
  itemEntry.qty = count - amount
  if itemEntry.qty <= 0 then
    table.remove(storage.items, itemIdx)
  end
  return true
end

-- =========================================================================
-- Pokédex Normalization Layer (Gen 3)
-- =========================================================================

function Gen3Adapter:getDex()
  local session = self:getSession()
  if session and session.dex then return session.dex end
  local save = self.game and self.game.save
  if save then
    if save.dex then return save.dex end
    if save.session and save.session.dex then return save.session.dex end
    if save.pokedex then return save.pokedex end
  end
  local Pokedex = package.loaded["src.ui.game3.pokedex"]
  if Pokedex and Pokedex._dex then return Pokedex._dex end
  local RsePokedex = package.loaded["src.ui.game3.rse.pokedex"]
  if RsePokedex and RsePokedex.active and RsePokedex.active() then
    local s = RsePokedex.active()
    if s and s.dex then return s.dex end
  end
  return nil
end

local _s2nMap = nil
local _n2sMap = nil
local _s2rHoennMap = nil
local _r2sHoennMap = nil

local function ensureIndexMaps()
  if _s2nMap then return end
  _s2nMap, _n2sMap, _s2rHoennMap, _r2sHoennMap = {}, {}, {}, {}

  -- Baseline 1..251 identity mapping
  for i = 1, 251 do
    _s2nMap[i] = i
    _n2sMap[i] = i
  end

  local okC, C = pcall(require, "src.core.game3.constants.emerald.species")
  if not okC or not C or not C.byName then
    local okC2, C2 = pcall(require, "src.core.game3.constants")
    if okC2 and C2 and C2.of then
      local em = C2.of("emerald")
      if em and em.species then C = em.species end
    end
  end

  if C and C.byName then
    local byName = C.byName
    for k, sp in pairs(byName) do
      local name = k:match("^SPECIES_(.*)$")
      if name and type(sp) == "number" and sp >= 1 and sp <= 411 then
        local nat = byName["NATIONAL_DEX_" .. name]
        if nat and type(nat) == "number" and nat >= 1 and nat <= 386 then
          _s2nMap[sp] = nat
          _n2sMap[nat] = sp
        end
        local hoenn = byName["HOENN_DEX_" .. name]
        if hoenn and type(hoenn) == "number" and hoenn >= 1 and hoenn <= 202 then
          _s2rHoennMap[sp] = hoenn
          _r2sHoennMap[hoenn] = sp
        end
      end
    end
  end

  -- Fallback formula for Gen 3 species 277..411 (speciesId - 25 = nationalNo)
  for sp = 277, 411 do
    local nat = sp - 25
    if nat >= 252 and nat <= 386 then
      if not _s2nMap[sp] then _s2nMap[sp] = nat end
      if not _n2sMap[nat] then _n2sMap[nat] = sp end
    end
  end
end

function Gen3Adapter:resolveSpeciesId(speciesId)
  if type(speciesId) == "number" then
    if speciesId >= 252 and speciesId <= 276 then
      local sp = self:nationalToSpecies(speciesId)
      if sp then return sp end
    end
    return speciesId
  end
  if type(speciesId) ~= "string" then return nil end
  local num = tonumber(speciesId)
  if num then
    if num >= 252 and num <= 276 then
      local sp = self:nationalToSpecies(num)
      if sp then return sp end
    end
    return num
  end

  ensureIndexMaps()
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if okP and Pokemon and Pokemon.speciesFromName then
    local sp = Pokemon.speciesFromName(speciesId)
    if sp then return sp end
  end

  local okC, C = pcall(require, "src.core.game3.constants.emerald.species")
  if okC and C and C.byName then
    local sp = C.byName["SPECIES_" .. speciesId:upper()]
    if sp then return sp end
  end
  return nil
end

function Gen3Adapter:speciesToNational(speciesId)
  local sp = self:resolveSpeciesId(speciesId)
  if not sp then return nil end
  ensureIndexMaps()
  if _s2nMap[sp] then return _s2nMap[sp] end
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if okP and Pokemon and Pokemon.national then
    local nat = Pokemon.national(sp)
    if nat then return nat end
  end
  if sp <= 251 then return sp end
  if sp >= 277 and sp <= 411 then return sp - 25 end
  return nil
end

function Gen3Adapter:nationalToSpecies(nationalNo)
  nationalNo = tonumber(nationalNo)
  if not nationalNo or nationalNo < 1 or nationalNo > 386 then return nil end
  ensureIndexMaps()
  if _n2sMap[nationalNo] then return _n2sMap[nationalNo] end
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if okP and Pokemon and Pokemon.speciesFromNational then
    local sp = Pokemon.speciesFromNational(nationalNo)
    if sp then return sp end
  end
  if nationalNo <= 251 then return nationalNo end
  if nationalNo >= 252 and nationalNo <= 386 then return nationalNo + 25 end
  return nil
end

function Gen3Adapter:speciesToRegional(speciesId)
  local sp = self:resolveSpeciesId(speciesId)
  if not sp then return nil end
  ensureIndexMaps()

  if self.region == "HOENN" then
    if _s2rHoennMap[sp] then return _s2rHoennMap[sp] end
    local okDex, Dex = pcall(require, "src.core.game3.dex")
    if okDex and Dex and Dex.regionalNumber then
      local ok, r = pcall(Dex.regionalNumber, sp, "emerald")
      if ok and r and r >= 1 and r <= 202 then return r end
    end
    return nil
  else
    -- Kanto (FRLG) Regional Dex: 1..151
    local nat = self:speciesToNational(sp)
    if nat and nat >= 1 and nat <= 151 then
      return nat
    end
    return nil
  end
end

function Gen3Adapter:regionalToSpecies(regionalNo)
  regionalNo = tonumber(regionalNo)
  if not regionalNo or regionalNo < 1 then return nil end
  ensureIndexMaps()

  if self.region == "HOENN" then
    if regionalNo > 202 then return nil end
    return _r2sHoennMap[regionalNo]
  else
    -- Kanto (FRLG) Regional Dex: 1..151
    if regionalNo > 151 then return nil end
    return self:nationalToSpecies(regionalNo)
  end
end

function Gen3Adapter:hasSeen(speciesId)
  local dex = self:getDex()
  if not dex then return false end
  local sp = self:resolveSpeciesId(speciesId) or speciesId
  local okDex, Dex = pcall(require, "src.core.game3.dex")
  if okDex and Dex and Dex.isSeen then
    local ok, res = pcall(Dex.isSeen, dex, sp)
    if ok and res == true then return true end
    if type(sp) == "number" and sp >= 1 and sp <= 386 then
      local natSp = self:nationalToSpecies(sp)
      if natSp and natSp ~= sp then
        local ok2, res2 = pcall(Dex.isSeen, dex, natSp)
        if ok2 and res2 == true then return true end
      end
    end
  end
  local seen = dex.seen or {}
  if seen[sp] == true or seen[speciesId] == true then return true end
  return self:hasCaught(speciesId)
end

function Gen3Adapter:hasCaught(speciesId)
  local dex = self:getDex()
  if not dex then return false end
  local sp = self:resolveSpeciesId(speciesId) or speciesId
  local okDex, Dex = pcall(require, "src.core.game3.dex")
  if okDex and Dex and Dex.isCaught then
    local ok, res = pcall(Dex.isCaught, dex, sp)
    if ok and res == true then return true end
    if type(sp) == "number" and sp >= 1 and sp <= 386 then
      local natSp = self:nationalToSpecies(sp)
      if natSp and natSp ~= sp then
        local ok2, res2 = pcall(Dex.isCaught, dex, natSp)
        if ok2 and res2 == true then return true end
      end
    end
  end
  local owned = dex.owned or dex.caught or {}
  return owned[sp] == true or owned[speciesId] == true
end

function Gen3Adapter:isNationalDexUnlocked()
  local session = self:getSession()
  local dex = self:getDex()
  local okPd, PokedexData = pcall(require, "src.core.game3.pokedex_data")
  if okPd and PokedexData and PokedexData.isNationalUnlocked then
    local ok, unlocked = pcall(PokedexData.isNationalUnlocked, session, dex)
    if ok and unlocked ~= nil then return unlocked == true end
  end
  local okDex, Dex = pcall(require, "src.core.game3.dex")
  if okDex and Dex and Dex.nationalEnabled then
    local save = self.game and self.game.save
    local ok, enabled = pcall(Dex.nationalEnabled, save or { dex = dex })
    if ok and enabled ~= nil then return enabled == true end
  end
  if dex and (dex.nationalUnlocked or dex.national) then return true end
  if session and (session.national_dex_unlocked or (session.dex and session.dex.nationalUnlocked)) then return true end
  local RsePokedex = package.loaded["src.ui.game3.rse.pokedex"]
  if RsePokedex and RsePokedex.active and RsePokedex.active() then
    local s = RsePokedex.active()
    if s and s.nationalEnabled ~= nil then return s.nationalEnabled == true end
  end
  return false
end

function Gen3Adapter:getFootprint(speciesId)
  local sp = self:resolveSpeciesId(speciesId)
  if not sp or sp == 0 then return nil end
  local okChrome, PokedexChrome = pcall(require, "src.ui.game3.pokedex_chrome")
  if okChrome and PokedexChrome and PokedexChrome.footprintSource then
    local bytes = PokedexChrome.footprintSource(sp)
    if bytes and #bytes > 0 then
      return { bytes = bytes, speciesId = sp }
    end
  end
  return nil
end

function Gen3Adapter:getPokedexCounts()
  local dex = self:getDex()
  local session = self:getSession()
  local seenCount = 0
  local ownedCount = 0

  if dex then
    -- Species -> true maps. Dex.countSeen / countCaught below are the
    -- engine's own totals and win when they see more than the raw map.
    seenCount = BaseAdapter.countFlags(dex.seen)
    local ownedKeys = {}
    local function take(tbl)
      if type(tbl) == "number" then
        if tbl > ownedCount then ownedCount = tbl end
        return
      end
      if type(tbl) ~= "table" then return end
      for k, v in pairs(tbl) do
        if v and v ~= 0 and v ~= false then ownedKeys[k] = true end
      end
    end
    take(dex.owned)
    take(dex.caught)
    local n = 0
    for _ in pairs(ownedKeys) do n = n + 1 end
    if n > ownedCount then ownedCount = n end
  end

  local okSave, SaveMenu = pcall(require, "src.ui.game3.save_menu")
  if okSave and SaveMenu and SaveMenu.countDex and session then
    local okCnt, cnt = pcall(SaveMenu.countDex, session)
    if okCnt and type(cnt) == "number" and cnt > ownedCount then
      ownedCount = cnt
    end
  end

  local okDex, Dex = pcall(require, "src.core.game3.dex")
  if okDex and Dex and dex then
    if Dex.countSeen then
      local okS, s = pcall(Dex.countSeen, dex)
      if okS and type(s) == "number" and s > seenCount then seenCount = s end
    end
    if Dex.countCaught then
      local okC, c = pcall(Dex.countCaught, dex)
      if okC and type(c) == "number" and c > ownedCount then ownedCount = c end
    end
  end

  if seenCount < ownedCount then
    seenCount = ownedCount
  end

  return {
    seen = seenCount,
    owned = ownedCount,
  }
end

function Gen3Adapter:getPokedexEntries(mode, searchType1, searchType2)
  local data = self.game and self.game.data or {}
  local pokemon = data.pokemon or {}
  local entries = {}
  local sortMode = mode or (self.region == "HOENN" and "HOENN" or "KANTO")

  if next(pokemon) == nil then
    local count = (sortMode == "HOENN" or self.region == "HOENN") and 202 or (sortMode == "NATIONAL" and 386 or 151)
    for i = 1, count do
      local sp = (self.region == "HOENN") and self:regionalToSpecies(i) or (sortMode == "NATIONAL" and self:nationalToSpecies(i) or self:regionalToSpecies(i) or i)
      if sp then
        local entry = self:getDexEntry(sp)
        local match = true
        if searchType1 and entry.types and entry.types[1] ~= searchType1 and entry.types[2] ~= searchType1 then
          match = false
        end
        if searchType2 and entry.types and entry.types[1] ~= searchType2 and entry.types[2] ~= searchType2 then
          match = false
        end
        if match then
          entries[#entries + 1] = {
            id = entry.species,
            species = entry.species,
            name = entry.name,
            dex = entry.dex,
            kantoNum = (self.region ~= "HOENN") and entry.regionalDex or 0,
            hoennNum = (self.region == "HOENN") and entry.regionalDex or 0,
            nationalNum = entry.nationalDex,
            seen = entry.seen,
            caught = entry.caught,
            types = entry.types,
            height = entry.height,
            weight = entry.weight,
          }
        end
      end
    end
  else
    for id, def in pairs(pokemon) do
      if type(def) == "table" and id ~= "EGG" then
        local sp = self:resolveSpeciesId(id) or (def.dex or 0)
        local isSeen = self:hasSeen(id) or self:hasSeen(sp)
        local isCaught = self:hasCaught(id) or self:hasCaught(sp)

        local natNum = self:speciesToNational(sp) or def.nationalDex or def.dex or 0
        local regNum = self:speciesToRegional(sp)
        local hNum = (self.region == "HOENN") and (regNum or 0) or (def.hoennDex or 0)
        local kNum = (self.region ~= "HOENN") and (regNum or 0) or (def.kantoDex or (natNum <= 151 and natNum or 0))

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
            species = sp,
            name = def.name or id,
            dex = (self.region == "HOENN" and hNum > 0) and hNum or (kNum > 0 and kNum or natNum),
            kantoNum = kNum,
            hoennNum = hNum,
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
  end

  if sortMode == "NATIONAL" then
    table.sort(entries, function(a, b) return (a.nationalNum or 0) < (b.nationalNum or 0) end)
  elseif sortMode == "HOENN" then
    table.sort(entries, function(a, b) return (a.hoennNum or 0) < (b.hoennNum or 0) end)
  elseif sortMode == "A-Z" then
    table.sort(entries, function(a, b) return tostring(a.name) < tostring(b.name) end)
  else
    table.sort(entries, function(a, b) return (a.kantoNum or a.dex or 0) < (b.kantoNum or b.dex or 0) end)
  end

  return entries
end

function Gen3Adapter:getDexEntry(speciesId)
  local data = self.game and self.game.data or {}
  local pokemon = data.pokemon or {}
  local sp = self:resolveSpeciesId(speciesId) or speciesId
  local def = pokemon[speciesId] or (type(sp) == "number" and pokemon[sp])

  if not def and type(speciesId) == "number" then
    for k, d in pairs(pokemon) do
      if type(d) == "table" and (d.dex == speciesId or d.nationalDex == speciesId or d.hoennDex == speciesId) then
        def = d
        speciesId = k
        sp = self:resolveSpeciesId(k) or sp
        break
      end
    end
  end

  local natNum = self:speciesToNational(sp) or (def and (def.nationalDex or def.dex)) or (type(speciesId) == "number" and speciesId) or 1
  local regNum = self:speciesToRegional(sp)
  local dexNum = (self.region == "HOENN" and regNum) or (self.region ~= "HOENN" and regNum) or natNum
  -- Name Resolution
  local name = def and (def.name or def.species)
  if not name or tostring(name):find("^%d+$") then
    local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
    if okP and Pokemon and Pokemon.name and type(sp) == "number" then
      local okN, n = pcall(Pokemon.name, sp)
      if okN and n and n ~= "" and not n:find("^%?+$") then
        name = n
      end
    end
  end
  if not name or tostring(name):find("^%d+$") then
    name = tostring(speciesId or "POKÉMON"):upper()
  end

  -- Type Resolution
  local GBA_TYPE_MAP = {
    [0] = "NORMAL", [1] = "FIGHTING", [2] = "FLYING", [3] = "POISON",
    [4] = "GROUND", [5] = "ROCK", [6] = "BUG", [7] = "GHOST",
    [8] = "STEEL", [9] = "???", [10] = "FIRE", [11] = "WATER",
    [12] = "GRASS", [13] = "ELECTRIC", [14] = "PSYCHIC", [15] = "ICE",
    [16] = "DRAGON", [17] = "DARK",
  }
  local types = (def and def.types and #def.types > 0 and def.types) or nil
  if not types and type(sp) == "number" then
    local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
    if okP and Pokemon and Pokemon.types then
      local okT, t = pcall(Pokemon.types, sp)
      if okT and type(t) == "table" and t[1] ~= nil then
        local t1Name = GBA_TYPE_MAP[t[1]] or "NORMAL"
        local t2Name = (t[2] and t[2] ~= t[1] and GBA_TYPE_MAP[t[2]]) or nil
        if t2Name then
          types = { t1Name, t2Name }
        else
          types = { t1Name }
        end
      end
    end
  end
  types = types or { "NORMAL" }

  -- Pokédex Entry Lore Resolution
  local dexEntry = def and def.dexEntry or {}
  local okPd, PokedexData = pcall(require, "src.core.game3.pokedex_data")
  local pdEntry = nil
  if okPd and PokedexData then
    if PokedexData.getEntry and type(sp) == "number" then
      local okPde, pde = pcall(PokedexData.getEntry, sp)
      if okPde and type(pde) == "table" then
        pdEntry = pde
      end
    end
    if not pdEntry and PokedexData.init and type(sp) == "number" then
      pcall(PokedexData.init)
      if PokedexData._entries and PokedexData._entries[sp] then
        local raw = PokedexData._entries[sp]
        pdEntry = {
          category = raw.category,
          heightDm = raw.height,
          weightHg = raw.weight,
          description = raw.description,
          description2 = raw.description2,
        }
      end
    end
  end

  if not pdEntry and type(sp) == "number" then
    local okM, Mapsec = pcall(require, "src.ui.game3.rse.mapsec")
    if okM and Mapsec and Mapsec.readLua then
      local okEntries, entries = pcall(Mapsec.readLua, "pokemon/pokedex/entries.lua")
      if okEntries and type(entries) == "table" and entries[sp] then
        local raw = entries[sp]
        pdEntry = {
          category = raw.category,
          heightDm = raw.height,
          weightHg = raw.weight,
          description = raw.description,
          description2 = raw.description2,
        }
      end
    end
  end

  local rawKind = (pdEntry and pdEntry.category) or dexEntry.kind or dexEntry.species or (def and def.kind) or "POKÉMON"
  local kind = tostring(rawKind):gsub("%s*POK[EÉ]MON$", ""):gsub("%s*PKMN$", "")
  if kind == "" then kind = "POKÉMON" end

  local isCaught = self:hasCaught(sp)
  local isSeen = self:hasSeen(sp)

  -- Canonical GBA Integer Truncation for Height (decimeters) and Weight (hectograms)
  local dm = (pdEntry and pdEntry.heightDm) or dexEntry.heightDm or (type(dexEntry.height) == "number" and dexEntry.height)
  local hg = (pdEntry and pdEntry.weightHg) or dexEntry.weightHg or (type(dexEntry.weight) == "number" and dexEntry.weight)

  local heightStr = "---"
  local heightMetric = "---"
  if dm and type(dm) == "number" and dm > 0 then
    local inchesTenths = math.floor(10000 * dm / 254)
    if inchesTenths % 10 >= 5 then inchesTenths = inchesTenths + 10 end
    local feet = math.floor(inchesTenths / 120)
    local inches = math.floor((inchesTenths - feet * 120) / 10)
    heightStr = string.format("%d'%02d\"", feet, inches)
    heightMetric = ("%.1f m"):format(dm / 10):gsub("%.", ",")
  elseif dexEntry.heightFt ~= nil then
    heightStr = ("%d'%02d\""):format(dexEntry.heightFt or 0, dexEntry.heightIn or 0)
    heightMetric = ("%.1f m"):format(((dexEntry.heightFt or 0) * 12 + (dexEntry.heightIn or 0)) * 0.0254):gsub("%.", ",")
  elseif dexEntry.heightM ~= nil then
    heightMetric = ("%.1f m"):format(dexEntry.heightM):gsub("%.", ",")
    local totalIn = math.floor(dexEntry.heightM * 39.37)
    heightStr = ("%d'%02d\""):format(math.floor(totalIn / 12), totalIn % 12)
  end

  local weightStr = "---"
  local weightMetric = "---"
  if hg and type(hg) == "number" and hg > 0 then
    local lbsHund = math.floor((hg * 100000) / 4536)
    if lbsHund % 10 >= 5 then lbsHund = lbsHund + 10 end
    local wholeLbs = math.floor(lbsHund / 100)
    local fracLbs = math.floor((lbsHund % 100) / 10)
    weightStr = string.format("%d.%d lbs.", wholeLbs, fracLbs)
    weightMetric = ("%.1f kg"):format(hg / 10):gsub("%.", ",")
  elseif dexEntry.weightKg ~= nil then
    weightMetric = ("%.1f kg"):format(dexEntry.weightKg):gsub("%.", ",")
    local totalTenths = math.floor(dexEntry.weightKg * 22.046)
    weightStr = ("%d.%d lbs."):format(math.floor(totalTenths / 10), totalTenths % 10)
  elseif type(dexEntry.weight) == "number" then
    weightStr = ("%.1f lbs."):format(dexEntry.weight / 10)
  end

  -- Format description. Cart pages use <NEXT>; Gen 1 leftovers are text-bank keys.
  local desc = BaseAdapter.plainText(pdEntry and pdEntry.description, data)
    or BaseAdapter.plainText(dexEntry and dexEntry.description, data)
    or BaseAdapter.plainText(dexEntry and dexEntry.text, data)
    or BaseAdapter.plainText(def and def.description, data)
  desc = desc or "A wild POKÉMON discovered across the region."
  local desc2 = BaseAdapter.plainText(pdEntry and pdEntry.description2, data) or desc

  return {
    species = sp,
    speciesId = sp,
    dex = dexNum,
    nationalDex = natNum,
    regionalDex = regNum,
    name = name,
    types = types,
    kind = kind,
    height = heightStr,
    heightMetric = heightMetric,
    heightM = heightMetric,
    weight = weightStr,
    weightMetric = weightMetric,
    weightKg = weightMetric,
    description = desc,
    description2 = desc2,
    seen = isSeen,
    caught = isCaught,
    hasFootprint = (self:getFootprint(sp) ~= nil),
    def = def,
  }
end

function Gen3Adapter:getAreaInfo(speciesId, requestedRegion)
  local sp = self:resolveSpeciesId(speciesId)
  local data = self.game and self.game.data or {}
  local enc = data.encounters or {}
  local nests = {}
  local seenCoords = {}
  local seen = {}
  local hasKanto = false
  local hasSevii = false
  local hasHoenn = false

  -- =========================================================================
  -- 1. HOENN (EMERALD / RSE) ENCOUNTER RESOLUTION & 420-CELL INVERTED SCAN
  -- =========================================================================
  local isHoennGame = (self.region == "HOENN") or (requestedRegion == "hoenn")
  if isHoennGame then
    local targetSecList = {}
    local seenSec = {}

    -- Try authentic rse pokedex_area matcher first
    local okArea, Area = pcall(require, "src.ui.game3.rse.pokedex_area")
    local okDex, Pokedex = pcall(require, "src.ui.game3.rse.pokedex")
    if okArea and Area and Area.findMapsWithMon and okDex and Pokedex and Pokedex.areaContext then
      local s = { session = self.game and (self.game.session or self.game.save) or {} }
      local okCtx, ctx = pcall(Pokedex.areaContext, s)
      if okCtx and ctx then
        local found = Area.findMapsWithMon(sp, ctx)
        if found then
          for _, o in ipairs(found.overworld or {}) do
            if o.sec and not seenSec[o.sec] then
              seenSec[o.sec] = true
              targetSecList[#targetSecList + 1] = o.sec
            end
          end
          for _, sec in ipairs(found.special or {}) do
            if not seenSec[sec] then
              seenSec[sec] = true
              targetSecList[#targetSecList + 1] = sec
            end
          end
        end
      end
    end

    -- Direct encounter table scan fallback if findMapsWithMon yielded nothing or failed
    if #targetSecList == 0 and enc then
      for k, mapEnc in pairs(enc) do
        local hasSpecies = false
        -- Check both slot format (game.data.encounters) and header format (encounters.lua)
        for _, tableKey in ipairs({ "grass", "land", "water", "surf", "rod", "fishing", "oldRod", "goodRod", "superRod", "rockSmash", "rocks" }) do
          local sub = mapEnc[tableKey]
          if sub and sub.slots then
            for _, s in ipairs(sub.slots) do
              if s.species == sp or s.species == speciesId or (type(s.species) == "number" and s.species == sp) then
                hasSpecies = true
                break
              end
            end
          end
          if hasSpecies then break end
        end

        if hasSpecies then
          local sec = mapEnc.regionMapSectionId or mapEnc.mapsec or (mapEnc.header and mapEnc.header.regionMapSectionId)
          if not sec and type(k) == "string" and k:match("^%d+:%d+$") then
            local g, n = k:match("^(%d+):(%d+)$")
            local okCat, MapCatalog = pcall(require, "src.import.gba.map_catalog")
            local maps = data.maps or {}
            local id = okCat and MapCatalog and MapCatalog.mapIdFor and MapCatalog.mapIdFor(tonumber(g), tonumber(n))
            local def = id and maps[id]
            sec = def and tonumber(def.regionMapSectionId)
          end
          if sec and not seenSec[sec] then
            seenSec[sec] = true
            targetSecList[#targetSecList + 1] = sec
          end
        end
      end
    end

    -- Inverted 420-cell scan across RegionMap.mapSecAt(x, y) to collect ALL tiles
    -- for multi-tile routes (Route 119 = 6 tiles, Route 120 = 7 tiles, Route 124 = 12 tiles)
    local okRM, RegionMap = pcall(require, "src.ui.game3.rse.region_map")
    local okMapsec, Mapsec = pcall(require, "src.ui.game3.rse.mapsec")
    if #targetSecList > 0 then
      local minX = (okRM and RegionMap and RegionMap.CURSOR_X_MIN) or 1
      local maxX = (okRM and RegionMap and RegionMap.CURSOR_X_MAX) or 28
      local minY = (okRM and RegionMap and RegionMap.CURSOR_Y_MIN) or 2
      local maxY = (okRM and RegionMap and RegionMap.CURSOR_Y_MAX) or 16

      for _, targetSec in ipairs(targetSecList) do
        local secName = nil
        if okMapsec and Mapsec and Mapsec.name then
          local okN, res = pcall(Mapsec.name, targetSec)
          if okN and type(res) == "string" and res ~= "" then
            secName = res
          end
        end
        if not secName or secName == "" then
          secName = "ROUTE " .. tostring(targetSec)
        end

        local foundAnyTile = false
        if okRM and RegionMap and RegionMap.mapSecAt then
          for y = minY, maxY do
            for x = minX, maxX do
              local okSec, secId = pcall(RegionMap.mapSecAt, x, y)
              if okSec and secId == targetSec then
                foundAnyTile = true
                local coordKey = x .. "_" .. y
                if not seenCoords[coordKey] then
                  seenCoords[coordKey] = true
                  hasHoenn = true
                  nests[#nests + 1] = {
                    id = "MAPSEC_" .. tostring(targetSec) .. "_" .. coordKey,
                    name = secName,
                    mapId = "hoenn",
                    coords = { x = x, y = y },
                    mapsec = targetSec,
                  }
                end
              end
            end
          end
        end

        -- If targetSec is a special off-grid dungeon (e.g. Island Cave, Meteor Falls)
        if not foundAnyTile and okArea and Area and Area.markerPositions and okMapsec and Mapsec and Mapsec.entry then
          local okMarkers, markers = pcall(Area.markerPositions, { targetSec }, Mapsec.entry)
          if okMarkers and markers then
            for _, m in ipairs(markers or {}) do
              local tx = math.floor(m.x / 8)
              local ty = math.floor(m.y / 8)
              local coordKey = tx .. "_" .. ty
              if not seenCoords[coordKey] then
                seenCoords[coordKey] = true
                hasHoenn = true
                nests[#nests + 1] = {
                  id = "SPECIAL_" .. tostring(targetSec),
                  name = secName,
                  mapId = "hoenn",
                  coords = { x = tx, y = ty },
                  mapsec = targetSec,
                  isSpecial = true,
                }
              end
            end
          end
        end

        -- Direct coords fallback from encounter table if RegionMap wasn't cached
        if not foundAnyTile and enc then
          for _, mapEnc in pairs(enc) do
            local sec = mapEnc.regionMapSectionId or mapEnc.mapsec
            if sec == targetSec and mapEnc.coords then
              local tx = mapEnc.coords.x or 0
              local ty = mapEnc.coords.y or 0
              local coordKey = tx .. "_" .. ty
              if not seenCoords[coordKey] then
                seenCoords[coordKey] = true
                hasHoenn = true
                nests[#nests + 1] = {
                  id = "ENC_" .. tostring(targetSec) .. "_" .. coordKey,
                  name = secName,
                  mapId = "hoenn",
                  coords = { x = tx, y = ty },
                  mapsec = targetSec,
                }
              end
            end
          end
        end
      end
    end

    -- Deduplicate locations for UI list display so multi-tile routes appear once
    local locations = {}
    local seenLocNames = {}
    for _, n in ipairs(nests) do
      local locName = n.name or "WILD AREA"
      if not seenLocNames[locName] then
        seenLocNames[locName] = true
        locations[#locations + 1] = {
          id = "LOC_" .. tostring(n.mapsec or #locations + 1),
          name = locName,
          mapId = "hoenn",
          mapsec = n.mapsec,
          coords = n.coords,
          tiles = { n.coords },
          isSpecial = n.isSpecial,
        }
      else
        for _, loc in ipairs(locations) do
          if loc.name == locName then
            loc.tiles[#loc.tiles + 1] = n.coords
            break
          end
        end
      end
    end

    if hasHoenn or isHoennGame then
      return {
        region = "hoenn",
        canSwapRegion = false,
        availableRegions = { "hoenn" },
        nests = nests,
        locations = locations,
        hasHoenn = hasHoenn,
        isUnknown = (#nests == 0),
      }
    end
  end

  -- =========================================================================
  -- 2. KANTO & SEVII (FRLG) ENCOUNTER RESOLUTION
  -- =========================================================================
  -- Query authentic Gen 3 PokedexData wild area registry
  local okData, PokedexData = pcall(require, "src.core.game3.pokedex_data")
  if okData and PokedexData and PokedexData.getWildAreasForSpecies then
    local areas = PokedexData.getWildAreasForSpecies(sp) or {}
    for _, aKey in ipairs(areas) do
      local marker = PokedexData.getAreaMarker and PokedexData.getAreaMarker(aKey)
      local mapKey = PokedexData.getAreaMapKey and PokedexData.getAreaMapKey(aKey) or "kanto"
      local isSevii = (mapKey ~= "kanto" and mapKey ~= "hoenn")
      if isSevii then hasSevii = true else hasKanto = true end

      local targetReg = requestedRegion or (hasSevii and not hasKanto and "sevii" or "kanto")
      local match = false
      if targetReg == "sevii" and isSevii then match = true
      elseif targetReg == "kanto" and not isSevii then match = true
      elseif targetReg == "hoenn" then match = true end

      if match and not seen[aKey] then
        seen[aKey] = true
        nests[#nests + 1] = {
          id = aKey,
          name = aKey:gsub("^DEX_AREA_", ""):gsub("_", " "),
          mapId = mapKey,
          coords = marker and { x = marker.x, y = marker.y },
          marker = marker,
        }
      end
    end
  end

  -- Fallback to game.data.encounters table if empty
  if #nests == 0 and not (hasKanto or hasSevii) then
    for mapId, mapEnc in pairs(enc) do
      local hasSpecies = false
      for _, tableKey in ipairs({ "grass", "water", "surf", "rod", "oldRod", "goodRod", "superRod", "rockSmash" }) do
        if mapEnc[tableKey] and mapEnc[tableKey].slots then
          for _, s in ipairs(mapEnc[tableKey].slots) do
            if s.species == speciesId or (type(s.species) == "number" and s.species == speciesId) then
              hasSpecies = true
              break
            end
          end
        end
        if hasSpecies then break end
      end

      if hasSpecies and not seen[mapId] then
        seen[mapId] = true
        local isSevii = (mapId:find("isle") ~= nil or mapId:find("island") ~= nil or mapId:find("sevii") ~= nil or mapId:find("one_") ~= nil or mapId:find("two_") ~= nil or mapId:find("three_") ~= nil or mapId:find("four_") ~= nil or mapId:find("five_") ~= nil or mapId:find("six_") ~= nil or mapId:find("seven_") ~= nil)
        if isSevii then hasSevii = true else hasKanto = true end
        nests[#nests + 1] = {
          id = mapId,
          name = mapId:gsub("_", " "),
          mapId = mapId,
        }
      end
    end
  end

  local reg = requestedRegion
  if not reg then
    if self.region == "HOENN" then
      reg = "hoenn"
    elseif hasSevii and not hasKanto then
      reg = "sevii"
    else
      reg = "kanto"
    end
  end

  local canSwap = (self.region == "KANTO") and (hasKanto or hasSevii)
  return {
    region = reg,
    canSwapRegion = canSwap,
    availableRegions = (self.region == "HOENN") and { "hoenn" } or { "kanto", "sevii" },
    nests = nests,
    hasKanto = hasKanto,
    hasSevii = hasSevii,
    isUnknown = (#nests == 0),
  }
end


-- =========================================================================
-- Bag & Inventory Normalization Layer (Gen 3)
-- =========================================================================

function Gen3Adapter:getBagPockets()
  local isRse = (self.region == "HOENN")
  local pockets
  if isRse then
    pockets = {
      { id = "ITEMS", label = "ITEMS", max = 42, items = {} },
      { id = "POKE_BALLS", label = "POKé BALLS", max = 16, items = {} },
      { id = "TM_CASE", label = "TMs & HMs", max = 64, items = {} },
      { id = "BERRY_POUCH", label = "BERRIES", max = 46, items = {} },
      { id = "KEY_ITEMS", label = "KEY ITEMS", max = 30, items = {} },
    }
  else
    pockets = {
      { id = "ITEMS", label = "ITEMS", max = 42, items = {} },
      { id = "KEY_ITEMS", label = "KEY ITEMS", max = 30, items = {} },
      { id = "POKE_BALLS", label = "POKé BALLS", max = 13, items = {} },
      { id = "TM_CASE", label = "TM CASE", max = 58, items = {} },
      { id = "BERRY_POUCH", label = "BERRY POUCH", max = 43, items = {} },
    }
  end

  local session = self:getSession()
  local BagMenu = package.loaded["src.ui.game3.bag_menu"] or package.loaded["src.ui.game3.rse.bag_menu"]
  local ItemPc = package.loaded["src.ui.game3.item_pc"]
  local bag = (session and (session.bag or session.inventory))
    or (BagMenu and BagMenu._bag)
    or (ItemPc and ItemPc._bag)
    or (self.game and self.game.save and (self.game.save.bag or self.game.save.inventory))
    or (self.game and (self.game.bag or self.game.inventory))

  local okItemsData, ItemsData = pcall(require, "src.core.game3.items_data")
  if okItemsData and ItemsData and ItemsData.ensureModel then
    pcall(ItemsData.ensureModel, session or (isRse and "emerald" or "firered"))
  end
  local okBag, Bag = pcall(require, "src.core.game3.bag")

  for _, pDef in ipairs(pockets) do
    local rows = nil
    if not isRse and pDef.id == "TM_CASE" then
      -- FRLG TM Case sub-container resolution
      if okBag and Bag and Bag.listPocket and bag then
        local okList, list = pcall(Bag.listPocket, bag, "TM_CASE")
        if okList and type(list) == "table" and #list > 0 then rows = list end
      end
      if not rows and bag and bag.pockets and (bag.pockets.TM_CASE or bag.pockets.tm_case) then
        rows = bag.pockets.TM_CASE or bag.pockets.tm_case
      end
      if not rows and bag and (bag.tmCase or bag.tmsHms) then
        rows = bag.tmCase or bag.tmsHms
      end
      if not rows then
        local okTm, TmCase = pcall(require, "src.ui.game3.tm_case")
        if okTm and TmCase and TmCase.list then
          local okList, list = pcall(TmCase.list)
          if okList and type(list) == "table" and #list > 0 then rows = list end
        end
      end
    elseif not isRse and pDef.id == "BERRY_POUCH" then
      -- FRLG Berry Pouch sub-container resolution
      if okBag and Bag and Bag.listPocket and bag then
        local okList, list = pcall(Bag.listPocket, bag, "BERRY_POUCH")
        if okList and type(list) == "table" and #list > 0 then rows = list end
      end
      if not rows and bag and bag.pockets and (bag.pockets.BERRY_POUCH or bag.pockets.berry_pouch) then
        rows = bag.pockets.BERRY_POUCH or bag.pockets.berry_pouch
      end
      if not rows and bag and (bag.berryPouch or bag.berries) then
        rows = bag.berryPouch or bag.berries
      end
      if not rows then
        local okBp, BerryPouch = pcall(require, "src.ui.game3.berry_pouch")
        if okBp and BerryPouch and BerryPouch.list then
          local okList, list = pcall(BerryPouch.list)
          if okList and type(list) == "table" and #list > 0 then rows = list end
        end
      end
    else
      -- Standard pocket parsing (RSE dedicated pockets or FRLG direct pockets)
      if okBag and Bag and Bag.listPocket and bag then
        local okList, list = pcall(Bag.listPocket, bag, pDef.id)
        if okList and type(list) == "table" then rows = list end
      end

      if not rows and bag and bag.pockets then
        rows = bag.pockets[pDef.id] or bag.pockets[pDef.id:lower()] or bag.pockets[pDef.id:upper()]
      end
      if not rows and bag and type(bag) == "table" then
        rows = bag[pDef.id] or bag[pDef.id:lower()] or bag[pDef.id:upper()]
      end
    end

    for idx, r in ipairs(rows or {}) do
      local itemId = r.id or r.itemId or r.value or r[1] or r
      local qty = r.qty or r.count or r.quantity or r[2] or 1
      local dName = r.name or r.label
      if not dName or dName == "" then
        if okItemsData and ItemsData and ItemsData.displayName then
          local okDn, resDn = pcall(ItemsData.displayName, itemId)
          if okDn and resDn and resDn ~= "" then dName = resDn end
        end
      end
      if not dName or dName == "" then
        local okIdb, ItemDatabase = pcall(require, "mods.omni_ui.core.ItemDatabase")
        if okIdb and ItemDatabase and ItemDatabase.getName then
          dName = ItemDatabase.getName(itemId, self.game)
        end
      end
      dName = dName or tostring(itemId)

      local desc = r.description or r.desc
      if not desc or desc == "" then
        if okItemsData and ItemsData and ItemsData.description then
          local okDe, resDe = pcall(ItemsData.description, itemId)
          if okDe and resDe and resDe ~= "" then desc = resDe end
        end
      end
      if not desc or desc == "" then
        local okIdb, ItemDatabase = pcall(require, "mods.omni_ui.core.ItemDatabase")
        if okIdb and ItemDatabase and ItemDatabase.getDescription then
          desc = ItemDatabase.getDescription(itemId, nil, self.game)
        end
      end
      desc = desc or ""

      local isTm = (pDef.id == "TM_CASE")
      if not isTm and okItemsData and ItemsData and ItemsData.isTm then
        isTm = ItemsData.isTm(itemId)
      end

      pDef.items[#pDef.items + 1] = {
        id = itemId,
        value = itemId,
        name = dName,
        label = dName,
        count = qty,
        qty = qty,
        slot = idx,
        description = desc,
        isTM = isTm,
        pocket = pDef.id,
      }
    end
  end

  return pockets
end

function Gen3Adapter:getBagItems(pocketId)
  local pockets = self:getBagPockets()
  if pocketId then
    for _, p in ipairs(pockets) do
      if p.id == pocketId or p.label == pocketId or p.id:lower() == tostring(pocketId):lower() then
        return p.items
      end
    end
  end

  local all = {}
  for _, p in ipairs(pockets) do
    for _, it in ipairs(p.items) do
      all[#all + 1] = it
    end
  end
  return all
end

function Gen3Adapter:getBagCapacity(pocketId)
  local okItemsData, ItemsData = pcall(require, "src.core.game3.items_data")
  if okItemsData and ItemsData and ItemsData.CAPACITY then
    if pocketId and ItemsData.CAPACITY[pocketId] then
      return ItemsData.CAPACITY[pocketId]
    end
  end
  return 42
end

-- =========================================================================
-- Start Menu Items Normalization Layer (Gen 3)
-- =========================================================================

function Gen3Adapter:getStartMenuItems()
  local session = self:getSession()
  local items = {}

  -- 1. POKéDEX (gated by SYS_POKEDEX_GET flag or session dex presence)
  local okSave, SaveMenu = pcall(require, "src.ui.game3.save_menu")
  local hasDex = false
  if okSave and SaveMenu and SaveMenu.hasDex then
    local okH, h = pcall(SaveMenu.hasDex, session)
    if okH and h == true then
      hasDex = true
    end
  end
  if not hasDex and session then
    if session.hasDex or session.pokedex or (session.dex and (session.dex.seen or session.dex.owned)) then
      hasDex = true
    end
  end
  if hasDex then
    items[#items + 1] = { id = "pokedex", label = "POKéDEX" }
  end

  -- 2. POKéMON
  items[#items + 1] = { id = "pokemon", label = "POKéMON" }

  -- 3. BAG
  items[#items + 1] = { id = "item", label = "BAG" }

  -- 4. [PLAYER] TRAINER CARD
  local playerName = (session and (session.playerName or session.name)) or "TRAINER"
  items[#items + 1] = { id = "trainer", label = tostring(playerName):upper() }

  -- 5. SAVE (or RETIRE in Safari Zone)
  local safari = self:getSafariInfo()
  if safari and safari.active then
    items[#items + 1] = { id = "retire", label = "RETIRE", isSafari = true }
  else
    items[#items + 1] = { id = "save", label = "SAVE" }
  end

  -- 6. OPTION
  items[#items + 1] = { id = "option", label = "OPTION" }

  -- 7. EXIT
  items[#items + 1] = { id = "exit", label = "EXIT" }

  return items
end

--- Attaches dialogue / message controls for Gen 3.
function Gen3Adapter:attachDialogueControls(state)
  if not state then return end
  local okMO, ModernOverlay = pcall(require, "mods.omni_ui.core.ModernOverlay")
  if okMO and ModernOverlay and ModernOverlay.attachDialogueControls then
    ModernOverlay.attachDialogueControls(state, self.game)
  end
end

return Gen3Adapter

