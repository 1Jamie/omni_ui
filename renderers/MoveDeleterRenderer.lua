-- OmniUI Modern Move Deleter & Move Relearner Interface Renderer
-- 4-Slot Move Inspector displaying Type Badges, Category, Power, Accuracy, PP Bars, and Forget Action Prompts.
-- Fully responsive across desktop landscape, compact mobile landscape, and stacked mobile portrait orientations.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")

local MoveDeleterRenderer = {}

local function monName(mon)
  if not mon then return "POKÉMON" end
  return (mon.nickname or mon.name or mon.species or "POKÉMON"):upper()
end

function MoveDeleterRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local data = (game and game.data) or {}
  local mon = state.mon or {}
  local movesData = state.moves or (data and data.moves) or {}
  local list = state.list or (mon.moves) or {}
  local selectedRow = state.row or 1
  local isForgetMode = state.forget or (state.layout == "forget")

  -- 1. Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- Main Frame Metrics
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(680, vw - pad * 2)
  local cardH = math.min(500, vh - pad * 2)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 2. Master Card
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = isForgetMode and theme.colors.accent or (theme.colors.danger or theme.colors.accent),
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 16),
  })

  -- 3. Header Bar
  local topY = cardY + pad
  local headerH = isCompact and 22 or 26
  local headerTitle = isForgetMode and "REPLACE MOVE" or "MOVE DELETER"
  Layout.drawBadge(cardX + pad, topY, headerTitle, {
    kind = isForgetMode and "accent" or "danger",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local nameStr = monName(mon)
  local lvlStr = ("Lv. %d"):format(mon.level or 1)
  local infoW = Layout.textWidth(nameStr .. "  " .. lvlStr, "tiny") + 16
  Layout.drawBadge(cardX + cardW - pad - infoW, topY, nameStr .. "  " .. lvlStr, {
    kind = "primary",
    font = "tiny",
    height = headerH,
    width = infoW,
    radius = 4,
  })

  -- 4. 4-Slot Move List
  local listY = topY + headerH + (isCompact and 6 or 10)
  local footerH = isCompact and 28 or 36
  local listH = cardH - (listY - cardY) - footerH - pad
  local itemGap = isCompact and 5 or 8
  local itemH = math.floor((listH - itemGap * 3) / 4)
  local itemW = cardW - pad * 2

  for slot = 1, 4 do
    local entry = list[slot]
    local isSelected = (slot == selectedRow)
    local iy = listY + (slot - 1) * (itemH + itemGap)

    if entry then
      local mId = entry.id or entry.move or entry
      local mDef = (type(mId) == "table" and mId) or (movesData and movesData[mId]) or { name = tostring(mId), type = "NORMAL", pp = 20, power = 40, accuracy = 100 }
      local moveName = (mDef.name or tostring(mId)):upper()
      local moveType = (mDef.type or "NORMAL"):upper()
      local curPp = tonumber(entry.pp or mDef.pp or 20)
      local maxPp = tonumber(mDef.pp or 20)
      local pwr = mDef.power and (mDef.power > 0 and tostring(mDef.power) or "--") or "--"
      local acc = mDef.accuracy and (mDef.accuracy > 0 and (tostring(mDef.accuracy) .. "%") or "--") or "--"

      -- Move Container
      Layout.drawCard(cardX + pad, iy, itemW, itemH, {
        color = isSelected and theme.colors.raised or theme.colors.surfaceHigh,
        borderColor = isSelected and (theme.colors.accent or theme.colors.borderStrong) or theme.colors.border,
        borderWidth = isSelected and 2 or 1,
        radius = 6,
      })

      -- Selector Pip
      if isSelected then
        Layout.drawBadge(cardX + pad + 6, iy + math.floor((itemH - 18) / 2), "►", {
          kind = "accent",
          font = "tiny",
          width = 16,
          height = 18,
          radius = 3,
        })
      end

      local textStartX = cardX + pad + (isSelected and 28 or 10)

      -- Move Name & PP Badge on Line 1
      Layout.drawText(moveName, textStartX, iy + (isCompact and 4 or 6), {
        font = isCompact and "caption" or "button",
        color = isSelected and theme.colors.heading or theme.colors.text,
        bold = true,
      })

      local nameTw = Layout.textWidth(moveName, isCompact and "caption" or "button")
      local typeBadgeX = textStartX + nameTw + 8
      Widgets.drawTypeBadge(moveType, typeBadgeX, iy + (isCompact and 3 or 5), { height = 16, font = "tiny" })

      local ppStr = ("PP %d/%d"):format(curPp, maxPp)
      local ppW = Layout.textWidth(ppStr, "tiny") + 12
      local ppX = cardX + pad + itemW - ppW - 8
      Layout.drawBadge(ppX, iy + (isCompact and 3 or 5), ppStr, {
        kind = (curPp == 0) and "danger" or (curPp <= 5 and "warning" or "ghost"),
        font = "tiny",
        height = 16,
        width = ppW,
        radius = 3,
      })

      -- Power & Accuracy on Line 2
      local line2Y = iy + (isCompact and 20 or 26)
      if itemH >= 38 then
        Layout.drawText(("PWR %s   ACC %s"):format(pwr, acc), textStartX, line2Y, {
          font = "tiny",
          color = theme.colors.textDim,
        })
      end

      -- PP Progress Bar at bottom of item
      local barY = iy + itemH - (isCompact and 4 or 5)
      Layout.drawProgressBar(textStartX, barY, itemW - (textStartX - (cardX + pad)) - 8, 3, curPp, maxPp, {
        fillColor = (curPp == 0) and theme.colors.danger or (curPp <= 5 and theme.colors.hpYellow or theme.colors.hpGreen),
        bgColor = theme.colors.surface,
      })
    else
      -- Empty Move Slot
      Layout.drawSlot(cardX + pad, iy, itemW, itemH, {
        color = theme.colors.surfaceHigh,
        borderColor = theme.colors.border,
        borderWidth = 1,
        radius = 6,
      })

      Layout.drawText("- EMPTY MOVE SLOT -", cardX + pad + 12, iy + math.floor(itemH / 2) - 6, {
        font = "tiny",
        color = theme.colors.textDim,
      })
    end
  end

  -- 5. Footer Hint Bar
  local footerY = cardY + cardH - footerH
  local actionHint = isForgetMode and "▲ ▼ Select Move to Replace   A Forget Move   B Cancel" or "▲ ▼ Select Move to Forget   A Forget Move   B Cancel"
  Layout.drawText(actionHint, cardX + pad, footerY + (isCompact and 4 or 8), {
    font = "tiny",
    color = theme.colors.textDim,
    align = "center",
    width = itemW,
  })
end

return MoveDeleterRenderer
