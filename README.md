# OmniUI 0.5.0-beta

A modern UI overhaul framework for Pokémon Gen 1–3 recompilations (Mod API v2), by **Good Girl Software**.

OmniUI sits on top of the live engine stack. It does not fork menus: it reads the same states, hooks, and save data the carts already use, then redraws them as a unified overlay.

## 0.5.0-beta highlights

- **Full FireRed / LeafGreen screen coverage** across the unified Gen 1–3 UI (party, bag, summary, Pokédex, PC/storage, naming, options, shops, battle chrome, Hall of Fame, and the rest of the FRLG overlay set).
- **Gen 1 bag classification** so Red/Blue/Yellow inventory maps into the shared pocket UI instead of a single undifferentiated list.
- **Options integration** — cart option pages (FRLG and RSE) render inside Omni rather than as leftover native windows.
- **Battle HUD live state** — HP interpolation, party-ball pips, and status chrome follow engine battle anims instead of snapped snapshots.
- **Mobile / mouse hit testing** is deferred for a future update. Gamepad and keyboard remain the supported input paths in this beta.

---

## Theme Directory & Custom Themes

OmniUI features a dedicated themes directory at [`mods/omni_ui/themes/`](themes/). Developers can add new themes simply by creating a `.lua` file in `themes/` or extending an existing theme via `Theme.extend()`.

### Built-in Themes
- [`dark.lua`](themes/dark.lua) - Graphite surfaces, crisp contrast, sapphire accents (Default).
- [`kanto.lua`](themes/kanto.lua) - Fiery crimson accents with warm dark surfaces.
- [`emerald.lua`](themes/emerald.lua) - Jade and emerald forest tones with mint highlights.
- [`cyber.lua`](themes/cyber.lua) - Cyberpunk neon cyan/magenta with left-docked pause menu.
- [`classic.lua`](themes/classic.lua) - Monochrome Game Boy Pocket retro slate styling.

### Creating a Declarative Theme (Zero Math / Zero Render Code)
```lua
return {
  id = "synthwave",
  label = "Synthwave 80s",
  colors = {
    bg      = "#1B0B2B",
    surface = "#26143D",
    accent  = "#FF007F",
    text    = "#FFE3F1",
    hpGreen = "#00F0FF",
  },
  metrics = {
    radius = { card = 8, button = 6 },
  },
  layout = {
    dock = { align = "left", width = 300 },
  }
}
```

### Built-in UI Primitives
Developers can use or override high-level primitives without manual geometry math:
- `Layout.drawCard(x, y, w, h, opts)` - Surface container with border and radius tokens.
- `Layout.drawSlot(x, y, w, h, opts)` - Inset row slot inside cards.
- `Layout.drawButton(x, y, w, h, label, opts)` - Primary, accent, danger, and ghost buttons with left/right padding support.
- `Layout.drawBadge(x, y, text, opts)` - Status badges and notification tags.
- `Layout.drawPedestal(x, y, rx, ry, opts)` - Monster pedestal platform.
- `Layout.drawHealthBar(x, y, w, h, current, max, opts)` - Dynamic HP/Stat meters.
- `Layout.drawProgressBar(x, y, w, h, current, max, opts)` - Experience and progress bars.
- `Layout.drawDivider(x, y, w, opts)` - Subtle horizontal divider lines.
- `Layout.drawButtonHint(x, y, keyText, labelText, opts)` - Gamepad/keyboard prompt pill.
- `Layout.drawHintBar(x, y, w, h, hints, opts)` - Locked-spacing footer action bar.
- `Layout.drawText(text, x, y, opts)` / `Layout.drawTextWrapped(text, x, y, wrapLimit, opts)` - Vector typography.

---

## Mod Developer Public API (`PublicApi`)

Other mods can integrate seamlessly into OmniUI via `require("mods.omni_ui.api.PublicApi")`:

### 1. Menu & Screen Extension
- **Start / Pause Menu**:
  ```lua
  local PublicApi = require("mods.omni_ui.api.PublicApi")
  PublicApi.registerStartMenuItem({
    id = "quest_log",
    label = "QUESTS",
    badge = "3",          -- Optional notification tag
    kind = "primary",     -- "primary" | "accent" | "good" | "danger" | "ghost"
    insertAfter = "ITEM", -- Anchor placement
    onSelect = function(game) ... end,
  })
  ```
- **Game Settings / Options Menu**:
  ```lua
  PublicApi.registerOptionRow({
    id = "text_speed_turbo",
    label = "TURBO DIALOGUE",
    choices = { "OFF", "ON" },
    get = function() return ... end,
    set = function(val) ... end,
  })
  ```
