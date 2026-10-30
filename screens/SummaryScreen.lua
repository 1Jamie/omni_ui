-- OmniUI Modern Pokémon Summary Screen
-- Pixel-perfect 1:1 layout with authentic species portrait, SGB color zones, stats, moves, and abilities.

local Font = require("src.render.Font")
local Strings = require("src.core.Strings")
local Theme = require("src.ui.Theme")
local TypeChart = require("src.battle.TypeChart")
local Growth = require("src.pokemon.Growth")
local Sprites = require("src.pokemon.Sprites")
local HudTiles = require("src.render.HudTiles")
local PaletteFX = require("src.render.PaletteFX")
local Status = require("src.battle.Status")
local LevelDisplay = require("src.ui.LevelDisplay")

local SummaryScreen = { isMenu = true, isOpaque = true }
SummaryScreen.__index = SummaryScreen

local frontPics = {}
local function frontPic(path)
  if not path then return nil end
  local img = frontPics[path]
  if img then return img end
  local ok, loaded = pcall(love.graphics.newImage, path)
  if ok and loaded then
    frontPics[path] = loaded
    return loaded
  end
  return nil
end

local function drawLineBox(tx, ty, b, c)
  for i = 0, b - 1 do HudTiles.statusTile(0x78, tx * 8, (ty + i) * 8) end
  HudTiles.statusTile(0x77, tx * 8, (ty + b) * 8)
  for i = 1, c do HudTiles.statusTile(0x76, (tx - i) * 8, (ty + b) * 8) end
  HudTiles.statusTile(0x6F, (tx - c - 1) * 8, (ty + b) * 8)
end

local function printLevel(tx, ty, level)
  local x = tx * 8
  if level < 100 then
    HudTiles.statusTile(0x6E, x, ty * 8)
    x = x + 8
  end
  Font.draw(tostring(level), x, ty * 8)
end

function SummaryScreen.new(game, opts)
  local self = setmetatable({}, SummaryScreen)
  self.game = game
  self.opts = opts or {}
  self.screenId = "SummaryMenu"
  self._expMaxPage = 3
  self.page = 1
  self.closing = false

  if opts and opts.species then
    self.mon = opts
    self.party = { opts }
    self.partyIdx = 1
  else
    self.party = (opts and opts.party) or (game.save and game.save.party) or {}
    self.partyIdx = (opts and opts.index) or 1
    self.mon = (opts and opts.mon) or self.party[self.partyIdx]
  end

  -- Resolve front sprite
  if self.mon and self.mon.species then
    local path, trueColor = Sprites.path(game.data, self.mon.species, "front", { mon = self.mon, kind = "summary" })
    if path then
      self.sprite = frontPic(path)
      self.spriteTrueColor = trueColor
    end
  end

  -- Play Cry
  if self.mon and self.mon.species and game.data then
    local Sound = package.loaded["src.core.Sound"] or require("src.core.Sound")
    if Sound and Sound.playCry then
      Sound.playCry(game.data, self.mon.species)
    end
  end

  return self
end

function SummaryScreen:sgbPalettes(game)
  local P = require("src.render.PaletteFX")
  local mon = self.mon
  if not mon then return P.wholeNamed(game.data, "MEWMON") end
  local maxHp = (mon.stats and mon.stats.hp) or mon.maxHp or mon.hp or 1
  local bar = P.pal(game.data, P.barPalName(mon.hp or 0, maxHp))
  if not bar then return nil end
  return { P.whole(bar), P.zone(P.monPal(game.data, mon.species), 1, 0, 7, 6) }
end

function SummaryScreen:update(dt)
  if self.closing then return end
  local input = self.game and self.game.input
  if not input then return end

  if self.game.data and (input:wasPressed("a") or input:wasPressed("b")) then
    local Sound = package.loaded["src.core.Sound"] or require("src.core.Sound")
    if Sound and Sound.play then
      Sound.play(self.game.data, "Press_AB")
    end
  end

  if input:wasPressed("b") then
    self:close()
    return
  elseif input:wasPressed("a") then
    if self.page < 3 then
      self.page = self.page + 1
    else
      self:close()
    end
    return
  elseif input:wasPressed("left") then
    self.page = (self.page > 1) and (self.page - 1) or 3
  elseif input:wasPressed("right") then
    self.page = (self.page < 3) and (self.page + 1) or 1
  end
end

