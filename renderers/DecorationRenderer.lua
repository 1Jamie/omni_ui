-- OmniUI Modern Bedroom Decoration Interface Renderer
-- Furniture, carpet, console, and plush doll customizer for the player's bedroom.
-- Responsively calculates visible decoration rows, item heights, and scrollbars for all viewports.

local Layout = require("mods.omni_ui.core.Layout")

local DecorationRenderer = {}

local SIDES = {
  { id = "right", label = "RIGHT SIDE" },
  { id = "left", label = "LEFT SIDE" },
  { id = nil, label = "CANCEL" },
}

function DecorationRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local mode = state.mode or "category"
  local index = tonumber(state.index or 1)
  local scroll = tonumber(state.scroll or 0)

  -- Dimmed Backdrop
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(480, math.max(280, vw - pad * 2))
  local cardH = math.min(vh - pad * 2, isCompact and 290 or 350)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- 1. Main Container
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.accent,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 14),
  })

  -- 2. Header
  local topY = cardY + pad
  local headerH = isCompact and 20 or 24
  Layout.drawBadge(cardX + pad, topY, "MY ROOM DECOR", {
    kind = "primary",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  local modeBadge = (mode == "items") and (state.category and state.category.label or "ITEMS") or (mode == "side" and "CHOOSE SIDE" or "CATEGORIES")
  local modeW = Layout.textWidth(modeBadge, "tiny") + 16
  Layout.drawBadge(cardX + cardW - pad - modeW, topY, modeBadge, {
    kind = "accent",
    font = "tiny",
    height = headerH,
    width = modeW,
    radius = 4,
  })

  local listStartY = topY + headerH + (isCompact and 6 or 10)
  local footerH = isCompact and 24 or 30
  local listAvailableH = cardH - (listStartY - cardY) - footerH - pad
  local itemH = isCompact and 28 or 34
  local itemGap = 4
  local listW = cardW - pad * 2
  local visibleRows = math.max(2, math.floor(listAvailableH / (itemH + itemGap)))

  -- 3. Content Rendering by Mode
  if mode == "category" then
    local categories = state.categories or {}
    local total = #categories + 1
    local maxShow = math.min(visibleRows, total)

    for row = 1, maxShow do
      local i = row
      local isSel = (i == index)
      local iy = listStartY + (row - 1) * (itemH + itemGap)
      local label = (i <= #categories) and tostring(categories[i].label or categories[i].name or categories[i].id):upper() or "EXIT"

      Layout.drawButton(cardX + pad, iy, listW, itemH, label, {
        kind = isSel and "primary" or "ghost",
        selected = isSel,
        font = itemH > 30 and "button" or "caption",
      })
    end
  elseif mode == "items" then
    local rows = state.rows or {}
    local visibleCount = math.min(visibleRows, #rows)

    for row = 1, visibleCount do
      local i = row + scroll
      local decoId = rows[i]
      if decoId then
        local isSel = (i == index)
        local iy = listStartY + (row - 1) * (itemH + itemGap)
        local rawName = state.rowName and state:rowName(decoId) or tostring(decoId):gsub("_", " ")
        local nameStr = tostring(rawName):upper()

        Layout.drawSlot(cardX + pad, iy, listW, itemH, {
          color = isSel and theme.colors.raised or theme.colors.surfaceHigh,
          borderColor = isSel and theme.colors.accent or theme.colors.border,
          borderWidth = isSel and 2 or 1,
          radius = 5,
        })

        Layout.drawText(nameStr, cardX + pad + 10, iy + math.floor((itemH - Layout.textHeight(itemH > 30 and "button" or "caption")) / 2), {
          font = itemH > 30 and "button" or "caption",
          color = isSel and theme.colors.heading or theme.colors.text,
          bold = true,
        })

        if isSel then
          Layout.drawBadge(cardX + cardW - pad - 54, iy + math.floor((itemH - 18) / 2), "SET", {
            kind = "good",
            font = "tiny",
            height = 18,
            width = 46,
            radius = 3,
          })
        end
      end
    end

    if #rows > visibleRows then
      Layout.drawScrollBar(cardX + cardW - pad + 3, listStartY, 3, visibleRows * (itemH + itemGap) - itemGap, #rows, visibleRows, scroll + 1, {
        is1Indexed = true,
        radius = 2,
      })
    end
  elseif mode == "side" then
    local sideIndex = tonumber(state.sideIndex or 1)
    for i, side in ipairs(SIDES) do
      local isSel = (i == sideIndex)
      local iy = listStartY + (i - 1) * (itemH + itemGap)
      Layout.drawButton(cardX + pad, iy, listW, itemH, side.label, {
        kind = isSel and "primary" or "ghost",
        selected = isSel,
        font = itemH > 30 and "button" or "caption",
      })
    end
  end

  -- 4. Dialogue Box Overlay if message is active
  if state.pages and state.pageIndex then
    local curMsg = state.pages[state.pageIndex]
    local msgText = type(curMsg) == "table" and table.concat(curMsg, "\n") or tostring(curMsg or "")
    local dw = cardW - pad * 2
    local dh = isCompact and 54 or 68
    local dx = cardX + pad
    local dy = cardY + cardH - dh - 8

    Layout.drawCard(dx, dy, dw, dh, {
      color = theme.colors.surfaceHigh,
      borderColor = theme.colors.borderStrong,
      borderWidth = 1.5,
      radius = 6,
    })

    Layout.drawTextWrapped(msgText, dx + 10, dy + 8, dw - 20, {
      font = "caption",
      color = theme.colors.heading,
      lineHeight = 1.2,
    })
  else
    -- Footer Hint
    local footerY = cardY + cardH - footerH
    local hintText = (mode == "category") and "▲ ▼ Select Category   A Open   B Exit" or "▲ ▼ Select Item   A Place / Stash   B Back"
    Layout.drawText(hintText, cardX + pad, footerY + 2, {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = listW,
    })
  end
end

return DecorationRenderer
