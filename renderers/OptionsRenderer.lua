-- OmniUI Options Menu Renderer
-- Settings list with segmented controls, sliders, and launcher-styled toggles.

local Layout = require("mods.omni_ui.core.Layout")

local OptionsRenderer = {}

local function gen3OptionPage(state)
  if type(state) ~= "table" then return nil end
  local pages = state._pages
  if type(pages) ~= "table" or #pages == 0 then
    pages = state._st and state._st.pages
  end
  if type(pages) ~= "table" or #pages == 0 then return nil end
  return pages[#pages]
end

local function optionRowCtx(state, game)
  if type(state) == "table" then
    if state._ctx then return state._ctx end
    if state._st and state._st.ctx then return state._st.ctx end
  end
  return game
end

local function absorbOptionRows(game, state, page)
  if not page or type(page.rows) ~= "table" then return end
  local okRuntime, Runtime = pcall(require, "src.mods.Runtime")
  if not okRuntime or not Runtime or not Runtime.call then return end
  local hookGame = game
  if type(state) == "table" then
    hookGame = state._game or (state._ctx and state._ctx.game) or (state._st and state._st.ctx and state._st.ctx.game) or game
  end
  local function sameRows(_, rows) return rows end
  local ok, hooked = pcall(Runtime.call, "ui.options.rows", sameRows, hookGame, page.rows)
  if ok and type(hooked) == "table" then page.rows = hooked end
end

local function rowValue(row, ctx, game, state)
  if type(row.value) ~= "function" then return nil end
  local ok, res = pcall(row.value, ctx)
  if ok and res ~= nil then return res end
  ok, res = pcall(row.value, game, state)
  if ok and res ~= nil then return res end
  return nil
end

function OptionsRenderer.draw(game, state, w, h, theme, animProgress)
  local page = gen3OptionPage(state)
  if page then absorbOptionRows(game, state, page) end
  local rowCtx = optionRowCtx(state, game)
  local isSub = state.sub == true or (page and page.top == nil and page ~= ((state._pages and state._pages[1]) or (state._st and state._st.pages and state._st.pages[1])))
  local title = isSub and (state.title or (page and page.title) or "SUB-OPTIONS") or ((page and page.title) or "GAME SETTINGS")
  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 540) or ctx.isPortrait

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText(title, 18, 12, { font = "headline", color = theme.heading, bold = true })
  if w >= 360 then
    local badgeLabel = isSub and "SUB-MENU" or (isNarrow and "CONFIG" or "CONFIGURATION")
    local bw = Layout.textWidth(badgeLabel, "caption") + 24
    Layout.drawBadge(w - bw - 14, 12, badgeLabel, { kind = "ghost", width = bw })
  end

  local sourceRows = (page and page.rows) or state.view or state.rows or state.options or {}
  local displayList = {}
  for _, r in ipairs(sourceRows) do
    displayList[#displayList + 1] = r
  end

  -- Add Cancel / Back row at bottom if not already in list
  local hasBack = false
  for _, r in ipairs(displayList) do
    if r.isBack or r.id == "cancel" or (r.label and (r.label:upper() == "CANCEL" or r.label:upper() == "BACK")) then
      hasBack = true
      break
    end
  end
  if not hasBack then
    displayList[#displayList + 1] = {
      id = "cancel",
      label = isSub and "BACK" or "CANCEL",
      isBack = true,
    }
  end

  local curIdx = (page and (state.cursor or page.index)) or state.index or state.cursor or 1
  local listY = 52
  local listH = h - 100
  local rowH = isNarrow and 44 or 46
  local rowGap = 6
  local itemStep = rowH + rowGap
  local visibleCount = math.max(1, math.floor((listH - 16) / itemStep))

  -- Determine scroll
  local scroll = state.scroll or 0
  if curIdx <= scroll then
    scroll = curIdx - 1
  elseif curIdx > scroll + visibleCount then
    scroll = curIdx - visibleCount
  end
  scroll = math.max(0, math.min(math.max(0, #displayList - visibleCount), scroll))
  state.scroll = scroll

  -- Background card for options
  Layout.drawCard(0, listY, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

  local contentW = (#displayList > visibleCount) and (w - 30) or (w - 20)

  for slot = 1, visibleCount do
    local idx = scroll + slot
    local r = displayList[idx]
    if not r then break end

    local isSel = (curIdx == idx)
    local py = listY + 8 + (slot - 1) * itemStep

    -- Staggered cascade ripple for options rows (22ms per row, 18px slide)
    local offsetX = Layout.getCascadeOffset(slot, animProgress, 0.022, 18)

    love.graphics.push()
    if offsetX ~= 0 then
      love.graphics.translate(offsetX, 0)
    end

    if isSel then
      Layout.drawCard(10, py, contentW, rowH, {
        color = theme.accentDark,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = 8,
      })
    else
      Layout.drawSlot(10, py, contentW, rowH, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
    end

    local label = r.label or r.name or "OPTION"
    local fontName = isNarrow and "body" or "button"
    local fh = Layout.textHeight(fontName)
    local labelY = py + math.floor((rowH - fh) / 2)

    -- Dynamic right control allocation & width
    local rightControlW = 80
    if r.isBack then
      rightControlW = 70
    elseif r.group or (r.activate and not r.step and not r.choices and not r.values) then
      rightControlW = 80
    elseif r.choices or r.values then
      local choices = r.choices or r.values
      local availRightW = math.min(240, math.max(120, math.floor(contentW * 0.50)))
      rightControlW = availRightW
    else
      rightControlW = math.min(150, math.max(90, math.floor(contentW * 0.44)))
    end

    local maxLabelW = math.max(80, contentW - rightControlW - 32)
    Layout.drawText(label, 22, labelY, {
      font = fontName,
      color = isSel and theme.heading or theme.text,
      bold = isSel,
      width = maxLabelW,
    })

    local options = state.options or (game and game.options) or (game and game.save and game.save.options) or (state.save and state.save.options) or {}
    local key = r.key or r.id
    local curVal = nil
    if r.get then
      local ok, res = pcall(r.get, game)
      if ok and res ~= nil then curVal = res end
    end
    if curVal == nil then
      curVal = rowValue(r, rowCtx, game, state)
    end
    if curVal == nil and key and options[key] ~= nil then
      curVal = options[key]
    end

    -- Right side: Value, Submenu Folder, or Segmented Choices
    if r.isBack then
      local capFh = Layout.textHeight("caption")
      local backY = py + math.floor((rowH - capFh) / 2)
      local backW = Layout.textWidth("(Return)", "caption")
      Layout.drawText("(Return)", contentW - backW - 14, backY, {
        font = "caption",
        color = isSel and theme.heading or theme.textMuted,
      })
    elseif r.group or (r.activate and not r.step and not r.cycle and not r.choices and not r.values and not r.text) then
      -- Group Opener
      local resolvedValue = rowValue(r, rowCtx, game, state)
      local countStr = resolvedValue or (type(r.value) ~= "function" and r.value) or "VIEW"
      local badgeText = tostring(countStr) .. " →"
      local bh = 24
      local by = py + math.floor((rowH - bh) / 2)
      local badgeW = Layout.textWidth(badgeText, "caption") + 20
      local badgeX = contentW - badgeW - 10
      Layout.drawBadge(badgeX, by, badgeText, {
        kind = isSel and "good" or "ghost",
        height = bh,
        width = badgeW,
        font = "caption",
      })
    elseif r.choices or r.values then
      -- Segmented Pills or Compact Stepper
      local choices = r.choices or r.values
      local availW = math.min(240, math.floor(contentW * 0.52))
      local pillH = 26
      local pillGap = 4
      local pillW = math.floor((availW - (#choices - 1) * pillGap) / #choices)

      -- If pills are wide enough (>= 40px), render segmented pill row
      if pillW >= 40 and #choices <= 4 then
        local totalPillsW = #choices * (pillW + pillGap) - pillGap
        local pillX = contentW - totalPillsW - 10
        local pillY = py + math.floor((rowH - pillH) / 2)
        for ci, c in ipairs(choices) do
          local isChosen = false
          if r.selected == ci or r.index == ci then
            isChosen = true
          elseif curVal ~= nil then
            if c == curVal then
              isChosen = true
            elseif type(c) == "string" and type(curVal) == "string" and c:upper():gsub("%s+", "") == curVal:upper():gsub("%s+", "") then
              isChosen = true
            elseif key == "textSpeed" then
              if (curVal == 1 or tostring(curVal):upper():find("FAST")) and tostring(c):upper():find("FAST") then
                isChosen = true
              elseif (curVal == 3 or tostring(curVal):upper():find("MID")) and tostring(c):upper():find("MID") then
                isChosen = true
              elseif (curVal == 5 or tostring(curVal):upper():find("SLOW")) and tostring(c):upper():find("SLOW") then
                isChosen = true
              end
            elseif type(c) == "boolean" then
              if c == true and (curVal == true or tostring(curVal):upper():find("ON")) then
                isChosen = true
              elseif c == false and (curVal == false or tostring(curVal):upper():find("OFF")) then
                isChosen = true
              end
            end
          end

          local pillLabel = ""
          if r.display and r.display[c] ~= nil then
            pillLabel = tostring(r.display[c])
          elseif c == true then
            pillLabel = "ON"
          elseif c == false then
            pillLabel = "OFF"
          else
            pillLabel = tostring(c)
          end
          pillLabel = pillLabel:match("^%s*(.-)%s*$") or pillLabel

          Layout.drawButton(pillX, pillY, pillW, pillH, pillLabel:sub(1, 8), {
            kind = isChosen and "primary" or "ghost",
            selected = isChosen,
            font = "tiny",
          })
          pillX = pillX + pillW + pillGap
        end
      else
        -- Stepper Cycler (< CURRENT >) for tight widths
        local chosenIdx = r.selected or r.index or 1
        if curVal ~= nil then
          for ci, c in ipairs(choices) do
            if c == curVal or (type(c) == "string" and type(curVal) == "string" and c:upper():gsub("%s+", "") == curVal:upper():gsub("%s+", "")) then
              chosenIdx = ci
              break
            end
          end
        end
        local c = choices[chosenIdx] or choices[1]
        local valStr = ""
        if r.display and r.display[c] ~= nil then
          valStr = tostring(r.display[c])
        elseif c == true then
          valStr = "ON"
        elseif c == false then
          valStr = "OFF"
        else
          valStr = tostring(c or "")
        end
        valStr = valStr:match("^%s*(.-)%s*$") or valStr

        local pillBoxW = math.min(140, availW)
        local pillBoxX = contentW - pillBoxW - 10
        local pillBoxY = py + math.floor((rowH - pillH) / 2)

        Layout.drawSlot(pillBoxX, pillBoxY, pillBoxW, pillH, {
          color = isSel and theme.surface or theme.surfaceHigh,
          borderColor = isSel and theme.borderStrong or theme.border,
          radius = 6,
        })
        Layout.drawText(valStr, pillBoxX, pillBoxY + 5, {
          font = "caption",
          color = isSel and theme.heading or theme.text,
          bold = isSel,
          align = "center",
          width = pillBoxW,
        })
        if isSel then
          Layout.drawText("‹", pillBoxX + 5, pillBoxY + 4, { font = "body", color = theme.colors.accent, bold = true })
          Layout.drawText("›", pillBoxX + pillBoxW - 12, pillBoxY + 4, { font = "body", color = theme.colors.accent, bold = true })
        end
      end
    else
      -- Dynamic Setting Value / Cycler (GAME SPEED, ZOOM, TILT, SOUND, AUDIO VOLUMES, etc.)
      local valStr = ""
      if r.text then
        local ok, res = pcall(r.text, options, 0, game)
        if not ok or res == nil then ok, res = pcall(r.text, options, game) end
        if not ok or res == nil then ok, res = pcall(r.text, options) end
        if ok and res ~= nil then valStr = tostring(res) end
      end
      if valStr == "" then
        local resolved = rowValue(r, rowCtx, game, state)
        if resolved ~= nil then
          valStr = tostring(resolved)
        elseif r.value ~= nil and type(r.value) ~= "function" then
          valStr = tostring(r.value)
        end
      end
      if valStr == "" and r.get then
        local ok, res = pcall(r.get, game)
        if ok and res ~= nil then valStr = tostring(res) end
      end
      if valStr == "" and r.frame then
        valStr = "TYPE " .. tostring(options.frame or 1)
      end
      if valStr == "" and key and options[key] ~= nil then
        local v = options[key]
        if r.display and r.display[v] ~= nil then
          valStr = tostring(r.display[v])
        elseif type(v) == "boolean" then
          valStr = v and "ON" or "OFF"
        else
          valStr = tostring(v)
        end
      end
      valStr = valStr:match("^%s*(.-)%s*$") or valStr

      if valStr ~= "" then
        local capFh = Layout.textHeight("caption")
        local tw = Layout.textWidth(valStr, "caption")
        local pillW = math.max(86, math.min(150, tw + 32))
        local pillH = 26
        local pillX = contentW - pillW - 10
        local pillY = py + math.floor((rowH - pillH) / 2)

        Layout.drawSlot(pillX, pillY, pillW, pillH, {
          color = isSel and theme.surface or theme.surfaceHigh,
          borderColor = isSel and theme.borderStrong or theme.border,
          radius = 6,
        })

        local textY = pillY + math.floor((pillH - capFh) / 2)
        Layout.drawText(valStr, pillX, textY, {
          font = "caption",
          color = isSel and theme.heading or theme.text,
          bold = isSel,
          align = "center",
          width = pillW,
        })

        if isSel and (r.step or r.cycle or r.key or r.values or r.choices) then
          Layout.drawText("‹", pillX + 5, pillY + 4, { font = "body", color = theme.colors.accent, bold = true })
          Layout.drawText("›", pillX + pillW - 12, pillY + 4, { font = "body", color = theme.colors.accent, bold = true })
        end
      end
    end

    love.graphics.pop()
  end

  -- Scrollbar Track and Thumb
  if #displayList > visibleCount then
    Layout.drawScrollBar(w - 14, listY + 10, 5, listH - 20, #displayList, visibleCount, scroll)
  end

  -- 3. Bottom Button Hints Footer Bar
  local footY = h - 38
  local hints = {
    { key = "▲ ▼", label = "Navigate" },
    { key = "◄ ►", label = "Adjust" },
    { key = "A", label = "Select", primary = true },
    { key = "B", label = isSub and "Back" or "Close" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return OptionsRenderer
