-- OmniUI Dialogue & Message Engine Renderer
-- Clean floating speech box, speaker nameplate, GBA control code tokenization,
-- dynamic vertical box auto-flipping (Top vs Bottom), audio-synced reveal, and multi-column choice modals.

local Layout = require("mods.omni_ui.core.Layout")
local Theme = require("mods.omni_ui.core.Theme")

local DialogueRenderer = {}

function DialogueRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end
  theme = theme or Theme.get()

  local ctx = Layout.getContext(vw, vh, viewport)

  local dConf = (theme.layout and theme.layout.dialogue) or {
    maxWidth = 740,
    height = 114,
    marginBottom = 24,
    nameplateHeight = 30,
    nameplateAlign = "left",
    nameplateMargin = 20,
  }

  local dw = math.min(vw - (ctx.isCompact and 16 or 36), dConf.maxWidth or 740)
  local dh = (ctx.isUltraCompact) and 92 or (dConf.height or 114)
  local dx = math.floor((vw - dw) / 2)
  local marginBottom = (ctx.isUltraCompact) and 8 or (ctx.isCompact and 14 or (dConf.marginBottom or 24))

  -- 1. Dynamic Vertical Box Auto-Flipping (Screen Occlusion Prevention)
  local isTopAnchor = false
  if state.anchor == "top" or state.isTop or state.top or (state.boxTy and state.boxTy <= 2) then
    isTopAnchor = true
  elseif state.playerY and tonumber(state.playerY) and tonumber(state.playerY) >= 9 then
    isTopAnchor = true
  elseif game and game.player and game.player.y and tonumber(game.player.y) and (tonumber(game.player.y) >= 9) then
    isTopAnchor = true
  end

  local dy
  if isTopAnchor then
    dy = (ctx.safeInsetTop or 16) + (ctx.isPortrait and 8 or 12)
  else
    dy = ctx.isPortrait and math.min(vh - dh - 160, math.floor(vh * 0.44)) or (vh - dh - marginBottom)
  end

  -- Main Dialogue Window Card
  Layout.drawCard(dx, dy, dw, dh, {
    color = theme.surfaceHigh,
    borderColor = theme.borderStrong,
    borderWidth = 1,
    radius = theme.metrics and theme.metrics.radius.dialogue or 12,
  })

  -- Subtle hairline highlight on top border
  Layout.drawSlot(dx + 16, dy + 2, dw - 32, 2, {
    color = theme.accentDark,
    borderColor = theme.border,
    borderWidth = 0,
    radius = 1,
  })

  -- 2. Speaker Nameplate & Line Text Extraction
  local speakerName = state.speaker or state.nameplate
  local line1Text = ""
  local line2Text = ""

  -- Helper to word-wrap visible dialogue text into two balanced lines without mid-word cuts
  local function wrapTwoLines(str, maxCols)
    local nl = str:find("\n")
    if nl then
      local l1 = str:sub(1, nl - 1)
      local l2 = str:sub(nl + 1):gsub("\n", " ")
      return l1, l2
    end
    local words = {}
    for w in str:gmatch("%S+") do words[#words + 1] = w end
    if #words == 0 then return "", "" end
    local l1, l2 = "", ""
    for _, w in ipairs(words) do
      local test = (l1 == "") and w or (l1 .. " " .. w)
      if #test <= maxCols and l2 == "" then
        l1 = test
      else
        l2 = (l2 == "") and w or (l2 .. " " .. w)
      end
    end
    return l1, l2
  end

  local maxCols = ctx.isUltraCompact and 32 or (ctx.isCompact and 38 or 46)

  -- Gen 3 Message State (_pages, _page, _revealed, _total, _waiting)
  if state._pages and state._page and state._pages[state._page] then
    local curRaw = state._pages[state._page]
    local rawStr = (type(curRaw) == "table" and table.concat(curRaw, "\n")) or tostring(curRaw or "")
    local cleanStr = Layout.cleanText(rawStr)

    -- Extract speaker prefix if present (e.g. "OAK: Hello!")
    if not speakerName or speakerName == "" then
      local spk, rest = cleanStr:match("^([%w%._'%s%-]+):%s*(.*)$")
      if spk and #spk <= 16 then
        speakerName = spk
        cleanStr = rest
      end
    end

    local isFastForward = (game and game.logicSpeed and type(game.logicSpeed) == "function" and game:logicSpeed() > 1)
        or (game and game.input and type(game.input.isDown) == "function" and (game.input:isDown("a") or game.input:isDown("b")))
        or state._speedUp or state.instant or state.is_instant

    if isFastForward then
      state._suppressTypewriterSfx = true
      state._speedUp = true
    end

    local totalChars = #cleanStr
    local revealedCount = (isFastForward or state._waiting) and totalChars or math.min(totalChars, state._revealed or totalChars)
    local visibleText = cleanStr:sub(1, revealedCount)

    line1Text, line2Text = wrapTwoLines(visibleText, maxCols)

  -- Gen 3 RSE Printer Lines State (e.g. Birch speech)
  elseif state.lines or (state.printer and state.printer.lines) then
    local rawLines = state.lines or state.printer.lines
    local n = #rawLines
    if n >= 2 then
      line1Text = Layout.cleanText(tostring(rawLines[n - 1] or ""))
      line2Text = Layout.cleanText(tostring(rawLines[n] or ""))
    elseif n == 1 then
      line1Text = Layout.cleanText(tostring(rawLines[1] or ""))
      line2Text = ""
    end

    if not speakerName or speakerName == "" then
      local spk, rest = line1Text:match("^([%w%._'%s%-]+):%s*(.*)$")
      if spk and #spk <= 16 then
        speakerName = spk
        line1Text = rest
      end
    end

  -- Gen 3 FireRed / Paged Printer State (pages, page, revealed)
  elseif state.pages and state.page and state.pages[state.page] then
    local curRaw = state.pages[state.page]
    local rawStr = (type(curRaw) == "table" and table.concat(curRaw, "\n")) or tostring(curRaw or "")
    local cleanStr = Layout.cleanText(rawStr)

    if not speakerName or speakerName == "" then
      local spk, rest = cleanStr:match("^([%w%._'%s%-]+):%s*(.*)$")
      if spk and #spk <= 16 then
        speakerName = spk
        cleanStr = rest
      end
    end

    local isFastForward = (game and game.logicSpeed and type(game.logicSpeed) == "function" and game:logicSpeed() > 1)
        or (game and game.input and type(game.input.isDown) == "function" and (game.input:isDown("a") or game.input:isDown("b")))
        or state._speedUp or state.instant

    local totalChars = #cleanStr
    local revealedCount = (isFastForward or state._waiting) and totalChars or math.min(totalChars, state.revealed or (state.printer and state.printer.revealed) or totalChars)
    local visibleText = cleanStr:sub(1, revealedCount)

    line1Text, line2Text = wrapTwoLines(visibleText, maxCols)

  -- Gen 1/2 Classic Paged State (Flow full sentence/page text across modern dialogue width without 18-char chops)
  elseif state.pages and state.pageIndex and state.pages[state.pageIndex] then
    if state.isTextBox and not state.__omniContHooked and state.update then
      state.__omniContHooked = true
      local origUpdate = state.update
      state.update = function(self, dt)
        if self.waiting and self.contAdvance then
          self.waiting = false
          self.contAdvance = false
          self.preWait = 0
          self.lineIndex = self.lineIndex + 1
          self:beginLine()
          self.holdFrames = 0
        end
        return origUpdate(self, dt)
      end
    end
    local pageLines = state.pages[state.pageIndex]
    local fullStr = ""
    local currentRevealed = 0
    for lIdx, lText in ipairs(pageLines) do
      local cleanL = Layout.cleanText(tostring(lText or ""))
      if lIdx > 1 then
        fullStr = fullStr .. " "
        if (state.lineIndex or 1) >= lIdx then
          currentRevealed = currentRevealed + 1
        end
      end
      fullStr = fullStr .. cleanL
      if (state.lineIndex or 1) > lIdx then
        currentRevealed = currentRevealed + #cleanL
      elseif (state.lineIndex or 1) == lIdx then
        local cIdx = math.min(#cleanL, state.charIndex or #cleanL)
        currentRevealed = currentRevealed + cIdx
      end
    end

    local isFastForward = (game and game.logicSpeed and type(game.logicSpeed) == "function" and game:logicSpeed() > 1)
        or (game and game.input and type(game.input.isDown) == "function" and (game.input:isDown("a") or game.input:isDown("b")))
        or state.instant

    local isFullyWaiting = (state.waiting and not state.contAdvance) or state.done
    if isFullyWaiting or isFastForward then
      currentRevealed = #fullStr
    end

    local visibleText = fullStr:sub(1, currentRevealed)
    if not speakerName or speakerName == "" then
      local spk, rest = visibleText:match("^([%w%._'%s%-]+):%s*(.*)$")
      if spk and #spk <= 16 then
        speakerName = spk
        visibleText = rest
      end
    end

    line1Text, line2Text = wrapTwoLines(visibleText, maxCols)

  -- Dynamic visibleText method fallback
  elseif state.visibleText and type(state.visibleText) == "function" then
    local ok, vis = pcall(state.visibleText, state)
    if ok and vis then
      line1Text = Layout.cleanText(tostring(vis[1] or ""))
      line2Text = Layout.cleanText(tostring(vis[2] or ""))
      if not speakerName or speakerName == "" then
        local spk, rest = line1Text:match("^([%w%._'%s%-]+):%s*(.*)$")
        if spk and #spk <= 16 then
          speakerName = spk
          line1Text = rest
        end
      end
    end

  -- Simple text string
  elseif state.text then
    local raw = Layout.cleanText(tostring(type(state.text) == "function" and "" or state.text))
    if not speakerName or speakerName == "" then
      local spk, rest = raw:match("^([%w%._'%s%-]+):%s*(.*)$")
      if spk and #spk <= 16 then
        speakerName = spk
        line1Text = rest
      else
        line1Text = raw
      end
    else
      line1Text = raw
    end
  end

  local isExit = (line1Text .. " " .. line2Text):upper():find("RETURN TO MAIN") ~= nil or (line1Text .. " " .. line2Text):upper():find("MAIN MENU") ~= nil
  if (not speakerName or speakerName == "") and isExit then
    speakerName = "SYSTEM"
  end

  -- 3. Dedicated Raised Nameplate Card
  if speakerName and speakerName ~= "" then
    local spLabel = tostring(speakerName):upper()
    local spW = math.max(84, Layout.textWidth(spLabel, "headline") + 28)
    local spH = dConf.nameplateHeight or 30
    local spX = (dConf.nameplateAlign == "right") and (dx + dw - spW - (dConf.nameplateMargin or 20))
        or (dConf.nameplateAlign == "center") and (dx + math.floor((dw - spW) / 2))
        or (dx + (dConf.nameplateMargin or 20))
    local spY = isTopAnchor and (dy + dh - 4) or (dy - math.floor(spH * 0.6))

    Layout.drawCard(spX, spY, spW, spH, {
      color = theme.raised,
      borderColor = theme.borderStrong,
      borderWidth = 1.5,
      radius = theme.metrics and theme.metrics.radius.card or 8,
    })
    Layout.drawText(spLabel, spX + 14, spY + 6, {
      font = "headline",
      color = theme.heading,
      bold = true,
    })
  end

  -- 4. Dialogue Text Lines (High-Resolution Typography)
  local textX = dx + 28
  local line1Y = dy + (ctx.isUltraCompact and 16 or 24)
  local line2Y = dy + (ctx.isUltraCompact and 46 or 58)

  if line1Text ~= "" then
    Layout.drawText(line1Text, textX, line1Y, { font = ctx.isUltraCompact and "caption" or "headline", color = theme.heading, bold = false })
  end
  if line2Text ~= "" then
    Layout.drawText(line2Text, textX, line2Y, { font = ctx.isUltraCompact and "caption" or "headline", color = theme.heading, bold = false })
  end

  -- 5. Animated Prompt Cursor & Advance Indicator (\p bouncing chevron)
  local isWaiting = state._waiting or (state.waiting and not state.contAdvance) or (state.done and not state.auto and not state.stay and not state.choice)
  if isWaiting then
    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
    local bounceY = math.floor(math.sin(now * 8) * 3)

    local isNext = (state._page and state._pages and state._page < #state._pages)
        or (state.pageIndex and state.pages and state.pageIndex < #state.pages)
    local indLabel = isNext and "Next" or "Close"

    Layout.drawButtonHint(dx + dw - 110, dy + dh - (ctx.isUltraCompact and 26 or 32) + bounceY, "A", indLabel, { primary = true })
  end

  -- 6. Choice SubState / Modal (Synchronized Anchor Inversion & Multi-Column Support)
  local function isChoiceBoxState(s)
    if not s or s == state then return false end
    if s.isMenu or s.isPcMenu or s.isPlayerPC or s.isBoxMenu or s.isBag or s.isPartyMenu or s.isSummaryMenu or s.isOptionsMenu or s.isPokedexMenu or s.isTrainerCard or s.isStartMenu or s.isSaveMenu or s.isDiploma or s.isHallOfFame or s.isLeaguePC or s.isPokegear or s.isGen2Pokegear or s.cards then
      return false
    end
    local sid = s.screenId or s.id
    if sid and (sid == "PcMenu" or sid == "PlayerPC" or sid == "BoxMenu" or sid == "BagMenu" or sid == "PartyMenu" or sid == "SummaryMenu" or sid == "OptionsMenu" or sid == "PokedexMenu" or sid == "TrainerCard" or sid == "StartMenu" or sid == "Gen2StartMenu" or sid == "SaveMenu" or sid == "MainMenu" or sid == "CenterPcMenu" or sid == "ItemPcMenu" or sid == "Pokegear" or sid == "Gen2Pokegear") then
      return false
    end
    if s.showDescription ~= nil or (s.list and s.list.spacing) or (s.unlocked and s.visibleItems) then
      return false
    end
    local mt = getmetatable(s)
    if mt and (mt == package.loaded["src.ui.gen2.StartMenu"] or mt == package.loaded["src.ui.StartMenu"] or mt == package.loaded["src.ui.gen2.Pokegear"] or mt == package.loaded["src.ui.Pokegear"]) then
      return false
    end
    local ModernOverlay = package.loaded["mods.omni_ui.core.ModernOverlay"]
    if ModernOverlay and ModernOverlay.isSupported then
      local k = ModernOverlay.isSupported(s)
      if k and k ~= "choice" then
        return false
      end
    end
    if s.isChoiceBox or s.labels or s.choices or s.options or (sid and (sid == "ChoiceBox" or sid == "Gen2ChoiceBox" or sid == "Game3Choice" or sid == "Choice")) then
      return true
    end
    if s.onChoose and (s.labels or s.options or s.choices or s.isChoiceBox or s.firstItem or s.default_index) then
      return true
    end
    return false
  end

  local choiceState = nil
  if isChoiceBoxState(subState) then
    choiceState = subState
  elseif state._choice and isChoiceBoxState(state._choice) then
    choiceState = state._choice
  elseif state.choicePushed and game and game.stack and isChoiceBoxState(game.stack:top()) then
    choiceState = game.stack:top()
  elseif game and game.stack and game.stack.states then
    local states = game.stack.states
    local dIdx = 1
    for i = #states, 1, -1 do
      if states[i] == state then dIdx = i break end
    end
    -- Only inspect states pushed ON TOP of dialogue (never dormant parents underneath)
    for i = #states, dIdx + 1, -1 do
      local s = states[i]
      if isChoiceBoxState(s) then
        choiceState = s
        break
      end
    end
  end

  if choiceState and (choiceState.options or choiceState.labels or choiceState.choices or choiceState.items or choiceState.onChoose or choiceState.isChoiceBox) then
    local rawItems = choiceState.options or choiceState.labels or choiceState.choices or choiceState.items or { "YES", "NO" }
    local choiceIdx = choiceState.cursor or choiceState.index or choiceState.default_index or 1

    -- Specialized High-Impact Gender Selection Presentation
    if choiceState.isGender then
      local gw = ctx.isPortrait and math.min(vw - 32, 280) or 260
      local gh = 168

      -- Calculate stage position on the left flank opposite the character showcase
      local gameW = math.min(vw, math.floor(vh * (240 / 160)))
      local gameH = math.min(vh, math.floor(vw * (160 / 240)))
      local gx = math.floor((vw - gameW) / 2)
      local gy = math.floor((vh - gameH) / 2)
      local scale = gameW / 240

      local mx, my
      if ctx.isPortrait then
        mx = math.floor((vw - gw) / 2)
        my = math.max((ctx.safeInsetTop or 16) + 8, math.floor(dy * 0.26))
      else
        local targetX = math.floor(gx + 22 * scale)
        local targetY = math.floor(gy + 34 * scale)
        mx = math.max(24, math.min(vw - gw - 24, targetX))
        my = math.max(24, math.min(dy - gh - 16, targetY))
      end

      -- Master Card
      Layout.drawCard(mx, my, gw, gh, {
        color = theme.surface,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = theme.metrics and theme.metrics.radius.modal or 12,
      })

      -- Header Badge
      Layout.drawBadge(mx + 14, my + 10, "CHOOSE GENDER", {
        kind = "accent",
        font = "tiny",
        height = 20,
        radius = 4,
      })

      local btnW = gw - 28
      local btnH = 44
      local startY = my + 38

      -- 1. BOY Option (cursor == 1)
      local isBoy = (choiceIdx == 1)
      local boyBorder = isBoy and { 0.25, 0.55, 0.98, 1 } or theme.border
      local boyBg = isBoy and { 0.12, 0.24, 0.48, 0.92 } or theme.surfaceHigh
      Layout.drawSlot(mx + 14, startY, btnW, btnH, {
        color = boyBg,
        borderColor = boyBorder,
        borderWidth = isBoy and 2 or 1,
        radius = 8,
      })
      Layout.drawBadge(mx + 22, startY + 8, "♂", {
        kind = "primary",
        font = "headline",
        width = 28,
        height = 28,
        radius = 6,
      })
      Layout.drawText("BOY", mx + 58, startY + 12, {
        font = "button",
        color = isBoy and theme.heading or theme.text,
        bold = true,
      })
      if isBoy then
        local cx = mx + btnW - 20
        local cy = startY + math.floor(btnH / 2)
        love.graphics.setColor(0.25, 0.55, 0.98, 1)
        love.graphics.circle("fill", cx, cy, 10)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(cx - 4, cy, cx - 1, cy + 3, cx + 4, cy - 3)
      end

      -- 2. GIRL Option (cursor == 2)
      local isGirl = (choiceIdx == 2)
      local girlY = startY + btnH + 8
      local girlBorder = isGirl and { 0.95, 0.32, 0.65, 1 } or theme.border
      local girlBg = isGirl and { 0.45, 0.12, 0.28, 0.92 } or theme.surfaceHigh
      Layout.drawSlot(mx + 14, girlY, btnW, btnH, {
        color = girlBg,
        borderColor = girlBorder,
        borderWidth = isGirl and 2 or 1,
        radius = 8,
      })
      Layout.drawBadge(mx + 22, girlY + 8, "♀", {
        kind = "danger",
        font = "headline",
        width = 28,
        height = 28,
        radius = 6,
      })
      Layout.drawText("GIRL", mx + 58, girlY + 12, {
        font = "button",
        color = isGirl and theme.heading or theme.text,
        bold = true,
      })
      if isGirl then
        local cx = mx + btnW - 20
        local cy = girlY + math.floor(btnH / 2)
        love.graphics.setColor(0.95, 0.32, 0.65, 1)
        love.graphics.circle("fill", cx, cy, 10)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(cx - 4, cy, cx - 1, cy + 3, cx + 4, cy - 3)
      end

      -- Footer Hint
      Layout.drawText("▲ ▼ Select   A Confirm", mx + 14, my + gh - 18, {
        font = "tiny",
        color = theme.textDim,
        align = "center",
        width = btnW,
      })
      return
    end

    local cols = math.max(1, choiceState.cols or 1)

    local labels = {}
    for _, it in ipairs(rawItems) do
      local lbl = (type(it) == "table" and (it.label or it.name or it.text or it[1])) or tostring(it)
      table.insert(labels, Layout.cleanText(lbl))
    end

    local numChoices = #labels
    local maxVisibleRows = math.min(6, math.ceil(numChoices / cols))
    local itemH = (ctx.isUltraCompact) and 28 or 34
    local itemGap = 4
    local pad = 10

    -- Dynamic auto-scrolling slice when #choices > 6
    local totalRows = math.ceil(numChoices / cols)
    local currentRow = math.ceil(choiceIdx / cols)
    local scrollOffset = choiceState._scrollOffset or 0
    if currentRow > scrollOffset + maxVisibleRows then
      scrollOffset = currentRow - maxVisibleRows
    elseif currentRow <= scrollOffset then
      scrollOffset = currentRow - 1
    end
    scrollOffset = math.max(0, math.min(totalRows - maxVisibleRows, scrollOffset))
    choiceState._scrollOffset = scrollOffset

    local maxTextW = 90
    for _, lbl in ipairs(labels) do
      maxTextW = math.max(maxTextW, Layout.textWidth(tostring(lbl):upper(), "button") + 32)
    end

    local colW = math.max(110, maxTextW)
    local cw = math.min(dw - 24, colW * cols + (cols - 1) * 8 + pad * 2)
    local ch = pad * 2 + maxVisibleRows * itemH + (maxVisibleRows - 1) * itemGap
    local isLeft = (choiceState.anchor == "left") or (choiceState.tx and choiceState.tx <= 5)
    local cx = isLeft and (dx + 16) or (dx + dw - cw)

    -- Synchronized Anchor Inversion:
    -- If dialogue is top-anchored, dock choice box below speech card; otherwise dock above speech card
    local cy
    if isTopAnchor then
      cy = dy + dh + 10
    else
      cy = dy - ch - 12
    end

    Layout.drawCard(cx, cy, cw, ch, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = theme.metrics and theme.metrics.radius.modal or 10,
    })

    -- Render Choice Options (Grid or Single Column with Pagination)
    local btnW = math.floor((cw - pad * 2 - (cols - 1) * 8) / cols)
    for row = 1, maxVisibleRows do
      local rIdx = scrollOffset + row
      for col = 1, cols do
        local optIdx = (rIdx - 1) * cols + col
        if optIdx <= numChoices then
          local isSel = (choiceIdx == optIdx)
          local bx = cx + pad + (col - 1) * (btnW + 8)
          local by = cy + pad + (row - 1) * (itemH + itemGap)
          Layout.drawButton(bx, by, btnW, itemH, tostring(labels[optIdx]):upper(), {
            kind = isSel and "primary" or "ghost",
            selected = isSel,
            font = (itemH <= 28 or ctx.isUltraCompact) and "caption" or "button",
          })
        end
      end
    end

    -- Scroll Indicators if paginated
    if totalRows > maxVisibleRows then
      if scrollOffset > 0 then
        Layout.drawText("▲", cx + cw - 18, cy + 2, { font = "tiny", color = theme.accent })
      end
      if scrollOffset + maxVisibleRows < totalRows then
        Layout.drawText("▼", cx + cw - 18, cy + ch - 12, { font = "tiny", color = theme.accent })
      end
    end
  end

  -- 7. Substate Menus / Modals (Name select presets, ListMenu, or stacked menus over dialogue)
  local menuSub = nil
  if subState and subState ~= state and subState.items and (subState.isMenu or subState.index ~= nil or subState.cursor ~= nil or subState.tx ~= nil or subState.title ~= nil) and not isChoiceBoxState(subState) then
    local ModernOverlay = package.loaded["mods.omni_ui.core.ModernOverlay"]
    local sk = ModernOverlay and ModernOverlay.isSupported and ModernOverlay.isSupported(subState)
    if sk == "name_pick" or sk == "menu" then
      menuSub = subState
    end
  elseif game and game.stack and game.stack.states then
    local states = game.stack.states
    local dIdx = 1
    for i = #states, 1, -1 do
      if states[i] == state then dIdx = i break end
    end
    for i = #states, dIdx + 1, -1 do
      local topS = states[i]
      if topS and topS ~= state and topS.items and (topS.isMenu or topS.index ~= nil or topS.cursor ~= nil or topS.tx ~= nil or topS.title ~= nil) and not isChoiceBoxState(topS) then
        local ModernOverlay = package.loaded["mods.omni_ui.core.ModernOverlay"]
        local sk = ModernOverlay and ModernOverlay.isSupported and ModernOverlay.isSupported(topS)
        if sk == "name_pick" or sk == "menu" then
          menuSub = topS
          break
        end
      end
    end
  end

  if menuSub then
    local ModernOverlay = package.loaded["mods.omni_ui.core.ModernOverlay"]
    if ModernOverlay then
      local subKind = ModernOverlay.isSupported(menuSub)
      if subKind == "name_pick" and ModernOverlay.drawNamePick then
        ModernOverlay.drawNamePick(game, menuSub, vw, vh, theme, nil, viewport)
      elseif ModernOverlay.drawMenu then
        ModernOverlay.drawMenu(game, menuSub, vw, vh, theme, nil, viewport)
      end
    end
  end
end

return DialogueRenderer
