-- OmniUI Modern Battle Tower Challenge Interface Renderer
-- Challenge level room selector with streak requirements, rules overview, and party restriction checks.
-- Supports side-by-side desktop dual-pane and stacked vertical sections on portrait viewports with dynamic scrollbar.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local BattleTower = require("src.core.gen2.BattleTower")

local BattleTowerRenderer = {}

function BattleTowerRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local rows = state.rows or (BattleTower.levelGroupRows and BattleTower.levelGroupRows(state.save)) or {}
  local cursor = state.cursor or 1
  local totalRows = #rows + 1 -- Last is Cancel
  local phase = state.phase or "pick"
  local message = state.message or "What level do you want to challenge?"

  -- 1. Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Frame Dimensions
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(740, vw - pad * 2)
  local cardH = math.min(520, vh - pad * 2)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 2. Master Frame
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 16),
  })

  -- 3. Top Header Bar
  local topY = cardY + pad
  local headerH = isCompact and 22 or 26
  Layout.drawBadge(cardX + pad, topY, "BATTLE TOWER FACILITY", {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local streakW = isCompact and 110 or 130
  Layout.drawBadge(cardX + cardW - pad - streakW, topY, "7-BATTLE STREAK", {
    kind = "warning",
    font = "tiny",
    height = headerH,
    width = streakW,
    radius = 4,
  })

  -- 4. Content Area Layout
  local contentY = topY + headerH + (isCompact and 6 or 10)
  local footerH = isCompact and (isPortrait and 64 or 56) or 80
  local contentH = cardH - (contentY - cardY) - footerH - pad

  -- Helper to draw Room Level Selector
  local function drawRoomSelector(lx, ly, lw, lh)
    Layout.drawCard(lx, ly, lw, lh, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.border,
      borderWidth = 1,
      radius = 8,
    })

    Layout.drawText("CHALLENGE ROOMS", lx + 10, ly + 6, {
      font = "tiny",
      color = theme.colors.accent,
      bold = true,
    })

    local listStartY = ly + 24
    local listAvailH = lh - 28
    local itemH = isCompact and 26 or 32
    local itemGap = 4
    local visibleLevels = math.max(2, math.min(6, math.floor(listAvailH / (itemH + itemGap))))
    local scrollOffset = math.max(0, math.min(cursor - 1, totalRows - visibleLevels))

    for slot = 1, visibleLevels do
      local idx = scrollOffset + slot
      if idx <= totalRows then
        local isSel = (idx == cursor)
        local isCancel = (idx == totalRows)
        local levelLabel = isCancel and "CANCEL CHALLENGE" or ("LEVEL %d ROOM"):format(idx * 10)
        local iy = listStartY + (slot - 1) * (itemH + itemGap)

        Layout.drawCard(lx + 6, iy, lw - 12, itemH, {
          color = isSel and theme.colors.raised or theme.colors.surface,
          borderColor = isSel and (theme.colors.accent or theme.colors.borderStrong) or theme.colors.border,
          borderWidth = isSel and 2 or 1,
          radius = 5,
        })

        Layout.drawText(levelLabel, lx + 12, iy + math.floor((itemH - Layout.textHeight("tiny")) / 2), {
          font = "tiny",
          color = isSel and theme.colors.heading or (isCancel and theme.colors.danger or theme.colors.text),
          bold = isSel or isCancel,
        })

        if isSel then
          Layout.drawBadge(lx + lw - 26, iy + math.floor((itemH - 16) / 2), "►", {
            kind = "accent",
            font = "tiny",
            width = 16,
            height = 16,
            radius = 3,
          })
        end
      end
    end

    if totalRows > visibleLevels then
      Layout.drawScrollBar(lx + lw - 6, listStartY, 3, visibleLevels * (itemH + itemGap) - itemGap, totalRows, visibleLevels, scrollOffset + 1, {
        is1Indexed = true,
        radius = 2,
      })
    end
  end

  -- Helper to draw Regulations summary
  local function drawRegulations(rx, ry, rw, rh)
    Layout.drawCard(rx, ry, rw, rh, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.border,
      borderWidth = 1,
      radius = 8,
    })

    Layout.drawText("BATTLE TOWER REGULATIONS", rx + 10, ry + 6, {
      font = "tiny",
      color = theme.colors.heading,
      bold = true,
    })

    local ruleItems = {
      { tag = "TEAM SIZE", desc = "Exactly 3 Pokémon per run." },
      { tag = "NO DUPES", desc = "No duplicate Pokémon / items." },
      { tag = "BANS", desc = "Mew, Mewtwo, Lugia, Ho-Oh restricted." },
      { tag = "LEVEL CAP", desc = "Opponents scale to room cap." },
    }

    local rulesY = ry + 24
    local slotH = isCompact and 24 or 32
    local slotGap = 4
    local maxRules = math.min(#ruleItems, math.floor((rh - 28) / (slotH + slotGap)))

    for i = 1, maxRules do
      local r = ruleItems[i]
      local sy = rulesY + (i - 1) * (slotH + slotGap)
      Layout.drawSlot(rx + 6, sy, rw - 12, slotH, {
        color = theme.colors.surface,
        borderColor = theme.colors.border,
        borderWidth = 1,
        radius = 5,
      })

      Layout.drawBadge(rx + 10, sy + math.floor((slotH - 18) / 2), r.tag, {
        kind = "primary",
        font = "tiny",
        height = 18,
        radius = 3,
      })

      local descX = rx + (isCompact and 78 or 94)
      Layout.drawText(r.desc, descX, sy + math.floor((slotH - Layout.textHeight("tiny")) / 2), {
        font = "tiny",
        color = theme.colors.textDim,
      })
    end
  end

  if isPortrait then
    -- =========================================================================
    -- PORTRAIT STACKED LAYOUT (Top: Room Selector, Bottom: Regulations)
    -- =========================================================================
    local slotGap = 6
    local topPaneH = math.floor(contentH * 0.54)
    local botPaneH = contentH - topPaneH - slotGap
    local paneW = cardW - pad * 2

    drawRoomSelector(cardX + pad, contentY, paneW, topPaneH)
    drawRegulations(cardX + pad, contentY + topPaneH + slotGap, paneW, botPaneH)
  else
    -- =========================================================================
    -- LANDSCAPE SIDE-BY-SIDE DUAL PANE
    -- =========================================================================
    local leftW = math.floor((cardW - pad * 2 - (isCompact and 10 or 16)) * 0.42)
    local rightW = cardW - pad * 2 - leftW - (isCompact and 10 or 16)
    local leftX = cardX + pad
    local rightX = leftX + leftW + (isCompact and 10 or 16)

    drawRoomSelector(leftX, contentY, leftW, contentH)
    drawRegulations(rightX, contentY, rightW, contentH)
  end

  -- 5. Bottom Dialogue / Confirmation Box
  local msgBoxY = cardY + cardH - footerH - pad
  local msgBoxW = cardW - pad * 2

  Layout.drawCard(cardX + pad, msgBoxY, msgBoxW, footerH, {
    color = theme.colors.surfaceHigh,
    borderColor = phase == "message" and theme.colors.danger or theme.colors.accent,
    borderWidth = 1.5,
    radius = 8,
  })

  Layout.drawText(tostring(message), cardX + pad + 12, msgBoxY + (isCompact and 6 or 10), {
    font = isCompact and "caption" or "body",
    color = theme.colors.heading,
    bold = true,
  })

  if phase == "quit" then
    local btnW = isCompact and 70 or 86
    local btnH = isCompact and 24 or 28
    local btnY = msgBoxY + footerH - btnH - (isCompact and 4 or 8)
    local isYes = state.yes

    Layout.drawButton(cardX + cardW - pad - btnW * 2 - 14, btnY, btnW, btnH, "YES", {
      kind = isYes and "primary" or "ghost",
      selected = isYes,
      font = "tiny",
    })
    Layout.drawButton(cardX + cardW - pad - btnW - 6, btnY, btnW, btnH, "NO", {
      kind = not isYes and "primary" or "ghost",
      selected = not isYes,
      font = "tiny",
    })
  else
    Layout.drawText("▲ ▼ Select Level   A Confirm Challenge   B Cancel", cardX + pad, msgBoxY + footerH - (isCompact and 16 or 20), {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = msgBoxW,
    })
  end
end

return BattleTowerRenderer