function SummaryScreen:draw()
  local mon = self.mon
  if not mon then return end
  local game = self.game
  local data = game.data
  local def = (data and data.pokemon and data.pokemon[mon.species]) or {}

  -- Background fill (DMG shade 0)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)

  -- Shared Header: Front Pic (1,0), Nickname (9,1), No. + Dex (1,7)
  if self.sprite then
    local pw, ph = self.sprite:getDimensions()
    local py = math.max(0, 56 - ph)
    love.graphics.draw(self.sprite, 8 + pw, py, 0, -1, 1)
    if self.spriteTrueColor then
      PaletteFX.markTrueColor(8, py, pw, ph)
    end
  end

  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(mon.nickname or def.name or mon.species or "POKéMON", 72, 8)

  -- No. + Dex Number
  HudTiles.statusTile(0x74, 8, 56)  -- №
  Font.drawCode(0xF2, 16, 56)       -- <DOT>
  Font.draw(("%03d"):format(def.dex or 0), 24, 56)

  if self.page == 1 then
    self:drawPage1(mon, def, data)
  elseif self.page == 2 then
    self:drawPage2(mon, def, data)
  else
    self:drawPage3(mon, def, data)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function SummaryScreen:drawPage1(mon, def, data)
  if LevelDisplay.visible(mon, "summary", self.game) then
    printLevel(14, 2, mon.level or 1)
  end

  drawLineBox(19, 1, 6, 10)

  local barZoned = PaletteFX.shader() ~= nil and PaletteFX.pal(data, "GREENBAR") ~= nil
  HudTiles.drawHPBar(data, 11, 3, mon, 1, barZoned)

  local maxHp = (mon.stats and mon.stats.hp) or mon.maxHp or mon.hp or 1
  Font.draw(("%3d/%3d"):format(mon.hp or 0, maxHp), 96, 32)
  Font.draw(Strings("STATUS/"), 72, 48)
  Font.draw(Status.hudLabelFor(data and data.statuses, mon.status) or "OK", 128, 48)

  -- Stats Box: (0,8) 10x10
  Font.drawBox(0, 8, 10, 10)
  local StatResolver = require("mods.omni_ui.core.StatResolver")
  local st = StatResolver.getStats(mon, def, self.game)

  local statList
  if st.isSplit then
    statList = {
      { "ATTACK", st.attack },
      { "DEFENSE", st.defense },
      { "SP.ATK", st.spAttack },
      { "SP.DEF", st.spDefense },
      { "SPEED", st.speed },
    }
    for i, s in ipairs(statList) do
      local y = 70 + (i - 1) * 14
      Font.draw(Strings(s[1]), 8, y)
      Font.draw(("%3d"):format(s[2]), 52, y)
    end
  else
    statList = {
      { "ATTACK", st.attack },
      { "DEFENSE", st.defense },
      { "SPEED", st.speed },
      { "SPECIAL", st.special },
    }
    for i, s in ipairs(statList) do
      local y = 72 + (i - 1) * 16
      Font.draw(Strings(s[1]), 8, y)
      Font.draw(("%3d"):format(s[2]), 48, y + 8)
    end
  end

  -- TYPE1/TYPE2/IDNo/OT Box: drawLineBox(19, 9, 8, 6)
  drawLineBox(19, 9, 8, 6)
  Font.draw(Strings("TYPE1/"), 80, 72)
  Font.draw(def.types and def.types[1] and TypeChart.displayName(def.types[1], data) or "", 88, 80)
  if def.types and def.types[2] then
    Font.draw(Strings("TYPE2/"), 80, 88)
    Font.draw(TypeChart.displayName(def.types[2], data), 88, 96)
  end

  HudTiles.statusTile(0x73, 80, 104) -- <ID>
  HudTiles.statusTile(0x74, 88, 104) -- №
  Font.draw("/", 96, 104)
  local otId = mon.otId or (self.game.save and self.game.save.player and self.game.save.player.id) or 0
  Font.draw(("%05d"):format(otId), 96, 112)

  Font.draw(Strings("OT/"), 80, 120)
  local ot = mon.ot or (self.game.save and self.game.save.player and self.game.save.player.name) or "RED"
  Font.draw(ot, 96, 128)
end

function SummaryScreen:drawPage2(mon, def, data)
  drawLineBox(19, 1, 6, 10)
  Font.draw(Strings("EXP POINTS"), 72, 24)
  Font.draw(("%7d"):format(mon.exp or 0), 96, 32)
  Font.draw(Strings("LEVEL UP"), 72, 40)

  local nextExp = (mon.level or 1) < 100
    and (Growth.expForLevel(def.growthRate, (mon.level or 1) + 1) - (mon.exp or 0)) or 0
  Font.draw(("%7d"):format(math.max(0, nextExp)), 56, 48)

  if LevelDisplay.visible(mon, "summary", self.game) then
    HudTiles.statusTile(0x70, 112, 48) -- '<to>'
    printLevel(16, 6, math.min(100, (mon.level or 1) + 1))
  end

  -- Moves Box (0,8) 20x10
  Font.drawBox(0, 8, 20, 10)
  local moves = mon.moves or {}
  for i = 1, 4 do
    local mv = moves[i]
    local y = 72 + (i - 1) * 16
    local moveId = (type(mv) == "table" and mv.id) or mv
    if moveId and data and data.moves and data.moves[moveId] then
      local mdef = data.moves[moveId]
      Font.draw(mdef.name or moveId, 16, y)
      Font.draw(Strings("PP"), 88, y + 8)
      local maxPP = mdef.pp + ((type(mv) == "table" and mv.ppUps) or 0) * math.floor(mdef.pp / 5)
      local curPP = (type(mv) == "table" and mv.pp) or mdef.pp
      Font.draw(("%2d/%2d"):format(curPP, maxPP), 112, y + 8)
    else
      Font.draw("-", 16, y)
      Font.draw("--", 112, y + 8)
    end
  end
end

function SummaryScreen:drawPage3(mon, def, data)
  drawLineBox(19, 1, 6, 10)
  Font.draw(Strings("DETAILS"), 72, 24)

  Font.draw("GENDER/", 72, 40)
  Font.draw(mon.gender or "UNKNOWN", 128, 40)

  -- Details Box (0,8) 20x10
  Font.drawBox(0, 8, 20, 10)

  Font.draw("ABILITY/", 16, 72)
  Font.draw(mon.ability or "NONE", 80, 72)

  Font.draw("NATURE/", 16, 88)
  Font.draw(mon.nature or "HARDY", 80, 88)

  Font.draw("HELD ITEM/", 16, 104)
  Font.draw(mon.heldItem or mon.item or "NONE", 96, 104)

  local otId = mon.otId or (self.game.save and self.game.save.player and self.game.save.player.id) or 0
  Font.draw(("IDNo. %05d"):format(otId), 16, 120)
end

function SummaryScreen:close()
  if self.closing then return end
  self.closing = true
  if self.game and self.game.stack then
    if self.game.stack:top() == self then
      self.game.stack:pop()
    else
      self.game.stack:pop()
    end
  end
end

return SummaryScreen
