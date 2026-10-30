-- OmniUI Contest Database & Metadata Inspector
-- Provides Contest Categories (COOL, BEAUTY, CUTE, SMART, TOUGH), Appeal Hearts, Jam Hearts,
-- tactical contest effect tags, combo metadata, and authentic descriptions across Gen 1-3.

local ContestDatabase = {}

local CATEGORIES = {
  COOL = {
    id = 0,
    name = "COOL",
    label = "Cool",
    color = { 0.95, 0.35, 0.25 },
    bg = { 0.38, 0.12, 0.08 },
    border = { 0.95, 0.45, 0.35 },
  },
  BEAUTY = {
    id = 1,
    name = "BEAUTY",
    label = "Beauty",
    color = { 0.25, 0.65, 0.95 },
    bg = { 0.08, 0.22, 0.38 },
    border = { 0.35, 0.75, 0.98 },
  },
  CUTE = {
    id = 2,
    name = "CUTE",
    label = "Cute",
    color = { 0.95, 0.45, 0.70 },
    bg = { 0.38, 0.12, 0.26 },
    border = { 0.98, 0.55, 0.78 },
  },
  SMART = {
    id = 3,
    name = "SMART",
    label = "Smart",
    color = { 0.30, 0.80, 0.45 },
    bg = { 0.10, 0.32, 0.15 },
    border = { 0.40, 0.88, 0.55 },
  },
  TOUGH = {
    id = 4,
    name = "TOUGH",
    label = "Tough",
    color = { 0.90, 0.75, 0.20 },
    bg = { 0.36, 0.30, 0.06 },
    border = { 0.95, 0.82, 0.28 },
  },
}

ContestDatabase.CATEGORIES = CATEGORIES

local CATEGORY_BY_ID = {
  [0] = CATEGORIES.COOL,
  [1] = CATEGORIES.BEAUTY,
  [2] = CATEGORIES.CUTE,
  [3] = CATEGORIES.SMART,
  [4] = CATEGORIES.TOUGH,
}

