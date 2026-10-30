-- OmniUI Pokégear Renderer (Gen 2)
-- High-tech multifunction companion device featuring Clock, Town Map, Phone, and Radio.
-- Designed for all viewport sizes, orientations, handhelds, and mobile screens.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local Strings = require("src.core.Strings")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local PokegearRenderer = {}

-- -----------------------------------------------------------------------------
-- Helpers & Data Mapping (Strictly ASCII Text & Vector Rendered - No Emojis)
-- -----------------------------------------------------------------------------

local CARD_METADATA = {
  clock = { label = "CLOCK", tag = "CLK", color = { 0.20, 0.70, 0.90, 1.0 }, desc = "System Time & Date" },
  map   = { label = "TOWN MAP", tag = "MAP", color = { 0.30, 0.85, 0.45, 1.0 }, desc = "Regional Navigation" },
  phone = { label = "PHONE", tag = "TEL", color = { 0.95, 0.70, 0.20, 1.0 }, desc = "Contact Directory" },
  radio = { label = "RADIO", tag = "RAD", color = { 0.85, 0.40, 0.90, 1.0 }, desc = "Broadcast Tuner" },
  dexnav = { label = "DEXNAV", tag = "NAV", color = { 0.95, 0.45, 0.30, 1.0 }, desc = "Habitat & Wild Species" },
}

local DAY_NAMES = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }

local function getDaytimeInfo(hour)
  hour = hour or 12
  if hour >= 4 and hour < 10 then
    return "MORNING", { 0.95, 0.75, 0.30, 1.0 }
  elseif hour >= 10 and hour < 18 then
    return "DAY", { 0.30, 0.80, 0.95, 1.0 }
  else
    return "NIGHT", { 0.55, 0.45, 0.90, 1.0 }
  end
end

