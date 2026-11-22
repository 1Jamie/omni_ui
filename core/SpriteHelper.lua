-- OmniUI Sprite & Palette Resolution Helper
-- Centralized resolver for front/back sprites, party icons, GBC/SGB color palettes,
-- mod hook dispatch (pokemon.sprite / pokemon.icon), and true-color detection.

local Sprites = require("src.pokemon.Sprites")
local PaletteFX = require("src.render.PaletteFX")
local Palettes = require("src.world.gen2.Palettes")
local Assets = require("src.render.Assets")

local SpriteHelper = {}

SpriteHelper.mod = nil

function SpriteHelper.setMod(modHandle)
  SpriteHelper.mod = modHandle
end

function SpriteHelper.getG9Exports()
  local mod = SpriteHelper.mod
  if not mod then return nil end
  if type(mod.find) == "function" then
    local ok, handle = pcall(mod.find, mod, "g9-battle-sprites")
    if not ok or not handle then
      ok, handle = pcall(mod.find, "g9-battle-sprites")
    end
    if ok and handle and handle.exports then
      return handle.exports
    end
  end
  if mod.loader and mod.loader.exports and mod.loader.exports["g9-battle-sprites"] then
    return mod.loader.exports["g9-battle-sprites"]
  end
  if mod.exports and mod.exports["g9-battle-sprites"] then
    return mod.exports["g9-battle-sprites"]
  end
  return nil
end

local imageCache = setmetatable({}, { __mode = "v" })

-- Host cart generation for art policy. Gen 3 PC/party uses 32×64 icon
-- sheets; Gen 1/2 Bill's PC is supposed to draw the species front pic.
-- Never infer Gen 3 from `require("src.core.game3.pokemon")` succeeding —
-- that module is always on disk and will happily resolve "DIGLETT".
function SpriteHelper.hostGeneration(gameData, opts)
  opts = opts or {}
  local gen = tonumber(opts.generation)
  if gen then return gen end
  local mon = opts.mon
  if type(mon) == "table" then
    gen = tonumber(mon.generation)
    if gen then return gen end
  end
  local data = gameData or {}
  gen = tonumber(data.generation)
  if gen then return gen end
  if data.gen2Palettes or data.gen2Icons or data.gen2MenuGfx then return 2 end
  local okGV, GV = pcall(require, "src.core.GameVersion")
  if okGV and GV and type(GV.generation) == "function" then
    local okG, g = pcall(GV.generation)
    if okG then
      gen = tonumber(g)
      if gen then return gen end
    end
  end
  return nil
end

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

-- Same lookup PartyMenu uses: icons.bySpecies / def.icon / icons.byDex.
function SpriteHelper.vanillaIconPath(gameData, species, def)
  local data = gameData or {}
  local icons = data.icons
  local entry = (icons and icons.bySpecies and species and icons.bySpecies[species])
    or (def and def.icon)
  local name, path, trueColor
  if type(entry) == "string" then
    name = entry
    path = icons and icons.icons and icons.icons[entry]
  elseif type(entry) == "table" then
    path = entry.image
    trueColor = entry.trueColor and true or false
  end
  if not path and def and def.dex and icons and icons.byDex then
    name = icons.byDex[def.dex]
    path = name and icons.icons and icons.icons[name]
  end
  return path, trueColor, name
end

