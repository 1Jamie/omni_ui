-- OmniUI Sprite & Palette Resolution Helper
-- Centralized resolver for front/back sprites, party icons, GBC/SGB color palettes,
-- mod hook dispatch (pokemon.sprite / pokemon.icon), and true-color detection.

local Sprites = require("src.pokemon.Sprites")
local PaletteFX = require("src.render.PaletteFX")
local Palettes = require("src.world.gen2.Palettes")
local Assets = require("src.render.Assets")

local SpriteHelper = {}

local imageCache = setmetatable({}, { __mode = "v" })

function SpriteHelper.getImage(path)
  if not path or path == "" then return nil end
  if imageCache[path] then return imageCache[path] end

  local img = nil
  if Assets and Assets.image then
    local ok, res = pcall(Assets.image, path)
    if ok and res then img = res end
  end
  if not img and love and love.graphics and love.graphics.newImage then
    local ok, res = pcall(love.graphics.newImage, path)
    if ok and res then img = res end
  end

  if img and img.setFilter then
    img:setFilter("nearest", "nearest")
    imageCache[path] = img
  end
  return img
end

-- Canonical species lookup across string keys, integer dex numbers, IDs, and defs
function SpriteHelper.resolveSpeciesDef(gameData, species)
  if not species then return nil, nil end
  local data = gameData or {}
  local pokemon = data.pokemon or {}

  local def = pokemon[species]
  local speciesKey = species
  if def then
    speciesKey = (type(species) == "string") and species or (def.species or def.name or def.id)
    return def, speciesKey
  end

  if type(species) == "number" then
    for k, d in pairs(pokemon) do
      if type(d) == "table" and (d.dex == species or d.id == species) then
        return d, (type(k) == "string" and k) or d.species or d.name or d.id
      end
    end
  end

  if type(species) == "string" then
    local up = species:upper()
    if pokemon[up] then return pokemon[up], up end
    for k, d in pairs(pokemon) do
      if type(d) == "table" and (d.name == species or d.name == up or d.id == species or d.id == up) then
        return d, (type(k) == "string" and k) or d.species or d.name or d.id
      end
    end
  end

  return nil, speciesKey
end

-- Resolves the 4-color palette for a Pokémon across all generations and mods
function SpriteHelper.getMonPalette(gameData, species, isShiny, mon)
  if not species then return nil end
  local data = gameData or {}
  local def, speciesKey = SpriteHelper.resolveSpeciesDef(data, species)
  local querySpecies = speciesKey or species or (mon and (mon.species or mon.speciesId))
  local spStr = tostring(querySpecies):upper()

  -- Check for Castform Forecast form palette
  local formSuffix = mon and (mon._krCastformForm or mon.form or mon.formSuffix)
  if not formSuffix and mon and mon.curTypes and mon.curTypes[1] and spStr == "CASTFORM" then
    local t = mon.curTypes[1]
    if t == "FIRE" then formSuffix = "sunny"
    elseif t == "WATER" then formSuffix = "rainy"
    elseif t == "ICE" then formSuffix = "snowy"
    end
  end
  if not formSuffix and spStr == "CASTFORM" then
    local okCast, CastformFx = pcall(require, "mods.Kanto-Reforged.battle.castform_fx")
    if okCast and CastformFx and CastformFx.activeSuffix then
      local okSuf, suf = pcall(CastformFx.activeSuffix, nil, mon)
      if okSuf and suf then formSuffix = suf end
    end
  end
  if formSuffix and spStr == "CASTFORM" then
    local palKey = "CASTFORM_" .. string.upper(formSuffix)
    local okKr, PaletteGen2 = pcall(require, "mods.Kanto-Reforged.pokemon.palette_gen2")
    if okKr and PaletteGen2 and PaletteGen2.colorsFor then
      local okColors, krColors = pcall(PaletteGen2.colorsFor, palKey)
      if okColors and type(krColors) == "table" then
        return krColors
      end
    end
  end

  -- 1. Check Gen 2 Palettes (gen2Palettes.pokemon[species])
  if data.gen2Palettes then
    local colors = Palettes.monColors(data.gen2Palettes, querySpecies, isShiny)
    if not colors and def and def.id then
      colors = Palettes.monColors(data.gen2Palettes, def.id, isShiny)
    end
    if not colors and spStr ~= querySpecies then
      colors = Palettes.monColors(data.gen2Palettes, spStr, isShiny)
    end
    if colors then return colors end
  end

  -- 2. Check Mod-specific palette resolvers (e.g. Kanto-Reforged)
  local okKr, PaletteGen2 = pcall(require, "mods.Kanto-Reforged.pokemon.palette_gen2")
  if okKr and PaletteGen2 and PaletteGen2.colorsFor then
    local okColors, krColors = pcall(PaletteGen2.colorsFor, querySpecies)
    if okColors and type(krColors) == "table" then
      return krColors
    end
    if spStr ~= querySpecies then
      local okColors2, krColors2 = pcall(PaletteGen2.colorsFor, spStr)
      if okColors2 and type(krColors2) == "table" then
        return krColors2
      end
    end
  end

  -- 3. Check Gen 1 / SGB / GBC Palettes via PaletteFX
  if PaletteFX and PaletteFX.monPal then
    local pal = PaletteFX.monPal(data, querySpecies)
    if not pal and def and def.id then
      pal = PaletteFX.monPal(data, def.id)
    end
    if not pal and spStr ~= querySpecies then
      pal = PaletteFX.monPal(data, spStr)
    end
    if pal then return pal end
  end

  -- 4. Check per-instance and per-species record custom palettes (mods)
  if mon then
    if type(mon.palette) == "table" and #mon.palette >= 4 then
      return mon.palette
    elseif type(mon.colors) == "table" and #mon.colors >= 4 then
      return mon.colors
    end
  end
  if def then
    if type(def.palette) == "table" and #def.palette >= 4 then
      return def.palette
    elseif type(def.colors) == "table" and #def.colors >= 4 then
      return def.colors
    end
  end

  return nil
