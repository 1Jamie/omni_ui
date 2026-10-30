-- OmniUI Load Report / Quarantine Report Renderer
-- High-resolution modern load report screen shown when loading a save where mods have changed or items/mons were quarantined.

local Layout = require("mods.omni_ui.core.Layout")

local LoadReportRenderer = {}

local function formatModId(id)
  id = tostring(id or "")
  return id:gsub("_", " "):gsub("(%a)(%w*)", function(a, b) return a:upper() .. b:lower() end)
end

function LoadReportRenderer.buildFlatList(report, meta, fallbackLines)
  report = report or {}
  local diff = report.modsDiff or {}
  local sections = {}

  local addedCount = #(diff.added or {})
  local removedCount = #(diff.removed or {})
  local changedCount = #(diff.changed or {})
  local lostMonCount = #(report.lostMons or {})
  local lostItemCount = #(report.lostItems or {})
  local restoredCount = #(report.restoredMons or {}) + #(report.restoredItems or {})
  local remappedCount = #(report.remappedMaps or {})

  -- Section: Mod Differences
  if addedCount > 0 or removedCount > 0 or changedCount > 0 then
    local rows = {}
    for _, modId in ipairs(diff.added or {}) do
      rows[#rows + 1] = {
        kind = "added",
        title = "+ " .. formatModId(modId),
        desc = "Newly activated mod in load order",
        tag = "ADDED",
        tagKind = "good",
      }
    end
    for _, modId in ipairs(diff.removed or {}) do
      rows[#rows + 1] = {
        kind = "removed",
        title = "- " .. formatModId(modId),
        desc = "Mod is no longer active in profile",
        tag = "REMOVED",
        tagKind = "danger",
      }
    end
    for _, chg in ipairs(diff.changed or {}) do
      rows[#rows + 1] = {
        kind = "changed",
        title = "Δ " .. formatModId(chg.id),
        desc = ("Version updated from %s to %s"):format(tostring(chg.from or "?"), tostring(chg.to or "?")),
        tag = "UPDATED",
        tagKind = "accent",
      }
    end
    sections[#sections + 1] = { title = "MOD ENVIRONMENT CHANGES", rows = rows }
  end

  -- Section: Quarantined Pokémon
  if lostMonCount > 0 then
    local rows = {}
    for _, mon in ipairs(report.lostMons or {}) do
      rows[#rows + 1] = {
        kind = "lost_mon",
        title = tostring(mon.species or "UNKNOWN MON"),
        desc = "Moved to safe quarantine box (" .. tostring(mon.from or "save") .. ")",
        tag = "QUARANTINED",
        tagKind = "warn",
      }
    end
    sections[#sections + 1] = { title = "QUARANTINED POKÉMON", rows = rows }
  end

  -- Section: Removed / Incompatible Items
  if lostItemCount > 0 then
    local rows = {}
    for _, item in ipairs(report.lostItems or {}) do
      rows[#rows + 1] = {
        kind = "lost_item",
        title = tostring(item.id or "ITEM"),
        desc = ("Removed %d obsolete or unsupported item(s)"):format(tonumber(item.count or 1)),
        tag = "REMOVED",
        tagKind = "danger",
      }
    end
    sections[#sections + 1] = { title = "REMOVED ITEMS", rows = rows }
  end

  -- Section: Location Remaps
  if remappedCount > 0 then
    local rows = {}
    for _, map in ipairs(report.remappedMaps or {}) do
      local desc = map.to and ("Warped safely to " .. tostring(map.to)) or ("Reset from " .. tostring(map.field or "unloaded area"))
      rows[#rows + 1] = {
        kind = "remap",
        title = tostring(map.id or "MAP"),
        desc = desc,
        tag = "SAFE WARP",
        tagKind = "ghost",
      }
    end
    sections[#sections + 1] = { title = "LOCATION RESETS", rows = rows }
  end

  -- Section: Restored Entities
  if restoredCount > 0 then
    local rows = {}
    for _, mon in ipairs(report.restoredMons or {}) do
      rows[#rows + 1] = {
        kind = "restored",
        title = tostring(mon.species or "POKÉMON"),
        desc = ("Restored back to Box %d"):format(tonumber(mon.box or 1)),
        tag = "RESTORED",
        tagKind = "good",
      }
    end
    for _, item in ipairs(report.restoredItems or {}) do
      rows[#rows + 1] = {
        kind = "restored",
        title = tostring(item.id or "ITEM"),
        desc = ("Restored x%d to inventory"):format(tonumber(item.count or 1)),
        tag = "RESTORED",
        tagKind = "good",
      }
    end
    sections[#sections + 1] = { title = "RESTORED CONTENT", rows = rows }
  end

  -- Flatten items for scrollable list
  local flatList = {}
  for _, sec in ipairs(sections) do
    flatList[#flatList + 1] = { isHeader = true, title = sec.title }
    for _, row in ipairs(sec.rows) do
      flatList[#flatList + 1] = row
    end
  end

  -- Fallback to lines if flatList empty
  if #flatList == 0 and fallbackLines then
    for _, line in ipairs(fallbackLines) do
      if line ~= "" then
        flatList[#flatList + 1] = { title = line, desc = "", tag = "INFO", tagKind = "ghost" }
      end
    end
  end

  local counts = {
    added = addedCount,
    removed = removedCount,
    changed = changedCount,
    lostMons = lostMonCount,
    lostItems = lostItemCount,
    restored = restoredCount,
    remapped = remappedCount,
  }

  return flatList, counts
end

function LoadReportRenderer.draw(game, state, w, h, theme)
  local report = state.report or {}
  local diff = report.modsDiff or {}
  local meta = (game and game.save and game.save.meta) or (state.save and state.save.meta) or {}

  local flatList, counts = LoadReportRenderer.buildFlatList(report, meta, state.lines)
  local addedCount = counts.added
  local removedCount = counts.removed
  local changedCount = counts.changed
  local lostMonCount = counts.lostMons
  local lostItemCount = counts.lostItems

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText("SAVE LOAD REPORT", 18, 12, { font = "headline", color = theme.heading, bold = true })
  
  local headerBadge = "MOD CHANGES"
  local headerKind = "warn"
  if report.recovered then
    headerBadge = "RECOVERED"
    headerKind = "good"
  elseif (addedCount + removedCount + changedCount) > 0 then
    headerBadge = "MODS CHANGED"
    headerKind = "accent"
  elseif lostMonCount > 0 or lostItemCount > 0 then
    headerBadge = "QUARANTINE"
    headerKind = "warn"
  end
  local badgeW = Layout.textWidth(headerBadge, "caption") + 24
  Layout.drawBadge(w - badgeW - 14, 10, headerBadge, { kind = headerKind, font = "caption", height = 24, width = badgeW })

  local footY = h - 38

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE STACKED OVERVIEW + FULL-WIDTH BREAKDOWN
    -- =========================================================================
    local topHeroH = 104
    Layout.drawCard(0, 48, w, topHeroH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    Layout.drawText("SAFE SAVE LOAD", 16, 58, { font = "button", color = theme.heading, bold = true })
    local badgeLabel = (removedCount > 0 or lostMonCount > 0) and "NOTICE" or "HEALTHY"
    local badgeK = (removedCount > 0 or lostMonCount > 0) and "warn" or "good"
    local bW = Layout.textWidth(badgeLabel, "tiny") + 20
    Layout.drawBadge(w - bW - 14, 56, badgeLabel, { kind = badgeK, font = "tiny", width = bW, height = 22 })

    local statY = 82
    local statH = 46
    local colW = math.floor((w - 28) / 3)
    Layout.drawStatMetric(14, statY, colW, tostring(addedCount + changedCount), "updated")
    Layout.drawStatMetric(14 + colW, statY, colW, tostring(removedCount), "removed")
    Layout.drawStatMetric(14 + colW * 2, statY, colW, tostring(lostMonCount + lostItemCount), "quarantine")

    -- Bottom Breakdown List Card
    local listY = 48 + topHeroH + 6
    local listH = footY - listY - 6
    Layout.drawCard(0, listY, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local itemH = 42
    local itemGap = 4
    local itemStep = itemH + itemGap
    local visibleCount = math.max(1, math.floor((listH - 16) / itemStep))
    local curScroll = math.max(0, math.min(math.max(0, #flatList - visibleCount), state.offset or 0))
    state.offset = curScroll

    local pw = (#flatList > visibleCount) and (w - 26) or (w - 16)

    for slot = 1, visibleCount do
      local idx = curScroll + slot
      local it = flatList[idx]
      if not it then break end

      local py = listY + 8 + (slot - 1) * itemStep

      if it.isHeader then
        local accentColor = (theme.colors and theme.colors.accent) or theme.accent or { 0.3, 0.6, 1.0, 1.0 }
        Layout.drawText(it.title, 14, py + 10, { font = "caption", color = accentColor, bold = true })
        Layout.drawDivider(14, py + 28, pw - 4)
      else
        Layout.drawSlot(8, py, pw, itemH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        local titleFh = Layout.textHeight("button")
        local hasDesc = (it.desc and it.desc ~= "")
        local titleY = hasDesc and (py + 4) or (py + math.floor((itemH - titleFh) / 2))

        local maxTitleW = pw - (it.tag and 90 or 24)
        Layout.drawText(it.title, 16, titleY, { font = "button", color = theme.heading, bold = true, width = maxTitleW })

        if hasDesc then
          Layout.drawText(it.desc, 16, py + 22, { font = "tiny", color = theme.textDim, width = maxTitleW })
        end

        if it.tag then
          local tagW = Layout.textWidth(it.tag, "tiny") + 16
          local tagH = 20
          local tagX = 8 + pw - tagW - 6
          local tagY = py + math.floor((itemH - tagH) / 2)
          Layout.drawBadge(tagX, tagY, it.tag, { kind = it.tagKind or "ghost", font = "tiny", height = tagH, width = tagW })
        end
      end
    end

    if #flatList > visibleCount then
      Layout.drawScrollBar(w - 10, listY + 8, 4, listH - 16, #flatList, visibleCount, curScroll)
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-COLUMN LAYOUT
    -- =========================================================================
    local leftW = math.max(260, math.floor(w * 0.38))
    local bodyY = 52
    local bodyH = h - 96
    local rightX = leftW + 12
    local rightW = w - rightX

    -- Left Column: Hero Status Card
    Layout.drawCard(0, bodyY, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    Layout.drawText("STATUS OVERVIEW", 16, bodyY + 14, { font = "headline", color = theme.heading, bold = true })

    local statusBoxY = bodyY + 40
    Layout.drawSlot(12, statusBoxY, leftW - 24, 82, {
      color = theme.surfaceHigh,
      borderColor = (removedCount > 0 or lostMonCount > 0)
          and ((theme.colors and theme.colors.hpYellow) or theme.hpYellow or theme.warn or { 1, 0.8, 0, 1 })
          or ((theme.colors and theme.colors.hpGreen) or theme.hpGreen or theme.good or { 0.2, 0.9, 0.4, 1 }),
      borderWidth = 1.5,
      radius = 6,
    })
    Layout.drawText("SAFE SAVE LOAD", 22, statusBoxY + 10, { font = "button", color = theme.heading, bold = true })
    Layout.drawTextWrapped(
      (report.recovered and "Save was successfully recovered from backup copy." or "Your save was safely updated for the current mod environment without data corruption."),
      22, statusBoxY + 30, leftW - 44, { font = "tiny", color = theme.textDim }
    )

    -- Stat Summary
    local statY = statusBoxY + 94
    local statH = 50
    Layout.drawSlot(12, statY, leftW - 24, statH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
    local colW = math.floor((leftW - 36) / 3)
    Layout.drawStatMetric(14, statY + 8, colW, addedCount + changedCount, "updated")
    Layout.drawStatMetric(14 + colW, statY + 8, colW, removedCount, "removed")
    Layout.drawStatMetric(14 + colW * 2, statY + 8, colW, lostMonCount + lostItemCount, "quarantined")

    -- Quick Info Slot
    local infoBoxY = statY + statH + 12
    local infoBoxH = bodyH - (infoBoxY - bodyY) - 12
    if infoBoxH > 40 then
      local noticeColor = (theme.colors and theme.colors.accent) or theme.accent or { 0.3, 0.6, 1.0, 1.0 }
      Layout.drawText("NOTICE", 22, infoBoxY + 10, { font = "caption", color = noticeColor, bold = true })
      Layout.drawTextWrapped("Quarantined entries remain safely stored in orphaned records and can be recovered if their respective mods are re-enabled.", 22, infoBoxY + 28, leftW - 44, { font = "tiny", color = theme.textDim })
    end

    -- Right Column: Detailed Breakdown Card
    Layout.drawCard(rightX, bodyY, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local itemH = 46
    local itemGap = 6
    local itemStep = itemH + itemGap
    local visibleCount = math.max(1, math.floor((bodyH - 24) / itemStep))
    local curScroll = math.max(0, math.min(math.max(0, #flatList - visibleCount), state.offset or 0))

    for slot = 1, visibleCount do
      local idx = curScroll + slot
      local it = flatList[idx]
      if not it then break end

      local py = bodyY + 12 + (slot - 1) * itemStep
      local pw = rightW - 24

      if it.isHeader then
        local accentColor = (theme.colors and theme.colors.accent) or theme.accent or { 0.3, 0.6, 1.0, 1.0 }
        Layout.drawText(it.title, rightX + 16, py + 14, { font = "caption", color = accentColor, bold = true })
        Layout.drawDivider(rightX + 16, py + 34, pw - 8)
      else
        Layout.drawSlot(rightX + 12, py, pw, itemH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

        local titleFh = Layout.textHeight("button")
        local capFh = Layout.textHeight("tiny")
        local hasDesc = (it.desc and it.desc ~= "")
        local titleY = hasDesc and (py + 6) or (py + math.floor((itemH - titleFh) / 2))

        Layout.drawText(it.title, rightX + 24, titleY, { font = "button", color = theme.heading, bold = true })

        if hasDesc then
          Layout.drawText(it.desc, rightX + 24, py + 24, { font = "tiny", color = theme.textDim })
        end

        if it.tag then
          local tagW = Layout.textWidth(it.tag, "tiny") + 18
          local tagH = 22
          local tagX = rightX + pw - tagW - 8
          local tagY = py + math.floor((itemH - tagH) / 2)
          Layout.drawBadge(tagX, tagY, it.tag, { kind = it.tagKind or "ghost", font = "tiny", height = tagH, width = tagW })
        end
      end
    end

    -- Scrollbar
    if #flatList > visibleCount then
      Layout.drawScrollBar(rightX + rightW - 14, bodyY + 12, 6, bodyH - 24, #flatList, visibleCount, curScroll)
    end
  end

  -- 4. Bottom Footer Hints
  local hints = {
    { key = "A", label = "Continue Adventure", primary = true },
    { key = "▲ ▼", label = "Scroll Details" },
    { key = "B", label = "Dismiss" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return LoadReportRenderer
