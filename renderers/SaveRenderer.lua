-- OmniUI Save Menu Renderer
-- Floating modal dialog for saving adventure progress with high contrast launcher Yes/No controls.

local Layout = require("mods.omni_ui.core.Layout")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local SaveRenderer = {}

function SaveRenderer.draw(game, state, vw, vh, theme, subState, hasStartMenu)
  local adapter = AdapterResolver.resolve(game)
  local info = adapter:getPlayerInfo()

  -- Locate ChoiceBox or TextBox on the stack
  local activeChoice = nil
  local activeTextBox = nil
  if game and game.stack and game.stack.states then
    for i = #game.stack.states, 1, -1 do
      local s = game.stack.states[i]
      if s.isTextBox or s.pages or s.shown then
        if not activeTextBox then activeTextBox = s end
      end
      if s.labels or s.onChoose or (s.index and s.pending ~= nil) or s.isChoiceBox then
        if not activeChoice then activeChoice = s end
      end
    end
  end

  local cursor = 1
  if activeChoice and activeChoice.index then
    cursor = activeChoice.index
  elseif subState and subState.index and (subState.labels or subState.onChoose or subState.pending ~= nil or subState.isChoiceBox) then
    cursor = subState.index
  elseif subState and subState.choice then
    cursor = subState.choice
  elseif subState and subState.confirmChoice then
    cursor = subState.confirmChoice
  elseif state.cursor then
    cursor = state.cursor
  elseif state.choice then
    cursor = state.choice
  elseif state.confirmChoice then
    cursor = state.confirmChoice
  elseif state.index then
    cursor = state.index
  end

  -- Determine Save State Phase & message
  local phase = state._phase or state.phase or (subState and (subState._phase or subState.phase)) or "confirm"
  local subText = ""
  if activeTextBox then
    if activeTextBox.pages then
      for _, p in ipairs(activeTextBox.pages) do
        for _, l in ipairs(p) do
          subText = subText .. " " .. tostring(l or "")
        end
      end
    end
    if activeTextBox.text then
      subText = subText .. " " .. tostring(activeTextBox.text)
    end
    if activeTextBox.visibleText then
      local vt = activeTextBox:visibleText()
      if vt then subText = subText .. " " .. table.concat(vt, " ") end
    end
  end
  if subState and subState.text then
    subText = subText .. " " .. tostring(subState.text)
  end

  local isSaving = (phase == "saving") or subText:find("saving") or subText:find("SAVING") or subText:find("Now saving")
  local isSaved = (phase == "saved" or phase == "done") or subText:find("saved") or subText:find("SAVED")
  local isOverwrite = (phase == "overwrite") or subText:find("overwrite") or subText:find("OVERWRITE")

  local ctx = Layout.getContext(vw, vh)

  -- Floating Modal Card Dimensions & Position
  local isSideBySide = hasStartMenu and not ctx.isPortrait
  local modalW = ctx.isPortrait and math.min(vw - 24, 380) or (isSideBySide and math.min(520, vw - 330) or math.min(vw - (ctx.isCompact and 16 or 32), 480))
  local modalH = ctx.isUltraCompact and 250 or 280
  local mx = isSideBySide and 24 or math.floor((vw - modalW) / 2)
  local my = ctx.isPortrait and math.max(ctx.safeInsetTop or 48, math.floor(vh * 0.12)) or math.floor((vh - modalH) / 2)

  -- Outer Modal Card
  Layout.drawCard(mx, my, modalW, modalH, {
    color = theme.surface,
    borderColor = theme.borderStrong,
    borderWidth = 2,
    radius = 10,
  })

  -- Modal Header
  Layout.drawText("SAVE PROGRESS", mx + 20, my + 16, { font = "headline", color = theme.heading, bold = true })
  local locStr = tostring(info.location or "OVERWORLD"):upper()
  if modalW > 280 then
    local badgeX = mx + modalW - 16
    if info.rtc then
      local rtcStr = ("%s %02d:%02d"):format(info.rtc.timeOfDay or "DAY", info.rtc.hour or 0, info.rtc.minute or 0)
      local rtcW = Layout.textWidth(rtcStr, "tiny") + 24
      badgeX = badgeX - rtcW
      local rtcKind = (info.rtc.timeOfDay == "NITE") and "purple" or "gold"
      Layout.drawBadge(badgeX, my + 14, rtcStr, { kind = rtcKind, width = rtcW })
      badgeX = badgeX - 8
    end

    if badgeX > mx + 180 then
      local locBadgeW = math.min(140, Layout.textWidth(locStr, "tiny") + 24)
      Layout.drawBadge(badgeX - locBadgeW, my + 14, locStr, { kind = "ghost", width = locBadgeW })
    end
  end

  -- Save Details Hero Slot
  local slotY = my + 48
  local slotH = ctx.isUltraCompact and 110 or 126
  Layout.drawSlot(mx + 16, slotY, modalW - 32, slotH, {
    color = theme.surfaceHigh,
    borderColor = theme.border,
    borderWidth = 1,
    radius = 8,
  })

  -- Player Name & Trainer Info
  Layout.drawText(info.name, mx + 24, slotY + 12, { font = "headline", color = theme.heading, bold = true })
  if modalW > 260 then
    local rightTag = info.rtc and info.rtc.dayName or "ACTIVE SAVE"
    local tagW = Layout.textWidth(rightTag, "tiny") + 24
    Layout.drawBadge(mx + modalW - tagW - 24, slotY + 12, rightTag, { kind = "primary", width = tagW })
  end

  -- 3-Column Metrics (Badges, Played, Caught)
  local metricY = slotY + (ctx.isUltraCompact and 42 or 50)
  local metricW = math.floor((modalW - 48) / 3)
  Layout.drawStatMetric(mx + 24, metricY, metricW, ("%d / %d"):format(info.badges, info.maxBadges), "badges")
  Layout.drawStatMetric(mx + 24 + metricW, metricY, metricW, info.playTimeString, "played")
  Layout.drawStatMetric(mx + 24 + metricW * 2, metricY, metricW, tostring(info.pokedex.owned or 0), "caught")

  -- Bottom Prompt & Interaction Area
  local promptY = my + modalH - (ctx.isUltraCompact and 72 or 80)
  local promptH = ctx.isUltraCompact and 58 or 64
  Layout.drawSlot(mx + 16, promptY, modalW - 32, promptH, {
    color = theme.surfaceHigh,
    borderColor = isSaving and theme.accentHover or (isSaved and theme.hpGreen or theme.border),
    borderWidth = 1,
    radius = 8,
  })

  if isSaved then
    Layout.drawText("[OK] " .. info.name .. " saved the game!", mx + 24, promptY + 20, { font = "headline", color = theme.hpGreen, bold = true })
  elseif isSaving then
    Layout.drawText("Saving game data... Please do not power off.", mx + 24, promptY + 20, { font = "headline", color = theme.hpYellow, bold = true })
  else
    local promptText = isOverwrite and "Overwrite save file?" or "Would you like to SAVE?"
    local yesSel = (cursor == 1)

    if modalW < 360 then
      -- Stack prompt label and full-touch Yes/No buttons cleanly on compact / portrait screens
      Layout.drawText(promptText, mx + 24, promptY + 8, { font = "body", color = theme.heading, bold = true })
      local btnW = math.floor((modalW - 48 - 10) / 2)
      local btnH = 28
      local btnY = promptY + 28
      local yesX = mx + 24
      local noX = yesX + btnW + 10

      Layout.drawButton(yesX, btnY, btnW, btnH, "Yes", {
        kind = yesSel and "primary" or "ghost",
        selected = yesSel,
      })

      Layout.drawButton(noX, btnY, btnW, btnH, "No", {
        kind = (not yesSel) and "primary" or "ghost",
        selected = (not yesSel),
      })
    else
      local btnW = math.max(64, math.min(84, math.floor((modalW - 180) / 2)))
      local btnH = 34
      local btnY = promptY + math.floor((promptH - btnH) / 2)
      local noX = mx + modalW - 24 - btnW
      local yesX = noX - btnW - 10

      local maxPromptW = (yesX > mx + 24) and (yesX - mx - 32) or (modalW - 48)
      Layout.drawText(promptText, mx + 24, promptY + math.floor((promptH - 16) / 2), { font = "body", color = theme.heading, bold = true, width = maxPromptW })

      Layout.drawButton(yesX, btnY, btnW, btnH, "Yes", {
        kind = yesSel and "primary" or "ghost",
        selected = yesSel,
      })

      Layout.drawButton(noX, btnY, btnW, btnH, "No", {
        kind = (not yesSel) and "primary" or "ghost",
        selected = (not yesSel),
      })
    end
  end
end

return SaveRenderer
