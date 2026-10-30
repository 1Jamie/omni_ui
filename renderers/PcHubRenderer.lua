-- OmniUI PC Hub / Terminal Access Launcher Renderer
-- High-contrast visual portal for Bill's PC, Player's PC, Dex Evaluation, and Hall of Fame.

local Layout = require("mods.omni_ui.core.Layout")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local PcHubRenderer = {}

function PcHubRenderer.draw(game, state, w, h, theme, subState, animProgress)
  local adapter = AdapterResolver.resolve(game)
  local playerInfo = adapter:getPlayerInfo()
  local items = state.entries or state.items
  local curIdx = state.index or state.cursor or 1

  local function getLabel(it)
    if type(it) ~= "table" then return tostring(it or "") end
    local okL, l = pcall(function() return it.label end)
    if okL and l and tostring(l) ~= "" then return tostring(l) end
    local okN, n = pcall(function() return it.name or it.text end)
    if okN and n and tostring(n) ~= "" then return tostring(n) end
    if it.id then
      local idStr = tostring(it.id):gsub("_", " "):upper()
      if idStr == "STORAGE" then return "SOMEONE'S PC"
      elseif idStr == "PLAYER" then return (playerInfo.name or "PLAYER") .. "'S PC"
      elseif idStr == "QUIT" or idStr == "TURN OFF" then return "LOG OFF"
      end
      return idStr
    end
    return tostring(it)
  end

  local function getDesc(it)
    if type(it) ~= "table" then return nil end
    local okD, d = pcall(function() return it.desc end)
    if okD and d and tostring(d) ~= "" then return tostring(d) end
    return nil
  end

  if not items or #items == 0 then
    local PcMenu = package.loaded["src.ui.game3.pc_menu"]
    local mode = state.mode or (PcMenu and PcMenu.mode) or "root"
    if mode == "msg" and (state._prevMode or (PcMenu and PcMenu._prevMode)) then
      mode = state._prevMode or (PcMenu and PcMenu._prevMode)
    end

    local sess = state._session or (PcMenu and PcMenu._session)
    if mode == "player_pc" then
      local okProf, Profile = pcall(require, "src.core.game3.profile")
      local isRse = okProf and sess and Profile.family(sess) == "rse"
      if isRse then
        local okRse, rsePc = pcall(require, "src.ui.game3.rse.player_pc")
        if okRse and rsePc and rsePc.topOrder then
          local okRom, RomText = pcall(require, "src.core.game3.rom_text")
          local topRows = {
            item_storage = "gText_ItemStorage",
            mailbox = "gText_Mailbox",
            decoration = "gText_Decoration",
            turn_off = "gText_TurnOff",
          }
          local okOrder, order = pcall(rsePc.topOrder, state)
          if okOrder and order then
            items = {}
            for _, id in ipairs(order) do
              local lbl = nil
              if okRom and RomText and RomText.plain and topRows[id] then
                pcall(function() lbl = RomText.plain(topRows[id]) end)
              end
              items[#items + 1] = { id = id, label = lbl or id:gsub("_", " "):upper() }
            end
          end
        end
      end
      if not items or #items == 0 then
        items = state.TOP_ACTIONS or (PcMenu and PcMenu.TOP_ACTIONS)
      end
    elseif mode == "item_storage" then
      local okProf, Profile = pcall(require, "src.core.game3.profile")
      local isRse = okProf and sess and Profile.family(sess) == "rse"
      if isRse then
        local okRom, RomText = pcall(require, "src.core.game3.rom_text")
        local okPolicy, RsPolicy = pcall(require, "src.ui.game3.rs.player_pc_policy")
        local storageRows = {
          { id = "withdraw", label = "gText_WithdrawItem" },
          { id = "deposit", label = "gText_DepositItem" },
          { id = "toss", label = "gText_TossItem" },
          { id = "exit", label = "gText_Cancel" },
        }
        items = {}
        for _, row in ipairs(storageRows) do
          local lbl = nil
          if okRom and RomText and RomText.plain then
            local isRs = okPolicy and RsPolicy and RsPolicy.matches and RsPolicy.matches(sess)
            local key = (row.id == "exit" and isRs) and "gOtherText_Exit" or row.label
            pcall(function() lbl = RomText.plain(key) end)
          end
          items[#items + 1] = { id = row.id, label = lbl or row.id:gsub("_", " "):upper() }
        end
      else
        items = state.ITEM_STORAGE_ACTIONS or (PcMenu and PcMenu.ITEM_STORAGE_ACTIONS)
      end
    elseif mode == "storage_menu" then
      if state._storageOptions then
        local okO, res = pcall(state._storageOptions, state)
        if not okO or not res then okO, res = pcall(state._storageOptions) end
        if okO and res then items = res end
      elseif PcMenu and PcMenu._storageOptions then
        local okO, res = pcall(PcMenu._storageOptions)
        if okO and res then items = res end
      end
      curIdx = state.storageCursor or state.cursor or 1
    else
      -- mode == "root" or default
      if state._rootEntries then
        local okE, res = pcall(state._rootEntries, state)
        if not okE or not res then okE, res = pcall(state._rootEntries) end
        if okE and res then items = res end
      elseif PcMenu and PcMenu._rootEntries then
        local okE, res = pcall(PcMenu._rootEntries)
        if okE and res then items = res end
      end
    end

    if not items or #items == 0 then
      local who = (adapter.isBill and adapter:isBill() and "BILL'S PC") or "SOMEONE'S PC"
      items = {
        { id = "storage", label = who },
        { id = "player", label = (playerInfo.name or "PLAYER") .. "'S PC" },
        { id = "hall", label = "HALL OF FAME" },
        { id = "quit", label = "LOG OFF" },
      }
    end
  end

  curIdx = state.cursor or state.storageCursor or state.index or curIdx or 1
  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 540) or ctx.isPortrait
  local footY = h - 38

  -- 1. Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText("POKÉMON TERMINAL", 18, 12, { font = "headline", color = theme.heading, bold = true })
  if w >= 360 then
    Layout.drawBadge(w - 120, 10, "ONLINE", { kind = "good", font = "caption", height = 24 })
  end

  local function formatLabel(raw)
    local s = tostring(raw or "")
    s = s:gsub("<PK><MN>", "POKÉMON ")
    s = s:gsub("<PK>", "PK")
    s = s:gsub("<MN>", "MN")
    local u = s:upper()
    if u:find("LEAGUE") or u:find("HALL OF FAME") then
      return "HALL OF FAME"
    end
    return s
  end

  local function getSubDesc(it, raw, displayLabel)
    local desc = getDesc(it)
    if desc and desc ~= "" then
      local d = tostring(desc)
      d = d:gsub("<PK><MN>", "POKÉMON ")
      d = d:gsub("<PK>", "PK")
      d = d:gsub("<MN>", "MN")
      d = d:gsub("[\r\n]+", " "):gsub("%s+", " ")
      return d
    end
    local upperLabel = tostring(raw or ""):upper() .. " " .. displayLabel:upper()
    if upperLabel:find("BILL") or upperLabel:find("SOMEONE") or upperLabel:find("LANETTE") or upperLabel:find("STORAGE") then
      return "Manage Pokémon boxes, party, and transfers"
    elseif upperLabel:find("ITEM") or upperLabel:find("PLAYER") or upperLabel:find(playerInfo.name:upper()) then
      return "Deposit and withdraw stored items"
    elseif upperLabel:find("OAK") or upperLabel:find("BIRCH") or upperLabel:find("ELM") or upperLabel:find("EVAL") then
      return "Evaluate Pokédex completion rating"
    elseif upperLabel:find("HALL") or upperLabel:find("FAME") or upperLabel:find("LEAGUE") then
      return "View League Champion records"
    elseif upperLabel:find("WITHDRAW") then
      return "Move stored Pokémon or items to your party"
    elseif upperLabel:find("DEPOSIT") then
      return "Store Pokémon or items safely in the system"
    elseif upperLabel:find("MOVE") then
      return "Reorganize Pokémon or items in boxes"
    elseif upperLabel:find("MAIL") then
      return "Check and manage received mail"
    elseif upperLabel:find("DECOR") then
      return "Place decorations and furniture in room"
    elseif upperLabel:find("TOSS") then
      return "Throw away unwanted stored items"
    elseif upperLabel:find("LOG") or upperLabel:find("OFF") or upperLabel:find("TURN") or upperLabel:find("EXIT") or upperLabel:find("CANCEL") or upperLabel:find("SEE YA") then
      return "Power down terminal and return to overworld"
    end
    return "Access terminal service"
  end

  local boxCap = adapter:getBoxCapacity() * adapter:getBoxCount()
  local storedMons = 0
  for b = 1, adapter:getBoxCount() do
    local bData = adapter:getBoxData(b) or {}
    for s = 1, adapter:getBoxCapacity() do
      if bData[s] then storedMons = storedMons + 1 end
    end
  end

  if not isNarrow then
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANE LAYOUT
    -- =========================================================================
    local bodyH = h - 96
    local leftW = math.floor(w * 0.52)
    local rightX = leftW + 12
    local rightW = w - rightX

    -- Left Menu Options Dock
    Layout.drawCard(0, 52, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local itemH = 68
    local itemGap = 8
    for i, it in ipairs(items) do
      local isSel = (curIdx == i)
      local raw = getLabel(it)
      local displayLabel = formatLabel(raw)
      local subDesc = getSubDesc(it, raw, displayLabel)
      local iy = 66 + (i - 1) * (itemH + itemGap)

      if isSel then
        Layout.drawCard(8, iy, leftW - 16, itemH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 8,
        })
        Layout.drawText(displayLabel, 22, iy + 8, { font = "headline", color = theme.heading, bold = true })
        Layout.drawTextWrapped(subDesc, 22, iy + 30, leftW - 44, { font = "tiny", color = theme.colors.accent })
      else
        Layout.drawSlot(8, iy, leftW - 16, itemH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 8,
        })
        Layout.drawText(displayLabel, 22, iy + 8, { font = "headline", color = theme.text })
        Layout.drawTextWrapped(subDesc, 22, iy + 30, leftW - 44, { font = "tiny", color = theme.textDim })
      end
    end

    -- Right Terminal Summary Intel Card
    Layout.drawCard(rightX, 52, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    Layout.drawText("TERMINAL STATUS", rightX + 18, 66, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(rightX + rightW - 120, 66, playerInfo.name, { kind = "team" })

    local metricY = 104
    local metricW = math.floor((rightW - 48) / 2)

    Layout.drawStatMetric(rightX + 18, metricY, metricW, ("%d / %d"):format(storedMons, boxCap), "BOXED PKMN")
    Layout.drawStatMetric(rightX + 18 + metricW + 12, metricY, metricW, tostring(#adapter:getItemStorage()), "STORED ITEMS")

    local descSlotY = metricY + 84
    local descSlotH = bodyH + 52 - descSlotY - 16
    Layout.drawSlot(rightX + 16, descSlotY, rightW - 32, descSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
    Layout.drawText("SYSTEM LOG", rightX + 26, descSlotY + 14, { font = "caption", color = theme.colors.accent, bold = true })

    local statusText = "Connected to regional Silph Co. / Devon network link. High-speed transfers and item storage protocols online."
    if state._status and tostring(state._status) ~= "" then
      statusText = tostring(state._status)
    elseif state.message and tostring(state.message) ~= "" then
      statusText = tostring(state.message)
    end
    statusText = statusText:gsub("<PK><MN>", "POKÉMON "):gsub("<PK>", "PK"):gsub("<MN>", "MN")
    Layout.drawTextWrapped(statusText, rightX + 26, descSlotY + 38, rightW - 52, { font = "body", color = theme.text })

  else
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE STACKED LAYOUT
    -- =========================================================================
    local bannerH = 58
    Layout.drawCard(0, 48, w, bannerH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local metricW = math.floor((w - 32) / 2)
    Layout.drawStatMetric(16, 52, metricW, ("%d / %d"):format(storedMons, boxCap), "BOXED PKMN")
    Layout.drawStatMetric(16 + metricW, 52, metricW, tostring(#adapter:getItemStorage()), "STORED ITEMS")

    -- Bottom Options Dock (Full Width)
    local listY = 48 + bannerH + 6
    local listH = footY - listY - 6
    Layout.drawCard(0, listY, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local itemH = 58
    local itemGap = 6
    for i, it in ipairs(items) do
      local isSel = (curIdx == i)
      local raw = getLabel(it)
      local displayLabel = formatLabel(raw)
      local subDesc = getSubDesc(it, raw, displayLabel)
      local iy = listY + 8 + (i - 1) * (itemH + itemGap)

      if isSel then
        Layout.drawCard(8, iy, w - 16, itemH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
        Layout.drawText(displayLabel, 18, iy + 6, { font = "button", color = theme.heading, bold = true })
        Layout.drawTextWrapped(subDesc, 18, iy + 26, w - 40, { font = "tiny", color = theme.colors.accent })
      else
        Layout.drawSlot(8, iy, w - 16, itemH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 6,
        })
        Layout.drawText(displayLabel, 18, iy + 6, { font = "button", color = theme.text })
        Layout.drawTextWrapped(subDesc, 18, iy + 26, w - 40, { font = "tiny", color = theme.textDim })
      end
    end
  end

  -- 4. Footer Hint Bar
  local hints = {
    { key = "A", label = "Select", primary = true },
    { key = "▲ ▼", label = "Navigate" },
    { key = "B", label = "Log Off" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return PcHubRenderer
