-- OmniUI Mod Manager Renderer
-- In-game mod manager with tabbed views, hero detail cards, options schema editor,
-- profile management, and responsive orientation adaptability.

local Layout = require("mods.omni_ui.core.Layout")

local ModManagerRenderer = {}

local GAME_ABBREV = {
  red = "R", blue = "B", yellow = "Y",
  gold = "G", silver = "S", crystal = "C",
  ruby = "R", sapphire = "S", emerald = "E",
  firered = "FR", leafgreen = "LG",
}

local function getTargetBadges(mod)
  local ModTargets = package.loaded["src.mods.ModTargets"]
  if not ModTargets or not mod then
    return { { text = "GEN 1-3", kind = "ghost" } }
  end

  local versions = ModTargets.versions(mod)
  if not versions or #versions == 0 then
    return { { text = "GEN 1-3", kind = "ghost" } }
  end

  local set = {}
  for _, id in ipairs(versions) do set[id] = true end

  local g1List, g2List, g3List = {}, {}, {}
  local g1All, g2All, g3All = true, true, true

  local g1Vers = ModTargets.generationVersions(1) or { "red", "blue", "yellow" }
  local g2Vers = ModTargets.generationVersions(2) or { "gold", "silver", "crystal" }
  local g3Vers = ModTargets.generationVersions(3) or { "ruby", "sapphire", "emerald", "firered", "leafgreen" }

  for _, id in ipairs(g1Vers) do
    if set[id] then table.insert(g1List, GAME_ABBREV[id] or id:sub(1, 1):upper()) else g1All = false end
  end
  for _, id in ipairs(g2Vers) do
    if set[id] then table.insert(g2List, GAME_ABBREV[id] or id:sub(1, 1):upper()) else g2All = false end
  end
  for _, id in ipairs(g3Vers) do
    if set[id] then table.insert(g3List, GAME_ABBREV[id] or id:sub(1, 1):upper()) else g3All = false end
  end

  if #g1List > 0 and #g2List > 0 and #g3List > 0 and g1All and g2All and g3All then
    return { { text = "GEN 1-3 (ALL)", kind = "primary" } }
  end
  if #g1List > 0 and #g2List > 0 and #g3List == 0 and g1All and g2All then
    return { { text = "GEN 1-2", kind = "good" } }
  end

  local badges = {}
  if #g1List > 0 then
    local label = g1All and "GEN 1" or ("G1:" .. table.concat(g1List, "/"))
    table.insert(badges, { text = label, kind = "danger" })
  end
  if #g2List > 0 then
    local label = g2All and "GEN 2" or ("G2:" .. table.concat(g2List, "/"))
    table.insert(badges, { text = label, kind = "warn" })
  end
  if #g3List > 0 then
    local label = g3All and "GEN 3" or ("G3:" .. table.concat(g3List, "/"))
    table.insert(badges, { text = label, kind = "good" })
  end

  if #badges == 0 then
    table.insert(badges, { text = "GEN 1", kind = "danger" })
  end

  return badges
end

local function getTargetSummary(mod)
  local ModTargets = package.loaded["src.mods.ModTargets"]
  if not ModTargets or not mod then return "G1-3" end

  local versions = ModTargets.versions(mod)
  if not versions or #versions == 0 then return "G1-3" end

  local set = {}
  for _, id in ipairs(versions) do set[id] = true end

  local g1Any, g2Any, g3Any = false, false, false
  local g1All, g2All, g3All = true, true, true

  local g1Vers = ModTargets.generationVersions(1) or { "red", "blue", "yellow" }
  local g2Vers = ModTargets.generationVersions(2) or { "gold", "silver", "crystal" }
  local g3Vers = ModTargets.generationVersions(3) or { "ruby", "sapphire", "emerald", "firered", "leafgreen" }

  for _, id in ipairs(g1Vers) do
    if set[id] then g1Any = true else g1All = false end
  end
  for _, id in ipairs(g2Vers) do
    if set[id] then g2Any = true else g2All = false end
  end
  for _, id in ipairs(g3Vers) do
    if set[id] then g3Any = true else g3All = false end
  end

  if g1All and g2All and g3All then return "G1-3" end
  if g1All and g2All and not g3Any then return "G1-2" end
  if g1All and not g2Any and not g3Any then return "G1" end
  if not g1Any and g2All and not g3Any then return "G2" end
  if not g1Any and not g2Any and g3All then return "G3" end

  local parts = {}
  if g1Any then table.insert(parts, "G1") end
  if g2Any then table.insert(parts, "G2") end
  if g3Any then table.insert(parts, "G3") end
  return #parts > 0 and table.concat(parts, "+") or "G1"
end

local function getClampedScroll(state, key, curIdx, visibleCount, totalItems)
  state._omniScroll = state._omniScroll or {}
  local scroll = state._omniScroll[key] or state.scroll or 1
  if curIdx < scroll then
    scroll = curIdx
  elseif curIdx >= scroll + visibleCount then
    scroll = curIdx - visibleCount + 1
  end
  scroll = math.max(1, math.min(math.max(1, totalItems - visibleCount + 1), scroll))
  state._omniScroll[key] = scroll
  return scroll
end

