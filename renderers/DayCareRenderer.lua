-- OmniUI Modern Day-Care Concierge Dashboard Renderer
-- Dual-slot breeding manager displaying both parents, growth levels, withdrawal fees, and active egg status.
-- Supports side-by-side desktop view and stacked vertical parent strips on mobile portrait and compact screens.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")

local DayCareRenderer = {}

local function monName(mon)
  if not mon then return "UNKNOWN" end
  return (mon.nickname or mon.name or mon.species or "POKÉMON"):upper()
end

function DayCareRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local data = (game and game.data) or {}
  local save = state.save or (game and game.save) or {}
  local dc = (save and save.dayCare) or {}
  local manSlot = dc.man or (dc[1]) or {}
  local ladySlot = dc.lady or (dc[2]) or {}
  local hasEgg = dc.hasEgg or (state.side == "outside" and not (state.message and state.message.pages and #state.message.pages == 1 and state.message.pages[1][1] == "Not yet…"))

  local activeSide = state.side or "man"

  -- 1. Dimmed Map Backdrop
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Card Metrics
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(760, vw - pad * 2)
  local cardH = math.min(520, vh - pad * 2)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 2. Main Terminal Card
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 16),
  })

  -- 3. Header Bar
  local topY = cardY + pad
  local headerH = isCompact and 22 or 26
  Layout.drawBadge(cardX + pad, topY, "DAY-CARE CONCIERGE", {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local sideTitle = (activeSide == "lady") and "DAY-CARE LADY" or ((activeSide == "outside") and "GARDEN & EGGS" or "DAY-CARE MAN")
  local sideW = isCompact and 110 or 130
  Layout.drawBadge(cardX + cardW - pad - sideW, topY, sideTitle, {
    kind = "primary",
    font = "tiny",
    height = headerH,
    width = sideW,
    radius = 4,
  })

  -- 4. Dual-Slot Breeding Dashboard Cards
  local dashY = topY + headerH + (isCompact and 6 or 10)
  local footerH = (state.message or state.confirm) and (isCompact and (isPortrait and 80 or 70) or 110) or (isCompact and 28 or 36)
  local eggBannerH = hasEgg and (isCompact and 26 or 34) or 0
  local slotsH = cardH - (dashY - cardY) - footerH - eggBannerH - pad - (hasEgg and 6 or 0)

  -- Helper to render a parent slot
  local function drawParentSlot(slotData, x, y, w, h, title, isTarget, isCompactView)
    local mon = slotData and slotData.mon
    local isVacant = not mon

    Layout.drawCard(x, y, w, h, {
      color = theme.colors.surfaceHigh,
      borderColor = isTarget and (theme.colors.accent or theme.colors.borderStrong) or theme.colors.border,
      borderWidth = isTarget and 1.5 or 1,
      radius = 8,
    })

    Layout.drawBadge(x + 8, y + 6, title, {
      kind = isTarget and "accent" or "ghost",
      font = "tiny",
      height = 18,
      radius = 3,
    })

    if isVacant then
      Layout.drawText("VACANT / READY FOR DEPOSIT", x + 12, y + math.floor(h / 2) - 6, {
        font = "tiny",
        color = theme.colors.textDim,
      })
    else
      local name = monName(mon)
      local lvl = tonumber(mon.level or 1)
      local species = mon.species or "DITTO"
      local pDef = data.pokemon and data.pokemon[species] or { types = { "NORMAL" } }

      if isCompactView and isPortrait then
        -- Compact single row view for portrait
        Layout.drawText(name, x + 10, y + 26, {
          font = "button",
          color = theme.colors.heading,
          bold = true,
        })
        Layout.drawBadge(x + w - 60, y + 6, ("Lv. %d"):format(lvl), {
          kind = "primary",
          font = "tiny",
          height = 18,
          width = 52,
          radius = 3,
        })
        local grown = state.grown or 0
        local price = state.price or 100
        local feeText = ("GROWTH: +%d LVL  •  FEE: ¥%d"):format(grown, price)
        Layout.drawText(feeText, x + 10, y + 46, {
          font = "tiny",
          color = grown > 0 and (theme.colors.hpGreen or theme.colors.accent) or theme.colors.textDim,
          bold = true,
        })
      else
        local nameY = y + (isCompactView and 26 or 32)
        Layout.drawText(name, x + 10, nameY, {
          font = isCompactView and "button" or "headline",
          color = theme.colors.heading,
          bold = true,
        })

        Layout.drawBadge(x + w - 60, y + 6, ("Lv. %d"):format(lvl), {
          kind = "primary",
          font = "tiny",
          height = 18,
          width = 52,
          radius = 3,
        })

        local uTypes = Widgets.getUniqueTypes(pDef.types)
        if #uTypes > 0 and h >= 90 then
          local tyX = x + 10
          local tyY = nameY + (isCompactView and 20 or 24)
          for _, tName in ipairs(uTypes) do
            local bw = Widgets.drawTypeBadge(tName, tyX, tyY, { height = 16, font = "tiny" })
            tyX = tyX + (bw or 50) + 4
          end
        end

        -- Growth & Retrieval Cost Bar
        local feeH = isCompactView and 28 or 36
        local feeY = y + h - feeH - 6
        Layout.drawSlot(x + 8, feeY, w - 16, feeH, {
          color = theme.colors.surface,
          borderColor = theme.colors.border,
          borderWidth = 1,
          radius = 5,
        })

        local grown = state.grown or 0
        local price = state.price or 100
        Layout.drawText("GROWTH: " .. (grown > 0 and ("+" .. grown .. " LVLS") or "NO GAIN"), x + 12, feeY + 4, {
          font = "tiny",
          color = grown > 0 and (theme.colors.hpGreen or theme.colors.accent) or theme.colors.textDim,
          bold = true,
        })

        Layout.drawText(("FEE: ¥%d"):format(price), x + w - 90, feeY + 4, {
          font = "tiny",
          color = theme.colors.accent,
          bold = true,
        })
      end
    end
  end

  if isPortrait then
    -- =========================================================================
    -- PORTRAIT STACKED LAYOUT (Top: Parent 1, Bottom: Parent 2)
    -- =========================================================================
    local slotGap = 6
    local singleSlotH = math.floor((slotsH - slotGap) / 2)
    local slotW = cardW - pad * 2

    drawParentSlot(manSlot, cardX + pad, dashY, slotW, singleSlotH, "PARENT 1 (MAN)", activeSide == "man", true)
    drawParentSlot(ladySlot, cardX + pad, dashY + singleSlotH + slotGap, slotW, singleSlotH, "PARENT 2 (LADY)", activeSide == "lady", true)
  else
    -- =========================================================================
    -- LANDSCAPE SIDE-BY-SIDE DUAL PANE
    -- =========================================================================
    local slotW = math.floor((cardW - pad * 2 - (isCompact and 10 or 16)) / 2)
    local slot1X = cardX + pad
    local slot2X = slot1X + slotW + (isCompact and 10 or 16)
    drawParentSlot(manSlot, slot1X, dashY, slotW, slotsH, "PARENT 1 (MAN)", activeSide == "man", isMobileLandscape)
    drawParentSlot(ladySlot, slot2X, dashY, slotW, slotsH, "PARENT 2 (LADY)", activeSide == "lady", isMobileLandscape)
  end

  -- 5. Egg Waiting Banner (If egg available)
  local currentY = dashY + slotsH + 6
  if hasEgg then
    Layout.drawCard(cardX + pad, currentY, cardW - pad * 2, eggBannerH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.hpGreen or theme.colors.accent,
      borderWidth = 1.5,
      radius = 6,
    })

    Layout.drawBadge(cardX + pad + 8, currentY + math.floor((eggBannerH - 18) / 2), "★ EGG READY", {
      kind = "good",
      font = "tiny",
      height = 18,
      radius = 3,
    })

    local bannerText = isCompact and "An Egg is ready! Speak with Day-Care Man." or "A Pokémon Egg has been discovered! Speak with the Day-Care Man outside to receive it."
    Layout.drawText(bannerText, cardX + pad + 96, currentY + math.floor((eggBannerH - Layout.textHeight("tiny")) / 2), {
      font = "tiny",
      color = theme.colors.heading,
      bold = true,
    })
  end

  -- 6. Bottom Dialogue / Question Modal
  local msgBoxY = cardY + cardH - footerH - pad
  local msgBoxW = cardW - pad * 2

  if state.message or state.confirm then
    local activeMsg = state.message or state.confirm
    local pageIdx = activeMsg.page or 1
    local pages = activeMsg.pages or {}
    local curLines = pages[pageIdx] or {}
    local line1 = curLines[1] or ""
    local line2 = curLines[2] or ""

    Layout.drawCard(cardX + pad, msgBoxY, msgBoxW, footerH, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.accent,
      borderWidth = 1.5,
      radius = 8,
    })

    Layout.drawText(line1, cardX + pad + 12, msgBoxY + (isCompact and 6 or 10), {
      font = isCompact and "caption" or "body",
      color = theme.colors.heading,
      bold = true,
    })
    if line2 and #line2 > 0 and footerH >= 50 then
      Layout.drawText(line2, cardX + pad + 12, msgBoxY + (isCompact and 22 or 28), {
        font = isCompact and "caption" or "body",
        color = theme.colors.heading,
        bold = true,
      })
    end

    if state.confirm and pageIdx >= #pages then
      local choice = state.confirm.choice or 1
      local btnW = isCompact and 70 or 86
      local btnH = isCompact and 24 or 28
      local btnY = msgBoxY + footerH - btnH - (isCompact and 4 or 8)

      Layout.drawButton(cardX + cardW - pad - btnW * 2 - 14, btnY, btnW, btnH, "YES", {
        kind = choice == 1 and "primary" or "ghost",
        selected = choice == 1,
        font = "tiny",
      })
      Layout.drawButton(cardX + cardW - pad - btnW - 6, btnY, btnW, btnH, "NO", {
        kind = choice == 2 and "primary" or "ghost",
        selected = choice == 2,
        font = "tiny",
      })
    end
  else
    Layout.drawText("A Confirm    B Cancel", cardX + pad, msgBoxY + (isCompact and 6 or 10), {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = msgBoxW,
    })
  end
end

return DayCareRenderer
