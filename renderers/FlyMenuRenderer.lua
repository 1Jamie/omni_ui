-- OmniUI HM02 Fly Destination Navigator Renderer
-- Split-pane destination navigator pairing the visited town list with live Town Map affine coordinate beacons.

local Layout = require("mods.omni_ui.core.Layout")
local TownMap = require("src.ui.TownMap")

local FlyMenuRenderer = {}

-- Normalized affine map coordinates [0.0 .. 1.0] for all Kanto/Johto fly destination towns
local TOWN_AFFINE_COORDS = {
  PALLET_TOWN    = { x = 0.20, y = 0.70 },
  VIRIDIAN_CITY  = { x = 0.20, y = 0.52 },
  PEWTER_CITY    = { x = 0.20, y = 0.20 },
  CERULEAN_CITY  = { x = 0.65, y = 0.20 },
  VERMILION_CITY = { x = 0.65, y = 0.60 },
  LAVENDER_TOWN  = { x = 0.85, y = 0.38 },
  CELADON_CITY   = { x = 0.48, y = 0.38 },
  FUCHSIA_CITY   = { x = 0.50, y = 0.85 },
  CINNABAR_ISLAND= { x = 0.20, y = 0.90 },
  INDIGO_PLATEAU = { x = 0.08, y = 0.12 },
  SAFFRON_CITY   = { x = 0.65, y = 0.38 },
}

local cachedBg = nil

local function getTownMapBg(game)
  if not cachedBg and TownMap and TownMap.loadBg then
    cachedBg = TownMap.loadBg(game)
  end
  return cachedBg
end

