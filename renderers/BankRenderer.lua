-- OmniUI Modern Bank of Mom ATM Interface Renderer
-- High-contrast financial terminal for Mom's savings account with digit-by-digit place value stepping and quick badges.
-- Dynamically scales digit boxes and balances across ultra-compact, portrait, and mobile landscape viewports.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")

local BankRenderer = {}

function BankRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local isDeposit = (state.kind == "deposit")
  local saved = tonumber(state.saved or 0)
  local held = tonumber(state.held or 0)
  local amount = tonumber(state.amount or 0)
  local pos = tonumber(state.position or 5) -- 0 to 5

  -- Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Main Card Metrics
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(480, math.max(280, vw - pad * 2))
  local cardH = math.min(vh - pad * 2, isCompact and 230 or 260)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 1. Main Terminal Card
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = isDeposit and theme.colors.accent or theme.colors.hpGreen,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 14),
  })

  -- 2. Header
  local topY = cardY + pad
  local headerH = isCompact and 20 or 24
  Layout.drawBadge(cardX + pad, topY, "MOM'S SAVINGS", {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local modeLabel = isDeposit and "DEPOSIT" or "WITHDRAW"
  local modeKind = isDeposit and "primary" or "good"
  local modeW = Layout.textWidth(modeLabel, "tiny") + 16
  Layout.drawBadge(cardX + cardW - pad - modeW, topY, modeLabel, {
    kind = modeKind,
    font = "tiny",
    height = headerH,
    width = modeW,
    radius = 4,
  })

  -- 3. Balance Comparison Slots
  local balanceY = topY + headerH + (isCompact and 6 or 10)
  local slotW = math.floor((cardW - pad * 2 - (isCompact and 8 or 12)) / 2)
  local slotH = isCompact and 36 or 42

  -- Saved Slot
  Layout.drawSlot(cardX + pad, balanceY, slotW, slotH, {
    color = theme.colors.surfaceHigh,
    borderColor = theme.colors.border,
    borderWidth = 1,
    radius = 6,
  })
  Layout.drawText("SAVED BALANCE", cardX + pad + 8, balanceY + 4, {
    font = "tiny",
    color = theme.colors.textDim,
  })
  Layout.drawText(("¥ %s"):format(Widgets.formatNumber(saved)), cardX + pad + 8, balanceY + (isCompact and 18 or 20), {
    font = isCompact and "caption" or "button",
    color = theme.colors.accent,
    bold = true,
  })

  -- Held / Wallet Slot
  local heldX = cardX + pad + slotW + (isCompact and 8 or 12)
  Layout.drawSlot(heldX, balanceY, slotW, slotH, {
    color = theme.colors.surfaceHigh,
    borderColor = theme.colors.border,
    borderWidth = 1,
    radius = 6,
  })
  Layout.drawText("HELD WALLET", heldX + 8, balanceY + 4, {
    font = "tiny",
    color = theme.colors.textDim,
  })
  Layout.drawText(("¥ %s"):format(Widgets.formatNumber(held)), heldX + 8, balanceY + (isCompact and 18 or 20), {
    font = isCompact and "caption" or "button",
    color = theme.colors.heading,
    bold = true,
  })

  -- 4. Transfer Amount Digit Editor Box
  local transferY = balanceY + slotH + (isCompact and 6 or 10)
  local transferW = cardW - pad * 2
  local footerH = isCompact and 24 or 30
  local transferH = cardH - (transferY - cardY) - footerH - pad

  Layout.drawCard(cardX + pad, transferY, transferW, transferH, {
    color = theme.colors.surfaceHigh,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1,
    radius = 8,
  })

  Layout.drawText(isDeposit and "AMOUNT TO DEPOSIT" or "AMOUNT TO WITHDRAW", cardX + pad + 10, transferY + 6, {
    font = "tiny",
    color = theme.colors.textDim,
    bold = true,
  })

  -- 6 Digit Place Value Boxes with Dynamic Scaling
  local digits = ("%06d"):format(amount)
  local digitBoxW = math.max(18, math.min(30, math.floor((transferW - 70) / 6)))
  local digitGap = math.max(3, math.min(6, math.floor((transferW - 60 - digitBoxW * 6) / 5)))
  local digitBoxH = math.max(24, math.min(32, transferH - 30))
  local totalDigitsW = 6 * digitBoxW + 5 * digitGap
  local digitStartX = cardX + pad + transferW - totalDigitsW - 10
  local digitStartY = transferY + math.floor((transferH - digitBoxH + 10) / 2)

  -- Currency Symbol
  Layout.drawText("¥", digitStartX - 16, digitStartY + math.floor((digitBoxH - Layout.textHeight("button")) / 2), {
    font = "button",
    color = theme.colors.accent,
    bold = true,
  })

  for i = 0, 5 do
    local isSelected = (i == pos)
    local dx = digitStartX + i * (digitBoxW + digitGap)
    local dChar = digits:sub(i + 1, i + 1)

    Layout.drawSlot(dx, digitStartY, digitBoxW, digitBoxH, {
      color = isSelected and theme.colors.raised or theme.colors.surface,
      borderColor = isSelected and (theme.colors.accent or theme.colors.borderStrong) or theme.colors.border,
      borderWidth = isSelected and 2 or 1,
      radius = 4,
    })

    if isSelected then
      love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], 0.9)
      Layout.drawText("▲", dx, digitStartY - 9, { font = "tiny", align = "center", width = digitBoxW })
      Layout.drawText("▼", dx, digitStartY + digitBoxH - 3, { font = "tiny", align = "center", width = digitBoxW })
    end

    Layout.drawText(dChar, dx, digitStartY + math.floor((digitBoxH - Layout.textHeight("tiny")) / 2), {
      font = "tiny",
      color = isSelected and theme.colors.heading or theme.colors.text,
      align = "center",
      width = digitBoxW,
      bold = true,
    })
  end

  -- 5. Footer Hint Bar
  local footerY = cardY + cardH - footerH
  Layout.drawText("◄ ► Select   ▲ ▼ Adjust   A Confirm   B Cancel", cardX + pad, footerY + 2, {
    font = "tiny",
    color = theme.colors.textDim,
    align = "center",
    width = cardW - pad * 2,
  })
end

return BankRenderer
