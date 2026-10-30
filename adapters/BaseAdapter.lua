-- OmniUI Base Adapter Contract
-- Abstract interface for multi-generation game state normalization.

local BaseAdapter = {}
BaseAdapter.__index = BaseAdapter

function BaseAdapter.new(game)
  local self = setmetatable({}, BaseAdapter)
  self.game = game
  return self
end

-- Normalized party pokemon accessor
function BaseAdapter:getParty()
  local party = (self.game and self.game.save and self.game.save.party) or {}
  local list = {}
  for i, mon in ipairs(party) do
    list[#list + 1] = self:normalizeMon(mon, i)
  end
  return list
end

function BaseAdapter:getMon(index)
  local party = (self.game and self.game.save and self.game.save.party) or {}
  local mon = party[index]
  return mon and self:normalizeMon(mon, index) or nil
end

function BaseAdapter:normalizeMon(mon, index)
  if not mon then return nil end
  local data = (self.game and self.game.data) or {}
  local speciesId = mon.species or "UNKNOWN"
  local def = data.pokemon and data.pokemon[speciesId]
  local stats = mon.stats or {}

  return {
    index = index,
    speciesId = speciesId,
    displayName = (def and def.name) or speciesId,
    nickname = mon.nickname or (def and def.name) or speciesId,
    level = mon.level or 1,
    currentHp = mon.hp or 0,
    maxHp = stats.hp or mon.maxHp or mon.hp or 1,
    status = mon.status,
    types = (def and def.types) or { "NORMAL" },
    heldItem = mon.heldItem or mon.item,
    ability = mon.ability,
    nature = mon.nature,
    isShiny = mon.isShiny or false,
    stats = stats,
    moves = mon.moves or {},
    raw = mon,
  }
end

--- Resolves the badge count across all Gen 1-3 save formats, inventories, flags, and mod tables.
--- @param save table|nil
--- @param game table|nil
--- @return number
function BaseAdapter.resolveBadgeCount(save, game)
  if not save then return 0 end

  -- 1. Direct numeric badge count
  if type(save.badges) == "number" then
    return save.badges
  end
  if save.player and type(save.player.badges) == "number" then
    return save.player.badges
  end

  -- 2. Engine Badges module (Gen 1 recomp)
  local okBadges, Badges = pcall(require, "src.inventory.Badges")
  if okBadges and Badges and Badges.count then
    local cnt = Badges.count(game and game.data, save)
    if cnt and cnt > 0 then return cnt end
  end

  -- 3. Check save.inventory (Standard Gen 1 / Rom hacks badge storage)
  local inv = save.inventory or (save.player and save.player.inventory)
  if type(inv) == "table" then
    local count = 0
    local kantoBadges = {
      BOULDERBADGE = true, CASCADEBADGE = true, THUNDERBADGE = true, RAINBOWBADGE = true,
      SOULBADGE = true, MARSHBADGE = true, VOLCANOBADGE = true, EARTHBADGE = true,
    }
    local seen = {}
    for k, v in pairs(inv) do
      if v and v ~= 0 and v ~= false then
        local uk = tostring(k):upper()
        if kantoBadges[uk] or uk:find("BADGE") then
          if not seen[uk] then
            seen[uk] = true
            count = count + 1
          end
        end
      end
    end
    if count > 0 then return count end
  end

  -- 4. Check Gen 2 Johto / Kanto badge tables (in save or save.player)
  local jCount = 0
  local kCount = 0
  local jTable = save.johtoBadges or (save.player and save.player.badges) or save.badges
  local kTable = save.kantoBadges or (save.player and save.player.kantoBadges)
  if type(jTable) == "table" then
    for _, b in pairs(jTable) do if b and b ~= 0 and b ~= false then jCount = jCount + 1 end end
  end
  if type(kTable) == "table" then
    for _, b in pairs(kTable) do if b and b ~= 0 and b ~= false then kCount = kCount + 1 end end
  end
  if (jCount + kCount) > 0 then
    return jCount + kCount
  end

  -- 5. Check badges table in save or player
  local bTable = save.badges or (save.player and save.player.badges)
  if type(bTable) == "table" then
    local count = 0
    for _, v in pairs(bTable) do
      if v and v ~= 0 and v ~= false then
        count = count + 1
      end
    end
    if count > 0 then return count end
  end

  -- 6. Check flags in save
  local flags = save.flags or (save.player and save.player.flags)
  if type(flags) == "table" then
    local count = 0
    for k, v in pairs(flags) do
      if v and v ~= 0 and v ~= false and tostring(k):upper():find("BADGE") then
        count = count + 1
      end
    end
    if count > 0 then return count end
  end

  return 0
end

-- Normalized player profile info
function BaseAdapter:getPlayerInfo()
  local save = self.game and self.game.save or {}
  local player = save.player or {}
  
  local rawTime = save.playTime or save.time or (player and player.playTime) or 0
  local hours, minutes, seconds, t = 0, 0, 0, 0
  if type(rawTime) == "number" then
    t = math.floor(rawTime)
    hours = math.floor(t / 3600)
    minutes = math.floor((t % 3600) / 60)
    seconds = t % 60
  elseif type(rawTime) == "table" then
    hours = tonumber(rawTime.hours or rawTime.h or rawTime[1]) or 0
    minutes = tonumber(rawTime.minutes or rawTime.m or rawTime[2]) or 0
    seconds = tonumber(rawTime.seconds or rawTime.s or rawTime[3]) or 0
    t = hours * 3600 + minutes * 60 + seconds
  end

  local locationName = "KANTO"
  local ow = self.game and self.game.overworld
  local mapId = (ow and ow.map and ow.map.id) or (ow and ow.mapId) or save.map
  if mapId then
    local data = self.game and self.game.data
    local mapDef = data and data.maps and data.maps[mapId]
    if mapDef and mapDef.name then
      locationName = mapDef.name
    else
      locationName = tostring(mapId):gsub("_", " "):upper()
    end
  end

  return {
    name = player.name or save.playerName or save.name or "TRAINER",
    id = player.id or save.playerID or save.trainerId or save.id or 0,
    money = tonumber(save.money or (player and player.money)) or 0,
    playTime = { hours = hours, minutes = minutes, seconds = seconds, totalSeconds = t },
    playTimeString = ("%02d:%02d"):format(hours, minutes),
    badges = BaseAdapter.resolveBadgeCount(save, self.game),
    maxBadges = 8,
    region = "KANTO",
    location = locationName,
    pokedex = self:getPokedexCounts(),
    gender = save.gender or (player and player.gender) or "MALE",
  }
end

-- Normalized pokedex seen/owned counts
function BaseAdapter:getPokedexCounts()
  local save = self.game and self.game.save or {}
  local dex = save.pokedex or {}
  local seenCount = 0
  local ownedCount = 0

  if type(dex.seen) == "table" then
    for _ in pairs(dex.seen) do seenCount = seenCount + 1 end
  elseif type(dex.seen) == "number" then
    seenCount = dex.seen
  end

  local ownedTbl = dex.owned or dex.caught
  if type(ownedTbl) == "table" then
    for _ in pairs(ownedTbl) do ownedCount = ownedCount + 1 end
  elseif type(ownedTbl) == "number" then
    ownedCount = ownedTbl
  end

  return {
    seen = seenCount,
    owned = ownedCount,
  }
end

function BaseAdapter:hasSeen(speciesId)
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

function BaseAdapter:hasCaught(speciesId)
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

function BaseAdapter:isNationalDexUnlocked()
  return false
end

-- Normalized Safari / Contest info
function BaseAdapter:getSafariInfo()
  local save = self.game and self.game.save or {}
  local safari = save.safari
  if not safari or safari.active ~= true then return nil end
  return {
    active = true,
    steps = safari.steps or 0,
    maxSteps = safari.maxSteps or 500,
    balls = safari.balls or 0,
  }
end

-- Normalized Start Menu items contract
function BaseAdapter:getStartMenuItems()
  return {
    { id = "pokedex", label = "POKéDEX" },
    { id = "pokemon", label = "POKéMON" },
    { id = "item", label = "ITEM" },
    { id = "trainer", label = (self.game and self.game.save and self.game.save.playerName) or "TRAINER" },
    { id = "save", label = "SAVE" },
    { id = "option", label = "OPTION" },
    { id = "exit", label = "EXIT" },
  }
end

-- Persistent Zero-Allocation Battle Cache Initialization
function BaseAdapter:initBattleCache()
  local function createBattlerSlot()
    return {
      active = false,
      species = "",
      name = "",
      level = 1,
      hp = 0,
      maxHp = 1,
      shownHp = 0,
      shownPx = 0,
      hpRatio = 1.0,
      exp = 0,
      maxExp = 1,
      expRatio = 0.0,
      status = nil,
      shownStatus = nil,
      types = { "NORMAL" },
      heldItem = nil,
      ability = nil,
      gender = nil,
      isShiny = false,
      isCaught = false,
      statStages = { attack = 0, defense = 0, speed = 0, special = 0 },
      partyBalls = { "empty", "empty", "empty", "empty", "empty", "empty" },
    }
  end

  local function createMoveSlot()
    return {
      id = "",
      name = "--",
      type = "NORMAL",
      category = "PHYSICAL",
      pp = 0,
      maxPP = 0,
      power = 0,
      accuracy = 100,
      effectiveness = 1.0,
      isFixedDamage = false,
      description = "",
      note = "",
    }
  end

  self._battleCache = {
    revision = 0,
    signature = "",
    isActive = false,
    isDouble = false,
    phase = "action_select", -- "action_select", "move_select", "target_select", "bag", "party", "message", "anim", "ended"
    selectedAction = 1,
    selectedMove = 1,
    selectedTarget = 1,
    validTargets = {},
    player = createBattlerSlot(),
    player2 = createBattlerSlot(),
    enemy = createBattlerSlot(),
    enemy2 = createBattlerSlot(),
    moves = { createMoveSlot(), createMoveSlot(), createMoveSlot(), createMoveSlot() },
    actions = {
      { id = "FIGHT", label = "FIGHT", key = "A", kind = "primary" },
      { id = "BAG", label = "BAG", key = "X", kind = "accent" },
      { id = "POKEMON", label = "POKEMON", key = "Y", kind = "ghost" },
      { id = "RUN", label = "RUN", key = "B", kind = "danger" },
    },
    message = "",
    waitingForA = false,
    canRun = true,
    weather = nil,
  }
  return self._battleCache
end

function BaseAdapter:getBattleCache()
  if not self._battleCache then self:initBattleCache() end
  return self._battleCache
end

function BaseAdapter:getActiveBattle()
  local states = (self.game and self.game.stack and self.game.stack.states) or {}
  for i = #states, 1, -1 do
    local s = states[i]
    if s and (s.isBattleState or s.isBattle or s.isGen2BattleState or s.screenId == "BattleState" or s.screenId == "Gen2BattleState") then
      return s, states[#states]
    end
  end
  return nil, nil
end

function BaseAdapter:updateBattleInfo(outCache)
  local cache = outCache or self:getBattleCache()
  local battle, topState = self:getActiveBattle()
  if not battle then
    cache.isActive = false
    return cache
  end

  cache.isActive = true
  return cache
end

-- Normalized Storage System (Bill's PC & Player PC) Contracts
function BaseAdapter:getBoxCount()
  return 12
end

function BaseAdapter:getBoxCapacity()
  return 20
end

function BaseAdapter:getCurrentBox()
  local save = self.game and self.game.save
  return (save and save.currentBox) or 1
end

function BaseAdapter:setCurrentBox(boxId)
  local save = self.game and self.game.save
  if save then
    save.currentBox = math.max(1, math.min(self:getBoxCount(), boxId or 1))
    return true
  end
  return false
end

function BaseAdapter:getBoxName(boxId)
  return ("BOX %d"):format(boxId or self:getCurrentBox())
end

function BaseAdapter:setBoxName(boxId, name)
  return false
end

function BaseAdapter:getBoxData(boxId)
  return {}
end

function BaseAdapter:getPartyCapacity()
  return 6
end

function BaseAdapter:getPartyData()
  return self:getParty()
end

function BaseAdapter:canDeposit(partySlot, targetBoxId)
  return false, "Not implemented"
end

function BaseAdapter:canWithdraw(boxId, boxSlot)
  return false, "Not implemented"
end

function BaseAdapter:depositMon(partySlot, targetBoxId, targetSlot)
  return false, "Not implemented"
end

function BaseAdapter:withdrawMon(boxId, boxSlot, targetPartySlot)
  return false, "Not implemented"
end

function BaseAdapter:swapSlots(sourceLoc, sourceSlot, targetLoc, targetSlot, sourceBoxId, targetBoxId)
  return false, "Not implemented"
end

function BaseAdapter:releaseMon(loc, slot, boxId)
  return false, "Not implemented"
end

function BaseAdapter:getItemStorage()
  return {}
end

function BaseAdapter:getBagItems()
  return {}
end

function BaseAdapter:withdrawItem(itemId, qty)
  return false, "Not implemented"
end

function BaseAdapter:depositItem(itemId, qty)
  return false, "Not implemented"
end

function BaseAdapter:getBagCapacity()
  local data = self.game and self.game.data or (require("src.core.Data"))
  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if okBag and Bag and Bag.capacity then
    local cap = Bag.capacity(data)
    if type(cap) == "number" and cap > 0 then return cap end
  end
  if data and data.constants and data.constants.bagSize then
    return math.floor(data.constants.bagSize)
  end
  if data and data.constants and data.constants.bagCapacity then
    return math.floor(data.constants.bagCapacity)
  end
  if okBag and Bag and Bag.CAPACITY then
    return Bag.CAPACITY
  end
  return 20
end

function BaseAdapter:getPcCapacity()
  local data = self.game and self.game.data or (require("src.core.Data"))
  if data and data.field and data.field.pcItemCap then
    return data.field.pcItemCap
  end
  if data and data.constants and data.constants.pcItemCap then
    return data.constants.pcItemCap
  end
  return 50
end

function BaseAdapter:getMonStats(mon, def)
  local StatResolver = require("mods.omni_ui.core.StatResolver")
  return StatResolver.getStats(mon, def, self.game)
end

function BaseAdapter:getDexEntry(speciesId)
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

  local dexNum = (def and def.dex) or (type(speciesId) == "number" and speciesId) or 1
  local name = (def and (def.name or def.species)) or tostring(speciesId or "POKÉMON"):upper()
  local types = (def and def.types) or { "NORMAL" }

  local dexEntry = def and def.dexEntry or {}
  local kind = dexEntry.kind or dexEntry.species or (def and def.kind) or ""

  -- Format height
  local heightStr = "---"
  if dexEntry.heightFt ~= nil then
    heightStr = ("%d'%02d\""):format(dexEntry.heightFt or 0, dexEntry.heightIn or 0)
  elseif dexEntry.heightM ~= nil then
    heightStr = ("%.1f m"):format(dexEntry.heightM)
  elseif type(dexEntry.height) == "number" then
    local ft = math.floor(dexEntry.height / 12)
    local inch = dexEntry.height % 12
    heightStr = ("%d'%02d\""):format(ft, inch)
  elseif type(dexEntry.height) == "table" then
    heightStr = ("%d'%02d\""):format(dexEntry.height[1] or 0, dexEntry.height[2] or 0)
  end

  -- Format weight
  local weightStr = "---"
  if dexEntry.weightKg ~= nil then
    weightStr = ("%.1f kg"):format(dexEntry.weightKg)
  elseif type(dexEntry.weight) == "number" then
    if dexEntry.weight >= 10 then
      weightStr = ("%.1f lbs"):format(dexEntry.weight / 10)
    else
      weightStr = ("%d lbs"):format(dexEntry.weight)
    end
  end

  -- Format description
  local desc = dexEntry.description
  if not desc and dexEntry.text and data.text then
    desc = data.text[dexEntry.text]
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

function BaseAdapter:getAreaInfo(speciesId, requestedRegion)
  local data = self.game and self.game.data or {}
  local enc = data.encounters or {}
  local nests = {}
  local seen = {}

  for mapId, mapEnc in pairs(enc) do
    local hasSpecies = false
    if mapEnc.grass and mapEnc.grass.slots then
      for _, s in ipairs(mapEnc.grass.slots) do
        if s.species == speciesId then hasSpecies = true break end
      end
    end
    if not hasSpecies and mapEnc.water and mapEnc.water.slots then
      for _, s in ipairs(mapEnc.water.slots) do
        if s.species == speciesId then hasSpecies = true break end
      end
    end

    if hasSpecies and not seen[mapId] then
      seen[mapId] = true
      nests[#nests + 1] = {
        id = mapId,
        name = mapId:gsub("_", " "),
        mapId = mapId,
      }
    end
  end

  return {
    region = "kanto",
    canSwapRegion = false,
    availableRegions = { "kanto" },
    nests = nests,
  }
end

--- Attach modern input controllers and navigation hooks to a screen state.
function BaseAdapter:attachControls(state, kind)
  local okMO, ModernOverlay = pcall(require, "mods.omni_ui.core.ModernOverlay")
  if okMO and ModernOverlay and ModernOverlay.attachControls then
    ModernOverlay.attachControls(state, self.game)
  end
end

--- Attaches dialogue / message controls tailored to the active generation.
function BaseAdapter:attachDialogueControls(state)
  if not state or state.isTextBox then return end
  local okMO, ModernOverlay = pcall(require, "mods.omni_ui.core.ModernOverlay")
  if okMO and ModernOverlay and ModernOverlay.attachDialogueControls then
    ModernOverlay.attachDialogueControls(state, self.game)
  end
end

return BaseAdapter

