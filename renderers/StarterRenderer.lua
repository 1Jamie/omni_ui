local Layout = require("mods.omni_ui.core.Layout")
local Theme = require("mods.omni_ui.core.Theme")

local StarterRenderer = {}

local STARTER_DATA = {
  [0] = {
    id = "treecko",
    name = "TREECKO",
    category = "WOOD GECKO POKéMON",
    type1 = "GRASS",
    hp = 40, attack = 45, defense = 35, spAtk = 65, spDef = 55, speed = 70,
    desc = "It makes its nest in a giant tree in the forest. It fiercely guards its territory against anything that approaches.",
    color = { 0.22, 0.72, 0.38 },
  },
  [1] = {
    id = "torchic",
    name = "TORCHIC",
    category = "CHICK POKéMON",
    type1 = "FIRE",
    hp = 45, attack = 60, defense = 40, spAtk = 70, spDef = 50, speed = 45,
    desc = "A fire burns inside, so it feels very warm to hug. It launches fireballs of 1,800 degrees F at foes.",
    color = { 0.95, 0.45, 0.22 },
  },
  [2] = {
    id = "mudkip",
    name = "MUDKIP",
    category = "MUD FISH POKéMON",
    type1 = "WATER",
    hp = 50, attack = 70, defense = 50, spAtk = 50, spDef = 50, speed = 40,
    desc = "The fin on its head acts as highly sensitive radar. Using it to sense water movements, it navigates without seeing.",
    color = { 0.25, 0.60, 0.92 },
  },
}

function StarterRenderer.attachControls(state, game)
  if not state or state.__omniUiStarterAttached then return end
  state.__omniUiStarterAttached = true

  local baseFrame = state.frame
  state.frame = function(self, inp)
    inp = inp or { new = {}, held = {} }
    inp.new, inp.held = inp.new or {}, inp.held or {}

    -- Navigation in selection phase
    if self.state == "input" or self.state == "choose" or self.state == "create_label" then
      if inp.new.left and (self.selection or 0) > 0 then
        self.selection = (self.selection or 0) - 1
      elseif inp.new.right and (self.selection or 0) < 2 then
        self.selection = (self.selection or 0) + 1
      elseif inp.new.a then
        self.state = "ask"
      end
    -- Confirmation phase
    elseif self.state == "ask" or self.state == "confirm" then
      self._confirmChoice = self._confirmChoice or 1 -- 1 = YES, 2 = NO
      if inp.new.up or inp.new.down or inp.new.left or inp.new.right then
        self._confirmChoice = (self._confirmChoice == 1) and 2 or 1
      elseif inp.new.b then
        self._confirmChoice = 1
        self.state = "input"
      elseif inp.new.a then
        if self._confirmChoice == 1 then
          -- YES confirmed -> zero-delay completion
          self.done = true
          self.result = self.selection or 0
          if self.onDone then
            self.onDone(self.result)
          end
          return true
        else
          self.state = "input"
        end
      end
    end

    if baseFrame then
      return baseFrame(self, inp)
    end
    return self.done
  end
end

function StarterRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end
  theme = theme or Theme.get()
  StarterRenderer.attachControls(state, game)

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isCompact = ctx.isCompact or ctx.isUltraCompact

  local selIdx = state.selection or (state.label and state.label.selection) or 0
  local curData = STARTER_DATA[selIdx] or STARTER_DATA[0]
  local isConfirming = (state.state == "ask" or state.state == "confirm" or state.confirm ~= nil)
  local confirmChoice = state._confirmChoice or (state.confirm and (state.confirm.cursor or state.confirm.index)) or 1

  -- 1. Full Screen Backdrop Fill
  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Top Header Banner
  local headH = isCompact and 36 or 44
  Layout.drawCard(0, 0, vw, headH, {
    color = theme.surface,
    borderColor = theme.border,
    radius = 6,
  })
  Layout.drawText("PROF. BIRCH'S BAG", 18, isCompact and 10 or 12, {
    font = "title",
    color = theme.heading,
    bold = true,
  })
  Layout.drawBadge(Layout.textWidth("PROF. BIRCH'S BAG", "title") + 28, isCompact and 8 or 10, "Choose Starter", { kind = "accent" })

  local topY = headH + (isCompact and 8 or 16)
  local bottomMargin = isCompact and 10 or 20
  local contentH = vh - topY - bottomMargin

  if isPortrait then
    -- =========================================================================
    -- MOBILE PORTRAIT: Stacked 3 Starter Balls Carousel + Hero Preview Card
    -- =========================================================================
    local cardW = math.min(vw - 24, 380)
    local cardX = math.floor((vw - cardW) / 2)

    -- Top 3 Starter Tabs
    local tabW = math.floor((cardW - 16) / 3)
    local tabH = 42
    for i = 0, 2 do
      local sData = STARTER_DATA[i]
      local isSel = (selIdx == i)
      local tx = cardX + i * (tabW + 8)
      Layout.drawButton(tx, topY, tabW, tabH, sData.name, {
        kind = isSel and "primary" or "ghost",
        selected = isSel,
        font = "caption",
      })
    end

    -- Hero Preview Card
    local heroY = topY + tabH + 10
    local heroH = math.min(contentH - tabH - 10, 360)
    Layout.drawCard(cardX, heroY, cardW, heroH, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 1.5,
      radius = 12,
    })

    Layout.drawText(curData.name, cardX + 16, heroY + 14, { font = "headline", color = theme.heading, bold = true })
    Layout.drawText(curData.category, cardX + 16, heroY + 36, { font = "tiny", color = theme.textDim })
    Layout.drawBadge(cardX + cardW - 70, heroY + 14, curData.type1, { kind = "team", font = "tiny", height = 20, width = 56 })

    -- Stat Bars
    local statY = heroY + 64
    local stats = {
      { label = "HP", val = curData.hp, max = 100 },
      { label = "ATK", val = curData.attack, max = 100 },
      { label = "DEF", val = curData.defense, max = 100 },
      { label = "SP.ATK", val = curData.spAtk, max = 100 },
      { label = "SP.DEF", val = curData.spDef, max = 100 },
      { label = "SPD", val = curData.speed, max = 100 },
    }
    for _, st in ipairs(stats) do
      Layout.drawText(st.label, cardX + 16, statY, { font = "tiny", color = theme.textDim, bold = true })
      Layout.drawProgressBar(cardX + 70, statY + 2, cardW - 120, 8, st.val / st.max, {
        barColor = curData.color,
        bgColor = theme.surfaceHigh,
      })
      Layout.drawText(tostring(st.val), cardX + cardW - 40, statY, { font = "tiny", color = theme.heading })
      statY = statY + 18
    end

    -- Description
    Layout.drawText(curData.desc, cardX + 16, statY + 8, {
      font = "caption",
      color = theme.textDim,
      width = cardW - 32,
      lineSpacing = 1.2,
    })

  else
    -- =========================================================================
    -- WIDESCREEN / DESKTOP: 3 Side-by-Side Holographic Starter Cards
    -- =========================================================================
    local totalW = math.min(vw - 32, 840)
    local startX = math.floor((vw - totalW) / 2)
    local cardW = math.floor((totalW - 24) / 3)
    local cardH = math.min(contentH - 44, 380)

    for i = 0, 2 do
      local sData = STARTER_DATA[i]
      local isSel = (selIdx == i)
      local cx = startX + i * (cardW + 12)
      local cy = topY

      Layout.drawCard(cx, cy, cardW, cardH, {
        color = isSel and theme.surfaceHigh or theme.surface,
        borderColor = isSel and (theme.accent or curData.color) or theme.border,
        borderWidth = isSel and 2 or 1,
        radius = 12,
      })

      -- Highlight top hairline
      if isSel then
        Layout.drawSlot(cx + 12, cy + 2, cardW - 24, 3, {
          color = sData.color,
          borderColor = theme.border,
          borderWidth = 0,
          radius = 1,
        })
      end

      -- Title & Category
      Layout.drawText(sData.name, cx + 16, cy + 16, { font = "headline", color = theme.heading, bold = true })
      Layout.drawText(sData.category, cx + 16, cy + 40, { font = "tiny", color = theme.textDim })
      Layout.drawBadge(cx + cardW - 68, cy + 16, sData.type1, { kind = "team", font = "tiny", height = 20, width = 54 })

      -- Stat Bars
      local statY = cy + 72
      local stats = {
        { label = "HP", val = sData.hp, max = 100 },
        { label = "ATK", val = sData.attack, max = 100 },
        { label = "DEF", val = sData.defense, max = 100 },
        { label = "SP.A", val = sData.spAtk, max = 100 },
        { label = "SP.D", val = sData.spDef, max = 100 },
        { label = "SPD", val = sData.speed, max = 100 },
      }
      for _, st in ipairs(stats) do
        Layout.drawText(st.label, cx + 16, statY, { font = "tiny", color = theme.textDim, bold = true })
        Layout.drawProgressBar(cx + 56, statY + 2, cardW - 96, 7, st.val / st.max, {
          barColor = sData.color,
          bgColor = theme.surfaceHigh,
        })
        Layout.drawText(tostring(st.val), cx + cardW - 34, statY, { font = "tiny", color = theme.heading })
        statY = statY + 17
      end

      -- Description
      Layout.drawText(sData.desc, cx + 16, statY + 8, {
        font = "caption",
        color = theme.textDim,
        width = cardW - 32,
        lineSpacing = 1.2,
      })

      -- Action Button at bottom of card
      local btnY = cy + cardH - 42
      Layout.drawButton(cx + 12, btnY, cardW - 24, 32, isSel and "SELECTED" or "SELECT", {
        kind = isSel and "primary" or "ghost",
        selected = isSel,
        font = "button",
      })
    end
  end

  -- Bottom Hints Bar
  local footY = vh - (isCompact and 32 or 40)
  local hints = {
    { key = "◄ ►", label = "Switch" },
    { key = "A", label = "Choose Starter", primary = true },
  }
  Layout.drawHintBar(0, footY, vw, isCompact and 32 or 40, hints, { paddingX = 24 })

  -- =========================================================================
  -- CONFIRMATION MODAL ("Do you choose TREECKO?" -> YES / NO)
  -- =========================================================================
  if isConfirming then
    local mw = math.min(vw - 24, 380)
    local mh = 156
    local mx = math.floor((vw - mw) / 2)
    local my = math.floor((vh - mh) / 2)

    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", -50, -50, vw + 100, vh + 100)

    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 12,
    })

    Layout.drawText(("Choose %s?"):format(curData.name), mx + 24, my + 18, {
      font = "headline",
      color = theme.heading,
      bold = true,
    })
    Layout.drawText(("Do you want to choose %s as your companion?"):format(curData.name), mx + 24, my + 48, {
      font = "body",
      color = theme.textDim,
      width = mw - 48,
    })

    local btnW = math.floor((mw - 64) / 2)
    local btnH = 38
    local btnY = my + 96

    Layout.drawButton(mx + 24, btnY, btnW, btnH, "YES", {
      kind = (confirmChoice == 1) and "primary" or "ghost",
      selected = (confirmChoice == 1),
    })

    Layout.drawButton(mx + 24 + btnW + 16, btnY, btnW, btnH, "NO", {
      kind = (confirmChoice == 2) and "primary" or "ghost",
      selected = (confirmChoice == 2),
    })
  end
end

return StarterRenderer
