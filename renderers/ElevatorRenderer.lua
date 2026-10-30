-- OmniUI Modern Elevator Directory Interface Renderer
-- Vertical elevator level selector and floor indicator.
-- Responsively calculates visible floor rows and scrollbar bounds for ultra-compact and mobile landscape heights.

local Layout = require("mods.omni_ui.core.Layout")

local ElevatorRenderer = {}

local FALLBACK_FLOORS = {
  "B4F", "B3F", "B2F", "B1F", "1F", "2F", "3F", "4F", "5F", "6F", "7F",
  "8F", "9F", "10F", "11F", "ROOF",
}

local function floorName(floorNames, row)
  if type(row) == "string" then return row end
  if type(row) == "table" then return row.floorId or row.name or row.id or "?" end
  if type(floorNames) == "table" and tonumber(row) and floorNames[tonumber(row) + 1] then
    return floorNames[tonumber(row) + 1]
  end
  local num = tonumber(row)
  if num then
    return FALLBACK_FLOORS[num + 1] or ("FLOOR " .. num)
  end
  return tostring(row or "?")
end

function ElevatorRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local floors = state.floors or {}
  local originIdx = state.origin
  local index = tonumber(state.index or 1)
  local scroll = tonumber(state.scroll or 0)
  local floorNames = state.floorNames

  -- Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(440, math.max(280, vw - pad * 2))
  local cardH = math.min(vh - pad * 2, isCompact and 280 or 340)
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
  Layout.drawBadge(cardX + pad, topY, "ELEVATOR", {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  -- Current Floor Status Badge
  local originRow = originIdx and floors[originIdx]
  local originStr = ("NOW ON: %s"):format(floorName(floorNames, originRow and originRow.floorId))
  local originW = Layout.textWidth(originStr, "tiny") + 16
  Layout.drawBadge(cardX + cardW - pad - originW, topY, originStr, {
    kind = "primary",
    font = "tiny",
    height = headerH,
    width = originW,
    radius = 4,
  })

  local promptY = topY + headerH + (isCompact and 4 or 8)
  Layout.drawText("SELECT DESTINATION FLOOR", cardX + pad, promptY, {
    font = "caption",
    color = theme.colors.textDim,
    bold = true,
  })

  -- Floors List with Dynamic Visible Row Calculation
  local startY = promptY + (isCompact and 18 or 24)
  local footerH = isCompact and 24 or 30
  local listAvailableH = cardH - (startY - cardY) - footerH - pad
  local itemH = isCompact and 28 or 36
  local itemGap = 4
  local visibleRows = math.max(2, math.min(#floors, math.floor(listAvailableH / (itemH + itemGap))))
  local listW = cardW - pad * 2

  for slot = 1, math.min(visibleRows, #floors) do
    local i = scroll + slot
    local row = floors[i]
    if row then
      local isSel = (i == index)
      local isOrigin = (i == originIdx)
      local iy = startY + (slot - 1) * (itemH + itemGap)
      local fName = floorName(floorNames, row.floorId)

      Layout.drawSlot(cardX + pad, iy, listW, itemH, {
        color = isSel and theme.colors.raised or theme.colors.surfaceHigh,
        borderColor = isSel and theme.colors.accent or theme.colors.border,
        borderWidth = isSel and 2 or 1,
        radius = 5,
      })

      -- Elevator Level Number / Name
      Layout.drawText(fName, cardX + pad + 12, iy + math.floor((itemH - Layout.textHeight(itemH > 30 and "button" or "caption")) / 2), {
        font = itemH > 30 and "button" or "caption",
        color = isSel and theme.colors.heading or theme.colors.text,
        bold = true,
      })

      -- Current Floor Indicator Tag
      if isOrigin then
        local curTagW = isCompact and 58 or 68
        Layout.drawBadge(cardX + cardW - pad - curTagW - 8, iy + math.floor((itemH - 18) / 2), "CURRENT", {
          kind = "ghost",
          font = "tiny",
          height = 18,
          width = curTagW,
          radius = 3,
        })
      elseif isSel then
        local goTagW = isCompact and 38 or 46
        Layout.drawBadge(cardX + cardW - pad - goTagW - 8, iy + math.floor((itemH - 18) / 2), "GO", {
          kind = "good",
          font = "tiny",
          height = 18,
          width = goTagW,
          radius = 3,
        })
      end
    end
  end

  -- Scroll Bar
  if #floors > visibleRows then
    Layout.drawScrollBar(cardX + cardW - pad + 3, startY, 3, visibleRows * (itemH + itemGap) - itemGap, #floors, visibleRows, scroll + 1, {
      is1Indexed = true,
      radius = 2,
    })
  end

  -- Footer Hint
  local footerY = cardY + cardH - footerH
  Layout.drawText("▲ ▼ Select Floor   A Ride Elevator   B Exit", cardX + pad, footerY + 2, {
    font = "tiny",
    color = theme.colors.textDim,
    align = "center",
    width = listW,
  })
end

return ElevatorRenderer
