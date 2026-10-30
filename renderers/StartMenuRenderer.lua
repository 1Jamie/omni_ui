-- OmniUI Start Menu / Pause Dock Renderer
-- High contrast launcher-styled floating pause menu dock with vector typography.

local Layout = require("mods.omni_ui.core.Layout")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local StartMenuRenderer = {}

function StartMenuRenderer.draw(game, state, vw, vh, theme, subState, animProgress, viewport)
  if type(animProgress) == "table" and not viewport then
    viewport = animProgress
    animProgress = 1.0
  end
  local adapter = AdapterResolver.resolve(game)
  local playerInfo = adapter:getPlayerInfo()
  local safariInfo = adapter:getSafariInfo()
  local bugInfo = adapter.getBugContestInfo and adapter:getBugContestInfo()

  local ctx = Layout.getContext(vw, vh)
  local isCompact = (vw < 560) or ctx.isCompact
  local isShort = (vh < 520)

  local dockConf = (theme.layout and theme.layout.dock) or {
    width = 290,
    align = "right",
    marginX = 24,
    marginY = 24,
    profileHeight = 68,
    itemHeight = 42,
    itemGap = 6,
    footerHeight = 36,
  }

  local dockW = isCompact and math.min(vw - 24, 290) or (dockConf.width or 290)
  local dockX
  if isCompact or dockConf.align == "center" then
    dockX = math.floor((vw - dockW) / 2)
  elseif dockConf.align == "left" then
    dockX = dockConf.marginX or 24
  else
    dockX = vw - dockW - (dockConf.marginX or 24)
  end
  local dockY = ctx.isPortrait and (ctx.safeInsetTop or 48) or (isShort and 12 or (dockConf.marginY or 24))

  local items = state.items or state.entries or state.ENTRIES or (state.list and state.list.items) or {}
  local curIdx = state.index or state.cursor or (state.list and state.list.index) or 1

  -- 1. Safari / Bug Contest Banner if active
  if safariInfo and safariInfo.active then
    local sH = isShort and 44 or 54
    Layout.drawCard(dockX, dockY, dockW, sH, {
      color = theme.surface,
      borderColor = theme.hpGreen,
      borderWidth = 2,
      radius = theme.metrics and theme.metrics.radius.card or 8,
    })
    Layout.drawText("SAFARI ZONE", dockX + 16, dockY + (isShort and 6 or 10), { font = "headline", color = theme.heading, bold = true })
    Layout.drawText(("STEPS: %d/%d"):format(safariInfo.steps, safariInfo.maxSteps), dockX + 16, dockY + (isShort and 24 or 30), { font = "tiny", color = theme.hpGreen, bold = true })
    Layout.drawText(("BALLS: %d"):format(safariInfo.balls), dockX + dockW - 90, dockY + (isShort and 24 or 30), { font = "tiny", color = theme.textDim })
    dockY = dockY + sH + 8
  elseif bugInfo and bugInfo.active then
    local bH = isShort and 44 or 54
    Layout.drawCard(dockX, dockY, dockW, bH, {
      color = theme.surface,
      borderColor = theme.hpYellow,
      borderWidth = 2,
      radius = theme.metrics and theme.metrics.radius.card or 8,
    })
    Layout.drawText("BUG-CATCHING CONTEST", dockX + 16, dockY + (isShort and 6 or 10), { font = "headline", color = theme.heading, bold = true })
    Layout.drawText(("PARK BALLS: %d"):format(bugInfo.balls or 0), dockX + 16, dockY + (isShort and 24 or 30), { font = "tiny", color = theme.hpYellow, bold = true })
    dockY = dockY + bH + 8
  end

  -- 2. Player Profile Banner at Top of Dock
  local profileH = isShort and 52 or (dockConf.profileHeight or 68)
  Layout.drawCard(dockX, dockY, dockW, profileH, {
    color = theme.surface,
    borderColor = theme.border,
    borderWidth = 1,
    radius = theme.metrics and theme.metrics.radius.card or 8,
  })

  local money = playerInfo.money or 0
  local moneyStr = ("¥%d"):format(money)

  if isShort then
    local timeW = Layout.textWidth(playerInfo.playTimeString, "caption")
    Layout.drawText(playerInfo.name, dockX + 14, dockY + 8, { font = "headline", color = theme.heading, bold = true })
    Layout.drawText(playerInfo.playTimeString, dockX + dockW - timeW - 14, dockY + 10, { font = "caption", color = theme.textDim })

    Layout.drawBadge(dockX + 14, dockY + 28, ("%d / %d BADGES"):format(playerInfo.badges, playerInfo.maxBadges), { kind = "team", font = "tiny", height = 18 })
    local moneyW = Layout.textWidth(moneyStr, "tiny") + 16
    Layout.drawBadge(dockX + dockW - moneyW - 14, dockY + 28, moneyStr, { kind = "good", font = "tiny", height = 18, width = moneyW })
  else
    local timeW = Layout.textWidth(playerInfo.playTimeString, "caption")
    Layout.drawText(playerInfo.name, dockX + 18, dockY + 14, { font = "headline", color = theme.heading, bold = true })
    Layout.drawText(playerInfo.playTimeString, dockX + dockW - timeW - 18, dockY + 16, { font = "caption", color = theme.textDim })

    Layout.drawBadge(dockX + 18, dockY + 38, ("%d / %d BADGES"):format(playerInfo.badges, playerInfo.maxBadges), { kind = "team", font = "tiny" })
    local moneyW = Layout.textWidth(moneyStr, "caption") + 20
    Layout.drawBadge(dockX + dockW - moneyW - 18, dockY + 38, moneyStr, { kind = "good", font = "caption", height = 22, width = moneyW })
  end

  -- 3. Dynamic Height Clamping & Vertical Scrolling for Action Items List
  local listY = dockY + profileH + 8
  local footerH = isShort and 30 or (dockConf.footerHeight or 36)
  local bottomMargin = isShort and 10 or 16
  local maxListH = math.max(80, vh - listY - footerH - bottomMargin)

  local itemH = isShort and 36 or (dockConf.itemHeight or 42)
  local itemGap = isShort and 4 or (dockConf.itemGap or 6)
  local itemStride = itemH + itemGap
  local neededListH = #items * itemStride + 14

  local isScrollable = (neededListH > maxListH)
  local visibleCount = #items
  local listH = neededListH

  if isScrollable then
    visibleCount = math.max(2, math.floor((maxListH - 14) / itemStride))
    visibleCount = math.min(#items, visibleCount)
    listH = visibleCount * itemStride + 14
  end

  local scroll = state.scroll or state._scroll or 1
  if curIdx < scroll then
    scroll = curIdx
  elseif curIdx >= scroll + visibleCount then
    scroll = curIdx - visibleCount + 1
  end
  scroll = math.max(1, math.min(math.max(1, #items - visibleCount + 1), scroll))
  state.scroll = scroll

  Layout.drawCard(dockX, listY, dockW, listH, {
    color = theme.surface,
    borderColor = theme.border,
    borderWidth = 1,
    radius = theme.metrics and theme.metrics.radius.card or 8,
  })

  local btnW = isScrollable and (dockW - 24) or (dockW - 16)

  for vi = 1, visibleCount do
    local i = scroll + vi - 1
    local it = items[i]
    if it then
      local isSel = (curIdx == i)
      local rawName = Layout.cleanText(tostring(it.label or it.name or it.text or it):upper())
      local displayLabel = Layout.cleanText(it.label or it.name or it.text or rawName)
      local iy = listY + 7 + (vi - 1) * itemStride

      -- Staggered ripple cascade for start menu rows (18ms delay per row, 14px slide)
      local offsetX = Layout.getCascadeOffset(vi, animProgress, 0.018, 14)

      love.graphics.push()
      if offsetX ~= 0 then
        love.graphics.translate(offsetX, 0)
      end

      local btnKind = (type(it) == "table" and it.kind) or (isSel and "primary" or "ghost")
      Layout.drawButton(dockX + 8, iy, btnW, itemH, displayLabel, {
        selected = isSel,
        align = "left",
        padX = isShort and 12 or 18,
        font = "button",
        kind = btnKind,
      })

      -- Optional Mod-Supplied Status Badge (e.g., Quest count, New notification tag)
      if type(it) == "table" and (it.badge or it.tag) then
        local badgeText = tostring(it.badge or it.tag)
        local bKind = it.badgeKind or (isSel and "good" or "ghost")
        local bw = Layout.textWidth(badgeText, "tiny") + 20
        Layout.drawBadge(dockX + 8 + btnW - bw - 6, iy + math.floor((itemH - 20) / 2), badgeText, {
          kind = bKind,
          font = "tiny",
          height = 20,
          width = bw,
        })
      end

      -- Optional Mod Custom Render Hook
      if type(it) == "table" and it.render and type(it.render) == "function" then
        local HookBoundary = require("mods.omni_ui.core.HookBoundary")
        HookBoundary.safeRender(it.id or ("start_item_" .. i), it.render, game, it, dockX + 8, iy, btnW, itemH, isSel, theme)
      end

      love.graphics.pop()
    end
  end

  if isScrollable then
    Layout.drawScrollBar(dockX + dockW - 12, listY + 7, 5, listH - 14, #items, visibleCount, scroll, {
      is1Indexed = true,
      radius = 3,
    })
  end

  -- 4. Bottom Button Hints Footer
  local footY = listY + listH + 8
  local hints = {
    { key = "A", label = "Select", primary = true },
    { key = "▲ ▼", label = "Move" },
    { key = "B", label = "Close" },
  }
  Layout.drawHintBar(dockX, footY, dockW, footerH, hints, {
    paddingX = 10,
    columns = { 0, math.floor(dockW * 0.35), math.floor(dockW * 0.70) },
  })

  -- 5. Modal Quit / Bug Contest Confirm Dialog
  if state.phase == "confirm" or state.phase == "confirmContest" or state._confirmExit then
    local mw = math.min(vw - 24, 340)
    local mh = 148
    local mx = math.floor((vw - mw) / 2)
    local my = math.floor((vh - mh) / 2)
    local confirmChoice = state._confirmCursor or state.confirmChoice or 2

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", -100, -100, vw + 200, vh + 200)

    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    local titleText = (state.phase == "confirmContest") and "End Bug Contest?" or "Return to Title Screen?"
    local descText = (state.phase == "confirmContest") and "Quit the contest and be judged?" or "Any unsaved progress will be lost."
    Layout.drawText(titleText, mx + 24, my + 18, { font = "headline", color = theme.heading, bold = true })
    Layout.drawText(descText, mx + 24, my + 48, { font = "body", color = theme.textDim })

    local btnW = math.floor((mw - 64) / 2)
    local btnH = 40
    local btnY = my + 88
    local yesX = mx + 24
    local noX = mx + 24 + btnW + 16

    Layout.drawButton(yesX, btnY, btnW, btnH, "Yes", {
      kind = (confirmChoice == 1) and "primary" or "ghost",
      selected = (confirmChoice == 1),
    })

    Layout.drawButton(noX, btnY, btnW, btnH, "No", {
      kind = (confirmChoice == 2) and "primary" or "ghost",
      selected = (confirmChoice == 2),
    })
  end
end

return StartMenuRenderer