- **Pokémon Summary Page Tabs**:
  ```lua
  PublicApi.registerSummaryTab({
    id = "ev_iv_inspector",
    label = "EV / IV",
    draw = function(game, mon, rx, ry, rw, rh, theme)
      -- Render custom summary panel with full theme access
    end,
  })
  ```
- **Bag / Inventory Pockets**:
  ```lua
  PublicApi.registerBagPocket({
    id = "held_items",
    label = "HELD ITEMS",
    filter = function(itemId, itemDef) return itemDef.isHoldable end,
  })
  ```
- **Party Context Submenu**:
  ```lua
  PublicApi.registerPartyAction({
    id = "pet_mon",
    label = "PET POKÉMON",
    onSelect = function(game, mon, partyIndex) ... end,
  })
  ```
- **Completely Custom UI Screens**:
  ```lua
  PublicApi.registerScreen("my_mod_screen", {
    match = function(state) return state.isMyModScreen == true end,
    draw = function(game, state, w, h, theme, subState, animProgress)
      -- Draw custom UI with modern cards, slots, buttons, and theme colors
    end,
  })
  ```

### 2. Lifecycle Render Hooks
```lua
-- Intercept before or after screen rendering for overlays, telemetry, or custom HUDs
PublicApi.onPreRender("battle", "my_hud_pre", function(game, state, w, h, theme) ... end)
PublicApi.onPostRender("battle", "my_hud_post", function(game, state, w, h, theme) ... end)
```

### 3. Sandboxed Execution (`HookBoundary`)
External mod renderers and callbacks are protected by `HookBoundary`, preventing third-party Lua crashes or unpopped graphics matrix states from disrupting the core game.

---

## Mod Hooks & API

Third-party mods should treat Omni as a **presenter**, not a second engine. Cart menus, scripts, and other mods keep owning state. Omni classifies that state, normalizes data through a generation adapter, and paints.

### Engine primitives and emulated hooks

Omni attaches with the same Mod API v2 wrap points the rest of the loader uses. Typical seams:

| Seam | What Omni does |
| --- | --- |
| `render.hud` | Calls `next(game, viewport)` first (native / other mods draw), then paints the overlay. |
| `ui.start_menu.items` | Runs `next`, then injects `PublicApi.startMenuItems`. |
| `ui.options.rows`, `ui.party.submenu` | Same pattern for options rows and party actions. |
| `battle.status_hud_visible` / `battle.bottom_ui_visible` | Hides leftover native battle chrome while Omni’s HUD is live. |
| `pokemon.sprite` / `pokemon.icon` | SpriteHelper resolves party/box/summary art through these hooks and `icons.bySpecies`, so replacement packs and added species show up without Omni-specific wiring. |
| `input.key` | Theme cycle (F6/F7) and overlay-aware input; always falls through with `nextFn`. |

`ModernOverlay.isSupported(state)` maps engine stack objects (`PartyMenu`, `Game3Bag`, FRLG naming, Choice boxes, …) onto overlay kinds. Anything it does not recognize is **not** rewritten.

Art and species records go through the engine’s live hooks rather than frozen `spriteFront` paths, so a mod that wraps `pokemon.sprite` or registers `icons.bySpecies` is absorbed automatically.

### Injecting extra menu entries

Prefer `PublicApi` over patching StartMenu tables:

```lua
local PublicApi = require("mods.omni_ui.api.PublicApi")

PublicApi.registerStartMenuItem({
  id = "quest_log",
  label = "QUESTS",
  insertAfter = "ITEM",
  onSelect = function(game)
    game.stack:push({
      isMyModScreen = true,
      screenId = "my_mod_screen",
      isMenu = true,
    })
  end,
})
```

Injection is applied after the engine’s `ui.start_menu.items` chain, so Gen 1 StartMenu, Gen 2 pause, and FRLG/RSE start lists all receive the same extra row. Use `insertBefore` / `insertAfter` against cart labels (`POKEMON`, `ITEM`, `SAVE`, …). `registerOptionRow`, `registerBagPocket`, `registerPartyAction`, and `registerSummaryTab` follow the same “append to the unified chrome” rule.

To draw a full custom page in Omni’s theme, register the screen and push a state that `match` accepts (`registerScreen` example above).

### Yielding to custom third-party screens

Omni **yields** whenever the top of the stack is not an overlay kind:

