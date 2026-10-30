-- OmniUI Pokédex Menu Renderer
-- Unified multi-generation Pokédex browser with seen/caught status detection, live preview,
-- PaletteFX GBC/SGB shaders, mod hooks (pokemon.sprite), modal options overlay, and full entry view.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
local SpriteHelper = require("mods.omni_ui.core.SpriteHelper")
local PokedexFilter = require("mods.omni_ui.core.PokedexFilter")

local PokedexRenderer = {}

-- Robust detection of whether a species has been seen or caught across all generation save formats
-- Robust detection of whether a species has been seen or caught across all generation save formats
local function checkDexStatus(dex, def, dexNum, adapter)
  if adapter and adapter.hasSeen and adapter.hasCaught then
    local sp = def and (def.species or def.id or def.speciesId) or dexNum
    local isSeen = adapter:hasSeen(sp)
    local isCaught = adapter:hasCaught(sp)
    if isCaught then isSeen = true end
    return isSeen, isCaught
  end
  if not dex then return false, false end
  local seenTbl = dex.seen or {}
  local ownedTbl = dex.owned or dex.caught or {}

  local isSeen = false
  local isOwned = false

  -- Check by integer dex number
  if dexNum then
    if seenTbl[dexNum] == true then isSeen = true end
    if ownedTbl[dexNum] == true then isOwned = true end
  end

  -- Check by species identifier, key, or name
  if def then
    local keys = {
      def.id,
      def.species,
      def.name,
      tostring(def.id or ""):upper(),
      tostring(def.species or ""):upper(),
      tostring(def.name or ""):upper(),
    }
    for _, k in ipairs(keys) do
      if k and k ~= "" then
        if seenTbl[k] == true then isSeen = true end
        if ownedTbl[k] == true then isOwned = true end
      end
    end
  end

  if isOwned then isSeen = true end
  return isSeen, isOwned
end

local function drawFootprintWidget(adapter, speciesId, isOwned, x, y, size, theme)
  if not isOwned then return false end
  local fp = adapter and adapter.getFootprint and adapter:getFootprint(speciesId)
  if not fp then return false end

  local okChrome, PokedexChrome = pcall(require, "src.ui.game3.pokedex_chrome")
  if not (okChrome and PokedexChrome and PokedexChrome.drawFootprint) then return false end

  size = size or 40
  Layout.drawSlot(x, y, size, size, {
    color = theme.surfaceHigh,
    borderColor = theme.border,
    radius = 6,
  })

  local scale = math.max(1, math.floor(size / 16))
  local fx = x + math.floor((size - 16 * scale) / 2)
  local fy = y + math.floor((size - 16 * scale) / 2)
  PokedexChrome.drawFootprint(speciesId, fx, fy, scale)
  return true
end

