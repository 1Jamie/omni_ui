package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local ModernOverlay = require("mods.omni_ui.core.ModernOverlay")
local BagRenderer = require("mods.omni_ui.renderers.BagRenderer")
local Theme = require("mods.omni_ui.core.Theme")
local BerryPouch = require("src.ui.game3.berry_pouch")
local Stack = require("src.ui.game3.stack")

T.eq(ModernOverlay.isSupported({ screenId = "berry_pouch", isMenu = true }), "bag",
  "Berry pouch screenId routes to bag, not generic menu")
T.eq(ModernOverlay.isSupported({ isMenu = true }), "menu",
  "A generic isMenu state still routes to menu")
T.eq(ModernOverlay.isSupported({ isMenu = true, _plantMode = true, list = function() return {} end }), "bag",
  "Kanto-Reforged plant-mode pouch routes to bag")

local prevLayers = Stack._layers
local prevOpen = BerryPouch.open
Stack._layers = { { id = "berry_pouch", mod = BerryPouch, hideBelow = true, fullscreen = true } }
BerryPouch.open = true
BerryPouch._plantMode = true
BerryPouch._location = "berry_tree"
BerryPouch.location = "berry_tree"
BerryPouch.ACTIONS = { "PLANT", "CANCEL" }
BerryPouch.mode = "list"
BerryPouch.cursor = 1
BerryPouch._bag = { pockets = { BERRY_POUCH = { { id = "ORAN_BERRY", qty = 3 } } } }

T.eq(ModernOverlay.isSupported(BerryPouch), "bag", "Live BerryPouch module is a bag overlay")
local kind, active = ModernOverlay.getActiveScreen({ phase = "field" })
T.eq(kind, "bag", "getActiveScreen maps berry_pouch stack layer to bag")
T.eq(active, BerryPouch, "getActiveScreen returns the BerryPouch module")

local plantState = {
  screenId = "berry_pouch",
  _plantMode = true,
  location = "berry_tree",
  mode = "action",
  actionCursor = 1,
  ACTIONS = { "PLANT", "CANCEL" },
  cursor = 1,
  list = function() return { { id = "ORAN_BERRY", name = "ORAN BERRY", qty = 3 } } end,
}
local okDraw = pcall(BagRenderer.draw, { gameVersion = "firered", save = {}, data = Data }, plantState, 800, 600, Theme.get(), nil, 1)
T.eq(okDraw, true, "BagRenderer draws planting berry pouch without error")

BerryPouch.open = prevOpen
BerryPouch._plantMode = false
BerryPouch._location = nil
BerryPouch.location = nil
BerryPouch.ACTIONS = { "USE", "GIVE", "TOSS", "EXIT" }
Stack._layers = prevLayers

do
  local Choice = require("src.ui.game3.choice")
  local DialogueRenderer = require("mods.omni_ui.renderers.DialogueRenderer")
  local Layout = require("mods.omni_ui.core.Layout")
  local Message = require("src.ui.game3.message")
  local prevMsgOpen = Message.open
  local prevChoiceActive = Choice.active
  Message.open = false
  Choice.reset()
  Choice.active = true
  Choice.kind = "yesno"
  Choice.options = { "YES", "NO" }
  Choice.cursor = 1
  Choice.done = function() end

  local kind, active = ModernOverlay.getActiveScreen({ phase = "field", player = { y = 12 } })
  T.eq(kind, "dialogue", "Choice-only field prompt is still a dialogue overlay")
  T.eq(active, Choice, "Choice module is the dialogue state when Message is closed")

  local closeHint = false
  local origHint = Layout.drawButtonHint
  Layout.drawButtonHint = function(_, _, btn, label, ...)
    if btn == "A" and label == "Close" then closeHint = true end
    if origHint then return origHint(_, _, btn, label, ...) end
  end
  local origCard = Layout.drawCard
  local cards = 0
  Layout.drawCard = function(...)
    cards = cards + 1
    if origCard then return origCard(...) end
  end
  local origSlot = Layout.drawSlot
  Layout.drawSlot = function(...)
    if origSlot then return origSlot(...) end
  end
  local origText = Layout.drawText
  Layout.drawText = function(...)
    if origText then return origText(...) end
  end
  local origBadge = Layout.drawBadge
  Layout.drawBadge = function(...)
    if origBadge then return origBadge(...) end
  end

  local okChoiceDraw = pcall(DialogueRenderer.draw, { phase = "field", player = { y = 12 } }, Choice, 800, 600, Theme.get())
  Layout.drawButtonHint = origHint
  Layout.drawCard = origCard
  Layout.drawSlot = origSlot
  Layout.drawText = origText
  Layout.drawBadge = origBadge
  T.eq(okChoiceDraw, true, "Choice-only overlay draws without error")
  T.eq(closeHint, false, "Choice-only overlay does not flash empty A Close")
  T.eq(cards > 0, true, "Choice-only overlay still draws the YES/NO modal")

  -- Held plant prompt: message text stays, yes/no is subState, no A Close.
  closeHint = false
  Layout.drawButtonHint = function(_, _, btn, label, ...)
    if btn == "A" and label == "Close" then closeHint = true end
    if origHint then return origHint(_, _, btn, label, ...) end
  end
  local heldMsg = {
    _pages = { "It's soft, loamy soil.\nWould you like to plant a BERRY?" },
    _page = 1,
    _waiting = true,
    _hold = true,
    _held = true,
    open = true,
  }
  local okHeld = pcall(DialogueRenderer.draw, { phase = "field", player = { y = 12 } }, heldMsg, 800, 600, Theme.get(), Choice)
  Layout.drawButtonHint = origHint
  T.eq(okHeld, true, "Held plant prompt with YES/NO draws")
  T.eq(closeHint, false, "Held plant prompt does not show A Close over YES/NO")

  Choice.reset()
  Message.open = prevMsgOpen
  if prevChoiceActive then Choice.active = prevChoiceActive end
end

T.finish("omni_ui_berry_pouch_overlay")
