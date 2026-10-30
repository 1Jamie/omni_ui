-- OmniUI Storage System (Bill's PC & Pokémon Storage) Renderer
-- Desktop/Console grade interactive box manager with 6-col grid, party drawer,
-- dynamic layout inspector card, box carousel switcher, and safe release dialogs.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local PaletteFX = require("src.render.PaletteFX")
local Sprites = require("src.pokemon.Sprites")
local StorageController = require("mods.omni_ui.core.StorageController")
local SpriteHelper = require("mods.omni_ui.core.SpriteHelper")
local StatResolver = require("mods.omni_ui.core.StatResolver")

local StorageRenderer = {}

local function drawMonSprite(game, speciesName, x, y, w, h, alpha, isShiny)
  if not speciesName then return end
  SpriteHelper.drawFrontPic(game.data, speciesName, x, y, w, h, {
    alpha = alpha or 1.0,
    isShiny = isShiny or false,
    kind = "summary",
  })
end

function StorageRenderer.draw(game, state, w, h, theme, subState, animProgress)
  -- Initialize or bind state machine controller
  if not state.__storageController then
    state.__storageController = StorageController.new(game, {
      mode = state.mode or "browse",
      subMode = state.subMode or (state.mode == "withdraw" and "withdraw") or (state.mode == "deposit" and "deposit") or "move",
    })
  end

  local ctrl = state.__storageController
  local adapter = ctrl.adapter
  local boxMons = ctrl.boxMons or {}
  local partyMons = ctrl.partyMons or {}
  local capacity = ctrl.boxCapacity or 20
  local boxCount = ctrl.boxCount or 12
  local curBoxId = ctrl.currentBoxId or 1
  local curBoxName = ctrl.boxName or ("BOX " .. curBoxId)

  -- Count occupied slots in current box
  local occupiedCount = 0
  for slot = 1, capacity do
    if boxMons[slot] then occupiedCount = occupiedCount + 1 end
  end

  -- Pre-cache adjacent boxes asynchronously (box - 1, box + 1)
  local prevBox = ((curBoxId - 2 + boxCount) % boxCount) + 1
  local nextBox = (curBoxId % boxCount) + 1
  local prevData = adapter:getBoxData(prevBox)
  local nextData = adapter:getBoxData(nextBox)
  for _, m in ipairs(prevData or {}) do
    local p = Sprites.path(game.data, m.speciesId or m.displayName, "front")
    SpriteHelper.getImage(p)
  end
  for _, m in ipairs(nextData or {}) do
    local p = Sprites.path(game.data, m.speciesId or m.displayName, "front")
    SpriteHelper.getImage(p)
  end

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait
  local footY = h - 38

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 42, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText("POKÉMON STORAGE", 18, 11, { font = "headline", color = theme.heading, bold = true })

  -- Box Occupancy Meter & Switcher Button
  local meterText = ("%s • %d/%d"):format(curBoxName, occupiedCount, capacity)
  local meterBadgeW = Layout.textWidth(meterText, "caption") + 24
  Layout.drawBadge(w - meterBadgeW - 12, 9, meterText, { kind = (occupiedCount >= capacity) and "danger" or "good", font = "caption", height = 24, width = meterBadgeW })

  local heroH = isNarrow and 104 or 0
  local workspaceY = isNarrow and (46 + heroH + 6) or 52
  local bodyH = isNarrow and (footY - workspaceY - 6) or (h - 96)
  local leftW = isNarrow and w or math.floor(w * 0.58)
  local rightX = leftW + 12
  local rightW = w - rightX

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT HERO INSPECTION PREVIEW CARD
    -- =========================================================================
    Layout.drawCard(0, 46, w, heroH, { color = theme.surface, borderColor = theme.border, radius = 8 })
    local selMon = ctrl:getCurrentSelection()
    local boxW = 76
    local boxH = 76
    Layout.drawSlot(8, 54, boxW, boxH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

    if selMon then
      local isEgg = selMon.isEgg
      local selSpecies = isEgg and "EGG" or (selMon.speciesId or selMon.species or selMon.displayName)
      drawMonSprite(game, selSpecies, 10, 56, boxW - 4, boxH - 4, 1.0, selMon.isShiny)
      if selMon.isShiny and not isEgg then
        Layout.drawText("★", 12, 56, { font = "tiny", color = theme.hpYellow, bold = true })
      end

      local hx = boxW + 18
      local hw = w - hx - 10
      local name = isEgg and "POKÉMON EGG" or (selMon.nickname or selMon.displayName or selSpecies)
      Layout.drawText(name, hx, 52, { font = "headline", color = theme.heading, bold = true, width = hw - 70 })

      if isEgg then
        Layout.drawBadge(w - 60, 52, "EGG", { kind = "team", font = "tiny" })
        Layout.drawText(selMon.eggFlavorText or "An odd Pokémon EGG.", hx, 76, { font = "tiny", color = theme.textDim, width = hw })
      else
        local badgeX = w - 60
        Layout.drawBadge(badgeX, 52, ("Lv.%d"):format(selMon.level or 1), { kind = "team", font = "tiny" })
        if selMon.gender == "MALE" or selMon.gender == "M" then
          Layout.drawText("♂", badgeX - 16, 54, { font = "tiny", color = { 0.35, 0.65, 1.0, 1.0 }, bold = true })
        elseif selMon.gender == "FEMALE" or selMon.gender == "F" then
          Layout.drawText("♀", badgeX - 16, 54, { font = "tiny", color = { 1.0, 0.45, 0.55, 1.0 }, bold = true })
        end

        -- Types (Deduplicated for single-type Pokémon)
        local uniqueTypes = Widgets.getUniqueTypes(selMon.types or { "NORMAL" })
        local tyX = hx
        for _, t in ipairs(uniqueTypes) do
          local bw = Widgets.drawTypeBadge(t, tyX, 74)
          tyX = tyX + bw + 4
        end

        -- HP bar & Numbers
        local curHp = selMon.currentHp or selMon.hp or selMon.maxHp or 1
        local maxHp = selMon.maxHp or 1
        Layout.drawHealthBar(hx, 106, hw, 5, curHp, maxHp)
        Layout.drawText(("HP %d/%d"):format(curHp, maxHp), hx, 116, { font = "tiny", color = theme.textDim })
        if selMon.isMail then
          Layout.drawBadge(w - 86, 114, "✉ MAIL", { kind = "warn", font = "tiny", height = 16 })
        elseif selMon.heldItem then
          local iName = tostring(selMon.heldItem):gsub("_", " ")
          Layout.drawBadge(w - 86, 114, iName, { kind = "ghost", font = "tiny", height = 16 })
        end
      end
    else
      Layout.drawText("EMPTY SLOT", 92, 68, { font = "headline", color = theme.textMuted, bold = true })
      Layout.drawText("Select a slot to inspect Pokémon details", 92, 92, { font = "caption", color = theme.textDim, width = w - 104 })
    end
  end

  -- 2. Box & Party Workspace Panel
  Layout.drawCard(0, workspaceY, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

  -- Box Navigator Subheader
  local navY = workspaceY + 8
  local navH = 34
  Layout.drawSlot(8, navY, leftW - 16, navH, {
    color = (ctrl.zone == "header") and theme.accentDark or theme.surfaceHigh,
    borderColor = (ctrl.zone == "header") and theme.borderStrong or theme.border,
    borderWidth = (ctrl.zone == "header") and 2 or 1,
    radius = 6,
  })
  Layout.drawText("◀", 18, navY + 7, { font = "body", color = theme.colors.accent, bold = true })
  Layout.drawText("▶", leftW - 32, navY + 7, { font = "body", color = theme.colors.accent, bold = true })

  -- Grid and Party Dimensions
  local gridY = navY + navH + 8
  local cols = 6
  local rows = math.ceil(capacity / cols)
  local cellW = math.floor((leftW - 32 - (cols - 1) * 5) / cols)
  local drawerH = isNarrow and 60 or 68
  local drawerY = bodyH + workspaceY - drawerH - 8
  local gridAreaH = drawerY - gridY - 8
  local cellH = math.floor((gridAreaH - (rows - 1) * 5) / rows)
  local pCellW = math.floor((leftW - 32 - 5 * 5) / 6)
  local pCellH = isNarrow and 40 or 44

  local isMoving = (ctrl.mode == "grabbed" and ctrl.grabbed ~= nil)
  local grabbed = ctrl.grabbed

  -- Helper for computing slot bounds
  local function getSlotBounds(zone, slot)
    if zone == "box" then
      local r = math.floor((slot - 1) / cols)
      local c = (slot - 1) % cols
      local cx = 16 + c * (cellW + 5)
      local cy = gridY + r * (cellH + 5)
      return cx, cy, cellW, cellH
    elseif zone == "party" then
      local px = 16 + (slot - 1) * (pCellW + 5)
      local py = drawerY + (isNarrow and 16 or 20)
      return px, py, pCellW, pCellH
    elseif zone == "header" then
      local col = ((ctrl.boxSlot or 1) - 1) % cols
      local hx = 16 + col * (cellW + 5)
      local hy = navY + math.floor((navH - cellH) / 2)
      return hx, hy, cellW, cellH
    end
    return 16, gridY, cellW, cellH
  end

  -- Check box transition animation state
  local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
  local trans = ctrl.boxTransition
  if trans and not Layout.animationsEnabled() then
    ctrl.boxTransition = nil
    trans = nil
  end
  local isTrans = false
  local p = 1.0
  local t = 1.0
  if trans then
    local elapsed = now - (trans.startTime or now)
    p = math.min(1.0, math.max(0.0, elapsed / (trans.duration or 0.22)))
    if p >= 1.0 then
      ctrl.boxTransition = nil
    else
      isTrans = true
      t = p * p * (3 - 2 * p)
    end
  end

  -- Subheader title rendering (with smooth sliding transition if cycling)
  local titleY = navY + 7
  local titleCenterX = math.floor(leftW / 2)
  if isTrans then
    local titleOffset = 30
    local fromTX = (trans.dir > 0) and (titleCenterX - titleOffset * t) or (titleCenterX + titleOffset * t)
    local toTX = (trans.dir > 0) and (titleCenterX + titleOffset * (1 - t)) or (titleCenterX - titleOffset * (1 - t))
    local fromAlpha = math.max(0, 1.0 - t)
    local toAlpha = math.max(0, t)
    Layout.drawText(trans.fromName:upper(), fromTX - 30, titleY, { font = "button", color = { theme.heading[1], theme.heading[2], theme.heading[3], fromAlpha }, bold = true })
    Layout.drawText(trans.toName:upper(), toTX - 30, titleY, { font = "button", color = { theme.heading[1], theme.heading[2], theme.heading[3], toAlpha }, bold = true })
  else
    Layout.drawText(curBoxName:upper(), titleCenterX - 30, titleY, { font = "button", color = theme.heading, bold = true })
  end

  -- Reusable function to draw a single 6-column box grid
  local function drawBoxGrid(bId, bMons, offsetX, opacity)
    opacity = opacity or 1.0
    love.graphics.push()
    love.graphics.translate(offsetX, 0)
    for slot = 1, capacity do
      local cx, cy, cw, ch = getSlotBounds("box", slot)
      local isCursor = (ctrl.zone == "box" and ctrl.boxSlot == slot and bId == curBoxId)
      local mon = bMons[slot]

      -- Check if this slot is the origin of the currently grabbed mon
      local isOrigin = isMoving and grabbed and (grabbed.sourceLoc == "box") and (grabbed.sourceBox == bId) and (grabbed.sourceSlot == slot)

      if isOrigin then
        Layout.drawSlot(cx, cy, cw, ch, {
          color = { 0.15, 0.15, 0.20, 0.35 * opacity },
          borderColor = { theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], (theme.colors.accent[4] or 1) * opacity },
          borderWidth = 1,
          radius = 6,
        })
        Layout.drawText("ORIGIN", cx + 2, cy + ch - 12, { font = "tiny", color = { theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], (theme.colors.accent[4] or 1) * opacity } })
      elseif isCursor then
        Layout.drawCard(cx, cy, cw, ch, {
          color = { theme.accentDark[1], theme.accentDark[2], theme.accentDark[3], (theme.accentDark[4] or 1) * opacity },
          borderColor = isMoving and (mon and theme.hpYellow or theme.hpGreen) or theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
        if isMoving then
          local tip = mon and "⇄" or "↓"
          Layout.drawBadge(cx + 2, cy + 2, tip, { kind = mon and "team" or "good", font = "tiny" })
        end
      else
        Layout.drawSlot(cx, cy, cw, ch, {
          color = mon and theme.surfaceHigh or theme.surface,
          borderColor = { theme.border[1], theme.border[2], theme.border[3], (theme.border[4] or 1) * opacity },
          borderWidth = 1,
          radius = 6,
        })
      end

      -- Render mon icon in slot
      if mon and not isOrigin then
        local isEgg = mon.isEgg
        local species = isEgg and "EGG" or (mon.speciesId or mon.species or mon.displayName)
        drawMonSprite(game, species, cx + 2, cy + 1, cw - 4, ch - 14, opacity, mon.isShiny)
        if isEgg then
          Layout.drawText("EGG", cx + 3, cy + ch - 13, { font = "tiny", color = isCursor and theme.heading or theme.colors.accent, bold = true })
        else
          local lvlStr = ("L%d"):format(mon.level or 1)
          Layout.drawText(lvlStr, cx + 3, cy + ch - 13, { font = "tiny", color = isCursor and theme.heading or theme.textDim, bold = true })
          if mon.isShiny then
            Layout.drawText("★", cx + cw - 11, cy + 2, { font = "tiny", color = theme.hpYellow, bold = true })
          end
          if mon.isMail then
            Layout.drawText("✉", cx + cw - 20, cy + 2, { font = "tiny", color = theme.hpYellow, bold = true })
          end
        end
      end
    end
    love.graphics.pop()
  end

  -- Grid rendering with sliding transition
  local gridClipH = drawerY - gridY - 4
  local canStencil = love and love.graphics and love.graphics.stencil and love.graphics.setStencilTest
  if isTrans then
    local slideW = leftW - 20
    local fromX = (trans.dir > 0) and (-slideW * t) or (slideW * t)
    local toX = (trans.dir > 0) and (slideW * (1 - t)) or (-slideW * (1 - t))
    if canStencil then
      love.graphics.stencil(function()
        love.graphics.rectangle("fill", 8, gridY - 4, leftW - 16, gridClipH)
      end, "replace", 1)
      love.graphics.setStencilTest("greater", 0)
    end
    drawBoxGrid(trans.fromBoxId, trans.fromMons, fromX, 1.0 - t * 0.7)
    drawBoxGrid(trans.toBoxId, trans.toMons, toX, 0.3 + t * 0.7)
    if canStencil then
      love.graphics.setStencilTest()
    end
  else
    drawBoxGrid(curBoxId, boxMons, 0, 1.0)
  end

  -- Docked Party Drawer
  Layout.drawCard(8, drawerY, leftW - 16, drawerH, {
    color = theme.surfaceHigh,
    borderColor = (ctrl.zone == "party") and theme.borderStrong or theme.border,
    borderWidth = (ctrl.zone == "party") and 2 or 1,
    radius = 8,
  })
  Layout.drawText("PARTY", 16, drawerY + 3, { font = "caption", color = theme.colors.accent, bold = true })

  for pSlot = 1, 6 do
    local px, py, pw, ph = getSlotBounds("party", pSlot)
    local isPCur = (ctrl.zone == "party" and ctrl.partySlot == pSlot)
    local pMon = partyMons[pSlot]

    local isOrigin = isMoving and grabbed and (grabbed.sourceLoc == "party") and (grabbed.sourceSlot == pSlot)

    if isOrigin then
      Layout.drawSlot(px, py, pw, ph, {
        color = { 0.15, 0.15, 0.20, 0.35 },
        borderColor = theme.colors.accent,
        borderWidth = 1,
        radius = 6,
      })
      Layout.drawText("ORIGIN", px + 2, py + ph - 12, { font = "tiny", color = theme.colors.accent })
    elseif isPCur then
      Layout.drawCard(px, py, pw, ph, {
        color = theme.accentDark,
        borderColor = isMoving and (pMon and theme.hpYellow or theme.hpGreen) or theme.borderStrong,
        borderWidth = 2,
        radius = 6,
      })
      if isMoving then
        local tip = pMon and "⇄" or "↓"
        Layout.drawBadge(px + 2, py + 2, tip, { kind = pMon and "team" or "good", font = "tiny" })
      end
    else
      Layout.drawSlot(px, py, pw, ph, {
        color = pMon and theme.surface or theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 6,
      })
    end

    if pMon and not isOrigin then
      local species = pMon.speciesId or pMon.species or pMon.displayName
      drawMonSprite(game, species, px + 2, py + 1, pw - 4, ph - 10)
      local hpR = pMon.maxHp > 0 and math.max(0, math.min(1, pMon.currentHp / pMon.maxHp)) or 0
      local barC = (hpR > 0.5) and theme.hpGreen or ((hpR > 0.2) and theme.hpYellow or theme.hpRed)
      love.graphics.setColor(0, 0, 0, 0.4)
      love.graphics.rectangle("fill", px + 3, py + ph - 5, pw - 6, 3, 2, 2)
      love.graphics.setColor(barC)
      love.graphics.rectangle("fill", px + 3, py + ph - 5, math.floor((pw - 6) * hpR), 3, 2, 2)
    end
  end

  -- Elevated Moving / Grabbed Pokémon Card
  if isMoving and grabbed and grabbed.mon then
    local targetX, targetY, targetW, targetH = getSlotBounds(ctrl.zone, (ctrl.zone == "party") and ctrl.partySlot or ctrl.boxSlot)

    local dt = (love and love.timer and love.timer.getDelta and love.timer.getDelta()) or 0.016
    local curTime = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    local animateGrab = Layout.animationsEnabled()
    if not animateGrab then
      grabbed.animX = targetX
      grabbed.animY = targetY
      grabbed.animW = targetW
      grabbed.animH = targetH
      grabbed.elevation = 0
    else
      if not grabbed.animX then
        local ox, oy = getSlotBounds(grabbed.sourceLoc, grabbed.sourceSlot)
        grabbed.animX = ox
        grabbed.animY = oy
        grabbed.animW = targetW
        grabbed.animH = targetH
        grabbed.elevation = 0.0
      end

      local lerpFactor = math.min(1.0, dt * 22)
      grabbed.animX = grabbed.animX + (targetX - grabbed.animX) * lerpFactor
      grabbed.animY = grabbed.animY + (targetY - grabbed.animY) * lerpFactor
      grabbed.animW = grabbed.animW + (targetW - grabbed.animW) * lerpFactor
      grabbed.animH = grabbed.animH + (targetH - grabbed.animH) * lerpFactor
      grabbed.elevation = math.min(1.0, (grabbed.elevation or 0) + (dt / 0.12))
    end

    local popScale = 1.0 + 0.12 * (grabbed.elevation or 0)
    local liftOffset = -10 * (grabbed.elevation or 0)
    local floatBob = animateGrab and (math.sin(curTime * 5.0) * 3.0) or 0

    local drawX = grabbed.animX
    local drawY = grabbed.animY + liftOffset + floatBob
    local drawW = grabbed.animW
    local drawH = grabbed.animH

    love.graphics.setColor(0, 0, 0, 0.45 * grabbed.elevation)
    love.graphics.rectangle("fill", drawX + 4, grabbed.animY + drawH - 2, drawW - 8, 8, 4, 4)

    love.graphics.push()
    love.graphics.translate(drawX + drawW / 2, drawY + drawH / 2)
    love.graphics.scale(popScale, popScale)
    love.graphics.translate(-drawW / 2, -drawH / 2)

    Layout.drawCard(0, 0, drawW, drawH, {
      color = theme.accentDark,
      borderColor = theme.colors.accent,
      borderWidth = 2,
      radius = 8,
    })

    local gMon = grabbed.mon
    local gSpecies = gMon.speciesId or gMon.species or gMon.displayName
    drawMonSprite(game, gSpecies, 4, 2, drawW - 8, drawH - 16)

    local lvlStr = ("L%d"):format(gMon.level or 1)
    Layout.drawText(lvlStr, 4, drawH - 14, { font = "tiny", color = theme.heading, bold = true })

    love.graphics.pop()
  end

  -- 3. Right Inspector & Live Data Card (Landscape only)
  if not isNarrow then
    Layout.drawCard(rightX, 52, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local selMon, selLoc = ctrl:getCurrentSelection()
    if selMon then
      local portH = 124
      Layout.drawSlot(rightX + 16, 66, rightW - 32, portH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
      local isEgg = selMon.isEgg
      local selSpecies = isEgg and "EGG" or (selMon.speciesId or selMon.species or selMon.displayName)
      drawMonSprite(game, selSpecies, rightX + 16, 66, rightW - 32, portH, 1.0, selMon.isShiny)

      local infoY = 66 + portH + 8

      if isEgg then
        Layout.drawText("POKÉMON EGG", rightX + 18, infoY, { font = "title", color = theme.heading, bold = true })
        Layout.drawBadge(rightX + rightW - 74, infoY + 2, "EGG", { kind = "team", font = "tiny" })

        local descSlotH = bodyH - (portH + 8) - 40
        Layout.drawSlot(rightX + 16, infoY + 32, rightW - 32, descSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawTextWrapped(selMon.eggFlavorText or "An odd Pokémon EGG found at the Day-Care. It looks like it will take a long time to hatch.", rightX + 26, infoY + 44, rightW - 52, { font = "body", color = theme.text })
        Layout.drawText("ORIGIN: " .. (selMon.otName or "DAY-CARE"), rightX + 26, infoY + descSlotH - 12, { font = "tiny", color = theme.textDim, bold = true })
      else
        local nameStr = (selMon.isShiny and "★ " or "") .. (selMon.nickname or selMon.displayName or selSpecies)
        Layout.drawText(nameStr, rightX + 18, infoY, { font = "title", color = theme.heading, bold = true, width = rightW - 130 })

        local badgeX = rightX + rightW - 90
        Layout.drawBadge(badgeX, infoY + 2, ("LV %d"):format(selMon.level or 1), { kind = "team", font = "tiny" })
        if selMon.gender == "MALE" or selMon.gender == "M" then
          Layout.drawText("♂", badgeX - 16, infoY + 4, { font = "tiny", color = { 0.35, 0.65, 1.0, 1.0 }, bold = true })
        elseif selMon.gender == "FEMALE" or selMon.gender == "F" then
          Layout.drawText("♀", badgeX - 16, infoY + 4, { font = "tiny", color = { 1.0, 0.45, 0.55, 1.0 }, bold = true })
        end

        if selMon.pokerus == "infected" then
          Layout.drawBadge(badgeX - 60, infoY + 2, "PKRS", { kind = "team", font = "tiny" })
        elseif selMon.pokerus == "cured" then
          Layout.drawBadge(badgeX - 60, infoY + 2, "•PKRS•", { kind = "ghost", font = "tiny" })
        end

        local uniqueTypes = Widgets.getUniqueTypes(selMon.types or { "NORMAL" })
        local tyX = rightX + 18
        for _, t in ipairs(uniqueTypes) do
          local bw = Widgets.drawTypeBadge(t, tyX, infoY + 24)
          tyX = tyX + bw + 6
        end

        local hasHeldItem = selMon.heldItem ~= nil
        local hasAbility = selMon.ability ~= nil
        local hasNature = selMon.nature ~= nil
        local hasForm = selMon.form ~= nil

        local currentY = infoY + 48

        if hasHeldItem or hasAbility or hasNature or hasForm or selMon.isMail then
          local metaSlotH = 30
          Layout.drawSlot(rightX + 16, currentY, rightW - 32, metaSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
          local mx = rightX + 22
          if selMon.isMail then
            local itemDef = game.data and game.data.items and game.data.items[selMon.heldItem]
            local iName = itemDef and itemDef.name or tostring(selMon.heldItem)
            Layout.drawText("✉ MAIL: " .. iName, mx, currentY + 7, { font = "tiny", color = theme.hpYellow, bold = true })
            mx = mx + Layout.textWidth("✉ MAIL: " .. iName, "tiny") + 14
          elseif hasHeldItem then
            local itemDef = game.data and game.data.items and game.data.items[selMon.heldItem]
            local iName = itemDef and itemDef.name or tostring(selMon.heldItem)
            Layout.drawText("ITEM: " .. iName, mx, currentY + 7, { font = "tiny", color = theme.heading, bold = true })
            mx = mx + Layout.textWidth("ITEM: " .. iName, "tiny") + 14
          end
          if hasForm then
            Layout.drawText("FORM: " .. tostring(selMon.form):upper(), mx, currentY + 7, { font = "tiny", color = theme.colors.accent, bold = true })
            mx = mx + Layout.textWidth("FORM: " .. tostring(selMon.form):upper(), "tiny") + 14
          end
          if hasAbility then
            Layout.drawText("AB: " .. tostring(selMon.ability):upper(), mx, currentY + 7, { font = "tiny", color = theme.textDim })
          end
          currentY = currentY + metaSlotH + 8
        end

        local moveLineH = 18
        local moveSlotH = 4 * moveLineH + 12
        local moveSlotY = bodyH + 52 - moveSlotH - 10

        local statSlotH = math.max(64, moveSlotY - currentY - 8)
        Layout.drawSlot(rightX + 16, currentY, rightW - 32, statSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        local st = StatResolver.getStats(selMon, selMon.def, game)
        local statItems = {
          { label = "HP", val = st.maxHp, max = 255 },
          { label = "ATK", val = st.attack, max = 200 },
          { label = "DEF", val = st.defense, max = 200 },
          { label = "SPD", val = st.speed, max = 200 },
          { label = "SP.A", val = st.isSplit and st.spAttack or st.special or 1, max = 200 },
          { label = "SP.D", val = st.isSplit and st.spDefense or st.special or 1, max = 200 },
        }

        local barW = math.floor((rightW - 140) / 2)
        local statRowH = math.max(16, math.min(22, math.floor((statSlotH - 12) / 3)))
        for i, s in ipairs(statItems) do
          local col = (i <= 3) and 0 or 1
          local row = (i - 1) % 3
          local sx = rightX + 24 + col * (barW + 70)
          local sy = currentY + 6 + row * statRowH

          Layout.drawText(s.label, sx, sy, { font = "tiny", color = theme.textDim, bold = true })
          Layout.drawText(tostring(s.val), sx + 34, sy, { font = "tiny", color = theme.heading, bold = true, align = "right", width = 28 })

          local ratio = math.max(0, math.min(1, s.val / s.max))
          love.graphics.setColor(0, 0, 0, 0.4)
          love.graphics.rectangle("fill", sx + 68, sy + 3, barW - 60, 6, 2, 2)
          love.graphics.setColor(theme.colors.accent)
          love.graphics.rectangle("fill", sx + 68, sy + 3, math.floor((barW - 60) * ratio), 6, 2, 2)
        end

        Layout.drawSlot(rightX + 16, moveSlotY, rightW - 32, moveSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        local moves = selMon.moves or {}
        for m = 1, 4 do
          local mv = moves[m]
          local my = moveSlotY + 6 + (m - 1) * moveLineH
          if mv then
            local mvId = mv.id or mv
            local mvDef = game.data and game.data.moves and game.data.moves[mvId]
            local mvName = mvDef and mvDef.name or tostring(mvId)
            local ppStr = ("%d/%d"):format(mv.pp or mvDef and mvDef.pp or 10, mv.maxPP or mvDef and mvDef.pp or 10)
            Layout.drawText(mvName, rightX + 26, my, { font = "tiny", color = theme.heading, bold = true })
            Layout.drawText(ppStr, rightX + rightW - 74, my, { font = "tiny", color = theme.textDim })
          else
            Layout.drawText("-", rightX + 26, my, { font = "tiny", color = theme.textMuted })
          end
        end
      end
    else
      Layout.drawText("EMPTY SLOT", rightX + 24, 70, { font = "title", color = theme.textMuted })
      Layout.drawText("Select a Pokémon from the box grid or party drawer to inspect details, move, or withdraw.", rightX + 24, 100, { font = "body", color = theme.textDim, width = rightW - 48 })
    end
  end

  -- Action Context Menu Modal
  if ctrl.mode == "action_menu" then
    local actions = ctrl:getAvailableActions()
    local popW = math.min(w - 24, 220)
    local popH = #actions * 38 + 24
    local px = math.floor((w - popW) / 2)
    local py = math.floor((h - popH) / 2)
    Layout.drawCard(px, py, popW, popH, { color = theme.surface, borderColor = theme.borderStrong, borderWidth = 2, radius = 8 })
    Layout.drawText("CHOOSE ACTION", px + 16, py + 10, { font = "caption", color = theme.colors.accent, bold = true })

    for i, act in ipairs(actions) do
      local isSel = (ctrl.actionCursor == i)
      local ay = py + 28 + (i - 1) * 38
      if isSel then
        Layout.drawCard(px + 8, ay, popW - 16, 32, { color = act.danger and theme.hpRed or theme.accentDark, borderColor = theme.borderStrong, borderWidth = 1, radius = 6 })
        Layout.drawText(act.label, px + 18, ay + 7, { font = "button", color = theme.heading, bold = true })
      else
        Layout.drawSlot(px + 8, ay, popW - 16, 32, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText(act.label, px + 18, ay + 7, { font = "button", color = act.danger and theme.hpRed or theme.text })
      end
    end
  end

  -- Safety Release Confirmation Modal
  if ctrl.mode == "confirm_release" then
    local relW = math.min(w - 24, 360)
    local relH = 190
    local rx = math.floor((w - relW) / 2)
    local ry = math.floor((h - relH) / 2)
    Layout.drawCard(rx, ry, relW, relH, { color = theme.surface, borderColor = theme.hpRed, borderWidth = 2, radius = 8 })
    Layout.drawText("RELEASE POKÉMON", rx + 18, ry + 16, { font = "headline", color = theme.hpRed, bold = true })

    local selMon = ctrl:getCurrentSelection()
    local monName = selMon and (selMon.nickname or selMon.displayName) or "POKÉMON"
    Layout.drawTextWrapped(("Once released, %s will be gone forever. Are you absolutely sure?"):format(monName), rx + 18, ry + 46, relW - 36, { font = "body", color = theme.text })

    local btnW = math.floor((relW - 48) / 2)
    local choices = { "YES, RELEASE", "CANCEL" }
    for c = 1, 2 do
      local isSel = (ctrl.releaseChoice == c)
      local bx = rx + 16 + (c - 1) * (btnW + 16)
      local by = ry + 134
      if isSel then
        Layout.drawCard(bx, by, btnW, 36, { color = (c == 1) and theme.hpRed or theme.accentDark, borderColor = theme.borderStrong, borderWidth = 2, radius = 6 })
        Layout.drawText(choices[c], bx + 8, by + 9, { font = "button", color = theme.heading, bold = true, align = "center", width = btnW - 16 })
      else
        Layout.drawSlot(bx, by, btnW, 36, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText(choices[c], bx + 8, by + 9, { font = "button", color = theme.text, align = "center", width = btnW - 16 })
      end
    end
  end

  -- Box Switcher Carousel Modal
  if ctrl.mode == "switch_box" then
    local swW = math.min(w - 24, 480)
    local swH = math.min(h - 40, 320)
    local sx = math.floor((w - swW) / 2)
    local sy = math.floor((h - swH) / 2)
    Layout.drawCard(sx, sy, swW, swH, { color = theme.surface, borderColor = theme.borderStrong, borderWidth = 2, radius = 8 })
    Layout.drawText("SWITCH ACTIVE BOX", sx + 18, sy + 16, { font = "headline", color = theme.heading, bold = true })

    local bCols = (swW < 360) and 2 or (swW < 440 and 3 or 4)
    local bCellW = math.floor((swW - 36 - (bCols - 1) * 6) / bCols)
    local bCellH = 46
    for b = 1, boxCount do
      local col = (b - 1) % bCols
      local row = math.floor((b - 1) / bCols)
      local bx = sx + 18 + col * (bCellW + 6)
      local by = sy + 50 + row * (bCellH + 6)
      local isSel = (ctrl.boxMenuCursor == b)
      local bName = adapter:getBoxName(b)
      local bData = adapter:getBoxData(b)
      local bOcc = 0
      for s = 1, capacity do
        if bData[s] then bOcc = bOcc + 1 end
      end

      if isSel then
        Layout.drawCard(bx, by, bCellW, bCellH, { color = theme.accentDark, borderColor = theme.borderStrong, borderWidth = 2, radius = 6 })
        Layout.drawText(bName, bx + 8, by + 8, { font = "caption", color = theme.heading, bold = true })
        Layout.drawBadge(bx + bCellW - 50, by + 8, ("%d/%d"):format(bOcc, capacity), { kind = "good", font = "tiny" })
      else
        Layout.drawSlot(bx, by, bCellW, bCellH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText(bName, bx + 8, by + 8, { font = "caption", color = theme.text })
        Layout.drawBadge(bx + bCellW - 50, by + 8, ("%d/%d"):format(bOcc, capacity), { kind = "ghost", font = "tiny" })
      end
    end
  end

  -- Message Toast / Alert Banner
  if ctrl.message then
    local msgW = math.min(w - 24, 380)
    local msgH = 64
    local mx = math.floor((w - msgW) / 2)
    local my = math.floor((h - msgH) / 2)
    Layout.drawCard(mx, my, msgW, msgH, { color = theme.surface, borderColor = theme.borderStrong, borderWidth = 2, radius = 8 })
    Layout.drawText(tostring(ctrl.message), mx + 16, my + 14, { font = "body", color = theme.heading, bold = true })
    Layout.drawText("Press A to dismiss", mx + 16, my + 38, { font = "tiny", color = theme.colors.accent })
  end

  -- 4. Bottom Footer Hint Bar
  local function getGen()
    local ver = game and (game.gameVersion or (game.cart and game.cart.gameVersion) or (game.save and game.save.gameVersion))
    if ver then
      ver = tostring(ver):lower()
      if ver == "firered" or ver == "leafgreen" or ver == "emerald" or ver == "ruby" or ver == "sapphire" then return 3 end
      if ver == "gold" or ver == "silver" or ver == "crystal" then return 2 end
      if ver == "red" or ver == "blue" or ver == "yellow" then return 1 end
    end
    local saveGen = game and game.save and game.save.generation
    if saveGen then return saveGen end
    if package.loaded["src.battle.game3"] ~= nil or package.loaded["src.world.game3"] ~= nil then return 3 end
    if package.loaded["src.battle.gen2"] ~= nil or package.loaded["src.world.gen2"] ~= nil then return 2 end
    return 1
  end

  local hints = {
    { key = "A", label = (ctrl.mode == "grabbed") and "Drop/Swap" or "Select", primary = true },
  }
  if getGen() >= 3 then
    table.insert(hints, { key = "L R", label = "Flip" })
  end
  table.insert(hints, { key = "B", label = (ctrl.mode == "grabbed") and "Cancel" or "Log Off" })
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return StorageRenderer