function PokedexRenderer.draw(game, state, w, h, theme, subState, animProgress)
  local ModernOverlay = package.loaded["mods.omni_ui.core.ModernOverlay"]
  if not state.__omniUiPokedexAttached and ModernOverlay and ModernOverlay.attachPokedexControls then
    ModernOverlay.attachPokedexControls(state, game)
  end

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait

  local adapter = AdapterResolver.resolve(game)
  local info = adapter:getPlayerInfo()
  local dexCounts = (adapter and adapter.getPokedexCounts and adapter:getPokedexCounts()) or info.pokedex or { seen = 0, owned = 0 }
  local dex = (adapter and adapter.getDex and adapter:getDex()) or (game.save and (game.save.dex or game.save.pokedex)) or { seen = {}, owned = {} }

  local curIdx = state.listCursor or state.index or state.cursor or state._cursor or (type(state.selected) == "number" and (state.selected + 1)) or 1
  local scroll = state.listScroll or state.scroll or state._scroll or 0
  local footY = h - 38

  local rseSortMap = {
    [0] = (state.dexMode == 1) and "NATIONAL" or "REGIONAL",
    [1] = "NAME_AZ",
    [2] = "HEAVIEST",
    [3] = "LIGHTEST",
    [4] = "TALLEST",
    [5] = "SMALLEST",
  }
  local mode = (state.mode and type(state.mode) == "function" and state:mode())
    or (state.dexOrder ~= nil and rseSortMap[state.dexOrder])
    or (state.dexMode and (state.dexMode == 1 and "OLD" or "NEW"))
    or (state.modeIndex and (state.modeIndex == 2 and "OLD" or (state.modeIndex == 3 and "A-Z" or "NEW")))
    or "NEW"

  -- Pre-cache species lookup map by dex index number and calculate true dynamic max dex limit
  local byDex = {}
  local maxDexFound = (adapter.region == "JOHTO") and 251 or ((adapter.region == "HOENN") and 386 or 151)
  if game and game.data and game.data.constants and game.data.constants.dexSize then
    maxDexFound = math.max(maxDexFound, game.data.constants.dexSize)
  end
  if state.items and #state.items > 0 then
    maxDexFound = math.max(maxDexFound, #state.items)
  end
  if state.totalCount and state.totalCount > 0 then
    maxDexFound = math.max(maxDexFound, state.totalCount)
  end
  if type(state.rows) == "table" and #state.rows > 0 then
    maxDexFound = math.max(maxDexFound, #state.rows)
  end
  for k, d in pairs(game.data and game.data.pokemon or {}) do
    if type(d) == "table" and type(d.dex) == "number" then
      byDex[d.dex] = d
      if d.dex > maxDexFound then maxDexFound = d.dex end
    elseif type(k) == "number" then
      if k > maxDexFound then maxDexFound = k end
    end
  end
  if game and game.save and game.save.pokedex then
    for k in pairs(game.save.pokedex.seen or {}) do
      if type(k) == "number" and k > maxDexFound then maxDexFound = k end
    end
    for k in pairs(game.save.pokedex.owned or game.save.pokedex.caught or {}) do
      if type(k) == "number" and k > maxDexFound then maxDexFound = k end
    end
  end

  local maxDex = maxDexFound

  -- Check if this is a dedicated Unown Dex glyph browser
  local isUnownDex = (state.unownDex == true) or (state.viewMode == "UNOWN_DEX") or (subState and subState.unownDex) or (state.view == "unown")
  if isUnownDex and adapter.getUnownDex then
    local unownList = adapter:getUnownDex()
    local unlockedMap = {}
    for _, u in ipairs(unownList) do
      unlockedMap[u.letter] = u
      unlockedMap[u.index] = u
    end

    Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("UNOWN RESEARCH DEX", 18, 12, { font = "headline", color = theme.heading, bold = true })
    local unownSummary = ("%d / 26 DISCOVERED"):format(#unownList)
    local unownSummaryW = Layout.textWidth(unownSummary, "caption") + 28
    Layout.drawBadge(w - unownSummaryW - 16, 10, unownSummary, { kind = (#unownList >= 26) and "gold" or "accent", font = "caption", height = 24, width = unownSummaryW })

    local cardY = 52
    local cardH = footY - cardY - 6
    Layout.drawCard(0, cardY, w, cardH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local gridCols = isNarrow and 6 or 9
    local colGap = 6
    local rowGap = 6
    local cellW = math.floor((w - 24 - (gridCols - 1) * colGap) / gridCols)
    local cellH = isNarrow and 46 or 54

    for i = 1, 26 do
      local letter = alphabet:sub(i, i)
      local unownData = unlockedMap[letter]
      local col = (i - 1) % gridCols
      local row = math.floor((i - 1) / gridCols)
      local gx = 12 + col * (cellW + colGap)
      local gy = cardY + 12 + row * (cellH + rowGap)

      if unownData then
        Layout.drawCard(gx, gy, cellW, cellH, {
          color = theme.surfaceHigh,
          borderColor = theme.colors.hpYellow,
          borderWidth = 1,
          radius = 6,
        })
        Layout.drawText(letter, gx, gy + 4, { font = "headline", color = theme.heading, align = "center", width = cellW, bold = true })
        Layout.drawBadge(gx + math.floor((cellW - 32) / 2), gy + cellH - 18, ("#%02d"):format(unownData.order or i), { kind = "gold", font = "tiny", width = 32 })
      else
        Layout.drawSlot(gx, gy, cellW, cellH, {
          color = theme.surface,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 6,
        })
        Layout.drawText("?", gx, gy + 8, { font = "headline", color = theme.textMuted, align = "center", width = cellW, bold = true })
        Layout.drawText(letter, gx, gy + cellH - 16, { font = "tiny", color = theme.textDim, align = "center", width = cellW })
      end
    end

    local hints = {
      { key = "A/B", label = "Close Unown Dex", primary = true },
    }
    Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16 })
    return
  end

  -- Check if this is an Area/Habitat map view
  if state.view == "area" or (state.view ~= "list" and (state.screen == "area" or state.page == 5)) then
    local TownMapRenderer = require("mods.omni_ui.renderers.TownMapRenderer")
    return TownMapRenderer.draw(game, state, w, h, theme, subState, animProgress)
  end

  -- =========================================================================
  -- SEARCH, FILTER & SORT CONFIGURATION MODAL VIEW (2D GRID NAVIGATION)
  -- =========================================================================
  local isFilterView = (state.view == "option") or (state.view == "search") or (state.view == "filter") or (state._filterModalOpen == true) or (state.view ~= "list" and state.page == 2)
  if isFilterView then
    local sortModes = PokedexFilter.getAvailableSortModes(adapter)
    local filterModes = PokedexFilter.FILTER_MODES
    local typeList = PokedexFilter.TYPES

    local curSortId = state._dexSortMode or (mode == "OLD" and "NATIONAL" or (mode == "A-Z" and "NAME_AZ" or "REGIONAL"))
    local curFilterId = state._dexFilterMode or "ALL"
    local curTypeFilter = state._dexTypeFilter or "NORMAL"
    local curQuery = state._dexSearchQuery or ""

    local gridSec = state._gridSection or "sort"
    local gridIdx = state._gridIndex or 1

    Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("POKÉDEX SEARCH & SORT MODES", 18, 12, { font = "headline", color = theme.heading, bold = true })
    local modeSummary = ("SORT: %s   FILTER: %s"):format(curSortId, curFilterId)
    local modeSummaryW = Layout.textWidth(modeSummary, "caption") + 28
    Layout.drawBadge(w - modeSummaryW - 16, 10, modeSummary, { kind = "accent", font = "caption", height = 24, width = modeSummaryW })

    local cardY = 52
    local cardH = footY - cardY - 6
    Layout.drawCard(0, cardY, w, cardH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local padX = isNarrow and 12 or (w > 720 and 24 or 16)
    local innerW = w - padX * 2

    -- Adaptive Grid Column Counts based on screen aspect ratio & width
    local sortCols = isNarrow and 2 or ((w > 720 and not (h < 460)) and 5 or 4)
    local filtCols = isNarrow and 2 or ((w > 720 and not (h < 460)) and 6 or 3)
    local tyCols = isNarrow and 6 or ((w > 720) and 9 or 6)

    local sortBtnW = math.floor((innerW - (sortCols - 1) * 6) / sortCols)
    local sortBtnH = (h < 460) and 26 or 30
    local sortRows = math.ceil(#sortModes / sortCols)
    local sortSecH = 20 + sortRows * (sortBtnH + 6) + 10

    local filtBtnW = math.floor((innerW - (filtCols - 1) * 6) / filtCols)
    local filtBtnH = (h < 460) and 26 or 30
    local filtRows = math.ceil(#filterModes / filtCols)
    local filtSecH = 20 + filtRows * (filtBtnH + 6) + 10

    local hasType = (curFilterId == "TYPE")
    local tySecH = hasType and (20 + math.ceil(#typeList / tyCols) * 24 + 10) or 0

    local searchBoxW = innerW
    local searchBoxH = (h < 460) and 30 or 34
    local searchSecH = 18 + searchBoxH + 12

    local actBtnW = math.floor((innerW - 12) / 2)
    local actBtnH = (h < 460) and 30 or 34
    local actSecH = actBtnH + 12

    local totalContentH = 12 + sortSecH + filtSecH + tySecH + searchSecH + actSecH
    local viewY = cardY + 8
    local viewH = cardH - 16
    local maxScroll = math.max(0, totalContentH - viewH)

    -- Auto-scroll position tracking focused section
    local targetScroll = 0
    if maxScroll > 0 then
      if gridSec == "sort" then
        targetScroll = 0
      elseif gridSec == "filter" then
        targetScroll = math.min(maxScroll, sortSecH)
      elseif gridSec == "type" then
        targetScroll = math.min(maxScroll, sortSecH + filtSecH)
      elseif gridSec == "search" then
        targetScroll = math.min(maxScroll, sortSecH + filtSecH + tySecH)
      elseif gridSec == "actions" then
        targetScroll = maxScroll
      end
    end
    state._modalScroll = targetScroll

    -- Scissor clipping for clean scroll containment on compact viewports
    if maxScroll > 0 then
      love.graphics.setScissor(0, viewY, w, viewH)
    end
    love.graphics.push()
    love.graphics.translate(0, -state._modalScroll)

    local contentY = cardY + 12

    -- 1. SORT MODE GRID SECTION
    Layout.drawText("1. SORT ORDER", padX, contentY, { font = "caption", color = (gridSec == "sort") and theme.heading or theme.textDim, bold = true })
    contentY = contentY + 20

    for i, sm in ipairs(sortModes) do
      local col = (i - 1) % sortCols
      local row = math.floor((i - 1) / sortCols)
      local bx = padX + col * (sortBtnW + 6)
      local by = contentY + row * (sortBtnH + 6)
      local isSelected = (curSortId == sm.id)
      local isFocused = (gridSec == "sort" and gridIdx == i)

      if isFocused then
        Layout.drawCard(bx - 2, by - 2, sortBtnW + 4, sortBtnH + 4, {
          color = theme.accentDark,
          borderColor = theme.colors.accent,
          borderWidth = 2,
          radius = 6,
        })
      end

      if isSelected then
        Layout.drawButton(bx, by, sortBtnW, sortBtnH, sm.label, { kind = "primary", selected = true })
      else
        Layout.drawSlot(bx, by, sortBtnW, sortBtnH, { color = isFocused and theme.surfaceHigh or theme.surface, borderColor = theme.border })
        Layout.drawText(sm.label, bx + 4, by + ((h < 460) and 5 or 7), { font = "caption", color = isFocused and theme.heading or theme.textMuted, width = sortBtnW - 8, align = "center", bold = isFocused })
      end
    end
    contentY = contentY + sortRows * (sortBtnH + 6) + 10

    -- 2. FILTER MODE GRID SECTION
    Layout.drawText("2. FILTER CRITERIA", padX, contentY, { font = "caption", color = (gridSec == "filter") and theme.heading or theme.textDim, bold = true })
    contentY = contentY + 20

    for i, fm in ipairs(filterModes) do
      local col = (i - 1) % filtCols
      local row = math.floor((i - 1) / filtCols)
      local bx = padX + col * (filtBtnW + 6)
      local by = contentY + row * (filtBtnH + 6)
      local isSelected = (curFilterId == fm.id)
      local isFocused = (gridSec == "filter" and gridIdx == i)

      if isFocused then
        Layout.drawCard(bx - 2, by - 2, filtBtnW + 4, filtBtnH + 4, {
          color = theme.accentDark,
          borderColor = theme.colors.hpYellow,
          borderWidth = 2,
          radius = 6,
        })
      end

      if isSelected then
        Layout.drawButton(bx, by, filtBtnW, filtBtnH, fm.label, { kind = "gold", selected = true })
      else
        Layout.drawSlot(bx, by, filtBtnW, filtBtnH, { color = isFocused and theme.surfaceHigh or theme.surface, borderColor = theme.border })
        Layout.drawText(fm.label, bx + 4, by + ((h < 460) and 5 or 7), { font = "caption", color = isFocused and theme.heading or theme.textMuted, width = filtBtnW - 8, align = "center", bold = isFocused })
      end
    end
    contentY = contentY + filtRows * (filtBtnH + 6) + 10

    -- 3. ELEMENTAL TYPE GRID SECTION (Visible when Filter is TYPE)
    if hasType then
      Layout.drawText("3. SELECT ELEMENTAL TYPE", padX, contentY, { font = "caption", color = (gridSec == "type") and theme.heading or theme.colors.accent, bold = true })
      contentY = contentY + 20
      local tyBtnW = math.floor((innerW - (tyCols - 1) * 6) / tyCols)
      for i, t in ipairs(typeList) do
        local col = (i - 1) % tyCols
        local row = math.floor((i - 1) / tyCols)
        local bx = padX + col * (tyBtnW + 6)
        local by = contentY + row * 24
        local isSel = (curTypeFilter == t)
        local isFocused = (gridSec == "type" and gridIdx == i)

        if isFocused or isSel then
          Layout.drawCard(bx - 2, by - 2, tyBtnW + 4, 22, {
            color = theme.accentDark,
            borderColor = isFocused and theme.colors.hpYellow or theme.borderStrong,
            borderWidth = isFocused and 2 or 1,
            radius = 4,
          })
        end
        Widgets.drawTypeBadge(t, bx, by)
      end
      contentY = contentY + math.ceil(#typeList / tyCols) * 24 + 10
    end

    -- 4. LIVE TEXT SEARCH BAR & IN-GAME KEYBOARD
    Layout.drawText("SEARCH QUERY (IN-GAME KEYBOARD)", padX, contentY, { font = "caption", color = theme.textDim, bold = true })
    contentY = contentY + 18

    local isSearchFocused = (gridSec == "search")

    if isSearchFocused then
      Layout.drawCard(padX - 2, contentY - 2, searchBoxW + 4, searchBoxH + 4, {
        color = theme.accentDark,
        borderColor = theme.colors.accent,
        borderWidth = 2,
        radius = 8,
      })
    end

    Layout.drawSlot(padX, contentY, searchBoxW, searchBoxH, {
      color = isSearchFocused and theme.surfaceHighest or theme.surfaceHigh,
      borderColor = isSearchFocused and theme.colors.accent or ((curQuery ~= "") and theme.colors.accent or theme.border),
      borderWidth = (isSearchFocused or curQuery ~= "") and 2 or 1,
      radius = 6,
    })

    local queryDisplay = (curQuery ~= "") and ("SEARCH: \"" .. curQuery .. "\"") or (isSearchFocused and "PRESS Ⓐ TO ENTER KEYBOARD..." or "SELECT TO TYPE QUERY...")
    Layout.drawText(queryDisplay, padX + 12, contentY + ((h < 460) and 6 or 8), {
      font = "caption",
      color = (curQuery ~= "") and theme.heading or (isSearchFocused and theme.heading or theme.textMuted),
      bold = (curQuery ~= "" or isSearchFocused),
    })

    local badgeLabel = isSearchFocused and "Ⓐ OPEN KEYBOARD" or ((curQuery ~= "") and "EDIT" or "KEYBOARD")
    local badgeKind = isSearchFocused and "good" or ((curQuery ~= "") and "accent" or "ghost")
    local badgeW = isNarrow and 106 or 136
    Layout.drawBadge(padX + searchBoxW - badgeW - 8, contentY + 5, badgeLabel, {
      kind = badgeKind,
      font = "tiny",
      height = 24,
    })

    contentY = contentY + searchBoxH + 12

    -- 5. ACTION BUTTONS GRID (APPLY & RETURN, RESET ALL)
    local actItems = {
      { label = "APPLY & RETURN", kind = "primary" },
      { label = "RESET ALL FILTERS", kind = "ghost" },
    }
    for i, act in ipairs(actItems) do
      local bx = padX + (i - 1) * (actBtnW + 12)
      local isFocused = (gridSec == "actions" and gridIdx == i)

      if isFocused then
        Layout.drawCard(bx - 2, contentY - 2, actBtnW + 4, actBtnH + 4, {
          color = theme.accentDark,
          borderColor = theme.colors.accent,
          borderWidth = 2,
          radius = 8,
        })
      end

      Layout.drawButton(bx, contentY, actBtnW, actBtnH, act.label, {
        kind = isFocused and "primary" or act.kind,
        selected = isFocused,
      })
    end

    love.graphics.pop()
    if maxScroll > 0 then
      love.graphics.setScissor()
      Layout.drawScrollBar(w - 8, viewY + 4, 4, viewH - 8, totalContentH, viewH, state._modalScroll)
    end

    -- Footer Hints
    local filterHints = {
      { key = "▲ ▼ ◄ ►", label = "Navigate Grid", primary = true },
      { key = "A", label = isSearchFocused and "Open Keyboard" or "Select / Toggle" },
      { key = "START", label = "Clear Query" },
      { key = "B", label = "Done / Close" },
    }
    Layout.drawHintBar(0, footY, w, 36, filterHints, { paddingX = isNarrow and 8 or 16 })
    return
  end

  -- Check if this is a dedicated DexEntryMenu view
  local isDexEntryView = (state.view == "entry")
    or (state.screenId == "DexEntryMenu")
    or (state.view ~= "list" and state.view ~= "area" and (state.screen == "data" or state.page == 1 or state.page == 8 or (state.def and (state.species or state.pageCount))))
    or (subState and subState.def and (subState.species or subState.pageCount))
  local activeEntryState = isDexEntryView and (subState and subState.def and subState or state) or nil

  if isDexEntryView and activeEntryState then
    local selectedRow = (type(state.filteredRows) == "table" and state.filteredRows[curIdx])
      or (type(state.rows) == "table" and state.rows[curIdx])
    local natSp = (activeEntryState.info and activeEntryState.info.dexNum and adapter and adapter.nationalToSpecies and adapter:nationalToSpecies(activeEntryState.info.dexNum))
    local targetSpecies = activeEntryState.species
      or (activeEntryState.def and (activeEntryState.def.species or activeEntryState.def.name or activeEntryState.def.id))
      or (selectedRow and (selectedRow.species or selectedRow.speciesId))
      or natSp
      or (activeEntryState.info and activeEntryState.info.dexNum)
      or (selectedRow and (selectedRow.name or selectedRow.dex))
      or curIdx
    local entryData = (selectedRow and selectedRow.entryData) or adapter:getDexEntry(targetSpecies)

    local natDex = entryData.nationalDex or entryData.dex or (selectedRow and (selectedRow.nationalDex or selectedRow.dex)) or curIdx
    local displayDexNum = (selectedRow and selectedRow.displayNum)
      or ((state._dexSortMode == "NATIONAL" or mode == "OLD") and natDex)
      or entryData.regionalDex or entryData.dex or curIdx
    local monName = entryData.name or "POKÉMON"
    local isSeen, isOwned = checkDexStatus(dex, entryData.def or entryData, natDex, adapter)
    if activeEntryState.info and activeEntryState.info.owned ~= nil then
      if activeEntryState.info.owned == true then
        isOwned = true
        isSeen = true
      end
    end
    if selectedRow then
      if selectedRow.seen ~= nil then isSeen = (selectedRow.seen == true) end
      if selectedRow.caught ~= nil then isOwned = (selectedRow.caught == true) end
    end
    if state.screenId == "DexEntryMenu" and isSeen == nil then
      isSeen = true
    end

    if not isSeen then
      Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
      Layout.drawText("POKÉDEX DATA ENTRY", 18, 12, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(w - (isNarrow and 120 or 180), 10, ("#%03d UNKNOWN"):format(displayDexNum), { kind = "ghost", font = "caption", height = 24 })

      Layout.drawCard(0, 52, w, footY - 58, { color = theme.surface, borderColor = theme.border, radius = 8 })
      Layout.drawSlot(20, 72, w - 40, footY - 140, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
      Layout.drawText("UNKNOWN POKÉMON DATA", 36, 92, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawText("This species has not been encountered yet.\nCapture or battle this Pokémon in the field to register biological records.", 36, 126, { font = "body", color = theme.textDim })

      local hints = {
        { key = "B", label = "Return to Pokédex", primary = true },
      }
      Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16 })
      return
    end

    -- 1. Header Card
    Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("POKÉDEX DATA ENTRY", 18, 12, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(w - (isNarrow and 120 or 180), 10, ("#%03d %s"):format(displayDexNum, isOwned and "CAUGHT" or "SEEN"), { kind = isOwned and "good" or "ghost", font = "caption", height = 24 })

    local isMetric = (adapter and adapter.isMetric and adapter:isMetric()) or false
    local htStr = isOwned and (entryData.height or "---") or (isMetric and "???,? m" or "??'??\"")
    local wtStr = isOwned and (entryData.weight or "---") or (isMetric and "???,? kg" or "????.? lbs.")

    if isNarrow then
      -- Stacked Portrait Single Entry View
      local heroH = 106
      Layout.drawCard(0, 48, w, heroH, { color = theme.surface, borderColor = theme.border, radius = 8 })

      local boxSize = 84
      Layout.drawSlot(8, 56, boxSize, boxSize, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

      SpriteHelper.drawFrontPic(game.data, entryData.species or targetSpecies, 8, 56, boxSize, boxSize, { kind = "dex" })

      local hx = boxSize + 16
      local hw = w - hx - 10
      Layout.drawText(monName, hx, 54, { font = "headline", color = theme.heading, bold = true, width = hw })
      local cleanKind = tostring(entryData.kind or ""):gsub("%s*POK[EÉ]MON$", ""):gsub("%s*PKMN$", "")
      local catText = (cleanKind ~= "" and cleanKind ~= "POKÉMON") and (cleanKind:upper() .. " PKMN") or "POKÉMON"
      Layout.drawText(catText, hx, 76, { font = "tiny", color = theme.textDim, bold = true, width = hw })

      local uniqueTypes = Widgets.getUniqueTypes(entryData.types)
      if #uniqueTypes > 0 then
        local tyX = hx
        for _, t in ipairs(uniqueTypes) do
          local bw = Widgets.drawTypeBadge(t, tyX, 98)
          tyX = tyX + bw + 4
        end
      end

      -- Bottom Lore Card
      local loreY = 48 + heroH + 6
      local loreH = footY - loreY - 6
      Layout.drawCard(0, loreY, w, loreH, { color = theme.surface, borderColor = theme.border, radius = 8 })

      local hasFp = isOwned and adapter and adapter.getFootprint and (adapter:getFootprint(entryData.species or targetSpecies) ~= nil)
      if hasFp then
        local fpSize = 44
        local metricColW = math.floor((w - 36 - fpSize) / 2)
        Layout.drawStatMetric(12, loreY + 8, metricColW, htStr, "height")
        Layout.drawStatMetric(12 + metricColW + 4, loreY + 8, metricColW, wtStr, "weight")
        drawFootprintWidget(adapter, entryData.species or targetSpecies, isOwned, 12 + (metricColW + 4) * 2, loreY + 8, fpSize, theme)
      else
        local metricColW = math.floor((w - 28) / 2)
        Layout.drawStatMetric(12, loreY + 8, metricColW, htStr, "height")
        Layout.drawStatMetric(12 + metricColW + 8, loreY + 8, metricColW, wtStr, "weight")
      end

      local descSlotY = loreY + 62
      local descSlotH = loreH - 68
      Layout.drawSlot(8, descSlotY, w - 16, descSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

      local descText = isOwned and entryData.description or "Data not yet recorded."
      Layout.drawTextWrapped(descText, 16, descSlotY + 10, w - 32, { font = "caption", color = isOwned and theme.text or theme.textMuted })
    else
      local bodyH = h - 96
      local leftW = math.floor(w * 0.44)
      local rightX = leftW + 12
      local rightW = w - rightX

      -- 2. Left Hero Portrait & Biology Card
      Layout.drawCard(0, 52, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

      local portH = 180
      Layout.drawSlot(16, 68, leftW - 32, portH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })

      -- Pedestal under Pokémon
      local pedX = 16 + math.floor((leftW - 32) / 2)
      local pedY = 68 + portH - 26
      local pedW = math.floor((leftW - 32) * 0.40)
      Layout.drawPedestal(pedX, pedY, pedW, 10)

      SpriteHelper.drawFrontPic(game.data, entryData.species or targetSpecies, 16, 68, leftW - 32, portH - 12, { kind = "dex", scale = 2.4 })

      local bioY = 68 + portH + 14
      Layout.drawText(monName, 20, bioY, { font = "title", color = theme.heading, bold = true })

      local cleanKind = tostring(entryData.kind or ""):gsub("%s*POK[EÉ]MON$", ""):gsub("%s*PKMN$", "")
      local catText = (cleanKind ~= "" and cleanKind ~= "POKÉMON") and (cleanKind:upper() .. " POKÉMON") or "POKÉMON"
      Layout.drawText(catText, 20, bioY + 28, { font = "caption", color = theme.textDim, bold = true })

      local uniqueTypes = Widgets.getUniqueTypes(entryData.types)
      if #uniqueTypes > 0 then
        local tyX = 20
        for _, t in ipairs(uniqueTypes) do
          local bw = Widgets.drawTypeBadge(t, tyX, bioY + 52)
          tyX = tyX + bw + 6
        end
      end

      -- 3. Right Details & Lore Description Card
      Layout.drawCard(rightX, 52, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

      -- Stat Metrics Box (Height / Weight / Footprint)
      local statSlotY = 68
      local statSlotH = 70
      Layout.drawSlot(rightX + 16, statSlotY, rightW - 32, statSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

      local hasFp = isOwned and adapter and adapter.getFootprint and (adapter:getFootprint(entryData.species or targetSpecies) ~= nil)
      if hasFp then
        local fpSize = 50
        local metricColW = math.floor((rightW - 48 - fpSize) / 2)
        Layout.drawStatMetric(rightX + 20, statSlotY + 10, metricColW, htStr, "height")
        Layout.drawStatMetric(rightX + 20 + metricColW + 6, statSlotY + 10, metricColW, wtStr, "weight")
        drawFootprintWidget(adapter, entryData.species or targetSpecies, isOwned, rightX + 20 + (metricColW + 6) * 2, statSlotY + 10, fpSize, theme)
      else
        local metricColW = math.floor((rightW - 48) / 2)
        Layout.drawStatMetric(rightX + 20, statSlotY + 10, metricColW, htStr, "height")
        Layout.drawStatMetric(rightX + 20 + metricColW + 8, statSlotY + 10, metricColW, wtStr, "weight")
      end

      -- Description Box (Unified full entry display)
      local descSlotY = statSlotY + statSlotH + 14
      local descSlotH = bodyH + 52 - descSlotY - 16
      Layout.drawSlot(rightX + 16, descSlotY, rightW - 32, descSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

      Layout.drawText("POKÉDEX ARCHIVE LORE", rightX + 28, descSlotY + 14, { font = "caption", color = theme.colors.accent, bold = true })

      local descText = isOwned and entryData.description or "Data not yet recorded."
      Layout.drawTextWrapped(descText, rightX + 28, descSlotY + 38, rightW - 56, { font = "body", color = isOwned and theme.text or theme.textMuted })
    end

    -- 4. Footer Hint Bar
    local hints = {
      { key = "A", label = "Area Map", primary = true },
      { key = "START", label = "Play Cry" },
      { key = "B", label = "Back" },
    }
    Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
    return
  end

  -- =========================================================================
  -- Main Pokédex Archive Browser View with Dynamic Search & Sort Rows
  -- =========================================================================
  local activeRows, totalMonCount = PokedexFilter.buildRows(game, state, adapter)
  state.filteredRows = activeRows
  local rowCount = #activeRows
  maxDex = rowCount

  -- 1. Top Header Card with Active Search / Filter Status Indicators
  local curSortMode = state._dexSortMode or (mode == "OLD" and "NATIONAL" or (mode == "A-Z" and "NAME_AZ" or "REGIONAL"))
  local curFilterMode = state._dexFilterMode or "ALL"
  local curQuery = state._dexSearchQuery or ""

  local sortBadgeText = ("SORT: %s"):format(curSortMode)
  local filterBadgeText = (curFilterMode == "TYPE" and state._dexTypeFilter) and ("TYPE: " .. state._dexTypeFilter) or ("FILTER: " .. curFilterMode)
  if curQuery ~= "" then
    filterBadgeText = ("SEARCH: \"%s\""):format(curQuery)
  end

  local dexSummary = ("%d / %d   SEEN: %d  CAUGHT: %d"):format(rowCount, totalMonCount, dexCounts.seen, dexCounts.owned)
  local dexSummaryW = Layout.textWidth(dexSummary, "caption") + 32

  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText("POKÉDEX ARCHIVE", 18, 12, { font = "headline", color = theme.heading, bold = true })

  -- Filter & Sort Badges in Header
  local hx = 200
  if not isNarrow and w > 640 then
    Layout.drawBadge(hx, 10, sortBadgeText, { kind = "primary", font = "tiny", height = 24 })
    hx = hx + Layout.textWidth(sortBadgeText, "tiny") + 28
    Layout.drawBadge(hx, 10, filterBadgeText, { kind = (curFilterMode ~= "ALL" or curQuery ~= "") and "gold" or "ghost", font = "tiny", height = 24 })
  end

  Layout.drawBadge(w - dexSummaryW - 18, 10, dexSummary, { kind = "good", font = "caption", height = 24, width = dexSummaryW })

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE HERO PREVIEW + FULL-WIDTH LIST
    -- =========================================================================
    local topPreviewH = 156
    local selectedRow = activeRows[curIdx]
    local targetSpecies = (selectedRow and selectedRow.species) or curIdx
    local entryData = (selectedRow and selectedRow.entryData) or adapter:getDexEntry(targetSpecies)
    local curSeen = selectedRow and selectedRow.seen or false
    local curOwned = selectedRow and selectedRow.caught or false

    -- Top Species Hero Preview Card
    Layout.drawCard(0, 50, w, topPreviewH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    if curSeen and selectedRow then
      local boxW = 104
      local boxH = topPreviewH - 16
      Layout.drawSlot(8, 58, boxW, boxH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

      local pedX = 8 + math.floor(boxW / 2)
      local pedY = 58 + boxH - 18
      Layout.drawPedestal(pedX, pedY, math.floor(boxW * 0.44), 6)

      SpriteHelper.drawFrontPic(game.data, entryData.species or targetSpecies, 8, 58, boxW, boxH - 8, { kind = "dex" })

      -- Right Info Area inside Hero Card
      local rx = boxW + 18
      local rw = w - rx - 8
      local monName = entryData.name or "POKÉMON"
      Layout.drawText(monName, rx, 58, { font = "headline", color = theme.heading, bold = true })

      local statusText = curOwned and "CAUGHT" or "SEEN ONLY"
      local statusW = Layout.textWidth(statusText, "tiny") + 22
      Layout.drawBadge(w - statusW - 12, 58, statusText, { kind = curOwned and "good" or "ghost", font = "tiny", width = statusW })

      local cleanKind = tostring(entryData.kind or ""):gsub("%s*POK[EÉ]MON$", ""):gsub("%s*PKMN$", "")
      local catText = (cleanKind ~= "" and cleanKind ~= "POKÉMON") and (cleanKind:upper() .. " PKMN") or "POKÉMON"
      local displayNum = selectedRow.displayNum or curIdx
      local catLine = ("#%03d  %s"):format(displayNum, catText)
      Layout.drawText(catLine, rx, 82, { font = "caption", color = theme.textDim, bold = true })

      -- Dual Types (Deduplicated for single-type Pokémon)
      local uniqueTypes = Widgets.getUniqueTypes(entryData.types)
      if #uniqueTypes > 0 then
        local tyX = rx
        for _, t in ipairs(uniqueTypes) do
          local bw = Widgets.drawTypeBadge(t, tyX, 104)
          tyX = tyX + bw + 4
        end
      end

      -- Height & Weight Metrics
      local htStr = curOwned and entryData.height or "???"
      local wtStr = curOwned and entryData.weight or "???"
      Layout.drawText(("HT: %s   WT: %s"):format(htStr, wtStr), rx, 130, { font = "tiny", color = theme.textDim })
    else
      Layout.drawText("UNKNOWN SPECIES", 18, 64, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawText("Species has not been encountered yet.", 18, 92, { font = "caption", color = theme.textDim })
    end

    -- Bottom Scrollable Full-Width Dex List Card
    local listY = 50 + topPreviewH + 6
    local listH = footY - listY - 6
    Layout.drawCard(0, listY, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowH = 36
    local visibleRows = math.max(1, math.floor((listH - 16) / (rowH + 3)))
    state.visibleRows = visibleRows

    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + visibleRows then
      scroll = curIdx - visibleRows
    end
    scroll = math.max(0, math.min(math.max(0, maxDex - visibleRows), scroll))
    state.scroll = scroll

    local itemW = (maxDex > visibleRows) and (w - 28) or (w - 16)

    if rowCount == 0 then
      Layout.drawText("NO SPECIES MATCH ACTIVE FILTER / SEARCH", 20, listY + 30, { font = "button", color = theme.textMuted, align = "center", width = w - 40, bold = true })
      Layout.drawText("Press SELECT to change filter or START to clear query.", 20, listY + 60, { font = "caption", color = theme.textDim, align = "center", width = w - 40 })
    end

    for r = 1, visibleRows do
      local rowIdx = scroll + r
      if rowIdx > maxDex then break end

      local isSel = (curIdx == rowIdx)
      local rowEntry = activeRows[rowIdx]
      if not rowEntry then break end

      local dexNum = rowEntry.displayNum or rowIdx
      local isSeen = rowEntry.seen
      local isOwned = rowEntry.caught
      local iy = listY + 8 + (r - 1) * (rowH + 3)

      if isSel then
        Layout.drawCard(8, iy, itemW, rowH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
      else
        Layout.drawSlot(8, iy, itemW, rowH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 6,
        })
      end

      -- Dex Index Number according to sort mode
      Layout.drawText(("#%03d"):format(dexNum), 16, iy + 9, {
        font = "caption",
        color = isSel and theme.heading or theme.textDim,
        bold = true,
      })

      -- Status Badge
      if isOwned then
        Layout.drawBadge(54, iy + 7, "OWN", { kind = "good", font = "tiny", width = 42 })
      elseif isSeen then
        Layout.drawBadge(54, iy + 7, "SEEN", { kind = "ghost", font = "tiny", width = 42 })
      end

      -- Species Name
      local name = isSeen and (rowEntry.name or tostring(rowEntry.species)) or "------------"
      local nameColor = isSel and theme.heading or (isSeen and theme.text or theme.textMuted)
      Layout.drawText(name, 104, iy + 9, {
        font = "button",
        color = nameColor,
        bold = isSel,
      })
    end

    if maxDex > visibleRows then
      Layout.drawScrollBar(w - 12, listY + 8, 5, listH - 16, maxDex, visibleRows, scroll)
    end

    -- Floating Action Submenu for portrait mode
    local actionMenu = subState or state.submenu
    local actionItems = actionMenu and (actionMenu.entries or actionMenu.items or actionMenu.rows)
    if actionItems and type(actionItems) == "table" and #actionItems > 0 then
      local popW = math.min(w - 32, 240)
      local popH = #actionItems * 38 + 20
      local popX = math.floor((w - popW) / 2)
      local popY = math.max(60, math.floor((h - popH) / 2))

      love.graphics.setColor(0, 0, 0, 0.45)
      love.graphics.rectangle("fill", 0, 0, w, h)
      love.graphics.setColor(1, 1, 1, 1)

      Layout.drawCard(popX, popY, popW, popH, {
        color = theme.surface,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = 8,
      })

      for ai, entry in ipairs(actionItems) do
        local isActSel = ((actionMenu.index or actionMenu.cursor or 1) == ai)
        local ay = popY + 10 + (ai - 1) * 38
        local lbl = (type(entry) == "table" and (entry.label or entry.name or entry[1])) or tostring(entry)
        lbl = tostring(lbl):upper()

        if isActSel then
          Layout.drawButton(popX + 8, ay, popW - 16, 32, lbl, { kind = "primary", selected = true })
        else
          Layout.drawSlot(popX + 8, ay, popW - 16, 32, { color = theme.surfaceHigh, borderColor = theme.border })
          Layout.drawText(lbl, popX + 16, ay + 8, { font = "button", color = theme.text })
        end
      end
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANEL LAYOUT
    -- =========================================================================
    local bodyH = h - 96
    local lw = 320
    Layout.drawCard(0, 52, lw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowH = 38
    local visibleRows = math.max(1, math.floor((bodyH - 24) / (rowH + 4)))
    state.visibleRows = visibleRows

    if curIdx <= scroll then
      scroll = curIdx - 1
    elseif curIdx > scroll + visibleRows then
      scroll = curIdx - visibleRows
    end
    scroll = math.max(0, math.min(math.max(0, maxDex - visibleRows), scroll))
    state.scroll = scroll

    local itemW = (maxDex > visibleRows) and (lw - 28) or (lw - 16)
    local selectedRow = activeRows[curIdx]
    local targetSpecies = (selectedRow and selectedRow.species) or curIdx
    local entryData = (selectedRow and selectedRow.entryData) or adapter:getDexEntry(targetSpecies)

    if rowCount == 0 then
      Layout.drawText("NO MATCHING SPECIES", 20, 100, { font = "button", color = theme.textMuted, align = "center", width = lw - 40, bold = true })
      Layout.drawText("Press SELECT to change filters\nor START to clear query.", 20, 130, { font = "caption", color = theme.textDim, align = "center", width = lw - 40 })
    end

    for r = 1, visibleRows do
      local rowIdx = scroll + r
      if rowIdx > maxDex then break end

      local isSel = (curIdx == rowIdx)
      local rowEntry = activeRows[rowIdx]
      if not rowEntry then break end

      local dexNum = rowEntry.displayNum or rowIdx
      local isSeen = rowEntry.seen
      local isOwned = rowEntry.caught

      local offsetX = Layout.getCascadeOffset(r, animProgress, 0.022, 18)
      local iy = 62 + (r - 1) * (rowH + 4)

      love.graphics.push()
      if offsetX ~= 0 then
        love.graphics.translate(offsetX, 0)
      end

      if isSel then
        entryData = rowEntry.entryData or adapter:getDexEntry(rowEntry.species)
        Layout.drawCard(8, iy, itemW, rowH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
      else
        Layout.drawSlot(8, iy, itemW, rowH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 6,
        })
      end

      Layout.drawText(("#%03d"):format(dexNum), 18, iy + 10, {
        font = "caption",
        color = isSel and theme.heading or theme.textDim,
        bold = true,
      })

      if isOwned then
        Layout.drawBadge(58, iy + 8, "OWN", { kind = "good", font = "tiny", width = 48 })
      elseif isSeen then
        Layout.drawBadge(58, iy + 8, "SEEN", { kind = "ghost", font = "tiny", width = 48 })
      end

      local name = isSeen and (rowEntry.name or tostring(rowEntry.species)) or "------------"
      local nameColor = isSel and theme.heading or (isSeen and theme.text or theme.textMuted)
      Layout.drawText(name, 116, iy + 10, {
        font = "button",
        color = nameColor,
        bold = isSel,
      })

      love.graphics.pop()
    end

    if maxDex > visibleRows then
      Layout.drawScrollBar(lw - 14, 62, 6, bodyH - 24, maxDex, visibleRows, scroll)
    end

    -- 3. Right Species Preview & Info Panel
    local rx = lw + 12
    local rw = w - rx
    Layout.drawCard(rx, 52, rw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curSeen = selectedRow and selectedRow.seen or false
    local curOwned = selectedRow and selectedRow.caught or false

    if curSeen and selectedRow then
      local portH = 146
      Layout.drawSlot(rx + 16, 68, rw - 32, portH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })

      local pedX = rx + 16 + math.floor((rw - 32) / 2)
      local pedY = 68 + portH - 22
      local pedW = math.floor((rw - 32) * 0.38)
      Layout.drawPedestal(pedX, pedY, pedW, 8)

      SpriteHelper.drawFrontPic(game.data, entryData.species or targetSpecies, rx + 16, 68, rw - 32, portH - 12, { kind = "dex", scale = 2.0 })

      local nameY = 68 + portH + 12
      local monName = entryData.name or "POKÉMON"
      local displayNum = selectedRow.displayNum or curIdx
      Layout.drawText(("#%03d %s"):format(displayNum, monName), rx + 18, nameY, { font = "title", color = theme.heading, bold = true })

      local statusText = curOwned and "CAUGHT" or "SEEN ONLY"
      local statusW = Layout.textWidth(statusText, "tiny") + 28
      Layout.drawBadge(rx + rw - statusW - 18, nameY + 2, statusText, { kind = curOwned and "good" or "ghost", font = "tiny", width = statusW })

      local curY = nameY + 26

      local cleanKind = tostring(entryData.kind or ""):gsub("%s*POK[EÉ]MON$", ""):gsub("%s*PKMN$", "")
      local catText = (cleanKind ~= "" and cleanKind ~= "POKÉMON") and (cleanKind:upper() .. " POKÉMON") or "POKÉMON"
      Layout.drawText(catText, rx + 18, curY, { font = "caption", color = curOwned and theme.textDim or theme.textMuted, bold = true })
      curY = curY + 20

      local uniqueTypes = Widgets.getUniqueTypes(entryData.types)
      if #uniqueTypes > 0 then
        local tyX = rx + 18
        for _, t in ipairs(uniqueTypes) do
          local bw = Widgets.drawTypeBadge(t, tyX, curY)
          tyX = tyX + bw + 6
        end
        curY = curY + 24
      end

      local htStr = curOwned and entryData.height
      local wtStr = curOwned and entryData.weight
      if htStr and wtStr then
        Layout.drawText(("HT: %s   WT: %s"):format(htStr, wtStr), rx + 18, curY, { font = "tiny", color = theme.textDim, bold = true })
        curY = curY + 18
      elseif not curOwned then
        Layout.drawText("HT: ???   WT: ???", rx + 18, curY, { font = "tiny", color = theme.textMuted, bold = true })
        curY = curY + 18
      end

      local descText = curOwned and entryData.description or "Data not yet recorded."
      local descSlotY = curY + 6
      local descSlotH = math.max(60, bodyH + 52 - descSlotY - 16)
      Layout.drawSlot(rx + 16, descSlotY, rw - 32, descSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawTextWrapped(descText, rx + 28, descSlotY + 12, rw - 56, { font = "body", color = curOwned and theme.textDim or theme.textMuted })

      local actionMenu = subState or state.submenu
      local actionItems = actionMenu and (actionMenu.entries or actionMenu.items or actionMenu.rows)
      if actionItems and type(actionItems) == "table" and #actionItems > 0 then
        local popW = 160
        local popH = #actionItems * 38 + 20
        local popX = rx + rw - popW - 16
        local popY = 68

        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(1, 1, 1, 1)

        Layout.drawCard(popX, popY, popW, popH, {
          color = theme.surface,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 8,
        })

        for ai, entry in ipairs(actionItems) do
          local isActSel = ((actionMenu.index or actionMenu.cursor or 1) == ai)
          local ay = popY + 10 + (ai - 1) * 38
          local lbl = (type(entry) == "table" and (entry.label or entry.name or entry[1])) or tostring(entry)
          lbl = tostring(lbl):upper()

          if isActSel then
            Layout.drawButton(popX + 8, ay, popW - 16, 32, lbl, { kind = "primary", selected = true })
          else
            Layout.drawSlot(popX + 8, ay, popW - 16, 32, { color = theme.surfaceHigh, borderColor = theme.border })
            Layout.drawText(lbl, popX + 16, ay + 8, { font = "button", color = theme.text })
          end
        end
      end
    else
      Layout.drawText("UNKNOWN SPECIES", rx + 18, 70, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawSlot(rx + 16, 104, rw - 32, 100, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("Species has not been encountered yet.\nSearch wild areas and trainer battles to record data.", rx + 28, 126, { font = "caption", color = theme.textDim })
    end
  end

  -- 4. Bottom Button Hints Footer Bar
  local actionMenu = subState or state.submenu
  local isSubOpen = actionMenu and (actionMenu.entries or actionMenu.items or actionMenu.rows) and #(actionMenu.entries or actionMenu.items or actionMenu.rows) > 0
  local hints = isSubOpen and {
    { key = "▲ ▼", label = "Choose Option", primary = true },
    { key = "A", label = "Select" },
    { key = "B", label = "Cancel" },
  } or {
    { key = "▲ ▼", label = "Navigate List", primary = true },
    { key = "A", label = "Options" },
    { key = "SELECT", label = "Sort & Filter" },
    { key = "B", label = "Close" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return PokedexRenderer