end

-- Resolve sprite path, image, palette, and trueColor flag
function SpriteHelper.resolveSprite(gameData, species, side, opts)
  opts = opts or {}
  local data = gameData or {}
  side = (side == "back") and "back" or "front"

  local def, speciesKey = SpriteHelper.resolveSpeciesDef(data, species)
  local querySpecies = speciesKey or species or (opts.mon and (opts.mon.species or opts.mon.speciesId))
  local isEgg = (querySpecies == "EGG" or querySpecies == 253 or (opts.mon and opts.mon.isEgg))

  -- 1. Resolve path through Sprites.path (invokes Runtime hook 'pokemon.sprite' for external mods)
  local path, trueColor = nil, false
  if isEgg then
    path = (data.gen2MenuGfx and data.gen2MenuGfx.egg) or (def and (side == "back" and def.spriteBack or def.spriteFront))
  else
    path, trueColor = Sprites.path(data, querySpecies, side, {
      mon = opts.mon,
      kind = opts.kind or "battle",
    })
  end

  -- 2. If path is still nil, directly query Runtime hook 'pokemon.sprite'
  if not path and not isEgg then
    local Runtime = require("src.mods.Runtime")
    if Runtime and Runtime.wantsHook and Runtime.wantsHook("pokemon.sprite") then
      local ctx = {
        species = querySpecies,
        side = side,
        kind = opts.kind or "battle",
        mon = opts.mon,
        data = data,
        trueColor = false,
      }
      local hooked = Runtime.call("pokemon.sprite", function(p) return p end, "", ctx)
      if type(hooked) == "string" and hooked ~= "" then
        path = hooked
        trueColor = ctx.trueColor and true or false
      end
    end
  end

  -- 3. Fallback to definition / mon fields if path returned nil
  if not path and def then
    path = (side == "back") and def.spriteBack or def.spriteFront
    if def.trueColor then trueColor = true end
  end
  if not path and opts.mon and opts.mon.def then
    path = (side == "back") and opts.mon.def.spriteBack or opts.mon.def.spriteFront
    if opts.mon.def.trueColor then trueColor = true end
  end
  if not path and opts.mon and opts.mon.spriteFront then
    path = opts.mon.spriteFront
  end

  -- 4. Check candidate mod assets if still nil
  if not path and not isEgg and querySpecies then
    local spStr = tostring(querySpecies):upper()
    local spLower = tostring(querySpecies):lower()
    local candidatePaths = {
      "mods/Kanto-Reforged/assets/gs/" .. spStr .. "_" .. side .. ".png",
      "mods/Kanto-Reforged/assets/" .. spLower .. "_" .. side .. ".png",
      "assets/gs/" .. spStr .. "_" .. side .. ".png",
      "assets/" .. spLower .. "_" .. side .. ".png",
      "assets/generated/battle/" .. side .. "/" .. spLower .. ".png",
    }
    local Assets = require("src.render.Assets")
    for _, cp in ipairs(candidatePaths) do
      if (Assets and Assets.exists and Assets.exists(cp)) or (love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(cp)) then
        path = cp
        break
      end
    end
  end

  local img = path and SpriteHelper.getImage(path) or nil
  local isShiny = opts.isShiny or (opts.mon and opts.mon.isShiny) or false

  -- If sprite not found via asset paths, query Gen 3 engine if active
  if not img and not isEgg then
    local okP, G3Pokemon = pcall(require, "src.core.game3.pokemon")
    if okP and G3Pokemon then
      local spNum = tonumber(querySpecies) or (opts.mon and tonumber(opts.mon.species or opts.mon.speciesId))
      if not spNum and G3Pokemon.speciesFromName then
        spNum = G3Pokemon.speciesFromName(tostring(querySpecies))
      end
      if spNum then
        local pid = opts.mon and (opts.mon.personality or opts.mon.pid)
        local picEntry = nil
        if opts.kind == "party" or opts.kind == "icon" then
          picEntry = (opts.mon and G3Pokemon.monIcon and G3Pokemon.monIcon(opts.mon))
            or (G3Pokemon.icon and G3Pokemon.icon(spNum))
            or (G3Pokemon.frontPic and G3Pokemon.frontPic(spNum, 0, isShiny, pid))
        else
          if side == "back" and G3Pokemon.backPic then
            picEntry = (opts.mon and G3Pokemon.monBackPic and G3Pokemon.monBackPic(opts.mon)) or G3Pokemon.backPic(spNum, 0, isShiny)
          elseif G3Pokemon.monFrontPic and opts.mon then
            picEntry = G3Pokemon.monFrontPic(opts.mon)
          elseif G3Pokemon.frontPic then
            picEntry = G3Pokemon.frontPic(spNum, 0, isShiny, pid)
          end
        end
        if picEntry and picEntry.image then
          img = picEntry.image
          quad = picEntry.quads and picEntry.quads[0]
          entryW = picEntry.w
          entryH = picEntry.h
          trueColor = true
        end
      end
    end
  end

  local pal = nil
  if not trueColor and not isEgg then
    pal = SpriteHelper.getMonPalette(data, querySpecies, isShiny, opts.mon)
  end

  return {
    path = path,
    image = img,
    quad = quad,
    w = entryW,
    h = entryH,
    trueColor = trueColor,
    palette = pal,
    isEgg = isEgg,
    species = querySpecies,
    def = def,
  }
