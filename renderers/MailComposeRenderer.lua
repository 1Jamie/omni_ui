-- OmniUI Modern Mail Composition Interface Renderer
-- 2-Line real-time stationery preview with 10-column virtual keyboard, case switching, and glyph palette.
-- Fully responsive keyboard grid, preview card, and action keys across portrait and mobile landscape displays.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local Mail = require("src.core.gen2.Mail")

local MailComposeRenderer = {}

function MailComposeRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local text = (type(state.text) == "string" and state.text) or (type(state.text) == "table" and table.concat(state.text, "")) or ""
  local isLower = state.lower or false
  local curCol = state.col or 0
  local curRow = state.row or 0
  local isBottom = (curRow == 5)
  local bottomTarget = (type(state.bottomTarget) == "function" and state:bottomTarget()) or (curCol < 3 and 1 or (curCol < 6 and 2 or 3))

  local grid = (type(state.rows) == "function" and state:rows()) or (isLower and state.MAIL_INPUT_LOWER or state.MAIL_INPUT_UPPER) or {}

  -- 1. Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Frame Metrics
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(700, vw - pad * 2)
  local cardH = math.min(520, vh - pad * 2)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 2. Master Card
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 16),
  })

  -- 3. Header Bar
  local topY = cardY + pad
  local headerH = isCompact and 20 or 24
  Layout.drawBadge(cardX + pad, topY, "COMPOSE MAIL", {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local chars = Mail.characters(text)
  local countStr = ("%d / 32 CHARS"):format(#chars)
  local countW = Layout.textWidth(countStr, "tiny") + 16
  Layout.drawBadge(cardX + cardW - pad - countW, topY, countStr, {
    kind = #chars >= 32 and "warning" or "primary",
    font = "tiny",
    height = headerH,
    width = countW,
    radius = 4,
  })

  -- 4. Live Letter Postcard Preview
  local prevY = topY + headerH + (isCompact and 4 or 8)
  local prevW = cardW - pad * 2
  local prevH = isCompact and (isPortrait and 64 or 50) or 80

  Layout.drawCard(cardX + pad, prevY, prevW, prevH, {
    color = theme.colors.surfaceHigh,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1,
    radius = 8,
  })

  local topChars, botChars = {}, {}
  for i = 1, math.min(#chars, 16) do topChars[#topChars + 1] = chars[i] end
  for i = 17, math.min(#chars, 32) do botChars[#botChars + 1] = chars[i] end

  local topStr = table.concat(topChars, "")
  local botStr = table.concat(botChars, "")

  local prevFont = isCompact and "caption" or "headline"

  -- Line 1
  Layout.drawText(topStr, cardX + pad + 14, prevY + (isCompact and 6 or 12), {
    font = prevFont,
    color = theme.colors.heading,
    bold = true,
  })

  -- Line 2
  Layout.drawText(botStr, cardX + pad + 14, prevY + (isCompact and 24 or 38), {
    font = prevFont,
    color = theme.colors.heading,
    bold = true,
  })

  -- Underline guidelines
  love.graphics.setColor(theme.colors.border[1], theme.colors.border[2], theme.colors.border[3], 0.35)
  love.graphics.line(cardX + pad + 10, prevY + (isCompact and 20 or 32), cardX + pad + prevW - 10, prevY + (isCompact and 20 or 32))
  love.graphics.line(cardX + pad + 10, prevY + (isCompact and 38 or 58), cardX + pad + prevW - 10, prevY + (isCompact and 38 or 58))

  -- 5. Virtual Keyboard Grid (10 columns x 5 character rows)
  local kbY = prevY + prevH + (isCompact and 6 or 10)
  local kbW = cardW - pad * 2
  local keyGap = isCompact and 3 or 4
  local keyCols = 10
  local keyW = math.floor((kbW - (keyCols - 1) * keyGap) / keyCols)
  local footerH = isCompact and 20 or 24
  local actionH = isCompact and 26 or 32
  local kbAvailableH = cardH - (kbY - cardY) - actionH - footerH - pad - 6
  local keyH = math.max(18, math.min(30, math.floor((kbAvailableH - 4 * keyGap) / 5)))

  for r = 0, 4 do
    local rowLine = grid[r + 1] or {}
    local ky = kbY + r * (keyH + keyGap)
    for c = 0, 9 do
      local kx = cardX + pad + c * (keyW + keyGap)
      local ch = rowLine[c + 1] or " "
      local isSel = (not isBottom and curRow == r and curCol == c)

      if ch ~= " " and ch ~= "" then
        Layout.drawCard(kx, ky, keyW, keyH, {
          color = isSel and theme.colors.raised or theme.colors.surfaceHigh,
          borderColor = isSel and (theme.colors.accent or theme.colors.borderStrong) or theme.colors.border,
          borderWidth = isSel and 2 or 1,
          radius = 3,
        })

        Layout.drawText(ch, kx, ky + math.floor((keyH - Layout.textHeight("tiny")) / 2), {
          font = "tiny",
          color = isSel and theme.colors.heading or theme.colors.text,
          align = "center",
          width = keyW,
          bold = true,
        })
      else
        -- Empty key slot
        Layout.drawSlot(kx, ky, keyW, keyH, {
          color = theme.colors.surface,
          borderColor = theme.colors.border,
          borderWidth = 0.5,
          radius = 3,
        })
      end
    end
  end

  -- 6. Bottom Action Keys: [CASE TOGGLE]  [DELETE]  [END / CONFIRM]
  local actionY = kbY + 5 * (keyH + keyGap) + 4
  local actBtnGap = 6
  local actBtnW = math.floor((kbW - 2 * actBtnGap) / 3)

  -- Button 1: CASE
  local isCaseSel = (isBottom and bottomTarget == 1)
  local caseLabel = isLower and "UPPER (SELECT)" or "lower (SELECT)"
  Layout.drawButton(cardX + pad, actionY, actBtnW, actionH, caseLabel, {
    kind = isCaseSel and "primary" or "ghost",
    selected = isCaseSel,
    font = "tiny",
  })

  -- Button 2: DEL
  local isDelSel = (isBottom and bottomTarget == 2)
  Layout.drawButton(cardX + pad + actBtnW + actBtnGap, actionY, actBtnW, actionH, "DEL (B)", {
    kind = isDelSel and "danger" or "ghost",
    selected = isDelSel,
    font = "tiny",
  })

  -- Button 3: END
  local isEndSel = (isBottom and bottomTarget == 3)
  Layout.drawButton(cardX + pad + (actBtnW + actBtnGap) * 2, actionY, actBtnW, actionH, "END (START)", {
    kind = isEndSel and "good" or "ghost",
    selected = isEndSel,
    font = "tiny",
  })

  -- 7. Footer Hint
  local footerY = cardY + cardH - footerH
  Layout.drawText("▲ ▼ ◄ ► Navigate   A Type   B Delete   SELECT Case   START Finish", cardX + pad, footerY + 2, {
    font = "tiny",
    color = theme.colors.textDim,
    align = "center",
    width = kbW,
  })
end

return MailComposeRenderer
