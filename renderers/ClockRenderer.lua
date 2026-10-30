-- OmniUI Modern Digital Timepiece & Calendar Setup Interface Renderer
-- Features modern digital clock styling, active digit blinking/steppers, AM/PM format, time-of-day indicator, and clean dialogue sequencing.
-- Fully responsive across compact, portrait, and mobile landscape viewports with adaptive layouts.

local Layout = require("mods.omni_ui.core.Layout")
local Clock = require("src.core.gen2.Clock")

local ClockRenderer = {}

function ClockRenderer.attachControls(state, game)
  if not state or state.__omniUiClockAttached then return end
  state.__omniUiClockAttached = true
  local baseUpdate = state.update
  state.update = function(self, dt)
    local input = (self.game and self.game.input) or (game and game.input)
    if input then
      if self.confirm then
        if input:wasPressed("left") or input:wasPressed("up") then
          self.confirm.cursor = 0
          local g = (self.game and self.game.data) or (game and game.data)
          if g then pcall(function() require("src.core.Sound").play(g, "Press_AB") end) end
        elseif input:wasPressed("right") or input:wasPressed("down") then
          self.confirm.cursor = 1
          local g = (self.game and self.game.data) or (game and game.data)
          if g then pcall(function() require("src.core.Sound").play(g, "Press_AB") end) end
        end
      elseif self.confirming and self:confirming() and not self:morePages() then
        if input:wasPressed("left") or input:wasPressed("right") then
          self.yesNo = (self.yesNo == 1) and 2 or 1
          if self.game and self.game.data then
            pcall(function() require("src.core.Sound").play(self.game.data, "Press_AB") end)
          end
          return
        end
      end
    end
    if baseUpdate then baseUpdate(self, dt) end
  end
end

function ClockRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  if not state then return end
  ClockRenderer.attachControls(state, game)

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local phase = state.phase or (state.t and ((state.state == "ask_confirm" or state.state == "confirm_input") and "confirm-minute" or "set-time")) or "intro"
  local isDayMode = (state.mode == "day" or phase == "day" or phase == "confirm-day")
  local hour = tonumber((state.t and state.t.hours) or state.hour or 10)
  local minute = tonumber((state.t and state.t.minutes) or state.minute or 0)
  local dayIdx = tonumber(state.day or 0) -- 0 to 6 (Sun to Sat)

  local isConfirming = (phase == "confirm-hour" or phase == "confirm-minute" or phase == "confirm-day" or (state.confirming and state:confirming()) or state.state == "ask_confirm" or state.state == "confirm_input" or state.confirm ~= nil)
  local yesNo = 1
  if state.confirm and state.confirm.cursor ~= nil then
    yesNo = state.confirm.cursor + 1
  elseif state.yesNo ~= nil then
    yesNo = state.yesNo
  end

  -- 1. Full-Screen Backdrop Dimming
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 0, 0, vw, vh)

  -- =========================================================================
  -- FLOW STAGE 1: INTRO SPEECH (Oak waking up - Clock is NOT visible yet)
  -- =========================================================================
  if phase == "intro" then
    local dConf = (theme.layout and theme.layout.dialogue) or {
      maxWidth = 720,
      height = 114,
      marginBottom = 24,
    }

    local dw = math.min(vw - (ctx.isCompact and 16 or 36), dConf.maxWidth or 720)
    local dh = (ctx.isUltraCompact) and 96 or (dConf.height or 118)
    local dx = math.floor((vw - dw) / 2)
    local marginBottom = (ctx.isUltraCompact) and 8 or (ctx.isCompact and 14 or (dConf.marginBottom or 24))
    local dy = ctx.isPortrait and math.min(vh - dh - 120, math.floor(vh * 0.48)) or (vh - dh - marginBottom)

    -- Dialogue Frame Card
    Layout.drawCard(dx, dy, dw, dh, {
      color = theme.colors.surfaceHigh or theme.surfaceHigh,
      borderColor = theme.colors.borderStrong or theme.borderStrong,
      borderWidth = 1.5,
      radius = theme.metrics and theme.metrics.radius.dialogue or 12,
    })

    -- Speaker Nameplate Badge
    local speakerName = state.speaker or "OAK"
    local npW = Layout.textWidth(speakerName, "tiny") + 20
    Layout.drawBadge(dx + 16, dy - 12, speakerName, {
      kind = "accent",
      font = "tiny",
      height = 22,
      width = npW,
      radius = 4,
    })

    -- Dialogue Text (Sanitized current page text without form feed tokens)
    local rawText = (state.pageText and state:pageText()) or (state.question and state:question()) or "Zzz... Hm? Wha...?\nYou woke me up!\nWill you check the clock for me?"
    local cleanSpeech = Layout.cleanText(rawText)

    Layout.drawText(cleanSpeech, dx + 18, dy + 18, {
      font = isCompact and "caption" or "body",
      color = theme.colors.heading,
      bold = true,
      lineSpacing = 1.3,
      width = dw - 36,
    })

    -- Bottom-right "A Next" indicator
    local nextPulse = 0.70 + 0.30 * math.sin((love.timer and love.timer.getTime() or os.clock()) * 4.5)
    love.graphics.setColor(1, 1, 1, nextPulse)
    local nextX = dx + dw - 76
    local nextY = dy + dh - 24
    Layout.drawBadge(nextX, nextY, "A NEXT", {
      kind = "primary",
      font = "tiny",
      height = 18,
      width = 62,
      radius = 3,
    })
    love.graphics.setColor(1, 1, 1, 1)
    return
  end

  -- =========================================================================
  -- FLOW STAGE 2: DIGITAL TIMEPIECE TERMINAL (Hours / Minutes / Day / Confirm)
  -- =========================================================================
  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 16)
  local cardW = math.min(540, math.max(280, vw - pad * 2))
  local cardH = math.min(vh - pad * 2, isCompact and 290 or 340)
  local cardX = math.floor((vw - cardW) / 2)
  local cardY = math.floor((vh - cardH) / 2)

  -- Master Card Frame
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = theme.colors.surface,
    borderColor = theme.colors.borderStrong,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or (isCompact and 10 or 14),
  })

  -- Header Bar
  local topY = cardY + pad
  local headerH = isCompact and 20 or 24
  local headerTitle = isDayMode and "CALENDAR SETUP" or "TIMEPIECE SETUP"
  Layout.drawBadge(cardX + pad, topY, headerTitle, {
    kind = "accent",
    font = "tiny",
    height = headerH,
    radius = 4,
  })

  -- Time of Day Chip
  local timeOfDay = Clock.daytimeLabel and Clock.daytimeLabel(hour) or (hour < 10 and "MORN" or (hour < 18 and "DAY" or "NITE"))
  local todKind = (timeOfDay:upper():find("MORN") and "warning") or (timeOfDay:upper():find("DAY") and "good" or "primary")
  local todW = Layout.textWidth(timeOfDay:upper(), "tiny") + 16
  Layout.drawBadge(cardX + cardW - pad - todW, topY, timeOfDay:upper(), {
    kind = todKind,
    font = "tiny",
    height = headerH,
    width = todW,
    radius = 4,
  })

  -- Central Digital Clock Display Panel
  local displayY = topY + headerH + (isCompact and 8 or 12)
  local displayW = cardW - pad * 2
  local qBoxH = isCompact and 72 or 84
  local displayH = cardH - (displayY - cardY) - qBoxH - pad - (isCompact and 8 or 12)

  Layout.drawCard(cardX + pad, displayY, displayW, displayH, {
    color = theme.colors.surfaceHigh,
    borderColor = theme.colors.accent,
    borderWidth = 1.5,
    radius = 8,
  })

  local now = (love.timer and love.timer.getTime()) or os.clock()
  local blinkCycle = (math.floor(now * 3.5) % 2 == 0)
  local smoothPulse = 0.55 + 0.45 * math.abs(math.sin(now * 5.0))

  if isDayMode then
    -- Calendar Weekday Mode
    local dayName = (Clock.weekdayName and Clock.weekdayName(dayIdx + 1)) or (Clock.DAY_NAMES and Clock.DAY_NAMES[dayIdx + 1]) or "SUNDAY"
    Layout.drawText("SELECT DAY OF THE WEEK", cardX + pad + 14, displayY + (isCompact and 6 or 10), {
      font = "tiny",
      color = theme.colors.textDim,
      bold = true,
    })

    -- Active Day Pill with Animated Steppers
    local pillX = cardX + pad + 14
    local pillY = displayY + (isCompact and 24 or 34)
    local pillW = displayW - 28
    local pillH = isCompact and 36 or 44

    Layout.drawCard(pillX, pillY, pillW, pillH, {
      color = { theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], 0.15 },
      borderColor = theme.colors.accent,
      borderWidth = 1.5,
      radius = 6,
    })

    Layout.drawText(tostring(dayName):upper(), pillX + 14, pillY + math.floor((pillH - (isCompact and 16 or 20)) / 2), {
      font = isCompact and "headline" or "title",
      color = theme.colors.heading,
      bold = true,
    })

    -- Animated Stepper Arrows
    Layout.drawText("▲", pillX + pillW - 28, pillY + 4, {
      font = "tiny",
      color = theme.colors.accent,
      bold = true,
    })
    Layout.drawText("▼", pillX + pillW - 28, pillY + pillH - 16, {
      font = "tiny",
      color = theme.colors.accent,
      bold = true,
    })

    -- Status Action Tag
    local adjStr = "SELECTING DAY • ▲ / ▼ CHANGE • A NEXT"
    local adjW = Layout.textWidth(adjStr, "tiny") + 16
    Layout.drawBadge(cardX + pad + displayW - adjW - 14, displayY + displayH - 24, adjStr, {
      kind = "primary",
      font = "tiny",
      height = 18,
      width = adjW,
      radius = 3,
    })
  else
    -- Digital Clock Mode (Hours : Minutes AM/PM)
    local displayHour = hour % 12
    if displayHour == 0 then displayHour = 12 end
    local ampm = (hour >= 12) and "PM" or "AM"

    local isHourActive = (phase == "hour")
    local isMinActive = (phase == "minute")

    Layout.drawText("DIGITAL 12-HOUR RTC SYNCHRONIZATION", cardX + pad + 14, displayY + (isCompact and 6 or 10), {
      font = "tiny",
      color = theme.colors.textDim,
      bold = true,
    })

    -- Layout Digit Segments
    local blockY = displayY + (isCompact and 24 or 34)
    local blockH = isCompact and 42 or 52
    local hourW = isCompact and 64 or 78
    local colonW = isCompact and 16 or 22
    local minW = hourW
    local ampmW = isCompact and 48 or 58

    local startX = cardX + pad + 14
    local hourX = startX
    local colonX = hourX + hourW + 4
    local minX = colonX + colonW + 4
    local ampmX = minX + minW + 8

    -- 1. Hour Digit Block
    local hourBgAlpha = isHourActive and (0.15 + 0.15 * smoothPulse) or 0.05
    local hourBorder = isHourActive and theme.colors.accent or theme.colors.border
    Layout.drawCard(hourX, blockY, hourW, blockH, {
      color = { theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], hourBgAlpha },
      borderColor = hourBorder,
      borderWidth = isHourActive and 2 or 1,
      radius = 6,
    })

    if isHourActive then
      -- Animated Stepper Chevrons on Hours
      local chevronPulse = smoothPulse
      love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], chevronPulse)
      Layout.drawText("▲", hourX + math.floor(hourW / 2) - 4, blockY - 14, { font = "tiny", bold = true })
      Layout.drawText("▼", hourX + math.floor(hourW / 2) - 4, blockY + blockH + 1, { font = "tiny", bold = true })
      love.graphics.setColor(1, 1, 1, 1)
    end

    local hourColor = isHourActive and ((blinkCycle or isConfirming) and theme.colors.heading or theme.colors.accent) or theme.colors.textDim
    Layout.drawText(("%02d"):format(displayHour), hourX, blockY + math.floor((blockH - (isCompact and 18 or 24)) / 2), {
      font = isCompact and "headline" or "title",
      color = hourColor,
      bold = true,
      align = "center",
      width = hourW,
    })

    -- 2. Colon Separator
    Layout.drawText(":", colonX, blockY + math.floor((blockH - (isCompact and 18 or 24)) / 2) - 1, {
      font = isCompact and "headline" or "title",
      color = theme.colors.textDim,
      bold = true,
      align = "center",
      width = colonW,
    })

    -- 3. Minute Digit Block
    local minBgAlpha = isMinActive and (0.15 + 0.15 * smoothPulse) or 0.05
    local minBorder = isMinActive and theme.colors.accent or theme.colors.border
    Layout.drawCard(minX, blockY, minW, blockH, {
      color = { theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], minBgAlpha },
      borderColor = minBorder,
      borderWidth = isMinActive and 2 or 1,
      radius = 6,
    })

    if isMinActive then
      -- Animated Stepper Chevrons on Minutes
      local chevronPulse = smoothPulse
      love.graphics.setColor(theme.colors.accent[1], theme.colors.accent[2], theme.colors.accent[3], chevronPulse)
      Layout.drawText("▲", minX + math.floor(minW / 2) - 4, blockY - 14, { font = "tiny", bold = true })
      Layout.drawText("▼", minX + math.floor(minW / 2) - 4, blockY + blockH + 1, { font = "tiny", bold = true })
      love.graphics.setColor(1, 1, 1, 1)
    end

    local minColor = isMinActive and ((blinkCycle or isConfirming) and theme.colors.heading or theme.colors.accent) or theme.colors.textDim
    Layout.drawText(("%02d"):format(minute), minX, blockY + math.floor((blockH - (isCompact and 18 or 24)) / 2), {
      font = isCompact and "headline" or "title",
      color = minColor,
      bold = true,
      align = "center",
      width = minW,
    })

    -- 4. AM/PM Indicator
    Layout.drawCard(ampmX, blockY + math.floor((blockH - 26) / 2), ampmW, 26, {
      color = theme.colors.surface,
      borderColor = theme.colors.border,
      borderWidth = 1,
      radius = 4,
    })
    Layout.drawText(ampm, ampmX, blockY + math.floor((blockH - 26) / 2) + 5, {
      font = "tiny",
      color = theme.colors.heading,
      bold = true,
      align = "center",
      width = ampmW,
    })

    -- Action Status Hint Chip
    local actionText = isHourActive and "ADJUSTING HOURS • ▲ / ▼ CHANGE • A NEXT"
                    or (isMinActive and "ADJUSTING MINUTES • ▲ / ▼ CHANGE • A SET"
                    or (isConfirming and "CONFIRM TIME • A YES • B NO"
                    or "TIME CONFIGURED"))
    local actionKind = (isHourActive or isMinActive) and "accent" or "primary"
    local actW = Layout.textWidth(actionText, "tiny") + 16
    Layout.drawBadge(cardX + pad + displayW - actW - 14, displayY + displayH - 24, actionText, {
      kind = actionKind,
      font = "tiny",
      height = 18,
      width = actW,
      radius = 3,
    })
  end

  -- =========================================================================
  -- 5. Bottom Dialogue / Confirmation Box
  -- =========================================================================
  local qBoxY = displayY + displayH + (isCompact and 8 or 12)
  local qBoxW = cardW - pad * 2

  Layout.drawCard(cardX + pad, qBoxY, qBoxW, qBoxH, {
    color = theme.colors.surfaceHigh,
    borderColor = theme.colors.border,
    borderWidth = 1,
    radius = 6,
  })

  local rawQText = (state.pageText and state:pageText()) or (state.question and state:question()) or "What time is it?"
  local cleanQText = Layout.cleanText(rawQText)

  Layout.drawText(cleanQText, cardX + pad + 12, qBoxY + (isCompact and 8 or 12), {
    font = isCompact and "caption" or "body",
    color = theme.colors.heading,
    bold = true,
    width = isConfirming and (qBoxW - 170) or (qBoxW - 24),
  })

  -- Confirmation YES / NO Buttons
  if isConfirming then
    local btnW = isCompact and 66 or 76
    local btnH = isCompact and 24 or 28
    local btnY = qBoxY + math.floor((qBoxH - btnH) / 2)

    Layout.drawButton(cardX + cardW - pad - btnW * 2 - 12, btnY, btnW, btnH, "YES", {
      kind = yesNo == 1 and "primary" or "ghost",
      selected = yesNo == 1,
      font = "tiny",
    })
    Layout.drawButton(cardX + cardW - pad - btnW - 6, btnY, btnW, btnH, "NO", {
      kind = yesNo == 2 and "primary" or "ghost",
      selected = yesNo == 2,
      font = "tiny",
    })

    Layout.drawText("◄ / ► Select Choice    A Confirm    B Decline", cardX + pad, qBoxY + qBoxH - 16, {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = qBoxW,
    })
  elseif phase == "response" then
    Layout.drawText("A Continue", cardX + pad, qBoxY + qBoxH - 16, {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = qBoxW,
    })
  else
    Layout.drawText("▲ / ▼ Adjust Time/Day    A Confirm", cardX + pad, qBoxY + qBoxH - 16, {
      font = "tiny",
      color = theme.colors.textDim,
      align = "center",
      width = qBoxW,
    })
  end
end

return ClockRenderer
