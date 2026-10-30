-- OmniUI Modern Character Gender Selection Interface Renderer
-- Dual character portrait selector (Boy / Girl) with gender badges, selection halos, and intro speech integration.
-- Reconstructs side-by-side cards into stacked vertical tiles in portrait and adapts heights for mobile landscape.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")

local GenderRenderer = {}

function GenderRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local cursor = state.cursor or 1 -- 1 = Boy, 2 = Girl
  local text = (type(state.text) == "string" and state.text) or "Are you a boy?\nOr are you a girl?"

  -- 1. Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Frame Dimensions
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(600, vw - pad * 2)
  local cardH = math.min(480, vh - pad * 2)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 2. Master Frame
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 16),
  })

  -- 3. Header Bar
  local topY = cardY + pad
  local headerH = isCompact and 20 or 24
  Layout.drawBadge(cardX + pad, topY, "TRAINER REGISTRATION", {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local setupW = isCompact and 100 or 120
  Layout.drawBadge(cardX + cardW - pad - setupW, topY, "CHARACTER SETUP", {
    kind = "primary",
    font = "tiny",
    height = headerH,
    width = setupW,
    radius = 4,
  })

  -- 4. Dual Character Profile Cards
  local profilesY = topY + headerH + (isCompact and 6 or 10)
  local speechH = isCompact and (isPortrait and 54 or 46) or 72
  local profilesH = cardH - (profilesY - cardY) - speechH - pad

  -- Helper to render a character card
  local function drawGenderCard(x, y, w, h, isBoy, isSelected, isCompactView)
    local title = isBoy and (isCompactView and "BOY (CHRIS)" or "BOY (CHRIS / ETHAN)") or (isCompactView and "GIRL (KRIS)" or "GIRL (KRIS / LYRA)")
    local symbol = isBoy and "♂" or "♀"
    local badgeKind = isBoy and "primary" or "danger"
    local cardBorder = isSelected and (theme.colors.accent or theme.colors.heading) or theme.colors.border

    Layout.drawCard(x, y, w, h, {
      color = isSelected and theme.colors.raised or theme.colors.surfaceHigh,
      borderColor = cardBorder,
      borderWidth = isSelected and 2 or 1,
      radius = 8,
    })

    if isPortrait and isCompactView then
      -- Horizontal tile layout for portrait
      Layout.drawBadge(x + 10, y + math.floor((h - 22) / 2), symbol, {
        kind = badgeKind,
        font = "headline",
        width = 28,
        height = 28,
        radius = 6,
      })

      Layout.drawText(title, x + 46, y + math.floor((h - Layout.textHeight("button")) / 2), {
        font = "button",
        color = theme.colors.heading,
        bold = true,
      })

      local selW = 80
      Layout.drawBadge(x + w - selW - 10, y + math.floor((h - 22) / 2), isSelected and "CHOSEN" or "SELECT", {
        kind = isSelected and "primary" or "ghost",
        font = "tiny",
        height = 22,
        width = selW,
        radius = 4,
      })
    else
      -- Vertical box layout for desktop / landscape
      Layout.drawBadge(x + 10, y + 8, title, {
        kind = badgeKind,
        font = "tiny",
        height = 20,
        radius = 4,
      })

      local symbolSize = isCompactView and 34 or 44
      local symX = x + math.floor((w - symbolSize) / 2)
      local symY = y + math.floor((h - symbolSize) / 2) - (isCompactView and 6 or 12)

      Layout.drawBadge(symX, symY, symbol, {
        kind = badgeKind,
        font = isCompactView and "button" or "headline",
        width = symbolSize,
        height = symbolSize,
        radius = 8,
      })

      local btnH = isCompactView and 26 or 30
      local btnY = y + h - btnH - 8
      Layout.drawButton(x + 10, btnY, w - 20, btnH, isSelected and "SELECTED" or "CHOOSE", {
        kind = isSelected and "primary" or "ghost",
        selected = isSelected,
        font = "tiny",
      })
    end
  end

  if isPortrait then
    -- =========================================================================
    -- PORTRAIT STACKED TILES
    -- =========================================================================
    local slotGap = 6
    local singleSlotH = math.floor((profilesH - slotGap) / 2)
    local slotW = cardW - pad * 2
    drawGenderCard(cardX + pad, profilesY, slotW, singleSlotH, true, cursor == 1, true)
    drawGenderCard(cardX + pad, profilesY + singleSlotH + slotGap, slotW, singleSlotH, false, cursor == 2, true)
  else
    -- =========================================================================
    -- LANDSCAPE SIDE-BY-SIDE CARDS
    -- =========================================================================
    local colW = math.floor((cardW - pad * 2 - (isCompact and 10 or 16)) / 2)
    local leftX = cardX + pad
    local rightX = leftX + colW + (isCompact and 10 or 16)
    drawGenderCard(leftX, profilesY, colW, profilesH, true, cursor == 1, isMobileLandscape)
    drawGenderCard(rightX, profilesY, colW, profilesH, false, cursor == 2, isMobileLandscape)
  end

  -- 5. Bottom Speech Box
  local speechY = cardY + cardH - speechH - pad
  local speechW = cardW - pad * 2
  Layout.drawCard(cardX + pad, speechY, speechW, speechH, {
    color = theme.colors.surfaceHigh,
    borderColor = theme.colors.accent,
    borderWidth = 1.5,
    radius = 8,
  })

  Layout.drawText("PROF. OAK:", cardX + pad + 10, speechY + 6, {
    font = "tiny",
    color = theme.colors.accent,
    bold = true,
  })

  Layout.drawText(tostring(text), cardX + pad + 10, speechY + (isCompact and 20 or 24), {
    font = isCompact and "caption" or "body",
    color = theme.colors.heading,
    bold = true,
  })

  -- 6. Footer Hint
  Layout.drawText("▲ ▼ / ◄ ► Choose Gender   A Confirm", cardX + pad, speechY + speechH - 14, {
    font = "tiny",
    color = theme.colors.textDim,
    align = "right",
    width = speechW - 10,
  })
end

return GenderRenderer
