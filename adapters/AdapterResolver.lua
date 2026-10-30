-- OmniUI Adapter Resolver
-- Detects the host engine generation and returns the specialized adapter.

local Gen1Adapter = require("mods.omni_ui.adapters.Gen1Adapter")
local Gen2Adapter = require("mods.omni_ui.adapters.Gen2Adapter")
local Gen3Adapter = require("mods.omni_ui.adapters.Gen3Adapter")

local AdapterResolver = {}

function AdapterResolver.resolve(game)
  -- 1. Check game instance's explicit gameVersion / cart / save
  local version = game and (game.gameVersion or (game.cart and game.cart.gameVersion) or game.version)
  if version then
    version = tostring(version):lower()
    if version == "firered" or version == "leafgreen" or version == "emerald" or version == "ruby" or version == "sapphire" then
      return Gen3Adapter.new(game)
    elseif version == "gold" or version == "silver" or version == "crystal" then
      return Gen2Adapter.new(game)
    elseif version == "red" or version == "blue" or version == "yellow" then
      return Gen1Adapter.new(game)
    end
  end

  -- 2. Check engine GameVersion global state if present
  local okGV, GV = pcall(require, "src.core.GameVersion")
  if okGV and GV then
    local gvGen = (GV.generation and GV.generation())
    local gvName = (GV.get and GV.get())
    if gvGen == 2 or gvName == "gold" or gvName == "silver" or gvName == "crystal" then
      return Gen2Adapter.new(game)
    elseif gvGen == 3 or gvName == "firered" or gvName == "leafgreen" or gvName == "emerald" or gvName == "ruby" or gvName == "sapphire" then
      return Gen3Adapter.new(game)
    elseif gvGen == 1 or gvName == "red" or gvName == "blue" or gvName == "yellow" then
      return Gen1Adapter.new(game)
    end
  end

  -- 3. Check game instance's own save/data structures
  if game then
    local data = game.data or {}
    local save = game.save
    local player = save and save.player
    if data.gen2Palettes or data.gen2Icons or (save and (
        save.generation == 2 or save.johtoBadges or save.kantoBadges
        or save.momMoney or save.mom or save.phoneContacts
        or (player and player.kantoBadges))) then
      return Gen2Adapter.new(game)
    end
    if (game.save and (game.save.session or game.save.game3)) or game.session then
      return Gen3Adapter.new(game)
    end
    if package.loaded["src.ui.game3.party_menu"] and (package.loaded["src.ui.game3.party_menu"].open or package.loaded["src.ui.game3.party_menu"]._party) then
      return Gen3Adapter.new(game)
    end
    local mt = getmetatable(game)
    local g2 = package.loaded["src.core.Game2"]
    if g2 and (mt == g2 or game == g2) then
      return Gen2Adapter.new(game)
    end
    local g3 = package.loaded["src.core.Game3"]
    if g3 and (mt == g3 or game == g3) then
      return Gen3Adapter.new(game)
    end
  end

  if (package.loaded["src.ui.game3.party_menu"] and (package.loaded["src.ui.game3.party_menu"].open or package.loaded["src.ui.game3.party_menu"]._party))
    or (package.loaded["src.ui.game3.rse.pokedex"] and package.loaded["src.ui.game3.rse.pokedex"].active and package.loaded["src.ui.game3.rse.pokedex"].active())
    or (package.loaded["src.ui.game3.pokedex"] and (package.loaded["src.ui.game3.pokedex"].isOpen and package.loaded["src.ui.game3.pokedex"].isOpen() or package.loaded["src.ui.game3.pokedex"].open))
    or (package.loaded["src.ui.game3.pc_menu"] and (package.loaded["src.ui.game3.pc_menu"].isOpen and package.loaded["src.ui.game3.pc_menu"].isOpen() or package.loaded["src.ui.game3.pc_menu"].open or package.loaded["src.ui.game3.pc_menu"]._session))
    or (package.loaded["src.ui.game3.item_pc"] and (package.loaded["src.ui.game3.item_pc"].isOpen and package.loaded["src.ui.game3.item_pc"].isOpen() or package.loaded["src.ui.game3.item_pc"].open or package.loaded["src.ui.game3.item_pc"]._session or package.loaded["src.ui.game3.item_pc"]._bag))
    or (package.loaded["src.ui.game3.bag_menu"] and (package.loaded["src.ui.game3.bag_menu"].isOpen and package.loaded["src.ui.game3.bag_menu"].isOpen() or package.loaded["src.ui.game3.bag_menu"].open or package.loaded["src.ui.game3.bag_menu"]._session or package.loaded["src.ui.game3.bag_menu"]._bag))
    or (package.loaded["src.ui.game3.box_storage_ui"] and package.loaded["src.ui.game3.box_storage_ui"].open)
    or (package.loaded["src.ui.game3.stack"] and package.loaded["src.ui.game3.stack"].has and (package.loaded["src.ui.game3.stack"].has("rse_pokedex") or package.loaded["src.ui.game3.stack"].has("rs_pokedex") or package.loaded["src.ui.game3.stack"].has("pokedex") or package.loaded["src.ui.game3.stack"].has("party") or package.loaded["src.ui.game3.stack"].has("summary") or package.loaded["src.ui.game3.stack"].has("bag") or package.loaded["src.ui.game3.stack"].has("box_storage") or package.loaded["src.ui.game3.stack"].has("pc_menu") or package.loaded["src.ui.game3.stack"].has("item_pc"))) then
    return Gen3Adapter.new(game)
  end

  return Gen1Adapter.new(game)
end

return AdapterResolver
