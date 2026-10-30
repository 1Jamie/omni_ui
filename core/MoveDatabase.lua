-- OmniUI Move Database & Metadata Inspector
-- Provides canonical move descriptions, damage class categories (Physical/Special/Status),
-- tactical effect tags, and extensible provider hooks across Gen 1-3 and modded games (e.g. Kanto Reforged).

local MoveDatabase = {}

-- Mod-registered moves and custom providers
local registeredMoves = {}
local descriptionProviders = {}

--- Registers a custom move definition or override from a mod.
--- @param moveId string Unique move identifier (e.g., "BLAZE_KICK" or "CUSTOM_STRIKE")
--- @param moveDef table { name=string, type=string, power=number, accuracy=number, pp=number, category=string, description=string, effectTag=string }
function MoveDatabase.registerMove(moveId, moveDef)
  if not moveId or not moveDef then return false end
  registeredMoves[tostring(moveId):upper()] = moveDef
  return true
end

--- Batch registers custom move definitions.
--- @param movesTable table Table of moveId -> moveDef
function MoveDatabase.registerMoves(movesTable)
  if type(movesTable) ~= "table" then return false end
  for k, v in pairs(movesTable) do
    MoveDatabase.registerMove(k, v)
  end
  return true
end

--- Registers a dynamic move description provider hook.
--- @param providerFn function(moveId, moveDef, game): string|nil
function MoveDatabase.registerDescriptionProvider(providerFn)
  if type(providerFn) == "function" then
    descriptionProviders[#descriptionProviders + 1] = providerFn
    return true
  end
  return false
end

-- =========================================================================
-- Canonical Move Descriptions (Gen 1, Gen 2, and Gen 3)
-- =========================================================================
local MOVE_DESCRIPTIONS = {
  -- Gen 1 Classics
  POUND = "Pounds the target with forelegs or tail.",
  KARATE_CHOP = "A sharp, chopping strike with a high critical-hit ratio.",
  DOUBLESLAP = "Slaps the foe repeatedly 2 to 5 times in a row.",
  COMET_PUNCH = "Repeatedly punches the target 2 to 5 times in a single turn.",
  MEGA_PUNCH = "A powerful punch thrown with incredible force.",
  PAY_DAY = "Scatters coins across the field that can be collected after battle.",
  FIRE_PUNCH = "Strikes with a fiery punch. Has a 10% chance to burn.",
  ICE_PUNCH = "Strikes with an icy punch. Has a 10% chance to freeze.",
  THUNDERPUNCH = "Strikes with an electric punch. Has a 10% chance to paralyze.",
  SCRATCH = "Scratches the target with sharp, hard claws.",
  VICEGRIP = "Grips the target with powerful, crushing pincers.",
  GUILLOTINE = "Chops the foe with massive pincers to inflict an instant One-Hit KO.",
  RAZOR_WIND = "Whips up a whirlwind on turn 1, then strikes on turn 2.",
  SWORDS_DANCE = "A frenetic dance of battle that sharply raises Attack by 2 stages.",
  CUT = "Cuts the target with sharp claws or blades. Can cut trees in field.",
  GUST = "Strikes the target with a fierce gust of wind whipped up by wings.",
  WING_ATTACK = "Strikes the target by spreading wings wide and slamming into them.",
  WHIRLWIND = "Blasts the target with wind to end wild battles or force switches.",
  FLY = "Soars high into the sky on turn 1, then dives to strike on turn 2.",
  BIND = "Binds the target in place to inflict damage for 2 to 5 turns.",
  SLAM = "Slams the target with a long tail or foreleg to deal heavy damage.",
  VINE_WHIP = "Strikes the target with slender, whip-like vines.",
  STOMP = "Stomps the target with huge feet. Has a 30% chance to make foe flinch.",
  DOUBLE_KICK = "A double-kicking attack that strikes the foe twice in one turn.",
  MEGA_KICK = "A ferocious kick delivered with tremendous muscular power.",
  JUMP_KICK = "A leaping kick. If it misses, the user hurts itself on landing.",
  ROLLING_KICK = "A quick, spinning kick. Has a 30% chance to make the foe flinch.",
  SAND_ATTACK = "Hurls sand into the target's face to lower its Accuracy by 1 stage.",
  HEADBUTT = "A forceful headbutt attack. Has a 30% chance to make the foe flinch.",
  HORN_ATTACK = "Jabs and strikes the foe with a sharp horn.",
  FURY_ATTACK = "Jabs the target repeatedly with a sharp beak or horn 2 to 5 times.",
  HORN_DRILL = "Spins a horn like a drill to inflict an instant One-Hit KO.",
  TACKLE = "Charges and slams into the target with full body weight.",
  BODY_SLAM = "Drops full body weight onto the target with a 30% chance to paralyze.",
  WRAP = "Wraps around the target tightly to inflict damage for 2 to 5 turns.",
  TAKE_DOWN = "A reckless full-body charge that causes 25% recoil damage.",
  THRASH = "Rampages fiercely for 2 to 3 turns before becoming confused.",
  DOUBLE_EDGE = "A reckless charge that deals massive damage with recoil.",
  TAIL_WHIP = "Wags tail cutely to make foe lower its guard, reducing Defense by 1.",
  POISON_STING = "Strikes with a poisonous barb. Has a 30% chance to poison.",
  TWINEEDLE = "Jabs the foe with twin spikes twice. Has a 20% chance to poison.",
  PIN_MISSILE = "Fires sharp pins at the target to hit 2 to 5 times in a row.",
  LEER = "Glares menacingly at the target to lower its Defense by 1 stage.",
  BITE = "Bites down with sharp teeth. Has a 10% chance to make the foe flinch.",
  GROWL = "Growls cutely to lower the opposing Pokémon's Attack stat.",
  ROAR = "Roars fiercely to scare away wild foes or force trainer switches.",
  SING = "Sings a soothing, gentle melody that puts the target to sleep.",
  SUPERSONIC = "Emits bizarre sound waves that confuse the target.",
  SONICBOOM = "Blasts the target with shock waves to deal exactly 20 HP damage.",
  DISABLE = "Psychically disables one of the target's moves for several turns.",
  ACID = "Sprays corrosive acid that may lower the target's Defense.",
  EMBER = "Attacks with small flames. Has a 10% chance to burn the target.",
  FLAMETHROWER = "Scorches the target with intense fire. Has a 10% chance to burn.",
  MIST = "Creates a white mist that protects the user's stats from being lowered.",
  WATER_GUN = "Squirts water forcefully at the target to inflict damage.",
  HYDRO_PUMP = "Blasts water under enormous pressure to deal massive damage.",
  SURF = "Creates a huge wave that crashes down on the target.",
  ICE_BEAM = "Blasts the target with an icy beam. Has a 10% chance to freeze.",
  BLIZZARD = "A howling blizzard that strikes with a 10% chance to freeze.",
  PSYBEAM = "Fires a peculiar psychic ray. Has a 10% chance to confuse.",
  BUBBLEBEAM = "Sprays forceful bubbles that may lower the target's Speed by 1.",
  AURORA_BEAM = "Fires a rainbow-colored beam that may lower the target's Attack.",
  HYPER_BEAM = "A devastating energy blast. User must recharge on next turn.",
  PECK = "Jabs the target with a sharp beak or horn.",
  DRILL_PECK = "Spins the beak like a corkscrew to drill into the target.",
  SUBMISSION = "A reckless body slam that deals damage with 25% recoil.",
  LOW_KICK = "A low kick that trips the foe. Heavier targets take more damage.",
  COUNTER = "Retaliates against physical attacks with double the damage taken.",
  SEISMIC_TOSS = "Inflicts damage exactly equal to the user's level.",
  STRENGTH = "Slams the foe with tremendous power. Can move boulders in field.",
  ABSORB = "A nutrient-draining attack that heals the user by 50% of damage dealt.",
  MEGA_DRAIN = "A tough draining attack that heals the user by 50% of damage dealt.",
  LEECH_SEED = "Plants a draining seed on the target that saps HP each turn.",
  GROWTH = "Stimulates cellular growth to raise the user's Special by 1 stage.",
  RAZOR_LEAF = "Cuts with sharp leaves. Has a high critical-hit ratio.",
  SOLARBEAM = "Absorbs solar energy on turn 1, then fires a blast on turn 2.",
  POISONPOWDER = "Scatters toxic dust that poisons the target.",
  STUN_SPORE = "Scatters paralyzing spores that paralyze the target.",
  SLEEP_POWDER = "Scatters soothing powder that puts the target to sleep.",
  PETAL_DANCE = "Scatters petals for 2-3 turns before becoming confused.",
  STRING_SHOT = "Binds the target in silk to drastically lower its Speed by 2 stages.",
  DRAGON_RAGE = "Pounds the target with shock waves to deal exactly 40 HP damage.",
  FIRE_SPIN = "Traps the target in a ring of fire to deal damage for 2 to 5 turns.",
  THUNDERSHOCK = "Zaps the target with a jolt of electricity. May paralyze (10%).",
  THUNDERBOLT = "Unleashes a strong electric blast. Has a 10% chance to paralyze.",
  THUNDER_WAVE = "A weak electric shock that paralyzes the target 100%.",
  THUNDER = "Strikes with a wicked lightning bolt. Has a 10% chance to paralyze.",
  ROCK_THROW = "Picks up and hurls small rocks at the target.",
  EARTHQUAKE = "A powerful ground tremor that hits all grounded Pokémon.",
  FISSURE = "Opens an enormous fissure to inflict an instant One-Hit KO.",
  DIG = "Digs underground on turn 1, then attacks from below on turn 2.",
  TOXIC = "Badly poisons the target, dealing escalating damage each turn.",
  CONFUSION = "A telekinetic psychic attack. Has a 10% chance to confuse.",
  PSYCHIC = "A powerful telekinetic blast. May lower the target's Special by 1.",
  PSYCHIC_M = "A powerful telekinetic blast. May lower the target's Special by 1.",
  HYPNOSIS = "Emits hypnotic suggestion that puts the target to sleep.",
  MEDITATE = "Meditates peacefully to raise the user's Attack stat by 1 stage.",
  AGILITY = "Relaxes the body to sharply boost the user's Speed stat by 2 stages.",
  QUICK_ATTACK = "Lunges forward with blinding speed to strike first (+1 Priority).",
  RAGE = "As the user takes damage, its Attack stat continuously rises.",
  TELEPORT = "Use in the wild to flee immediately, or return to last Poké Center.",
  NIGHT_SHADE = "Inflicts damage exactly equal to the user's current level.",
  MIMIC = "Temporarily copies one of the target's known moves during battle.",
  SCREECH = "Emits an ear-splitting screech that harshly lowers Defense by 2.",
  DOUBLE_TEAM = "Moves rapidly to create illusory copies, raising Evasion by 1.",
  RECOVER = "Restores up to half of the user's maximum HP.",
  HARDEN = "Stiffens the body's muscles to raise Defense by 1 stage.",
  MINIMIZE = "Compresses the body to sharply raise Evasion by 1 stage.",
  SMOKESCREEN = "Releases an ink or smoke cloud to lower the target's Accuracy by 1.",
  CONFUSE_RAY = "A sinister ray of light that causes immediate confusion.",
  WITHDRAW = "Withdraws into a hard shell to raise Defense by 1 stage.",
  DEFENSE_CURL = "Curls up tightly to raise the user's Defense by 1 stage.",
  BARRIER = "Creates a sturdy psychic barrier that sharply raises Defense by 2.",
  LIGHT_SCREEN = "Creates a translucent wall that halves incoming Special damage.",
  HAZE = "Eliminates all stat changes and status effects on the battlefield.",
  REFLECT = "Creates a protective barrier that halves incoming Physical damage.",
  FOCUS_ENERGY = "Focuses concentration to increase the user's critical-hit ratio.",
  BIDE = "Endures attacks for 2-3 turns, then strikes back with double damage.",
  METRONOME = "Wags a finger to randomly trigger almost any Pokémon move.",
  MIRROR_MOVE = "Counters by mimicking the target's last used move.",
  SELFDESTRUCT = "User faints to cause a massive explosion that deals heavy damage.",
  EXPLOSION = "User faints to trigger a catastrophic explosion of extreme power.",
  LICK = "Licks the target with a long tongue. Has a 30% chance to paralyze.",
  SMOG = "Blows exhaust gas at the target. Has a 40% chance to poison.",
  SLUDGE = "Hurls toxic sludge at the target. Has a 40% chance to poison.",
  BONE_CLUB = "Strikes with a hard bone club. Has a 10% chance to make foe flinch.",
  FIRE_BLAST = "An all-consuming star-shaped fireball. Has a 10% chance to burn.",
  WATERFALL = "Charges with enough force to scale waterfalls. Deals damage.",
  CLAMP = "Clamps down with a hard shell to trap the target for 2 to 5 turns.",
  SWIFT = "Fires star-shaped rays that never miss the target.",
  SKULL_BASH = "Tucks in head on turn 1 (raising Defense), then bashes on turn 2.",
  SPIKE_CANNON = "Fires sharp spikes at the target 2 to 5 times in a single turn.",
  CONSTRICT = "Constricts the foe painfully. Has a 10% chance to lower Speed.",
  AMNESIA = "Clears the mind to sharply boost the user's Special stat by 2 stages.",
  KINESIS = "Bends a spoon to distract the target, lowering Accuracy by 1.",
  SOFTBOILED = "Heals up to half of the user's max HP in or out of battle.",
  HI_JUMP_KICK = "A jumping knee kick. If it misses, the user takes heavy recoil.",
  GLARE = "Intimidates the foe with an intense gaze to paralyze it 100%.",
  DREAM_EATER = "Absorbs HP from a sleeping target, healing user by 50% of damage.",
  POISON_GAS = "Envelops the target in toxic gas to inflict the poison status.",
  BARRAGE = "Hurls round objects at the target 2 to 5 times in a single turn.",
  LEECH_LIFE = "A blood-draining bite that heals user by 50% of damage dealt.",
  LOVELY_KISS = "Demands a kiss with a scary face, putting the target to sleep.",
  SKY_ATTACK = "Glows intensely on turn 1, then delivers a devastating strike on turn 2.",
  TRANSFORM = "Transforms into an exact copy of the target Pokémon and its moves.",
  BUBBLE = "Blows delicate bubbles that have a 10% chance to lower Speed.",
  DIZZY_PUNCH = "A rhythmic, staggering punch that has a 20% chance to confuse.",
  SPORE = "Scatters hypnotic spores that put the target to sleep 100%.",
  FLASH = "Emits a brilliant flash of light that lowers the target's Accuracy by 1.",
  PSYWAVE = "Attacks with psychic waves that deal random damage up to 1.5x level.",
  SPLASH = "Flops about harmlessly. Has no effect in battle whatsoever.",
  ACID_ARMOR = "Melts into a liquid state to sharply boost Defense by 2 stages.",
  CRABHAMMER = "Strikes with huge pincer claws. Has a high critical-hit ratio.",
  FURY_SWIPES = "Rakes the target with sharp claws 2 to 5 times in a single turn.",
  BONEMERANG = "Throws a boomerang bone that strikes the target twice in one turn.",
  REST = "Sleeps for 2 turns to completely restore HP and cure all status.",
  ROCK_SLIDE = "Hurls large boulders at the foe. Has a 30% chance to make foe flinch.",
  HYPER_FANG = "Bites with sharp, hard incisors. Has a 10% chance to make foe flinch.",
  SHARPEN = "Sharpens edges to raise the user's Attack stat by 1 stage.",
  CONVERSION = "Changes the user's type to match one of its known moves.",
  TRI_ATTACK = "Fires three beams at once. Has a chance to burn, freeze, or paralyze.",
  SUPER_FANG = "Chomps down with vicious fangs to cut the target's current HP by half.",
  SLASH = "Slashes with claws or blades. Has a high critical-hit ratio.",
  SUBSTITUTE = "Uses 25% max HP to create a decoy substitute that absorbs damage.",
  STRUGGLE = "Used only when all PP is exhausted. Deals damage with 25% recoil.",

  -- Gen 2 & Gen 3 Highlights & Full Catalog (often present in Kanto Reforged & cross-gen engines)
  AEROBLAST = "Emits a vortex of vacuum air. Has a high critical-hit ratio.",
  ANCIENT_POWER = "Attacks with prehistoric power. Has a 10% chance to boost all stats.",
  ATTRACT = "Makes the target infatuated with the user if they are opposite genders.",
  BATON_PASS = "Switches out while passing on all active stat boosts to the replacement.",
  BEAT_UP = "All party Pokémon join in to attack the target one after another.",
  BELLY_DRUM = "Sacrifices 50% max HP to maximize the user's Attack stat by 6 stages.",
  BONE_RUSH = "Strikes the target with a hard bone 2 to 5 times in a single turn.",
  CHARM = "Charms the target cutely to harshly lower its Attack by 2 stages.",
  COTTON_SPORE = "Releases cotton spores that harshly lower the target's Speed by 2 stages.",
  CROSS_CHOP = "Delivers a double-chopping strike. Has a high critical-hit ratio.",
  CRUNCH = "Crunches with sharp fangs. Has a 20% chance to lower target's Defense.",
  CURSE = "Ghosts sacrifice HP to place a curse; other types boost Attack/Def at Speed's cost.",
  DESTINY_BOND = "If the user faints before its next turn, the attacker also faints.",
  DETECT = "Completely protects the user from all incoming attacks for one turn.",
  DRAGON_BREATH = "Exhales a fiery, draconic breath. Has a 30% chance to paralyze.",
  DYNAMIC_PUNCH = "A devastating punch thrown with full power that always confuses on hit.",
  ENCORE = "Forces the target to repeat its last used move for 2 to 6 turns.",
  ENDURE = "Endures any incoming attack with at least 1 HP remaining for that turn.",
  EXTREME_SPEED = "A blindingly fast charge that strikes with high priority (+2).",
  FAINT_ATTACK = "Draws near slyly to strike the foe. This attack never misses.",
  FALSE_SWIPE = "A restrained strike that always leaves the target with at least 1 HP.",
  FLAIL = "Inflicts greater damage the lower the user's remaining HP is.",
  FLAME_WHEEL = "Cloaks user in flames to charge. 10% chance to burn, thaws user.",
  FORESIGHT = "Enables Normal and Fighting moves to strike Ghost Pokémon and resets evasion.",
  FRUSTRATION = "Strikes with full power that increases the less friendly the Pokémon is.",
  FURY_CUTTER = "Slashes repeatedly, doubling in power with each consecutive successful hit.",
  FUTURE_SIGHT = "Heightens inner power to strike the target with psychic energy 2 turns later.",
  GIGA_DRAIN = "A harsh draining attack that heals the user by 50% of damage dealt.",
  HEAL_BELL = "Rings a soothing chime that cures all status ailments in the party.",
  HIDDEN_POWER = "An attack whose type and power vary based on the Pokémon's IVs/DVs.",
  ICY_WIND = "Attacks with a freezing wind that reduces the target's Speed by 1 stage.",
  IRON_TAIL = "Strikes with a rigid, steel tail. Has a 30% chance to lower Defense.",
  LOCK_ON = "Locks onto the target to guarantee the user's next attack will hit.",
  MACH_PUNCH = "Throws a punch at lightning speed to strike first (+1 Priority).",
  MAGNITUDE = "Shakes the ground with random intensity from Magnitude 4 to 10.",
  MEAN_LOOK = "Glares with a fixed gaze to prevent the target from escaping or switching.",
  MEGAPHORN = "Charges and rams with brutal, tough horns to inflict heavy damage.",
  METAL_CLAW = "Slashes with steel claws. Has a 10% chance to raise user's Attack.",
  MILK_DRINK = "Restores up to half of the user's maximum HP in or out of battle.",
  MIND_READER = "Senses the target's movements to guarantee the user's next attack will hit.",
  MIRROR_COAT = "Retaliates against special attacks with double the damage taken.",
  MOONLIGHT = "Restores HP depending on current weather conditions.",
  MORNING_SUN = "Restores HP depending on current weather conditions.",
  MUD_SLAP = "Hurls mud at the target's eyes, lowering its Accuracy by 1 stage.",
  NIGHTMARE = "Inflicts a nightmare on a sleeping foe to drain 25% of its max HP each turn.",
  OCTAZOOKA = "Blasts ink at the target with a 50% chance to lower Accuracy.",
  OUTRAGE = "Rampages for 2 to 3 turns with dragon fury before becoming confused.",
  PAIN_SPLIT = "Adds both Pokémon's HP together and divides it equally between them.",
  PERISH_SONG = "Any Pokémon that hears this song faints after 3 turns unless switched out.",
  POWDER_SNOW = "Blasts the target with chilling snow. Has a 10% chance to freeze.",
  PRESENT = "Delivers a gift bomb that randomly inflicts damage or heals the target.",
  PROTECT = "Completely evades all incoming attacks for one turn. May fail if used consecutively.",
  PSYCH_UP = "Hypnotizes the user into copying all of the target's active stat changes.",
  PURSUIT = "Inflicts double damage if the target attempts to switch out of battle.",
  RAIN_DANCE = "Summons heavy rain for 5 turns, boosting Water moves and weakening Fire.",
  RAPID_SPIN = "Spins rapidly to deal damage and clear away hazards, bind, and seeds.",
  RETURN = "Strikes with full power that increases the friendlier the Pokémon is.",
  REVERSAL = "Inflicts greater damage the lower the user's remaining HP is.",
  ROCK_SMASH = "A forceful smash that may lower Defense. Can smash cracked rocks in field.",
  ROLLOUT = "Rolls into the target for 5 turns, doubling in power with each successive hit.",
  SACRED_FIRE = "A mystical holy flame with a 50% chance to inflict a burn. Thaws user.",
  SAFEGUARD = "Creates a protective mystical veil that prevents status ailments for 5 turns.",
  SANDSTORM = "Summons a violent sandstorm for 5 turns that damages non-Rock/Ground/Steel types.",
  SCARY_FACE = "Frightens the target with a scary face to harshly lower its Speed by 2.",
  SHADOW_BALL = "Hurls a shadowy blob at the target. Has a 20% chance to lower Sp. Def.",
  SKETCH = "Copies the target's last used move permanently, replacing Sketch.",
  SLEEP_TALK = "Randomly chooses and uses one of the user's known moves while asleep.",
  SLUDGE_BOMB = "Hurls sludge blobs at the target. Has a 30% chance to poison.",
  SNORE = "Can only be used while asleep. Emits a loud snore with a 30% chance to flinch.",
  SPARK = "Strikes with an electrically charged tackle. Has a 30% chance to paralyze.",
  SPIDER_WEB = "Ensnares the target in sticky webbing to prevent switching or fleeing.",
  SPIKES = "Scatters sharp spikes around opposing field to damage switching foes.",
  SPITE = "Vengefully cuts 4 PP from the target's last used move.",
  STEEL_WING = "Strikes with wings of steel. Has a 10% chance to raise user's Defense.",
  SUNNY_DAY = "Summons blazing sunlight for 5 turns, boosting Fire moves and weakening Water.",
  SWAGGER = "Enrages the target into confusion, but sharply raises its Attack by 2 stages.",
  SWEET_KISS = "Demands a kiss with a cute face, confusing the target.",
  SWEET_SCENT = "Allures foes with a sweet aroma to lower their Evasion by 1 stage.",
  SYNTHESIS = "Restores HP depending on the current weather condition.",
  THIEF = "Attacks and steals the target's held item if the user is holding none.",
  TRIPLE_KICK = "Kicks the target 3 times in a row, increasing in power with each strike.",
  TWISTER = "Whips up a vicious twister to strike. Has a 20% chance to make foe flinch.",
  VITAL_THROW = "Strikes after the target, but guarantees the attack will never miss.",
  WHIRLPOOL = "Traps the target in a raging whirlpool for 2 to 5 turns.",
  ZAP_CANNON = "Fires an electric blast that inflicts heavy damage and guarantees paralysis.",
  
  -- Gen 3 Full Catalog
  AERIAL_ACE = "An extremely fast aerial strike that never misses the target.",
  AIR_CUTTER = "Launches razor-like wind blades with a high critical-hit ratio.",
  ARM_THRUST = "Delivers straight-arm chops repeatedly 2 to 5 times in a single turn.",
  AROMATHERAPY = "Releases a soothing fragrance that heals all status ailments in the party.",
  ASSIST = "Randomly uses one of the moves known by other party Pokémon.",
  ASTONISH = "Shocks the target with a sudden scare. Has a 30% chance to flinch.",
  BLAST_BURN = "Incinerates target with extreme fiery blast. User must recharge next turn.",
  BLAZE_KICK = "A fiery kick with a high critical-hit ratio. Has a 10% chance to burn.",
  BLOCK = "Blocks the target's path with open arms to prevent switching or fleeing.",
  BOUNCE = "Bounces high on turn 1, then drops on turn 2. 30% chance to paralyze.",
  BRICK_BREAK = "Breaks light barriers like Reflect and Light Screen and deals damage.",
  BULK_UP = "Bulks up the user's body to raise both Attack and Defense by 1 stage.",
  BULLET_SEED = "Fires 2 to 5 seeds in rapid succession at the target in one turn.",
  CALM_MIND = "Focuses the mind to raise both Sp. Atk and Sp. Def by 1 stage.",
  CAMOUFLAGE = "Alters the user's type to match the terrain of the battlefield.",
  CHARGE = "Charges power to double the power of the next Electric attack used.",
  COSMIC_POWER = "Channels cosmic energy to raise both Defense and Sp. Def by 1 stage.",
  COVET = "Cutely begs the target and steals its held item if the user has none.",
  CRUSH_CLAW = "Tears at the target with sharp claws. Has a 50% chance to lower Defense.",
  DIVE = "Dives underwater on turn 1, then strikes on turn 2. Can explore deep trenches.",
  DOOM_DESIRE = "Summons concentrated light that strikes the target 2 turns later.",
  DRAGON_CLAW = "Slashes the target with huge, sharp dragon claws.",
  DRAGON_DANCE = "A mystical dance that boosts both the user's Attack and Speed by 1 stage.",
  ENDEAVOR = "Deals damage to reduce the target's HP to match the user's current HP.",
  ERUPTION = "Unleashes an explosive volcanic eruption. Deals more damage the higher the user's HP.",
  EXTRASENSORY = "Attacks with miraculous psychic power. Has a 10% chance to make foe flinch.",
  FACADE = "An attack that doubles in power if the user is burned, poisoned, or paralyzed.",
  FAKE_OUT = "Strikes first on the first turn of battle with +3 priority and guarantees a flinch.",
  FAKE_TEARS = "Fakes crying to harshly lower the target's Sp. Def by 2 stages.",
  FEATHER_DANCE = "Scatters a cloud of soft down to harshly lower the target's Attack by 2.",
  FLATTER = "Flatters the target into confusion, but raises its Sp. Atk by 1 stage.",
  FOCUS_PUNCH = "A powerful punch charged at turn start. Fails if user is hit before executing.",
  FOLLOW_ME = "Draws attention to the user, forcing opposing Pokémon to target it.",
  FRENZY_PLANT = "Slams the foe with massive roots. User must recharge next turn.",
  GRASS_WHISTLE = "Plays a pleasant melody with a blade of grass to put the target to sleep.",
  GRUDGE = "If the user faints on this turn, the move that felled it loses all PP.",
  HAIL = "Summons a hailstorm for 5 turns that damages all Pokémon except Ice types.",
  HEAT_WAVE = "Exhales an intense wave of hot air. Has a 10% chance to burn.",
  HELPING_HAND = "Boosts the power of an ally's attack in double battles.",
  HOWL = "Howls loudly to raise the user's Attack stat by 1 stage.",
  HYDRO_CANNON = "Blasts a huge torrent of water. User must recharge next turn.",
  HYPER_VOICE = "Attacks with loud, vibrating sound waves that echo across the field.",
  ICE_BALL = "Rolls ice at the foe for 5 turns, doubling power with each consecutive hit.",
  ICICLE_SPEAR = "Fires 2 to 5 sharp icicles at the target in a single turn.",
  IMPRISON = "Prevents opposing Pokémon from using any moves also known by the user.",
  INGRAIN = "Lays roots to restore HP each turn, but prevents switching out or fleeing.",
  IRON_DEFENSE = "Hardens the body like iron to sharply boost Defense by 2 stages.",
  KNOCK_OFF = "Knocks down the target's held item to prevent its use for the battle.",
  LEAF_BLADE = "Slashes with a sharp, leafy blade. Has a high critical-hit ratio.",
  LUSTER_PURGE = "Attacks with a blinding burst of light with a 50% chance to lower Sp. Def.",
  MAGICAL_LEAF = "Scatters magical leaves that track the target and never miss.",
  MAGIC_COAT = "Reflects status moves back at the attacker during the turn.",
  MEMENTO = "The user faints to harshly lower the target's Attack and Sp. Atk by 2 stages.",
  METAL_SOUND = "Emits a horrific metallic screech that harshly lowers Sp. Def by 2 stages.",
  METEOR_MASH = "Punches with the force of a meteor. Has a 20% chance to raise user's Attack.",
  MIST_BALL = "Attacks with a flurry of mist with a 50% chance to lower Sp. Atk.",
  MUDDY_WATER = "Attacks with a murky wave of muddy water. Has a 30% chance to lower Accuracy.",
  MUD_SHOT = "Hurls mud at the target to deal damage and lower its Speed by 1 stage.",
  MUD_SPORT = "Covers the field in mud to weaken Electric-type attacks by 50%.",
  NATURE_POWER = "An attack that transforms into a different move depending on the battlefield terrain.",
  NEEDLE_ARM = "Strikes with thorny arms with a 30% chance to make the foe flinch.",
  ODOR_SLEUTH = "Enables Normal and Fighting moves to hit Ghosts and resets evasion.",
  OVERHEAT = "Attacks with full-power heat, but harshly lowers user's Sp. Atk by 2 stages.",
  POISON_FANG = "Bites with venomous fangs. Has a 30% chance to badly poison.",
  POISON_TAIL = "Strikes with a poisonous tail with a high critical-hit ratio and 10% poison.",
  PSYCHO_BOOST = "Attacks with psychic power, but harshly lowers user's Sp. Atk by 2 stages.",
  RECYCLE = "Recycles a single-use held item that was consumed during battle.",
  REFRESH = "Cures the user of poison, paralysis, or a burn.",
  REVENGE = "An attack that deals double damage if the user was hurt by foe in same turn.",
  ROCK_BLAST = "Hurls 2 to 5 hard rocks at the target in a single turn.",
  ROCK_TOMB = "Boulders are hurled at the target to trap it, lowering its Speed by 1 stage.",
  ROLE_PLAY = "Mimics the target Pokémon to copy its special ability.",
  SAND_TOMB = "Traps the target in a swirling sandstorm vortex for 2 to 5 turns.",
  SECRET_POWER = "An attack whose secondary effect depends on the battlefield terrain.",
  SHADOW_PUNCH = "Throws a punch from the shadows that never misses the target.",
  SHEER_COLD = "Inflicts an instant One-Hit KO using absolute zero temperatures.",
  SHOCK_WAVE = "Strikes the target with a rapid electric jolt that never misses.",
  SIGNAL_BEAM = "Fires a bizarre, flashing beam of light. Has a 10% chance to confuse.",
  SILVER_WIND = "Blows powdery silver scales with a 10% chance to boost all user's stats.",
  SKILL_SWAP = "Uses psychic power to swap special abilities with the target.",
  SKY_UPPERCUT = "Delivers an uppercut leaping into the sky. Can hit flying targets.",
  SLACK_OFF = "Slacks off and lolls around to restore half of user's maximum HP.",
  SMELLING_SALT = "Deals double damage against paralyzed targets, but cures their paralysis.",
  SNATCH = "Steals the effects of any healing or stat-boosting moves used by the foe.",
  SPIT_UP = "Releases stored Stockpile energy to attack the target.",
  STOCKPILE = "Stockpiles power to raise both Defense and Sp. Def by 1 stage (up to 3x).",
  SUPERPOWER = "Attacks with immense power, but lowers user's Attack and Defense by 1 stage.",
  SWALLOW = "Absorbs stockpiled energy to restore the user's HP.",
  TAIL_GLOW = "Flashes tail brightly to sharply boost user's Sp. Atk by 2 (or 3) stages.",
  TAUNT = "Taunts the target into only using damaging attacks for several turns.",
  TEETER_DANCE = "Dances a dizzying, wobbling rhythm that confuses all Pokémon on field.",
  TICKLE = "Tickles the target to lower both its Attack and Defense by 1 stage.",
  TORMENT = "Torments the target to prevent it from using the same move twice in a row.",
  TRICK = "Tricks the target into swapping held items with the user.",
  UPROAR = "Causes an uproar for 2 to 5 turns that prevents all Pokémon from sleeping.",
  VOLT_TACKLE = "A reckless electric tackle of supreme power with 33% recoil and 10% paralyze.",
  WATER_PULSE = "Attacks with ultrasonic water pulses. Has a 20% chance to confuse.",
  WATER_SPORT = "Soaks the battlefield in water to weaken Fire-type attacks by 50%.",
  WATER_SPOUT = "Spouts a giant water pillar. Deals more damage the higher the user's HP.",
  WEATHER_BALL = "Type and power change dynamically depending on the current weather.",
  WILL_O_WISP = "Inflicts a sinister ghostly flame that burns the target 100%.",
  WISH = "Makes a wish that restores 50% max HP to the active Pokémon on the next turn.",
  YAWN = "A huge yawn that makes the target drowsy, falling asleep on the next turn.",

  -- Common Modern / Modded Moves (Gen 4-8 Expansion Packs)
  AQUA_JET = "Lunges forward with a burst of water to strike first (+1 Priority).",
  AURA_SPHERE = "Fires a blast of concentrated aura energy that never misses.",
  BRAVE_BIRD = "Dives recklessly with tucked wings. Deals massive damage with 33% recoil.",
  BUG_BUZZ = "Vibrates sound waves to attack. Has a 10% chance to lower Sp. Def.",
  BULLET_PUNCH = "Punches as fast as a bullet to strike first (+1 Priority).",
  CLOSE_COMBAT = "Fights relentlessly up close, but lowers user's Defense and Sp. Def.",
  DARK_PULSE = "Releases a horrible aura of dark thoughts. Has a 20% chance to flinch.",
  DAZZLING_GLEAM = "Emits a powerful flash of dazzling light to damage all opposing foes.",
  DEFOG = "Blows away fog, hazards like Spikes/Stealth Rock, and screens.",
  DRACO_METEOR = "Summons comets from the sky, but harshly lowers user's Sp. Atk by 2 stages.",
  DRAGON_PULSE = "Attacks with a shock wave generated from the user's draconic gaping mouth.",
  EARTH_POWER = "Causes the ground to erupt beneath the target. 10% chance to lower Sp. Def.",
  ENERGY_BALL = "Draws power from nature to fire a sphere with a 10% chance to lower Sp. Def.",
  FLARE_BLITZ = "Cloaks user in fierce fire to charge. Deals damage with 33% recoil and 10% burn.",
  FLASH_CANNON = "Concentrates light energy into a beam with a 10% chance to lower Sp. Def.",
  FOCUS_BLAST = "Focuses willpower to fire a destructive blast with a 10% chance to lower Sp. Def.",
  GIGA_IMPACT = "Charges the target with supreme brute force. User must recharge next turn.",
  GUNK_SHOT = "Hurls filthy garbage at the target. Has a 30% chance to poison.",
  HEAD_SMASH = "A desperate headbutt of incredible power with heavy 50% recoil damage.",
  HEX = "Deals double damage if the target is afflicted with a status condition.",
  HURRICANE = "Wraps the foe in a fierce hurricane. Has a 30% chance to confuse.",
  ICE_SHARD = "Hurls chunks of flash-frozen ice to strike first (+1 Priority).",
  IRON_HEAD = "Slams the foe with a steel-hard head. Has a 30% chance to make foe flinch.",
  LEAF_STORM = "Whips up a storm of sharp leaves, but harshly lowers Sp. Atk by 2 stages.",
  MOONBLAST = "Borrows the power of the moon to attack. Has a 30% chance to lower Sp. Atk.",
  NASTY_PLOT = "Stimulates devious thoughts to sharply raise user's Sp. Atk by 2 stages.",
  NIGHT_SLASH = "Slashes instantly as opportunity arises. Has a high critical-hit ratio.",
  PLAY_ROUGH = "Plays rough with the target. Has a 10% chance to lower target's Attack.",
  POISON_JAB = "Jabs the target with a toxic blade or tentacle. Has a 30% chance to poison.",
  ROOST = "Lands to rest its wings, restoring up to half of user's max HP.",
  SCALD = "Shoots boiling water at the target with a 30% chance to burn. Thaws user.",
  SHADOW_SNEAK = "Extends user's shadow to strike from behind with priority (+1).",
  STEALTH_ROCK = "Floats pointed stones around opposing field that damage switching foes.",
  STONE_EDGE = "Stabs the target with sharpened stones. Has a high critical-hit ratio.",
  TAILWIND = "Whips up a turbulent whirlwind that doubles the party's Speed for 4 turns.",
  U_TURN = "Attacks and immediately switches out with a waiting party Pokémon.",
  VOLT_SWITCH = "Attacks with electricity and immediately switches out with a party Pokémon.",
  WOOD_HAMMER = "Slams the target with a rugged tree trunk. Deals heavy recoil damage.",
  X_SCISSOR = "Slashes the target by crossing scythes or claws like a pair of scissors.",
}

-- Spelling and generation naming aliases mapped to canonical keys
local MOVE_ALIASES = {
  FEINT_ATTACK = "FAINT_ATTACK",
  FEINTATTACK = "FAINT_ATTACK",
  FAINTATTACK = "FAINT_ATTACK",
  HIGH_JUMP_KICK = "HI_JUMP_KICK",
  PSYCHIC_M = "PSYCHIC",
  POISONPOWDER = "POISONPOWDER",
  SOLARBEAM = "SOLARBEAM",
  SONICBOOM = "SONICBOOM",
  THUNDERSHOCK = "THUNDERSHOCK",
  THUNDERPUNCH = "THUNDERPUNCH",
  BUBBLEBEAM = "BUBBLEBEAM",
  DOUBLESLAP = "DOUBLESLAP",
  VICEGRIP = "VICEGRIP",
  SELFDESTRUCT = "SELFDESTRUCT",
  SOFTBOILED = "SOFTBOILED",
  DYNAMICPUNCH = "DYNAMIC_PUNCH",
  DRAGONBREATH = "DRAGON_BREATH",
  EXTREMESPEED = "EXTREME_SPEED",
  ANCIENTPOWER = "ANCIENT_POWER",
  FEATHERDANCE = "FEATHER_DANCE",
  GRASSWHISTLE = "GRASS_WHISTLE",
  SMELLINGSALT = "SMELLING_SALT",
  SMELLING_SALTS = "SMELLING_SALT",
}

-- Fast lookup cache for normalized keys and stripped underscores
local normalizedIndex = nil
local function getCanonicalDescription(key)
  if not key then return nil end
  if not normalizedIndex then
    normalizedIndex = {}
    for k, v in pairs(MOVE_DESCRIPTIONS) do
      local kClean = k:gsub("^MOVE_", ""):upper()
      normalizedIndex[kClean] = v
      normalizedIndex[kClean:gsub("_", "")] = v
    end
    for alias, target in pairs(MOVE_ALIASES) do
      local desc = normalizedIndex[target] or normalizedIndex[target:gsub("_", "")]
      if desc then
        normalizedIndex[alias] = desc
        normalizedIndex[alias:gsub("_", "")] = desc
      end
    end
  end

  local clean = key:gsub("^MOVE_", ""):upper()
  return normalizedIndex[clean] or normalizedIndex[clean:gsub("_", "")]
end

local SPECIAL_TYPES = {
  FIRE = true,
  WATER = true,
  GRASS = true,
  ELECTRIC = true,
  PSYCHIC = true,
  ICE = true,
  DRAGON = true,
  DARK = true,
  FAIRY = true,
}

local CANONICAL_MOVES_DATA = {
  THUNDERBOLT = { name = "Thunderbolt", type = "ELECTRIC", power = 95, accuracy = 100, pp = 15, category = "SPECIAL" },
  AEROBLAST = { name = "Aeroblast", type = "FLYING", power = 100, accuracy = 95, pp = 5, category = "SPECIAL" },
  HYPER_BEAM = { name = "Hyper Beam", type = "NORMAL", power = 150, accuracy = 90, pp = 5, category = "PHYSICAL" },
  SWORDS_DANCE = { name = "Swords Dance", type = "NORMAL", power = 0, accuracy = 100, pp = 30, category = "STATUS" },
  SURF = { name = "Surf", type = "WATER", power = 95, accuracy = 100, pp = 15, category = "SPECIAL" },
  EARTHQUAKE = { name = "Earthquake", type = "GROUND", power = 100, accuracy = 100, pp = 10, category = "PHYSICAL" },
  FLAMETHROWER = { name = "Flamethrower", type = "FIRE", power = 95, accuracy = 100, pp = 15, category = "SPECIAL" },
  ICE_BEAM = { name = "Ice Beam", type = "ICE", power = 95, accuracy = 100, pp = 10, category = "SPECIAL" },
  PSYCHIC = { name = "Psychic", type = "PSYCHIC", power = 90, accuracy = 100, pp = 10, category = "SPECIAL" },
  SHADOW_BALL = { name = "Shadow Ball", type = "GHOST", power = 80, accuracy = 100, pp = 15, category = "PHYSICAL" },
  SACRED_FIRE = { name = "Sacred Fire", type = "FIRE", power = 100, accuracy = 95, pp = 5, category = "PHYSICAL" },
  SOLARBEAM = { name = "SolarBeam", type = "GRASS", power = 120, accuracy = 100, pp = 10, category = "SPECIAL" },
  THUNDER = { name = "Thunder", type = "ELECTRIC", power = 120, accuracy = 70, pp = 10, category = "SPECIAL" },
  BLIZZARD = { name = "Blizzard", type = "ICE", power = 120, accuracy = 90, pp = 5, category = "SPECIAL" },
  FIRE_BLAST = { name = "Fire Blast", type = "FIRE", power = 120, accuracy = 85, pp = 5, category = "SPECIAL" },
  HYDRO_PUMP = { name = "Hydro Pump", type = "WATER", power = 120, accuracy = 80, pp = 5, category = "SPECIAL" },
}

local function formatTitleCase(str)
  if not str or str == "" then return "" end
  return (str:gsub("_", " "):gsub("(%a)([%w']*)", function(first, rest)
    return first:upper() .. rest:lower()
  end))
end

--- Resolves a normalized move definition table given an ID, move object, and game instance.
--- All stats (power, accuracy, pp, type, effect) are sourced directly from the running game and active mods.
function MoveDatabase.getMoveDef(moveId, moveObj, game)
  local idStr = (type(moveObj) == "table" and (moveObj.id or moveObj.move or moveObj[1])) or moveId
  if not idStr then return nil end
  idStr = tostring(idStr)
  local upperId = idStr:upper()
  local cleanKey = upperId:gsub("^MOVE_", "")

  -- 1. Check mod registered moves
  if registeredMoves[upperId] or registeredMoves[cleanKey] then
    local r = registeredMoves[upperId] or registeredMoves[cleanKey]
    return {
      id = upperId,
      name = r.name or formatTitleCase(cleanKey),
      type = r.type and tostring(r.type):upper() or "NORMAL",
      power = tonumber(r.power) or 0,
      accuracy = tonumber(r.accuracy) or 100,
      pp = tonumber(r.pp) or 15,
      category = r.category or r.split or r.damageClass,
      description = r.description or r.flavorText,
      effectTag = r.effectTag or r.tag,
      effect = r.effect,
    }
  end

  -- 2. Source directly from running game data tables (Gen 1 / Gen 2 / Gen 3 data structures)
  local gData = game and game.data
  local dataDef = nil
  if gData and gData.moves then
    dataDef = gData.moves[idStr] or gData.moves[upperId] or gData.moves[cleanKey] or gData.moves[idStr:lower()] or (tonumber(idStr) and gData.moves[tonumber(idStr)])
  end
  if not dataDef and game and game.moves then
    dataDef = game.moves[idStr] or game.moves[upperId] or game.moves[cleanKey] or (tonumber(idStr) and game.moves[tonumber(idStr)])
  end
  if not dataDef then
    local okData, dataMod = pcall(require, "src.core.Data")
    if okData and dataMod and dataMod.moves then
      dataDef = dataMod.moves[idStr] or dataMod.moves[upperId] or dataMod.moves[cleanKey] or (tonumber(idStr) and dataMod.moves[tonumber(idStr)])
    end
  end

  local canonDef = CANONICAL_MOVES_DATA[upperId] or CANONICAL_MOVES_DATA[cleanKey]

  -- 3. Construct normalized definition table strictly from live game definition and moveObj
  local res = {}
  if canonDef then
    for k, v in pairs(canonDef) do
      res[k] = v
    end
  end
  if dataDef then
    for k, v in pairs(dataDef) do
      if v ~= nil then res[k] = v end
    end
  end
  if type(moveObj) == "table" then
    for k, v in pairs(moveObj) do
      if v ~= nil then res[k] = v end
    end
  end

  res.id = res.id or upperId
  local rawName = (dataDef and dataDef.name) or res.name or cleanKey
  res.name = formatTitleCase(rawName)

  if dataDef and dataDef.type ~= nil then
    res.type = tostring(dataDef.type):upper()
  elseif type(moveObj) == "table" and moveObj.type ~= nil then
    res.type = tostring(moveObj.type):upper()
  elseif res.type ~= nil then
    res.type = tostring(res.type):upper()
  elseif canonDef and canonDef.type then
    res.type = canonDef.type
  else
    res.type = "NORMAL"
  end

  if dataDef and dataDef.power ~= nil then
    res.power = tonumber(dataDef.power) or 0
  elseif type(moveObj) == "table" and moveObj.power ~= nil then
    res.power = tonumber(moveObj.power) or 0
  elseif res.power == nil then
    res.power = canonDef and canonDef.power or 0
  end

  if dataDef and dataDef.accuracy ~= nil then
    res.accuracy = tonumber(dataDef.accuracy) or 100
  elseif type(moveObj) == "table" and moveObj.accuracy ~= nil then
    res.accuracy = tonumber(moveObj.accuracy) or 100
  elseif res.accuracy == nil then
    res.accuracy = canonDef and canonDef.accuracy or 100
  end

  if dataDef and dataDef.pp ~= nil then
    res.pp = tonumber(dataDef.pp) or 15
  elseif type(moveObj) == "table" and moveObj.pp ~= nil then
    res.pp = tonumber(moveObj.pp) or 15
  elseif res.pp == nil then
    res.pp = canonDef and canonDef.pp or 15
  end

  if dataDef and (dataDef.category or dataDef.split or dataDef.damageClass) then
    res.category = dataDef.category or dataDef.split or dataDef.damageClass
  elseif canonDef and canonDef.category then
    res.category = canonDef.category
  end

  -- Gen 3 battle slots already resolved the live move. A Gen 1 row that
  -- shares the name must not replace those stats or the display name.
  if type(moveObj) == "table" and moveObj.source == "gen3" then
    if type(moveObj.name) == "string" and moveObj.name ~= "" then
      res.name = formatTitleCase(moveObj.name)
    end
    if moveObj.type ~= nil then res.type = tostring(moveObj.type):upper() end
    if moveObj.power ~= nil then res.power = tonumber(moveObj.power) or 0 end
    if moveObj.accuracy ~= nil then res.accuracy = tonumber(moveObj.accuracy) or 0 end
    if moveObj.effect ~= nil then res.effect = moveObj.effect end
    local provided = moveObj.description or moveObj.desc
    if type(provided) == "string" and provided ~= "" and provided ~= "---" then
      res.description = provided
      res.desc = provided
    end
  end

  return res
end

local function usableMoveText(raw)
  if type(raw) ~= "string" then return nil end
  local text = raw:gsub("\n", " "):gsub("%s+", " ")
  if text == "" or text == "---" or text == "--" then return nil end
  if text:match("^A .+ technique used in battle%.?$") then return nil end
  return text
end

--- Numeric Gen 3 ids ("33") become the move's const name ("TACKLE") so the
--- dictionary and the ROM text can be found.
local function describedMoveKey(moveId, moveDef)
  local raw = tostring(moveId or (moveDef and (moveDef.id or moveDef.name)) or "")
  local upper = raw:upper():gsub("^MOVE_", "")
  local num = tonumber(upper:match("^(%d+)$") or upper:match("^MOVE (%d+)$"))
  if num and num > 0 then
    local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
    if ok and Pokemon and Pokemon.moveName then
      local okN, name = pcall(Pokemon.moveName, num)
      if okN and type(name) == "string" and name ~= "" and name ~= "-------" and not name:find("^MOVE ") then
        return name:upper():gsub("%s+", "_"):gsub("[^%w_]", "")
      end
    end
  end
  return upper:gsub("[^%w_]", "")
end

--- Resolves the textual description of a move across mods, engine ROM data, canonical dictionaries, and providers.
--- @param moveId string
--- @param moveDef table|nil
--- @param game table|nil
--- @return string
function MoveDatabase.getDescription(moveId, moveDef, game)
  if not moveId and not moveDef then return "A versatile combat technique." end
  local upperId = tostring(moveId or (moveDef and moveDef.id) or ""):upper()
  local cleanKey = upperId:gsub("^MOVE_", "")
  local namedKey = describedMoveKey(moveId or (moveDef and moveDef.id), moveDef)

  -- 1. Custom Provider Hooks registered by mods
  for _, prov in ipairs(descriptionProviders) do
    local ok, desc = pcall(prov, moveId, moveDef, game)
    if ok and desc and type(desc) == "string" and desc ~= "" then
      return desc:gsub("\n", " "):gsub("%s+", " ")
    end
  end

  -- 2. Text the game or the move record already provides.
  if moveDef then
    local rawDesc = moveDef.flavorText or moveDef.flavor or moveDef.description or moveDef.desc or moveDef.effectDescription
    if type(rawDesc) == "table" then
      local parts = {}
      for _, p in ipairs(rawDesc) do
        local piece = usableMoveText(p)
        if piece then parts[#parts + 1] = piece end
      end
      if #parts > 0 then return table.concat(parts, " ") end
    else
      local provided = usableMoveText(rawDesc)
      if provided then return provided end
    end
  end

  -- 3. Mod-registered move table lookup
  local registered = registeredMoves[upperId] or registeredMoves[cleanKey] or registeredMoves[namedKey]
  if registered then
    local d = usableMoveText(registered.description or registered.flavorText or registered.desc)
    if d then return d end
  end

  -- 4. Game data text, ahead of the built-in dictionary.
  if game and game.data then
    if game.data.moves then
      local m = game.data.moves[moveId] or game.data.moves[upperId] or game.data.moves[cleanKey]
        or game.data.moves[namedKey] or game.data.moves[namedKey:gsub("_", " ")]
      if m then
        local d = usableMoveText(m.description or m.flavorText or m.desc)
        if d then return d end
      end
    end
    if game.data.text and game.data.text.moves then
      local d = usableMoveText(game.data.text.moves[moveId] or game.data.text.moves[upperId]
        or game.data.text.moves[cleanKey] or game.data.text.moves[namedKey])
      if d then return d end
    end
  end

  -- 5. OmniUI descriptions when the game does not supply one.
  local canonicalDesc = getCanonicalDescription(namedKey) or getCanonicalDescription(upperId) or getCanonicalDescription(cleanKey)
  if canonicalDesc then
    return canonicalDesc
  end

  local cleanId = namedKey:gsub("_", " "):lower()
  if cleanId == "" then cleanId = "attack" end
  return ("A %s technique used in battle."):format(cleanId)
end

--- Formats the display power string for UI presentation.
--- @param moveDef table|nil
--- @return string
function MoveDatabase.getPowerString(moveDef)
  if not moveDef then return "---" end
  local pwr = moveDef.power
  if not pwr or pwr == 0 or pwr <= 0 then return "---" end
  return tostring(pwr)
end

--- Formats the display accuracy string for UI presentation.
--- @param moveDef table|nil
--- @return string
function MoveDatabase.getAccuracyString(moveDef)
  if not moveDef then return "---" end
  local acc = moveDef.accuracy
  if not acc or acc == 0 or acc <= 0 then return "---" end
  if type(acc) == "number" then
    if acc <= 1.0 then
      return ("%d%%"):format(math.floor(acc * 100))
    elseif acc == 255 then
      return "100%"
    elseif acc <= 100 then
      return ("%d%%"):format(acc)
    end
  end
  return tostring(acc) .. "%"
end

--- Resolves the damage category (PHYSICAL / SPECIAL / STATUS) honoring Gen 4+ split mods,
--- Kanto Reforged physical/special split, or Gen 1-3 classic elemental rules.
--- @param moveId string|nil
--- @param moveDef table|nil
--- @param game table|nil
--- @return string "PHYSICAL" | "SPECIAL" | "STATUS"
function MoveDatabase.getCategory(moveId, moveDef, game)
  if moveDef then
    local cat = moveDef.category or moveDef.split or moveDef.damageClass or moveDef.class
    if cat then
      local catUpper = tostring(cat):upper()
      if catUpper == "PHYSICAL" or catUpper == "SPECIAL" or catUpper == "STATUS" then
        return catUpper
      end
    end
  end

  local pwr = moveDef and moveDef.power or 0
  if pwr == 0 or not pwr or pwr <= 0 then
    return "STATUS"
  end

  -- Check Kanto Reforged physical/special split if active
  local krSplit = package.loaded["mods.Kanto-Reforged.battle.split_special"]
  if krSplit and krSplit.getCategory and moveId then
    local ok, krCat = pcall(krSplit.getCategory, moveId)
    if ok and krCat then
      local krUpper = tostring(krCat):upper()
      if krUpper == "PHYSICAL" or krUpper == "SPECIAL" or krUpper == "STATUS" then
        return krUpper
      end
    end
  end

  local mType = moveDef and moveDef.type and tostring(moveDef.type):upper() or "NORMAL"
  if SPECIAL_TYPES[mType] then
    return "SPECIAL"
  end
  return "PHYSICAL"
end

--- Resolves a concise tactical effect tagline (e.g. "One-Hit KO", "HP Drain (50%)", "Inflicts Sleep", etc.).
--- @param moveId string|nil
--- @param moveDef table|nil
--- @param game table|nil
--- @return string
function MoveDatabase.getEffectTag(moveId, moveDef, game)
  if moveDef then
    if moveDef.effectTag and moveDef.effectTag ~= "" then return moveDef.effectTag end
    if moveDef.tag and moveDef.tag ~= "" then return moveDef.tag end
  end

  local pwr = moveDef and moveDef.power or 0
  local eff = tostring(moveDef and moveDef.effect or ""):upper()
  local upperId = tostring(moveId or (moveDef and moveDef.id) or ""):upper()

  if upperId == "SWORDS_DANCE" then
    return "Sharply Boosts Attack"
  elseif upperId == "AGILITY" then
    return "Sharply Boosts Speed"
  elseif upperId == "AMNESIA" then
    return "Sharply Boosts Special"
  elseif upperId == "BARRIER" or upperId == "ACID_ARMOR" or upperId == "IRON_DEFENSE" then
    return "Sharply Boosts Defense"
  elseif upperId == "NASTY_PLOT" or upperId == "TAIL_GLOW" then
    return "Sharply Boosts Sp. Atk"
  end

  if eff:find("ONE_HIT_KO") or upperId == "GUILLOTINE" or upperId == "HORN_DRILL" or upperId == "FISSURE" or upperId == "SHEER_COLD" then
    return "One-Hit KO"
  elseif eff:find("HEAL") or upperId == "RECOVER" or upperId == "REST" or upperId == "SOFTBOILED" or upperId == "SLACK_OFF" or upperId == "MILK_DRINK" or upperId == "ROOST" or upperId == "WISH" then
    return "Heals HP"
  elseif eff:find("DRAIN") or upperId == "ABSORB" or upperId == "MEGA_DRAIN" or upperId == "GIGA_DRAIN" or upperId == "LEECH_LIFE" or upperId == "DREAM_EATER" then
    return "HP Drain (50%)"
  elseif eff:find("RECOIL") or upperId == "TAKE_DOWN" or upperId == "DOUBLE_EDGE" or upperId == "SUBMISSION" or upperId == "VOLT_TACKLE" or upperId == "FLARE_BLITZ" or upperId == "BRAVE_BIRD" or upperId == "WOOD_HAMMER" or upperId == "HEAD_SMASH" then
    return "Recoil Damage"
  elseif eff:find("SLEEP") or upperId == "SING" or upperId == "SLEEP_POWDER" or upperId == "HYPNOSIS" or upperId == "SPORE" or upperId == "YAWN" or upperId == "GRASSWHISTLE" or upperId == "GRASS_WHISTLE" then
    return "Inflicts Sleep"
  elseif eff:find("POISON_EFFECT") or eff:find("POISON_POWDER") or upperId == "TOXIC" or upperId == "POISONPOWDER" or upperId == "POISON_GAS" or upperId == "POISON_FANG" or upperId == "POISON_JAB" or upperId == "GUNK_SHOT" then
    return "Inflicts Poison"
  elseif eff:find("PARALYZE_EFFECT") or upperId == "THUNDER_WAVE" or upperId == "GLARE" or upperId == "STUN_SPORE" or upperId == "ZAP_CANNON" then
    return "Inflicts Paralyze"
  elseif eff:find("BURN_SIDE") or eff:find("FLAMETHROWER") or eff:find("FIRE_BLAST") or upperId == "WILL_O_WISP" or upperId == "BLAZE_KICK" or upperId == "SACRED_FIRE" or upperId == "SCALD" then
    return "May Inflict Burn"
  elseif eff:find("FREEZE_SIDE") or eff:find("ICE_BEAM") or eff:find("BLIZZARD") or upperId == "BLIZZARD" then
    return "May Freeze (10%)"
  elseif eff:find("PARALYZE_SIDE") or eff:find("THUNDERBOLT") or eff:find("BODY_SLAM") or upperId == "SPARK" or upperId == "DRAGONBREATH" or upperId == "DRAGON_BREATH" or upperId == "BOUNCE" or upperId == "THUNDERBOLT" or upperId == "BODY_SLAM" or upperId == "THUNDERPUNCH" or upperId == "THUNDER" or upperId == "LICK" then
    return "Paralyze Chance"
  elseif eff:find("FLINCH") or upperId == "BITE" or upperId == "HEADBUTT" or upperId == "ROCK_SLIDE" or upperId == "ASTONISH" or upperId == "AIR_CUTTER" or upperId == "DARK_PULSE" or upperId == "IRON_HEAD" or upperId == "NEEDLE_ARM" then
    return "May Cause Flinch"
  elseif eff:find("CONFUSION") or upperId == "CONFUSE_RAY" or upperId == "SUPERSONIC" or upperId == "DYNAMICPUNCH" or upperId == "DYNAMIC_PUNCH" or upperId == "TEETER_DANCE" or upperId == "WATER_PULSE" or upperId == "SWEET_KISS" or upperId == "FLATTER" or upperId == "SWAGGER" then
    return "Causes Confusion"
  elseif eff:find("CHARGE") or upperId == "SOLARBEAM" or upperId == "FLY" or upperId == "DIG" or upperId == "DIVE" or upperId == "BOUNCE" or upperId == "RAZOR_WIND" or upperId == "SKULL_BASH" or upperId == "SKY_ATTACK" then
    return "Two-Turn Move"
  elseif eff:find("TWO_TO_FIVE") or upperId == "FURY_ATTACK" or upperId == "PIN_MISSILE" or upperId == "DOUBLESLAP" or upperId == "BULLET_SEED" or upperId == "ICICLE_SPEAR" or upperId == "ROCK_BLAST" or upperId == "ARM_THRUST" or upperId == "BONE_RUSH" or upperId == "SPIKE_CANNON" or upperId == "BARRAGE" or upperId == "FURY_SWIPES" then
    return "Multi-Hit (2-5x)"
  elseif eff:find("ATTACK_TWICE") or upperId == "DOUBLE_KICK" or upperId == "BONEMERANG" or upperId == "TWINEEDLE" then
    return "Hits Twice"
  elseif upperId == "QUICK_ATTACK" or upperId == "MACH_PUNCH" or upperId == "EXTREMESPEED" or upperId == "EXTREME_SPEED" or upperId == "FAKE_OUT" or upperId == "AQUA_JET" or upperId == "BULLET_PUNCH" or upperId == "ICE_SHARD" or upperId == "SHADOW_SNEAK" then
    return "Priority Move"
  elseif upperId == "SLASH" or upperId == "RAZOR_LEAF" or upperId == "KARATE_CHOP" or upperId == "CRABHAMMER" or upperId == "AEROBLAST" or upperId == "LEAF_BLADE" or upperId == "BLAZE_KICK" or upperId == "CROSS_CHOP" or upperId == "NIGHT_SLASH" or upperId == "STONE_EDGE" then
    return "High Critical Rate"
  elseif upperId == "DRAGON_RAGE" then
    return "Fixed 40 HP"
  elseif upperId == "SONICBOOM" then
    return "Fixed 20 HP"
  elseif upperId == "SEISMIC_TOSS" or upperId == "NIGHT_SHADE" then
    return "Level-Based Damage"
  elseif upperId == "SUPER_FANG" then
    return "Halves Foe HP"
  elseif upperId == "FALSE_SWIPE" then
    return "Leaves 1 HP"
  elseif upperId == "ENDEAVOR" then
    return "HP Equalizer"
  elseif upperId == "FACADE" then
    return "Status Boost"
  elseif upperId == "BRICK_BREAK" then
    return "Breaks Screens"
  elseif upperId == "HAIL" then
    return "Summons Hail"
  elseif upperId == "RAIN_DANCE" then
    return "Summons Rain"
  elseif upperId == "SUNNY_DAY" then
    return "Summons Sun"
  elseif upperId == "SANDSTORM" then
    return "Summons Sandstorm"
  elseif eff:find("SWIFT") or upperId == "SWIFT" or upperId == "AERIAL_ACE" or upperId == "SHOCK_WAVE" or upperId == "MAGICAL_LEAF" or upperId == "SHADOW_PUNCH" or upperId == "AURA_SPHERE" or upperId == "FEINT_ATTACK" or upperId == "FAINT_ATTACK" or upperId == "FAINTATTACK" then
    return "Never Misses"
  elseif upperId == "BELLY_DRUM" then
    return "Maximizes Attack"
  elseif upperId == "BATON_PASS" then
    return "Passes Stat Boosts"
  elseif upperId == "DRAGON_DANCE" or upperId == "CALM_MIND" or upperId == "BULK_UP" or upperId == "COSMIC_POWER" then
    return "Boosts 2 Stats"
  elseif pwr == 0 then
    if eff:find("UP2") or eff:find("SHARPLY") or upperId == "SWORDS_DANCE" or upperId == "AMNESIA" or upperId == "AGILITY" or upperId == "BARRIER" or upperId == "IRON_DEFENSE" or upperId == "TAIL_GLOW" or upperId == "NASTY_PLOT" or upperId == "ACID_ARMOR" then
      return "Sharply Boosts Stats"
    elseif eff:find("UP1") or eff:find("DEFENSE_CURL") or eff:find("HARDEN") or eff:find("MEDITATE") or eff:find("GROWTH") or upperId == "HOWL" or upperId == "STOCKPILE" then
      return "Raises User Stats"
    elseif eff:find("DOWN2") or upperId == "SCREECH" or upperId == "STRING_SHOT" or upperId == "SCARY_FACE" or upperId == "FEATHERDANCE" or upperId == "FEATHER_DANCE" or upperId == "FAKE_TEARS" or upperId == "METAL_SOUND" or upperId == "COTTON_SPORE" or upperId == "CHARM" then
      return "Harshly Lowers Foe Stats"
    elseif eff:find("DOWN1") or upperId == "GROWL" or upperId == "TAIL_WHIP" or upperId == "LEER" or upperId == "SAND_ATTACK" or upperId == "SMOKESCREEN" or upperId == "MUD_SLAP" or upperId == "SWEET_SCENT" or upperId == "TICKLE" then
      return "Lowers Foe Stats"
    else
      return "Support / Tactical"
    end
  end

  return "Standard Damage"
end

return MoveDatabase