local function wrapToWidth(input, maxW, fontName)
  fontName = fontName or "tiny"
  maxW = math.max(40, maxW or 100)
  local paragraphs = type(input) == "table" and input or { tostring(input) }
  local lines = {}
  for _, p in ipairs(paragraphs) do
    local str = tostring(p or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for rawLine in (str .. "\n"):gmatch("(.-)\n") do
      local cur = ""
      for word in rawLine:gmatch("%S+") do
        local test = (#cur > 0) and (cur .. " " .. word) or word
        if Layout.textWidth(test, fontName) <= maxW then
          cur = test
        else
          if #cur > 0 then
            lines[#lines + 1] = cur
          end
          cur = word
        end
      end
      if #cur > 0 then
        lines[#lines + 1] = cur
      end
    end
  end
  return lines
end

-- -----------------------------------------------------------------------------
-- Card Renderers
-- -----------------------------------------------------------------------------

-- 1. CLOCK CARD
local function drawClockCard(game, state, x, y, w, h, theme, isNarrow)
  local hour, minute, weekday = 12, 0, 1
  if state.clockParts then
    hour, minute, weekday = state:clockParts()
  elseif state.clock then
    hour = state.clock.hour or 12
    minute = state.clock.minute or 0
    weekday = state.clock.weekday or 1
  end

  local dayName = DAY_NAMES[weekday] or (state.clock and state.clock.dayName) or "SUNDAY"
  local isPM = hour >= 12
  local dispHour = hour % 12
  if dispHour == 0 then dispHour = 12 end
  local timeStr = ("%02d:%02d"):format(dispHour, minute)
  local ampmStr = isPM and "PM" or "AM"
  local dayPeriod, dayColor = getDaytimeInfo(hour)

  local save = (game and game.save) or (state and state.save) or {}
  local player = save.player or {}
  local info = {}
  if game then
    local adapter = AdapterResolver.resolve(game)
    if adapter and adapter.getPlayerInfo then
      local okInfo, got = pcall(function() return adapter:getPlayerInfo() end)
      if okInfo and type(got) == "table" then info = got end
    end
  end
  local pName = info.name or player.name or save.playerName or "TRAINER"
  local money = tonumber(info.money or player.money or save.money) or 0
  local badgeCount = tonumber(info.badges) or 0
  local maxBadges = tonumber(info.maxBadges) or 16
  local dexSeen = info.pokedex and tonumber(info.pokedex.seen) or 0

  local curLandmark = (state.mapLandmark and state:mapLandmark()) or {}
  local locName = curLandmark.name or (state.currentLandmark and tostring(state.currentLandmark):gsub("_", " ")) or "JOHTO REGION"

  if isNarrow then
    -- Narrow / Mobile Vertical Clock View
    local heroH = 135
    Layout.drawCard(x, y, w, heroH, { color = theme.surfaceHigh, borderColor = theme.borderStrong, radius = 8 })

    Layout.drawText(dayName, x + 16, y + 14, { font = "caption", color = theme.textDim, bold = true })
    Layout.drawBadge(x + w - 90, y + 12, dayPeriod, { kind = "ghost", font = "tiny", height = 22 })

    Layout.drawText(timeStr, x + 16, y + 40, { font = "title", color = theme.heading, bold = true })
    Layout.drawText(ampmStr, x + Layout.textWidth(timeStr, "title") + 20, y + 52, { font = "headline", color = theme.accent, bold = true })

    -- Location Bar
    Layout.drawSlot(x + 12, y + 92, w - 24, 32, { color = theme.surface, radius = 6 })
    Layout.drawText("LOC: " .. locName, x + 20, y + 100, { font = "caption", color = theme.text, bold = true, width = w - 48 })

    -- Stats Cards below
    local statsY = y + heroH + 10
    local statsH = h - heroH - 10
    Layout.drawCard(x, statsY, w, statsH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rowY = statsY + 14
    local function drawStatRow(label, value)
      Layout.drawText(label, x + 16, rowY, { font = "body", color = theme.textDim })
      local vw = Layout.textWidth(tostring(value), "body")
      Layout.drawText(tostring(value), x + w - vw - 16, rowY, { font = "body", color = theme.heading, bold = true })
      rowY = rowY + 34
    end

    drawStatRow("TRAINER", pName)
    drawStatRow("SAVED CASH", ("¥%d"):format(money))
    drawStatRow("BADGES WON", ("%d / %d"):format(badgeCount, maxBadges))
    drawStatRow("POKÉDEX SEEN", tostring(dexSeen))
    drawStatRow("DST SWITCH", "STANDARD TIME")
  else
    -- Widescreen 2-Column Clock & Adventure Dashboard
    local colW = math.floor((w - 14) / 2)

    -- Left: Hero Digital Clock Card
    Layout.drawCard(x, y, colW, h, { color = theme.surfaceHigh, borderColor = theme.borderStrong, radius = 8 })

    local topY = y + 20
    Layout.drawText(dayName, x + 24, topY, { font = "headline", color = theme.textDim, bold = true })
    Layout.drawBadge(x + colW - 100, topY - 2, dayPeriod, { kind = "ghost", font = "caption", height = 24 })

    local timeY = topY + 44
    Layout.drawText(timeStr, x + 24, timeY, { font = "title", color = theme.heading, bold = true })
    Layout.drawText(ampmStr, x + Layout.textWidth(timeStr, "title") + 24, timeY + 16, { font = "headline", color = theme.accent, bold = true })

    -- Location Bar
    local locY = timeY + 70
    Layout.drawSlot(x + 20, locY, colW - 40, 42, { color = theme.surface, radius = 6 })
    Layout.drawText("CURRENT LOCATION", x + 32, locY + 6, { font = "tiny", color = theme.textMuted })
    Layout.drawText("LOC: " .. locName, x + 32, locY + 20, { font = "body", color = theme.heading, bold = true, width = colW - 64 })

    -- DST / Clock Control Banner
    local dstY = locY + 54
    Layout.drawSlot(x + 20, dstY, colW - 40, 42, { color = theme.surface, radius = 6 })
    Layout.drawText("DAYLIGHT SAVING", x + 32, dstY + 6, { font = "tiny", color = theme.textMuted })
    Layout.drawText("STANDARD TIME (AUTOMATIC)", x + 32, dstY + 20, { font = "caption", color = theme.colors.accent, bold = true })

    -- Right: Trainer & Adventure Passport Card
    local rightX = x + colW + 14
    Layout.drawCard(rightX, y, colW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })

    Layout.drawText("ADVENTURE PASSPORT", rightX + 24, y + 20, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(rightX + colW - 90, y + 18, "ACTIVE", { kind = "good", font = "tiny", height = 22 })

    local py = y + 60
    local function drawDashRow(label, value)
      Layout.drawSlot(rightX + 20, py, colW - 40, 40, { color = theme.surfaceHigh, radius = 6 })
      Layout.drawText(label, rightX + 32, py + 12, { font = "body", color = theme.textDim })
      local vw = Layout.textWidth(tostring(value), "body")
      Layout.drawText(tostring(value), rightX + colW - vw - 36, py + 12, { font = "body", color = theme.heading, bold = true })
      py = py + 48
    end

    drawDashRow("TRAINER NAME", pName)
    drawDashRow("HELD MONEY", ("¥%s"):format(tostring(money):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")))
    drawDashRow("GYM BADGES", ("%d / %d"):format(badgeCount, maxBadges))
    drawDashRow("POKÉDEX SEEN", tostring(dexSeen))
  end
end

-- 2. TOWN MAP CARD (Integrated Seamlessly in Pokegear Chassis)
local function drawMapCard(game, state, x, y, w, h, theme, isNarrow)
  local activeRegion = (state.viewedRegion and state:viewedRegion()) or (state.region and state:region()) or "johto"
  if state.fly and state.flyRegion then activeRegion = state.flyRegion end

  local currentLandmark = (state.mapLandmark and state:mapLandmark()) or {}
  local landmarkName = currentLandmark.name or "UNKNOWN LOCATION"
  local playerLandmark = (state.playerLandmark and state:playerLandmark()) or {}

  local gen2Gfx = (game and game.data and (game.data.gen2MenuGfx or (game.data.menuGfx and game.data.menuGfx.pokegear))) or (state.gfx)
  local gen2MapCells = (state.mapGfx and state.mapGfx.maps and state.mapGfx.maps[activeRegion])
    or (gen2Gfx and gen2Gfx.pokegear and gen2Gfx.pokegear.maps and gen2Gfx.pokegear.maps[activeRegion])
    or (gen2Gfx and gen2Gfx.maps and gen2Gfx.maps[activeRegion])

  local time = love.timer and love.timer.getTime() or 0

  if isNarrow then
    -- Narrow / Mobile Vertical Town Map View
    local mapBoxH = math.floor(h * 0.54)
    Layout.drawCard(x, y, w, mapBoxH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local mapNativeW, mapNativeH = 160, 144
    local pad = 10
    local scale = math.min((w - pad * 2) / mapNativeW, (mapBoxH - pad * 2) / mapNativeH)
    local drawW, drawH = mapNativeW * scale, mapNativeH * scale
    local mapX = x + math.floor((w - drawW) / 2)
    local mapY = y + math.floor((mapBoxH - drawH) / 2)

    Layout.drawSlot(mapX - 4, mapY - 4, drawW + 8, drawH + 8, {
      color = { 0.05, 0.07, 0.10, 1.0 },
      borderColor = theme.borderStrong,
      borderWidth = 1.5,
      radius = 6,
    })

    -- Draw Native Map Tilemap
    if gen2MapCells and state.drawTilemap then
      love.graphics.push()
      love.graphics.translate(mapX, mapY)
      love.graphics.scale(scale, scale)
      state:drawTilemap(gen2MapCells)
      love.graphics.pop()
    end

    -- Draw Player Icon / Beacon
    if playerLandmark and playerLandmark.x and playerLandmark.y then
      local px = mapX + playerLandmark.x * scale
      local py = mapY + playerLandmark.y * scale
      local pulse = 0.5 + 0.5 * math.sin(time * 6)
      love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.35 + 0.25 * pulse)
      love.graphics.circle("fill", px, py, (6 + 3 * pulse) * scale)
      love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 1.0)
      love.graphics.circle("fill", px, py, 2.5 * scale)
    end

    -- Draw Cursor Reticle
    if currentLandmark and currentLandmark.x and currentLandmark.y then
      local cx = mapX + currentLandmark.x * scale
      local cy = mapY + currentLandmark.y * scale
      local pulse = 0.5 + 0.5 * math.sin(time * 8)
      love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], 0.90)
      love.graphics.circle("line", cx, cy, (5 + pulse * 2) * scale)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.circle("fill", cx, cy, 1.5 * scale)
    end

    -- Bottom Landmark Info Card
    local infoY = y + mapBoxH + 8
    local infoH = h - mapBoxH - 8
    Layout.drawCard(x, infoY, w, infoH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
    Layout.drawText("SELECTED DESTINATION", x + 16, infoY + 12, { font = "tiny", color = theme.textMuted })
    Layout.drawText(landmarkName:gsub("\n", " "), x + 16, infoY + 28, { font = "headline", color = theme.heading, bold = true, width = w - 32 })
    Layout.drawBadge(x + w - 90, infoY + 12, activeRegion:upper(), { kind = "accent", font = "tiny", height = 22 })
  else
    -- Widescreen 2-Column Town Map View
    local mapBoxW = math.floor(w * 0.58)
    local infoBoxW = w - mapBoxW - 14

    -- Left: Regional Map Canvas Card
    Layout.drawCard(x, y, mapBoxW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local mapNativeW, mapNativeH = 160, 144
    local pad = 16
    local scale = math.min((mapBoxW - pad * 2) / mapNativeW, (h - pad * 2) / mapNativeH)
    local drawW, drawH = mapNativeW * scale, mapNativeH * scale
    local mapX = x + math.floor((mapBoxW - drawW) / 2)
    local mapY = y + math.floor((h - drawH) / 2)

    Layout.drawSlot(mapX - 4, mapY - 4, drawW + 8, drawH + 8, {
      color = { 0.05, 0.07, 0.10, 1.0 },
      borderColor = theme.borderStrong,
      borderWidth = 1.5,
      radius = 6,
    })

    -- Draw Native Map Tilemap
    if gen2MapCells and state.drawTilemap then
      love.graphics.push()
      love.graphics.translate(mapX, mapY)
      love.graphics.scale(scale, scale)
      state:drawTilemap(gen2MapCells)
      love.graphics.pop()
    end

    -- Draw Player Icon / Beacon
    if playerLandmark and playerLandmark.x and playerLandmark.y then
      local px = mapX + playerLandmark.x * scale
      local py = mapY + playerLandmark.y * scale
      local pulse = 0.5 + 0.5 * math.sin(time * 6)
      love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.35 + 0.25 * pulse)
      love.graphics.circle("fill", px, py, (6 + 3 * pulse) * scale)
      love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 1.0)
      love.graphics.circle("fill", px, py, 2.5 * scale)
    end

    -- Draw Cursor Reticle
    if currentLandmark and currentLandmark.x and currentLandmark.y then
      local cx = mapX + currentLandmark.x * scale
      local cy = mapY + currentLandmark.y * scale
      local pulse = 0.5 + 0.5 * math.sin(time * 8)
      love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], 0.90)
      love.graphics.circle("line", cx, cy, (6 + pulse * 2) * scale)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.circle("fill", cx, cy, 2 * scale)
    end

    -- Right: Selected Landmark Inspector Card
    local infoX = x + mapBoxW + 14
    Layout.drawCard(infoX, y, infoBoxW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })

    Layout.drawText("SELECTED DESTINATION", infoX + 20, y + 20, { font = "tiny", color = theme.textMuted })
    Layout.drawBadge(infoX + infoBoxW - 90, y + 18, activeRegion:upper(), { kind = "accent", font = "tiny", height = 22 })

    Layout.drawSlot(infoX + 16, y + 50, infoBoxW - 32, 60, { color = theme.surfaceHigh, radius = 6 })
    Layout.drawText(landmarkName:gsub("\n", " "), infoX + 26, y + 68, { font = "headline", color = theme.heading, bold = true, width = infoBoxW - 52 })

    -- Landmark Navigation Details
    local detY = y + 120
    Layout.drawCard(infoX + 16, detY, infoBoxW - 32, 110, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
    Layout.drawText("REGION MAP DATA", infoX + 26, detY + 16, { font = "caption", color = theme.textDim, bold = true })
    Layout.drawText("LANDMARK ID: " .. tostring(currentLandmark.index or 1), infoX + 26, detY + 40, { font = "body", color = theme.text })
    Layout.drawText("NAVIGATION: READY", infoX + 26, detY + 68, { font = "body", color = theme.colors.accent, bold = true })

    -- Interaction button hint
    Layout.drawButton(infoX + 16, y + h - 56, infoBoxW - 32, 42, "EXPLORE LANDMARK (PRESS UP / DOWN)", {
      kind = "ghost",
      selected = true,
      font = "caption",
    })
  end
end

local function getActiveCallDialogue(game, state, subState)
  local states = (game and game.stack and game.stack.states) or {}
  local dialogState = nil
  local choiceState = nil

  if subState then
    if subState.isChoiceBox or subState.labels or subState.choices or subState.options or subState.items or subState.onChoose then
      choiceState = subState
    elseif subState.isTextBox or (subState.pages and subState.shown) or subState.shownSource or (subState.pages and subState.pageIndex) or subState.lines or (subState.printer and subState.printer.lines) or subState.visibleText or subState.text then
      dialogState = subState
    end
  end

  for i = #states, 1, -1 do
    local s = states[i]
    if s == state then break end
    if not dialogState and s and (s.isTextBox or (s.pages and s.shown) or s.shownSource or (s.pages and s.pageIndex) or s.lines or (s.printer and s.printer.lines) or s.visibleText or s.text) then
      dialogState = s
      for c = #states, i + 1, -1 do
        local cs = states[c]
        if cs and (cs.isChoiceBox or cs.labels or cs.choices or cs.options or cs.items or cs.onChoose) then
          choiceState = cs
          break
        end
      end
      break
    end
    if not choiceState and s and (s.isChoiceBox or s.labels or s.choices or s.options or s.items or s.onChoose) then
      choiceState = s
    end
  end

  return dialogState, choiceState
end

local function extractCallMessage(dialogState, game)
  if not dialogState then return nil, false, false end

  local text = ""
  local isWaiting = dialogState._waiting or (dialogState.waiting and not dialogState.contAdvance) or (dialogState.done and not dialogState.auto and not dialogState.stay and not dialogState.choice)
  local isNext = false

  -- Gen 1/2 classic paged TextBox
  if dialogState.pages and dialogState.pageIndex and dialogState.pages[dialogState.pageIndex] then
    local pageLines = dialogState.pages[dialogState.pageIndex]
    local fullStr = ""
    local currentRevealed = 0
    for lIdx, lText in ipairs(pageLines) do
      local cleanL = Layout.cleanText(tostring(lText or ""))
      if lIdx > 1 and #cleanL > 0 then
        fullStr = fullStr .. " "
        if (dialogState.lineIndex or 1) >= lIdx then
          currentRevealed = currentRevealed + 1
        end
      end
      fullStr = fullStr .. cleanL
      if (dialogState.lineIndex or 1) > lIdx then
        currentRevealed = currentRevealed + #cleanL
      elseif (dialogState.lineIndex or 1) == lIdx then
        local cIdx = math.min(#cleanL, dialogState.charIndex or #cleanL)
        currentRevealed = currentRevealed + cIdx
      end
    end

    local isFastForward = (game and game.logicSpeed and type(game.logicSpeed) == "function" and game:logicSpeed() > 1)
        or (game and game.input and type(game.input.isDown) == "function" and (game.input:isDown("a") or game.input:isDown("b")))
        or dialogState.instant

    if isWaiting or isFastForward then
      currentRevealed = #fullStr
    end
    text = fullStr:sub(1, currentRevealed)
    isNext = dialogState.pageIndex < #dialogState.pages

  elseif dialogState.visibleText and type(dialogState.visibleText) == "function" then
    local ok, vis = pcall(dialogState.visibleText, dialogState)
    if ok and vis then
      text = Layout.cleanText(table.concat(vis, " "))
      fullStr = text
    end
  elseif dialogState.text then
    text = Layout.cleanText(tostring(type(dialogState.text) == "function" and "" or dialogState.text))
    fullStr = text
  elseif dialogState.shown or dialogState.shownSource then
    text = Layout.cleanText(tostring(dialogState.shown or dialogState.shownSource or ""))
    fullStr = text
  elseif dialogState._pages and dialogState._page and dialogState._pages[dialogState._page] then
    local raw = dialogState._pages[dialogState._page]
    text = Layout.cleanText((type(raw) == "table" and table.concat(raw, " ")) or tostring(raw))
    fullStr = text
    isNext = dialogState._page < #dialogState._pages
  elseif dialogState.lines or (dialogState.printer and dialogState.printer.lines) then
    local raw = dialogState.lines or dialogState.printer.lines
    text = Layout.cleanText(table.concat(raw, " "))
    fullStr = text
  end

  text = tostring(text or ""):gsub("%s+$", "")
  fullStr = tostring(fullStr or ""):gsub("%s+$", "")

  -- Strip redundant speaker prefix if already present in script text (e.g. "MOM: Hello?" -> "Hello?")
  local spk, rest = text:match("^([%w%._'%s%-]+):%s*(.*)$")
  if spk and #spk <= 16 then
    text = rest
  end
  local spkF, restF = fullStr:match("^([%w%._'%s%-]+):%s*(.*)$")
  if spkF and #spkF <= 16 then
    fullStr = restF
  end

  return text, isWaiting, isNext, fullStr
end

-- Accumulating Phone Chat Flow: preserves previous lines in a text-like flow
-- and only scrolls/clears oldest lines when content exceeds vertical capacity
local function updateCallTranscript(call, dialogState, game, bubbleW)
  if not call then return {}, false, false end
  call._transcript = call._transcript or {}
  call._seenPages = call._seenPages or {}

  local maxTextW = math.max(40, bubbleW - 28)

  -- 1. If we had a previous pending page and the dialogue advanced or changed, commit it
  if call._lastPending then
    local lp = call._lastPending
    local shouldCommit = false
    if lp.dialog ~= dialogState then
      shouldCommit = true
    elseif dialogState and dialogState.pages and (dialogState.pageIndex or 1) ~= lp.page then
      shouldCommit = true
    end

    if shouldCommit then
      call._seenPages[lp.dialog] = call._seenPages[lp.dialog] or {}
      if not call._seenPages[lp.dialog][lp.page] then
        call._seenPages[lp.dialog][lp.page] = true
        local t = lp.text or ""
        local spk, rest = t:match("^([%w%._'%s%-]+):%s*(.*)$")
        if spk and #spk <= 16 then t = rest end
        t = Layout.cleanText(t):gsub("^%s+", ""):gsub("%s+$", "")
        if #t > 0 then
          table.insert(call._transcript, t)
        end
      end
      call._lastPending = nil
    end
  end

  -- 2. If dialogState has paged text, ensure any earlier pages are marked and committed
  if dialogState and dialogState.pages then
    local curPage = dialogState.pageIndex or 1
    call._seenPages[dialogState] = call._seenPages[dialogState] or {}
    for p = 1, curPage - 1 do
      if not call._seenPages[dialogState][p] and dialogState.pages[p] then
        call._seenPages[dialogState][p] = true
        local pLines = dialogState.pages[p]
        local pStr = ""
        for _, lText in ipairs(pLines) do
          local cl = Layout.cleanText(tostring(lText or ""))
          if #cl > 0 then
            pStr = (#pStr > 0) and (pStr .. " " .. cl) or cl
          end
        end
        local spk, rest = pStr:match("^([%w%._'%s%-]+):%s*(.*)$")
        if spk and #spk <= 16 then pStr = rest end
        pStr = pStr:gsub("^%s+", ""):gsub("%s+$", "")
        if #pStr > 0 then
          table.insert(call._transcript, pStr)
        end
      end
    end
  end

  -- 3. Extract active live message
  local liveMsg, isWaiting, isNext, fullStr = extractCallMessage(dialogState, game)
  local activeLines = {}

  if dialogState then
    local curPage = (dialogState.pages and (dialogState.pageIndex or 1)) or 1
    local commitCandidate = (fullStr and #fullStr > 0) and fullStr or liveMsg
    if commitCandidate and #commitCandidate > 0 then
      call._lastPending = {
        dialog = dialogState,
        page = curPage,
        text = commitCandidate,
      }
    end

    if liveMsg and #liveMsg > 0 then
      activeLines = wrapToWidth(liveMsg, maxTextW, "body")
    end
  end

  -- 4. If transcript is empty and no active lines from dialogue, fallback to call.text
  if #call._transcript == 0 and #activeLines == 0 then
    local callerName = call.name or (call.contact and tostring(call.contact)) or "CALLER"
    local fallback = call.text or (callerName .. ": ……")
    local spk, rest = fallback:match("^([%w%._'%s%-]+):%s*(.*)$")
    if spk and #spk <= 16 then fallback = rest end
    fallback = Layout.cleanText(fallback):gsub("^%s+", ""):gsub("%s+$", "")
    activeLines = wrapToWidth(fallback, maxTextW, "body")
  end

  -- 5. Flatten committed transcript blocks into display lines
  local allLines = {}
  for _, block in ipairs(call._transcript) do
    local bLines = wrapToWidth(block, maxTextW, "body")
    for _, bl in ipairs(bLines) do
      if bl and #bl > 0 then
        table.insert(allLines, bl)
      end
    end
  end
  for _, al in ipairs(activeLines) do
    if al and #al > 0 then
      table.insert(allLines, al)
    end
  end

  -- Bound transcript memory to prevent unbounded growth
  if #call._transcript > 40 then
    while #call._transcript > 25 do
      table.remove(call._transcript, 1)
    end
  end

  return allLines, isWaiting, isNext
end

-- 3. PHONE CARD
local function drawPhoneCard(game, state, x, y, w, h, theme, isNarrow, subState)
  local hasService = true
  if state.phoneContext and state.mapHasService then
    hasService = state:mapHasService(state:phoneContext())
  end

  local contacts = (state.phoneList and state:phoneList()) or {}
  local phoneScroll = state.phoneScroll or 0
  local phoneCursor = state.phoneCursor or 0
  local selectedIndex = phoneScroll + phoneCursor + 1

  -- If a call is active, render interactive Call Screen Modal (Phone Chat UI)
  if state.call then
    local call = state.call
    local callerName = call.name or (call.contact and tostring(call.contact)) or "UNKNOWN"
    local dialogState, choiceState = getActiveCallDialogue(game, state, subState)

    local mw = math.min(w - 24, 460)
    local targetH = choiceState and 380 or 340
    local mh = math.min(h - 16, targetH)
    local mx = math.floor((w - mw) / 2)
    local my = math.max(8, math.floor((h - mh) / 2))
    mh = math.min(mh, h - my - 8)

    love.graphics.setColor(0, 0, 0, 0.70)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Phone Frame Card
    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = (call.kind == "nosignal") and theme.colors.hpRed or theme.colors.accent,
      borderWidth = 2,
      radius = 12,
    })

    -- Speaker Notch
    local notchW = 44
    Layout.drawSlot(mx + math.floor((mw - notchW) / 2), my + 6, notchW, 4, { color = theme.surfaceHigh, radius = 2 })

    -- Call Header Banner
    local headerH = 46
    Layout.drawSlot(mx + 10, my + 14, mw - 20, headerH, { color = theme.surfaceHigh, radius = 6 })

    local initStr = (callerName:sub(1, 1)):upper()
    Layout.drawBadge(mx + 18, my + 21, initStr, { kind = "primary", font = "headline", width = 32, height = 32, radius = 16 })

    Layout.drawText(callerName:upper(), mx + 56, my + 19, { font = "headline", color = theme.heading, bold = true })
    local subDesc = (call.kind == "nosignal") and "NO SERVICE AREA" or "CELLULAR VOICE CALL"
    Layout.drawText(subDesc, mx + 56, my + 38, { font = "tiny", color = theme.textDim })

    local sigText = (call.kind == "nosignal") and "NO SIGNAL" or "● IN CALL"
    local sigKind = (call.kind == "nosignal") and "danger" or "good"
    Layout.drawBadge(mx + mw - 105, my + 25, sigText, { kind = sigKind, font = "tiny", height = 24 })

    -- Bottom Hang Up Button
    local footH = 38
    local footY = my + mh - footH - 8

    -- Chat Stream Area (filling between header and hang up bar)
    local chatY = my + 64
    local chatH = footY - chatY - 6
    Layout.drawSlot(mx + 10, chatY, mw - 20, chatH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

    Layout.drawText("VOICE CONNECTION ENCRYPTED", mx + 16, chatY + 6, { font = "tiny", color = theme.textMuted, align = "center", width = mw - 32 })

    local bubbleX = mx + 18
    local bubbleW = mw - 36
    Layout.drawText(callerName:upper() .. ":", bubbleX + 4, chatY + 22, { font = "caption", color = theme.accent, bold = true })

    -- Expand message card vertically to maximize usable dialogue capacity
    local msgCardY = chatY + 38
    local choiceAreaH = choiceState and 68 or 0
    local msgCardH = chatH - 38 - (choiceState and (choiceAreaH + 6) or 8)

    Layout.drawCard(bubbleX, msgCardY, bubbleW, msgCardH, { color = theme.surface, borderColor = theme.borderStrong, radius = 6 })

    -- Accumulating transcript lines flow
    local allLines, isWaiting, isNext = updateCallTranscript(call, dialogState, game, bubbleW)

    local textPadX = 12
    local textPadTop = 8
    local lineH = math.max(16, Layout.textHeight("body") + 4)
    local bottomReserved = (isWaiting and not choiceState) and 28 or 10
    local textAvailH = msgCardH - textPadTop - bottomReserved
    local maxLines = math.max(2, math.floor(textAvailH / lineH))

    local numLines = #allLines
    local startLineIdx = math.max(1, numLines - maxLines + 1)
    local visibleCount = math.min(numLines, maxLines)

    for i = 1, visibleCount do
      local lineIdx = startLineIdx + i - 1
      local lText = allLines[lineIdx]
      local ly = msgCardY + textPadTop + (i - 1) * lineH
      Layout.drawText(lText, bubbleX + textPadX, ly, { font = "body", color = theme.heading, width = bubbleW - textPadX * 2 })
    end

    -- Bouncing button hint anchored safely inside the expanded message card
    if isWaiting and not choiceState then
      local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
      local bounce = math.floor(math.sin(now * 8) * 2)
      local indLabel = isNext and "Next" or "Close"
      local hintY = msgCardY + msgCardH - 24 + bounce
      Layout.drawButtonHint(bubbleX + bubbleW - 84, hintY, "A", indLabel, { primary = true })
    end

    -- Choice Modal inside Chat if active
    if choiceState then
      local rawChoices = choiceState.options or choiceState.labels or choiceState.choices or choiceState.items or { "YES", "NO" }
      local curChoice = choiceState.cursor or choiceState.index or choiceState.default_index or 1
      local cLabels = {}
      for _, it in ipairs(rawChoices) do
        cLabels[#cLabels + 1] = Layout.cleanText((type(it) == "table" and (it.label or it.name or it[1])) or tostring(it))
      end
      local choiceY = msgCardY + msgCardH + 6
      local gap = 8
      local numC = math.max(1, #cLabels)
      local btnW = math.floor((bubbleW - (numC - 1) * gap) / numC)
      for ci, opt in ipairs(cLabels) do
        local isSel = (curChoice == ci)
        local bx = bubbleX + (ci - 1) * (btnW + gap)
        Layout.drawButton(bx, choiceY, btnW, 32, opt, {
          kind = isSel and "primary" or "ghost",
          selected = isSel,
          font = "body",
        })
      end
      Layout.drawText("▲ ▼ Select   A Confirm", bubbleX, choiceY + 36, {
        font = "tiny",
        color = theme.textDim,
        align = "center",
        width = bubbleW,
      })
    end

    -- Render Bottom Hang Up Button
    local btnLabel = choiceState and "HANG UP (PRESS B)" or (isWaiting and "PRESS A TO CONTINUE // B TO HANG UP" or "HANG UP (PRESS A / B)")
    Layout.drawButton(mx + 10, footY, mw - 20, footH, btnLabel, {
      kind = choiceState and "ghost" or "danger",
      selected = (choiceState == nil),
      font = "body",
    })
    return
  end

  -- Contact Submenu Modal (CALL, DELETE, CANCEL)
  if state.phoneSubmenu then
    local menu = state.PHONE_SUBMENUS and state.PHONE_SUBMENUS[state.phoneSubmenu]
    local entries = menu and menu.entries or { "CALL", "CANCEL" }
    local subCursor = (state.phoneSubmenuCursor or 0) + 1

    local mw = math.min(w - 40, 320)
    local mh = 50 + #entries * 46
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    love.graphics.setColor(0, 0, 0, 0.60)
    love.graphics.rectangle("fill", 0, 0, w, h)

    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    Layout.drawText("CONTACT ACTION", mx + 20, my + 16, { font = "headline", color = theme.heading, bold = true })

    local by = my + 50
    for idx, opt in ipairs(entries) do
      local isSel = (subCursor == idx)
      local label = (opt == "CALL" and "CALL CONTACT")
                 or (opt == "DELETE" and "DELETE NUMBER")
                 or "CANCEL"
      Layout.drawButton(mx + 16, by, mw - 32, 38, label, {
        kind = isSel and ((opt == "DELETE") and "danger" or "primary") or "ghost",
        selected = isSel,
        font = "body",
      })
      by = by + 44
    end
    return
  end

  -- Standard Phone Directory View
  local listW = isNarrow and w or math.floor(w * 0.58)
  local detailW = isNarrow and 0 or (w - listW - 14)

  -- Left: Contact List Card
  Layout.drawCard(x, y, listW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })

  -- Signal status header
  Layout.drawSlot(x + 10, y + 8, listW - 20, 32, { color = theme.surfaceHigh, radius = 6 })
  Layout.drawText("CONTACT DIRECTORY", x + 20, y + 16, { font = "caption", color = theme.textDim, bold = true })
  local sigBadge = hasService and "4G NETWORK" or "NO SERVICE"
  Layout.drawBadge(x + listW - (isNarrow and 100 or 120), y + 12, sigBadge, {
    kind = hasService and "good" or "danger",
    font = "tiny",
    height = 22,
  })

  local itemH = 46
  local itemGap = 6
  local itemStep = itemH + itemGap
  local visibleRows = math.max(1, math.floor((h - 60) / itemStep))

  local rawList = {}
  for i, cid in ipairs(contacts) do
    if cid and cid ~= 0 then
      local name, className = cid, nil
      if state.contactRow then
        name, className = state:contactRow(cid)
      end
      rawList[#rawList + 1] = { id = cid, name = name or ("CONTACT #" .. i), className = className }
    end
  end

  local totalContacts = #rawList

  if totalContacts == 0 then
    Layout.drawSlot(x + 16, y + 60, listW - 32, 60, { color = theme.surfaceHigh, radius = 6 })
    Layout.drawText("NO CONTACTS REGISTERED", x + 28, y + 82, { font = "body", color = theme.textMuted, align = "center", width = listW - 56 })
  else
    -- Normalize and clamp phoneScroll & phoneCursor to totalContacts and visibleRows
    local curPos = (phoneScroll or 0) + (phoneCursor or 0) + 1
    if curPos > totalContacts then
      curPos = totalContacts
      if curPos <= visibleRows then
        state.phoneScroll = 0
        state.phoneCursor = curPos - 1
      else
        state.phoneScroll = curPos - visibleRows
        state.phoneCursor = visibleRows - 1
      end
      phoneScroll = state.phoneScroll
      phoneCursor = state.phoneCursor
    end
    selectedIndex = math.max(1, math.min(totalContacts, (phoneScroll or 0) + (phoneCursor or 0) + 1))

    for slot = 1, visibleRows do
      local idx = (phoneScroll or 0) + slot
      local c = rawList[idx]
      if not c then break end

      local isSel = ((phoneCursor or 0) + 1 == slot)
      local py = y + 48 + (slot - 1) * itemStep

      if isSel then
        Layout.drawCard(x + 10, py, listW - 20, itemH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
      else
        Layout.drawSlot(x + 10, py, listW - 20, itemH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          radius = 6,
        })
      end

      Layout.drawText(tostring(c.name), x + 20, py + (c.className and 6 or 14), {
        font = "body",
        color = isSel and theme.heading or theme.text,
        bold = isSel,
        width = listW - 140,
      })
      if c.className then
        Layout.drawText(tostring(c.className), x + 20, py + 26, { font = "tiny", color = isSel and theme.colors.accent or theme.textDim })
      end

      Layout.drawBadge(x + listW - 80, py + 11, "DIAL >", {
        kind = isSel and "primary" or "ghost",
        font = "tiny",
        height = 24,
      })
    end
  end

  -- Right: Selected Contact Inspector (Widescreen only)
  if not isNarrow and detailW > 0 then
    local detailX = x + listW + 14
    Layout.drawCard(detailX, y, detailW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local activeContact = rawList[selectedIndex]
    if activeContact then
      Layout.drawSlot(detailX + 16, y + 16, detailW - 32, 60, { color = theme.surfaceHigh, radius = 6 })
      Layout.drawText("CONTACT DETAILS", detailX + 26, y + 26, { font = "tiny", color = theme.textMuted })
      Layout.drawText(tostring(activeContact.name), detailX + 26, y + 42, { font = "headline", color = theme.heading, bold = true })

      local infoY = y + 90
      Layout.drawCard(detailX + 16, infoY, detailW - 32, 120, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("CATEGORY:", detailX + 26, infoY + 16, { font = "caption", color = theme.textDim })
      Layout.drawText(activeContact.className or "SPECIAL CONTACT", detailX + 26, infoY + 34, { font = "body", color = theme.accent, bold = true })

      Layout.drawText("CELLULAR CARRIER:", detailX + 26, infoY + 68, { font = "caption", color = theme.textDim })
      Layout.drawText("SILPH NETWORK // JOHTO", detailX + 26, infoY + 86, { font = "body", color = theme.heading })

      -- Quick Dial Button
      Layout.drawButton(detailX + 16, y + h - 56, detailW - 32, 42, "CALL CONTACT (PRESS A)", {
        kind = "primary",
        selected = true,
        font = "body",
      })
    else
      Layout.drawText("Select a contact to view info", detailX + 24, y + 40, { font = "body", color = theme.textMuted })
    end
  end
end

-- 4. RADIO CARD
local function drawRadioCard(game, state, x, y, w, h, theme, isNarrow)
  state:ensureTuned()
  local stations = (state.stations and state:stations()) or {}
  local curStation = (state.currentStation and state:currentStation()) or {}
  local tuningKnob = state.tuningKnob or 0
  local stationName = (state.radio and state.radio.stationName) or curStation.name or "NO SIGNAL / STATIC"
  local topText = (state.radio and state.radio.top) or ""
  local botText = (state.radio and state.radio.bottom) or ""

  local time = love.timer and love.timer.getTime() or 0

  if isNarrow then
    -- Narrow / Mobile Radio View
    local tunerH = 130
    Layout.drawCard(x, y, w, tunerH, { color = theme.surfaceHigh, borderColor = theme.borderStrong, radius = 8 })

    Layout.drawText("FM RADIO RECEIVER", x + 16, y + 14, { font = "caption", color = theme.textDim, bold = true })
    Layout.drawBadge(x + w - 100, y + 10, ("%04.1f MHz"):format((tuningKnob + 2) / 4), { kind = "accent", font = "caption", height = 24 })

    -- Frequency Dial Scale Bar
    local dialX = x + 16
    local dialY = y + 54
    local dialW = w - 32
    Layout.drawSlot(dialX, dialY, dialW, 20, { color = { 0.05, 0.08, 0.12, 1.0 }, radius = 4 })

    -- Tuner Knob Needle
    local needlePct = math.max(0, math.min(1, tuningKnob / 80))
    local needleX = dialX + math.floor(needlePct * (dialW - 8))
    love.graphics.setColor(theme.colors.hpRed[1], theme.colors.hpRed[2], theme.colors.hpRed[3], 1)
    love.graphics.rectangle("fill", needleX, dialY - 4, 8, 28, 2, 2)

    -- Station Name Bar
    Layout.drawSlot(x + 16, y + 88, w - 32, 32, { color = theme.surface, radius = 6 })
    Layout.drawText("CH: " .. stationName, x + 24, y + 96, { font = "caption", color = theme.heading, bold = true, width = w - 48 })

    -- Broadcast Message Box
    local transY = y + tunerH + 10
    local transH = h - tunerH - 10
    Layout.drawCard(x, transY, w, transH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    Layout.drawText("LIVE BROADCAST TRANSCRIPT", x + 16, transY + 14, { font = "tiny", color = theme.textMuted })
    Layout.drawSlot(x + 12, transY + 34, w - 24, transH - 46, { color = theme.surfaceHigh, radius = 6 })
    Layout.drawTextWrapped(topText .. (topText ~= "" and "\n" or "") .. botText, x + 22, transY + 46, w - 44, {
      font = "body",
      color = theme.text,
    })
  else
    -- Widescreen 2-Column Radio Station Hub
    local colW = math.floor((w - 14) / 2)

    -- Left Column: Tuner & Station Frequency Dial
    Layout.drawCard(x, y, colW, h, { color = theme.surfaceHigh, borderColor = theme.borderStrong, radius = 8 })

    Layout.drawText("FM RADIO RECEIVER", x + 24, y + 20, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(x + colW - 130, y + 18, ("%04.1f MHz"):format((tuningKnob + 2) / 4), { kind = "accent", font = "caption", height = 24 })

    -- Frequency Spectrum Graphic
    local specY = y + 60
    Layout.drawSlot(x + 20, specY, colW - 40, 50, { color = { 0.05, 0.08, 0.12, 1.0 }, radius = 6 })
    local barCount = 18
    local barW = math.floor((colW - 80) / barCount)
    for bi = 1, barCount do
      local barH = math.floor(10 + 20 * math.abs(math.sin(time * 4 + bi * 0.4)))
      local bx = x + 30 + (bi - 1) * (barW + 2)
      local by = specY + 45 - barH
      love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], 0.85)
      love.graphics.rectangle("fill", bx, by, barW, barH, 2, 2)
    end

    -- Frequency Slider
    local dialY = specY + 68
    Layout.drawSlot(x + 20, dialY, colW - 40, 24, { color = { 0.04, 0.06, 0.09, 1.0 }, radius = 4 })
    local needlePct = math.max(0, math.min(1, tuningKnob / 80))
    local needleX = (x + 20) + math.floor(needlePct * (colW - 48))
    love.graphics.setColor(theme.colors.hpRed[1], theme.colors.hpRed[2], theme.colors.hpRed[3], 1)
    love.graphics.rectangle("fill", needleX, dialY - 4, 8, 32, 2, 2)

    -- Station Presets Listing
    local presetY = dialY + 42
    Layout.drawText("AVAILABLE BROADCAST STATIONS", x + 24, presetY, { font = "tiny", color = theme.textMuted })
    local py = presetY + 18
    for _, st in ipairs(stations) do
      local isCur = (st.knob == tuningKnob)
      Layout.drawSlot(x + 20, py, colW - 40, 32, {
        color = isCur and theme.accentDark or theme.surface,
        borderColor = isCur and theme.borderStrong or theme.border,
        radius = 6,
      })
      Layout.drawText(st.name or "STATIC", x + 30, py + 8, {
        font = "caption",
        color = isCur and theme.heading or theme.textDim,
        bold = isCur,
      })
      Layout.drawBadge(x + colW - 90, py + 5, st.frequency .. " MHz", {
        kind = isCur and "good" or "ghost",
        font = "tiny",
        height = 22,
      })
      py = py + 36
      if py > y + h - 40 then break end
    end

    -- Right Column: Live Broadcast Marquee & Transcript
    local rightX = x + colW + 14
    Layout.drawCard(rightX, y, colW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })

    Layout.drawText("BROADCAST MONITOR", rightX + 24, y + 20, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(rightX + colW - 100, y + 18, "ON AIR", { kind = "danger", font = "tiny", height = 22 })

    -- Current Station Banner
    Layout.drawSlot(rightX + 20, y + 60, colW - 40, 48, { color = theme.surfaceHigh, radius = 6 })
    Layout.drawText("TUNED CHANNEL", rightX + 32, y + 68, { font = "tiny", color = theme.textMuted })
    Layout.drawText("CH: " .. stationName, rightX + 32, y + 84, { font = "body", color = theme.heading, bold = true })

    -- Live Scrolling Script Card
    local scriptY = y + 120
    local scriptH = h - 140
    Layout.drawSlot(rightX + 20, scriptY, colW - 40, scriptH, { color = theme.surfaceHigh, radius = 6 })
    Layout.drawText("TRANSCRIPT FEED", rightX + 32, scriptY + 12, { font = "tiny", color = theme.textMuted })

    local fullText = (topText ~= "" and (topText .. "\n") or "") .. botText
    if fullText == "" then fullText = "Listening for audio broadcast transmission..." end
    Layout.drawTextWrapped(fullText, rightX + 32, scriptY + 36, colW - 64, {
      font = "body",
      color = theme.text,
    })
  end
end

-- -----------------------------------------------------------------------------
-- 5. DEXNAV CARD (Kanto-Reforged Habitat & Wild Species Monitor)
-- -----------------------------------------------------------------------------
local function ensureDexNavData(state, game)
  if not state then return end
  if not state._krDexNavItems then
    local pgc = package.loaded["mods.pokegear_cards.cards"]
    if pgc and pgc.get then
      local entry = pgc.get("dexnav")
      if entry and entry.onHighlight then
        pcall(entry.onHighlight, state)
      end
    end
  end
  if not state._krDexNavItems then
    local okKR, DexNav = pcall(require, "mods.Kanto-Reforged.ui.dexnav")
    if okKR and DexNav and DexNav.buildItems then
      local g = game or state.game
      local mapId = (DexNav.currentMapId and DexNav.currentMapId(g)) or (g and g.save and g.save.player and g.save.player.map) or "CURRENT AREA"
      local dex = DexNav.dexFlags and DexNav.dexFlags(g and g.save and g.save.pokedex)
      local items, footer = DexNav.buildItems(g and g.data, mapId, dex, nil, nil)
      if not items or #items == 0 then
        items = { { label = "No wild Pokemon here.", right = "", value = nil } }
      end
      state._krDexNavItems = items
      state._krDexNavFooter = footer
      state._krDexNavCursor = 0
      state._krDexNavScroll = 0
      state._krDexNavMap = mapId
    end
  end
end

local function buildEncounterAdvice(g, st, spId, def, item, seen, owned, mTitle)
  local rightVal = item and item.right and tostring(item.right):upper() or ""
  local isRoam = rightVal:find("ROAM") ~= nil

  if not seen and not owned then
    return "UNRECORDED SPECIES", "UNKNOWN", {
      "AN UNRECORDED WILD POKEMON INHABITS THIS ROUTE.",
      "SEARCH LOCAL TERRAIN TO ENCOUNTER AND RECORD ITS DATA.",
    }
  end

  if isRoam then
    return "ROAMING SPECIES DETECTED", "ROAMING", {
      "ROAMING LEGENDARY! MOVES BETWEEN ROUTES AS YOU TRAVEL.",
      "USE FAST BALLS OR MEAN LOOK TO PREVENT ESCAPE.",
    }
  end

  local d = g and g.data
  local mId = st and st._krDexNavMap
  local inMorn, inDay, inNite = false, false, false
  local inWater = rightVal:find("SURF") ~= nil or rightVal:find("WATER") ~= nil
  local inFish = rightVal:find("FISH") ~= nil or rightVal:find("ROD") ~= nil
  local inGrass = rightVal:find("GRASS") ~= nil

  local function matchesSlot(slot)
    if not slot then return false end
    local s = slot.species or slot.id or slot[2] or slot[1]
    if not s then return false end
    if s == spId then return true end
    if type(s) == "string" and type(spId) == "string" and s:upper() == spId:upper() then return true end
    if def then
      if def.name and (s == def.name or (type(s) == "string" and s:upper() == def.name:upper())) then return true end
      if def.id and (s == def.id or (type(s) == "string" and s:upper() == tostring(def.id):upper())) then return true end
    end
    return false
  end

  local g2 = d and d.gen2Encounters
  if g2 and mId then
    local grassRow = g2.grass and g2.grass[mId]
    if grassRow and grassRow.slots then
      local slots = grassRow.slots
      if slots.MORN or slots.DAY or slots.NITE then
        for _, s in ipairs(slots.MORN or {}) do if matchesSlot(s) then inMorn = true inGrass = true end end
        for _, s in ipairs(slots.DAY or {}) do if matchesSlot(s) then inDay = true inGrass = true end end
        for _, s in ipairs(slots.NITE or {}) do if matchesSlot(s) then inNite = true inGrass = true end end
      elseif slots[1] then
        for _, s in ipairs(slots) do if matchesSlot(s) then inGrass = true inMorn = true inDay = true inNite = true end end
      end
    end

    local waterRow = g2.water and g2.water[mId]
    if waterRow and waterRow.slots then
      for _, s in ipairs(waterRow.slots) do if matchesSlot(s) then inWater = true end end
    end
  end

  if not inGrass and not inWater and d and d.encounters and mId and d.encounters[mId] then
    local enc = d.encounters[mId]
    if enc.grass and enc.grass.slots then
      for _, s in ipairs(enc.grass.slots) do if matchesSlot(s) then inGrass = true inMorn = true inDay = true inNite = true end end
    end
    if enc.water and enc.water.slots then
      for _, s in ipairs(enc.water.slots) do if matchesSlot(s) then inWater = true end end
    end
  end

  if not inFish and d and d.field and d.field.superRod and mId and d.field.superRod[mId] then
    for _, s in ipairs(d.field.superRod[mId]) do if matchesSlot(s) then inFish = true end end
  end

  local onlyNite = inNite and not inMorn and not inDay
  local onlyMorn = inMorn and not inDay and not inNite
  local onlyDay = inDay and not inMorn and not inNite
  local mornAndDay = inMorn and inDay and not inNite
  local mornAndNite = inMorn and inNite and not inDay

  local methodStr
  if inFish and onlyNite then
    methodStr = "FISHING (NIGHT)"
  elseif inFish then
    methodStr = "FISHING"
  elseif inWater and onlyNite then
    methodStr = "SURFING (NIGHT)"
  elseif inWater then
    methodStr = "SURFING"
  elseif onlyNite then
    methodStr = "NIGHT (TALL GRASS)"
  elseif onlyMorn then
    methodStr = "MORNING (TALL GRASS)"
  elseif onlyDay then
    methodStr = "DAY (TALL GRASS)"
  elseif mornAndDay then
    methodStr = "DAY & MORNING"
  elseif inGrass then
    methodStr = "TALL GRASS"
  else
    methodStr = (rightVal ~= "" and rightVal ~= "SEEN") and rightVal or "WILD ENCOUNTER"
  end

  if owned and rightVal ~= "" and rightVal ~= "SEEN" and rightVal:find("%d") then
    methodStr = rightVal
  end

  local advTitle, lines
  if inFish and onlyNite then
    advTitle = "NOCTURNAL ANGLER ADVICE"
    lines = {
      "NOCTURNAL WATER CATCH! FOUND BY CASTING A ROD",
      "INTO LOCAL WATERS AT NIGHT (6:00 PM - 3:59 AM).",
    }
  elseif inFish then
    advTitle = "FISHING HABITAT ADVICE"
    lines = {
      "HOOKED BY FISHING IN LOCAL WATERS AND SHORES.",
      "REQUIRES AN OLD ROD, GOOD ROD, OR SUPER ROD.",
    }
  elseif inWater and onlyNite then
    advTitle = "NOCTURNAL SURFING ADVICE"
    lines = {
      "ACTIVE IN OPEN WATERWAYS AT NIGHT (6:00 PM - 3:59 AM).",
      "NAVIGATE LOCAL WATERWAYS WITH SURF AFTER DARK.",
    }
  elseif inWater then
    advTitle = "AQUATIC HABITAT ADVICE"
    lines = {
      "INHABITS WATERWAYS AND PONDS. TRAVERSE LOCAL",
      "WATERS USING SURF TO TRIGGER ENCOUNTERS.",
    }
  elseif onlyNite then
    advTitle = "NOCTURNAL HABITAT ADVICE"
    lines = {
      "STRICTLY NOCTURNAL! APPEARS IN TALL GRASS ONLY",
      "AT NIGHT (6:00 PM - 3:59 AM). SEARCH AFTER DUSK.",
    }
  elseif onlyMorn then
    advTitle = "EARLY MORNING ADVICE"
    lines = {
      "EARLY RISER! FOUND IN TALL GRASS ONLY DURING",
      "MORNING HOURS (4:00 AM - 9:59 AM).",
    }
  elseif onlyDay then
    advTitle = "DIURNAL HABITAT ADVICE"
    lines = {
      "DAYLIGHT ONLY! FOUND IN TALL GRASS ONLY DURING",
      "THE DAY (10:00 AM - 5:59 PM). INACTIVE AFTER DUSK.",
    }
  elseif mornAndDay then
    advTitle = "DAYLIGHT HABITAT ADVICE"
    lines = {
      "ACTIVE IN DAYLIGHT HOURS (4:00 AM - 5:59 PM).",
      "SEARCH TALL GRASS IN MORNING OR DAY. SLEEPS AT NIGHT.",
    }
  elseif mornAndNite then
    advTitle = "TWILIGHT HABITAT ADVICE"
    lines = {
      "ACTIVE DURING LOW-LIGHT HOURS IN THE MORNING AND",
      "AT NIGHT. RETREATS DURING BRIGHT DAYLIGHT.",
    }
  else
    advTitle = "HABITAT MONITOR ADVICE"
    lines = {
      "COMMON HABITAT RESIDENT. RUSTLES IN TALL GRASS",
      "ACROSS ALL TIMES OF DAY (MORNING, DAY, AND NIGHT).",
    }
  end

  return advTitle, methodStr, lines
end

local function drawDexNavCard(game, state, x, y, w, h, theme, isNarrow)
  ensureDexNavData(state, game)
  local items = state._krDexNavItems or {}
  local footer = state._krDexNavFooter
  local cursor = state._krDexNavCursor or 0
  local scroll = state._krDexNavScroll or 0
  local total = #items

  local mapId = state._krDexNavMap or (game and game.save and game.save.player and game.save.player.map) or "CURRENT HABITAT"
  local mapTitle = tostring(mapId):gsub("_", " ")

  local ctx = Layout.getContext(w, h)
  local isPortrait = ctx.isPortrait or (w < h * 0.95)
  local isStacked = isPortrait or (isNarrow and h >= 460)

  local listW, listH, detailX, detailY, detailW, detailH

  if isStacked then
    listW = w
    listH = math.min(260, math.max(140, math.floor((h - 10) * 0.44)))
    detailX = x
    detailY = y + listH + 10
    detailW = w
    detailH = h - listH - 10
  elseif isNarrow and w < 480 then
    listW = w
    listH = h
    detailX = x
    detailY = y
    detailW = 0
    detailH = 0
  else
    listW = math.floor(w * (w < 720 and 0.52 or 0.55))
    listH = h
    detailX = x + listW + 12
    detailY = y
    detailW = w - listW - 12
    detailH = h
  end

  -- Left (or Top when stacked): Encounters Directory Card
  Layout.drawCard(x, y, listW, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

  -- Area Header Banner
  local countText = ("%d SPECIES"):format(total)
  local countBadgeW = Layout.textWidth(countText, "tiny") + 18
  Layout.drawSlot(x + 10, y + 8, listW - 20, 32, { color = theme.surfaceHigh, radius = 6 })
  Layout.drawText("HABITAT: " .. mapTitle, x + 20, y + 16, {
    font = "caption",
    color = theme.heading,
    bold = true,
    width = listW - 40 - countBadgeW - 10,
  })
  Layout.drawBadge(x + listW - countBadgeW - 14, y + 12, countText, {
    kind = "accent",
    font = "tiny",
    height = 22,
  })

  local footerH = (footer and tostring(footer) ~= "") and 28 or 0
  local itemH = 46
  local itemGap = 6
  local itemStep = itemH + itemGap
  local visibleRows = math.max(1, math.floor((listH - 52 - footerH) / itemStep))

  if total == 0 or (total == 1 and items[1].value == nil) then
    Layout.drawSlot(x + 16, y + 54, listW - 32, 64, { color = theme.surfaceHigh, radius = 6 })
    local msg = (items[1] and items[1].label) or "NO WILD POKEMON DETECTED"
    Layout.drawText(msg, x + 24, y + 78, { font = "body", color = theme.textMuted, align = "center", width = listW - 48 })
  else
    if cursor >= total then cursor = total - 1 end
    if cursor < 0 then cursor = 0 end
    if cursor < scroll then scroll = cursor end
    if cursor >= scroll + visibleRows then scroll = cursor - visibleRows + 1 end
    scroll = math.max(0, math.min(math.max(0, total - visibleRows), scroll))
    state._krDexNavScroll = scroll
    state._krDexNavCursor = cursor

    for slot = 1, visibleRows do
      local idx = scroll + slot
      local row = items[idx]
      if not row then break end

      local isSel = (cursor == idx - 1)
      local py = y + 48 + (slot - 1) * itemStep

      if isSel then
        Layout.drawCard(x + 10, py, listW - 20, itemH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
      else
        Layout.drawSlot(x + 10, py, listW - 20, itemH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          radius = 6,
        })
      end

      -- Right Method / Encounter Tag
      local rightVal = row.right
      local hasRight = rightVal and tostring(rightVal) ~= ""
      local rStr = hasRight and tostring(rightVal):upper() or ""
      local bw = 0

      if hasRight then
        local badgeKind = isSel and "accent" or "ghost"
        if rStr:find("GRASS") then
          badgeKind = isSel and "good" or "accent"
        elseif rStr:find("SURF") or rStr:find("WATER") then
          badgeKind = "accent"
        elseif rStr:find("ROAM") then
          badgeKind = "warn"
        end
        bw = Layout.textWidth(rStr, "tiny") + 16
        Layout.drawBadge(x + listW - bw - 20, py + 12, rStr, {
          kind = badgeKind,
          font = "tiny",
          height = 22,
        })
      end

      -- Label (strictly bounded before method badge)
      local lbl = row.label or "POKÉMON"
      local maxLabelW = listW - 44 - (hasRight and (bw + 12) or 0)
      Layout.drawText(tostring(lbl):upper(), x + 20, py + 14, {
        font = "body",
        color = isSel and theme.heading or theme.text,
        bold = isSel,
        width = maxLabelW,
      })
    end

    -- Scroll Indicators
    if scroll > 0 then
      Layout.drawText("▲", x + listW - 24, y + 42, { font = "tiny", color = theme.accent })
    end
    if scroll + visibleRows < total then
      Layout.drawText("▼", x + listW - 24, y + 48 + visibleRows * itemStep - 6, { font = "tiny", color = theme.accent })
    end
  end

  -- Bottom Footer Note if present
  if footer and tostring(footer) ~= "" then
    local fy = y + listH - footerH - 4
    Layout.drawSlot(x + 10, fy, listW - 20, 26, { color = theme.surfaceHigh, radius = 6 })
    Layout.drawText(tostring(footer), x + 16, fy + 6, { font = "tiny", color = theme.accent, align = "center", width = listW - 32 })
  end

  -- Right Column (or Bottom Card when stacked): Selected Species Detail Pane
  if detailW > 0 then
    Layout.drawCard(detailX, detailY, detailW, detailH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local selIdx = cursor + 1
    local selItem = items[selIdx]
    if selItem and selItem.value then
      local speciesId = selItem.value
      local data = game and game.data
      local pkDef = data and data.pokemon and data.pokemon[speciesId]
      local pokedex = game and game.save and game.save.pokedex

      -- Progressive reveal status (respects Gen 1 owned and Gen 2 caught flags)
      local isOwned = false
      local isSeen = false
      if pokedex then
        local ownedMap = pokedex.owned or pokedex.caught or {}
        local seenMap = pokedex.seen or {}
        if ownedMap[speciesId] or (pkDef and (ownedMap[pkDef.id] or ownedMap[pkDef.dex])) then
          isOwned = true
          isSeen = true
        elseif seenMap[speciesId] or (pkDef and (seenMap[pkDef.id] or seenMap[pkDef.dex])) then
          isSeen = true
        end
      end
      if selItem.label == "????" then
        isSeen = false
        isOwned = false
      end

      local isCompactDetail = detailH < 340
      local heroH = isCompactDetail and 58 or 72

      -- Hero Header Card
      Layout.drawSlot(detailX + 12, detailY + 12, detailW - 24, heroH, { color = theme.surfaceHigh, radius = 6 })
      local displayName = (isSeen or isOwned) and ((pkDef and pkDef.name) or selItem.label or speciesId) or "????"
      Layout.drawText(tostring(displayName):upper(), detailX + 24, detailY + (isCompactDetail and 14 or 20), {
        font = "headline",
        color = theme.heading,
        bold = true,
        width = detailW - 120,
      })

      local dexNum = (isSeen or isOwned) and pkDef and (pkDef.dex or pkDef.id)
      local numStr = dexNum and ("#%03d"):format(tonumber(dexNum) or 0) or "DEX ???"
      Layout.drawText(numStr, detailX + 24, detailY + (isCompactDetail and 36 or 48), {
        font = "caption",
        color = theme.accent,
        bold = true,
      })

      local statusText = isOwned and "OWNED" or (isSeen and "SEEN" or "UNSEEN")
      local statusKind = isOwned and "good" or (isSeen and "accent" or "ghost")
      Layout.drawBadge(detailX + detailW - 96, detailY + (isCompactDetail and 34 or 46), statusText, {
        kind = statusKind,
        font = "tiny",
        height = 22,
      })

      -- Encounter Specifications
      local specY = detailY + 12 + heroH + (isCompactDetail and 8 or 12)
      Layout.drawText("ENCOUNTER SPECIFICATION", detailX + 14, specY, { font = "tiny", color = theme.textMuted })

      local advTitle, methodText, rawAdviceLines = buildEncounterAdvice(game, state, speciesId, pkDef, selItem, isSeen, isOwned, mapTitle)

      local infoCardH = (isSeen or isOwned) and (isCompactDetail and 74 or 96) or (isCompactDetail and 56 or 70)
      Layout.drawCard(detailX + 12, specY + 14, detailW - 24, infoCardH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

      local labelW = 76
      local valX = detailX + 22 + labelW
      local valW = detailW - 44 - labelW

      local row1Y = specY + (isCompactDetail and 18 or 22)
      Layout.drawText("METHOD", detailX + 22, row1Y, { font = "caption", color = theme.textDim })
      Layout.drawText(methodText, valX, row1Y, { font = "caption", color = theme.heading, bold = true, align = "right", width = valW })

      local row2Y = row1Y + (isCompactDetail and 22 or 26)
      Layout.drawText("HABITAT", detailX + 22, row2Y, { font = "caption", color = theme.textDim })
      Layout.drawText(mapTitle, valX, row2Y, { font = "caption", color = theme.text, bold = true, align = "right", width = valW })

      -- Type badges if seen/owned
      if isSeen or isOwned then
        local types = pkDef and pkDef.types or {}
        local row3Y = row2Y + (isCompactDetail and 22 or 26)
        Layout.drawText("ELEMENT", detailX + 22, row3Y, { font = "caption", color = theme.textDim })
        local typeStr = table.concat(types, " / ")
        if typeStr == "" then typeStr = "NORMAL" end
        Layout.drawText(typeStr, valX, row3Y, { font = "caption", color = theme.accent, bold = true, align = "right", width = valW })
      end

      -- Roamer or Habitat Summary Advice Box
      local tipY = specY + 14 + infoCardH + (isCompactDetail and 8 or 12)
      local tipH = math.max(68, detailH - (tipY - detailY) - (isCompactDetail and 8 or 12))
      Layout.drawCard(detailX + 12, tipY, detailW - 24, tipH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

      local maxTextW = detailW - 48
      local titleColor = (advTitle:find("ROAMING") ~= nil) and ((theme.colors and theme.colors.hpRed) or theme.danger or theme.accent) or theme.accent
      Layout.drawText(advTitle, detailX + 24, tipY + 12, { font = "caption", color = titleColor, bold = true, width = maxTextW })

      local wrappedLines = wrapToWidth(rawAdviceLines, maxTextW, "tiny")
      local lineH = math.max(14, Layout.textHeight("tiny") + 3)
      local textStartY = tipY + 34
      for lineIdx, lineText in ipairs(wrappedLines) do
        local ly = textStartY + (lineIdx - 1) * lineH
        if ly + lineH - 2 <= tipY + tipH then
          Layout.drawText(lineText, detailX + 24, ly, {
            font = "tiny",
            color = theme.textDim,
            width = maxTextW,
          })
        end
      end
    else
      Layout.drawSlot(detailX + 16, detailY + 16, detailW - 32, 80, { color = theme.surfaceHigh, radius = 6 })
      Layout.drawText("SELECT A SPECIES", detailX + 24, detailY + 44, { font = "body", color = theme.textMuted, align = "center", width = detailW - 48 })
    end
  end
end

-- -----------------------------------------------------------------------------
-- Main Entry Point
-- -----------------------------------------------------------------------------

function PokegearRenderer.draw(game, state, w, h, theme, arg6, arg7, arg8)
  local subState = (type(arg6) == "table" and arg6) or (type(arg7) == "table" and arg7) or nil
  local animProgress = (type(arg6) == "number" and arg6) or (type(arg7) == "number" and arg7) or 1.0
  local viewport = (type(arg7) == "table" and not arg7.isChoiceBox and not arg7.labels and not arg7.isTextBox and arg7) or arg8

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 600) or ctx.isPortrait

  local cards = (state.visibleCards and state:visibleCards()) or state.cards or {
    { id = "clock", label = "CLOCK" },
    { id = "map", label = "MAP" },
    { id = "phone", label = "PHONE" },
    { id = "radio", label = "RADIO" },
  }

  -- Ensure DexNav tab is visible if Kanto-Reforged DexNav is enabled
  local hasDex = false
  for _, c in ipairs(cards) do
    if c.id == "dexnav" then hasDex = true break end
  end
  if not hasDex then
    local okKR, DexNav = pcall(require, "mods.Kanto-Reforged.ui.dexnav")
    if okKR and DexNav and DexNav.hasPokedex then
      local g = (state and state.game) or game
      if DexNav.hasPokedex(g) and (not DexNav.mode or DexNav.mode() ~= DexNav.MODE_OFF) then
        cards[#cards + 1] = {
          id = "dexnav",
          label = (DexNav.menuLabel and DexNav.menuLabel()) or "DEXNAV",
          icon = 0x40,
        }
      end
    end
  end

  local card = (state.card and state:card()) or cards[state.cardIndex or 1] or cards[1]
  local activeId = card and card.id or "clock"

  -- 1. Top Header & Card Navigation Tab Bar
  local headH = 48
  Layout.drawCard(0, 0, w, headH, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText("POKÉGEAR", 18, 14, { font = "headline", color = theme.heading, bold = true })

  -- Render Top Tab Bar for Unlocked Cards
  local tabStartX = isNarrow and 90 or 140
  local tabW = math.min(110, math.max(40, math.floor((w - tabStartX - 16) / #cards)))
  local tabH = 32
  local tabY = 8

  for i, c in ipairs(cards) do
    local isCardActive = (c.id == activeId)
    local meta = CARD_METADATA[c.id] or { label = c.label or c.id:upper(), tag = (c.label or c.id:upper()):sub(1, 3) }
    local tx = tabStartX + (i - 1) * (tabW + 6)
    if tx + tabW <= w - 10 then
      Layout.drawButton(tx, tabY, tabW, tabH, isNarrow and meta.tag or meta.label, {
        kind = isCardActive and "primary" or "ghost",
        selected = isCardActive,
        font = "caption",
      })
    end
  end

  -- 2. Card Content Viewport
  local contentY = headH + 8
  local contentH = h - headH - 48

  if activeId == "map" then
    drawMapCard(game, state, 0, contentY, w, contentH, theme, isNarrow)
  elseif activeId == "phone" then
    drawPhoneCard(game, state, 0, contentY, w, contentH, theme, isNarrow, subState)
  elseif activeId == "radio" then
    drawRadioCard(game, state, 0, contentY, w, contentH, theme, isNarrow)
  elseif activeId == "dexnav" then
    drawDexNavCard(game, state, 0, contentY, w, contentH, theme, isNarrow)
  else
    drawClockCard(game, state, 0, contentY, w, contentH, theme, isNarrow)
  end

  -- 3. Bottom Navigation Hint Bar
  local footY = h - 38
  local inCard = (state.mode == "card")
  local canSwap = state.kantoUnlocked and state:kantoUnlocked()
  local hints = {}

  if not inCard then
    local interactive = (activeId == "map" or activeId == "phone" or activeId == "radio" or activeId == "dexnav")
    hints = {
      { key = "◄ ►", label = "Switch Card" },
      interactive and { key = "A", label = "Open", primary = true } or nil,
      { key = "B", label = "Close Gear" },
    }
  elseif state.call then
    local dState, cState = getActiveCallDialogue(game, state, subState)
    if cState then
      hints = {
        { key = "▲ ▼", label = "Select" },
        { key = "A", label = "Confirm", primary = true },
        { key = "B", label = "Hang Up" },
      }
    elseif dState then
      hints = {
        { key = "A", label = "Next", primary = true },
        { key = "B", label = "Hang Up" },
      }
    else
      hints = {
        { key = "A / B", label = "Hang Up", primary = true },
      }
    end
  elseif state.phoneSubmenu then
    hints = {
      { key = "▲ ▼", label = "Select Action" },
      { key = "A", label = "Confirm", primary = true },
      { key = "B", label = "Cancel" },
    }
  elseif activeId == "map" then
    hints = {
      canSwap and { key = "◄ ►", label = "Swap Region" } or nil,
      { key = "▲ ▼", label = "Next Landmark" },
      { key = "B", label = "Back" },
    }
  elseif activeId == "phone" then
    hints = {
      { key = "▲ ▼", label = "Select Contact" },
      { key = "A", label = "Call / Menu", primary = true },
      { key = "B", label = "Back" },
    }
  elseif activeId == "radio" then
    hints = {
      { key = "▲ ▼", label = "Tune FM" },
      { key = "B", label = "Back" },
    }
  elseif activeId == "dexnav" then
    hints = {
      { key = "▲ ▼", label = "Browse Habitat" },
      { key = "B", label = "Back" },
    }
  else
    hints = {
      { key = "◄ ►", label = "Switch Card" },
      { key = "A", label = "Select Card", primary = true },
      { key = "B", label = "Close Gear" },
    }
  end

  local compact = {}
  for i = 1, 6 do if hints[i] then compact[#compact + 1] = hints[i] end end
  hints = compact

  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

PokegearRenderer.ensureDexNavData = ensureDexNavData
PokegearRenderer.wrapToWidth = wrapToWidth
PokegearRenderer.buildEncounterAdvice = buildEncounterAdvice
PokegearRenderer.getActiveCallDialogue = getActiveCallDialogue
PokegearRenderer.extractCallMessage = extractCallMessage
PokegearRenderer.updateCallTranscript = updateCallTranscript

return PokegearRenderer