local function adoptIconSheet(img, trueColorFlag)
  if not img then return nil end
  local iw, ih = 32, 32
  if img.getDimensions then
    iw, ih = img:getDimensions()
  end
  local cellW, cellH = iw, ih
  if iw and ih and ih >= (iw * 2) - 2 then
    cellH = math.floor(ih / math.max(2, math.floor(ih / math.max(iw, 1) + 0.5)))
  end
  local quad
  if cellH and cellH < ih and love and love.graphics and love.graphics.newQuad then
    local okQ, cropQ = pcall(love.graphics.newQuad, 0, 0, cellW, cellH, iw, ih)
    if okQ then quad = cropQ end
  end
  return img, quad, cellW, cellH, trueColorFlag and true or false
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
  local vanillaFront = def and ((side == "back") and def.spriteBack or def.spriteFront) or nil
  local spriteHooked = false
  if isEgg then
    path = (data.gen2MenuGfx and data.gen2MenuGfx.egg) or vanillaFront
  else
    path, trueColor = Sprites.path(data, querySpecies, side, {
      mon = opts.mon,
      kind = opts.kind or "battle",
    })
    if path and vanillaFront and path ~= vanillaFront then spriteHooked = true end
  end

  -- 2. If path is still nil, directly query Runtime hook 'pokemon.sprite'
  -- (new species with no def still get a chance to supply art)
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
        spriteHooked = true
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

  local isShiny = opts.isShiny or (opts.mon and opts.mon.isShiny) or false
  local img, quad, entryW, entryH = nil, nil, nil, nil
  local gen = SpriteHelper.hostGeneration(data, opts)
  local isGen3 = gen == 3
  local wantIcon = opts.kind == "party" or opts.kind == "icon"

  -- Live pokemon.icon / icons.bySpecies seam. Gen 3 party and PC use this;
  -- a replacement here must win over g9 convenience exports.
  local iconHooked = false
  if isGen3 and wantIcon and side == "front" then
    local vanillaIcon, iconTC, iconName = SpriteHelper.vanillaIconPath(data, querySpecies, def)
    local iconMon = opts.mon
    if type(iconMon) ~= "table" then
      iconMon = { species = querySpecies }
    end
    local hookedIcon, hookedTC = Sprites.iconPath(data, iconMon, vanillaIcon, {
      name = iconName,
      trueColor = iconTC,
    })
    local iconSeamPath = hookedIcon or vanillaIcon
    if hookedIcon and hookedIcon ~= vanillaIcon then iconHooked = true end
    if iconSeamPath then
      local loaded = SpriteHelper.getImage(iconSeamPath)
      if loaded then
        img, quad, entryW, entryH, trueColor = adoptIconSheet(loaded, hookedTC or iconTC or true)
      end
    end
  end

  local function applyG9Icon(q, atlas, cell, box)
    if not (atlas and q) then return false end
    img = atlas
    trueColor = true
    local fullQuad = q.full or q
    if box and box.w and box.w > 0 and box.h and box.h > 0 and love and love.graphics and love.graphics.newQuad then
      local qx = fullQuad.x or (fullQuad.getViewport and select(1, fullQuad:getViewport())) or 0
      local qy = fullQuad.y or (fullQuad.getViewport and select(2, fullQuad:getViewport())) or 0
      local aw, ah = atlas.getDimensions and atlas:getDimensions() or 2048, 2048
      local okQ, cropQ = pcall(love.graphics.newQuad, qx + box.x, qy + box.y, box.w, box.h, aw, ah)
      if okQ and cropQ then
        quad = cropQ
        entryW, entryH = box.w, box.h
        return true
      end
    end
    quad = fullQuad
    entryW, entryH = cell or 64, cell or 64
    return true
  end

  -- Gen 3 engine. Gen3Compat wrapPics/wrapIcons already raise pokemon.sprite
  -- and pokemon.icon plus icons.bySpecies, so this is the live seam native
  -- party/PC uses — not a bypass.
  if not img and isGen3 and not isEgg then
    local okP, G3Pokemon = pcall(require, "src.core.game3.pokemon")
    if okP and G3Pokemon then
      local spNum = tonumber(querySpecies) or (opts.mon and tonumber(opts.mon.species or opts.mon.speciesId))
      if not spNum and G3Pokemon.speciesFromName then
        spNum = G3Pokemon.speciesFromName(tostring(querySpecies))
      end
      if not spNum and G3Pokemon.speciesOf and opts.mon then
        spNum = G3Pokemon.speciesOf(opts.mon)
      end
      if spNum then
        local engineMon = opts.mon
        if type(engineMon) == "table" and type(engineMon.raw) == "table" then
          engineMon = engineMon.raw
        end
        local pid = (engineMon and (engineMon.personality or engineMon.pid))
          or (opts.mon and (opts.mon.personality or opts.mon.pid))
        local picEntry = nil
        if wantIcon then
          picEntry = (engineMon and G3Pokemon.monIcon and G3Pokemon.monIcon(engineMon))
            or (G3Pokemon.icon and G3Pokemon.icon(spNum))
        end
        if not picEntry then
          if side == "back" and G3Pokemon.backPic then
            picEntry = (engineMon and G3Pokemon.monBackPic and G3Pokemon.monBackPic(engineMon)) or G3Pokemon.backPic(spNum, 0, isShiny)
          elseif G3Pokemon.monFrontPic and engineMon then
            picEntry = G3Pokemon.monFrontPic(engineMon)
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

  -- g9-battle-sprites publishes in-memory sheets that cannot travel through
  -- the path-only pokemon.sprite / pokemon.icon hooks. Use them only when
  -- those hooks (and the Gen 3 engine) did not already supply art.
  if not img and not iconHooked and not spriteHooked and side == "front" then
    local g9 = SpriteHelper.getG9Exports and SpriteHelper.getG9Exports()
    if g9 then
      local monParam = opts.mon
      if type(monParam) ~= "table" then
        monParam = {
          species = tostring(querySpecies):upper(),
          shiny = isShiny,
          isEgg = isEgg,
        }
      elseif not monParam.species then
        monParam = {
          species = tostring(querySpecies):upper(),
          shiny = isShiny,
          isEgg = isEgg or monParam.isEgg,
          dvs = monParam.dvs,
          gender = monParam.gender,
        }
      end

      if isGen3 and wantIcon then
        if g9.iconArtHD then
          applyG9Icon(g9.iconArtHD(monParam))
        end
        if not img and g9.iconArt16 then
          local q, atlas, cell = g9.iconArt16(monParam)
          if atlas and q then
            img = atlas
            quad = q.full or q
            entryW, entryH = cell or 16, cell or 16
            trueColor = true
          end
        end
      elseif g9.frontArt then
        local fImg, fw, fh = g9.frontArt(monParam)
        if fImg then
          img = fImg
          entryW, entryH = fw, fh
          trueColor = true
          local iw, ih
          if fImg.getDimensions then
            iw, ih = fImg:getDimensions()
          end
          if fw and fh and iw and ih and (iw > fw or ih > fh)
              and love and love.graphics and love.graphics.newQuad then
            local okQ, cropQ = pcall(love.graphics.newQuad, 0, 0, fw, fh, iw, ih)
            if okQ and cropQ then quad = cropQ end
          end
        end
      end
    end
  end

  if not img then
    img = path and SpriteHelper.getImage(path) or nil
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
    -- Two-frame Gen 3 / menu icon sheets are stored as W×2H. Drawing the
    -- whole strip is the "cut and wrapped" box art bug.
    local cellW = spriteInfo.w or pw
    local cellH = spriteInfo.h
    if not quad and pw and ph and ph >= pw * 2 - 2 then
      cellH = cellH or math.floor(ph / math.max(2, math.floor(ph / pw + 0.5)))
      if cellH > 0 and cellH < ph and love and love.graphics and love.graphics.newQuad then
        local okQ, cropQ = pcall(love.graphics.newQuad, 0, 0, math.min(cellW, pw), cellH, pw, ph)
        if okQ and cropQ then
          quad = cropQ
          pw, ph = math.min(cellW, pw), cellH
        end
      end
    elseif not quad and spriteInfo.w and spriteInfo.h and (pw > spriteInfo.w or ph > spriteInfo.h)
        and love and love.graphics and love.graphics.newQuad then
      local okQ, cropQ = pcall(love.graphics.newQuad, 0, 0, spriteInfo.w, spriteInfo.h, pw, ph)
      if okQ and cropQ then
        quad = cropQ
        pw, ph = spriteInfo.w, spriteInfo.h
      end
    end
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