-- Canonical Gen 3 Contest Move Registry
-- appeal: number of hearts (typically 1 to 6, max 8)
-- jam: number of startle hearts (0 to 4)
local CANONICAL_CONTEST_MOVES = {
  -- COOL MOVES
  POUND = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A basic, steady appeal that pleases the judges." },
  KARATE_CHOP = { category = "TOUGH", appeal = 3, jam = 0, effectTag = "FIRST APPEAL", desc = "Appeals better if the user performs first in the turn." },
  DOUBLESLAP = { category = "TOUGH", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Startles the Pokémon that appealed before the user." },
  COMET_PUNCH = { category = "TOUGH", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Startles the Pokémon that appealed before the user." },
  MEGA_PUNCH = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A powerful, standard appeal with high impact." },
  PAY_DAY = { category = "SMART", appeal = 1, jam = 0, effectTag = "POPULAR", desc = "Scatters glittering coins that win over the audience." },
  FIRE_PUNCH = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Ignites fiery excitement in the audience." },
  ICE_PUNCH = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A dazzling punch coated in glistening frost." },
  THUNDERPUNCH = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Crackles with electricity to wow the judge." },
  SCRATCH = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A basic, steady appeal with sharp claws." },
  VICEGRIP = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Displays impressive physical gripping power." },
  GUILLOTINE = { category = "COOL", appeal = 2, jam = 3, effectTag = "BADLY STARTLE", desc = "Badly startles all Pokémon that made good appeals." },
  RAZOR_WIND = { category = "COOL", appeal = 3, jam = 0, effectTag = "COMBO STARTER", desc = "Whips up fierce winds that set up powerful combos." },
  SWORDS_DANCE = { category = "BEAUTY", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "A magnificent battle dance that doubles subsequent appeals." },
  CUT = { category = "COOL", appeal = 2, jam = 1, effectTag = "JAM PRECEDING", desc = "Startles the Pokémon that performed just before user." },
  GUST = { category = "SMART", appeal = 3, jam = 0, effectTag = "STEADY APPEAL", desc = "Blows a refreshing gust across the contest stage." },
  WING_ATTACK = { category = "COOL", appeal = 2, jam = 1, effectTag = "STEADY APPEAL", desc = "Spreads magnificent wings wide for a stylish display." },
  WHIRLWIND = { category = "BEAUTY", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Blows a vortex that scrambles next round's turn order." },
  FLY = { category = "SMART", appeal = 1, jam = 0, effectTag = "AVOID STARTLE", desc = "Soars into the air, completely avoiding startles for 1 turn." },
  BIND = { category = "TOUGH", appeal = 3, jam = 0, effectTag = "STEADY APPEAL", desc = "Demonstrates muscular constriction power." },
  SLAM = { category = "TOUGH", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Slams the floor forcefully to startle competitors." },
  VINE_WHIP = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Snaps slender vines with razor-sharp precision." },
  STOMP = { category = "TOUGH", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Heavily startles all rivals that made previous appeals." },
  DOUBLE_KICK = { category = "COOL", appeal = 2, jam = 1, effectTag = "STEADY APPEAL", desc = "Delivers two crisp kicks in rapid succession." },
  MEGA_KICK = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A ferocious kick with dazzling athleticism." },
  JUMP_KICK = { category = "COOL", appeal = 6, jam = 0, effectTag = "HIGH APPEAL", desc = "A daring leaping kick with immense appeal points." },
  ROLLING_KICK = { category = "COOL", appeal = 3, jam = 0, effectTag = "FIRST APPEAL", desc = "A dynamic spinning kick that shines when performed first." },
  SAND_ATTACK = { category = "CUTE", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Kicks up fine sand cutely to disrupt competitors." },
  HEADBUTT = { category = "TOUGH", appeal = 2, jam = 3, effectTag = "JAM FOES", desc = "A headstrong charge that startles all preceding contestants." },
  HORN_ATTACK = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Proudly showcases a magnificent, sharp horn." },
  FURY_ATTACK = { category = "COOL", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Strikes repeatedly in an aggressive flurry." },
  HORN_DRILL = { category = "COOL", appeal = 2, jam = 3, effectTag = "BADLY STARTLE", desc = "Spins a horn furiously, terrifying rival contestants." },
  TACKLE = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A sturdy, honest tackle that earns consistent praise." },
  BODY_SLAM = { category = "TOUGH", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Drops full body weight onto the stage with tremendous impact." },
  WRAP = { category = "TOUGH", appeal = 3, jam = 0, effectTag = "STEADY APPEAL", desc = "Coils gracefully around to display flexibility." },
  TAKE_DOWN = { category = "TOUGH", appeal = 6, jam = 0, effectTag = "HIGH APPEAL", desc = "A risky, reckless charge that scores huge appeal." },
  THRASH = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "REPEATED APPEAL", desc = "Can be repeatedly performed without boring the judge." },
  DOUBLE_EDGE = { category = "TOUGH", appeal = 6, jam = 0, effectTag = "HIGH APPEAL", desc = "An all-or-nothing charge yielding massive appeal points." },
  TAIL_WHIP = { category = "CUTE", appeal = 2, jam = 0, effectTag = "CHARMING", desc = "Wags tail cutely, endearing the user to the judge." },
  POISON_STING = { category = "SMART", appeal = 2, jam = 3, effectTag = "JAM FOES", desc = "Flashes toxic barbs to startle preceding contestants." },
  TWINEEDLE = { category = "COOL", appeal = 2, jam = 1, effectTag = "STEADY APPEAL", desc = "Jabs twin needles with stylish martial finesse." },
  PIN_MISSILE = { category = "COOL", appeal = 2, jam = 1, effectTag = "STEADY APPEAL", desc = "Launches sharp pins into the air in a sparkling spray." },
  LEER = { category = "COOL", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "A piercing glare that shakes up the turn order." },
  BITE = { category = "TOUGH", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Snaps sharp teeth to startle competitors." },
  GROWL = { category = "CUTE", appeal = 2, jam = 0, effectTag = "CHARMING", desc = "Growls adorably, winning over the entire audience." },
  ROAR = { category = "COOL", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "A majestic roar that completely scrambles the turn order." },
  SING = { category = "CUTE", appeal = 2, jam = 1, effectTag = "SOOTHING", desc = "A sweet lullaby that calms and startles competitors." },
  SUPERSONIC = { category = "SMART", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Bizarre sound waves that disorient other contestants." },
  SONICBOOM = { category = "COOL", appeal = 2, jam = 1, effectTag = "STEADY APPEAL", desc = "Emits a crisp shock wave that reverberates in the hall." },
  DISABLE = { category = "SMART", appeal = 2, jam = 0, effectTag = "STOP EXCITEMENT", desc = "Prevents competitors from exciting the judge." },
  ACID = { category = "SMART", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Sprays pungent acid that badly startles all rivals." },
  EMBER = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Sparks warm, glowing embers that enchant the crowd." },
  FLAMETHROWER = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A breathtaking stream of vibrant, roaring fire." },
  MIST = { category = "BEAUTY", appeal = 1, jam = 0, effectTag = "AVOID STARTLE", desc = "Covers user in white mist, preventing all startles." },
  WATER_GUN = { category = "CUTE", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Squirts water playfully across the stage." },
  HYDRO_PUMP = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A magnificent geyser of high-pressure water." },
  SURF = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Rides a magnificent tidal wave across the hall." },
  ICE_BEAM = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A shimmering ray of pure ice crystals." },
  BLIZZARD = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Summons a howling blizzard that covers stage in snow." },
  PSYBEAM = { category = "BEAUTY", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Flashes psychedelic light beams that bewilder foes." },
  BUBBLEBEAM = { category = "BEAUTY", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Blasts iridescent bubbles that startle rivals." },
  AURORA_BEAM = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "An ethereal aurora curtain glowing with rainbow light." },
  HYPER_BEAM = { category = "COOL", appeal = 6, jam = 0, effectTag = "HIGH APPEAL", desc = "An overwhelmingly powerful beam yielding enormous appeal." },
  PECK = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Pecks smartly with a sharp, poised beak." },
  DRILL_PECK = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Spins like a drill for a thrilling aerial performance." },
  SUBMISSION = { category = "COOL", appeal = 6, jam = 0, effectTag = "HIGH APPEAL", desc = "A reckless wrestling throw that dazzles the crowd." },
  LOW_KICK = { category = "TOUGH", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "A low sweep that trips up and startles rivals." },
  COUNTER = { category = "TOUGH", appeal = 2, jam = 0, effectTag = "LAST APPEAL", desc = "Appeals best if performed last in the round." },
  SEISMIC_TOSS = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Heaves the rival high into the air with gravity power." },
  STRENGTH = { category = "TOUGH", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Shows off titanic muscular strength to intimidate foes." },
  ABSORB = { category = "SMART", appeal = 2, jam = 1, effectTag = "JAM PRECEDING", desc = "Drains energy gently from the preceding contestant." },
  MEGA_DRAIN = { category = "SMART", appeal = 2, jam = 1, effectTag = "JAM PRECEDING", desc = "Drains vibrant vitality from preceding performers." },
  LEECH_SEED = { category = "SMART", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Plants tiny seeds that disrupt rival performances." },
  GROWTH = { category = "BEAUTY", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "Forces the body to bloom, enhancing subsequent appeals." },
  RAZOR_LEAF = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Launches razor-sharp glistening leaves with panache." },
  SOLARBEAM = { category = "COOL", appeal = 4, jam = 0, effectTag = "COMBO FINISHER", desc = "Absorbs solar energy to unleash a glorious light beam." },
  POISONPOWDER = { category = "SMART", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Scatters glittering toxic dust across the stage." },
  STUN_SPORE = { category = "SMART", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Releases paralyzing spores that freeze rivals." },
  SLEEP_POWDER = { category = "SMART", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Drifts soothing sleep spores over the entire arena." },
  PETAL_DANCE = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "REPEATED APPEAL", desc = "A splendid dance amidst a swirling flurry of flower petals." },
  STRING_SHOT = { category = "SMART", appeal = 2, jam = 3, effectTag = "JAM FOES", desc = "Spins fine silk across the arena to startle rivals." },
  DRAGON_RAGE = { category = "COOL", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Breathes Draconic blue fire that shakes the auditorium." },
  FIRE_SPIN = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Traps the stage in a swirling, beautiful ribbon of fire." },
  THUNDERSHOCK = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Crackles with playful electric sparks." },
  THUNDERBOLT = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A dazzling lightning strike that electrifies the audience." },
  THUNDER_WAVE = { category = "COOL", appeal = 2, jam = 3, effectTag = "JAM FOES", desc = "Sends out static waves that startle preceding performers." },
  THUNDER = { category = "COOL", appeal = 2, jam = 2, effectTag = "BADLY STARTLE", desc = "Brings down a thunderous bolt with deafening applause." },
  ROCK_THROW = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Hurls sturdy boulders with primitive vigor." },
  EARTHQUAKE = { category = "TOUGH", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Shakes the entire foundation of the contest hall." },
  FISSURE = { category = "TOUGH", appeal = 2, jam = 3, effectTag = "BADLY STARTLE", desc = "Splits open the floor with earth-shattering power." },
  DIG = { category = "SMART", appeal = 1, jam = 0, effectTag = "AVOID STARTLE", desc = "Burrows underground, evading all rival startles." },
  TOXIC = { category = "SMART", appeal = 3, jam = 0, effectTag = "BADLY STARTLE", desc = "Secretes harsh venom that shocks the judges." },
  CONFUSION = { category = "SMART", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Emits telekinetic pulses that scramble the turn order." },
  PSYCHIC = { category = "SMART", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Radiates formidable telekinetic mental prowess." },
  HYPNOSIS = { category = "SMART", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Swings a hypnotic pendulum to mesmerize rival Pokémon." },
  MEDITATE = { category = "BEAUTY", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "Calms the inner spirit to prepare for a grand combo." },
  AGILITY = { category = "COOL", appeal = 3, jam = 0, effectTag = "FIRST APPEAL", desc = "Dashes at blinding speed, ensuring first appeal next round." },
  QUICK_ATTACK = { category = "COOL", appeal = 3, jam = 0, effectTag = "FIRST APPEAL", desc = "Strikes with blinding speed to dazzle when going first." },
  RAGE = { category = "COOL", appeal = 3, jam = 0, effectTag = "REPEATED APPEAL", desc = "Can be repeatedly used without boring the judges." },
  TELEPORT = { category = "COOL", appeal = 1, jam = 0, effectTag = "AVOID STARTLE", desc = "Vanishes in a flash, avoiding all startle effects." },
  NIGHT_SHADE = { category = "SMART", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Conjures a spooky mirage that spooks preceding rivals." },
  MIMIC = { category = "CUTE", appeal = 1, jam = 0, effectTag = "COPY MOVE", desc = "Cleverly mimics the appeal of the previous contestant." },
  SCREECH = { category = "SMART", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Emits an ear-splitting shriek that rattles all rivals." },
  DOUBLE_TEAM = { category = "COOL", appeal = 2, jam = 0, effectTag = "AVOID STARTLE", desc = "Creates illusory copies to slip away from startles." },
  RECOVER = { category = "SMART", appeal = 2, jam = 0, effectTag = "AVOID STARTLE", desc = "Restores grace and composure, soothing any startles." },
  HARDEN = { category = "TOUGH", appeal = 2, jam = 0, effectTag = "AVOID STARTLE", desc = "Stiffens muscles defensively to block startles." },
  MINIMIZE = { category = "CUTE", appeal = 2, jam = 0, effectTag = "AVOID STARTLE", desc = "Shrinks cutely to avoid being startled by competitors." },
  SMOKESCREEN = { category = "SMART", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Billows dark smoke that obfuscates the stage order." },
  CONFUSE_RAY = { category = "SMART", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Flashes sinister ghostly lights to confuse all rivals." },
  WITHDRAW = { category = "CUTE", appeal = 2, jam = 0, effectTag = "AVOID STARTLE", desc = "Hides inside its sturdy shell to avoid startle effects." },
  DEFENSE_CURL = { category = "CUTE", appeal = 2, jam = 0, effectTag = "COMBO STARTER", desc = "Curls up cutely, setting up Rollout and Ice Ball combos." },
  BARRIER = { category = "COOL", appeal = 1, jam = 0, effectTag = "AVOID STARTLE", desc = "Erects a sparkling psychic wall that stops startles." },
  LIGHT_SCREEN = { category = "BEAUTY", appeal = 1, jam = 0, effectTag = "AVOID STARTLE", desc = "Erects a shimmering light barrier to safeguard appeal." },
  HAZE = { category = "BEAUTY", appeal = 3, jam = 0, effectTag = "STOP EXCITEMENT", desc = "Spreads cool haze that halts the judge's excitement." },
  REFLECT = { category = "SMART", appeal = 1, jam = 0, effectTag = "AVOID STARTLE", desc = "A reflective crystal wall that shields against startles." },
  FOCUS_ENERGY = { category = "COOL", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "Focuses immense spirit to double subsequent appeals." },
  BIDE = { category = "TOUGH", appeal = 1, jam = 0, effectTag = "AVOID STARTLE", desc = "Endures the crowd's gaze stoically without flinching." },
  METRONOME = { category = "CUTE", appeal = 3, jam = 0, effectTag = "RANDOM APPEAL", desc = "Wags finger unpredictably for a delightful surprise." },
  MIRROR_MOVE = { category = "SMART", appeal = 1, jam = 0, effectTag = "COPY MOVE", desc = "Replicates the dazzling move of the previous performer." },
  SELFDESTRUCT = { category = "BEAUTY", appeal = 8, jam = 0, effectTag = "EXPLOSION", desc = "Detonates with blinding brilliance for maximum appeal!" },
  EXPLOSION = { category = "BEAUTY", appeal = 8, jam = 0, effectTag = "EXPLOSION", desc = "Massive explosion delivering legendary appeal points!" },
  EGG_BOMB = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Hurls an explosive egg with surprising flair." },
  LICK = { category = "TOUGH", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Licks with a long tongue to creep out and startle rivals." },
  SMOG = { category = "TOUGH", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Releases foul smog that thoroughly startles rivals." },
  SLUDGE = { category = "TOUGH", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Hurls toxic sludge with shocking stage presence." },
  BONE_CLUB = { category = "TOUGH", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Swings a bone club with fierce prehistoric energy." },
  FIRE_BLAST = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A magnificent blazing kanji that illuminates the arena." },
  WATERFALL = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Charges up a roaring cascade with majestic grace." },
  CLAMP = { category = "TOUGH", appeal = 3, jam = 0, effectTag = "STEADY APPEAL", desc = "Snaps sturdy shells shut with resonant power." },
  SWIFT = { category = "COOL", appeal = 2, jam = 0, effectTag = "STEADY APPEAL", desc = "Fires golden stars that never miss the judge's eyes." },
  SKULL_BASH = { category = "TOUGH", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Drives head into foes to deliver a heavy startle." },
  SPIKE_CANNON = { category = "COOL", appeal = 2, jam = 1, effectTag = "STEADY APPEAL", desc = "Fires sharp spikes like arrows in rapid succession." },
  CONSTRICT = { category = "TOUGH", appeal = 2, jam = 3, effectTag = "JAM FOES", desc = "Constricts tightly to startle and intimidate foes." },
  AMNESIA = { category = "CUTE", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "Forgets worries cutely to set up psychic combos." },
  KINESIS = { category = "SMART", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Bends spoons telekinetically to baffle the crowd." },
  SOFTBOILED = { category = "BEAUTY", appeal = 2, jam = 0, effectTag = "AVOID STARTLE", desc = "Shares a warm egg that revitalizes the user." },
  HI_JUMP_KICK = { category = "COOL", appeal = 6, jam = 0, effectTag = "HIGH APPEAL", desc = "A sensational flying high-kick of supreme athletic skill." },
  GLARE = { category = "COOL", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Intimidates rivals with a chilling serpentine gaze." },
  DREAM_EATER = { category = "SMART", appeal = 2, jam = 1, effectTag = "JAM PRECEDING", desc = "Eats the dreams of rivals who made sleep appeals." },
  POISON_GAS = { category = "SMART", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Releases cloud of toxic gas that startles competitors." },
  BARRAGE = { category = "TOUGH", appeal = 2, jam = 1, effectTag = "STEADY APPEAL", desc = "Hurls round seeds repeatedly at the target." },
  LEECH_LIFE = { category = "SMART", appeal = 2, jam = 1, effectTag = "JAM PRECEDING", desc = "Drains life energy from preceding contestants." },
  LOVELY_KISS = { category = "BEAUTY", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Blows an irresistible kiss that flusters rivals." },
  SKY_ATTACK = { category = "COOL", appeal = 3, jam = 0, effectTag = "COMBO FINISHER", desc = "Cloaks body in brilliant light and dives from heaven." },
  TRANSFORM = { category = "SMART", appeal = 1, jam = 0, effectTag = "COPY MOVE", desc = "Transforms completely into the preceding Pokémon." },
  BUBBLE = { category = "CUTE", appeal = 2, jam = 2, effectTag = "JAM FOES", desc = "Blows delicate bubbles that drift and pop cutely." },
  DIZZY_PUNCH = { category = "COOL", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Punches in a dizzy, comical rhythm that confuses." },
  SPORE = { category = "BEAUTY", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Scatters 100% hypnotic golden spores everywhere." },
  FLASH = { category = "BEAUTY", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Flashes radiant light that scrambles the turn order." },
  PSYWAVE = { category = "SMART", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Telekinetic waves of shifting, eerie intensity." },
  SPLASH = { category = "CUTE", appeal = 2, jam = 0, effectTag = "CHARMING", desc = "Flops about hilariously to the delight of the crowd." },
  ACID_ARMOR = { category = "TOUGH", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "Melts into liquid to set up devastating combos." },
  CRABHAMMER = { category = "TOUGH", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Swings massive pincer hammer with resounding thump." },
  FURY_SWIPES = { category = "TOUGH", appeal = 2, jam = 1, effectTag = "STEADY APPEAL", desc = "Rakes claws in a dazzling, swift combination." },
  REST = { category = "CUTE", appeal = 2, jam = 0, effectTag = "AVOID STARTLE", desc = "Naps peacefully on stage, immune to all startles." },
  ROCK_SLIDE = { category = "TOUGH", appeal = 1, jam = 3, effectTag = "JAM FOES", desc = "Triggers a mini rockslide that rattles rivals." },
  SHARPEN = { category = "CUTE", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "Reduces polygon count cutely to set up combos." },
  CONVERSION = { category = "BEAUTY", appeal = 2, jam = 0, effectTag = "AVOID STARTLE", desc = "Alters code and color scheme with modern digital flair." },
  TRI_ATTACK = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Unleashes fire, frost, and electricity in unison." },
  SUPER_FANG = { category = "TOUGH", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Shows off formidable, sharp incisors with a crunch." },
  SLASH = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A clean, decisive blade slash of pure elegance." },
  SUBSTITUTE = { category = "SMART", appeal = 2, jam = 0, effectTag = "AVOID STARTLE", desc = "Leaves a cute decoy doll to take all startles." },
  STRUGGLE = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Fights desperately with all remaining strength." },

  -- Gen 2 & 3 Additions
  AEROBLAST = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "A vortex of vortex wind fired with legendary grace." },
  SACRED_FIRE = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Mystical pure flames that shimmer like gold." },
  DRAGON_CLAW = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Slashes with sharp, iridescent draconic talons." },
  SHADOW_BALL = { category = "SMART", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Hurls an ominous orb of dark spiritual energy." },
  BRICK_BREAK = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Smashes through defenses with martial perfection." },
  AERIAL_ACE = { category = "COOL", appeal = 2, jam = 0, effectTag = "STEADY APPEAL", desc = "A swift, unavoidable aerial slash of peerless style." },
  SILVER_WIND = { category = "BEAUTY", appeal = 1, jam = 0, effectTag = "POPULAR", desc = "Whips up wind powdered with sparkling silver scales." },
  DRAGON_DANCE = { category = "COOL", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "An ancient draconic dance that ignites passions." },
  CALM_MIND = { category = "SMART", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "Focuses the mind serenely, priming immense combos." },
  BULK_UP = { category = "BEAUTY", appeal = 1, jam = 0, effectTag = "COMBO STARTER", desc = "Flexes sculpted muscles to the admiration of all." },
  OVERHEAT = { category = "BEAUTY", appeal = 6, jam = 0, effectTag = "HIGH APPEAL", desc = "Unleashes maximum blazing heat in an awe-inspiring blast." },
  VOLT_TACKLE = { category = "COOL", appeal = 6, jam = 0, effectTag = "HIGH APPEAL", desc = "Electrifies body and charges with thunderous energy." },
  SIGNAL_BEAM = { category = "BEAUTY", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Fires colorful flashing beams that scramble the order." },
  EXTREMESPEED = { category = "COOL", appeal = 3, jam = 0, effectTag = "FIRST APPEAL", desc = "Moves at blinding supersonic speed to appeal first." },
  METEOR_MASH = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Strikes with the blazing force of a falling meteor." },
  BLAZE_KICK = { category = "BEAUTY", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Launches a fiery flying kick that leaves a blazing trail." },
  WATER_PULSE = { category = "BEAUTY", appeal = 3, jam = 0, effectTag = "SCRAMBLE ORDER", desc = "Pulses rhythmic water vibrations across the arena." },
  MUDDY_WATER = { category = "TOUGH", appeal = 2, jam = 1, effectTag = "JAM FOES", desc = "Shoots muddy water to startle preceding rivals." },
  LEAF_BLADE = { category = "COOL", appeal = 4, jam = 0, effectTag = "STEADY APPEAL", desc = "Slashes with sharp, leaf-shaped blades with supreme cool." },
  CRUNCH = { category = "TOUGH", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Crunches viciously to startle all rival performers." },
  ANCIENTPOWER = { category = "TOUGH", appeal = 1, jam = 0, effectTag = "POPULAR", desc = "Unearths prehistoric power to enchant the audience." },
  IRON_TAIL = { category = "COOL", appeal = 1, jam = 4, effectTag = "HEAVY JAM", desc = "Slams a steel-hard tail to startle preceding rivals." },
  OUTRAGE = { category = "COOL", appeal = 4, jam = 0, effectTag = "REPEATED APPEAL", desc = "A rampaging fury that can be repeated without boring." },
  GIGA_DRAIN = { category = "SMART", appeal = 2, jam = 1, effectTag = "JAM PRECEDING", desc = "Drains magnificent vitality from preceding contestants." },
}

--- Resolves the Contest definition for a given move.
--- Tries ROM cache first, then canonical database, then fallback.
function ContestDatabase.getContestDef(moveId, moveDef, game)
  if not moveId then return nil end

  local normKey = tostring(moveId):upper():gsub("[%s%-]", "_")

  -- 1. Check GBA Cache / Kit Lua if loaded
  local Kit = package.loaded["src.ui.game3.rse.scene_kit"]
  if Kit and Kit.loadLua then
    local ok, c = pcall(Kit.loadLua, "data/generated/gba/pokemon/contest_moves.lua")
    if ok and c and c.moves then
      local numId = tonumber(moveId) or (type(moveDef) == "table" and moveDef.id and tonumber(moveDef.id))
      if numId and c.moves[numId] then
        local cm = c.moves[numId]
        local eff = c.effects and c.effects[cm.effect]
        local catObj = CATEGORY_BY_ID[cm.category or 0] or CATEGORIES.COOL
        local appealHearts = (eff and eff.appeal and eff.appeal ~= 0xFF) and math.floor(eff.appeal / 10) or 2
        local jamHearts = (eff and eff.jam and eff.jam ~= 0xFF) and math.floor(eff.jam / 10) or 0
        local desc = (eff and eff.description and eff.description ~= "") and eff.description or (CANONICAL_CONTEST_MOVES[normKey] and CANONICAL_CONTEST_MOVES[normKey].desc) or "A stylish contest performance."
        return {
          category = catObj.name,
          categoryDef = catObj,
          appeal = appealHearts,
          jam = jamHearts,
          effectTag = (CANONICAL_CONTEST_MOVES[normKey] and CANONICAL_CONTEST_MOVES[normKey].effectTag) or "CONTEST MOVE",
          desc = desc,
          comboStarter = cm.comboStarterId or 0,
        }
      end
    end
  end

  -- 2. Check Canonical Registry
  local canon = CANONICAL_CONTEST_MOVES[normKey]
  if canon then
    local catObj = CATEGORIES[canon.category] or CATEGORIES.COOL
    return {
      category = catObj.name,
      categoryDef = catObj,
      appeal = canon.appeal or 4,
      jam = canon.jam or 0,
      effectTag = canon.effectTag or "STEADY APPEAL",
      desc = canon.desc or "A stylish contest appeal.",
      comboStarter = 0,
    }
  end

  -- 3. Fallback derivation based on battle move properties
  local mtype = (moveDef and moveDef.type) or "NORMAL"
  local mcat = (moveDef and moveDef.category) or "PHYSICAL"
  local fallbackCat = "COOL"
  if mtype == "FIRE" or mtype == "WATER" or mtype == "ICE" then
    fallbackCat = "BEAUTY"
  elseif mtype == "PSYCHIC" or mtype == "GHOST" or mtype == "GRASS" or mtype == "POISON" then
    fallbackCat = "SMART"
  elseif mtype == "NORMAL" and mcat == "STATUS" then
    fallbackCat = "CUTE"
  elseif mtype == "ROCK" or mtype == "GROUND" or mtype == "FIGHTING" or mtype == "STEEL" then
    fallbackCat = "TOUGH"
  end

  local catObj = CATEGORIES[fallbackCat] or CATEGORIES.COOL
  return {
    category = catObj.name,
    categoryDef = catObj,
    appeal = 4,
    jam = 0,
    effectTag = "STEADY APPEAL",
    desc = "A solid, standard contest appeal that appeals to the judges.",
    comboStarter = 0,
  }
end

--- Returns the category name (e.g. "BEAUTY", "COOL")
function ContestDatabase.getCategory(moveId, moveDef, game)
  local def = ContestDatabase.getContestDef(moveId, moveDef, game)
  return def and def.category or "COOL"
end

--- Returns the Category Definition table (with name, color, bg, border)
function ContestDatabase.getCategoryDef(categoryName)
  local k = tostring(categoryName or "COOL"):upper()
  return CATEGORIES[k] or CATEGORIES.COOL
end

--- Returns the Appeal Heart count (number of hearts, typically 1 to 8)
function ContestDatabase.getAppeal(moveId, moveDef, game)
  local def = ContestDatabase.getContestDef(moveId, moveDef, game)
  return def and def.appeal or 4
end

--- Returns the Jam Heart count (number of hearts, typically 0 to 4)
function ContestDatabase.getJam(moveId, moveDef, game)
  local def = ContestDatabase.getContestDef(moveId, moveDef, game)
  return def and def.jam or 0
end

--- Returns tactical effect tag (e.g. "HIGH APPEAL", "JAM FOES", "AVOID STARTLE")
function ContestDatabase.getEffectTag(moveId, moveDef, game)
  local def = ContestDatabase.getContestDef(moveId, moveDef, game)
  return def and def.effectTag or "CONTEST MOVE"
end

--- Returns authentic contest description
function ContestDatabase.getDescription(moveId, moveDef, game)
  local def = ContestDatabase.getContestDef(moveId, moveDef, game)
  return def and def.desc or "A stylish contest performance."
end

--- Formats appeal hearts string, e.g. "♥♥♥♥"
function ContestDatabase.formatAppealHearts(appealCount, maxHearts)
  appealCount = math.max(0, math.min(8, tonumber(appealCount) or 0))
  maxHearts = maxHearts or appealCount
  local s = ""
  for i = 1, appealCount do
    s = s .. "♥"
  end
  for i = appealCount + 1, maxHearts do
    s = s .. "♡"
  end
  return s
end

--- Formats jam startle hearts string, e.g. "💔💔"
function ContestDatabase.formatJamHearts(jamCount)
  jamCount = math.max(0, math.min(5, tonumber(jamCount) or 0))
  if jamCount == 0 then return "-" end
  local s = ""
  for i = 1, jamCount do
    s = s .. "💔"
  end
  return s
end

return ContestDatabase
