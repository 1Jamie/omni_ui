-- OmniUI Pokédex Advanced Search, Filter & Sort Controller
-- Unified multi-generation search engine supporting Regional/National sorting,
-- A-Z, Dual Type filtering, Caught/Seen status filtering, Height/Weight sorting,
-- and live real-time query searching across Gen 1, Gen 2, Gen 3, and modded Pokédexes.

local TypeChart = pcall(require, "src.battle.TypeChart") and require("src.battle.TypeChart") or nil

local PokedexFilter = {}

PokedexFilter.SORT_MODES = {
  { id = "REGIONAL", label = "REGIONAL DEX", desc = "Listed in regional Pokédex numerical order." },
  { id = "NATIONAL", label = "NATIONAL DEX", desc = "Listed in canonical National Pokédex order (#001-#386+)." },
  { id = "NAME_AZ",  label = "NAME (A - Z)", desc = "Alphabetical order by species name." },
  { id = "NAME_ZA",  label = "NAME (Z - A)", desc = "Reverse alphabetical order by species name." },
  { id = "TYPE",     label = "PRIMARY TYPE", desc = "Grouped by elemental type classification." },
  { id = "STATUS",   label = "CAUGHT FIRST", desc = "Owned species first, followed by seen and unknown." },
  { id = "HEAVIEST", label = "HEAVIEST",     desc = "Sorted from greatest to least recorded weight." },
  { id = "LIGHTEST", label = "LIGHTEST",     desc = "Sorted from least to greatest recorded weight." },
  { id = "TALLEST",  label = "TALLEST",      desc = "Sorted from greatest to least recorded height." },
  { id = "SHORTEST", label = "SHORTEST",     desc = "Sorted from least to greatest recorded height." },
}

PokedexFilter.FILTER_MODES = {
  { id = "ALL",      label = "ALL SPECIES",  desc = "Show all registered species entries." },
  { id = "CAUGHT",   label = "CAUGHT ONLY",  desc = "Show only Pokémon you have captured." },
  { id = "SEEN",     label = "SEEN ONLY",    desc = "Show only Pokémon you have seen." },
  { id = "UNCAUGHT", label = "UNCAUGHT",     desc = "Show species seen in battle but not yet captured." },
  { id = "UNSEEN",   label = "UNSEEN / ???", desc = "Show uncharted species slots." },
  { id = "TYPE",     label = "BY TYPE...",   desc = "Filter species by elemental type affinity." },
}

PokedexFilter.TYPES = {
  "NORMAL", "FIRE", "WATER", "GRASS", "ELECTRIC", "ICE",
  "FIGHTING", "POISON", "GROUND", "FLYING", "PSYCHIC", "BUG",
  "ROCK", "GHOST", "DRAGON", "STEEL", "DARK", "FAIRY"
}