local function getClampedScroll0(state, key, curIdx, visibleCount, totalItems)
  state._omniScroll = state._omniScroll or {}
  local scroll = state._omniScroll[key] or state.scroll or 0
  if curIdx <= scroll then
    scroll = curIdx - 1
  elseif curIdx > scroll + visibleCount then
    scroll = curIdx - visibleCount
  end
  scroll = math.max(0, math.min(math.max(0, totalItems - visibleCount), scroll))
  state._omniScroll[key] = scroll
  return scroll
end

function ModManagerRenderer.draw(game, state, w, h, theme, subState)
  local screen = state.screen or "list"
  local tab = state.tab or 1
  local curIdx = state.cursor or 1
  local scroll = state.scroll or 1
  local status = state.status or (state.game and state.game.modStatus) or { available = {}, errors = {} }
  local available = status.available or {}
  local errors = status.errors or {}

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait
  local footY = h - 38

  local curModName = state.currentMod and (state.currentMod.name or state.currentMod.id) or "MOD"
  local headerTitle = "MOD MANAGER"
  if screen == "detail" then
    headerTitle = "MOD: " .. curModName
  elseif screen == "options" then
    headerTitle = curModName .. " SETTINGS"
  elseif screen == "permissions" then
    headerTitle = "PERMISSIONS: " .. curModName
  elseif screen == "errors" then
    headerTitle = "ERROR LOG"
  elseif screen == "apply" then
    headerTitle = "PENDING CHANGES"
  end

  local bodyY = 52
  if isNarrow then
    -- Top Header Card
    Layout.drawCard(0, 0, w, 40, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText(headerTitle, 16, 11, { font = "headline", color = theme.heading, bold = true, width = w - 130 })

    local tagX = w - 110
    if state.banner or (package.loaded["src.mods.Runtime"] and package.loaded["src.mods.Runtime"].safeMode) then
      Layout.drawBadge(tagX, 8, "SAFE MODE", { kind = "danger", font = "tiny" })
    elseif state.restartPending then
      Layout.drawBadge(tagX, 8, "! RESTART", { kind = "warn", font = "tiny" })
    end

    if screen == "list" then
      -- Full-Width Tab Switcher
      Layout.drawCard(0, 44, w, 36, { color = theme.surface, borderColor = theme.border, radius = 8 })
      local tabNames = {
        ("MODS (%d)"):format(#available),
        "PROFILES",
        (#errors > 0 and ("ERRORS (%d)"):format(#errors) or "ERRORS"),
      }
      local tabW = math.floor((w - 16) / #tabNames)
      for i, tLabel in ipairs(tabNames) do
        local isCurTab = (tab == i and screen == "list")
        local tx = 8 + (i - 1) * tabW
        Layout.drawButton(tx, 48, tabW - 4, 28, tLabel, {
          kind = isCurTab and "accent" or "ghost",
          selected = isCurTab,
          font = "caption",
        })
      end
      bodyY = 84
    else
      Layout.drawCard(0, 44, w, 36, { color = theme.surface, borderColor = theme.border, radius = 8 })
      Layout.drawButton(8, 48, w - 16, 28, "‹ BACK TO MODS", {
        kind = "ghost",
        font = "caption",
      })
      bodyY = 84
    end
  else
    -- Desktop / Landscape Single Header with Inline Tabs
    Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText(headerTitle, 18, 12, { font = "headline", color = theme.heading, bold = true })

    local tagX = Layout.textWidth(headerTitle, "headline") + 32
    if state.banner or (package.loaded["src.mods.Runtime"] and package.loaded["src.mods.Runtime"].safeMode) then
      Layout.drawBadge(tagX, 10, "SAFE MODE", { kind = "danger" })
      tagX = tagX + 110
    end
    if state.restartPending then
      Layout.drawBadge(tagX, 10, "! RESTART NEEDED", { kind = "warn" })
      tagX = tagX + 150
    end

    if screen == "list" then
      local tabNames = {
        ("MODS (%d)"):format(#available),
        "PROFILES",
        (#errors > 0 and ("ERRORS (%d)"):format(#errors) or "ERRORS"),
      }
      local tabW = 110
      for i, tLabel in ipairs(tabNames) do
        local isCurTab = (tab == i and screen == "list")
        local tx = w - (4 - i) * (tabW + 8) - 10
        Layout.drawButton(tx, 7, tabW, 30, tLabel, {
          kind = isCurTab and "accent" or "ghost",
          selected = isCurTab,
          font = "caption",
        })
      end
    else
      Layout.drawButton(w - 110, 7, 100, 30, "‹ BACK", {
        kind = "ghost",
        font = "caption",
      })
    end
    bodyY = 52
  end

  local totalAvailH = footY - bodyY - 8
  local bodyH = totalAvailH

  -- 2. Screen Routing
  if screen == "list" then
    local rows = (state.rowsForScreen and state:rowsForScreen()) or state.rows or {}
    local selRow = rows[curIdx]
    local selMod = selRow and selRow.mod
    local selProfile = selRow and selRow.profile

    if isNarrow then
      -- =======================================================================
      -- PORTRAIT / COMPACT MOBILE VERTICALLY STACKED LAYOUT
      -- =======================================================================
      if tab == 1 then
        local drawerH = math.min(124, math.max(86, math.floor(totalAvailH * 0.28)))
        local listH = totalAvailH - drawerH - 6
        local drawerY = bodyY + listH + 6

        -- Top Full-Width Mod List Card
        Layout.drawCard(0, bodyY, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

        local rowH = 38
        local rowGap = 4
        local itemStep = rowH + rowGap
        local visibleCount = math.max(1, math.floor((listH - 16) / itemStep))

        local listScroll = getClampedScroll(state, "list_tab1_portrait", curIdx, visibleCount, #rows)

        local contentW = (#rows > visibleCount) and (w - 22) or (w - 16)

        for slot = 1, visibleCount do
          local idx = listScroll + slot - 1
          local r = rows[idx]
          if not r then break end

          local isSel = (curIdx == idx)
          local ry = bodyY + 8 + (slot - 1) * itemStep

          if isSel then
            Layout.drawCard(8, ry, contentW, rowH, {
              color = theme.accentDark,
              borderColor = theme.borderStrong,
              borderWidth = 2,
              radius = 6,
            })
          else
            Layout.drawSlot(8, ry, contentW, rowH, {
              color = theme.surfaceHigh,
              borderColor = theme.border,
              borderWidth = 1,
              radius = 6,
            })
          end

          if r.header then
            Layout.drawText("- " .. tostring(r.label) .. " -", 20, ry + 10, { font = "button", color = theme.heading, bold = true })
          else
            local m = r.mod
            local badgeText = "OFF"
            local badgeKind = "ghost"
            local rightInfo = ""

            if m then
              local isStaged = state.isStaged and state:isStaged(m)
              if m.error then
                badgeText = "ERR"
                badgeKind = "danger"
              elseif isStaged then
                badgeText = "STAGED"
                badgeKind = "warn"
              elseif m.enabled then
                badgeText = "ON"
                badgeKind = "good"
              end

              local tChip = getTargetSummary(m)
              local verText = m.version and ("v" .. tostring(m.version)) or ""
              rightInfo = tChip .. (verText ~= "" and (" " .. verText) or "")
            end

            Layout.drawBadge(16, ry + 7, badgeText, { kind = badgeKind, font = "tiny", width = 52 })

            local rw = (rightInfo ~= "") and (Layout.textWidth(rightInfo, "tiny") + 14) or 0
            if rightInfo ~= "" then
              Layout.drawBadge(contentW - rw - 2, ry + 7, rightInfo, {
                kind = isSel and "accent" or "ghost",
                font = "tiny",
                width = rw,
              })
            end

            local labelStartX = 74
            local maxLabelW = contentW - labelStartX - rw - 8
            local rawLabel = tostring(r.label or (m and (m.name or m.id)) or "ENTRY")
            Layout.drawText(rawLabel, labelStartX, ry + 9, {
              font = "button",
              color = isSel and theme.heading or theme.text,
              bold = isSel,
              width = maxLabelW,
            })
          end
        end

        if #rows > visibleCount then
          Layout.drawScrollBar(w - 10, bodyY + 10, 4, listH - 20, #rows, visibleCount, listScroll, { is1Indexed = true, minThumbH = 16, radius = 2 })
        end

        -- Bottom Docked Mod Inspector Card
        Layout.drawCard(0, drawerY, w, drawerH, { color = theme.surface, borderColor = theme.border, radius = 8 })
        Layout.drawSlot(8, drawerY + 6, w - 16, drawerH - 12, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        if selMod then
          local badges = getTargetBadges(selMod)
          local curBx = w - 24
          for bi = #badges, 1, -1 do
            local b = badges[bi]
            local bw = Layout.textWidth(b.text, "tiny") + 16
            curBx = curBx - bw - 4
            Layout.drawBadge(curBx, drawerY + 12, b.text, { kind = b.kind, font = "tiny", width = bw })
          end

          Layout.drawText(selMod.name or selMod.id, 18, drawerY + 12, { font = "headline", color = theme.heading, bold = true, width = curBx - 24 })
          local authorStr = (selMod.author and ("by " .. selMod.author) or ("ID: " .. selMod.id)) .. "  |  v" .. tostring(selMod.version or "1.0") .. "  |  " .. tostring(selMod.category or "Mod"):upper()
          Layout.drawText(authorStr, 18, drawerY + 34, { font = "tiny", color = theme.textDim, width = w - 36 })

          local descText = selMod.description or (selMod.note and ("Note: " .. selMod.note)) or "No description provided."
          Layout.drawText(descText, 18, drawerY + 52, { font = "caption", color = theme.textMuted, width = w - 36 })
        else
          Layout.drawText("Select a mod from the list above", 18, drawerY + 16, { font = "caption", color = theme.textMuted })
        end

      elseif tab == 2 then
        local drawerH = math.min(108, math.max(76, math.floor(totalAvailH * 0.25)))
        local listH = totalAvailH - drawerH - 6
        local drawerY = bodyY + listH + 6

        -- Top Full-Width Profile List Card
        Layout.drawCard(0, bodyY, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

        local rowH = 38
        local rowGap = 4
        local itemStep = rowH + rowGap
        local visibleCount = math.max(1, math.floor((listH - 16) / itemStep))

        local listScroll = getClampedScroll(state, "list_tab2_portrait", curIdx, visibleCount, #rows)

        local contentW = (#rows > visibleCount) and (w - 22) or (w - 16)

        for slot = 1, visibleCount do
          local idx = listScroll + slot - 1
          local r = rows[idx]
          if not r then break end

          local isSel = (curIdx == idx)
          local ry = bodyY + 8 + (slot - 1) * itemStep

          if isSel then
            Layout.drawCard(8, ry, contentW, rowH, {
              color = theme.accentDark,
              borderColor = theme.borderStrong,
              borderWidth = 2,
              radius = 6,
            })
          else
            Layout.drawSlot(8, ry, contentW, rowH, {
              color = theme.surfaceHigh,
              borderColor = theme.border,
              borderWidth = 1,
              radius = 6,
            })
          end

          local badgeText = "SAVED"
          local badgeKind = "ghost"
          local rightInfo = ""

          if r.profile then
            local opts = state.optionsTable and state:optionsTable()
            local isActive = (opts and opts.activeProfile == r.profile.name)
            badgeText = isActive and "ACTIVE" or "SAVED"
            badgeKind = isActive and "good" or "ghost"

            local enCount = 0
            for _, en in pairs(r.profile.enabled or {}) do
              if en then enCount = enCount + 1 end
            end
            rightInfo = enCount .. " mods"

          elseif r.adhoc then
            local opts = state.optionsTable and state:optionsTable()
            local isLive = (not opts or not opts.activeProfile)
            badgeText = isLive and "LIVE" or "AD-HOC"
            badgeKind = isLive and "good" or "ghost"
            rightInfo = isLive and "(Live)" or ""

          elseif r.saveAs then
            badgeText = "SAVE"
            badgeKind = "primary"
            rightInfo = "(New)"

          elseif r.exportProfile then
            badgeText = "EXPORT"
            badgeKind = "ghost"
            rightInfo = "(.g1rmodlist)"

          elseif r.importProfile then
            badgeText = "IMPORT"
            badgeKind = "ghost"
            rightInfo = "(profiles/)"
          end

          Layout.drawBadge(16, ry + 7, badgeText, { kind = badgeKind, font = "tiny", width = 60 })

          local rw = (rightInfo ~= "") and (Layout.textWidth(rightInfo, "tiny") + 14) or 0
          if rightInfo ~= "" then
            Layout.drawBadge(contentW - rw - 2, ry + 7, rightInfo, {
              kind = isSel and "accent" or "ghost",
              font = "tiny",
              width = rw,
            })
          end

          local labelStartX = 82
          local maxLabelW = contentW - labelStartX - rw - 8
          local rawLabel = tostring(r.label or (r.profile and r.profile.name) or "ENTRY")
          Layout.drawText(rawLabel, labelStartX, ry + 9, {
            font = "button",
            color = isSel and theme.heading or theme.text,
            bold = isSel,
            width = maxLabelW,
          })
        end

        if #rows > visibleCount then
          Layout.drawScrollBar(w - 10, bodyY + 10, 4, listH - 20, #rows, visibleCount, listScroll, { is1Indexed = true, minThumbH = 16, radius = 2 })
        end

        -- Bottom Docked Profile Details Card
        Layout.drawCard(0, drawerY, w, drawerH, { color = theme.surface, borderColor = theme.border, radius = 8 })
        Layout.drawSlot(8, drawerY + 6, w - 16, drawerH - 12, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        if selProfile then
          local opts = state.optionsTable and state:optionsTable()
          local isActive = (opts and opts.activeProfile == selProfile.name)
          local enCount = 0
          for _, en in pairs(selProfile.enabled or {}) do
            if en then enCount = enCount + 1 end
          end
          local optCount = 0
          for _, bucket in pairs(selProfile.options or {}) do
            for _ in pairs(bucket) do optCount = optCount + 1 end
          end

          Layout.drawBadge(w - 120, drawerY + 12, isActive and "ACTIVE" or "SAVED", { kind = isActive and "good" or "ghost", font = "tiny" })
          Layout.drawText(selProfile.name, 18, drawerY + 12, { font = "headline", color = theme.heading, bold = true, width = w - 140 })
          Layout.drawText(("Mods: %d enabled | %d available  •  %d setting overrides"):format(enCount, #available, optCount), 18, drawerY + 34, { font = "caption", color = theme.textDim, width = w - 36 })
          Layout.drawText("A: Load Profile  •  SELECT: Rename  •  START: Delete", 18, drawerY + 52, { font = "tiny", color = theme.colors.accent, width = w - 36 })
        else
          Layout.drawText("Select a profile from the list above", 18, drawerY + 16, { font = "caption", color = theme.textMuted })
        end

      elseif tab == 3 then
        -- Full-Width Error Log Card
        Layout.drawCard(0, bodyY, w, totalAvailH, { color = theme.surface, borderColor = theme.border, radius = 8 })
        Layout.drawSlot(8, bodyY + 8, w - 16, 36, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        local errCount = #errors
        Layout.drawText("MOD SYSTEM ERROR LOG", 18, bodyY + 16, { font = "headline", color = errCount > 0 and theme.hpRed or theme.heading, bold = true })
        Layout.drawBadge(w - 110, bodyY + 14, errCount > 0 and (errCount .. " ERRORS") or "NO ERRORS", { kind = errCount > 0 and "danger" or "good", font = "tiny" })

        local errSlotH = totalAvailH - 56
        Layout.drawSlot(8, bodyY + 48, w - 16, errSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        local errLines = state.errorLines and state:errorLines(nil) or { "No errors reported." }
        local ey = bodyY + 56
        for _, el in ipairs(errLines) do
          if ey > bodyY + totalAvailH - 24 then break end
          Layout.drawText(el, 18, ey, { font = "body", color = theme.textDim, width = w - 36 })
          ey = ey + 20
        end
      end

    else
      -- =======================================================================
      -- LANDSCAPE / STANDARD 2-PANE DESKTOP LAYOUT
      -- =======================================================================
      local listW = math.floor(w * 0.52)
      local inspectX = listW + 12
      local inspectW = w - inspectX

      Layout.drawCard(0, bodyY, listW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

      local rowH = 40
      local rowGap = 5
      local itemStep = rowH + rowGap
      local visibleCount = math.max(1, math.floor((bodyH - 24) / itemStep))

      local listScroll = getClampedScroll(state, "list_tab" .. tostring(tab) .. "_landscape", curIdx, visibleCount, #rows)

      local contentW = (#rows > visibleCount) and (listW - 22) or (listW - 16)

      for slot = 1, visibleCount do
        local idx = listScroll + slot - 1
        local r = rows[idx]
        if not r then break end

        local isSel = (curIdx == idx)
        local ry = bodyY + 12 + (slot - 1) * itemStep

        if isSel then
          Layout.drawCard(8, ry, contentW, rowH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(8, ry, contentW, rowH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
        end

        if r.header then
          Layout.drawText("- " .. tostring(r.label) .. " -", 20, ry + 11, { font = "button", color = theme.heading, bold = true })
        else
          local m = r.mod
          local badgeText = "OFF"
          local badgeKind = "ghost"
          local rightInfo = ""

          if m then
            local isStaged = state.isStaged and state:isStaged(m)
            if m.error then
              badgeText = "ERR"
              badgeKind = "danger"
            elseif isStaged then
              badgeText = "STAGED"
              badgeKind = "warn"
            elseif m.enabled then
              badgeText = "ON"
              badgeKind = "good"
            end

            local tChip = getTargetSummary(m)
            local verText = m.version and ("v" .. tostring(m.version)) or ""
            rightInfo = tChip .. (verText ~= "" and (" " .. verText) or "")

          elseif r.profile then
            local opts = state.optionsTable and state:optionsTable()
            local isActive = (opts and opts.activeProfile == r.profile.name)
            badgeText = isActive and "ACTIVE" or "SAVED"
            badgeKind = isActive and "good" or "ghost"

            local enCount = 0
            for _, en in pairs(r.profile.enabled or {}) do
              if en then enCount = enCount + 1 end
            end
            rightInfo = enCount .. " mods"

          elseif r.adhoc then
            local opts = state.optionsTable and state:optionsTable()
            local isLive = (not opts or not opts.activeProfile)
            badgeText = isLive and "LIVE" or "AD-HOC"
            badgeKind = isLive and "good" or "ghost"
            rightInfo = isLive and "(Live)" or ""

          elseif r.saveAs then
            badgeText = "SAVE"
            badgeKind = "primary"
            rightInfo = "(New)"

          elseif r.exportProfile then
            badgeText = "EXPORT"
            badgeKind = "ghost"
            rightInfo = "(.g1rmodlist)"

          elseif r.importProfile then
            badgeText = "IMPORT"
            badgeKind = "ghost"
            rightInfo = "(profiles/)"
          end

          Layout.drawBadge(16, ry + 8, badgeText, { kind = badgeKind, font = "tiny" })

          local rw = (rightInfo ~= "") and (Layout.textWidth(rightInfo, "caption") + 14) or 0
          if rightInfo ~= "" then
            Layout.drawText(rightInfo, contentW - rw - 10, ry + 11, {
              font = "caption",
              color = isSel and theme.heading or theme.textDim,
            })
          end

          local labelStartX = 84
          local maxLabelW = contentW - labelStartX - rw - 10
          local rawLabel = tostring(r.label or (m and (m.name or m.id)) or (r.profile and r.profile.name) or "ENTRY")
          Layout.drawText(rawLabel, labelStartX, ry + 10, {
            font = "button",
            color = isSel and theme.heading or theme.text,
            bold = isSel,
            width = maxLabelW,
          })
        end
      end

      -- Scrollbar indicator
      if #rows > visibleCount then
        Layout.drawScrollBar(listW - 12, bodyY + 12, 4, bodyH - 24, #rows, visibleCount, listScroll, { is1Indexed = true, minThumbH = 16, radius = 2 })
      end

      -- Right Inspector Panel
      Layout.drawCard(inspectX, bodyY, inspectW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

      if tab == 1 and selMod then
        Layout.drawSlot(inspectX + 12, bodyY + 12, inspectW - 24, 76, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })

        local badges = getTargetBadges(selMod)
        local curBx = inspectX + inspectW - 24
        for bi = #badges, 1, -1 do
          local b = badges[bi]
          local bw = Layout.textWidth(b.text, "tiny") + 20
          curBx = curBx - bw - 6
          Layout.drawBadge(curBx, bodyY + 18, b.text, { kind = b.kind, font = "tiny" })
        end

        Layout.drawText(selMod.name or selMod.id, inspectX + 22, bodyY + 18, { font = "headline", color = theme.heading, bold = true })
        local authorStr = selMod.author and ("by " .. selMod.author) or ("ID: " .. selMod.id)
        Layout.drawText(authorStr, inspectX + 22, bodyY + 40, { font = "caption", color = theme.textDim })
        local versionStr = "v" .. tostring(selMod.version or "1.0") .. "  |  " .. tostring(selMod.category or "Mod"):upper()
        Layout.drawText(versionStr, inspectX + 22, bodyY + 58, { font = "tiny", color = theme.textDim })

        local descY = bodyY + 98
        local descH = 140
        Layout.drawSlot(inspectX + 12, descY, inspectW - 24, descH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("DESCRIPTION", inspectX + 22, descY + 10, { font = "caption", color = theme.heading, bold = true })

        local descText = selMod.description or (selMod.note and ("Note: " .. selMod.note)) or "No description provided."
        Layout.drawTextWrapped(descText, inspectX + 22, descY + 32, inspectW - 48, { font = "body", color = theme.textDim })

        local permY = descY + descH + 12
        local permH = bodyH - (permY - bodyY) - 12
        Layout.drawSlot(inspectX + 12, permY, inspectW - 24, permH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("PERMISSIONS & SAFETY", inspectX + 22, permY + 10, { font = "caption", color = theme.heading, bold = true })

        local perms = selMod.permissions or {}
        if #perms > 0 then
          local py = permY + 32
          for _, p in ipairs(perms) do
            Layout.drawText("! " .. tostring(p):upper(), inspectX + 22, py, { font = "caption", color = theme.hpYellow, bold = true })
            py = py + 18
          end
        else
          Layout.drawText("✓ Standard Sandboxed Mod", inspectX + 22, permY + 32, { font = "caption", color = theme.hpGreen, bold = true })
        end

      elseif tab == 2 then
        if selProfile then
          local opts = state.optionsTable and state:optionsTable()
          local isActive = (opts and opts.activeProfile == selProfile.name)

          local enCount = 0
          local enNames = {}
          for id, en in pairs(selProfile.enabled or {}) do
            if en then
              enCount = enCount + 1
              local m = state.byId and state.byId[id]
              enNames[#enNames + 1] = m and (m.name or m.id) or id
            end
          end
          table.sort(enNames)

          local optCount = 0
          for _, bucket in pairs(selProfile.options or {}) do
            for _ in pairs(bucket) do optCount = optCount + 1 end
          end

          Layout.drawSlot(inspectX + 12, bodyY + 12, inspectW - 24, 76, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
          Layout.drawBadge(inspectX + inspectW - 140, bodyY + 18, isActive and "ACTIVE PROFILE" or "SAVED PROFILE", { kind = isActive and "good" or "ghost" })

          Layout.drawText(selProfile.name, inspectX + 22, bodyY + 18, { font = "headline", color = theme.heading, bold = true })
          Layout.drawText(("Mods: %d enabled  |  %d available"):format(enCount, #available), inspectX + 22, bodyY + 40, { font = "caption", color = theme.textDim })
          Layout.drawText(("Overrides: %d setting values stored"):format(optCount), inspectX + 22, bodyY + 58, { font = "tiny", color = theme.textDim })

          local modListY = bodyY + 98
          local modListH = 150
          Layout.drawSlot(inspectX + 12, modListY, inspectW - 24, modListH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
          Layout.drawText("MODS IN THIS PROFILE (" .. enCount .. ")", inspectX + 22, modListY + 10, { font = "caption", color = theme.heading, bold = true })

          local my = modListY + 32
          if #enNames > 0 then
            for i = 1, math.min(#enNames, 5) do
              Layout.drawText("+ " .. enNames[i], inspectX + 22, my, { font = "body", color = theme.text })
              my = my + 20
            end
            if #enNames > 5 then
              Layout.drawText(("...and %d more mods"):format(#enNames - 5), inspectX + 22, my, { font = "caption", color = theme.textDim })
            end
          else
            Layout.drawText("No mods enabled in this profile.", inspectX + 22, my, { font = "body", color = theme.textMuted })
          end

          local actY = modListY + modListH + 12
          local actH = bodyH - (actY - bodyY) - 12
          Layout.drawSlot(inspectX + 12, actY, inspectW - 24, actH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
          Layout.drawText("PROFILE ACTIONS", inspectX + 22, actY + 10, { font = "caption", color = theme.heading, bold = true })
          Layout.drawText("A: Load & Apply Profile", inspectX + 22, actY + 32, { font = "body", color = theme.heading, bold = true })
          Layout.drawText("SELECT: Rename Profile    START: Delete Profile", inspectX + 22, actY + 54, { font = "caption", color = theme.textDim })
        end

      elseif tab == 3 then
        Layout.drawSlot(inspectX + 12, bodyY + 12, inspectW - 24, bodyH - 24, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
        Layout.drawText("MOD SYSTEM ERROR LOG", inspectX + 22, bodyY + 22, { font = "headline", color = theme.hpRed, bold = true })
        local errLines = state.errorLines and state:errorLines(nil) or { "No errors reported." }
        local ey = bodyY + 52
        for _, el in ipairs(errLines) do
          if ey > bodyY + bodyH - 36 then break end
          Layout.drawText(el, inspectX + 22, ey, { font = "body", color = theme.textDim })
          ey = ey + 22
        end
      end
    end

  elseif screen == "detail" then
    local m = state.currentMod
    if m then
      Layout.drawCard(0, bodyY, w, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

      -- Top Mod Info Slot
      Layout.drawSlot(16, bodyY + 14, w - 32, 80, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })

      local badges = getTargetBadges(m)
      local curBx = w - 32
      for bi = #badges, 1, -1 do
        local b = badges[bi]
        local bw = Layout.textWidth(b.text, "tiny") + 20
        curBx = curBx - bw - 8
        Layout.drawBadge(curBx, bodyY + 22, b.text, { kind = b.kind, font = "tiny" })
      end

      Layout.drawText(m.name or m.id, 30, bodyY + 22, { font = "headline", color = theme.heading, bold = true, width = curBx - 36 })
      Layout.drawText("Version: " .. tostring(m.version or "1.0") .. "  |  Author: " .. tostring(m.author or "Unknown"), 30, bodyY + 44, { font = "caption", color = theme.textDim, width = w - 64 })
      Layout.drawText("Category: " .. tostring(m.category or "TOOL"):upper() .. "  |  Profile: " .. tostring(m.profile or "content"), 30, bodyY + 62, { font = "tiny", color = theme.textDim, width = w - 64 })

      -- Description Slot
      local descY = bodyY + 104
      local descH = 110
      Layout.drawSlot(16, descY, w - 32, descH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("DESCRIPTION", 30, descY + 10, { font = "caption", color = theme.heading, bold = true })
      local descText = m.description or (m.note and ("Note: " .. m.note)) or "No description provided."
      Layout.drawTextWrapped(descText, 30, descY + 32, w - 64, { font = "body", color = theme.textDim })

      -- Actions Slot
      local choicesY = descY + descH + 12
      local choicesH = bodyH - (choicesY - bodyY) - 12
      Layout.drawSlot(16, choicesY, w - 32, choicesH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

      local rows = (state.rowsForScreen and state:rowsForScreen()) or state.rows or {}
      local rowH = 40
      local rowGap = 6
      local itemStep = rowH + rowGap
      local visibleActions = math.max(1, math.floor((choicesH - 16) / itemStep))

      local detScroll = getClampedScroll(state, "detail_actions", curIdx, visibleActions, #rows)

      for slot = 1, visibleActions do
        local i = detScroll + slot - 1
        local r = rows[i]
        if not r then break end

        local isSel = (curIdx == i)
        local ay = choicesY + 8 + (slot - 1) * itemStep
        local aw = w - 48

        if isSel then
          Layout.drawCard(24, ay, aw, rowH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(24, ay, aw, rowH, {
            color = theme.surface,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
        end

        local rawLbl = tostring(r.label or "")
        local pillText = "ACTION"
        local pillKind = "ghost"
        local displayTitle = rawLbl
        local rightHint = ""

        if rawLbl == "ENABLE" or rawLbl:find("^ENABLE") then
          pillText = "OFF"
          pillKind = "ghost"
          displayTitle = "ENABLE THIS MOD"
          rightHint = "(Press A to Enable)"
        elseif rawLbl == "DISABLE" or rawLbl:find("^DISABLE") then
          pillText = "ON"
          pillKind = "good"
          displayTitle = "DISABLE THIS MOD"
          rightHint = "(Press A to Disable)"
        elseif rawLbl:find("OPTIONS") then
          pillText = "OPTIONS"
          pillKind = "primary"
          displayTitle = "CONFIGURE MOD SETTINGS..."
          rightHint = "(A: Open Options)"
        elseif rawLbl:find("PERMISSIONS") then
          pillText = "SECURITY"
          pillKind = "warn"
          displayTitle = "VIEW MOD PERMISSIONS..."
          rightHint = "(A: View)"
        elseif r.adjust or rawLbl:find("LOAD") then
          pillText = "ORDER"
          pillKind = "primary"
          local at, total = rawLbl:match("(%d+)[/%s%w]*(%d+)")
          if at and total then
            displayTitle = "<  LOAD ORDER: POSITION " .. at .. " OF " .. total .. "  >"
          else
            displayTitle = "<  " .. rawLbl .. "  >"
          end
          rightHint = "< / >: Move in Order"
        elseif rawLbl:find("BACK") then
          pillText = "‹"
          pillKind = "ghost"
          displayTitle = "BACK TO MODS LIST"
          rightHint = "(B / A: Back)"
        end

        local btnFh = Layout.textHeight("button")
        local textY = ay + math.floor((rowH - btnFh) / 2)
        local capFh = Layout.textHeight("caption")
        local hintY = ay + math.floor((rowH - capFh) / 2)
        local bh = 22
        local by = ay + math.floor((rowH - bh) / 2)
        local badgeW = math.max(68, Layout.textWidth(pillText, "tiny") + 22)
        local titleX = 36 + badgeW + 14

        Layout.drawBadge(36, by, pillText, { kind = pillKind, font = "tiny", height = bh, width = badgeW })
        local maxTitleW = isNarrow and (aw - badgeW - 32) or (aw - badgeW - Layout.textWidth(rightHint, "caption") - 48)
        Layout.drawText(displayTitle, titleX, textY, {
          font = "button",
          color = isSel and theme.heading or theme.text,
          bold = isSel,
          width = maxTitleW,
        })

        if rightHint ~= "" and not isNarrow then
          Layout.drawText(rightHint, 24 + aw - Layout.textWidth(rightHint, "caption") - 14, hintY, {
            font = "caption",
            color = isSel and theme.heading or theme.textDim,
          })
        end
      end
    end

  elseif screen == "options" then
    Layout.drawCard(0, bodyY, w, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local rows = state.optionRows or {}
    local rowH = 46
    local rowGap = 6
    local itemStep = rowH + rowGap
    local visibleCount = math.max(1, math.floor((bodyH - 24) / itemStep))

    local optScroll = getClampedScroll0(state, "options_rows", curIdx, visibleCount, #rows)

    for slot = 1, visibleCount do
      local idx = optScroll + slot
      local r = rows[idx]
      if not r then break end

      local isSel = (curIdx == idx)
      local py = bodyY + 12 + (slot - 1) * itemStep
      local btnFh = Layout.textHeight("button")
      local labelY = py + math.floor((rowH - btnFh) / 2)
      local capFh = Layout.textHeight("caption")
      local hintY = py + math.floor((rowH - capFh) / 2)

      if isSel then
        Layout.drawCard(16, py, w - 32, rowH, { color = theme.accentDark, borderColor = theme.borderStrong, borderWidth = 2, radius = 6 })
      else
        Layout.drawSlot(16, py, w - 32, rowH, { color = theme.surfaceHigh, borderColor = theme.border, borderWidth = 1, radius = 6 })
      end

      if r.id == "__reset" then
        Layout.drawText("[ RESTORE DEFAULT SETTINGS ]", 34, labelY, { font = "button", color = isSel and theme.heading or theme.textDim, bold = isSel, width = w - 180 })
        if not isNarrow then
          Layout.drawText("(Press A to reset)", w - 180, hintY, { font = "caption", color = isSel and theme.heading or theme.textMuted })
        end
      else
        local optLabel = r.label or r.id or "OPTION"
        local maxOptW = isNarrow and (w - 180) or (w - 240)
        Layout.drawText(optLabel, 34, labelY, { font = "button", color = isSel and theme.heading or theme.text, bold = isSel, width = maxOptW })

        if r.value then
          local valStr = type(r.value) == "function" and tostring(r.value()) or tostring(r.value)
          if valStr == "ON" or valStr == "OFF" then
            local isValOn = (valStr == "ON")
            local swW = isNarrow and 54 or 70
            local swX = w - (swW * 2 + 38)
            local swH = 28
            local swY = py + math.floor((rowH - swH) / 2)

            Layout.drawButton(swX, swY, swW, swH, "ON", {
              kind = isValOn and "good" or "ghost",
              selected = isValOn,
              font = "caption",
            })
            Layout.drawButton(swX + swW + 6, swY, swW, swH, "OFF", {
              kind = (not isValOn) and "danger" or "ghost",
              selected = (not isValOn),
              font = "caption",
            })
          else
            local displayVal = "< " .. valStr .. " >"
            local valW = Layout.textWidth(displayVal, "caption") + 24
            local valH = 28
            local valX = math.max(w * 0.45, w - valW - 24)
            local valY = py + math.floor((rowH - valH) / 2)

            Layout.drawSlot(valX, valY, valW, valH, {
              color = isSel and theme.surface or theme.surfaceHigh,
              borderColor = isSel and theme.borderStrong or theme.border,
              radius = 6,
            })
            local valTextY = valY + math.floor((valH - capFh) / 2)
            Layout.drawText(displayVal, valX, valTextY, {
              font = "caption",
              color = isSel and theme.heading or theme.textDim,
              align = "center",
              width = valW,
            })
          end
        end
      end
    end
  end

  -- 3. Bottom Footer Bar with Dynamic Hints
  local hints = {}
  if screen == "list" and tab == 2 then
    hints = {
      { key = "A", label = "Apply Profile", primary = true },
      { key = "SELECT", label = "Rename" },
      { key = "START", label = "Delete" },
      { key = "B", label = "Back" },
    }
  elseif screen == "list" and tab == 3 then
    hints = {
      { key = "▲ ▼", label = "Scroll Log" },
      { key = "B", label = "Back" },
    }
  elseif screen == "detail" then
    hints = {
      { key = "A", label = "Select Action", primary = true },
      { key = "◄ ►", label = "Order" },
      { key = "B", label = "Back" },
    }
  elseif screen == "options" then
    hints = {
      { key = "◄ ►", label = "Adjust" },
      { key = "A", label = "Toggle" },
      { key = "B", label = "Back", primary = true },
    }
  else
    hints = isNarrow and {
      { key = "A", label = "Toggle", primary = true },
      { key = "B", label = "Close" },
      { key = "SELECT", label = "Quick" },
      { key = "START", label = "Apply" },
    } or {
      { key = "A", label = "Select / Toggle", primary = true },
      { key = "B", label = "Close" },
      { key = "SELECT", label = "Quick Toggle" },
      { key = "START", label = "Apply & Restart" },
    }
  end

  local columns = isNarrow and nil or (screen == "detail" and { 0, 180, 360 } or screen == "options" and { 0, 180, 340 } or { 0, 160, 320, 480 })
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 8 or 16, columns = columns })
end

return ModManagerRenderer
