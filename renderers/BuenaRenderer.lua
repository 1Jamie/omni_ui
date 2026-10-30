-- OmniUI Modern Buena's Password & Blue Card Prize Terminal Renderer
-- Modernized Radio Quiz show and Prize Point Redemption Center.
-- Dynamically adjusts prize lists, scrollbars, and quiz options for compact mobile and portrait screens.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")

local BuenaRenderer = {}

function BuenaRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local isPrize = (state.mode == "prize")
  local index = tonumber(state.index or 1)
  local scroll = tonumber(state.scroll or 0)

  -- Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)

  if isPrize then
    -- =========================================================================
    -- BLUE CARD PRIZE REDEMPTION MODE
    -- =========================================================================
    local balance = tonumber(state.balance or 0)
    local prizes = state.prizes or {}
    local cardW = math.min(480, math.max(280, vw - pad * 2))
    local cardH = math.min(vh - pad * 2, isCompact and 280 or 320)
    local cardX = math.floor((vw - cardW) / 2)
    local cardY = math.floor((vh - cardH) / 2)

    Layout.drawCard(cardX, cardY, cardW, cardH, {
      color = theme.colors.surface,
      borderColor = theme.colors.accent,
      borderWidth = 1.5,
      radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 14),
    })

    -- Header
    local topY = cardY + pad
    local headerH = isCompact and 20 or 24
    Layout.drawBadge(cardX + pad, topY, "BUENA PRIZES", {
      kind = "primary",
      font = "tiny",
      height = headerH,
      radius = 4,
    })

    local balanceStr = ("%d PTS"):format(balance)
    local balBadgeW = Layout.textWidth(balanceStr, "tiny") + 16
    Layout.drawBadge(cardX + cardW - pad - balBadgeW, topY, balanceStr, {
      kind = "good",
      font = "tiny",
      height = headerH,
      width = balBadgeW,
      radius = 4,
    })

    -- Prize Items List with Dynamic Row Calculation
    local startY = topY + headerH + (isCompact and 6 or 10)
    local footerH = isCompact and 24 or 30
    local listAvailableH = cardH - (startY - cardY) - footerH - pad
    local itemH = isCompact and 28 or 36
    local itemGap = 4
    local visibleRows = math.max(2, math.min(#prizes, math.floor(listAvailableH / (itemH + itemGap))))
    local listW = cardW - pad * 2

    for row = 1, math.min(visibleRows, #prizes) do
      local i = row + scroll
      local prize = prizes[i]
      if prize then
        local isSel = (i == index)
        local iy = startY + (row - 1) * (itemH + itemGap)
        local canAfford = (balance >= (prize.cost or 1))

        Layout.drawSlot(cardX + pad, iy, listW, itemH, {
          color = isSel and theme.colors.raised or theme.colors.surfaceHigh,
          borderColor = isSel and theme.colors.accent or theme.colors.border,
          borderWidth = isSel and 2 or 1,
          radius = 5,
        })

        -- Item Name
        local nameStr = tostring(prize.name or prize.item or "ITEM"):upper()
        Layout.drawText(nameStr, cardX + pad + 10, iy + math.floor((itemH - Layout.textHeight(itemH > 30 and "button" or "caption")) / 2), {
          font = itemH > 30 and "button" or "caption",
          color = isSel and theme.colors.heading or (canAfford and theme.colors.text or theme.colors.textDim),
          bold = true,
        })

        -- Point Cost Tag
        local costStr = ("%d PTS"):format(prize.cost or 1)
        local costW = Layout.textWidth(costStr, "tiny") + 12
        local costBadgeKind = isSel and (canAfford and "good" or "danger") or "ghost"
        Layout.drawBadge(cardX + cardW - pad - costW - 8, iy + math.floor((itemH - 18) / 2), costStr, {
          kind = costBadgeKind,
          font = "tiny",
          height = 18,
          width = costW,
          radius = 3,
        })
      end
    end

    -- Scroll Bar
    if #prizes > visibleRows then
      Layout.drawScrollBar(cardX + cardW - pad + 3, startY, 3, visibleRows * (itemH + itemGap) - itemGap, #prizes, visibleRows, scroll + 1, {
        is1Indexed = true,
        radius = 2,
      })
    end

    -- Footer
    local footerY = cardY + cardH - footerH
    Layout.drawText("▲ ▼ Select Prize   A Redeem   B Exit", cardX + pad, footerY + 2, {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = listW,
    })
  else
    -- =========================================================================
    -- RADIO SHOW PASSWORD QUIZ MODE
    -- =========================================================================
    local words = state.words or {}
    local cardW = math.min(420, math.max(280, vw - pad * 2))
    local cardH = math.min(vh - pad * 2, isCompact and 210 or 250)
    local cardX = math.floor((vw - cardW) / 2)
    local cardY = math.floor((vh - cardH) / 2)

    Layout.drawCard(cardX, cardY, cardW, cardH, {
      color = theme.colors.surface,
      borderColor = theme.colors.accent,
      borderWidth = 1.5,
      radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 14),
    })

    -- Header
    local topY = cardY + pad
    local headerH = isCompact and 20 or 24
    Layout.drawBadge(cardX + pad, topY, "BUENA'S PASSWORD", {
      kind = "primary",
      font = "tiny",
      height = headerH,
      radius = 4,
    })

    Layout.drawBadge(cardX + cardW - pad - 60, topY, "ON AIR", {
      kind = "danger",
      font = "tiny",
      height = headerH,
      width = 60,
      radius = 4,
    })

    local promptY = topY + headerH + (isCompact and 4 or 8)
    Layout.drawText("WHAT IS TODAY'S PASSWORD?", cardX + pad, promptY, {
      font = "caption",
      color = theme.colors.textDim,
      bold = true,
    })

    -- 3 Word Choices
    local startY = promptY + (isCompact and 18 or 24)
    local footerH = isCompact and 24 or 30
    local choiceAvailableH = cardH - (startY - cardY) - footerH - pad
    local itemH = math.min(36, math.floor((choiceAvailableH - (#words - 1) * 4) / math.max(1, #words)))
    local itemGap = 4
    local listW = cardW - pad * 2

    for i, word in ipairs(words) do
      local isSel = (i == index)
      local iy = startY + (i - 1) * (itemH + itemGap)

      Layout.drawButton(cardX + pad, iy, listW, itemH, tostring(word):upper(), {
        kind = isSel and "primary" or "ghost",
        selected = isSel,
        font = itemH > 28 and "button" or "caption",
      })
    end

    -- Footer
    local footerY = cardY + cardH - footerH
    Layout.drawText("▲ ▼ Select Answer   A Confirm", cardX + pad, footerY + 2, {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = listW,
    })
  end
end

return BuenaRenderer
