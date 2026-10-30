-- OmniUI Celadon Game Corner Prize Counter Renderer
-- Exchange shop with live coin balance, prize categories, and item/species previews.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local Sprites = require("src.pokemon.Sprites")
local PaletteFX = require("src.render.PaletteFX")

local PrizeCounterRenderer = {}

local frontPics = {}
local function frontPic(path)
  if not path then return nil end
  if not frontPics[path] then
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
      img:setFilter("nearest", "nearest")
      frontPics[path] = img
    end
  end
  return frontPics[path]
end

function PrizeCounterRenderer.draw(game, state, w, h, theme, subState)
  local coins = (game.save and game.save.coins) or (state.save and state.save.coins) or 0
  local prizes = state.prizes or {}
  local curIdx = state.index or 1

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait
  local footY = h - 38

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText("CELADON PRIZE EXCHANGE", 18, 12, { font = "headline", color = theme.heading, bold = true })
  Layout.drawBadge(w - (isNarrow and 120 or 180), 10, ("%d COINS"):format(coins), { kind = "good", font = "caption", height = 24 })

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE FULL-WIDTH LIST + DOCKED PREVIEW DRAWER
    -- =========================================================================
    local detailH = 114
    local listH = footY - 50 - detailH - 8
    Layout.drawCard(0, 50, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local totalItems = #prizes + 1 -- include 'No Thanks'
    local rowH = 36
    local itemGap = 4
    local visibleRows = math.max(1, math.floor((listH - 16) / (rowH + itemGap)))
    local scroll = math.max(0, math.min(totalItems - visibleRows, curIdx - math.floor(visibleRows / 2)))

    local itemW = (totalItems > visibleRows) and (w - 28) or (w - 16)

    for r = 1, visibleRows do
      local idx = scroll + r
      local iy = 56 + (r - 1) * (rowH + itemGap)
      local isSel = (curIdx == idx)

      if idx <= #prizes then
        local p = prizes[idx]
        local canAfford = (coins >= (p.cost or 0))

        if isSel then
          Layout.drawCard(8, iy, itemW, rowH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(8, iy, itemW, rowH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            radius = 6,
          })
        end

        Layout.drawText(p.name or "PRIZE", 16, iy + 8, { font = "caption", color = isSel and theme.heading or theme.text, bold = isSel, width = itemW - 90 })
        local costStr = ("%d C"):format(p.cost or 0)
        local costW = Layout.textWidth(costStr, "tiny") + 16
        Layout.drawBadge(8 + itemW - costW - 6, iy + 6, costStr, { kind = canAfford and "good" or "danger", font = "tiny", width = costW })
      elseif idx == #prizes + 1 then
        if isSel then
          Layout.drawCard(8, iy, itemW, rowH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
          Layout.drawText("NO THANKS", 16, iy + 8, { font = "caption", color = theme.heading, bold = true })
        else
          Layout.drawSlot(8, iy, itemW, rowH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            radius = 6,
          })
          Layout.drawText("NO THANKS", 16, iy + 8, { font = "caption", color = theme.textMuted })
        end
      end
    end

    if totalItems > visibleRows then
      Layout.drawScrollBar(w - 12, 56, 5, listH - 12, totalItems, visibleRows, scroll)
    end

    -- Docked Prize Preview Drawer
    local detailY = 50 + listH + 6
    Layout.drawCard(0, detailY, w, detailH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curPrize = prizes[curIdx]
    if curPrize then
      local pName = curPrize.name or "PRIZE"
      local canAfford = (coins >= (curPrize.cost or 0))

      local monDef = nil
      for _, d in pairs(game.data and game.data.pokemon or {}) do
        if d.name == pName or d.species == pName or d.id == pName or d.id == curPrize.species then
          monDef = d
          break
        end
      end

      if monDef then
        local boxSize = 72
        Layout.drawSlot(8, detailY + 12, boxSize, boxSize, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        local path, trueColor = Sprites.path(game.data, monDef.species or monDef.name, "front")
        local img = frontPic(path)
        if img then
          local pw, ph = img:getDimensions()
          local scale = (boxSize - 8) / math.max(pw, ph)
          local targetW = pw * scale
          local targetH = ph * scale
          local px = 8 + math.floor((boxSize - targetW) / 2)
          local py = detailY + 12 + math.floor((boxSize - targetH) / 2)

          local shader = PaletteFX.shader()
          local pal = PaletteFX.monPal(game.data, monDef.species or monDef.name)
          if shader and pal and not trueColor then
            love.graphics.setShader(shader)
            PaletteFX.sendColors(shader, pal)
          end
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(img, px + targetW, py, 0, -scale, scale)
          if shader and pal and not trueColor then
            love.graphics.setShader()
          end
        end

        local hx = boxSize + 16
        Layout.drawText(pName, hx, detailY + 10, { font = "headline", color = theme.heading, bold = true })
        Layout.drawBadge(w - 90, detailY + 10, ("%d COINS"):format(curPrize.cost or 0), { kind = canAfford and "good" or "danger", font = "tiny" })

        if monDef.types then
          local tyX = hx
          for _, t in ipairs(monDef.types) do
            local bw = Widgets.drawTypeBadge(t, tyX, detailY + 38)
            tyX = tyX + bw + 4
          end
        end

        Layout.drawText(canAfford and "Press A to exchange prize" or "Not enough coins", hx, detailY + 68, {
          font = "tiny",
          color = canAfford and theme.colors.hpGreen or theme.colors.hpRed,
          bold = true,
        })
      else
        Layout.drawText(pName, 14, detailY + 10, { font = "headline", color = theme.heading, bold = true })
        Layout.drawBadge(w - 90, detailY + 10, ("%d COINS"):format(curPrize.cost or 0), { kind = canAfford and "good" or "danger", font = "tiny" })
        Layout.drawTextWrapped(
          "Exclusive technical machine or rare item obtainable with game coins.",
          14, detailY + 38, w - 28, { font = "caption", color = theme.textDim }
        )
      end
    else
      Layout.drawText("EXIT COUNTER", 14, detailY + 14, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawText("Press A or B to leave the prize counter.", 14, detailY + 42, { font = "caption", color = theme.textDim })
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANEL LAYOUT
    -- =========================================================================
    local bodyH = h - 96
    local leftW = math.floor(w * 0.52)
    local rightX = leftW + 12
    local rightW = w - rightX

    -- Left Prize Catalog Card
    Layout.drawCard(0, 52, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("AVAILABLE PRIZES", 18, 66, { font = "caption", color = theme.colors.accent, bold = true })

    local rowH = 46
    local itemGap = 8

    for i, p in ipairs(prizes) do
      local isSel = (curIdx == i)
      local iy = 90 + (i - 1) * (rowH + itemGap)
      local canAfford = (coins >= (p.cost or 0))

      if isSel then
        Layout.drawCard(12, iy, leftW - 24, rowH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
      else
        Layout.drawSlot(12, iy, leftW - 24, rowH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 6,
        })
      end

      Layout.drawText(p.name or "PRIZE", 24, iy + 12, { font = "button", color = isSel and theme.heading or theme.text, bold = isSel })
      local costStr = ("%d COINS"):format(p.cost or 0)
      Layout.drawBadge(leftW - 120, iy + 10, costStr, { kind = canAfford and "good" or "danger", font = "tiny" })
    end

    local exitIdx = #prizes + 1
    local isExitSel = (curIdx == exitIdx or curIdx > #prizes)
    local exitY = 90 + #prizes * (rowH + itemGap)

    if isExitSel then
      Layout.drawCard(12, exitY, leftW - 24, rowH, {
        color = theme.accentDark,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = 6,
      })
      Layout.drawText("NO THANKS", 24, exitY + 12, { font = "button", color = theme.heading, bold = true })
    else
      Layout.drawSlot(12, exitY, leftW - 24, rowH, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 6,
      })
      Layout.drawText("NO THANKS", 24, exitY + 12, { font = "button", color = theme.textMuted })
    end

    -- Right Prize Preview & Exchange Panel
    Layout.drawCard(rightX, 52, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curPrize = prizes[curIdx]
    if curPrize then
      local pName = curPrize.name or "PRIZE"
      Layout.drawText(pName, rightX + 18, 66, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(rightX + rightW - 120, 66, ("%d COINS"):format(curPrize.cost or 0), { kind = (coins >= (curPrize.cost or 0)) and "good" or "danger" })

      local monDef = nil
      for _, d in pairs(game.data and game.data.pokemon or {}) do
        if d.name == pName or d.species == pName or d.id == pName or d.id == curPrize.species then
          monDef = d
          break
        end
      end

      if monDef then
        local portH = 140
        Layout.drawSlot(rightX + 16, 100, rightW - 32, portH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
        local path, trueColor = Sprites.path(game.data, monDef.species or monDef.name, "front")
        local img = frontPic(path)
        if img then
          local pw, ph = img:getDimensions()
          local scale = 2
          local targetW = pw * scale
          local targetH = ph * scale
          local px = rightX + 16 + math.floor((rightW - 32 - targetW) / 2)
          local py = 100 + math.floor((portH - targetH) / 2)

          local shader = PaletteFX.shader()
          local pal = PaletteFX.monPal(game.data, monDef.species or monDef.name)
          if shader and pal and not trueColor then
            love.graphics.setShader(shader)
            PaletteFX.sendColors(shader, pal)
          end
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(img, px + targetW, py, 0, -scale, scale)
          if shader and pal and not trueColor then
            love.graphics.setShader()
          end
        end

        if monDef.types then
          local tyX = rightX + 18
          for _, t in ipairs(monDef.types) do
            local bw = Widgets.drawTypeBadge(t, tyX, 252)
            tyX = tyX + bw + 6
          end
        end
      else
        local infoY = 100
        local infoH = 120
        Layout.drawSlot(rightX + 16, infoY, rightW - 32, infoH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("EXCHANGE ITEM", rightX + 28, infoY + 14, { font = "caption", color = theme.colors.accent, bold = true })
        Layout.drawTextWrapped(
          "Exchange your hard-earned Game Corner coins for exclusive technical machines and rare items.",
          rightX + 28, infoY + 38, rightW - 56, { font = "body", color = theme.textDim }
        )
      end
    else
      Layout.drawText("EXIT COUNTER", rightX + 18, 66, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawSlot(rightX + 16, 100, rightW - 32, 80, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("Leave the counter and return to the game floor.", rightX + 28, 126, { font = "caption", color = theme.textDim })
    end
  end

  -- 4. Bottom Button Hints Footer Bar
  local hints = {
    { key = "▲ ▼", label = "Select", primary = true },
    { key = "A", label = "Exchange" },
    { key = "B", label = "Leave" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return PrizeCounterRenderer
