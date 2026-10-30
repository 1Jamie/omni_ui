-- OmniUI Modern Level-Up Stat Increases Window Renderer
-- Displays high-contrast stat growth popup cards across Gen 1, Gen 2, and Gen 3.
-- Responsively adapts slot heights and dimensions across desktop, mobile landscape, and portrait viewports.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local StatResolver = require("mods.omni_ui.core.StatResolver")
local SpriteHelper = require("mods.omni_ui.core.SpriteHelper")

local LevelUpStatRenderer = {}

local STAT_CONFIGS = {
  { key = "hp", label = "HP", color = { 0.95, 0.35, 0.40 } },
  { key = "attack", label = "ATTACK", color = { 0.95, 0.60, 0.30 } },
  { key = "defense", label = "DEFENSE", color = { 0.95, 0.80, 0.30 } },
  { key = "spAttack", label = "SP. ATK", color = { 0.40, 0.70, 0.95 } },
  { key = "spDefense", label = "SP. DEF", color = { 0.40, 0.85, 0.65 } },
  { key = "special", label = "SPECIAL", color = { 0.60, 0.65, 0.95 } },
  { key = "speed", label = "SPEED", color = { 0.85, 0.50, 0.90 } },
}

function LevelUpStatRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  local mon = (state and (state.mon or state.statsBoxMon or state.statsMon)) or (subState and (subState.mon or subState.statsBoxMon))
  if not mon then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local data = (game and game.data) or {}
  local species = mon.species or mon.speciesId or "UNKNOWN"
  local def = (data and data.pokemon and data.pokemon[species]) or {}
  local name = tostring(mon.nickname or mon.name or (def and def.name) or species):upper()
  local level = tonumber(mon.level or 1)

  -- Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Resolve Stats & Stat Deltas (Increases from Level-Up)
  local stats, deltas, prevStats = StatResolver.getStatDeltas(mon, def, game)
  local isSplit = stats.isSplit

  -- Card Dimensions
  local isCompact = ctx.isUltraCompact or (vh < 440) or (vw < 540)
  local cardW = math.min(380, math.max(260, math.floor(vw * 0.85)))
  local numRows = isSplit and 6 or 5
  local pad = isCompact and 10 or 18
  local headerH = isCompact and 54 or 76
  local footerH = isCompact and 28 or 40
  local slotGap = isCompact and 3 or 6

  local idealCardH = headerH + (numRows * (isCompact and 28 or 38) + (numRows - 1) * slotGap) + footerH + pad * 2
  local cardH = math.min(vh - 16, idealCardH)
  local rowsAvailableH = cardH - headerH - footerH - pad * 2 - (numRows - 1) * slotGap
  local slotH = math.max(22, math.floor(rowsAvailableH / numRows))

  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.max(8, math.floor((vh - cardH) / 2))

  -- 1. Main Modal Floating Card Container
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong or theme.colors.accent,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 16),
  })

  -- 2. Header: Pokémon Identity + Level Up Badge
  local topY = cardY + pad
  Layout.drawBadge(cardX + pad, topY, "LEVEL UP!", {
    kind = "primary",
    font = "tiny",
    height = isCompact and 18 or 20,
    radius = 3,
  })

  local lvBadgeText = ("Lv. %d"):format(level)
  local lvW = Layout.textWidth(lvBadgeText, "tiny") + 14
  Layout.drawBadge(cardX + cardW - pad - lvW, topY, lvBadgeText, {
    kind = "accent",
    font = "tiny",
    height = isCompact and 18 or 20,
    width = lvW,
    radius = 3,
  })

  local nameY = topY + (isCompact and 20 or 24)
  Layout.drawText(name, cardX + pad, nameY, {
    font = isCompact and "button" or "headline",
    color = theme.colors.heading,
    bold = true,
  })

  local subY = nameY + Layout.textHeight(isCompact and "button" or "headline") + 1
  Layout.drawText("STATS INCREASED", cardX + pad, subY, {
    font = "caption",
    color = theme.colors.textDim,
    bold = true,
  })

  -- Mini Sprite / Icon on top right if height allows
  if not isCompact or cardH >= 300 then
    local sprW, sprH = isCompact and 36 or 48, isCompact and 36 or 48
    local sprX = cardX + cardW - pad - sprW
    local sprY = topY + (isCompact and 8 or 14)
    SpriteHelper.drawFrontPic(data, species, sprX, sprY, sprW, sprH, {
      mon = mon,
      kind = "battle",
      isShiny = mon.isShiny or mon.shiny,
    })
  end

  -- Divider line
  local divY = cardY + headerH + pad - 4
  love.graphics.setColor(theme.colors.border[1], theme.colors.border[2], theme.colors.border[3], 0.5)
  love.graphics.setLineWidth(1)
  love.graphics.line(cardX + pad, divY, cardX + cardW - pad, divY)

  -- 3. Stat Rows with Deltas & New Values
  local rowsList = {}
  if isSplit then
    rowsList = {
      { key = "hp", label = "HP", val = stats.maxHp or stats.hp or 1, delta = deltas.hp or 1, cfg = STAT_CONFIGS[1] },
      { key = "attack", label = "ATTACK", val = stats.attack or 0, delta = deltas.attack or 1, cfg = STAT_CONFIGS[2] },
      { key = "defense", label = "DEFENSE", val = stats.defense or 0, delta = deltas.defense or 1, cfg = STAT_CONFIGS[3] },
      { key = "spAttack", label = "SP. ATK", val = stats.spAttack or stats.specialAttack or stats.special or 0, delta = deltas.spAttack or 1, cfg = STAT_CONFIGS[4] },
      { key = "spDefense", label = "SP. DEF", val = stats.spDefense or stats.specialDefense or stats.special or 0, delta = deltas.spDefense or 1, cfg = STAT_CONFIGS[5] },
      { key = "speed", label = "SPEED", val = stats.speed or 0, delta = deltas.speed or 1, cfg = STAT_CONFIGS[7] },
    }
  else
    rowsList = {
      { key = "hp", label = "HP", val = stats.maxHp or stats.hp or 1, delta = deltas.hp or 1, cfg = STAT_CONFIGS[1] },
      { key = "attack", label = "ATTACK", val = stats.attack or 0, delta = deltas.attack or 1, cfg = STAT_CONFIGS[2] },
      { key = "defense", label = "DEFENSE", val = stats.defense or 0, delta = deltas.defense or 1, cfg = STAT_CONFIGS[3] },
      { key = "special", label = "SPECIAL", val = stats.special or stats.spAttack or 0, delta = deltas.special or 1, cfg = STAT_CONFIGS[6] },
      { key = "speed", label = "SPEED", val = stats.speed or 0, delta = deltas.speed or 1, cfg = STAT_CONFIGS[7] },
    }
  end

  local curRowY = cardY + headerH + pad
  local slotW = cardW - pad * 2
  for _, r in ipairs(rowsList) do
    -- Slot Card
    Layout.drawSlot(cardX + pad, curRowY, slotW, slotH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.border,
      borderWidth = 1,
      radius = 5,
    })

    -- Stat Color Indicator Pip
    local dotCol = r.cfg.color
    love.graphics.setColor(dotCol[1], dotCol[2], dotCol[3], 0.95)
    love.graphics.circle("fill", cardX + pad + 10, curRowY + math.floor(slotH / 2), 3)

    -- Stat Label
    local labelX = cardX + pad + 20
    local labelY = curRowY + math.floor((slotH - Layout.textHeight("caption")) / 2)
    Layout.drawText(r.label, labelX, labelY, {
      font = "caption",
      color = theme.colors.heading,
      bold = true,
    })

    -- Final Stat Value on Far Right
    local valStr = ("%d"):format(r.val or 0)
    local valW = Layout.textWidth(valStr, isCompact and "caption" or "button")
    local valX = cardX + cardW - pad - valW - 10
    local valY = curRowY + math.floor((slotH - Layout.textHeight(isCompact and "caption" or "button")) / 2)
    Layout.drawText(valStr, valX, valY, {
      font = isCompact and "caption" or "button",
      color = theme.colors.heading,
      bold = true,
    })

    -- Stat Delta Increase Tag (e.g. "+3", "+2") without icon dots
    local deltaStr = ("+%d"):format(r.delta or 1)
    local deltaTextW = Layout.textWidth(deltaStr, "tiny")
    local deltaBadgeW = math.max(28, deltaTextW + 10)
    local deltaBadgeH = isCompact and 16 or 18
    local deltaX = valX - deltaBadgeW - 8
    local deltaY = curRowY + math.floor((slotH - deltaBadgeH) / 2)

    local hpGreen = theme.colors.hpGreen or { 0.25, 0.85, 0.65 }
    Layout.drawSlot(deltaX, deltaY, deltaBadgeW, deltaBadgeH, {
      color = { hpGreen[1] * 0.25, hpGreen[2] * 0.25, hpGreen[3] * 0.25, 0.85 },
      borderColor = { hpGreen[1], hpGreen[2], hpGreen[3], 0.9 },
      borderWidth = 1,
      radius = 3,
    })
    Layout.drawText(deltaStr, deltaX, deltaY + math.floor((deltaBadgeH - Layout.textHeight("tiny")) / 2), {
      font = "tiny",
      color = { hpGreen[1] * 0.6 + 0.4, hpGreen[2] * 0.6 + 0.4, hpGreen[3] * 0.6 + 0.4, 1.0 },
      align = "center",
      width = deltaBadgeW,
      bold = true,
    })

    -- Mini Stat Progression Meter (between label and delta badge)
    local labelW = isSplit and 54 or 48
    local barStartX = labelX + labelW + 6
    local barW = math.max(16, deltaX - barStartX - 8)
    local barRatio = math.max(0, math.min(1, (r.val or 0) / 255))
    local barY = curRowY + math.floor((slotH - 3) / 2)
    Layout.drawProgressBar(barStartX, barY, barW, 3, math.floor(barRatio * 100), 100, {
      color = dotCol,
      trackColor = theme.colors.crust or theme.colors.raised,
      radius = 2,
    })

    curRowY = curRowY + slotH + slotGap
  end

  -- 4. Footer: Dismiss Hint
  local hintY = cardY + cardH - footerH + 2
  Layout.drawButtonHint(cardX + pad, hintY, "A / B", "Continue", {
    font = "caption",
    keyFont = "tiny",
    textColor = theme.colors.textDim,
  })
end

return LevelUpStatRenderer