end

-- Draw a Pokémon front pic with proper palette shader & centering
function SpriteHelper.drawFrontPic(gameData, species, boxX, boxY, boxW, boxH, opts)
  opts = opts or {}
  local spriteInfo = SpriteHelper.resolveSprite(gameData, species, "front", opts)
  local img = spriteInfo.image

  if not img then
    if spriteInfo.isEgg then
      love.graphics.setColor(0.95, 0.88, 0.72, 1.0)
      love.graphics.circle("fill", boxX + math.floor(boxW / 2), boxY + math.floor(boxH / 2), math.floor(math.min(boxW, boxH) * 0.35))
      love.graphics.setColor(0.85, 0.75, 0.55, 1.0)
      love.graphics.setLineWidth(1.5)
      love.graphics.circle("line", boxX + math.floor(boxW / 2), boxY + math.floor(boxH / 2), math.floor(math.min(boxW, boxH) * 0.35))
    end
    return false
  end

  local quad = spriteInfo.quad
  local pw, ph
  if quad and spriteInfo.w and spriteInfo.h then
    pw, ph = spriteInfo.w, spriteInfo.h
  else
    pw, ph = img:getDimensions()
  end
  local scaleFactor = opts.scale
  if not scaleFactor then
    local margin = (opts.kind == "party" and quad) and 6 or 4
    local targetSize = math.min(boxW - margin, boxH - margin)
    scaleFactor = targetSize / math.max(pw, ph)
  end

  local targetW = pw * scaleFactor
  local targetH = ph * scaleFactor
  local px = boxX + math.floor((boxW - targetW) / 2)
  local py = boxY + math.floor((boxH - targetH) / 2)
  if opts.kind == "party" and quad then
    py = py - 1
  end

  local shader = PaletteFX and PaletteFX.shader and PaletteFX.shader()
  local pal = spriteInfo.palette
  local useShader = shader and pal and not spriteInfo.trueColor

  if useShader then
    love.graphics.setShader(shader)
    PaletteFX.sendColors(shader, pal)
  end

  love.graphics.setColor(1, 1, 1, opts.alpha or 1.0)
  if quad then
    love.graphics.draw(img, quad, px, py, 0, scaleFactor, scaleFactor)
  elseif spriteInfo.trueColor then
    love.graphics.draw(img, px, py, 0, scaleFactor, scaleFactor)
  else
    love.graphics.draw(img, px + targetW, py, 0, -scaleFactor, scaleFactor)
  end

  if useShader then
    love.graphics.setShader()
  end
  return true
end

return SpriteHelper