1. `getActiveScreen` walks `game.stack` (Gen 1/2) or the Gen 3 UI stack.
2. If the top state is an independent screen and `isSupported` returns false — minigames, intro movies, title, Quest Log, wireless, RTC warnings, or **your** unregistered menu — Omni returns `nil` and **does not draw**.
3. `render.hud` has already called `next(...)`, so the native or third-party `state:draw` runs unobscured.
4. Child modals (Choice / Text / quantity boxes) still attach to a supported parent; a full-screen foreign menu on top of StartMenu hides the pause dock instead of compositing both.

To opt **in** to Omni chrome, `registerScreen` with a `match` function. To keep a private UI, push a stack state Omni does not know and do not register it — Omni yields.

Pass-through ids (never overdrawn) include `SlotMachine`, `CardFlip`, `UnownPuzzle`, `QuestLog`, intro/title movies, and battery/RTC/clear-save warnings.

### Data adapters for cross-mod interaction

UI widgets never read cart memory directly. They talk to an adapter from `AdapterResolver.resolve(game)`:

- **Gen 1** (`Gen1Adapter`) — species string ids, DV shininess, field moves, 20-slot boxes.
- **Gen 2** (`Gen2Adapter`) — Unown forms, held items, Pokérus, 4-pocket bag, RTC.
- **Gen 3 / FRLG** (`Gen3Adapter`) — internal SPECIES integers, personality, abilities, 30-slot boxes, FRLG vs RSE bags.

`BaseAdapter.normalizeMon` is the contract other mods should return:

```lua
{
  index = 1,
  speciesId = "PIKACHU",   -- or a Gen 3 SPECIES number
  displayName = "PIKACHU",
  nickname = "SPARKY",
  level = 18,
  hp = 42, currentHp = 42, maxHp = 55,
  types = { "ELECTRIC" },
  moves = { ... },
  raw = mon,               -- original engine object
}
```

**FRLG / Gen 3 — wrap the engine mon, keep `raw`:**

```lua
local BaseAdapter = require("mods.omni_ui.adapters.BaseAdapter")
local FRLG = setmetatable({}, { __index = BaseAdapter })
FRLG.__index = FRLG

function FRLG.new(game)
  local self = BaseAdapter.new(game)
  self.generation = 3
  return setmetatable(self, FRLG)
end

function FRLG:normalizeMon(mon, index)
  local Pokemon = require("src.core.game3.pokemon")
  local sp = Pokemon.speciesOf(mon)
  local norm = BaseAdapter.normalizeMon(self, mon, index)
  norm.speciesId = sp
  norm.species = sp
  norm.displayName = Pokemon.name(sp) or norm.displayName
  norm.raw = mon
  return norm
end
```

**Gen 2 — DVs, Unown, held items:**

```lua
local BaseAdapter = require("mods.omni_ui.adapters.BaseAdapter")
local GSC = setmetatable({}, { __index = BaseAdapter })
GSC.__index = GSC

function GSC.new(game)
  local self = BaseAdapter.new(game)
  self.generation = 2
  return setmetatable(self, GSC)
end

function GSC:normalizeMon(mon, index)
  local norm = BaseAdapter.normalizeMon(self, mon, index)
  local Stats = require("src.pokemon.Stats")
  norm.isShiny = Stats.isShiny(mon.dvs) and true or false
  norm.heldItem = mon.item or mon.heldItem
  if mon.species == "UNOWN" then
    local Unown = require("src.pokemon.Unown")
    norm.form = Unown.monLetter(mon)
  end
  return norm
end
```

**Legacy v1 registration** (`gen1_modern_ui` compat):

Keep your existing `gen1ModernUi` screens table. In the other mod, depend on `omni_ui` and point find at it. `registerAdapter` / `adopt` publish through Omni `registerScreen`. Native Omni bag/summary/party wins when both exist; unique v1 screens still use the legacy overlay.

```lua
-- optional_dependencies: ["omni_ui"]  (was gen1_modern_ui)
local ui = mod.find("omni_ui") or mod.find("gen1_modern_ui")
if ui and ui.exports then
  -- either keep the old call:
  ui.exports.registerAdapter({ owner = mod.id, contract = mod.exports.gen1ModernUi })
  -- or the one-liner:
  -- ui.exports.adopt(mod)
end
```

New content (species, icons, moves) should land in the engine registries / `pokemon.sprite` / `pokemon.icon` hooks. Omni’s adapters and SpriteHelper will pick them up on the next draw; you do not need a private Omni sprite table.

---

## Support / Donation

OmniUI is developed by **Good Girl Software**. If you want to support the work:

- GitHub Sponsors: https://github.com/sponsors/1Jamie
- Ko-fi: https://ko-fi.com/1jamie
