-- OmniUI Character & Nickname Registration Screen Renderer
-- Modern tactile QWERTY virtual keyboard with live preview banner, species portrait,
-- case switching (UPPER / lower), numbers & symbols (123 / SYM), and gamepad/touch navigation.

local Layout = require("mods.omni_ui.core.Layout")
local Sprites = require("src.pokemon.Sprites")
local PaletteFX = require("src.render.PaletteFX")

local NamingRenderer = {}

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

-- =========================================================================
-- QWERTY Keyboards Definition (Upper, Lower, Symbols)
-- =========================================================================
NamingRenderer.PAGES = {
  upper = {
    mode = "upper",
    label = "QWERTY UPPER",
    rows = {
      { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" },
      { "A", "S", "D", "F", "G", "H", "J", "K", "L", "-" },
      { "Z", "X", "C", "V", "B", "N", "M", ",", ".", "?" },
    },
    actions = {
      { id = "case",  label = "lower", icon = "CAPS", flex = 1.3 },
      { id = "sym",   label = "123",   icon = "#",    flex = 1.1 },
      { id = "space", label = "SPACE",                flex = 2.5 },
      { id = "del",   label = "DEL",   icon = "DEL",  flex = 1.3 },
      { id = "ok",    label = "OK",    icon = "OK",   flex = 1.5, primary = true },
    }
  },
  lower = {
    mode = "lower",
    label = "QWERTY lower",
    rows = {
      { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
      { "a", "s", "d", "f", "g", "h", "j", "k", "l", "-" },
      { "z", "x", "c", "v", "b", "n", "m", ",", ".", "!" },
    },
    actions = {
      { id = "case",  label = "UPPER", icon = "CAPS", flex = 1.3 },
      { id = "sym",   label = "123",   icon = "#",    flex = 1.1 },
      { id = "space", label = "SPACE",                flex = 2.5 },
      { id = "del",   label = "DEL",   icon = "DEL",  flex = 1.3 },
      { id = "ok",    label = "OK",    icon = "OK",   flex = 1.5, primary = true },
    }
  },
  sym = {
    mode = "sym",
    label = "123 & SYMBOLS",
    rows = {
      { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
      { "!", "?", "/", ":", ";", "(", ")", "[", "]", "&" },
      { "♂", "♀", "×", "+", "-", "'", "\"", ".", ",", "/" },
    },
    actions = {
      { id = "case",  label = "ABC",   icon = "ABC", flex = 1.3 },
      { id = "sym",   label = "ABC",   icon = "ABC", flex = 1.1 },
      { id = "space", label = "SPACE",               flex = 2.5 },
      { id = "del",   label = "DEL",   icon = "DEL", flex = 1.3 },
      { id = "ok",    label = "OK",    icon = "OK",  flex = 1.5, primary = true },
    }
  },
}

local DEFAULT_NAMES = {
  emerald = { [0] = "BRENDAN", [1] = "MAY" },
  ruby = { [0] = "BRENDAN", [1] = "MAY" },
  sapphire = { [0] = "BRENDAN", [1] = "MAY" },
  firered = { [0] = "RED", [1] = "LEAF" },
  leafgreen = { [0] = "RED", [1] = "LEAF" },
  red = { [0] = "RED", [1] = "RED" },
  blue = { [0] = "BLUE", [1] = "BLUE" },
  yellow = { [0] = "YELLOW", [1] = "YELLOW" },
  gold = { [0] = "GOLD", [1] = "GOLD" },
  silver = { [0] = "SILVER", [1] = "SILVER" },
  crystal = { [0] = "CHRIS", [1] = "KRIS" },
}

function NamingRenderer.resolveFallback(state, game)
  if not state then return "RED" end
  if state.default and tostring(state.default):match("%S") then
    return tostring(state.default)
  end
  if state.seed and tostring(state.seed):match("%S") then
    return tostring(state.seed)
  end

  local ver = (game and game.gameVersion) or (package.loaded["src.core.GameVersion"] and package.loaded["src.core.GameVersion"].get and package.loaded["src.core.GameVersion"].get()) or "emerald"
  ver = tostring(ver):lower()
  local g = state.gender or (state.opts and state.opts.gender) or 0
  if g == "female" or g == "F" or g == 1 then g = 1 else g = 0 end

  local tpl = state.template or (state.species and "CAUGHT_MON") or "PLAYER"
  if tpl == "CAUGHT_MON" or tpl == "NICKNAME" then
    if state.species then
      if type(state.species) == "string" and not tonumber(state.species) then
        return state.species:upper()
      end
      local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
      if okP and Pokemon and Pokemon.name then
        local spName = Pokemon.name(state.species)
        if spName and spName ~= "" and spName ~= "?????" then return spName:upper() end
      end
      return tostring(state.species):upper()
    end
    return nil -- signals un-nicknamed to engine
  elseif tpl == "RIVAL" or (state.title and tostring(state.title):upper():find("RIVAL")) then
    return (ver == "firered" or ver == "leafgreen" or ver == "red" or ver == "blue" or ver == "yellow") and "BLUE" or "BRENDAN"
  elseif tpl == "BOX" then
    return "BOX 1"
  else -- PLAYER
    local defs = DEFAULT_NAMES[ver] or DEFAULT_NAMES.emerald
    return defs[g] or "RED"
  end
end

function NamingRenderer.getNameInfo(state)
  if not state then return "", 7 end
  if state._state and type(state._state) == "table" then
    return NamingRenderer.getNameInfo(state._state)
  end
  local name = ""
  local tpl = state.template or (state.species and "CAUGHT_MON")
  local defaultMax = (tpl == "CAUGHT_MON" or tpl == "NICKNAME") and 10 or (tpl == "BOX" and 8 or 7)
  local maxLen = state.maxLen or state.maxChars or state.maxLength or defaultMax

  if state.name ~= nil then
    name = tostring(state.name)
  elseif state.glyphs and type(state.glyphs) == "table" then
    name = table.concat(state.glyphs)
  elseif state.text then
    name = tostring(state.text)
  elseif state.buffer then
    name = tostring(state.buffer)
  end

  return name, maxLen
end

-- Attach robust QWERTY input navigation controller to state
local function playNamingSfx(state, game, kind)
  local Audio = package.loaded["src.core.game3.audio"]
  local SE = package.loaded["src.core.game3.se_ids"]
  if Audio and Audio.playSe and SE then
    if kind == "del" then
      Audio.playSe(SE.SE_BALL or 23)
    else
      Audio.playSe(SE.SE_SELECT or 5)
    end
    return
  end
  local g = (state and state.game) or game or (package.loaded["src.core.Game"])
  if g and g.data then
    pcall(function() require("src.core.Sound").play(g.data, "Press_AB") end)
  end
end

function NamingRenderer.handleInput(state, input, game)
  if not state then return false end
  if state._state and type(state._state) == "table" and state._state.template then
    return NamingRenderer.handleInput(state._state, input, game)
  end

  state._omniRow = state._omniRow or 1
  state._omniCol = state._omniCol or 1
  if state._omniRow < 1 or state._omniRow > 4 then state._omniRow = 1 end
  local maxC = (state._omniRow == 4) and 5 or 10
  if state._omniCol < 1 or state._omniCol > maxC then state._omniCol = 1 end
  state._omniMode = state._omniMode or (state.lower and "lower" or "upper")

  state.anim = (state.anim or 0) + 1

  if (state.whiteout or 0) > 0 then
    state.whiteout = state.whiteout - 1
    return true
  end

  local function wasPressed(k)
    if not input then return false end
    if input.wasPressed then
      local ok, res = pcall(input.wasPressed, input, k)
      if ok and res then return true end
      local ok2, res2 = pcall(input.wasPressed, k)
      if ok2 and res2 then return true end
    end
    if input.pressed and type(input.pressed) == "function" then
      local ok, res = pcall(input.pressed, input, k)
      if ok and res then return true end
    end
    return false
  end

  local function getPage()
    local mode = state._omniMode or "upper"
    return NamingRenderer.PAGES[mode] or NamingRenderer.PAGES.upper
  end

  local function addChar(ch)
    if not ch or ch == "" then return end
    local name, maxLen = NamingRenderer.getNameInfo(state)
    if #name >= maxLen then return end

    if state.name ~= nil then
      state.name = state.name .. ch
    elseif state.glyphs and type(state.glyphs) == "table" then
      table.insert(state.glyphs, ch)
    elseif state.addCharacter then
      state:addCharacter(ch)
    elseif state.text then
      state.text = state.text .. ch
    elseif state.buffer then
      state.buffer = state.buffer .. ch
    end

    playNamingSfx(state, game, "press")

    local newName = NamingRenderer.getNameInfo(state)
    if #newName >= maxLen then
      -- Auto-jump cursor to OK button
      state._omniRow = 4
      state._omniCol = 5
      state.row = 4
      state.col = 5
    end
  end

  local function deleteChar()
    local name, _ = NamingRenderer.getNameInfo(state)
    if #name == 0 then return end

    if state.name ~= nil then
      state.name = state.name:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
    elseif state.glyphs and type(state.glyphs) == "table" then
      table.remove(state.glyphs)
    elseif state.deleteCharacter then
      state:deleteCharacter()
    elseif state.text then
      state.text = state.text:sub(1, #state.text - 1)
    elseif state.buffer then
      state.buffer = state.buffer:sub(1, #state.buffer - 1)
    end

    playNamingSfx(state, game, "del")
  end

  local function cycleMode()
    if state._omniMode == "upper" then
      state._omniMode = "lower"
    elseif state._omniMode == "lower" then
      state._omniMode = "sym"
    else
      state._omniMode = "upper"
    end
    state.lower = (state._omniMode == "lower")
    playNamingSfx(state, game, "select")
  end

  local function toggleCase()
    if state._omniMode == "lower" then
      state._omniMode = "upper"
    elseif state._omniMode == "upper" then
      state._omniMode = "lower"
    else
      state._omniMode = "upper"
    end
    state.lower = (state._omniMode == "lower")
    playNamingSfx(state, game, "select")
  end

  local function toggleSym()
    if state._omniMode == "sym" then
      state._omniMode = state.lower and "lower" or "upper"
    else
      state._omniMode = "sym"
    end
    playNamingSfx(state, game, "select")
  end

  local function doFinalConfirm()
    state._confirming = false
    playNamingSfx(state, game, "press")

    local name, _ = NamingRenderer.getNameInfo(state)
    local sanitized = tostring(name):match("^%s*(.-)%s*$") or ""
    if #sanitized == 0 then
      sanitized = NamingRenderer.resolveFallback(state, game)
    end

    if state.confirm then
      state:confirm()
    elseif state.accept then
      state:accept()
    elseif state.name ~= nil and package.loaded["src.ui.game3.naming"] and package.loaded["src.ui.game3.naming"].close then
      package.loaded["src.ui.game3.naming"].close(sanitized)
    else
      local stk = (state.game and state.game.stack) or (game and game.stack) or (package.loaded["src.core.Game"] and package.loaded["src.core.Game"].stack)
      if stk and stk.pop then stk:pop() end
      if state.onDone then state.onDone(sanitized, true) end
    end
  end

  local function requestConfirm()
    local name, _ = NamingRenderer.getNameInfo(state)
    local fallback = NamingRenderer.resolveFallback(state, game)
    if #name == 0 and not fallback and not state.default then
      state.whiteout = 45
      playNamingSfx(state, game, "press")
      return
    end

    state._confirming = true
    state._confirmChoice = 1 -- 1 = YES, 2 = NO
    playNamingSfx(state, game, "select")
  end

  -- Confirmation Modal Navigation
  if state._confirming then
    if wasPressed("left") or wasPressed("right") or wasPressed("up") or wasPressed("down") then
      state._confirmChoice = (state._confirmChoice == 1) and 2 or 1
      playNamingSfx(state, game, "select")
      return true
    end
    if wasPressed("a") or wasPressed("start") then
      if state._confirmChoice == 1 then
        doFinalConfirm()
      else
        state._confirming = false
        playNamingSfx(state, game, "select")
      end
      return true
    end
    if wasPressed("b") then
      state._confirming = false
      playNamingSfx(state, game, "select")
      return true
    end
    return true
  end

  -- START: Request Confirmation
  if wasPressed("start") then
    requestConfirm()
    return true
  end

  -- SELECT: 3-way cycle: UPPER -> lower -> 123/SYM -> UPPER
  if wasPressed("select") then
    cycleMode()
    return true
  end

  -- B: Immediate Delete / Backspace
  if wasPressed("b") then
    deleteChar()
    return true
  end

  -- Navigation
  local curR = state._omniRow or 1
  if curR < 1 or curR > 4 then curR = 1 end
  local maxCols = (curR == 4) and 5 or 10
  local curC = state._omniCol or 1
  if curC < 1 or curC > maxCols then curC = 1 end
  local page = getPage()

  local moved = false
  if wasPressed("up") then
    if curR > 1 then
      if curR == 4 then
        -- Coming up from 5-button action bar to 10-key row 3
        curC = math.min(10, (curC - 1) * 2 + 1)
      end
      curR = curR - 1
    else
      -- Wrap from row 1 to row 4
      curR = 4
      curC = math.min(5, math.floor((curC - 1) / 2) + 1)
    end
    moved = true
  elseif wasPressed("down") then
    if curR < 4 then
      curR = curR + 1
      if curR == 4 then
        -- Going down from 10-key row 3 to 5-button action bar
        curC = math.min(5, math.floor((curC - 1) / 2) + 1)
      end
    else
      -- Wrap from row 4 to row 1
      curR = 1
      curC = math.min(10, (curC - 1) * 2 + 1)
    end
    moved = true
  elseif wasPressed("left") then
    local maxColNow = (curR == 4) and 5 or 10
    curC = (curC > 1) and (curC - 1) or maxColNow
    moved = true
  elseif wasPressed("right") then
    local maxColNow = (curR == 4) and 5 or 10
    curC = (curC < maxColNow) and (curC + 1) or 1
    moved = true
  elseif wasPressed("a") then
    if curR == 4 then
      local act = page.actions[curC]
      if act then
        if act.id == "case" then
          toggleCase()
        elseif act.id == "sym" then
          toggleSym()
        elseif act.id == "space" then
          addChar(" ")
        elseif act.id == "del" then
          deleteChar()
        elseif act.id == "ok" then
          requestConfirm()
          return true
        end
      end
    else
      local rowKeys = page.rows[curR]
      local ch = rowKeys and rowKeys[curC]
      if ch and ch ~= "" then
        addChar(ch)
      end
    end
    return true
  end

  if moved then
    playNamingSfx(state, game, "select")
  end

  state._omniRow = curR
  state._omniCol = curC
  state.row = curR
  state.col = curC
  return moved
end

-- Attach robust QWERTY input navigation controller to state
function NamingRenderer.attachControls(state, game)
  if not state then return end
  if state._state and type(state._state) == "table" and state._state.template then
    return NamingRenderer.attachControls(state._state, game)
  end
  if state.__omniUiNamingAttached then return end
  state.__omniUiNamingAttached = true

  state._omniRow = state._omniRow or 1
  state._omniCol = state._omniCol or 1
  if state._omniRow < 1 or state._omniRow > 4 then state._omniRow = 1 end
  local maxC = (state._omniRow == 4) and 5 or 10
  if state._omniCol < 1 or state._omniCol > maxC then state._omniCol = 1 end
  state._omniMode = state._omniMode or (state.lower and "lower" or "upper")

  local baseUpdate = state.update
  state.update = function(self, dt)
    if type(self) == "number" then
      dt = self
      self = state
    end
    if not self or type(self) ~= "table" then
      self = state
    end

    local input = (self.game and self.game.input)
      or (game and game.input)
      or (package.loaded["src.core.Game"] and package.loaded["src.core.Game"].input)
      or (package.loaded["src.core.Game2"] and package.loaded["src.core.Game2"].input)

    if input then
      NamingRenderer.handleInput(self, input, game)
    elseif baseUpdate then
      baseUpdate(self, dt)
    end
  end
end

function NamingRenderer.draw(game, state, w, h, theme, subState)
  if state.choosing then return end
  if not state.__omniUiNamingAttached then
    NamingRenderer.attachControls(state, game)
  end
  state.anim = (state.anim or 0) + 1

  local title = tostring(state.title or state.prompt or "YOUR NAME?"):upper()
  local currentName, maxLen = NamingRenderer.getNameInfo(state)

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 580) or ctx.isPortrait

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText(title, 18, 12, { font = "headline", color = theme.heading, bold = true })
  
  local charCount = #currentName
  local isFull = (charCount >= maxLen)
  Layout.drawBadge(w - (isNarrow and 120 or 160), 10, ("%d / %d CHARS"):format(charCount, maxLen), {
    kind = isFull and "warn" or "ghost",
    font = "caption",
    height = 24,
  })

  local footY = h - 38

  -- Resolve active Pokémon definition or Trainer mode
  local mon = state.mon
  local monDef = nil
  if mon then
    local species = mon.species or state.speciesName
    monDef = game and game.data and game.data.pokemon and (game.data.pokemon[species] or game.data.pokemon[mon.id])
  end

  -- Determine active QWERTY page
  local mode = state._omniMode or (state.lower and "lower" or "upper")
  local page = NamingRenderer.PAGES[mode] or NamingRenderer.PAGES.upper
  local curRow = state._omniRow or 1
  if curRow < 1 or curRow > 4 then curRow = 1 end
  local maxCols = (curRow == 4) and 5 or 10
  local curCol = state._omniCol or 1
  if curCol < 1 or curCol > maxCols then curCol = 1 end

  -- Caret blink
  local anim = state.anim or 0
  local showCaret = (math.floor(anim / 20) % 2 == 0)

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE STACKED HERO CARD + FULL-WIDTH QWERTY KEYBOARD
    -- =========================================================================
    local heroH = math.max(68, math.min(94, math.floor(h * 0.17)))
    Layout.drawCard(0, 48, w, heroH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local boxSize = heroH - 16
    Layout.drawSlot(8, 56, boxSize, boxSize, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

    if monDef then
      local path, trueColor = Sprites.path(game.data, monDef.species or monDef.name, "front")
      local img = frontPic(path)
      if img then
        local pw, ph = img:getDimensions()
        local scale = (boxSize - 8) / math.max(pw, ph)
        local targetW = pw * scale
        local targetH = ph * scale
        local px = 8 + math.floor((boxSize - targetW) / 2)
        local py = 56 + math.floor((boxSize - targetH) / 2)

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
    else
      Layout.drawBadge(12, 56 + math.floor((boxSize - 20) / 2), "TRAINER", { kind = "accent", width = boxSize - 8, font = "tiny" })
    end

    local hx = boxSize + 16
    local hw = w - hx - 10
    local nameBoxH = boxSize
    Layout.drawSlot(hx, 56, hw, nameBoxH, {
      color = theme.surfaceHigh,
      borderColor = theme.borderStrong,
      borderWidth = 1.5,
      radius = 6,
    })

    -- Name preview with caret
    local displayName = currentName
    if displayName == "" then
      displayName = showCaret and "_" or ""
    elseif #displayName < maxLen and showCaret then
      displayName = displayName .. "_"
    end
    Layout.drawText(displayName, hx + 12, 56 + 6, { font = "title", color = theme.heading, bold = true, width = hw - 24 })

    local subLabel = monDef and (monDef.name or monDef.species) or "PLAYER CHARACTER"
    Layout.drawText(subLabel, hx + 12, 56 + nameBoxH - 22, { font = "tiny", color = theme.textDim, width = hw - 24 })

    -- Full Width QWERTY Keyboard Card
    local keyCardY = 48 + heroH + 6
    local keyCardH = footY - keyCardY - 6
    Layout.drawCard(0, keyCardY, w, keyCardH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    -- Mode header pill
    Layout.drawBadge(12, keyCardY + 6, page.label, { kind = "ghost", font = "tiny", height = 18 })

    local keyAreaY = keyCardY + (ctx.isUltraCompact and 24 or 28)
    local keyAreaH = keyCardH - (ctx.isUltraCompact and 28 or 34)
    local rowStep = math.floor(keyAreaH / 4)
    local keyH = math.max(28, math.min(48, rowStep - (ctx.isUltraCompact and 3 or 4)))

    -- Draw Rows 1 to 3 (10 keys per row)
    local colGap = ctx.isUltraCompact and 2 or (ctx.isCompact and 3 or 4)
    local totalGap = (10 - 1) * colGap
    local keyW = math.floor((w - 20 - totalGap) / 10)
    local btnFont = (keyW < 30 or ctx.isUltraCompact) and "caption" or "button"

    for r = 1, 3 do
      local rowKeys = page.rows[r] or {}
      local ry = keyAreaY + (r - 1) * rowStep + math.floor((rowStep - keyH) / 2)
      for c = 1, 10 do
        local cell = rowKeys[c] or ""
        local kx = 10 + (c - 1) * (keyW + colGap)
        local isSel = (curRow == r and curCol == c)

        if isSel then
          Layout.drawButton(kx, ry, keyW, keyH, cell, {
            kind = "primary",
            selected = true,
            font = btnFont,
          })
        else
          Layout.drawSlot(kx, ry, keyW, keyH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 5,
          })
          Layout.drawText(cell, kx, ry + math.floor((keyH - 16) / 2), {
            font = btnFont,
            color = theme.heading,
            align = "center",
            width = keyW,
            bold = true,
          })
        end
      end
    end

    -- Draw Row 4 (5 Action buttons: Case, Sym, Space, Del, OK)
    local r4Y = keyAreaY + 3 * rowStep + math.floor((rowStep - keyH) / 2)
    local actions = page.actions
    local totalFlex = 0
    for _, act in ipairs(actions) do totalFlex = totalFlex + (act.flex or 1) end
    local availW = w - 20 - (#actions - 1) * colGap

    local actX = 10
    for c, act in ipairs(actions) do
      local bW = math.floor((act.flex / totalFlex) * availW)
      local isSel = (curRow == 4 and curCol == c)
      local isOk = (act.id == "ok")
      local isDel = (act.id == "del")
      local isSpace = (act.id == "space")

      local actFont = (bW < 44 or ctx.isUltraCompact) and "tiny" or "caption"

      if isSel then
        Layout.drawButton(actX, r4Y, bW, keyH, act.label, {
          kind = isOk and "good" or "primary",
          selected = true,
          font = actFont,
        })
      elseif isOk then
        Layout.drawButton(actX, r4Y, bW, keyH, act.label, {
          kind = "good",
          font = actFont,
        })
      else
        Layout.drawButton(actX, r4Y, bW, keyH, act.label, {
          kind = isSpace and "surface" or "accent",
          font = actFont,
        })
      end

      actX = actX + bW + colGap
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANEL LAYOUT
    -- =========================================================================
    local bodyH = h - 96
    local leftW = math.max(200, math.min(320, math.floor(w * (ctx.isCompact and 0.32 or 0.36))))
    local rightX = leftW + 12
    local rightW = w - rightX

    -- Left Preview & Identity Card
    Layout.drawCard(0, 52, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local portH = math.min(160, math.max(90, math.floor(bodyH * 0.38)))
    Layout.drawSlot(16, 66, leftW - 32, portH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })

    if monDef then
      local path, trueColor = Sprites.path(game.data, monDef.species or monDef.name, "front")
      local img = frontPic(path)
      if img then
        local pw, ph = img:getDimensions()
        local scale = math.min(3, math.max(1.5, (portH - 16) / 56))
        local targetW = pw * scale
        local targetH = ph * scale
        local px = 16 + math.floor((leftW - 32 - targetW) / 2)
        local py = 66 + math.floor((portH - targetH) / 2)

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
    else
      Layout.drawBadge(16 + math.floor((leftW - 32 - 120) / 2), 66 + math.floor((portH - 24) / 2), "TRAINER NAME", { kind = "accent", width = 120 })
    end

    local nameBoxY = 66 + portH + 12
    local nameBoxH = math.max(54, math.min(68, math.floor(bodyH * 0.18)))
    Layout.drawSlot(16, nameBoxY, leftW - 32, nameBoxH, {
      color = theme.surfaceHigh,
      borderColor = theme.borderStrong,
      borderWidth = 1.5,
      radius = 6,
    })

    local displayName = currentName
    if displayName == "" then
      displayName = showCaret and "_" or ""
    elseif #displayName < maxLen and showCaret then
      displayName = displayName .. "_"
    end
    Layout.drawText(displayName, 26, nameBoxY + 10, { font = "title", color = theme.heading, bold = true })

    local subLabel = monDef and (monDef.name or monDef.species) or "PLAYER CHARACTER"
    Layout.drawText(subLabel, 26, nameBoxY + nameBoxH - 22, { font = "tiny", color = theme.textDim })

    local tipY = nameBoxY + nameBoxH + 12
    local tipH = bodyH + 52 - tipY - 12
    if tipH > 40 then
      Layout.drawSlot(16, tipY, leftW - 32, tipH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("KEYBOARD SHORTCUTS", 26, tipY + 8, { font = "caption", color = theme.colors.accent, bold = true })
      Layout.drawTextWrapped("Press SELECT to toggle Upper / lower / Symbols.\nPress START to confirm. Press B to delete.", 26, tipY + 26, leftW - 52, { font = "tiny", color = theme.textDim })
    end

    -- Right Interactive QWERTY Keyboard Card
    Layout.drawCard(rightX, 52, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    -- Mode header pill
    Layout.drawBadge(rightX + 16, 62, page.label, { kind = "ghost", font = "tiny", height = 20 })

    local keyAreaY = 88
    local keyAreaH = bodyH - 46
    local rowStep = math.floor(keyAreaH / 4)
    local keyH = math.max(30, math.min(52, rowStep - (ctx.isCompact and 4 or 6)))

    local colGap = ctx.isCompact and 4 or 6
    local totalGap = (10 - 1) * colGap
    local keyW = math.floor((rightW - 32 - totalGap) / 10)
    local btnFont = (keyW < 36 or ctx.isCompact) and "caption" or "button"

    -- Draw Rows 1 to 3
    for r = 1, 3 do
      local rowKeys = page.rows[r] or {}
      local ry = keyAreaY + (r - 1) * rowStep + math.floor((rowStep - keyH) / 2)
      for c = 1, 10 do
        local cell = rowKeys[c] or ""
        local kx = rightX + 16 + (c - 1) * (keyW + colGap)
        local isSel = (curRow == r and curCol == c)

        if isSel then
          Layout.drawButton(kx, ry, keyW, keyH, cell, {
            kind = "primary",
            selected = true,
            font = btnFont,
          })
        else
          Layout.drawSlot(kx, ry, keyW, keyH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
          Layout.drawText(cell, kx, ry + math.floor((keyH - 16) / 2), {
            font = btnFont,
            color = theme.heading,
            align = "center",
            width = keyW,
            bold = true,
          })
        end
      end
    end

    -- Draw Row 4 (5 Action buttons)
    local r4Y = keyAreaY + 3 * rowStep + math.floor((rowStep - keyH) / 2)
    local actions = page.actions
    local totalFlex = 0
    for _, act in ipairs(actions) do totalFlex = totalFlex + (act.flex or 1) end
    local availW = rightW - 32 - (#actions - 1) * colGap

    local actX = rightX + 16
    for c, act in ipairs(actions) do
      local bW = math.floor((act.flex / totalFlex) * availW)
      local isSel = (curRow == 4 and curCol == c)
      local isOk = (act.id == "ok")
      local isDel = (act.id == "del")
      local isSpace = (act.id == "space")

      local actFont = (bW < 50 or ctx.isCompact) and "caption" or "button"

      if isSel then
        Layout.drawButton(actX, r4Y, bW, keyH, act.label, {
          kind = isOk and "good" or "primary",
          selected = true,
          font = actFont,
        })
      elseif isOk then
        Layout.drawButton(actX, r4Y, bW, keyH, act.label, {
          kind = "good",
          font = actFont,
        })
      else
        Layout.drawButton(actX, r4Y, bW, keyH, act.label, {
          kind = isSpace and "surface" or "accent",
          font = actFont,
        })
      end

      actX = actX + bW + colGap
    end
  end

  -- 4. Bottom Button Hints Footer Bar
  local hints = {
    { key = "▲ ▼ ◄ ►", label = "Navigate", primary = true },
    { key = "A", label = "Type" },
    { key = "B", label = "Delete" },
    { key = "SELECT", label = (mode == "upper" and "lower" or (mode == "lower" and "123" or "UPPER")) },
    { key = "START", label = "Confirm" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 8 or 16 })

  -- 5. Confirmation Modal Dialog
  if state._confirming then
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local mw = math.min(380, math.floor(w * 0.88))
    local mh = 200
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    -- Modal Card
    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = theme.borderStrong or theme.accent,
      borderWidth = 2,
      radius = theme.metrics and theme.metrics.radius.modal or 12,
    })

    -- Header Badge / Title
    Layout.drawText("CONFIRM NAME", mx + 20, my + 16, {
      font = "headline",
      color = theme.heading,
      bold = true,
      letterSpacing = 1.2,
    })
    Layout.drawSlot(mx + 18, my + 42, mw - 36, 1.5, {
      color = theme.border,
      borderColor = theme.border,
      radius = 1,
    })

    -- Name Banner Preview
    local confirmedName = (currentName ~= "") and currentName or (state.default or "RED")
    Layout.drawText(tostring(confirmedName):upper(), mx + 20, my + 54, {
      font = "title",
      color = theme.accent or theme.colors.accent,
      bold = true,
      align = "center",
      width = mw - 40,
    })

    Layout.drawText("Is this name correct?", mx + 20, my + 88, {
      font = "body",
      color = theme.textDim,
      align = "center",
      width = mw - 40,
    })

    -- YES / NO Buttons
    local choice = state._confirmChoice or 1
    local btnW = math.floor((mw - 40 - 14) / 2)
    local btnH = 38
    local btnY = my + mh - 50

    -- YES Button (Choice 1)
    local isYes = (choice == 1)
    Layout.drawButton(mx + 20, btnY, btnW, btnH, "YES", {
      kind = isYes and "good" or "ghost",
      selected = isYes,
      font = "button",
    })

    -- NO Button (Choice 2)
    local isNo = (choice == 2)
    Layout.drawButton(mx + 20 + btnW + 14, btnY, btnW, btnH, "NO", {
      kind = isNo and "primary" or "ghost",
      selected = isNo,
      font = "button",
    })
  end
end

-- =========================================================================
-- Gen 2 Trainer Name Selection Menu (Gen2NamePick)
-- =========================================================================
function NamingRenderer.drawNamePick(game, state, vw, vh, theme, subState, viewport)
  if not state then return end
  theme = theme or (package.loaded["mods.omni_ui.core.Theme"] and package.loaded["mods.omni_ui.core.Theme"].get and package.loaded["mods.omni_ui.core.Theme"].get()) or {}

  local ctx = Layout.getContext(vw, vh, viewport)
  local isPortrait = ctx.isPortrait or (vw < 540)
  local isMobileLandscape = not isPortrait and (vh < 440)
  local isCompact = ctx.isCompact or isMobileLandscape or ctx.isUltraCompact

  local items = state.items or { "NEW NAME", "RED", "ASH", "JACK" }
  local cursor = state.cursor or state.index or 1

  local pad = ctx.isUltraCompact and 8 or (isCompact and 10 or 14)
  local headerH = isCompact and 48 or 56
  local footerH = isCompact and 22 or 28
  local itemH = isCompact and 30 or 36
  local itemGap = isCompact and 5 or 8
  local listH = #items * itemH + math.max(0, #items - 1) * itemGap
  local cardH = headerH + listH + footerH + pad * 2

  local cardW, cardX, cardY
  if isPortrait then
    cardW = math.min(vw - pad * 2, 420)
    cardX = math.floor((vw - cardW) / 2)
    cardY = math.max(math.floor(vh * 0.44), math.floor((vh - cardH) / 2))
    if cardY + cardH > vh - 10 then
      cardY = math.max(10, vh - cardH - 10)
    end
  else
    cardW = isCompact and math.min(320, math.floor(vw * 0.42)) or math.min(360, math.floor(vw * 0.40))
    cardX = math.max(16, math.floor(vw * 0.08))
    cardY = math.floor((vh - cardH) / 2)
  end

  local surfaceCol = (theme.colors and theme.colors.surface) or theme.surface
  local borderStrongCol = (theme.colors and theme.colors.borderStrong) or theme.borderStrong or theme.border
  local headingCol = (theme.colors and theme.colors.heading) or theme.heading
  local textDimCol = (theme.colors and theme.colors.textDim) or theme.textDim

  -- Master Card Frame
  Layout.drawCard(cardX, cardY, cardW, cardH, {
    color = surfaceCol,
    borderColor = borderStrongCol,
    borderWidth = 1.5,
    radius = theme.metrics and theme.metrics.radius.modal or 12,
  })

  local rawTitle = state.title and tostring(state.title):upper()
  local isRival = rawTitle and (rawTitle:find("RIVAL") ~= nil)
  local headerTitle = (rawTitle and rawTitle ~= "NAME") and rawTitle or (isRival and "WHAT IS RIVAL's NAME?" or "WHAT IS YOUR NAME?")

  -- Header Badges
  local topY = cardY + pad
  Layout.drawBadge(cardX + pad, topY, isRival and "RIVAL IDENTITY" or "TRAINER IDENTITY", {
    kind = isRival and "warn" or "accent",
    font = "tiny",
    height = isCompact and 18 or 20,
    radius = 4,
  })

  local stepBadgeW = isCompact and 80 or 95
  Layout.drawBadge(cardX + cardW - pad - stepBadgeW, topY, "SELECT NAME", {
    kind = "primary",
    font = "tiny",
    height = isCompact and 18 or 20,
    width = stepBadgeW,
    radius = 4,
  })

  -- Header Title
  Layout.drawText(headerTitle, cardX + pad, topY + (isCompact and 22 or 24), {
    font = isCompact and "caption" or "headline",
    color = headingCol,
    bold = true,
  })

  -- Divider Line
  Layout.drawSlot(cardX + pad, cardY + headerH + pad - 6, cardW - pad * 2, 1.5, {
    color = borderStrongCol,
    borderWidth = 0,
    radius = 1,
  })

  -- List items
  local listStartY = cardY + headerH + pad
  for i, raw in ipairs(items) do
    local isSelected = (i == cursor)
    local isNewName = (i == 1)
    local rawStr = type(raw) == "table" and (raw.text or raw.label or raw[1]) or tostring(raw)
    local nameText = Layout.cleanText(rawStr)
    local iy = listStartY + (i - 1) * (itemH + itemGap)
    local ix = cardX + pad
    local iw = cardW - pad * 2

    local label = isNewName and (nameText .. "...") or nameText
    local btnKind = isSelected and (isNewName and "accent" or "primary") or "ghost"

    Layout.drawButton(ix, iy, iw, itemH, label, {
      kind = btnKind,
      selected = isSelected,
      font = isCompact and "caption" or "button",
      align = "left",
    })

    if isSelected then
      local pillW = isCompact and 36 or 44
      local pillH = isCompact and 18 or 20
      Layout.drawBadge(ix + iw - pillW - 6, iy + math.floor((itemH - pillH) / 2), "SET", {
        kind = isNewName and "accent" or "primary",
        font = "tiny",
        height = pillH,
        width = pillW,
        radius = 4,
      })
    end
  end

  -- Footer Navigation Hint
  Layout.drawText("▲ ▼ Select    A Confirm", cardX + pad, cardY + cardH - footerH - pad + 4, {
    font = "tiny",
    color = textDimCol,
    align = "center",
    width = cardW - pad * 2,
  })
end

return NamingRenderer