function PokedexFilter.getAvailableSortModes(adapter)
  local isNatUnlocked = (adapter and adapter.isNationalDexUnlocked and adapter:isNationalDexUnlocked())
  if isNatUnlocked == nil then isNatUnlocked = true end
  local list = {}
  for _, m in ipairs(PokedexFilter.SORT_MODES) do
    if m.id == "NATIONAL" then
      if isNatUnlocked then list[#list + 1] = m end
    else
      list[#list + 1] = m
    end
  end
  return list
end

-- Check seen / caught status across any generation save format
local function checkStatus(dex, def, dexNum, speciesKey, adapter)
  if adapter and adapter.hasSeen then
    local sp = speciesKey or (def and (def.id or def.species)) or dexNum
    local isSeen = adapter:hasSeen(sp)
    local isOwned = adapter:hasCaught(sp)
    if isSeen or isOwned then
      return isSeen or isOwned, isOwned
    end
  end

  if not dex then return false, false end
  local seenTbl = dex.seen or {}
  local ownedTbl = dex.owned or dex.caught or {}

  local isSeen = false
  local isOwned = false

  if dexNum then
    if seenTbl[dexNum] == true then isSeen = true end
    if ownedTbl[dexNum] == true then isOwned = true end
  end

  local keys = {
    speciesKey,
    def and def.id,
    def and def.species,
    def and def.name,
  }
  for _, k in ipairs(keys) do
    if k and k ~= "" then
      if seenTbl[k] == true then isSeen = true end
      if ownedTbl[k] == true then isOwned = true end
      local upK = tostring(k):upper()
      if seenTbl[upK] == true then isSeen = true end
      if ownedTbl[upK] == true then isOwned = true end
    end
  end

  if isOwned then isSeen = true end
  return isSeen, isOwned
end

-- Parse numerical weight for sorting (standardized in 0.1 lbs or integer grams)
local function getWeightValue(entryData)
  if not entryData then return 0 end
  if entryData.weightKg then return entryData.weightKg * 22 end
  if type(entryData.weight) == "number" then return entryData.weight end
  local num = tostring(entryData.weight or ""):match("(%d+%.?%d*)")
  return tonumber(num) or 0
end

-- Parse numerical height for sorting (standardized in total inches)
local function getHeightValue(entryData)
  if not entryData then return 0 end
  if entryData.heightFt ~= nil then
    return (entryData.heightFt or 0) * 12 + (entryData.heightIn or 0)
  end
  if entryData.heightM ~= nil then return entryData.heightM * 39.37 end
  if type(entryData.height) == "number" then
    if entryData.height >= 100 then
      return math.floor(entryData.height / 100) * 12 + (entryData.height % 100)
    end
    return entryData.height
  end
  local ft, inch = tostring(entryData.height or ""):match("(%d+)'(%d+)")
  if ft and inch then return tonumber(ft) * 12 + tonumber(inch) end
  return 0
end

-- Clean type names (strips _TYPE suffix if present)
local function sanitizeType(t)
  if not t then return "NORMAL" end
  return tostring(t):upper():gsub("_TYPE$", "")
end

-- Build normalized species list and apply active sort, filter, and search query
function PokedexFilter.buildRows(game, state, adapter, opts)
  opts = opts or {}
  local rseSortMap = {
    [0] = (state.dexMode == 1) and "NATIONAL" or "REGIONAL",
    [1] = "NAME_AZ",
    [2] = "HEAVIEST",
    [3] = "LIGHTEST",
    [4] = "TALLEST",
    [5] = "SMALLEST",
  }
  local defaultSort = (state.dexOrder ~= nil and rseSortMap[state.dexOrder]) or (state.dexMode == 1 and "NATIONAL") or "REGIONAL"
  local sortMode = opts.sortMode or state._dexSortMode or defaultSort
  local filterMode = opts.filterMode or state._dexFilterMode or "ALL"
  local typeFilter = opts.typeFilter or state._dexTypeFilter or nil
  local query = (opts.query or state._dexSearchQuery or ""):match("^%s*(.-)%s*$"):upper()

  local isNatUnlocked = (adapter and adapter.isNationalDexUnlocked and adapter:isNationalDexUnlocked())
  if isNatUnlocked == nil then isNatUnlocked = true end
  if not isNatUnlocked and sortMode == "NATIONAL" then
    sortMode = "REGIONAL"
  end

  local dex = (adapter and adapter.getDex and adapter:getDex())
    or (game and game.save and (game.save.pokedex or game.save.dex or (game.save.session and game.save.session.dex)))
    or { seen = {}, owned = {} }
  local data = game and game.data or {}
  local pokemon = data.pokemon or {}
  local gen2Pokedex = data.gen2Pokedex or data.pokedex or {}

  -- 1. Gather all species records
  local baseList = {}
  local seenKeys = {}

  if adapter and adapter.generation == 3 then
    local isHoenn = (adapter.region == "HOENN")
    if isHoenn and sortMode == "REGIONAL" then
      local maxHoenn = 202
      local maxSeen = 1
      for regNo = 1, maxHoenn do
        local sp = adapter:regionalToSpecies(regNo)
        if sp then
          local entryData = adapter:getDexEntry(sp)
          local isSeen, isOwned = checkStatus(dex, entryData.def or entryData, regNo, sp, adapter)
          if isSeen and regNo > maxSeen then maxSeen = regNo end

          local rawTypes = (entryData and entryData.types) or { "NORMAL" }
          local cleanTypes = {}
          for _, t in ipairs(rawTypes) do cleanTypes[#cleanTypes + 1] = sanitizeType(t) end

          baseList[#baseList + 1] = {
            origIdx = regNo,
            regionalDex = regNo,
            nationalDex = adapter:speciesToNational(sp) or regNo,
            species = sp,
            speciesId = sp,
            name = (entryData and entryData.name) or tostring(sp),
            types = cleanTypes,
            entryData = entryData,
            seen = isSeen,
            caught = isOwned,
          }
        end
      end
      if (opts.clampToMaxSeen or state._clampToMaxSeen) and not isNatUnlocked then
        local clamped = {}
        for _, it in ipairs(baseList) do
          if (it.regionalDex or 0) <= maxSeen then clamped[#clamped + 1] = it end
        end
        baseList = clamped
      end
    elseif not isHoenn and sortMode == "REGIONAL" then
      local maxKanto = 151
      local maxSeen = 1
      for regNo = 1, maxKanto do
        local sp = adapter:regionalToSpecies(regNo) or regNo
        local entryData = adapter:getDexEntry(sp)
        local isSeen, isOwned = checkStatus(dex, entryData.def or entryData, regNo, sp, adapter)
        if isSeen and regNo > maxSeen then maxSeen = regNo end

        local rawTypes = (entryData and entryData.types) or { "NORMAL" }
        local cleanTypes = {}
        for _, t in ipairs(rawTypes) do cleanTypes[#cleanTypes + 1] = sanitizeType(t) end

        baseList[#baseList + 1] = {
          origIdx = regNo,
          regionalDex = regNo,
          nationalDex = adapter:speciesToNational(sp) or regNo,
          species = sp,
          speciesId = sp,
          name = (entryData and entryData.name) or tostring(sp),
          types = cleanTypes,
          entryData = entryData,
          seen = isSeen,
          caught = isOwned,
        }
      end
      if (opts.clampToMaxSeen or state._clampToMaxSeen) and not isNatUnlocked then
        local clamped = {}
        for _, it in ipairs(baseList) do
          if (it.regionalDex or 0) <= maxSeen then clamped[#clamped + 1] = it end
        end
        baseList = clamped
      end
    else
      -- National Dex mode in Gen 3 (1..386)
      local maxNat = isNatUnlocked and 386 or (isHoenn and 202 or 151)
      local maxSeen = 1
      for natNo = 1, maxNat do
        local sp = adapter:nationalToSpecies(natNo) or natNo
        local entryData = adapter:getDexEntry(sp)
        local isSeen, isOwned = checkStatus(dex, entryData.def or entryData, natNo, sp, adapter)
        if isSeen and natNo > maxSeen then maxSeen = natNo end

        local rawTypes = (entryData and entryData.types) or { "NORMAL" }
        local cleanTypes = {}
        for _, t in ipairs(rawTypes) do cleanTypes[#cleanTypes + 1] = sanitizeType(t) end

        baseList[#baseList + 1] = {
          origIdx = natNo,
          regionalDex = adapter:speciesToRegional(sp) or natNo,
          nationalDex = natNo,
          species = sp,
          speciesId = sp,
          name = (entryData and entryData.name) or tostring(sp),
          types = cleanTypes,
          entryData = entryData,
          seen = isSeen,
          caught = isOwned,
        }
      end
      if (opts.clampToMaxSeen or state._clampToMaxSeen) and not isNatUnlocked then
        local clamped = {}
        for _, it in ipairs(baseList) do
          if (it.nationalDex or 0) <= maxSeen then clamped[#clamped + 1] = it end
        end
        baseList = clamped
      end
    end
  elseif type(state.rows) == "table" and #state.rows > 0 then
    -- Check native Gen 2 rows if present
    for idx, r in ipairs(state.rows) do
      local spKey = r.species or r.dex
      local entryData = adapter:getDexEntry(spKey)
      local isSeen, isOwned = checkStatus(dex, entryData.def or entryData, r.dex or idx, spKey, adapter)
      if r.seen ~= nil then isSeen = (r.seen == true) end
      if r.caught ~= nil then isOwned = (r.caught == true) end

      local rawTypes = (entryData and entryData.types) or { "NORMAL" }
      local cleanTypes = {}
      for _, t in ipairs(rawTypes) do cleanTypes[#cleanTypes + 1] = sanitizeType(t) end

      baseList[#baseList + 1] = {
        origIdx = idx,
        regionalDex = idx,
        nationalDex = r.dex or (entryData.dex or idx),
        species = spKey,
        speciesId = spKey,
        name = (entryData and entryData.name) or tostring(spKey),
        types = cleanTypes,
        entryData = entryData,
        seen = isSeen,
        caught = isOwned,
      }
      seenKeys[tostring(spKey):upper()] = true
    end
  elseif gen2Pokedex.newOrder and #gen2Pokedex.newOrder > 0 then
    -- Gen 2 newOrder table
    for idx, spKey in ipairs(gen2Pokedex.newOrder) do
      local entryData = adapter:getDexEntry(spKey)
      local isSeen, isOwned = checkStatus(dex, entryData.def or entryData, entryData.dex or idx, spKey, adapter)

      local rawTypes = (entryData and entryData.types) or { "NORMAL" }
      local cleanTypes = {}
      for _, t in ipairs(rawTypes) do cleanTypes[#cleanTypes + 1] = sanitizeType(t) end

      baseList[#baseList + 1] = {
        origIdx = idx,
        regionalDex = idx,
        nationalDex = entryData.dex or idx,
        species = spKey,
        speciesId = spKey,
        name = (entryData and entryData.name) or tostring(spKey),
        types = cleanTypes,
        entryData = entryData,
        seen = isSeen,
        caught = isOwned,
      }
      seenKeys[tostring(spKey):upper()] = true
    end
  else
    -- Standard sequential Pokédex (Gen 1 / custom mods)
    local maxDex = (adapter.region == "JOHTO") and 251 or 151
    if data.constants and data.constants.dexSize then
      maxDex = math.max(maxDex, data.constants.dexSize)
    end
    if state.items and #state.items > 0 then
      maxDex = math.max(maxDex, #state.items)
    end
    for k, d in pairs(pokemon) do
      if type(d) == "table" and type(d.dex) == "number" and d.dex > maxDex then
        maxDex = d.dex
      end
    end

    local maxSeen = 1
    for idx = 1, maxDex do
      local spKey = idx
      for k, d in pairs(pokemon) do
        if type(d) == "table" and d.dex == idx then
          spKey = k
          break
        end
      end
      local entryData = adapter:getDexEntry(spKey)
      local isSeen, isOwned = checkStatus(dex, entryData.def or entryData, idx, spKey, adapter)
      if isSeen and idx > maxSeen then maxSeen = idx end

      local rawTypes = (entryData and entryData.types) or { "NORMAL" }
      local cleanTypes = {}
      for _, t in ipairs(rawTypes) do cleanTypes[#cleanTypes + 1] = sanitizeType(t) end

      baseList[#baseList + 1] = {
        origIdx = idx,
        regionalDex = idx,
        nationalDex = entryData.dex or idx,
        species = spKey,
        speciesId = spKey,
        name = (entryData and entryData.name) or tostring(spKey),
        types = cleanTypes,
        entryData = entryData,
        seen = isSeen,
        caught = isOwned,
      }
    end
    if (opts.clampToMaxSeen or state._clampToMaxSeen) and not isNatUnlocked then
      local clamped = {}
      for _, it in ipairs(baseList) do
        if (it.regionalDex or 0) <= maxSeen then clamped[#clamped + 1] = it end
      end
      baseList = clamped
    end
  end

  -- 2. Filter species
  local filtered = {}
  for _, item in ipairs(baseList) do
    local matchesFilter = true

    if filterMode == "CAUGHT" then
      matchesFilter = item.caught == true
    elseif filterMode == "SEEN" then
      matchesFilter = item.seen == true
    elseif filterMode == "UNCAUGHT" then
      matchesFilter = item.seen == true and item.caught ~= true
    elseif filterMode == "UNSEEN" then
      matchesFilter = item.seen ~= true
    elseif filterMode == "TYPE" and typeFilter then
      local hasType = false
      if item.seen == true then
        for _, t in ipairs(item.types or {}) do
          if sanitizeType(t) == sanitizeType(typeFilter) then hasType = true break end
        end
      end
      matchesFilter = hasType
    end

    -- Text / Query search (matches seen species names, types, or exact 3-digit dex number)
    if matchesFilter and query ~= "" then
      local nameMatch = (item.seen == true) and (item.name:upper():find(query, 1, true) ~= nil)
      local numMatch = (tostring(item.nationalDex) == query) or (tostring(item.regionalDex) == query) or (("%03d"):format(item.nationalDex) == query) or (("%03d"):format(item.regionalDex) == query)
      local typeMatch = false
      if item.seen == true then
        for _, t in ipairs(item.types or {}) do
          local cleanT = sanitizeType(t)
          if cleanT == query or cleanT:find(query, 1, true) ~= nil then
            typeMatch = true
            break
          end
        end
      end
      matchesFilter = nameMatch or numMatch or typeMatch
    end

    if matchesFilter then
      filtered[#filtered + 1] = item
    end
  end

  -- 3. Sort species
  table.sort(filtered, function(a, b)
    if sortMode == "NATIONAL" then
      return (a.nationalDex or 0) < (b.nationalDex or 0)
    elseif sortMode == "NAME_AZ" then
      if a.seen ~= b.seen then return a.seen and not b.seen end
      return (a.name or "") < (b.name or "")
    elseif sortMode == "NAME_ZA" then
      if a.seen ~= b.seen then return a.seen and not b.seen end
      return (a.name or "") > (b.name or "")
    elseif sortMode == "TYPE" then
      if a.seen ~= b.seen then return a.seen and not b.seen end
      local tA = (a.types and a.types[1]) or "ZZZ"
      local tB = (b.types and b.types[1]) or "ZZZ"
      if tA ~= tB then return tA < tB end
      return (a.regionalDex or 0) < (b.regionalDex or 0)
    elseif sortMode == "STATUS" then
      local rankA = a.caught and 3 or (a.seen and 2 or 1)
      local rankB = b.caught and 3 or (b.seen and 2 or 1)
      if rankA ~= rankB then return rankA > rankB end
      return (a.regionalDex or 0) < (b.regionalDex or 0)
    elseif sortMode == "HEAVIEST" then
      if a.caught ~= b.caught then return a.caught and not b.caught end
      local wA = a.caught and getWeightValue(a.entryData) or -1
      local wB = b.caught and getWeightValue(b.entryData) or -1
      if wA ~= wB then return wA > wB end
      return (a.regionalDex or 0) < (b.regionalDex or 0)
    elseif sortMode == "LIGHTEST" then
      if a.caught ~= b.caught then return a.caught and not b.caught end
      local wA = a.caught and getWeightValue(a.entryData) or 999999
      local wB = b.caught and getWeightValue(b.entryData) or 999999
      if wA ~= wB then return wA < wB end
      return (a.regionalDex or 0) < (b.regionalDex or 0)
    elseif sortMode == "TALLEST" then
      if a.caught ~= b.caught then return a.caught and not b.caught end
      local hA = a.caught and getHeightValue(a.entryData) or -1
      local hB = b.caught and getHeightValue(b.entryData) or -1
      if hA ~= hB then return hA > hB end
      return (a.regionalDex or 0) < (b.regionalDex or 0)
    elseif sortMode == "SHORTEST" then
      if a.caught ~= b.caught then return a.caught and not b.caught end
      local hA = a.caught and getHeightValue(a.entryData) or 999999
      local hB = b.caught and getHeightValue(b.entryData) or 999999
      if hA ~= hB then return hA < hB end
      return (a.regionalDex or 0) < (b.regionalDex or 0)
    else -- REGIONAL default
      return (a.regionalDex or 0) < (b.regionalDex or 0)
    end
  end)

  -- Assign display numbering
  for idx, row in ipairs(filtered) do
    if sortMode == "NATIONAL" then
      row.displayNum = row.nationalDex
    elseif sortMode == "REGIONAL" then
      row.displayNum = row.regionalDex
    else
      row.displayNum = idx
    end
  end

  return filtered, #baseList
end

-- Launch Authentic In-Game Virtual Keyboard (NamingScreen / Gen2NamingScreen)
function PokedexFilter.openTextEntry(state, game)
  if not state then return false end
  local g = game or state.game
  if not g or not g.stack then return false end

  local curQuery = state._dexSearchQuery or ""
  local maxLen = 10

  local inst
  local function onConfirm(name)
    if inst and g.stack and g.stack.top and g.stack:top() == inst then
      g.stack:pop()
    end
    state._dexSearchQuery = (name or ""):match("^%s*(.-)%s*$")
    state.index = 1
    state.scroll = 0
    if state.ensureVisible then state:ensureVisible() end
  end

  local function onCancel()
    if inst and g.stack and g.stack.top and g.stack:top() == inst then
      g.stack:pop()
    end
  end

  local isGen2 = (g.data and (g.data.gen2 or g.data.gen2Pokedex or g.data.gen2Sprites or g.data.gen2MenuGfx))
    or (state.isGen2 or (type(state.rows) == "table" and state.rows[1] and state.rows[1].mon))

  local Screens = pcall(require, "src.ui.Screens") and require("src.ui.Screens") or nil

  if isGen2 then
    local data = g.data or {}
    if Screens and pcall(Screens.get, g, "Gen2NamingScreen") then
      inst = Screens.push(g, "Gen2NamingScreen", {
        type = "player",
        prompt = "SEARCH POKÉDEX",
        maxLength = maxLen,
        initial = curQuery,
        menuGfx = data.gen2MenuGfx,
        onDone = function(name)
          onConfirm(name)
        end,
        onCancel = onCancel,
      })
      return true
    else
      local ok, Gen2Naming = pcall(require, "src.ui.gen2.NamingScreen")
      if ok and Gen2Naming then
        inst = Gen2Naming.new(g, {
          type = "player",
          prompt = "SEARCH POKÉDEX",
          maxLength = maxLen,
          initial = curQuery,
          menuGfx = data.gen2MenuGfx,
          onDone = function(name)
            onConfirm(name)
          end,
          onCancel = onCancel,
        })
        g.stack:push(inst)
        return true
      end
    end
  end

  -- Fallback to Gen 1 NamingScreen
  if Screens and pcall(Screens.get, g, "NamingScreen") then
    inst = Screens.push(g, "NamingScreen", {
      title = "SEARCH POKÉDEX",
      maxLen = maxLen,
      default = curQuery,
      initial = curQuery,
      onDone = function(name)
        onConfirm(name)
      end,
    })
    return true
  else
    local ok, Naming = pcall(require, "src.ui.NamingScreen")
    if ok and Naming then
      inst = Naming.new(g, {
        title = "SEARCH POKÉDEX",
        maxLen = maxLen,
        default = curQuery,
        initial = curQuery,
        onDone = function(name)
          onConfirm(name)
        end,
      })
      g.stack:push(inst)
      return true
    end
  end

  return false
end

-- Handle 2D Spatial Grid Navigation in the Search & Sort Modal
function PokedexFilter.handleGridInput(state, game, input, isNarrow)
  if not state then return false end

  -- Support flexible calling forms: handleGridInput(state, "down") or handleGridInput(state, input) or handleGridInput(state, game, input, isNarrow)
  if input == nil and game ~= nil then
    input = game
    game = state.game or nil
  end
  if not input then return false end

  local wasPressed
  if type(input) == "table" and type(input.wasPressed) == "function" then
    wasPressed = function(k) return input:wasPressed(k) end
  elseif type(input) == "string" then
    local s = input:lower()
    wasPressed = function(k) return s == k:lower() end
  else
    return false
  end

  local adapter = (game and pcall(require, "mods.omni_ui.adapters.AdapterResolver") and require("mods.omni_ui.adapters.AdapterResolver").resolve(game)) or (state and state.adapter)
  local sortModes = PokedexFilter.getAvailableSortModes(adapter)
  local filterModes = PokedexFilter.FILTER_MODES
  local typeList = PokedexFilter.TYPES

  state._gridSection = state._gridSection or "sort"
  state._gridIndex = state._gridIndex or 1

  local sortCols = isNarrow and 2 or 4
  local filtCols = isNarrow and 2 or 6
  local typeCols = isNarrow and 6 or 9
  local hasTypes = (state._dexFilterMode == "TYPE")

  if wasPressed("left") then
    if state._gridSection == "sort" then
      state._gridIndex = (state._gridIndex > 1) and (state._gridIndex - 1) or #sortModes
    elseif state._gridSection == "filter" then
      state._gridIndex = (state._gridIndex > 1) and (state._gridIndex - 1) or #filterModes
    elseif state._gridSection == "type" then
      state._gridIndex = (state._gridIndex > 1) and (state._gridIndex - 1) or #typeList
    elseif state._gridSection == "search" then
      state._gridIndex = 1
    elseif state._gridSection == "actions" then
      state._gridIndex = (state._gridIndex > 1) and (state._gridIndex - 1) or 2
    end
    if game and game.data then pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end) end
    return true
  elseif wasPressed("right") then
    if state._gridSection == "sort" then
      state._gridIndex = (state._gridIndex < #sortModes) and (state._gridIndex + 1) or 1
    elseif state._gridSection == "filter" then
      state._gridIndex = (state._gridIndex < #filterModes) and (state._gridIndex + 1) or 1
    elseif state._gridSection == "type" then
      state._gridIndex = (state._gridIndex < #typeList) and (state._gridIndex + 1) or 1
    elseif state._gridSection == "search" then
      state._gridIndex = 1
    elseif state._gridSection == "actions" then
      state._gridIndex = (state._gridIndex < 2) and (state._gridIndex + 1) or 1
    end
    if game and game.data then pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end) end
    return true
  elseif wasPressed("down") then
    if state._gridSection == "sort" then
      local nextIdx = state._gridIndex + sortCols
      if nextIdx <= #sortModes then
        state._gridIndex = nextIdx
      else
        local col = (state._gridIndex - 1) % sortCols
        state._gridSection = "filter"
        state._gridIndex = math.min(#filterModes, (col % filtCols) + 1)
      end
    elseif state._gridSection == "filter" then
      local nextIdx = state._gridIndex + filtCols
      if nextIdx <= #filterModes then
        state._gridIndex = nextIdx
      else
        local col = (state._gridIndex - 1) % filtCols
        if hasTypes then
          state._gridSection = "type"
          state._gridIndex = math.min(#typeList, (col % typeCols) + 1)
        else
          state._gridSection = "search"
          state._gridIndex = 1
        end
      end
    elseif state._gridSection == "type" then
      local nextIdx = state._gridIndex + typeCols
      if nextIdx <= #typeList then
        state._gridIndex = nextIdx
      else
        state._gridSection = "search"
        state._gridIndex = 1
      end
    elseif state._gridSection == "search" then
      state._gridSection = "actions"
      state._gridIndex = 1
    elseif state._gridSection == "actions" then
      state._gridSection = "sort"
      state._gridIndex = (state._gridIndex == 1) and 1 or math.min(#sortModes, sortCols)
    end
    if game and game.data then pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end) end
    return true
  elseif wasPressed("up") then
    if state._gridSection == "sort" then
      local prevIdx = state._gridIndex - sortCols
      if prevIdx >= 1 then
        state._gridIndex = prevIdx
      else
        state._gridSection = "actions"
        state._gridIndex = ((state._gridIndex - 1) % sortCols >= math.floor(sortCols / 2)) and 2 or 1
      end
    elseif state._gridSection == "filter" then
      local prevIdx = state._gridIndex - filtCols
      if prevIdx >= 1 then
        state._gridIndex = prevIdx
      else
        local col = (state._gridIndex - 1) % filtCols
        state._gridSection = "sort"
        local lastRowStart = math.floor((#sortModes - 1) / sortCols) * sortCols
        state._gridIndex = math.min(#sortModes, lastRowStart + (col % sortCols) + 1)
      end
    elseif state._gridSection == "type" then
      local prevIdx = state._gridIndex - typeCols
      if prevIdx >= 1 then
        state._gridIndex = prevIdx
      else
        local col = (state._gridIndex - 1) % typeCols
        state._gridSection = "filter"
        local lastRowStart = math.floor((#filterModes - 1) / filtCols) * filtCols
        state._gridIndex = math.min(#filterModes, lastRowStart + (col % filtCols) + 1)
      end
    elseif state._gridSection == "search" then
      if hasTypes then
        state._gridSection = "type"
        local lastRowStart = math.floor((#typeList - 1) / typeCols) * typeCols
        state._gridIndex = math.min(#typeList, lastRowStart + math.floor(typeCols / 2))
      else
        state._gridSection = "filter"
        local lastRowStart = math.floor((#filterModes - 1) / filtCols) * filtCols
        state._gridIndex = math.min(#filterModes, lastRowStart + math.floor(filtCols / 2))
      end
    elseif state._gridSection == "actions" then
      state._gridSection = "search"
      state._gridIndex = 1
    end
    if game and game.data then pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end) end
    return true
  elseif wasPressed("a") then
    if state._gridSection == "sort" then
      local sm = sortModes[state._gridIndex or 1]
      if sm then state._dexSortMode = sm.id end
    elseif state._gridSection == "filter" then
      local fm = filterModes[state._gridIndex or 1]
      if fm then
        state._dexFilterMode = fm.id
        if fm.id == "TYPE" and not state._dexTypeFilter then
          state._dexTypeFilter = "NORMAL"
        end
      end
    elseif state._gridSection == "type" then
      local t = typeList[state._gridIndex or 1]
      if t then
        state._dexTypeFilter = t
        state._dexFilterMode = "TYPE"
      end
    elseif state._gridSection == "search" then
      PokedexFilter.openTextEntry(state, game)
    elseif state._gridSection == "actions" then
      if state._gridIndex == 1 then
        state._filterModalOpen = false
        state.view = "list"
        state.index = 1
        state.scroll = 0
        if state.ensureVisible then state:ensureVisible() end
      elseif state._gridIndex == 2 then
        state._dexSortMode = "REGIONAL"
        state._dexFilterMode = "ALL"
        state._dexSearchQuery = ""
        state._dexTypeFilter = "NORMAL"
      end
    end
    if game and game.data then pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end) end
    return true
  elseif wasPressed("select") then
    state._filterModalOpen = false
    state.view = "list"
    state.index = 1
    state.scroll = 0
    if state.ensureVisible then state:ensureVisible() end
    if game and game.data then pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end) end
    return true
  elseif wasPressed("start") then
    state._dexSearchQuery = ""
    if game and game.data then pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end) end
    return true
  elseif wasPressed("b") then
    state._filterModalOpen = false
    state.view = "list"
    if game and game.data then pcall(function() require("src.core.Sound").play(game.data, "Press_AB") end) end
    return true
  end

  return false
end

return PokedexFilter