function FlyMenuRenderer.draw(game, state, w, h, theme, subState, progress)
  theme = theme or require("mods.omni_ui.core.Theme").get()
  local items = state.items or state.entries or {}
  local cursor = state.cursor or state.index or 1
  local curDest = items[cursor]
  local curMapId = curDest and (curDest.mapId or curDest.id or curDest.value)

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 540) or ctx.isPortrait
  local footY = h - 38

  -- 1. Outer Container
  Layout.drawCard(0, 0, w, h, {
    color = theme.bg,
    borderColor = theme.border,
    radius = 0,
  })

  -- Top Header
  Layout.drawCard(0, 0, w, 44, {
    color = theme.surface,
    borderColor = theme.border,
    radius = 0,
  })
  Layout.drawText("HM02 • AIR TRAVEL NAVIGATOR", 18, 12, { font = "headline", color = theme.heading, bold = true })
  if w >= 360 then
    Layout.drawBadge(w - 140, 10, "FLIGHT WARP", { kind = "accent", font = "caption", height = 24 })
  end

  local bg = getTownMapBg(game)

  if not isNarrow then
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANE LAYOUT
    -- =========================================================================
    local bodyH = h - 90
    local leftW = math.floor(w * 0.55)
    local rightX = leftW + 16
    local rightW = w - rightX - 16

    -- Left Pane: Schematic Town Map with Destination Spotlight
    Layout.drawCard(16, 52, leftW, bodyH, {
      color = theme.surface,
      borderColor = theme.border,
      radius = 8,
    })
    Layout.drawText("REGIONAL FLIGHT RADAR", 32, 66, { font = "caption", color = theme.colors.accent, bold = true })

    if bg and bg.img and bg.quads and bg.map then
      local mapNativeW = 160
      local mapNativeH = 144
      local pad = 16
      local availW = leftW - pad * 2
      local availH = bodyH - 60 - pad
      local scale = math.min(availW / mapNativeW, availH / mapNativeH)
      local drawW = mapNativeW * scale
      local drawH = mapNativeH * scale
      local mapX = 16 + math.floor((leftW - drawW) / 2)
      local mapY = 88 + math.floor((availH - drawH) / 2)

      Layout.drawSlot(mapX - 4, mapY - 4, drawW + 8, drawH + 8, {
        color = { 0.05, 0.07, 0.10, 1.0 },
        borderColor = theme.borderStrong,
        borderWidth = 1.5,
        radius = 6,
      })

      love.graphics.setColor(1, 1, 1, 1)
      for i, t in ipairs(bg.map) do
        local col = (i - 1) % 20
        local row = math.floor((i - 1) / 20)
        local q = bg.quads[t]
        if q then
          love.graphics.draw(bg.img, q, mapX + col * 8 * scale, mapY + row * 8 * scale, 0, scale, scale)
        end
      end

      local norm = curMapId and TOWN_AFFINE_COORDS[curMapId]
      if norm then
        local bx = mapX + norm.x * drawW
        local by = mapY + norm.y * drawH
        local time = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
        local pulse = 0.5 + 0.5 * math.sin(time * 6)

        love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], 0.35 + 0.25 * pulse)
        love.graphics.circle("fill", bx, by, (10 + 6 * pulse) * (scale / 2))

        love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], 1.0)
        love.graphics.circle("fill", bx, by, 4 * scale)

        love.graphics.setColor(1, 1, 1, 1.0)
        love.graphics.circle("fill", bx, by, 2 * scale)

        Layout.drawBadge(bx - 20, by - 24, "✈ FLY", { kind = "accent", font = "tiny" })
      end
    else
      Layout.drawSlot(32, 88, leftW - 32, bodyH - 60, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("KANTO REGION", 48, 110, { font = "headline", color = theme.heading, bold = true })
    end

    -- Right Pane: Visited Town Flight Destination List
    Layout.drawCard(rightX, 52, rightW, bodyH, {
      color = theme.surfaceHigh,
      borderColor = theme.border,
      radius = 8,
    })
    Layout.drawText("SELECT DESTINATION", rightX + 16, 66, { font = "caption", color = theme.colors.accent, bold = true })

    local itemH = 38
    local itemGap = 6
    local visibleRows = math.max(1, math.floor((bodyH - 60) / (itemH + itemGap)))
    local total = #items
    local scroll = math.max(0, math.min(total - visibleRows, cursor - math.floor(visibleRows / 2)))

    for r = 1, visibleRows do
      local idx = scroll + r
      local item = items[idx]
      if item then
        local iy = 90 + (r - 1) * (itemH + itemGap)
        local isSel = (idx == cursor)

        if isSel then
          Layout.drawCard(rightX + 12, iy, rightW - 24, itemH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(rightX + 12, iy, rightW - 24, itemH, {
            color = theme.surface,
            borderColor = theme.border,
            radius = 6,
          })
        end

        local label = item.label or tostring(item.value):gsub("_", " ")
        Layout.drawText(label:upper(), rightX + 24, iy + 10, { font = "button", color = theme.heading, bold = isSel, width = rightW - 110 })
        Layout.drawBadge(rightX + rightW - 74, iy + 8, isSel and "WARP" or "VISITED", { kind = isSel and "good" or "ghost", font = "tiny" })
      end
    end

    if total > visibleRows then
      Layout.drawScrollBar(rightX + rightW - 10, 90, 4, bodyH - 60, total, visibleRows, scroll)
    end

  else
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE STACKED LAYOUT
    -- =========================================================================
    local mapBoxH = 150
    Layout.drawCard(8, 48, w - 16, mapBoxH, {
      color = theme.surface,
      borderColor = theme.border,
      radius = 8,
    })

    if bg and bg.img and bg.quads and bg.map then
      local mapNativeW = 160
      local mapNativeH = 144
      local pad = 8
      local availW = w - 16 - pad * 2
      local availH = mapBoxH - pad * 2
      local scale = math.min(availW / mapNativeW, availH / mapNativeH)
      local drawW = mapNativeW * scale
      local drawH = mapNativeH * scale
      local mapX = 8 + math.floor((w - 16 - drawW) / 2)
      local mapY = 48 + math.floor((mapBoxH - drawH) / 2)

      love.graphics.setColor(1, 1, 1, 1)
      for i, t in ipairs(bg.map) do
        local col = (i - 1) % 20
        local row = math.floor((i - 1) / 20)
        local q = bg.quads[t]
        if q then
          love.graphics.draw(bg.img, q, mapX + col * 8 * scale, mapY + row * 8 * scale, 0, scale, scale)
        end
      end

      local norm = curMapId and TOWN_AFFINE_COORDS[curMapId]
      if norm then
        local bx = mapX + norm.x * drawW
        local by = mapY + norm.y * drawH
        local time = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
        local pulse = 0.5 + 0.5 * math.sin(time * 6)

        love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], 0.35 + 0.25 * pulse)
        love.graphics.circle("fill", bx, by, (8 + 4 * pulse) * (scale / 2))

        love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], 1.0)
        love.graphics.circle("fill", bx, by, 3 * scale)

        love.graphics.setColor(1, 1, 1, 1.0)
        love.graphics.circle("fill", bx, by, 1.5 * scale)

        Layout.drawBadge(bx - 16, by - 18, "✈", { kind = "accent", font = "tiny", height = 16 })
      end
    end

    -- Bottom Destination List (Full Width)
    local listY = 48 + mapBoxH + 6
    local listH = footY - listY - 6
    Layout.drawCard(8, listY, w - 16, listH, {
      color = theme.surfaceHigh,
      borderColor = theme.border,
      radius = 8,
    })

    local itemH = 34
    local itemGap = 4
    local visibleRows = math.max(1, math.floor((listH - 12) / (itemH + itemGap)))
    local total = #items
    local scroll = math.max(0, math.min(total - visibleRows, cursor - math.floor(visibleRows / 2)))

    for r = 1, visibleRows do
      local idx = scroll + r
      local item = items[idx]
      if item then
        local iy = listY + 6 + (r - 1) * (itemH + itemGap)
        local isSel = (idx == cursor)

        if isSel then
          Layout.drawCard(14, iy, w - 28, itemH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(14, iy, w - 28, itemH, {
            color = theme.surface,
            borderColor = theme.border,
            radius = 6,
          })
        end

        local label = item.label or tostring(item.value):gsub("_", " ")
        Layout.drawText(label:upper(), 24, iy + 8, { font = "caption", color = theme.heading, bold = isSel, width = w - 120 })
        Layout.drawBadge(w - 76, iy + 6, isSel and "WARP" or "VISITED", { kind = isSel and "good" or "ghost", font = "tiny" })
      end
    end

    if total > visibleRows then
      Layout.drawScrollBar(w - 14, listY + 6, 4, listH - 12, total, visibleRows, scroll)
    end
  end

  -- 4. Bottom Action Bar
  local hints = {
    { key = "A", label = "Fly", primary = true },
    { key = "▲ ▼", label = "Select" },
    { key = "B", label = "Cancel" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return FlyMenuRenderer
