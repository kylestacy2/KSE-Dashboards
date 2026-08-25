local G = {
  referenceW=800, referenceH=480,
  screenW=tonumber(LCD_W) or 800, screenH=tonumber(LCD_H) or 480,
  originX=0, originY=0, scaleX=1, scaleY=1, scaleMin=1,
  compact=false, compactJumboHero=false, largeScreen=false,
  screen480x320=false, screen800x480=false,
}
local SMLSIZE      = rawget(_G, "SMLSIZE")      or SMLSIZE      or 0
local MIDSIZE      = rawget(_G, "MIDSIZE")      or MIDSIZE      or 0
local DBLSIZE      = rawget(_G, "DBLSIZE")      or DBLSIZE      or 0
local XXLSIZE      = rawget(_G, "XXLSIZE")      or XXLSIZE      or DBLSIZE
G.fontSmall, G.fontValue, G.fontHero, G.fontTimer = SMLSIZE, MIDSIZE,
                                                     DBLSIZE, MIDSIZE
G.fontTop, G.fontGovernor, G.fontBattery = MIDSIZE, DBLSIZE, MIDSIZE
G.fontSecondaryLabel, G.fontSecondaryValue = SMLSIZE, SMLSIZE
local VALUE  = rawget(_G, "VALUE")  or 0
local BOOL   = rawget(_G, "BOOL")   or 2
local CHOICE = rawget(_G, "CHOICE") or 10
local STRING = rawget(_G, "STRING") or 3
local SOURCE = rawget(_G, "SOURCE") or _G.SOURCE or 1
-- EdgeTX exposes these flags through its read-only global lookup table. The
-- public Lua name for CENTERED is CENTER, so rawget("CENTERED") silently
-- returned nil and made every intended centered/right-aligned label align left.
local RIGHT = rawget(_G, "RIGHT") or _G.RIGHT or 0
local CENTERED = rawget(_G, "CENTER") or rawget(_G, "CENTERED")
                 or _G.CENTER or _G.CENTERED or 0
G.rounded = function(v)
  return math.floor(v + 0.5)
end
G.x = function(v)
  return G.rounded(v * G.scaleX)
end
G.y = function(v)
  return G.rounded(v * G.scaleY)
end
G.min = function(v)
  return G.rounded(v * G.scaleMin)
end
G.positiveSize = function(v, fallback)
  v = tonumber(v)
  if not v or v < 1 then return fallback end
  return G.rounded(v)
end
G.bounds = function(zone, fullScreen)
  if fullScreen then return 0, 0, G.screenW, G.screenH end
  local w = G.positiveSize(zone and zone.w, G.screenW)
  local h = G.positiveSize(zone and zone.h, G.screenH)
  local x = G.rounded(tonumber(zone and zone.x) or 0)
  local y = G.rounded(tonumber(zone and zone.y) or 0)
  return x, y, w, h
end
G.signature = function(x, y, w, h)
  return table.concat({ x, y, w, h }, ":")
end
G.configure = function(x, y, w, h)
  G.originX, G.originY = x, y
  G.w, G.h = w, h
  G.scaleX = G.w / G.referenceW
  G.scaleY = G.h / G.referenceH
  G.scaleMin = math.min(G.scaleX, G.scaleY)
  -- TX15-class screens are 480x320, while TX16S MKII is 480x272. Both need a
  -- compact typography/layout pass because EdgeTX bitmap fonts do not scale
  -- continuously with the panel geometry. TX16S MK3 remains on the 800x480
  -- reference presentation.
  G.compact = G.w <= 520
  G.compactJumboHero = G.compact and G.w >= 460 and G.h >= 260
  G.largeScreen = G.w >= 700 and G.h >= 420
  G.screen480x320 = G.screenW == 480 and G.screenH == 320
                      and G.w == 480 and G.h == 320
  G.screen800x480 = G.screenW == 800 and G.screenH == 480
                      and G.w == 800 and G.h == 480

  -- Font constants select discrete EdgeTX fonts; they are not additive style
  -- flags. In particular, combining BOLD with SMLSIZE/MIDSIZE can select an
  -- unintended oversized font and make retained LVGL labels wrap.
  G.fontSmall = SMLSIZE
  G.fontValue = G.screen800x480 and DBLSIZE
                or (G.scaleMin < 0.50 and SMLSIZE or MIDSIZE)
  G.fontHero = (G.largeScreen or G.compactJumboHero) and XXLSIZE
               or (G.scaleMin < 0.50 and SMLSIZE
               or ((not G.compact or (G.w >= 460 and G.h >= 260))
                   and DBLSIZE or MIDSIZE))
  G.fontTimer = G.scaleMin < 0.50 and SMLSIZE or MIDSIZE
  G.fontTop = G.scaleMin < 0.50 and SMLSIZE or MIDSIZE
  G.fontGovernor = G.scaleMin < 0.50 and SMLSIZE
                     or (G.compact and MIDSIZE or DBLSIZE)
  G.fontBattery = G.scaleMin < 0.50 and SMLSIZE or MIDSIZE
  G.fontSecondaryLabel = G.fontSmall
  G.fontSecondaryValue = G.largeScreen and MIDSIZE or G.fontSmall

  G.layout = {
    top  = { x=x + G.x(10), y=y + G.y(8), h=math.max(1, G.y(36)) },
    pic  = { x=x + G.x(10),  y=y + G.y(56),
             w=math.max(1, G.x(280)), h=math.max(1, G.y(180)),
             r=math.max(0, G.min(7)) },
    gov  = { x=x + G.x(10),  y=y + G.y(246),
             w=math.max(1, G.x(280)), h=math.max(1, G.y(108)),
             r=math.max(0, G.min(7)) },
    hero = { x=x + G.x(300), y=y + G.y(56),
             w=math.max(1, G.x(490)), h=math.max(1, G.y(140)),
             r=math.max(0, G.min(7)) },
    tiles= { x=x + G.x(300), y=y + G.y(206),
             w=math.max(1, G.x(490)), h=math.max(1, G.y(148)),
             r=math.max(0, G.min(7)), gap=math.max(1, G.x(8)) },
    bot  = { x=x + G.x(10), w=math.max(1, G.x(780)),
             h=math.max(1, G.y(100)), padBot=math.max(0, G.y(14)),
             r=math.max(0, G.min(7)) },
  }
  G.layout.bot.y = y + G.h - G.layout.bot.padBot - G.layout.bot.h
end
local C_BG, C_TEXT, C_DIM, C_LINE, C_TILE
local C_GREEN_BG, C_GREEN_BR
local C_YELLOW_BG, C_YELLOW_BR
local C_RED_BG,    C_RED_BR
local C_BLUE_BG,   C_BLUE_BR
local C_GREEN, C_YELLOW, C_RED, C_BLUE
local DEFAULT_ACCENT, C_ACCENT
local C_BLACK
-- RotorFlight 2.3 exposes six battery-profile slots. MSP uses zero-based
-- indexes while the BAT# telemetry sensor and the user-facing UI use 1..6.
local BATTERY_PROFILE_COUNT = 6
local GOV_STATES = {
  [0]="OFF",      [1]="IDLE",     [2]="SPOOLUP",  [3]="RECOVERY",
  [4]="ACTIVE",   [5]="THR-OFF",  [6]="LOST-HS",
  [7]="AUTOROT",  [8]="BAILOUT",  [9]="BYPASS",
}
-- Only explicit, recognized states participate in the motor-alert gate. An
-- unknown future enum must never be interpreted as motor-off.
local GOV_RUNNING_STATE = {
  [2]=true, -- SPOOLUP
  [3]=true, -- RECOVERY
  [4]=true, -- ACTIVE
  [8]=true, -- BAILOUT
  [9]=true, -- BYPASS
}
local GOV_STOP_STATE = {
  [0]=true, -- OFF
  [5]=true, -- THR-OFF / lost throttle
  [7]=true, -- AUTOROT
}
local GOV_PAUSE_HOLD_STATE = {
  [0]=true, -- OFF
  [1]=true, -- IDLE after a previously validated stop
  [5]=true, -- THR-OFF / lost throttle
  [7]=true, -- AUTOROT
}
local GOV_LABELS = { AUTOROT="AUTO" }
local GOV_COLOR = {}
local GOV_FALLBACK = {}
local themeAccent = nil
-- Single-color themes: solid bg + tiles a lighter shade of the
-- SAME hue (the original monochromatic look). Paired and specialty themes use
-- contrasting surfaces/accents. All keep text + status colors legible.
-- CHOICE values are 1-based. (bg = page background, tile = panel.)
local COLOR_THEMES = {
  orange = { bg={ 92, 42,  2}, tile={120, 60, 10}, line={160, 86, 24}, dim={230,178,120}, accent={255,155, 35} },
  red    = { bg={100, 18, 18}, tile={130, 28, 28}, line={180, 50, 50}, dim={240,165,165}, accent={255, 95, 95} },
  blue   = { bg={  4, 20, 54}, tile={ 10, 32, 74}, line={ 28, 72,124}, dim={150,180,220}, accent={ 80,165,255} },
  pink   = { bg={145,  0, 83}, tile={184,  0,105}, line={255, 20,147}, dim={255,196,225}, accent={255,222,239} },
  green  = { bg={  6, 54, 22}, tile={ 12, 74, 34}, line={ 24,120, 58}, dim={150,215,175}, accent={ 60,220,120} },
  purple = { bg={ 34, 12, 60}, tile={ 50, 22, 82}, line={ 92, 46,140}, dim={190,165,225}, accent={175,110,245} },
  reef   = { bg={  8, 22, 58}, tile={  8, 46, 50}, line={ 24, 96,104}, dim={150,190,218}, accent={ 70,200,230} },
  royal  = { bg={ 40, 16, 66}, tile={ 52, 40, 12}, line={112, 88, 28}, dim={202,172,228}, accent={180,120,248} },
  ember  = { bg={ 70, 18, 10}, tile={ 92, 52,  8}, line={150, 88, 26}, dim={235,175,150}, accent={255,150, 50} },
  graphite = { bg={ 18, 21, 25}, tile={ 34, 39, 46}, line={ 75, 85, 98}, dim={165,175,188}, accent={215,225,235} },
  glacier  = { bg={  8, 28, 42}, tile={ 18, 52, 68}, line={ 46,105,126}, dim={155,203,218}, accent={117,225,250} },
  sunset   = { bg={ 96, 12, 10}, tile={160, 48,  8}, line={230,105, 20}, dim={255,191,145}, accent={255,190, 48} },
  synthwave= { bg={ 22, 10, 55}, tile={ 59, 13, 70}, line={147, 35,126}, dim={205,154,226}, accent={ 71,229,255} },
  gulf     = { bg={ 10, 48, 65}, tile={ 16, 72, 88}, line={204,102, 36}, dim={162,205,216}, accent={255,139, 59} },
  voltage  = { bg={  9, 19, 10}, tile={ 26, 37, 17}, line={ 83,117, 31}, dim={183,204,145}, accent={185,255, 50} },
  titanium_ember = { bg={ 11, 14, 18}, tile={ 41, 49, 58}, line={100,113,125}, dim={174,184,193}, accent={255,138, 61} },
  aurora   = { bg={  6, 27, 24}, tile={ 23, 27, 59}, line={ 52, 84,122}, dim={159,185,200}, accent={116,242,206} },
  desert_night = { bg={ 26, 21, 12}, tile={ 52, 51, 27}, line={118,101, 59}, dim={201,187,139}, accent={245,196, 81} },
}
local THEME_NAMES = {
  [2] = "light",  [4] = "orange", [5] = "red",      [6] = "blue",
  [7] = "pink",   [8] = "green",  [9] = "purple",   [10] = "reef",
  [11]= "royal",  [12]= "ember",  [13]= "graphite", [14] = "glacier",
  [15]= "sunset", [16]= "synthwave", [17]= "gulf",  [18] = "voltage",
  [19]= "light",
  [20]= "titanium_ember", [21]= "aurora", [22]= "desert_night",
}
local function applyTheme(name)
  local rgb = lcd.RGB
  local ct = COLOR_THEMES[name]
  themeAccent = nil
  if not C_GREEN then
    C_GREEN        = rgb( 34, 197,  94)
    C_YELLOW       = rgb(240, 180,  41)
    C_RED          = rgb(239,  68,  68)
    C_BLUE         = rgb( 50, 130, 235)
    DEFAULT_ACCENT = rgb( 95, 211, 188)
    C_ACCENT       = DEFAULT_ACCENT
    C_BLACK        = rgb(  0,   0,   0)
  end
  if name == "light" or (ct and ct.light) then
    C_BG        = rgb(255, 255, 255)
    C_TEXT      = rgb(  0,   0,   0)
    C_DIM       = rgb(110, 110, 110)
    C_LINE      = rgb(210, 210, 210)
    C_TILE      = rgb(242, 242, 242)
    C_GREEN_BG  = rgb(220, 245, 228)
    C_GREEN_BR  = rgb(160, 210, 178)
    C_YELLOW_BG = rgb(255, 243, 205)
    C_YELLOW_BR = rgb(230, 200, 100)
    C_RED_BG    = rgb(252, 225, 225)
    C_RED_BR    = rgb(230, 170, 170)
    C_BLUE_BG   = rgb(225, 238, 255)
    C_BLUE_BR   = rgb(170, 200, 235)
  else
    C_BG        = rgb(  0,   0,   0)
    C_TEXT      = rgb(255, 255, 255)
    C_DIM       = rgb(124, 134, 148)
    C_LINE      = rgb( 42,  45,  51)
    C_TILE      = rgb( 13,  14,  17)
    C_GREEN_BG  = rgb( 12,  42,  22)
    C_GREEN_BR  = rgb( 29,  77,  42)
    C_YELLOW_BG = rgb( 42,  33,  10)
    C_YELLOW_BR = rgb( 90,  67,  19)
    C_RED_BG    = rgb( 42,  13,  13)
    C_RED_BR    = rgb( 88,  27,  27)
    C_BLUE_BG   = rgb( 13,  31,  42)
    C_BLUE_BR   = rgb( 30,  66,  88)
  end
  if ct then
    C_BG   = rgb(ct.bg[1],   ct.bg[2],   ct.bg[3])
    C_TILE = rgb(ct.tile[1], ct.tile[2], ct.tile[3])
    C_LINE = rgb(ct.line[1], ct.line[2], ct.line[3])
    C_DIM  = rgb(ct.dim[1],  ct.dim[2],  ct.dim[3])
    if ct.text then C_TEXT = rgb(ct.text[1], ct.text[2], ct.text[3]) end
    themeAccent = rgb(ct.accent[1], ct.accent[2], ct.accent[3])
  end
  GOV_COLOR.ACTIVE     = { fg=C_GREEN,  bg=C_GREEN_BG,  br=C_GREEN_BR  }
  GOV_COLOR.IDLE       = { fg=C_YELLOW, bg=C_YELLOW_BG, br=C_YELLOW_BR }
  GOV_COLOR.SPOOLUP    = { fg=C_YELLOW, bg=C_YELLOW_BG, br=C_YELLOW_BR }
  GOV_COLOR.RECOVERY   = { fg=C_YELLOW, bg=C_YELLOW_BG, br=C_YELLOW_BR }
  GOV_COLOR.OFF        = { fg=C_RED,    bg=C_RED_BG,    br=C_RED_BR    }
  GOV_COLOR["THR-OFF"] = { fg=C_RED,    bg=C_RED_BG,    br=C_RED_BR    }
  GOV_COLOR["LOST-HS"] = { fg=C_RED,    bg=C_RED_BG,    br=C_RED_BR    }
  GOV_COLOR.AUTOROT    = { fg=C_BLUE,   bg=C_BLUE_BG,   br=C_BLUE_BR   }
  GOV_COLOR.BAILOUT    = { fg=C_BLUE,   bg=C_BLUE_BG,   br=C_BLUE_BR   }
  GOV_COLOR.BYPASS     = { fg=C_BLUE,   bg=C_BLUE_BG,   br=C_BLUE_BR   }
  GOV_FALLBACK.fg = C_DIM
  GOV_FALLBACK.bg = C_TILE
  GOV_FALLBACK.br = C_LINE
end
-- Shared, SD-card-wide flight history. Keeping one authoritative root file
-- lets other dashboards use the same per-model counters without migration or
-- competing widget-local copies.
local FLIGHTS_PATH              = "/flights-count.csv"
local TOPBAR_MIN_DUR_DEFAULT    = 20
local FLIGHT_CACHE_MAX_ENTRIES  = 200
local flightCache       = nil
local modelFlights      = 0
local minFlightDur      = TOPBAR_MIN_DUR_DEFAULT
local flightModel       = "__default__"
local timerThresholdArmed = nil
local S = {
  rpmMax = 0,
  currMax = 0, tempMax = 0,
  becMin = nil, cellMin = nil,
}
local D = {
  adjustedPercent = 0,
  hasBattData     = false,
  isLiHV          = false,
  capacity        = 0,
  minCellVoltage  = nil,
  voltage         = 0,
  cellsResolved   = 0,
  rxVoltage       = nil,
  rxCellVoltage   = nil,
  rxPercent       = 0,
  minRxVoltage    = nil,
  packVoltageValid= false,
  cellCountValid  = false,
  cellVoltageValid= false,
  batteryPercentValid = false,
  capacityValid   = false,
  currentValid    = false,
  tempValid       = false,
  becValid        = false,
  rpmValid        = false,
  tailRpmValid    = false,
  govValid        = false,
  govCurrentInvalid = false,
}
-- BAT# telemetry can trail a profile command for a few frames. Keep the
-- RF Tool selection visible briefly, then return authority to live telemetry.
local PROFILE_CONFIRMED = {
  value = nil,
  tick = nil,
}
local A = {
  displayPercent     = 0,
  displayPercentInit = false,
  battAlertPrevPct       = nil,
  battAlertPrevSource    = nil,
  battVoicePlayed        = {},
  battZeroReached        = false,
  deadVoiceNextTick      = 0,
  flightDeadVoiceLatched = false,
  flightDeadVoiceAcknowledged = false,
  flightDeadVoiceStartPosition = nil,
  motorSwitchPosition    = nil,
  motorSwitchLastPosition= nil,
  motorPausedPosition    = nil,
  motorGateCandidateFrom = nil,
  motorGateCandidateTo   = nil,
  motorGateCandidateTick = nil,
  govGateLastState       = nil,
  govGateRunningPosition = nil,
  govGateStopTick        = nil,
  govGateStopSince       = nil,
  electricRpmGateRunningPosition = nil,
  electricRpmGateZeroSince       = nil,
  ompGateRunningPosition = nil,
  ompGateZeroSince       = nil,
  flightBatteryAlertsPaused = false,
  batteryAlertPauseTick  = nil,
  motorPauseProof        = nil,
  battAlert5HapticPlayed = false,
  battAlert0HapticPlayed = false,
  battAlertNextTick      = 0,
  battHapticState        = 0,
  battHapticBurstCount   = 0,
  battHapticNextTick     = 0,
  battHapticEndTick      = 0,
  battLinkWasAvailable   = false,
  battConnectionZeroPending = false,
  battConnectionZeroSince = nil,
  escTempAlertPlayed = false,
  becAlertPlayed     = false,
  liHvHighSamples       = 0,
  motorSourcePhysical   = false,
  motorSourceReadable   = false,
  motorConfigError      = "SET MOTOR SWITCH",
  flightSaveError       = false,
  linkAvailable          = false,
  linkSourceKnown        = false,
  linkSourceSeen         = false,
  battReplacementSince  = nil,
  rxLowSinceTick         = nil,
  rxLowHapticNext        = 0,
  rxDeadVoiceLatched     = false,
  rxDeadVoiceAcknowledged= false,
  rxDeadVoiceStartPosition = nil,
  rxDeadVoiceNextTick    = 0,
  escTempHighSince       = nil,
  becLowSince            = nil,
  lastDataTick = -1,
}
local HELI_ELECTRIC, HELI_NITRO, HELI_OMPHOBBY = 1, 2, 3
local OPT = {
  heliType     = HELI_ELECTRIC,
  battBarMode   = 0,
  reservePct    = 0,
  battVoice     = false,
  simTelemetry  = false,
  flightCounter = 2, -- FC.ROTORFLIGHT; FC is declared immediately below.
  rxPackMin     = 6.6,
  rxPackMax     = 8.4,
  rxPackValid   = true,
  bgTransparent = false,
}
-- Rotorflight flight-stat reads deliberately reuse RF Tool's one shared MSP
-- runtime. FC is kept in one table both to make its lifecycle explicit and to
-- stay below EdgeTX Lua's top-level local-variable limit.
local FC = {
  RADIO=1, ROTORFLIGHT=2, SIM_PREVIEW=3,
  disarmStableTicks=150,
  confirmMaxReads=6,
  count=nil, status="RADIO", stale=false,
  wanted=false, pending=false, stableSince=nil,
  state=nil, armState=nil, model=nil, flightSeenArmed=false,
  refreshBase=nil, refreshAttempts=0,
}
G.profileConnectedForDisplay = false
-- Fixed, representative values for EdgeTX Companion visual review. Simulation
-- replaces reads at the telemetry-adapter boundary but never transmits data or
-- exercises flight counting, files, voice, haptics, or safety-alert logic.
local SIM = {
  linkQuality=90,
  txVoltage=8.0,
  [HELI_ELECTRIC]={
    headspeed=2200, tailHeadspeed=9800, becVoltage=5.2,
    cellVoltage=4.02, cellCount=12, current=41.7, capacity=1120,
    batteryPercent=72, escTemperature=78, governorMode=4,
    batteryProfile=1, packVoltage=48.24,
  },
  [HELI_NITRO]={
    headspeed=1850, tailHeadspeed=7600, becVoltage=7.5,
    governorMode=4,
  },
  [HELI_OMPHOBBY]={
    headspeed=3100, packVoltage=11.55, cellCount=3, current=24.4,
    capacity=760, batteryPercent=68, escTemperature=62,
  },
}
local BATTERY_VOICE = {
  levels       = { 50, 40, 30, 20, 10, 0 },
  path         = "/WIDGETS/KSE4/BatterySounds/",
  available    = {},
  initialDelay = 250,
  repeatDelay  = 220,
  replacementConfirm = 100, -- require a one-second rise before rearming for a new pack
}
BATTERY_VOICE.deadPath = BATTERY_VOICE.path .. "dead.wav"
-- Percentage clips are currently about 0.8-1.0s and dead.wav is ~1.18s.
-- These conservative delays keep files from continuously filling the EdgeTX
-- audio queue and leave clear silence between critical repetitions.
local SAFETY = {
  batteryAlertCooldown = 220, -- comfortably longer than the percentage clips
  batteryHapticThreshold = 10,
  batteryConnectionZeroConfirm = 300, -- 3s continuous 0% after link acquisition
  batteryPercentUnit = rawget(_G, "UNIT_PERCENT") or 13,
  rxLowArmTicks = 200,        -- low receiver pack must persist for 2.0s
  rxLowHapticInterval = 20,   -- then buzz every 0.2s while it stays low
  escTempThreshold = 110,
  escTempRearm = 100,
  becAlertMinVoltage = 4.0, -- ignore USB leakage when no receiver pack is powered
  becVoltThreshold = 4.8,
  becVoltRearm = 5.0,
  alertConfirmTicks = 50,     -- ESC/BEC conditions must persist for 0.5s
  displayPercentAlpha = 0.15,
  rxPackMinAllowed = 4.0,
  rxPackMaxAllowed = 9.0,
  maxCellCount = 16,
  maxCellSanityV = 4.5,
  cellRedThreshold = 3.50,
  liHvDetectCellV = 4.22,
  liHvConfirmSamples = 10, -- one continuous second at the 10 Hz service rate
  govMotorCorrelationTicks = 150, -- switch/Gov events may arrive 1.5s apart
  govMotorStopConfirmTicks = 20,  -- require 0.2s of recognized stopped state
  electricMotorStopWindowTicks = 3000, -- allow a 30s Hspd coast-down
  electricMotorZeroConfirmTicks = 30, -- require 0.3s of displayed-zero Hspd
  electricMotorRunningRpm = 1, -- raw Hspd below 1 RPM matches displayed zero
  ompMotorStopWindowTicks = 3000, -- allow a 30s autorotation/spindown
  ompMotorZeroConfirmTicks = 30,   -- require 0.3s of current displayed-zero NR
  ompMotorRunningRpm = 1, -- raw NR below 1 RPM matches the displayed zero state
}
-- Source metadata distinguishes a missing zero from a live value. This matters
-- most for Smart Fuel: Bat%=0 is meaningful only when a flight pack is actually
-- present, while positive current values can stand on their own.
local txIsLiIon = false
local F = {}
local RESOLVED = {}
local function clearFrameCache()
  for k in pairs(F) do F[k] = nil end
end
-- Localize the hottest host globals so per-call lookups skip the global table.
local getValue = getValue
local getTime  = getTime
-- getTime(), cached once per frame. Alert paths ask for "now" repeatedly
-- within a single frame; this collapses those into one host call.
local function frameNow()
  local t = F.now
  if t ~= nil then return t end
  t = (getTime and getTime()) or 0
  F.now = t
  return t
end
local SRC = {}
local function getValSrc(srcId)
  if not srcId or srcId == 0 then return nil end
  local ok, v = pcall(getValue, srcId)
  if not ok or v == nil then return nil end
  if type(v) == "table" then v = v.value end
  return tonumber(v)
end
-- Parse an Rx-pack voltage typed as text ("6.60"), tolerant of whether EdgeTX
-- text entry offers a ".", and backward-compatible with the old integer scale:
--   <=15 -> volts as typed (6.6) ; 16-150 -> old tenths (66->6.6) ; >150 -> hundredths (660->6.6)
local function parseVolt(s, default)
  local str = string.match(tostring(s or ""), "^%s*(.-)%s*$")
  local validText = string.match(str, "^%d+$")
                    or string.match(str, "^%d+[.,]%d+$")
                    or string.match(str, "^[.,]%d+$")
  if not validText then return default end
  str = string.gsub(str, ",", ".")
  local v = tonumber(str)
  if not v or v <= 0 then return default end
  if v > 150 then return v / 100 end
  if v > 15  then return v / 10  end
  return v
end
local getFieldInfoFn = getFieldInfo
local getSourceNameFn = getSourceName
local function isPhysicalMotorSource(src)
  local id = tonumber(src)
  if not id or id == 0 then return false end

  local inspected = false
  if getFieldInfoFn then
    local ok, info = pcall(getFieldInfoFn, id)
    inspected = ok
    if ok and type(info) == "table" then
      local name = string.upper(tostring(info.name or ""))
      local desc = string.upper(tostring(info.desc or ""))
      if string.match(name, "^S[A-Z]$") or string.match(desc, "^SWITCH%s+[A-Z]") then
        return true
      end
    end
  end
  if getSourceNameFn then
    local ok, name = pcall(getSourceNameFn, id)
    inspected = inspected or ok
    if ok and string.match(string.upper(tostring(name or "")), "^S[A-Z]$") then
      return true
    end
  end

  -- Older supported firmwares may not expose source inspection. A configured,
  -- readable SOURCE is still safer than silently falling back to a channel.
  return not inspected
end
local function applyOptions(opts)
  local rawTheme = tonumber(opts and opts.Theme) or 0
  OPT.bgTransparent   = (rawTheme == 3 or rawTheme == 19)
  applyTheme(THEME_NAMES[rawTheme] or "dark")
  local rawBatt = tonumber(opts and opts.TxBatt) or 0
  txIsLiIon = (rawBatt == 2)
  local rawDur = tonumber(opts and (opts.MinFlight
                                    or opts["KSE Counter Min (sec)"]
                                    or opts["Min. Flight Time (sec)"]
                                    or opts.TopMinDur))
                 or TOPBAR_MIN_DUR_DEFAULT
  if rawDur < 0 then rawDur = math.abs(rawDur) end
  if rawDur < 1 then rawDur = 1 end
  minFlightDur = rawDur
  OPT.flightCounter = FC.ROTORFLIGHT
  OPT.simTelemetry = false
  local sgInfo = type(getFieldInfo) == "function" and getFieldInfo("SG") or nil
  local defaultMotorSwitch = type(sgInfo) == "table" and sgInfo.id or 0
  SRC.motorSwitch = defaultMotorSwitch
  if opts then
    -- The Motor Switch is the only mapped source. Rotorflight Gov/Hspd or OMP
    -- NR telemetry validates what a movement means; other sensors auto-detect.
    SRC.motorSwitch = opts.MotorSw or opts["Motor Switch"]
                      or defaultMotorSwitch
    -- Heli Type CHOICE (1-based): Electric=1, Nitro=2, OMPHOBBY=3.
    -- OMPHOBBY shares the percentage bar but has its own telemetry contract.
    local bb = tonumber(opts.HeliType or opts["Heli Type"]) or 1
    if bb < 1 or bb > 3 then bb = 1 end
    OPT.heliType = bb
    OPT.battBarMode = (bb == HELI_NITRO) and 1 or 0
    OPT.reservePct  = tonumber(opts.BattRsv or opts["Batt Reserve %"]) or 0
    if OPT.reservePct < 0 then OPT.reservePct = 0 end
    if OPT.reservePct > 50 then OPT.reservePct = 50 end
    OPT.battVoice   = (opts.BattVoice == 1 or opts.BattVoice == true)
    -- Slot 10 used to be the SimTelem boolean. CountSrc keeps that slot and
    -- folds preview into the same choice so the first nine persisted options
    -- remain in place and the EdgeTX ten-option ceiling is respected.
    local countMode = tonumber(opts.CountSrc or opts["Flight Counter"])
    if countMode == nil
       and (opts.SimTelem == 1 or opts.SimTelem == true
            or opts["Simulate Telemetry"] == 1
            or opts["Simulate Telemetry"] == true) then
      countMode = FC.SIM_PREVIEW
    end
    if countMode ~= FC.RADIO
       and countMode ~= FC.ROTORFLIGHT
       and countMode ~= FC.SIM_PREVIEW then
      countMode = FC.ROTORFLIGHT
    end
    OPT.flightCounter = countMode
    OPT.simTelemetry = countMode == FC.SIM_PREVIEW
    local parsedMin = parseVolt(opts.RxPackMin, nil)
    local parsedMax = parseVolt(opts.RxPackMax, nil)
    OPT.rxPackMin = parsedMin or 6.6
    OPT.rxPackMax = parsedMax or 8.4
    OPT.rxPackValid = parsedMin ~= nil and parsedMax ~= nil
                       and parsedMin >= SAFETY.rxPackMinAllowed
                       and parsedMax <= SAFETY.rxPackMaxAllowed
                       and (parsedMax - parsedMin) >= 0.1
  end
  A.motorSourcePhysical = isPhysicalMotorSource(SRC.motorSwitch)
  A.motorSourceReadable = A.motorSourcePhysical
                          and getValSrc(SRC.motorSwitch) ~= nil
  if OPT.simTelemetry then
    A.motorConfigError = nil
  elseif not A.motorSourcePhysical then
    A.motorConfigError = "SELECT A PHYSICAL MOTOR SWITCH"
  elseif not A.motorSourceReadable then
    A.motorConfigError = "MOTOR SWITCH UNAVAILABLE"
  else
    A.motorConfigError = nil
  end
  C_ACCENT = themeAccent or DEFAULT_ACCENT
end
local modelImageName = nil
local modelImagePath = nil
local READ_ALL_MAX_BYTES = 32 * 1024
local function readAll(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local parts = {}
  local total = 0
  local ok = pcall(function()
    while true do
      local chunk = io.read(f, 1024)
      if chunk == nil or chunk == "" then break end
      total = total + #chunk
      if total > READ_ALL_MAX_BYTES then break end
      parts[#parts+1] = chunk
      if #chunk < 1024 then break end
    end
  end)
  pcall(io.close, f)
  if not ok then return nil end
  return table.concat(parts)
end
local function writeAll(path, content)
  content = content or ""
  local function writeFile(target)
    local f = io.open(target, "w")
    if not f then return false end
    -- EdgeTX io.write() reports media/write failures by returning nil rather
    -- than necessarily throwing.  pcall success alone therefore does not
    -- prove that the bytes reached the file.
    local called, result = pcall(io.write, f, content)
    local closed = pcall(io.close, f)
    return called and result ~= nil and result ~= false and closed
  end
  local dirApi = dir
  local renameFn = type(dirApi) == "table" and dirApi.rename
                   or (type(os) == "table" and os.rename)
  local deleteFn = type(dirApi) == "table" and dirApi.del
                   or (type(os) == "table" and os.remove)
  local function renameFile(fromPath, toPath)
    if not renameFn then return false end
    local ok, result = pcall(renameFn, fromPath, toPath)
    return ok and (result == nil or result == true or result == 0)
  end
  local function deleteFile(target)
    if not deleteFn then return false end
    local ok, result = pcall(deleteFn, target)
    return ok and (result == nil or result == true or result == 0)
  end
  if renameFn then
    local tmp, backup = path .. ".tmp", path .. ".bak"
    deleteFile(tmp)
    if not writeFile(tmp) then
      deleteFile(tmp)
      return false
    end
    local existing = io.open(path, "r")
    if existing then pcall(io.close, existing) end
    local movedExisting = false
    if existing then
      deleteFile(backup)
      movedExisting = renameFile(path, backup)
      if not movedExisting then
        deleteFile(tmp)
        return false
      end
    end
    if renameFile(tmp, path) then
      if movedExisting then deleteFile(backup) end
      return true
    end
    if movedExisting then renameFile(backup, path) end
    deleteFile(tmp)
    return false
  end
  local f = io.open(path, "w")
  if not f then return false end
  local called, result = pcall(io.write, f, content)
  local closed = pcall(io.close, f)
  return called and result ~= nil and result ~= false and closed
end
local function trim(s) return string.match(s or "", "^%s*(.-)%s*$") end
local function sanitizeFsName(name)
  if not name then return nil end
  local s = (string.gsub(name, "[\\/:*?\"<>|]", "_"))
  return trim(s)
end
local function get(name)
  local source = name
  local sourceKey
  local sourceKnown = false
  if type(name) == "string" and getFieldInfoFn then
    sourceKey = "$" .. name
    local cached = RESOLVED[sourceKey]
    if cached ~= nil then
      source = cached
      sourceKnown = true
    else
      local infoOk, info = pcall(getFieldInfoFn, name)
      if infoOk and type(info) == "table" and info.id ~= nil then
        source = info.id
        RESOLVED[sourceKey] = source
        sourceKnown = true
      elseif infoOk then
        -- getValue(name) returns zero for a missing source. A successful
        -- metadata lookup returning nil lets us distinguish that from a live
        -- telemetry source whose legitimate value is zero.
        return nil, false, false, false
      end
    end
  end

  local sourceValueFn = rawget(_G, "getSourceValue") or _G.getSourceValue
  if type(sourceValueFn) == "function" then
    local ok, v, isCurrent, isFresh = pcall(sourceValueFn, source)
    if not ok or v == nil or isCurrent == false then
      -- Source ids can change after telemetry discovery. Re-resolve a stale id
      -- on the next sample instead of pinning the model to it indefinitely.
      if sourceKey then RESOLVED[sourceKey] = nil end
      return nil, false, isFresh == true, sourceKnown
    end
    if type(v) == "table" then v = v.value end
    if v == nil then return nil, false, isFresh == true, sourceKnown end
    return v, true, isFresh ~= false, true
  end

  local ok, v = pcall(getValue, source)
  if not ok or v == nil then return nil, false, false, sourceKnown end
  if type(v) == "table" then v = v.value end
  return v, true, true, true
end
local function getModelName()
  local v = F.modelName
  if v ~= nil then return v end
  local ok, info = pcall(model.getInfo)
  local n = (ok and info and info.name) or nil
  if not n or n == "" then n = "MODEL" end
  v = (string.gsub(n, ",", " "))
  F.modelName = v
  return v
end
-- Telemetry names are case-sensitive. Resolve each discovered source to its
-- numeric id, prefer getSourceValue() current-state reporting, and retain the
-- legacy getValue() path only as a compatibility fallback. Electric/Nitro use
-- the Rotorflight contract; OMPHOBBY uses the receiver's smaller contract.
local ROTORFLIGHT_SENSOR = {
  headspeed        = "Hspd",
  tailHeadspeed    = "Tspd",
  becVoltage       = "Vbec",
  cellVoltage      = "Vcel",
  cellCount        = "Cel#",
  -- The AMPS tile (and its session maximum) always reads Rotorflight's
  -- dedicated current sensor rather than the ESC telemetry source.
  current          = "Curr",
  capacity         = "Capa",
  -- Rotorflight publishes getBatteryChargeLevel() here. With Smart Fuel
  -- enabled, this is the FC's sag-compensated/rate-limited estimate.
  batteryPercent   = "Bat%",
  escTemperature   = "Tesc",
  governorMode     = "Gov",
  batteryProfile   = "BAT#",
  pidProfile       = "PID#",
  rateProfile      = "RTE#",
  -- Pack voltage remains a separate input used to validate electric packs.
  packVoltage      = "Vbat",
}
local OMPHOBBY_SENSOR = {
  headspeed        = "NR",
  packVoltage      = "RxBt",
  current          = "Curr",
  capacity         = "Capa",
  batteryPercent   = "Bat%",
  escTemperature   = "Tmp",
}
local function activeSensorName(key)
  local sensors = OPT.heliType == HELI_OMPHOBBY
                  and OMPHOBBY_SENSOR or ROTORFLIGHT_SENSOR
  return sensors[key]
end
local function getSensorNumber(key)
  if OPT.simTelemetry then
    local values = SIM[OPT.heliType] or SIM[HELI_ELECTRIC]
    local v = values[key]
    local available = v ~= nil
    return v, available, available, available
  end
  local name = activeSensorName(key)
  if not name then return nil end
  local v, current, fresh, exists = get(name)
  return tonumber(v), current, fresh, exists
end
-- Link quality is the one remaining name-variant fallback chain. Remember the
-- variant that resolves so later frames do not re-probe every candidate.
local NAMES = {
  lq = { "RQly", "RQLY", "LQ" },
}
local function resolveNamed(key)
  local names = NAMES[key]
  local cached = RESOLVED[key]
  if cached then
    local raw, _, _, exists = get(cached)
    if exists then A.linkSourceKnown = true end
    local v = tonumber(raw)
    if v ~= nil then return v end
    RESOLVED[key] = nil
  end
  for i = 1, #names do
    local raw, _, _, exists = get(names[i])
    if exists then A.linkSourceKnown = true end
    local v = tonumber(raw)
    if v ~= nil then
      RESOLVED[key] = names[i]
      return v
    end
  end
  return nil
end
local function getCellCount()
  local v = F.cellCount
  if v ~= nil then return v end
  if OPT.simTelemetry then
    v = getSensorNumber("cellCount") or 0
  elseif OPT.heliType == HELI_OMPHOBBY then
    -- OMP receivers do not stream cell count. Model names containing M2 are
    -- 3S; names containing M1 are 2S. Match case-insensitively anywhere.
    local modelName = string.upper(getModelName())
    if string.find(modelName, "M2", 1, true) then
      v = 3
    elseif string.find(modelName, "M1", 1, true) then
      v = 2
    else
      v = 0
    end
  else
    v = getSensorNumber("cellCount") or 0
  end
  v = math.floor(v + 0.5)
  D.cellCountValid = v >= 1 and v <= SAFETY.maxCellCount
  if not D.cellCountValid then v = 0 end
  F.cellCount = v
  return v
end
local function getPackVolt()
  local v = F.packVolt
  if v ~= nil then return v end
  v = getSensorNumber("packVoltage")
  D.packVoltageValid = v ~= nil and v > 0
                       and v <= SAFETY.maxCellCount * SAFETY.maxCellSanityV
  if not D.packVoltageValid then v = 0 end
  F.packVolt = v
  return v
end
local function getCellVoltage()
  local v = F.cellVoltage
  if v ~= nil then return v end
  if OPT.heliType == HELI_OMPHOBBY then
    local cells = getCellCount()
    local packVoltage = getPackVolt()
    v = cells > 0 and packVoltage > 0 and packVoltage / cells or nil
  else
    v = getSensorNumber("cellVoltage")
  end
  D.cellVoltageValid = v ~= nil and v > 0
                       and v <= SAFETY.maxCellSanityV
  if not D.cellVoltageValid then v = 0 end
  F.cellVoltage = v
  return v
end
local function getBatPct()
  local v = F.batPct
  if v ~= nil then return v end
  v = getSensorNumber("batteryPercent")
  D.batteryPercentValid = v ~= nil and v >= 0 and v <= 100
  if not D.batteryPercentValid then v = false end
  F.batPct = v
  return v
end
local function getCapa()
  local v = F.capa
  if v ~= nil then return v end
  v = getSensorNumber("capacity")
  D.capacityValid = v ~= nil and v >= 0 and v <= 100000
  if not D.capacityValid then v = 0 end
  F.capa = v
  return v
end
local function getCurr()
  local v = F.curr
  if v ~= nil then return v end
  v = getSensorNumber("current")
  local sane = v ~= nil and v >= -500 and v <= 1000
  if not sane then v = 0 end
  D.currentValid = sane
  F.curr = v
  return v
end
local function getTemp()
  local v = F.temp
  if v ~= nil then return v end
  v = getSensorNumber("escTemperature")
  local sane = v ~= nil and v >= -40 and v <= 250
  if not sane then v = 0 end
  D.tempValid = sane
  F.temp = v
  return v
end
local function getBec()
  local v = F.bec
  if v ~= nil then return v end
  v = getSensorNumber("becVoltage")
  local sane = v ~= nil and v > 0 and v <= 30
  D.becValid = sane
  if not D.becValid then v = 0 end
  F.bec = v
  return v
end
local function getRxBatt()
  local v = F.rxBatt
  if v ~= nil then return v end
  -- Nitro Rx pack voltage uses the same Vbec resolver as the BEC tile.
  v = getBec()
  F.rxBatt = v
  return v
end
local function getBattProfile()
  local v = F.battProfile
  if v ~= nil then return v end
  v = getSensorNumber("batteryProfile")
  local whole = v ~= nil and math.floor(v) or nil
  if whole == nil or v ~= whole
     or whole < 1 or whole > BATTERY_PROFILE_COUNT then
    v = nil
  else
    v = whole
  end

  if PROFILE_CONFIRMED.value then
    local age = frameNow() - (PROFILE_CONFIRMED.tick or 0)
    if v == PROFILE_CONFIRMED.value or age > 300 or age < 0 then
      PROFILE_CONFIRMED.value, PROFILE_CONFIRMED.tick = nil, nil
    else
      v = PROFILE_CONFIRMED.value
    end
  end
  F.battProfile = v
  return v
end
local function getHeadspeed()
  local v = F.rpm
  if v ~= nil then return v end
  v = getSensorNumber("headspeed")
  local sane = v ~= nil and v >= 0 and v <= 100000
  if not sane then v = 0 end
  D.rpmValid = sane
  F.rpm = v
  return v
end
local function getTailRpm()
  local v = F.trpm
  if v ~= nil then return v end
  v = getSensorNumber("tailHeadspeed")
  local sane = v ~= nil and v >= 0 and v <= 100000
  if not sane then v = 0 end
  D.tailRpmValid = sane
  F.trpm = v
  return v
end
local function getGovernorMode()
  local cached = F.govNumber
  if cached ~= nil then return cached ~= false and cached or nil end
  if OPT.heliType == HELI_OMPHOBBY then
    D.govValid = false
    D.govCurrentInvalid = false
    F.govNumber = false
    return nil
  end
  local raw, current = getSensorNumber("governorMode")
  local whole = raw ~= nil and math.floor(raw) or nil
  local valid = whole ~= nil and raw == whole and GOV_STATES[whole] ~= nil
  D.govValid = valid
  -- Missing/stale Gov may use the independent Hspd proof. A current but
  -- malformed or unknown enum is different: it must block that fallback.
  D.govCurrentInvalid = current == true and raw ~= nil and not valid
  F.govNumber = valid and whole or false
  return valid and whole or nil
end
local function getGovState()
  local v = F.gov
  if v ~= nil then return v end
  if OPT.heliType == HELI_OMPHOBBY then
    v = "--"
  else
    local g = getGovernorMode()
    v = g == nil and "--" or GOV_STATES[g]
  end
  F.gov = v
  return v
end
local function getTxVolt()
  local v = F.txVolt
  if v ~= nil then return v end
  if OPT.simTelemetry then
    F.txVolt = SIM.txVoltage
    return SIM.txVoltage
  end
  -- Capture only the source value. get() also returns current/fresh/existence
  -- metadata, which must not spill into tonumber() as its optional base.
  local raw = get("tx-voltage")
  v = tonumber(raw) or 0
  if v > 100 then v = v / 1000 end
  if v < 0 or v > 20 then v = 0 end
  F.txVolt = v
  return v
end
-- TX battery display endpoints for a 2S pack. Keep these separate from the
-- model battery settings: the top-bar gauge represents the radio battery.
local TX_LIPO_EMPTY_V = 7.0   -- 3.50 V/cell
local TX_LIPO_FULL_V  = 8.4   -- 4.20 V/cell
local TX_LIION_EMPTY_V = 6.2  -- 3.10 V/cell
local TX_LIION_FULL_V  = 8.4  -- 4.20 V/cell

local function txPctFromVolts(volts, isLiIon)
  if not volts or volts <= 0 then return nil end
  local emptyV = isLiIon and TX_LIION_EMPTY_V or TX_LIPO_EMPTY_V
  local fullV = isLiIon and TX_LIION_FULL_V or TX_LIPO_FULL_V
  local pct = ((volts - emptyV) / (fullV - emptyV)) * 100
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end
  return pct
end
local function signalPercent(raw)
  local v = tonumber(raw)
  if v == nil then return nil end
  local pct
  if v < 0 then
    pct = ((v + 120) / 80) * 100
  elseif v <= 100 then
    pct = v
  elseif v <= 255 then
    pct = (v / 255) * 100
  else
    pct = 100
  end
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end
  return pct
end
local function getRqly()
  local v = F.rqly
  if v ~= nil then return v end
  if OPT.simTelemetry then
    A.linkSourceKnown = true
    A.linkSourceSeen = true
    F.rqly = SIM.linkQuality
    return SIM.linkQuality
  end
  A.linkSourceKnown = false
  v = resolveNamed("lq")
  if v == nil then
    local rssi
    if getRSSI then
      local ok, r = pcall(getRSSI)
      if ok then rssi = tonumber(r) end
    end
    if rssi ~= nil and rssi ~= 0 then A.linkSourceKnown = true end
    if rssi == nil or rssi == 0 then
      local raw, _, _, exists = get("RSSI")
      if exists then A.linkSourceKnown = true end
      if raw ~= nil then rssi = tonumber(raw) end
    end
    v = signalPercent(rssi)
  end
  v = tonumber(v) or 0
  if v < 0 or v > 100 then v = signalPercent(v) or 0 end
  if v > 0 then A.linkSourceSeen = true end
  F.rqly = v
  return v
end
local function percentFromCellVoltage(cellVolts, isLiHV)
  if not cellVolts or cellVolts <= 0 then return 0 end
  local minV = 3.3
  local maxV = isLiHV and 4.35 or 4.2
  local pct = (cellVolts - minV) / (maxV - minV) * 100
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end
  return pct
end
-- Rotorflight publishes its FC-side charge estimate as Bat%. In Electric mode
-- that value is authoritative even when Vcel is not configured. A positive
-- Bat% is sufficient evidence by itself; a zero also needs live Vcel or Vbat
-- so an FC powered over USB without a flight pack is shown as NO DATA instead
-- of an empty battery. OMPHOBBY keeps its stricter RxBt + M1/M2 contract.
local function selectFlightBatteryPercent(heliType, sensorPercent, sensorValid,
                                          voltagePercent, hasCellVoltage,
                                          hasPackVoltage)
  local raw = tonumber(sensorPercent)
  if heliType == HELI_ELECTRIC then
    local fcPercentUsable = sensorValid and raw ~= nil
                            and raw >= 0 and raw <= 100
                            and (raw > 0 or hasCellVoltage or hasPackVoltage)
    if fcPercentUsable then return raw, true, "fc" end
  elseif heliType == HELI_OMPHOBBY then
    local ompPercentUsable = hasCellVoltage and sensorValid and raw ~= nil
                             and raw >= 0 and raw <= 100
    if ompPercentUsable then return raw, true, "telemetry" end
  else
    return 0, false, nil
  end
  if voltagePercent ~= nil then return voltagePercent, true, "voltage" end
  return 0, false, nil
end
local function calculateAdjustedPercent(actual, reserve)
  if not actual or actual <= 0 then return 0 end
  reserve = reserve or 0
  if reserve >= 100 then return 0 end
  local usable = 100 - reserve
  local adj = ((actual - reserve) / usable) * 100
  if adj < 0 then adj = 0 end
  if adj > 100 then adj = 100 end
  return adj
end
function BATTERY_VOICE.play(path)
  if OPT.simTelemetry then return false end
  if not playFile or not path then return false end
  local available = BATTERY_VOICE.available[path]
  if available == nil then
    local f = io.open(path, "r")
    available = f ~= nil
    BATTERY_VOICE.available[path] = available
    if f then pcall(io.close, f) end
  end
  if not available then return false end
  return pcall(playFile, path)
end
local function playBatteryRemainingAlert(level)
  if OPT.simTelemetry then return false end
  local n = tonumber(level)
  if n == nil then return false end
  local customPath = BATTERY_VOICE.path .. tostring(math.floor(n)) .. "%.wav"
  if BATTERY_VOICE.play(customPath) then return true end
  if playNumber then
    return pcall(playNumber, n, SAFETY.batteryPercentUnit, 0)
  end
  return false
end
local function playBatteryHaptic()
  if OPT.simTelemetry then return end
  if not playHaptic then return end
  local modeNow = rawget(_G, "PLAY_NOW") or 0
  pcall(playHaptic, 15, 0, modeNow)
end
local function resetBatteryAlertState(scope)
  scope = scope or "all"
  if scope ~= "rx" then
    A.battAlertPrevPct       = nil
    A.battAlertPrevSource    = nil
    A.battVoicePlayed        = {}
    A.battZeroReached        = false
    A.deadVoiceNextTick      = 0
    A.flightDeadVoiceLatched = false
    A.flightDeadVoiceAcknowledged = false
    A.flightDeadVoiceStartPosition = nil
    A.battAlert5HapticPlayed = false
    A.battAlert0HapticPlayed = false
    A.battAlertNextTick      = 0
    A.battHapticState        = 0
    A.battHapticBurstCount   = 0
    A.battHapticNextTick     = 0
    A.battHapticEndTick      = 0
    A.battConnectionZeroPending = false
    A.battConnectionZeroSince = nil
    A.battReplacementSince  = nil
    A.liHvHighSamples        = 0
    D.isLiHV                 = false
  end
  if scope ~= "flight" then
    A.rxLowSinceTick         = nil
    A.rxLowHapticNext        = 0
    A.rxDeadVoiceLatched     = false
    A.rxDeadVoiceAcknowledged= false
    A.rxDeadVoiceStartPosition = nil
    A.rxDeadVoiceNextTick    = 0
  end
  if scope == "all" then
    A.escTempAlertPlayed = false
    A.becAlertPlayed = false
    A.escTempHighSince = nil
    A.becLowSince = nil
  end
end
function BATTERY_VOICE.prime(percent, leaveZeroPending)
  local played = A.battVoicePlayed
  for _, level in ipairs(BATTERY_VOICE.levels) do
    -- Do not announce thresholds already passed when the widget starts or is
    -- reloaded in the middle of a flight. Zero is the safety exception: a
    -- widget that starts on a confirmed empty pack must still alert.
    if percent <= level and not (leaveZeroPending and level == 0) then
      played[level] = true
    end
  end
end
local function updateBatteryAlertState(percent, hasData, voiceEnabled, percentSource)
  if not hasData or not A.linkAvailable then
    -- A telemetry gap means a startup zero was not continuously observed.
    if A.battConnectionZeroPending then
      A.battConnectionZeroSince = nil
    end
    return
  end
  local p = tonumber(percent)
  if p == nil then return end
  if p < 0 then p = 0 end
  if p > 100 then p = 100 end
  local now = frameNow()
  local connectionZeroWaiting = false
  local connectionZeroConfirmed = false
  if A.battConnectionZeroPending then
    if p <= 0 then
      if A.battConnectionZeroSince == nil then
        A.battConnectionZeroSince = now
      end
      if now - A.battConnectionZeroSince
         >= SAFETY.batteryConnectionZeroConfirm then
        A.battConnectionZeroPending = false
        A.battConnectionZeroSince = nil
        connectionZeroConfirmed = true
      else
        connectionZeroWaiting = true
      end
    else
      -- Any positive reading proves the connection-time zero was transient.
      A.battConnectionZeroPending = false
      A.battConnectionZeroSince = nil
    end
  end
  local prev = tonumber(A.battAlertPrevPct)
  if prev == nil then
    local startsAtZero = p <= 0
    A.battAlertPrevPct = startsAtZero and 0.01 or p
    A.battAlertPrevSource = percentSource
    BATTERY_VOICE.prime(p, startsAtZero)
    return
  end
  local previousSource = A.battAlertPrevSource
  local sourceChanged = previousSource ~= nil and percentSource ~= nil
                        and previousSource ~= percentSource
  local replacementJump = false
  if not sourceChanged then
    if percentSource == "fc" and previousSource == "fc" then
      -- Rotorflight Smart Fuel is monotonic within a battery session. A
      -- sustained upward step therefore rearms alerts for the new FC session
      -- without any voltage/capacity-based pack classifier.
      replacementJump = (p - prev) >= 1
    else
      -- Voltage-derived/receiver percentages can rebound under reduced load,
      -- so retain the deliberately conservative legacy qualification.
      replacementJump = (p >= 95 and prev < 80)
                        or ((p - prev) >= 25 and p >= 60)
    end
  end
  if replacementJump then
    if A.battReplacementSince == nil then A.battReplacementSince = now end
    if (now - A.battReplacementSince) >= BATTERY_VOICE.replacementConfirm then
      resetBatteryAlertState("flight")
      A.battAlertPrevPct = p
      A.battAlertPrevSource = percentSource
      BATTERY_VOICE.prime(p)
    end
    return
  end
  A.battReplacementSince = nil
  local playedLevels = A.battVoicePlayed
  if voiceEnabled then
    if now >= (tonumber(A.battAlertNextTick) or 0) then
      local selectedLevel
      for i = #BATTERY_VOICE.levels, 1, -1 do
        local level = BATTERY_VOICE.levels[i]
        if not playedLevels[level] and p <= level then
          selectedLevel = level
          break
        end
      end
      if selectedLevel ~= nil then
        -- If telemetry skipped several thresholds, announce the current
        -- lowest one and retire the higher backlog. At 0%, this prevents old
        -- percentage clips from delaying the safety-critical dead warning.
        for _, level in ipairs(BATTERY_VOICE.levels) do
          if p <= level then playedLevels[level] = true end
        end
        playBatteryRemainingAlert(selectedLevel)
        A.battAlertNextTick = now + SAFETY.batteryAlertCooldown
        if selectedLevel == 0 then
          A.battZeroReached = true
          A.deadVoiceNextTick = now + BATTERY_VOICE.initialDelay
        end
      end
    end
  else
    -- Keep threshold state current while muted so enabling Battery Voice later
    -- does not announce a backlog of percentages already passed.
    for _, level in ipairs(BATTERY_VOICE.levels) do
      if p <= level then playedLevels[level] = true end
    end
  end
  if connectionZeroConfirmed and not A.battAlert0HapticPlayed then
    A.battHapticState      = 2
    A.battHapticNextTick   = now
    A.battHapticEndTick    = now + 500
    A.battAlert0HapticPlayed = true
  elseif not connectionZeroWaiting then
    if (not A.battAlert5HapticPlayed)
       and prev > SAFETY.batteryHapticThreshold
       and p <= SAFETY.batteryHapticThreshold then
      A.battHapticState      = 1
      A.battHapticBurstCount = 0
      A.battHapticNextTick   = now
      A.battAlert5HapticPlayed = true
    end
    if (not A.battAlert0HapticPlayed) and prev > 0 and p <= 0 then
      A.battHapticState      = 2
      A.battHapticNextTick   = now
      A.battHapticEndTick    = now + 500
      A.battAlert0HapticPlayed = true
    end
  end
  A.battAlertPrevPct = p
  A.battAlertPrevSource = percentSource
end
function BATTERY_VOICE.updateDead(voiceEnabled)
  if not voiceEnabled or not A.battZeroReached then return end
  -- Once the pilot has heard dead.wav, a later movement of the configured
  -- physical Motor Switch acknowledges only this repeating voice. Movement
  -- before the first successful playback cannot pre-acknowledge the warning;
  -- percentage/haptic pausing remains telemetry-validated separately.
  if A.flightDeadVoiceLatched then
    local startPosition = A.flightDeadVoiceStartPosition
    local currentPosition = A.motorSwitchPosition
    if startPosition == nil and currentPosition ~= nil then
      A.flightDeadVoiceStartPosition = currentPosition
      startPosition = currentPosition
    end
    if startPosition ~= nil and currentPosition ~= nil
       and currentPosition ~= startPosition then
      A.flightDeadVoiceAcknowledged = true
      A.deadVoiceNextTick = 0
    end
  end
  if A.flightDeadVoiceAcknowledged then return end
  if not A.linkAvailable then return end
  local now = frameNow()
  if now < (tonumber(A.deadVoiceNextTick) or 0) then return end
  if BATTERY_VOICE.play(BATTERY_VOICE.deadPath)
     and not A.flightDeadVoiceLatched then
    A.flightDeadVoiceLatched = true
    A.flightDeadVoiceStartPosition = A.motorSwitchPosition
  end
  A.deadVoiceNextTick = now + BATTERY_VOICE.repeatDelay
end
local function updateBatteryHapticTick()
  if (A.battHapticState or 0) == 0 then return end
  if not A.linkAvailable then return end
  local now = frameNow()
  if now < (A.battHapticNextTick or 0) then return end
  if A.battHapticState == 1 then
    playBatteryHaptic()
    A.battHapticBurstCount = (A.battHapticBurstCount or 0) + 1
    if A.battHapticBurstCount >= 2 then
      A.battHapticState = 0
    else
      A.battHapticNextTick = now + 100
    end
  elseif A.battHapticState == 2 then
    if now >= (A.battHapticEndTick or 0) then
      A.battHapticState = 0
    else
      playBatteryHaptic()
      A.battHapticNextTick = now + 18
    end
  end
end
local function updateEscBecAlerts(escT, escValid, becV, becValid)
  if not A.linkAvailable then
    A.escTempHighSince = nil
    A.becLowSince = nil
    return
  end
  local now = frameNow()
  if escValid then
    if escT > SAFETY.escTempThreshold then
      if not A.escTempAlertPlayed then
        if A.escTempHighSince == nil then A.escTempHighSince = now end
        if (now - A.escTempHighSince) >= SAFETY.alertConfirmTicks then
          playBatteryHaptic()
          A.escTempAlertPlayed = true
          A.escTempHighSince = nil
        end
      end
    elseif A.escTempAlertPlayed and escT < SAFETY.escTempRearm then
      A.escTempAlertPlayed = false
      A.escTempHighSince = nil
    elseif not A.escTempAlertPlayed then
      A.escTempHighSince = nil
    end
  else
    A.escTempHighSince = nil
  end
  if becValid and becV >= SAFETY.becAlertMinVoltage then
    if becV < SAFETY.becVoltThreshold then
      if not A.becAlertPlayed then
        if A.becLowSince == nil then A.becLowSince = now end
        if (now - A.becLowSince) >= SAFETY.alertConfirmTicks then
          playBatteryHaptic()
          A.becAlertPlayed = true
          A.becLowSince = nil
        end
      end
    elseif A.becAlertPlayed and becV > SAFETY.becVoltRearm then
      A.becAlertPlayed = false
      A.becLowSince = nil
    elseif not A.becAlertPlayed then
      A.becLowSince = nil
    end
  else
    A.becLowSince = nil
  end
end
-- Nitro Rx pack low-voltage alert: if rx voltage sits at or below RxPackMin for
-- SAFETY.rxLowArmTicks (2s) continuously, buzz aggressively and latch the repeating
-- dead-battery voice warning. Caller only invokes this in Nitro mode.
function BATTERY_VOICE.updateRxDead(voiceEnabled, rx)
  if not rx or rx < SAFETY.becAlertMinVoltage then return end
  if not A.rxDeadVoiceLatched or A.rxDeadVoiceAcknowledged then return end
  if not A.linkAvailable then return end
  local startPosition = A.rxDeadVoiceStartPosition
  local currentPosition = A.motorSwitchPosition
  if startPosition == nil and currentPosition ~= nil then
    A.rxDeadVoiceStartPosition = currentPosition
    startPosition = currentPosition
  end
  if startPosition ~= nil and currentPosition ~= nil
     and currentPosition ~= startPosition then
    A.rxDeadVoiceAcknowledged = true
    A.rxDeadVoiceNextTick = 0
    return
  end
  if not voiceEnabled then return end
  local now = frameNow()
  if now < (tonumber(A.rxDeadVoiceNextTick) or 0) then return end
  BATTERY_VOICE.play(BATTERY_VOICE.deadPath)
  A.rxDeadVoiceNextTick = now + BATTERY_VOICE.repeatDelay
end
local function updateRxPackAlert(rx)
  if not OPT.rxPackValid then
    A.rxLowSinceTick = nil
    A.rxLowHapticNext = 0
    A.rxDeadVoiceLatched = false
    A.rxDeadVoiceAcknowledged = false
    A.rxDeadVoiceStartPosition = nil
    A.rxDeadVoiceNextTick = 0
    return
  end
  if not A.linkAvailable then
    if not A.rxDeadVoiceLatched then A.rxLowSinceTick = nil end
    A.rxLowHapticNext = 0
    return
  end
  local rxMin = OPT.rxPackMin
  local low = rx and rx >= SAFETY.becAlertMinVoltage
              and rxMin and rxMin > 0 and rx <= rxMin
  if not low then
    A.rxLowSinceTick = nil
    A.rxLowHapticNext = 0
    -- Once the Motor Switch has acknowledged a latched warning, recovery above
    -- the minimum rearms it for a future sustained low-voltage event. An
    -- unacknowledged warning remains latched until the switch is moved.
    if not A.rxDeadVoiceLatched or A.rxDeadVoiceAcknowledged then
      A.rxDeadVoiceLatched = false
      A.rxDeadVoiceAcknowledged = false
      A.rxDeadVoiceStartPosition = nil
      A.rxDeadVoiceNextTick = 0
    end
    return
  end
  local now = frameNow()
  -- Only movement after the warning has actually latched can acknowledge it.
  -- Movement during the two-second qualification period is normal control
  -- activity and must not silence an alert that has not started yet.
  if A.rxDeadVoiceLatched and A.rxDeadVoiceStartPosition ~= nil
     and A.motorSwitchPosition ~= nil
     and A.motorSwitchPosition ~= A.rxDeadVoiceStartPosition then
    A.rxDeadVoiceAcknowledged = true
    A.rxDeadVoiceNextTick = 0
  end
  if A.rxLowSinceTick == nil then
    A.rxLowSinceTick  = now
    A.rxLowHapticNext = now + SAFETY.rxLowArmTicks -- first buzz only after 2s sustained
    A.rxDeadVoiceStartPosition = nil
    A.rxDeadVoiceAcknowledged = false
  else
    if (now - A.rxLowSinceTick) >= SAFETY.rxLowArmTicks
       and not A.rxDeadVoiceLatched then
      A.rxDeadVoiceLatched = true
      A.rxDeadVoiceStartPosition = A.motorSwitchPosition
      A.rxDeadVoiceAcknowledged = false
      A.rxDeadVoiceNextTick = now
    end
    if not A.rxDeadVoiceAcknowledged
       and now >= (A.rxLowHapticNext or 0) then
      playBatteryHaptic()
      A.rxLowHapticNext = now + SAFETY.rxLowHapticInterval
    end
  end
end
local updateMotorAlertGate
local function tick(nowT)
  nowT = nowT or frameNow()
  A.lastDataTick = nowT
  local rq = getRqly()
  local linkReported = rq and rq > 0 or false
  A.linkAvailable = false
  -- Read the whole physical Motor Switch as a raw source (-1024/0/+1024 for a
  -- three-position switch). There is deliberately no channel fallback: an
  -- invalid mapping must remain visible and can never suppress/acknowledge an
  -- alert.
  local rawMotorPosition
  if OPT.simTelemetry then
    A.motorSourceReadable = false
    A.motorConfigError = nil
    A.motorSwitchPosition = nil
  else
    if A.motorSourcePhysical then
      rawMotorPosition = getValSrc(SRC.motorSwitch)
    end
    rawMotorPosition = tonumber(rawMotorPosition)
    A.motorSourceReadable = A.motorSourcePhysical and rawMotorPosition ~= nil
    if not A.motorSourcePhysical then
      A.motorConfigError = "SELECT A PHYSICAL MOTOR SWITCH"
    elseif not A.motorSourceReadable then
      A.motorConfigError = "MOTOR SWITCH UNAVAILABLE"
    else
      A.motorConfigError = nil
    end
    if rawMotorPosition == nil then
      A.motorSwitchPosition = nil
    elseif rawMotorPosition > 0 then
      A.motorSwitchPosition = 1
    elseif rawMotorPosition < 0 then
      A.motorSwitchPosition = -1
    else
      A.motorSwitchPosition = 0
    end
  end
  local volt  = getPackVolt()
  local cells = getCellCount()
  local pctSensor = getBatPct()
  local capa  = getCapa()
  getCurr()
  local escT  = getTemp()
  local becV  = getBec()
  local cellVoltage = getCellVoltage()
  local headRpm = getHeadspeed()
  local governorMode = getGovernorMode()
  local hasCellVoltage = D.cellVoltageValid and cellVoltage > 0
  local telemetryEvidence = hasCellVoltage or D.batteryPercentValid
                            or D.capacityValid or D.currentValid
                            or D.tempValid or D.becValid or D.rpmValid
                            or D.govValid
  -- A link source becomes authoritative after it has produced a live positive
  -- sample. Until then, current telemetry itself keeps safety alerts operating;
  -- this covers discovered-but-unpopulated link sensors without masking a real
  -- zero after the link source has proved itself.
  A.linkAvailable = linkReported
                    or (not A.linkSourceSeen and telemetryEvidence)
  if A.linkAvailable then
    if not A.battLinkWasAvailable then
      A.battConnectionZeroPending = true
      A.battConnectionZeroSince = nil
    end
    A.battLinkWasAvailable = true
  else
    A.battLinkWasAvailable = false
    A.battConnectionZeroPending = false
    A.battConnectionZeroSince = nil
  end
  D.voltage       = D.packVoltageValid and volt or 0
  D.cellsResolved = D.cellCountValid and cells or 0
  D.capacity      = capa or 0
  if hasCellVoltage and cellVoltage > SAFETY.liHvDetectCellV then
    A.liHvHighSamples = math.min(SAFETY.liHvConfirmSamples, A.liHvHighSamples + 1)
    if A.liHvHighSamples >= SAFETY.liHvConfirmSamples then D.isLiHV = true end
  elseif not D.isLiHV then
    A.liHvHighSamples = 0
  end
  if hasCellVoltage then
    if D.minCellVoltage == nil or cellVoltage < D.minCellVoltage then
      D.minCellVoltage = cellVoltage
    end
  end
  local voltagePct = hasCellVoltage
                     and percentFromCellVoltage(cellVoltage, D.isLiHV) or nil
  local hasPackVoltage = D.packVoltageValid and volt > 0
  local pct, hasPct, pctSource = selectFlightBatteryPercent(
    OPT.heliType, pctSensor, D.batteryPercentValid, voltagePct,
    hasCellVoltage, hasPackVoltage)
  local hadPct = D.hasBattData
  D.hasBattData = hasPct
  D.adjustedPercent = calculateAdjustedPercent(pct, OPT.reservePct)
  if not hasPct then
    A.displayPercent = 0
    A.displayPercentInit = false
  elseif pctSource == "fc" then
    -- Smart Fuel already performs its own sag compensation and rate limiting.
    -- Preserve the FC estimate exactly instead of applying a second filter.
    A.displayPercent = D.adjustedPercent
    A.displayPercentInit = true
  elseif not hadPct or not A.displayPercentInit then
    A.displayPercent     = D.adjustedPercent
    A.displayPercentInit = true
  else
    A.displayPercent = A.displayPercent
                       + (D.adjustedPercent - A.displayPercent)
                         * SAFETY.displayPercentAlpha
  end
  if not OPT.simTelemetry then
    -- A raw switch move is never enough to silence a warning. Rotorflight must
    -- corroborate it with Gov or Hspd; OMPHOBBY uses stopped NR.
    updateMotorAlertGate(nowT, governorMode, headRpm)
    -- Percentage voice/haptic alerts belong to the main flight pack shown by
    -- Electric and OMPHOBBY modes. Nitro displays an Rx-pack voltage bar, so it
    -- must never run or retain this electric flight-pack alert state machine.
    local voiceEnabled = OPT.battVoice
    if OPT.battBarMode == 0 then
      if not A.flightBatteryAlertsPaused then
        updateBatteryAlertState(D.adjustedPercent, hasPct, voiceEnabled, pctSource)
        BATTERY_VOICE.updateDead(voiceEnabled)
        updateBatteryHapticTick()
      end
    elseif A.battAlertPrevPct ~= nil or A.battZeroReached
           or (A.battHapticState or 0) ~= 0 then
      resetBatteryAlertState("flight")
    end
    updateEscBecAlerts(escT, D.tempValid, becV, D.becValid)
  end
  if OPT.battBarMode == 1 then
    local rx = getRxBatt()
    if not OPT.simTelemetry then
      updateRxPackAlert(rx)
      BATTERY_VOICE.updateRxDead(OPT.battVoice, rx)
    end
    if D.becValid and rx and rx > 0 then
      D.rxVoltage     = rx
      D.rxCellVoltage = rx / 2
      if rx > 0 then
        if D.minRxVoltage == nil or rx < D.minRxVoltage then
          D.minRxVoltage = rx
        end
      end
      local rxMin = OPT.rxPackMin
      local rxMax = OPT.rxPackMax
      if OPT.rxPackValid and rxMax > rxMin then
        local p = (rx - rxMin) / (rxMax - rxMin) * 100
        if p < 0 then p = 0 end
        if p > 100 then p = 100 end
        D.rxPercent = p
      else
        D.rxPercent = 0
      end
    else
      D.rxVoltage = nil; D.rxCellVoltage = nil; D.rxPercent = 0
    end
  end
end
local function statRpmMax()  return S.rpmMax or 0 end
local function statCurrMax() return S.currMax or 0 end
local function statTempMax() return S.tempMax or 0 end
local function statBecMin()  return S.becMin end
local function statCellMin() return S.cellMin end
-- model.getTimer(0) shared per frame: the flight counter and top-bar clock both
-- need it, so read it once. Returns the timer table, or false on failure.
local function getTimer0()
  local t = F.timer0
  if t ~= nil then return t end
  local ok, tt = pcall(model.getTimer, 0)
  t = (ok and tt) or false
  F.timer0 = t
  return t
end
local function getTimer1Secs()
  local v = F.timerSecs
  if v ~= nil then return v end
  local t = getTimer0()
  v = (t and t.value) or 0
  F.timerSecs = v
  return v
end
local function getFlightCount()
  if OPT.flightCounter == FC.ROTORFLIGHT then return FC.count end
  return modelFlights
end
local function getFlightCache()
  -- RotorFlight mode never opens or parses the Radio CSV. Sim Preview may read
  -- the existing count, but every write/count path remains KSE Counter-only.
  if OPT.flightCounter == FC.ROTORFLIGHT then return {} end
  if flightCache then return flightCache end
  flightCache = {}
  local txt = readAll(FLIGHTS_PATH)
  if not txt or txt == "" then return flightCache end
  local entries = 0
  for line in string.gmatch(txt, "[^\r\n]+") do
    local n = trim(line)
    if n ~= "" and string.sub(n, 1, 1) ~= "#" then
      local k, v = string.match(n, "^%s*([^,]+)%s*,%s*([^,]+)")
      if k and v and k ~= "model_name" then
        flightCache[trim(k)] = tonumber(v) or 0
        entries = entries + 1
        if entries >= FLIGHT_CACHE_MAX_ENTRIES then break end
      end
    end
  end
  return flightCache
end
local function saveFlightCache()
  if OPT.flightCounter ~= FC.RADIO then return false end
  if not flightCache then return false end
  local keys = {}
  for k in pairs(flightCache) do keys[#keys+1] = k end
  table.sort(keys)
  local out = { "model_name,flight_count\n# api_ver=1\n" }
  for _, k in ipairs(keys) do
    out[#out+1] = string.format("%s,%d\n", k, tonumber(flightCache[k]) or 0)
  end
  local ok = writeAll(FLIGHTS_PATH, table.concat(out))
  A.flightSaveError = not ok
  return ok
end
local function modelKey(name)
  if type(name) ~= "string" or name == "" then return "__default__" end
  local s = trim(name)
  if s == "" then return "__default__" end
  return (string.gsub(s, ",", " "))
end
local function resetSessionStats()
  S.rpmMax  = 0
  S.currMax = 0
  S.tempMax = 0
  S.becMin  = nil
  S.cellMin = nil
end
local function resetSessionEvidence()
  for key in pairs(RESOLVED) do RESOLVED[key] = nil end
  A.linkAvailable = false
  A.linkSourceKnown = false
  A.linkSourceSeen = false
  A.battLinkWasAvailable = false
  A.battConnectionZeroPending = false
  A.battConnectionZeroSince = nil
  D.packVoltageValid = false
  D.cellCountValid = false
  D.cellVoltageValid = false
  D.batteryPercentValid = false
  D.capacityValid = false
  D.currentValid = false
  D.tempValid = false
  D.becValid = false
  D.rpmValid = false
  D.tailRpmValid = false
  D.govValid = false
  D.govCurrentInvalid = false
  D.hasBattData = false
  D.adjustedPercent = 0
  D.capacity = 0
  D.voltage = 0
  D.cellsResolved = 0
  D.isLiHV = false
  A.liHvHighSamples = 0
  A.displayPercent = 0
  A.displayPercentInit = false
  A.motorSwitchLastPosition = nil
  A.motorPausedPosition = nil
  A.motorGateCandidateFrom = nil
  A.motorGateCandidateTo = nil
  A.motorGateCandidateTick = nil
  A.govGateLastState = nil
  A.govGateRunningPosition = nil
  A.govGateStopTick = nil
  A.govGateStopSince = nil
  A.electricRpmGateRunningPosition = nil
  A.electricRpmGateZeroSince = nil
  A.ompGateRunningPosition = nil
  A.ompGateZeroSince = nil
  A.flightBatteryAlertsPaused = false
  A.batteryAlertPauseTick = nil
  A.motorPauseProof = nil
  D.minCellVoltage = nil
  D.minRxVoltage = nil
  resetBatteryAlertState()
end
local function loadModelFlights()
  if OPT.flightCounter == FC.ROTORFLIGHT then return end
  local key = modelKey(getModelName())
  flightModel = key
  modelFlights = getFlightCache()[key] or 0
  timerThresholdArmed = nil
  resetSessionStats()
  resetSessionEvidence()
end

-- Optional Rotorflight FC flight count --------------------------------------
-- RF Tool remains the only owner of transport framing and reply polling. The
-- small adapter below adds bounded behavior only to the command-14 message
-- created for KSE4; every unrelated RF Tool queue item keeps its original
-- semantics, including the official global retry policy.
--[=[ Legacy single-read implementation retained as source history only. KSE4
-- now uses the shared profile/diagnostics traffic coordinator below, matching
-- current KSE5 without replacing RF Tool's queue processor.
function FC.now()
  return (getTime and getTime()) or 0
end

function FC.selected()
  return OPT.flightCounter == FC.ROTORFLIGHT and not OPT.simTelemetry
end

function FC.shared()
  local shared = rawget(_G, "rf2") or _G.rf2
  return type(shared) == "table" and shared or nil
end

function FC.provider()
  local shared = FC.shared()
  local api = shared and tonumber(shared.rfToolApiVersion) or nil
  if not shared or not api or api < FC.toolApiMin
     or type(shared.registerWidget) ~= "function" then return nil end
  local seen = tonumber(shared.rfToolInstanceSeenAt)
  if seen and type(shared.clock) == "function" then
    local ok, clock = pcall(shared.clock)
    if ok and tonumber(clock) and tonumber(clock) - seen > 2 then return nil end
  end
  return shared
end

function FC.connected()
  if not FC.selected() then return false end
  local shared = FC.provider()
  local queue = shared and shared.mspQueue or nil
  local apiVersion = shared and tonumber(shared.apiVersion) or nil
  local state = FC.state
  return apiVersion and apiVersion >= FC.mspApiMin
         and type(queue) == "table" and type(queue.add) == "function"
         and (state == "connected" or state == "armed" or state == "disarmed")
end

function FC.armState()
  local value, current, _, known = get("ARM")
  value = tonumber(value)
  if current ~= true or known ~= true or value == nil then return nil end
  return math.floor(value) % 2 == 1
end

function FC.rfClock()
  local shared = FC.shared()
  if shared and type(shared.clock) == "function" then
    local ok, value = pcall(shared.clock)
    if ok and tonumber(value) then return tonumber(value) end
  end
  return FC.now() / 100
end

function FC.peekQueued(queue)
  local list = queue and queue.messageQueue
  if type(list) ~= "table" then return nil end
  if tonumber(queue.queueFirst) then return list[queue.queueFirst] end
  return list[1]
end

function FC.removeQueued(queue, message)
  local list = queue and queue.messageQueue
  if type(list) ~= "table" or not message then return false end
  if tonumber(queue.queueFirst) and tonumber(queue.queueLast) then
    local first, last = queue.queueFirst, queue.queueLast
    for i = first, last do
      if list[i] == message then
        for j = i, last - 1 do list[j] = list[j + 1] end
        list[last] = nil
        queue.queueLast = last - 1
        if queue.queueLast < queue.queueFirst then
          queue.queueFirst, queue.queueLast = 1, 0
        end
        return true
      end
    end
    return false
  end
  for i = 1, #list do
    if list[i] == message then
      table.remove(list, i)
      return true
    end
  end
  return false
end

function FC.cancelReason(message)
  local safety = message and message._stacyFlightSafety
  if not safety then return nil end
  if safety.cancelledReason then return safety.cancelledReason end
  if type(safety.cancel) ~= "function" then return nil end
  local ok, reason = pcall(safety.cancel)
  if not ok then return "CANCELLED" end
  return reason
end

function FC.notifyMessageError(message, reason)
  if not message then return end
  message._stacyFlightAbortReason = reason or "NO REPLY"
  if type(message.errorHandler) == "function" then
    pcall(message.errorHandler, message)
  end
end

function FC.abortCurrent(queue, reason)
  local message = queue and queue.currentMessage
  if not message then return false end
  queue.currentMessage = nil
  queue.lastTimeCommandSent = nil
  queue.retryCount = 0
  FC.notifyMessageError(message, reason)
  collectgarbage()
  return true
end

function FC.installQueueSafety(queue)
  if type(queue) ~= "table" then return false end
  if queue._stacyFlightSafetyInstalled then
    if queue._stacyFlightSafetyOwner == FC then return true end
    local base = queue._stacyFlightOriginalProcessQueue
    if type(base) ~= "function" then return false end
    queue.processQueue = base
    queue._stacyFlightSafetyInstalled = nil
    queue._stacyFlightSafetyOwner = nil
    queue._stacyFlightOriginalProcessQueue = nil
  end
  local original = queue.processQueue
  if type(original) ~= "function" then return false end
  queue._stacyFlightSafetyInstalled = true
  queue._stacyFlightSafetyOwner = FC
  queue._stacyFlightOriginalProcessQueue = original
  queue.processQueue = function(self)
    local now = FC.now()
    local current = self.currentMessage
    if not current then
      local queued = FC.peekQueued(self)
      local reason = FC.cancelReason(queued)
      if reason and FC.removeQueued(self, queued) then
        FC.notifyMessageError(queued, reason)
      end
    else
      local safety = current._stacyFlightSafety
      if safety then
        local reason = FC.cancelReason(current)
        if reason then
          safety.cancelledReason = reason
          safety.deadline = safety.deadline or (now + safety.responseTicks)
          -- A request that was already transmitted stays current for its
          -- finite reply window. This drains a possible late response while
          -- preventing every further send, then releases only this message.
          self.lastTimeCommandSent = FC.rfClock() + 86400
          if now >= safety.deadline then FC.abortCurrent(self, reason) end
        elseif (tonumber(self.retryCount) or 0) >= safety.maxAttempts
               and self.lastTimeCommandSent ~= nil then
          safety.deadline = safety.deadline or (now + safety.responseTicks)
          -- The official queue checks this timestamp before each retry. Move
          -- it into the future so it can continue polling but cannot transmit
          -- another command-14 frame while the final reply window is open.
          self.lastTimeCommandSent = FC.rfClock() + 86400
          if now >= safety.deadline then FC.abortCurrent(self, "NO REPLY") end
        end
      end
    end

    original(self)

    current = self.currentMessage
    local safety = current and current._stacyFlightSafety
    if safety and (tonumber(self.retryCount) or 0) >= safety.maxAttempts
       and self.lastTimeCommandSent ~= nil then
      safety.deadline = safety.deadline or (FC.now() + safety.responseTicks)
      self.lastTimeCommandSent = FC.rfClock() + 86400
    end
  end
  return true
end

function FC.requestFailed(token, reason)
  if token ~= FC.token then return end
  FC.pending = false
  FC.requestMessage = nil
  FC.stale = FC.count ~= nil
  if reason == "ARMED" then
    FC.status = "ARMED"
  elseif reason == "NO ARM" then
    FC.status = "NO ARM"
  elseif reason == "DISCONNECTED" then
    FC.count, FC.stale, FC.status = nil, false, "DISCONNECTED"
  elseif reason == "MODEL" or reason == "SOURCE" then
    FC.status = "WAITING"
  else
    FC.status = "NO REPLY"
  end
end

function FC.received(token, stats)
  if token ~= FC.token or not FC.selected() or FC.model ~= flightModel then
    return
  end
  FC.pending = false
  FC.requestMessage = nil
  if type(stats) ~= "table" or type(stats.statsEnabled) ~= "table"
     or tonumber(stats.statsEnabled.value) ~= 1 then
    FC.count, FC.stale, FC.status = nil, false, "STATS OFF"
    return
  end
  local count = stats.stats_total_flights
                and tonumber(stats.stats_total_flights.value) or nil
  if not count or count < 0 or count ~= math.floor(count) then
    FC.count, FC.stale, FC.status = nil, false, "BAD REPLY"
    return
  end
  FC.count, FC.stale, FC.status = count, false, "AVAILABLE"
end

function FC.requestCancelReason(widget, token)
  if token ~= FC.token or not FC.selected() then return "SOURCE" end
  if FC.model ~= flightModel then return "MODEL" end
  local armed = FC.armState()
  if armed == nil then return "NO ARM" end
  if armed then return "ARMED" end
  if FC.state == "disconnected" then return "DISCONNECTED" end
  return nil
end

function FC.queueRead(widget, shared)
  local queue = shared and shared.mspQueue or nil
  if type(queue) ~= "table" or type(queue.add) ~= "function"
     or not FC.installQueueSafety(queue) then
    FC.status = "NO QUEUE"
    return false
  end
  local idleOk, idle = pcall(queue.isProcessed, queue)
  if not idleOk or not idle then return false end
  local apiOk, api = pcall(shared.useApi, "mspFlightStats")
  if not apiOk or type(api) ~= "table" or type(api.read) ~= "function" then
    FC.status = "NO API"
    return false
  end

  FC.token = FC.token + 1
  local token = FC.token
  FC.pending, FC.wanted, FC.status = true, false, "LOADING"
  local inheritedAdd = queue.add
  local previousRawAdd = rawget(queue, "add")
  local decorated = false
  queue.add = function(self, message, copy)
    if not decorated and type(message) == "table" and message.command == 14 then
      decorated = true
      FC.requestMessage = message
      message._stacyFlightSafety = {
        maxAttempts=FC.maxAttempts,
        responseTicks=FC.responseTicks,
        cancel=function() return FC.requestCancelReason(widget, token) end,
      }
      local previousError = message.errorHandler
      message.errorHandler = function(self)
        if type(previousError) == "function" then pcall(previousError, self) end
        FC.requestFailed(token, self._stacyFlightAbortReason or "NO REPLY")
      end
    end
    return inheritedAdd(self, message, copy)
  end
  local readOk = pcall(api.read, FC.received, token)
  queue.add = previousRawAdd
  if not readOk or not decorated then
    FC.pending, FC.requestMessage, FC.status = false, nil, "REQUEST ERROR"
    return false
  end
  return true
end

function FC.cancelOutstanding(reason)
  FC.token = FC.token + 1
  FC.wanted, FC.pending, FC.stableSince = false, false, nil
  local message = FC.requestMessage
  FC.requestMessage = nil
  local shared = FC.shared()
  local queue = shared and shared.mspQueue or nil
  if not message or type(queue) ~= "table" then return end
  if queue.currentMessage == message then
    local safety = message._stacyFlightSafety
    if safety then safety.cancelledReason = reason or "SOURCE" end
  elseif FC.removeQueued(queue, message) then
    FC.notifyMessageError(message, reason or "SOURCE")
  end
end

function FC.selectSource(widget)
  FC.cancelOutstanding("SOURCE")
  FC.count, FC.stale, FC.state = nil, false, nil
  FC.model = flightModel
  if OPT.flightCounter == FC.ROTORFLIGHT then
    FC.status, FC.wanted = "STARTING", true
  else
    FC.status, FC.wanted = "RADIO", false
  end
end

function FC.stateChanged(widget, newState)
  if type(newState) ~= "string" then return end
  FC.state = newState
  if not FC.selected() then return end
  if newState == "disconnected" then
    FC.cancelOutstanding("DISCONNECTED")
    FC.count, FC.stale, FC.status = nil, false, "DISCONNECTED"
  elseif newState == "armed" then
    FC.wanted, FC.stableSince = false, nil
    if FC.count == nil then FC.status = "ARMED" end
  elseif newState == "connected" or newState == "disarmed" then
    FC.wanted, FC.stableSince, FC.status = true, nil, "WAITING"
    if newState == "disarmed" and FC.count ~= nil then FC.stale = true end
  end
end

function FC.startHiddenHost(widget)
  if FC.provider() or widget.fcRfToolHost
     or widget.profileRfProviderRef or widget.profileRfToolHost then return end
  local now = FC.now()
  if widget.fcRfToolRetryAt and now < widget.fcRfToolRetryAt then return end
  local loader = rawget(_G, "loadScript") or _G.loadScript
  if type(loader) ~= "function" then
    widget.fcRfToolError, widget.fcRfToolRetryAt = "INSTALL RF TOOL", now + 500
    return
  end
  local ok, factory = pcall(loader, "/WIDGETS/RfTool/app.lua")
  if not ok or type(factory) ~= "function" then
    widget.fcRfToolError, widget.fcRfToolRetryAt = "INSTALL RF TOOL", now + 500
    return
  end
  local hostOk, host = pcall(factory, { x=0, y=0, w=1, h=1 }, {
    Source=0, Color=C_TEXT, ["Hide Model"]=1,
    ["Hide State"]=1, ["Hide Telemetry"]=1,
    sourceName="", sourceUnit="",
  })
  if not hostOk or type(host) ~= "table"
     or type(host.background) ~= "function" then
    widget.fcRfToolError, widget.fcRfToolRetryAt = "RF TOOL FAILED", now + 500
    return
  end
  widget.fcRfToolHost = host
  widget.fcRfToolError, widget.fcRfToolRetryAt = nil, nil
end

function FC.serviceHiddenHost(widget)
  local host = widget and widget.fcRfToolHost
  if not host or type(host.background) ~= "function" then return end
  local ok = pcall(host.background, host, true)
  if not ok then
    widget.fcRfToolError = "RF TOOL ERROR"
    return
  end
  local shared = FC.shared()
  local queue = shared and shared.mspQueue or nil
  local apiVersion = shared and tonumber(shared.apiVersion) or nil
  local state = host.state
  if apiVersion and apiVersion >= FC.mspApiMin
     and (state == "connected" or state == "armed" or state == "disarmed")
     and type(queue) == "table" and type(queue.processQueue) == "function" then
    pcall(queue.processQueue, queue)
  end
end

function FC.register(widget, shared)
  if not shared or widget.fcRfToolRegistered then return end
  widget.onStateChanged = function(instance, newState)
    FC.stateChanged(instance, newState)
  end
  local ok = pcall(shared.registerWidget, widget)
  if ok then widget.fcRfToolRegistered = true end
end

function FC.service(widget)
  -- Once KSE4 has created a hidden RF Tool host, keep that official host
  -- alive even if the user switches back to KSE Counter. Other RF Tool clients
  -- must not be left registered against an unserviced global provider.
  local servicedHost = widget.fcRfToolHost ~= nil
  local profileOwnsService = widget.profileRfProviderRef ~= nil
  if servicedHost and not profileOwnsService then FC.serviceHiddenHost(widget) end
  if not FC.selected() then return end

  FC.startHiddenHost(widget)
  if widget.fcRfToolHost and not servicedHost and not profileOwnsService then
    FC.serviceHiddenHost(widget)
  end
  local shared = FC.provider()
  if not shared then
    FC.status = widget.fcRfToolError or "STARTING"
    return
  end
  FC.register(widget, shared)

  local state = (shared.widget and shared.widget.state)
                or (widget.fcRfToolHost and widget.fcRfToolHost.state)
  if state and state ~= FC.state then FC.stateChanged(widget, state) end
  if FC.state == "disconnected" then return end
  if FC.state ~= "connected" and FC.state ~= "disarmed"
     and FC.state ~= "armed" then
    FC.status = "RF TOOL WAIT"
    return
  end

  local apiVersion = tonumber(shared.apiVersion)
  if apiVersion and apiVersion < FC.mspApiMin then
    FC.status = "RF 2.3 REQUIRED"
    return
  elseif not apiVersion then
    FC.status = "INITIALIZING"
    return
  end

  local armed = FC.armState()
  if armed == nil then
    FC.stableSince = nil
    if not FC.pending then FC.status = "NO ARM SENSOR" end
    return
  elseif armed then
    FC.stableSince = nil
    if FC.count == nil and not FC.pending then FC.status = "ARMED" end
    return
  end

  local now = FC.now()
  FC.stableSince = FC.stableSince or now
  if FC.wanted and not FC.pending then
    FC.status = "WAITING"
    if now - FC.stableSince >= FC.disarmStableTicks then
      FC.queueRead(widget, shared)
    end
  end
end
--]=]

local function timerElapsedSeconds(timer)
  if type(timer) ~= "table" then return nil end
  local value = tonumber(timer.value)
  if not value then return nil end
  local start = tonumber(timer.start) or 0
  local elapsed = start > 0 and (start - value) or value
  if elapsed < 0 then elapsed = 0 end
  return elapsed
end
local function shiftFlightBatteryAlertTimers(delta)
  if not delta or delta <= 0 then return end
  if (A.battAlertNextTick or 0) > 0 then
    A.battAlertNextTick = A.battAlertNextTick + delta
  end
  if (A.deadVoiceNextTick or 0) > 0 then
    A.deadVoiceNextTick = A.deadVoiceNextTick + delta
  end
  if (A.battHapticNextTick or 0) > 0 then
    A.battHapticNextTick = A.battHapticNextTick + delta
  end
  if (A.battHapticEndTick or 0) > 0 then
    A.battHapticEndTick = A.battHapticEndTick + delta
  end
  if A.battConnectionZeroSince ~= nil then
    A.battConnectionZeroSince = A.battConnectionZeroSince + delta
  end
  if A.battReplacementSince ~= nil then
    A.battReplacementSince = A.battReplacementSince + delta
  end
end
local function setFlightBatteryAlertsPaused(paused, now)
  paused = paused == true
  if paused == A.flightBatteryAlertsPaused then return end
  now = tonumber(now) or frameNow()
  if paused then
    A.flightBatteryAlertsPaused = true
    A.batteryAlertPauseTick = now
  else
    local started = tonumber(A.batteryAlertPauseTick)
    A.flightBatteryAlertsPaused = false
    A.batteryAlertPauseTick = nil
    if started and now > started then
      shiftFlightBatteryAlertTimers(now - started)
    end
  end
end
local function clearMotorGateCandidate()
  A.motorGateCandidateFrom = nil
  A.motorGateCandidateTo = nil
  A.motorGateCandidateTick = nil
  A.electricRpmGateZeroSince = nil
  A.ompGateZeroSince = nil
end
local function clearMotorGateEvidence()
  clearMotorGateCandidate()
  A.govGateLastState = nil
  A.govGateRunningPosition = nil
  A.govGateStopTick = nil
  A.govGateStopSince = nil
  A.electricRpmGateRunningPosition = nil
  A.ompGateRunningPosition = nil
end
local function releaseMotorAlertPause(now)
  setFlightBatteryAlertsPaused(false, now)
  A.motorPausedPosition = nil
  A.motorPauseProof = nil
  clearMotorGateEvidence()
end
local function resetMotorAlertGate(now)
  -- Losing or changing any gate input must fail loud: immediately restore
  -- flight-pack alerts and discard all prior movement/state correlation.
  releaseMotorAlertPause(now)
  A.motorSwitchLastPosition = nil
end
local function gateTickIsRecent(tick, now, limit)
  return tick ~= nil and now >= tick and (now - tick) <= limit
end
local function captureMotorSwitchCandidate(fromPosition, toPosition, now)
  A.motorGateCandidateFrom = fromPosition
  A.motorGateCandidateTo = toPosition
  A.motorGateCandidateTick = now
  A.electricRpmGateZeroSince = nil
  A.ompGateZeroSince = nil
end
local function pauseFlightBatteryAlerts(position, now, proof)
  clearMotorGateEvidence()
  A.motorPausedPosition = position
  A.motorPauseProof = proof
  setFlightBatteryAlertsPaused(true, now)
end
local function updateRotorflightMotorGate(now, position, switchChanged,
                                           governorMode, headRpm)
  local govUsable = D.govValid and governorMode ~= nil
  local rpmUsable = D.rpmValid and headRpm ~= nil
  if not govUsable and not rpmUsable then
    clearMotorGateEvidence()
    return
  end

  -- Gov correlation is intentionally short, but the independent Hspd proof
  -- needs enough time for an autorotation or normal rotor coast-down.
  if A.motorGateCandidateTick ~= nil
     and not gateTickIsRecent(A.motorGateCandidateTick, now,
                              SAFETY.electricMotorStopWindowTicks) then
    clearMotorGateCandidate()
  end

  if govUsable then
    local previousGov = A.govGateLastState
    if GOV_RUNNING_STATE[governorMode] then
      A.govGateStopTick = nil
      A.govGateStopSince = nil
      -- A switch move may reach Lua just before Gov leaves ACTIVE. Keep the
      -- last position proven by an unchanged running sample until correlation
      -- either succeeds or expires.
      if not switchChanged and A.motorGateCandidateTick == nil then
        A.govGateRunningPosition = position
      end
    elseif GOV_STOP_STATE[governorMode] then
      if previousGov ~= nil and GOV_RUNNING_STATE[previousGov] then
        A.govGateStopTick = now
        A.govGateStopSince = now
      end
    elseif governorMode ~= 1 or A.govGateStopTick == nil then
      -- IDLE may follow a sampled AUTOROT/THR-OFF/OFF transition before its
      -- confirmation time elapses. Retain that explicit stop evidence only;
      -- IDLE by itself still cannot initiate a pause.
      A.govGateStopTick = nil
      A.govGateStopSince = nil
    end

    local switchRecent = gateTickIsRecent(
      A.motorGateCandidateTick, now, SAFETY.govMotorCorrelationTicks)
    local govRecent = gateTickIsRecent(
      A.govGateStopTick, now, SAFETY.govMotorCorrelationTicks)
    local stopConfirmed = A.govGateStopSince ~= nil
                          and now >= A.govGateStopSince
                          and (now - A.govGateStopSince)
                              >= SAFETY.govMotorStopConfirmTicks
    if GOV_PAUSE_HOLD_STATE[governorMode] and switchRecent and govRecent
       and stopConfirmed
       and A.motorGateCandidateFrom == A.govGateRunningPosition
       and A.motorGateCandidateTo == position then
      pauseFlightBatteryAlerts(position, now, "gov")
      return
    end
    A.govGateLastState = governorMode
  else
    -- Do not let stale Gov transition state leak into the Hspd fallback.
    A.govGateLastState = nil
    A.govGateRunningPosition = nil
    A.govGateStopTick = nil
    A.govGateStopSince = nil
  end

  if not rpmUsable then
    A.electricRpmGateRunningPosition = nil
    A.electricRpmGateZeroSince = nil
    return
  end

  local rotorRunning = headRpm >= SAFETY.electricMotorRunningRpm
  if rotorRunning then
    A.electricRpmGateZeroSince = nil
    if A.motorGateCandidateTick == nil then
      A.electricRpmGateRunningPosition = position
    end
    return
  end

  -- A known running/unsafe or current-invalid Gov value overrides a zero Hspd;
  -- this prevents a lost RPM signal from being mistaken for motor-off. Missing
  -- or stale Gov is allowed because Hspd is an independent current proof.
  local govAllowsRpmStop = not D.govCurrentInvalid
                           and (not govUsable
                                or GOV_PAUSE_HOLD_STATE[governorMode])
  local candidateValid = govAllowsRpmStop
                         and gateTickIsRecent(
                           A.motorGateCandidateTick, now,
                           SAFETY.electricMotorStopWindowTicks)
                         and A.electricRpmGateRunningPosition ~= nil
                         and A.motorGateCandidateFrom
                             == A.electricRpmGateRunningPosition
                         and A.motorGateCandidateTo == position
  if not candidateValid then
    A.electricRpmGateZeroSince = nil
    return
  end
  if A.electricRpmGateZeroSince == nil then
    A.electricRpmGateZeroSince = now
  end
  if now >= A.electricRpmGateZeroSince
     and (now - A.electricRpmGateZeroSince)
         >= SAFETY.electricMotorZeroConfirmTicks then
    pauseFlightBatteryAlerts(position, now, "rpm")
  end
end
local function updateOmpMotorGate(now, position, headRpm)
  if not D.rpmValid or headRpm == nil then
    clearMotorGateEvidence()
    return
  end

  if A.motorGateCandidateTick ~= nil
     and not gateTickIsRecent(A.motorGateCandidateTick, now,
                              SAFETY.ompMotorStopWindowTicks) then
    clearMotorGateCandidate()
  end

  local rotorRunning = headRpm >= SAFETY.ompMotorRunningRpm
  if rotorRunning then
    A.ompGateZeroSince = nil
    if A.motorGateCandidateTick ~= nil
       and (A.motorGateCandidateFrom ~= A.ompGateRunningPosition
            or A.motorGateCandidateTo ~= position) then
      clearMotorGateCandidate()
    end
    -- Running NR can persist during rotor coast-down. Do not relabel the new
    -- switch position as running while a valid stop candidate is pending.
    if A.motorGateCandidateTick == nil then
      A.ompGateRunningPosition = position
    end
    return
  end

  local candidateValid = A.motorGateCandidateTick ~= nil
                         and A.ompGateRunningPosition ~= nil
                         and A.motorGateCandidateFrom
                             == A.ompGateRunningPosition
                         and A.motorGateCandidateTo == position
  if not candidateValid then
    A.ompGateZeroSince = nil
    return
  end
  if A.ompGateZeroSince == nil then A.ompGateZeroSince = now end
  if now >= A.ompGateZeroSince
     and (now - A.ompGateZeroSince) >= SAFETY.ompMotorZeroConfirmTicks then
    pauseFlightBatteryAlerts(position, now, "omp")
  end
end
updateMotorAlertGate = function(now, governorMode, headRpm)
  local position = A.motorSwitchPosition
  local switchUsable = A.motorSourcePhysical and A.motorSourceReadable
                       and position ~= nil
  if not switchUsable or not A.linkAvailable then
    resetMotorAlertGate(now)
    return
  end

  local previousPosition = A.motorSwitchLastPosition
  local switchChanged = previousPosition ~= nil
                        and previousPosition ~= position
  A.motorSwitchLastPosition = position

  -- Nitro's receiver-pack warning retains its independent post-latch switch
  -- acknowledgement. This gate only controls Electric/OMP flight-pack alerts.
  if OPT.battBarMode ~= 0 then
    releaseMotorAlertPause(now)
    return
  end

  if A.flightBatteryAlertsPaused then
    if switchChanged or position ~= A.motorPausedPosition then
      releaseMotorAlertPause(now)
      return
    end
    if OPT.heliType == HELI_ELECTRIC then
      if A.motorPauseProof == "rpm" then
        local govBlocksRpmHold = D.govCurrentInvalid
                                 or (D.govValid and governorMode ~= nil
                                     and not GOV_PAUSE_HOLD_STATE[governorMode])
        if govBlocksRpmHold or not D.rpmValid or headRpm == nil
           or headRpm >= SAFETY.electricMotorRunningRpm then
          releaseMotorAlertPause(now)
        end
      elseif not D.govValid or governorMode == nil
             or not GOV_PAUSE_HOLD_STATE[governorMode] then
        releaseMotorAlertPause(now)
      end
    elseif not D.rpmValid or headRpm == nil
           or headRpm >= SAFETY.ompMotorRunningRpm then
      releaseMotorAlertPause(now)
    end
    return
  end

  if switchChanged then
    local candidateFrom = previousPosition
    if OPT.heliType == HELI_ELECTRIC then
      candidateFrom = A.govGateRunningPosition
                      or A.electricRpmGateRunningPosition
                      or candidateFrom
    elseif OPT.heliType == HELI_OMPHOBBY
           and A.ompGateRunningPosition ~= nil then
      -- A three-position switch can cross its middle detent on a separate
      -- service tick. Keep the position proven by running telemetry as the
      -- origin so intermediate detents cannot erase a valid stop event.
      candidateFrom = A.ompGateRunningPosition
    end
    if candidateFrom ~= position then
      captureMotorSwitchCandidate(candidateFrom, position, now)
    else
      clearMotorGateCandidate()
    end
  end
  if OPT.heliType == HELI_ELECTRIC then
    updateRotorflightMotorGate(now, position, switchChanged, governorMode,
                               headRpm)
  elseif OPT.heliType == HELI_OMPHOBBY then
    updateOmpMotorGate(now, position, headRpm)
  else
    clearMotorGateEvidence()
  end
end
local function tickFlightCount()
  if OPT.simTelemetry then return end
  local thisModel = modelKey(getModelName())
  if flightModel ~= thisModel then
    flightModel = thisModel
    if OPT.flightCounter == FC.RADIO then
      modelFlights = getFlightCache()[thisModel] or 0
    else
      FC.count, FC.stale = nil, false
      FC.status, FC.wanted = "WAITING", true
      FC.stableSince, FC.model = nil, thisModel
    end
    timerThresholdArmed = nil
    resetSessionStats()
    resetSessionEvidence()
  end
  if OPT.flightCounter ~= FC.RADIO then return end
  local t = getTimer0()
  if not t then return end
  local secs = timerElapsedSeconds(t)
  if secs == nil then return end
  if timerThresholdArmed == nil then
    timerThresholdArmed = (secs < minFlightDur)
  end
  if secs < minFlightDur then
    timerThresholdArmed = true
  elseif timerThresholdArmed then
    timerThresholdArmed = false
    local cache = getFlightCache()
    local newCount = (cache[thisModel] or modelFlights or 0) + 1
    cache[thisModel] = newCount
    modelFlights = newCount
    saveFlightCache()
  end
end
local function updateStats()
  if not A.linkAvailable then return end
  local r = getHeadspeed()
  if D.rpmValid and r > 0 then
    if r > S.rpmMax then S.rpmMax = r end
  end
  local c = getCurr()
  if D.currentValid and c > S.currMax then S.currMax = c end
  local t = getTemp()
  if D.tempValid and t > S.tempMax then S.tempMax = t end
  local b = getBec()
  if D.becValid and (S.becMin == nil or b < S.becMin) then S.becMin = b end
  local mc = getCellVoltage()
  if mc and mc > 0 and (S.cellMin == nil or mc < S.cellMin) then S.cellMin = mc end
end

local DATA_INTERVAL_TICKS = 10 -- 10 Hz; telemetry and UI do not need frame-rate polling
local function serviceTelemetry(trackStats)
  local now = frameNow()
  local last = A.lastDataTick
  if last and last >= 0 and now >= last and (now - last) < DATA_INTERVAL_TICKS then
    return false
  end
  if not OPT.simTelemetry then tickFlightCount() end
  tick(now)
  if trackStats then updateStats() end
  return true
end

-- Simulation is a display-only 36-second loop. It bypasses tick(), so none of
-- the flight counter, audio, haptic, motor-gate, MSP, or safety-alert code can
-- run. Tail-Rotor RPM remains on KSE4's existing fixed simulation path.
G.simIntervalTicks = 10
function G.applySimulatedTelemetry(now)
  now = tonumber(now) or 0
  local phase = (now % 3600) / 3600
  local wave = (math.sin(phase * math.pi * 2) + 1) * 0.5
  local motorRunning = phase >= 0.08 and phase < 0.92
  local rpm = motorRunning and G.rounded(650 + wave * 1750) or 0
  local current = motorRunning and G.rounded(15 + wave * 235) or 0
  local temp = G.rounded(32 + phase * 68)
  local rawPercent = 96 - phase * 74
  local adjustedPercent = calculateAdjustedPercent(rawPercent, OPT.reservePct)
  local cells = OPT.heliType == HELI_OMPHOBBY and 3 or 12
  local cell = 4.18 - phase * 0.56
  local pack = cell * cells
  local bec = 7.65 + wave * 0.42
  local govMode
  if phase < 0.08 then
    govMode = 0
  elseif phase < 0.20 then
    govMode = 2
  elseif phase < 0.80 then
    govMode = 4
  elseif phase < 0.92 then
    govMode = 3
  else
    govMode = 7
  end

  A.linkAvailable = true
  A.linkSourceKnown = true
  A.linkSourceSeen = true
  A.displayPercent = adjustedPercent
  A.displayPercentInit = true

  D.isLiHV = false
  D.hasBattData = OPT.heliType ~= HELI_NITRO
  D.adjustedPercent = adjustedPercent
  D.capacity = G.rounded(180 + phase * 4100)
  D.voltage = pack
  D.cellsResolved = cells
  D.packVoltageValid = OPT.heliType ~= HELI_NITRO
  D.cellCountValid = OPT.heliType ~= HELI_NITRO
  D.cellVoltageValid = OPT.heliType ~= HELI_NITRO
  D.batteryPercentValid = OPT.heliType ~= HELI_NITRO
  D.capacityValid = OPT.heliType ~= HELI_NITRO
  D.currentValid = OPT.heliType ~= HELI_NITRO
  D.tempValid = OPT.heliType ~= HELI_NITRO
  D.becValid = OPT.heliType ~= HELI_OMPHOBBY
  D.rpmValid = true
  D.govValid = OPT.heliType ~= HELI_OMPHOBBY
  D.govCurrentInvalid = false
  D.minCellVoltage = cell - 0.05

  if OPT.heliType == HELI_NITRO then
    local rx = 8.25 - phase * 1.35
    local denominator = math.max(0.1, OPT.rxPackMax - OPT.rxPackMin)
    local rxPercent = math.max(0, math.min(100,
      (rx - OPT.rxPackMin) / denominator * 100))
    D.rxVoltage = rx
    D.rxCellVoltage = rx / 2
    D.rxPercent = rxPercent
    D.minRxVoltage = rx - 0.12
    F.bec = rx
    F.cellVoltage = rx / 2
    F.packVolt = rx
  else
    D.rxVoltage = nil
    D.rxCellVoltage = nil
    D.rxPercent = 0
    D.minRxVoltage = nil
    F.bec = bec
    F.cellVoltage = cell
    F.packVolt = pack
  end

  F.rqly = G.rounded(88 + wave * 11)
  F.txVolt = 7.55 + wave * 0.65
  F.timerSecs = 182 + math.floor(phase * 815)
  F.cellCount = cells
  F.batPct = rawPercent
  F.capa = D.capacity
  F.curr = current
  F.temp = temp
  F.rpm = rpm
  F.battProfile = 3
  if OPT.heliType == HELI_OMPHOBBY then
    F.govNumber = false
    F.gov = "--"
  else
    F.govNumber = govMode
    F.gov = GOV_STATES[govMode]
  end

  S.rpmMax = 2400
  S.currMax = 250
  S.tempMax = 100
  S.becMin = OPT.heliType ~= HELI_OMPHOBBY and 7.55 or nil
  S.cellMin = OPT.heliType == HELI_NITRO and nil or 3.57
end

function G.serviceSimulation(widget)
  local now = frameNow()
  local last = widget.lastSimTick
  if last and last >= 0 and now >= last
     and (now - last) < G.simIntervalTicks then
    return false
  end
  widget.lastSimTick = now
  G.applySimulatedTelemetry(now)
  return true
end

local function fileExists(path)
  local f = io.open(path, "r")
  if not f then return false end
  pcall(io.close, f)
  return true
end
local function resolveModelImagePath()
  local name = getModelName()
  if modelImageName == name then return modelImagePath end
  local sanitized = sanitizeFsName(name)
  if not sanitized or sanitized == "" then sanitized = "MODEL" end
  -- Never concatenate raw model text into an SD-card path. The sanitized name
  -- preserves normal names while preventing separators from escaping /IMAGES.
  local candidates = {
    "/IMAGES/" .. sanitized .. ".png",
    "/IMAGES/" .. sanitized .. ".bmp",
    "/WIDGETS/KSE4/default.png",
  }
  candidates[#candidates+1] = "/IMAGES/default.png"
  candidates[#candidates+1] = "/IMAGES/defaultmodel.png"
  candidates[#candidates+1] = "/WIDGETS/KSE4/Rotorflight.png"
  modelImagePath = nil
  for _, path in ipairs(candidates) do
    if fileExists(path) then modelImagePath = path; break end
  end
  modelImageName = name
  return modelImagePath
end

local FMT_CACHE = {}
local function fmtNum(slot, pattern, v)
  local c = FMT_CACHE[slot]
  if c and c.v == v then return c.s end
  local s = string.format(pattern, v)
  if c then c.v = v; c.s = s else FMT_CACHE[slot] = { v = v, s = s } end
  return s
end
local flightsCacheN, flightsCacheS = -1, ""
local function fmtFlights(count)
  if count ~= flightsCacheN then
    flightsCacheN = count
    flightsCacheS = string.format("%d %s", count, (count == 1) and "Flight" or "Flights")
  end
  return flightsCacheS
end
local function batColor(pct)
  if pct >= 50 then return C_GREEN end
  if pct >= 20 then return C_YELLOW end
  return C_RED
end
local function txBatColor(pct)
  -- Classify the estimated whole percentage so floating-point rounding at the
  -- voltage boundaries cannot turn an exact 50% green or an exact 30% yellow.
  local wholePct = math.floor((pct or 0) + 0.5)
  if wholePct >= 51 then return C_GREEN end
  if wholePct >= 31 then return C_YELLOW end
  return C_RED
end
local function cellVoltageColor(sessionMin)
  if sessionMin and sessionMin <= SAFETY.cellRedThreshold then return C_RED end
  return C_TEXT
end

-- Retained LVGL object references. Static chrome is created once in update();
-- refresh() only changes the handful of properties whose values moved.
local V = {}
local OBJECT_STATE = {}
local function rememberObject(obj, properties)
  local state = { visible=true }
  for key, value in pairs(properties) do state[key] = value end
  OBJECT_STATE[obj] = state
  return obj
end
local function setObject(obj, properties)
  if not obj then return end
  local state = OBJECT_STATE[obj]
  if not state then
    state = {}
    OBJECT_STATE[obj] = state
  end
  local changed = false
  for key, value in pairs(properties) do
    if state[key] ~= value then
      state[key] = value
      changed = true
    end
  end
  if changed then obj:set(properties) end
end
local function setVisible(obj, visible)
  if not obj then return end
  local state = OBJECT_STATE[obj]
  if not state then
    state = {}
    OBJECT_STATE[obj] = state
  end
  visible = not not visible
  if state.visible == visible then return end
  state.visible = visible
  if visible then obj:show() else obj:hide() end
end
local function setLabel(obj, text, color, x, y, w, font, align)
  if not obj then return end
  local p = { text = tostring(text or "") }
  if color ~= nil then p.color = color end
  if x ~= nil then p.x = x end
  if y ~= nil then p.y = y end
  if w ~= nil then p.w = w end
  if font ~= nil then p.font = font end
  if align ~= nil then p.align = align end
  setObject(obj, p)
end
local function newLabel(x, y, w, text, font, color, align)
  local properties = { x=x, y=y, w=w or 0, h=0, text=text or "",
                       font=font or 0, color=color or C_TEXT, align=align or 0 }
  return rememberObject(lvgl.label(properties), properties)
end
local function newRect(x, y, w, h, color, filled, rounded, thickness)
  local properties = { x=x, y=y, w=w, h=h, color=color,
                       filled=filled and 1 or 0, rounded=rounded or 0,
                       thickness=thickness or 1 }
  return rememberObject(lvgl.rectangle(properties), properties)
end
local function newPanel(x, y, w, h, bg, border, rounded)
  return {
    fill = newRect(x, y, w, h, bg, true, rounded, 1),
    border = newRect(x, y, w, h, border, false, rounded, 1),
  }
end
local function setPanel(panel, bg, border)
  setObject(panel.fill, { color=bg })
  setObject(panel.border, { color=border })
end

local SIG_HEIGHTS = { 6, 10, 14, 18 }
local function buildTopBar()
  local y, h = G.layout.top.y, G.layout.top.h
  local centerY = y + h / 2
  local timerX = G.originX + G.w / 2 - G.x(100)
  local modelGap = math.max(3, G.x(8))
  local modelW = math.max(G.x(120), timerX - G.layout.top.x - modelGap)
  -- LVGL fonts carry more top leading than lcd.drawText(); compensate so the
  -- glyphs occupy the same top-bar baseline as the original dashboard.
  V.modelName = newLabel(G.layout.top.x, y - G.y(2), modelW, "",
                         G.fontTop, C_TEXT)
  V.timer = newLabel(timerX,
                     math.max(G.originY, y - G.y(9)),
                     G.x(200), "", G.fontTimer, C_TEXT, CENTERED)
  -- A compact vertical battery sits at the far right. Rotating the original
  -- glyph counter-clockwise puts its terminal on top and makes charge fill
  -- bottom-to-top. Signal quality occupies the space immediately to its left.
  local battW, battH = math.max(4, G.x(20)), math.max(8, G.y(28))
  local terminalW, terminalH = math.max(2, G.x(10)), math.max(1, G.y(3))
  local oneY = math.max(1, G.y(1))
  local totalBattH = battH + terminalH + oneY
  local battX = G.originX + G.w - G.x(10) - battW
  local battY = centerY - totalBattH / 2 + terminalH + oneY
  local sigX = battX - G.x(14) - G.x(36)
  local profileSignalGap = math.max(8, G.x(10))
  local profileMinW = #"Profile 6 / Rate 6" * 9
  local profileX = math.min(timerX + G.x(150),
                            sigX - profileSignalGap - profileMinW)
  local profileY = math.floor(centerY - 11)
  if G.screen480x320 then profileY = profileY + 2 end
  V.profileStatus = newLabel(
    profileX, profileY,
    math.max(1, sigX - profileSignalGap - profileX), "",
    SMLSIZE, C_TEXT, RIGHT)
  V.signal = {}
  for i, referenceH in ipairs(SIG_HEIGHTS) do
    local bh = math.max(1, G.y(referenceH))
    V.signal[i] = newRect(sigX + (i-1) * G.x(10),
                          centerY + G.y(10) - bh,
                          math.max(1, G.x(6)), bh,
                          C_LINE, true, 0, 0)
  end
  V.txBody = newPanel(battX, battY, battW, battH, C_TILE, C_DIM,
                      math.max(0, G.min(3)))
  newRect(battX + (battW - terminalW) / 2, battY - terminalH - 1,
          terminalW, terminalH, C_DIM, true, math.max(0, G.min(1)), 0)
  local insetX, insetY = math.max(1, G.x(2)), math.max(1, G.y(2))
  V.txFill = newRect(battX + insetX, battY + battH - insetY - 1,
                     math.max(1, battW - insetX * 2), 1, C_GREEN, true,
                     math.max(0, G.min(2)), 0)
  lvgl.hline({ x=G.originX, y=y + h + G.y(2), w=G.w, h=1, color=C_LINE })
  V.txBodyW, V.txBodyH, V.txBodyY = battW, battH, battY
  V.txInsetX, V.txInsetY = insetX, insetY
end

local function buildModelPanel()
  local p = G.layout.pic
  local footerH = math.max(1, G.y(28))
  local imgH = p.h - footerH
  newPanel(p.x, p.y, p.w, p.h, C_TILE, C_LINE, p.r)
  local inset = math.max(1, p.r - G.min(3))
  V.modelImage = lvgl.image({
    x=p.x + inset, y=p.y + inset, w=p.w - inset * 2,
    h=imgH - inset * 2, fill=false,
    file=function() return resolveModelImagePath() or "" end,
    visible=function() return resolveModelImagePath() ~= nil end,
  })
  V.noImage = lvgl.label({
    x=p.x, y=p.y + imgH / 2 - G.y(8), w=p.w, h=0,
    text="no model image", font=G.fontSmall, color=C_DIM, align=CENTERED,
    visible=function() return resolveModelImagePath() == nil end,
  })
  lvgl.hline({ x=p.x + G.x(8), y=p.y + imgH,
               w=p.w - G.x(16), h=1, color=C_LINE })
  V.flightCount = newLabel(p.x, p.y + p.h - footerH + G.y(5), p.w, "",
                           G.fontSmall, C_TEXT, CENTERED)
end

local function buildGovernor()
  local g = G.layout.gov
  V.govPanel = newPanel(g.x, g.y, g.w, g.h, C_TILE, C_LINE, g.r)
  newLabel(g.x, g.y + G.y(14), g.w, "GOVERNOR",
           G.fontSmall, C_ACCENT, CENTERED)
  V.govState = newLabel(g.x, g.y + G.y(50), g.w, "",
                        G.fontGovernor, C_TEXT, CENTERED)
end

local function buildHero()
  local hb = G.layout.hero
  newPanel(hb.x, hb.y, hb.w, hb.h, C_TILE, C_LINE, hb.r)
  local title = G.compact and "HEADSPEED" or "HEADSPEED RPM"
  newLabel(hb.x + G.x(14), hb.y + G.y(3), G.x(285),
           title, G.fontSmall, C_DIM)
  local rpmW = G.compact and G.x(250) or G.x(230)
  V.rpm = newLabel(hb.x + G.x(14), hb.y + G.y(42), rpmW, "",
                   G.fontHero, C_TEXT)
  local rx = hb.x + hb.w - G.x(14)
  if G.compact then
    -- Combine each secondary label/value into one right-aligned object. This
    -- avoids the narrow "max" and "tail" labels wrapping on 480-wide radios.
    local rightW = G.x(170)
    local rightX = rx - rightW
    local ry = hb.y + G.y(25)
    V.rpmMax = newLabel(rightX, ry, rightW, "",
                        G.fontSmall, C_YELLOW, RIGHT)
    V.tailRpm = newLabel(rightX, ry + G.y(60), rightW, "",
                         G.fontSmall, C_TEXT, RIGHT)
    V.compactHero = true
  elseif G.largeScreen then
    -- Pair each caption tightly with a left-aligned value. Offset the smaller
    -- caption downward so its visual center matches the MIDSIZE number.
    local ry, step = hb.y + G.y(25), G.y(60)
    local valueW = G.x(90)
    local labelW = G.x(45)
    local gap = G.x(6)
    local rightInset = G.x(20)
    local valueX = rx - rightInset - valueW
    local labelX = valueX - gap - labelW
    local labelYAdjust = G.y(4)
    newLabel(labelX, ry + labelYAdjust, labelW, "max",
             G.fontSecondaryLabel, C_DIM, RIGHT)
    V.rpmMax = newLabel(valueX, ry, valueW, "",
                        G.fontSecondaryValue, C_YELLOW)
    newLabel(labelX, ry + step + labelYAdjust, labelW, "tail",
             G.fontSecondaryLabel, C_DIM, RIGHT)
    V.tailRpm = newLabel(valueX, ry + step, valueW, "",
                         G.fontSecondaryValue, C_TEXT)
  else
    local lx = rx - G.x(170)
    local ry, step = hb.y + G.y(25), G.y(30)
    local labelW = G.x(70)
    newLabel(lx, ry, labelW, "max", G.fontSecondaryLabel, C_DIM)
    V.rpmMax = newLabel(lx + labelW, ry, G.x(100), "",
                        G.fontSecondaryValue, C_YELLOW, RIGHT)
    newLabel(lx, ry + step * 2, labelW, "tail", G.fontSecondaryLabel, C_DIM)
    V.tailRpm = newLabel(lx + labelW, ry + step * 2, G.x(100), "",
                         G.fontSecondaryValue, C_TEXT, RIGHT)
  end
end

local function buildTile(x, y, w, h, label, unit)
  if G.compact then
    local caption = label
    if unit == "(V)" then
      caption = label .. " V"
    elseif unit == "(°C)" then
      caption = "ESC °C"
    end
    newLabel(x + 2, y + 4, w - 4, caption,
             G.fontSmall, C_DIM, CENTERED)
    local valueY = y + math.max(20, G.y(32))
    if G.screen480x320 then
      -- MIDSIZE is 24 px tall on this target. Center the value itself in the
      -- tile while leaving the compact caption and extrema footer anchored.
      valueY = y + math.floor((h - 24) / 2)
    end
    return {
      value = newLabel(x + 2, valueY, w - 4, "",
                       G.fontValue, C_TEXT, CENTERED),
      footer = newLabel(x + 2, y + h - 16, w - 4, "",
                        G.fontSmall, C_DIM, CENTERED),
    }
  end
  newLabel(x + G.x(10), y + G.y(10), w - G.x(20), label,
           G.fontSmall, C_DIM)
  newLabel(x + w - G.x(45), y + G.y(10), G.x(35), unit,
           G.fontSmall, C_DIM, RIGHT)
  local valueY = y + G.y(54)
  if G.screen800x480 then
    -- Center the 32 px DBLSIZE value without moving the caption or footer.
    valueY = y + math.floor((h - 32) / 2)
  end
  return {
    value = newLabel(x + G.x(10), valueY, w - G.x(20), "",
                     G.fontValue, C_TEXT,
                     G.screen800x480 and CENTERED or 0),
    footer = newLabel(x + G.x(10), y + h - G.y(22),
                      w - G.x(20), "", G.fontSmall, C_DIM),
  }
end
local function buildTiles()
  local t = G.layout.tiles
  local n = 4
  local w = math.floor((t.w - (n-1) * t.gap) / n)
  local becLabel = OPT.heliType == HELI_NITRO and "BATT" or "BEC"
  newPanel(t.x, t.y, t.w, t.h, C_TILE, C_LINE, t.r)
  for i = 1, n - 1 do
    local dx = t.x + (w + t.gap) * i - math.floor(t.gap / 2)
    lvgl.vline({ x=dx, y=t.y + G.y(8), w=1,
                 h=t.h - G.y(16), color=C_LINE })
  end
  V.tiles = {
    buildTile(t.x,                         t.y, w, t.h, "AMPS",  "(A)"),
    buildTile(t.x + (w + t.gap),          t.y, w, t.h, "CELL",  "(V)"),
    buildTile(t.x + (w + t.gap) * 2,      t.y, w, t.h, becLabel, "(V)"),
    buildTile(t.x + (w + t.gap) * 3,      t.y, w, t.h, "ESC T", "(°C)"),
  }
end

local function buildBottom()
  local b = G.layout.bot
  local x, y, w = b.x, b.y, b.w
  local barY = y + G.y(G.compact and 30 or 26)
  -- Keep the top anchored and extend only the lower edge by five physical
  -- pixels so the increase is identical at every supported resolution.
  local barH = math.max(1, G.y(G.compact and 44 or 60) + 5)
  -- The original 44px bar centered this font at barY + 2. Move the text down
  -- by half of any added height so it remains centered as the bottom extends.
  local textY = barY + G.y(2)
                + math.floor((barH - G.y(44)) / 2)
  local insetX, insetY = math.max(1, G.x(2)), math.max(1, G.y(2))
  V.bottom = {
    x=x, y=y, w=w, barY=barY, barH=barH, textY=textY,
    insetX=insetX, insetY=insetY, minTextW=math.max(1, G.x(40)),
    header=newLabel(x, y + G.y(2), w, "", G.fontSmall, C_DIM),
    panel=newPanel(x, barY, w, barH, C_TILE, C_LINE,
                   math.max(0, G.min(5))),
    fill=newRect(x + insetX, barY + insetY, 1,
                 math.max(1, barH - insetY * 2), C_GREEN, true,
                 math.max(0, G.min(3)), 0),
    center=newLabel(x, textY, w, "", G.fontBattery, C_BLACK, CENTERED),
  }
  local B = V.bottom
  if OPT.battBarMode == 1 then
    B.mode = "nitro"
    B.minimum = newLabel(x, barY + barH + G.y(4), G.x(220), "",
                         G.fontSmall, C_DIM)
    B.range = newLabel(x + w - G.x(220), barY + barH + G.y(4),
                       G.x(220),
                       string.format("%.1fV - %.1fV", OPT.rxPackMin, OPT.rxPackMax),
                       G.fontSmall, C_DIM, RIGHT)
  else
    B.mode = "electric"
    -- The reference-size footer needs less air below the taller bar. Keep the
    -- compact-radio spacing unchanged because those layouts are independently
    -- fitted to their shorter screens.
    local footerGap = G.screen800x480 and G.y(1) or G.y(4)
    local fy = barY + barH + footerGap
    local tickW, halfTick = G.x(60), G.x(30)
    B.ticks = {
      newLabel(x,                    fy, tickW, "0%",   G.fontSmall, C_DIM),
      newLabel(x + w*.25 - halfTick, fy, tickW, "25%",  G.fontSmall, C_DIM, CENTERED),
      newLabel(x + w*.50 - halfTick, fy, tickW, "50%",  G.fontSmall, C_DIM, CENTERED),
      newLabel(x + w*.75 - halfTick, fy, tickW, "75%",  G.fontSmall, C_DIM, CENTERED),
      newLabel(x + w - tickW,        fy, tickW, "100%", G.fontSmall, C_DIM, RIGHT),
    }
  end
end

local function updateBottom()
  local B = V.bottom
  if not B then return end
  local configWarning
  local rxSettingsInvalid = B.mode == "nitro" and not OPT.rxPackValid
  if not OPT.simTelemetry then
    if A.motorConfigError and rxSettingsInvalid then
      configWarning = A.motorConfigError .. " · CHECK RX PACK SETTINGS"
    elseif A.motorConfigError then
      configWarning = A.motorConfigError
    elseif rxSettingsInvalid then
      configWarning = "CHECK RX PACK SETTINGS"
    end
  end
  if B.mode == "nitro" then
    local hasRx = OPT.rxPackValid and D.rxVoltage ~= nil and D.rxVoltage > 0
    local rxV, rxCV, pct = D.rxVoltage or 0, D.rxCellVoltage or 0, D.rxPercent or 0
    local header
    if G.compact then
      header = hasRx and string.format("RX BATT · %.2fV · %.2fV/cell", rxV, rxCV)
                     or "RX BATT · no data"
    else
      header = hasRx
                   and string.format("Receiver Battery · %.2fV · %.2fV/cell", rxV, rxCV)
                   or "Receiver Battery · no data"
    end
    if OPT.simTelemetry then header = "SIM · " .. header end
    setLabel(B.header,
             configWarning or header,
             configWarning and C_RED or C_DIM)
    local fillW = math.floor((B.w - B.insetX * 2) * pct / 100)
    local wholePct = math.floor(pct)
    local showEmpty = hasRx and wholePct <= 0
    setPanel(B.panel, C_TILE, showEmpty and C_RED or C_LINE)
    setObject(B.fill, { w=math.max(1, fillW),
                        h=math.max(1, B.barH - B.insetY * 2),
                        color=batColor(pct) })
    setVisible(B.fill, hasRx and fillW > 0)
    if showEmpty then
      setLabel(B.center, "0%", C_RED, B.x, B.textY, B.w,
               G.fontBattery, CENTERED)
      setVisible(B.center, true)
    else
      setLabel(B.center, tostring(wholePct) .. "%", C_BLACK,
               B.x + B.insetX, B.textY, math.max(1, fillW),
               G.fontBattery, CENTERED)
      setVisible(B.center, hasRx and fillW > B.minTextW)
    end
    setLabel(B.minimum, D.minRxVoltage and string.format("min %.2fV", D.minRxVoltage)
                                          or "min --", C_DIM)
    setLabel(B.range,
             OPT.rxPackValid and string.format("%.1fV - %.1fV", OPT.rxPackMin, OPT.rxPackMax)
                             or "INVALID RANGE",
             OPT.rxPackValid and C_DIM or C_RED)
    return
  end

  local cells, volt = D.cellsResolved, D.voltage
  local capa = math.floor(D.capacity or 0)
  local usedText = D.capacityValid
                   and (G.compact and string.format(" · %dmAh", capa)
                                  or string.format(" · %d mAh used", capa))
                   or ""
  local prof = getBattProfile()
  local batteryTitle = G.compact and "BATT" or "BATTERY"
  local header
  if not D.hasBattData and OPT.heliType == HELI_OMPHOBBY
     and getCellCount() == 0 then
    header = batteryTitle .. " · ADD M1 OR M2 TO MODEL NAME"
  elseif not D.hasBattData then
    header = batteryTitle .. " · no data"
  elseif cells > 0 and volt > 0 and prof and prof > 0 then
    header = string.format("%s · P%d · %dS · %.1fV",
                           batteryTitle, math.floor(prof), cells, volt) .. usedText
  elseif cells > 0 and volt > 0 then
    header = string.format("%s · %dS · %.1fV",
                           batteryTitle, cells, volt) .. usedText
  elseif D.cellVoltageValid then
    header = string.format("%s · %.2fV/cell",
                           batteryTitle, getCellVoltage()) .. usedText
  else
    -- Smart Fuel can remain fully usable when Vcel/Vbat are not configured.
    -- Do not invent a 0.00V/cell header for a valid FC-side percentage.
    header = batteryTitle .. usedText
  end
  if OPT.simTelemetry then header = "SIM · " .. header end
  setLabel(B.header, configWarning or header, configWarning and C_RED or C_DIM)
  setPanel(B.panel, C_TILE, C_LINE)
  if not D.hasBattData then
    setVisible(B.fill, false)
    setLabel(B.center, "NO DATA", C_RED, B.x, B.textY, B.w,
             G.fontBattery, CENTERED)
    setVisible(B.center, true)
    for _, tickLabel in ipairs(B.ticks) do setVisible(tickLabel, false) end
  else
    local pct = A.displayPercentInit and A.displayPercent or D.adjustedPercent
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    local fillW = math.floor((B.w - B.insetX * 2) * pct / 100)
    local wholePct = math.floor(pct)
    local showEmpty = wholePct <= 0
    setPanel(B.panel, C_TILE, showEmpty and C_RED or C_LINE)
    setObject(B.fill, { w=math.max(1, fillW),
                        h=math.max(1, B.barH - B.insetY * 2),
                        color=batColor(pct) })
    setVisible(B.fill, fillW > 0)
    if showEmpty then
      setLabel(B.center, "0%", C_RED, B.x, B.textY, B.w,
               G.fontBattery, CENTERED)
      setVisible(B.center, true)
    else
      setLabel(B.center, tostring(wholePct) .. "%", C_BLACK,
               B.x + B.insetX, B.textY, math.max(1, fillW),
               G.fontBattery, CENTERED)
      setVisible(B.center, fillW > B.minTextW)
    end
    for _, tickLabel in ipairs(B.ticks) do setVisible(tickLabel, true) end
  end
end

local function updateUiState()
  if not V.modelName then return end
  local modelName = getModelName()
  if OPT.simTelemetry then modelName = "SIM · " .. modelName end
  local modelFont = G.fontTop
  -- 480x320 has enough vertical and horizontal room for common full model
  -- names such as "Stratos 700 #3" at MIDSIZE. Keep the earlier small-font
  -- protection on 480x272 and for genuinely longer compact-screen names.
  local compactNameLimit = G.screen480x320 and 16 or 12
  if G.compact and #modelName > compactNameLimit then
    modelFont = G.fontSmall
  end
  if G.compact and #modelName > 22 then
    modelName = string.sub(modelName, 1, 20) .. ".."
  end
  setLabel(V.modelName, modelName, C_TEXT, nil, nil, nil, modelFont)
  local secs = getTimer1Secs()
  local mm = math.floor(math.abs(secs) / 60)
  local ss = math.abs(secs) - mm * 60
  setLabel(V.timer, string.format("%d:%02d", mm, ss), C_TEXT)

  local rq = getRqly()
  local bars = rq >= 80 and 4 or rq >= 60 and 3 or rq >= 40 and 2 or rq >= 20 and 1 or 0
  local sigColor = bars >= 3 and C_GREEN or bars == 2 and C_YELLOW or C_RED
  for i, bar in ipairs(V.signal) do
    setObject(bar, { color=(i <= bars) and sigColor or C_LINE })
  end

  local pidProfile = getSensorNumber("pidProfile")
  local rateProfile = getSensorNumber("rateProfile")
  pidProfile = tonumber(pidProfile)
  rateProfile = tonumber(rateProfile)
  if not pidProfile or pidProfile ~= math.floor(pidProfile)
     or pidProfile < 1 or pidProfile > 6 then
    pidProfile = nil
  end
  if not rateProfile or rateProfile ~= math.floor(rateProfile)
     or rateProfile < 1 or rateProfile > 6 then
    rateProfile = nil
  end
  if OPT.simTelemetry then
    pidProfile, rateProfile = 1, 1
  end
  local profilesReady = OPT.simTelemetry
                        or (A.linkAvailable
                            and pidProfile and rateProfile)
  setLabel(V.profileStatus,
    profilesReady and string.format("Profile %d / Rate %d",
      pidProfile, rateProfile) or "", C_TEXT)

  local txPct = txPctFromVolts(getTxVolt(), txIsLiIon)
  if txPct then
    local fillH = math.floor((V.txBodyH - V.txInsetY * 2) * txPct / 100)
    local fillY = V.txBodyY + V.txBodyH - V.txInsetY - fillH
    setObject(V.txFill, { y=fillY,
                          w=math.max(1, V.txBodyW - V.txInsetX * 2),
                          h=math.max(1, fillH),
                          color=txBatColor(txPct) })
    setVisible(V.txFill, fillH > 0)
  else
    setVisible(V.txFill, false)
  end

  local flightText, flightColor
  if OPT.flightCounter == FC.ROTORFLIGHT then
    local count = getFlightCount()
    if count ~= nil then
      flightText = fmtFlights(count)
      flightColor = FC.stale and C_YELLOW or C_TEXT
    else
      flightText = FC.status or "WAITING"
      flightColor = (FC.status == "LOADING" or FC.status == "WAITING"
                     or FC.status == "STARTING" or FC.status == "INITIALIZING")
                    and C_YELLOW or C_RED
    end
  else
    flightText = fmtFlights(getFlightCount())
    if A.flightSaveError then flightText = flightText .. " · SAVE ERROR" end
    flightColor = A.flightSaveError and C_RED or C_TEXT
  end
  if G.profileConnectedForDisplay then
    flightText = flightText .. " - Connected"
  end
  setLabel(V.flightCount, flightText, flightColor)
  local govState = getGovState()
  local govTheme = GOV_COLOR[govState] or GOV_FALLBACK
  setPanel(V.govPanel, govTheme.bg, govTheme.br)
  setLabel(V.govState, GOV_LABELS[govState] or govState, govTheme.fg)

  local rpm = getHeadspeed()
  if D.rpmValid then
    setLabel(V.rpm, tostring(math.floor(rpm)), C_TEXT)
    local maxText = fmtNum("rpmMax", "%d", math.floor(statRpmMax()))
    setLabel(V.rpmMax, V.compactHero and ("MAX " .. maxText) or maxText,
             C_YELLOW)
  else
    setLabel(V.rpm, "--", C_DIM)
    setLabel(V.rpmMax, V.compactHero and "MAX --" or "--", C_DIM)
  end
  local tailRpm = getTailRpm()
  local tailText = D.tailRpmValid and tostring(math.floor(tailRpm)) or "--"
  if V.compactHero then tailText = "TAIL " .. tailText end
  setLabel(V.tailRpm, tailText,
           D.tailRpmValid and C_TEXT or C_DIM)

  if OPT.battBarMode == 1 then
    setLabel(V.tiles[1].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
    setLabel(V.tiles[1].footer, "", C_DIM)
    local rxCell = D.rxCellVoltage
    local rxCellMin = D.minRxVoltage and (D.minRxVoltage / 2) or nil
    if rxCell and rxCell > 0 then
      setLabel(V.tiles[2].value, string.format("%.2f", rxCell), C_TEXT,
               nil, nil, nil, nil,
               (G.compact or G.screen800x480) and CENTERED or 0)
    else
      setLabel(V.tiles[2].value, "--", C_DIM,
               nil, nil, nil, nil, CENTERED)
    end
    setLabel(V.tiles[2].footer,
             rxCellMin and string.format("min %.2f", rxCellMin) or "min --", C_DIM)
  else
    local curr = getCurr()
    if D.currentValid then
      setLabel(V.tiles[1].value, tostring(math.ceil(curr)), C_TEXT)
      setLabel(V.tiles[1].footer,
               fmtNum("currMax", "max %d", math.ceil(statCurrMax())), C_YELLOW)
    else
      setLabel(V.tiles[1].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
      setLabel(V.tiles[1].footer, "", C_DIM)
    end
    local cell = getCellVoltage()
    local cellMin = statCellMin()
    if cell > 0 then
      setLabel(V.tiles[2].value, string.format("%.2f", cell),
               cellVoltageColor(cellMin), nil, nil, nil, nil,
               (G.compact or G.screen800x480) and CENTERED or 0)
    else
      setLabel(V.tiles[2].value, "--", C_DIM,
               nil, nil, nil, nil, CENTERED)
    end
    setLabel(V.tiles[2].footer,
             D.cellVoltageValid and cellMin
               and fmtNum("cellMin", "min %.2f", cellMin) or "min --", C_DIM)
  end
  local bec = getBec()
  local becColor = C_TEXT
  if bec and bec > 0 then
    if bec < 4.8 then becColor = C_RED elseif bec < 5.1 then becColor = C_YELLOW end
  end
  if D.becValid then
    setLabel(V.tiles[3].value, string.format("%.1f", bec), becColor)
    local becMin = statBecMin()
    setLabel(V.tiles[3].footer,
             becMin and fmtNum("becMin", "min %.1f", becMin) or "min --", C_DIM)
  else
    setLabel(V.tiles[3].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
    setLabel(V.tiles[3].footer, "", C_DIM)
  end
  if OPT.battBarMode == 1 then
    setLabel(V.tiles[4].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
    setLabel(V.tiles[4].footer, "", C_DIM)
  else
    local temp, tempMax = getTemp(), statTempMax()
    if D.tempValid then
      setLabel(V.tiles[4].value, tostring(math.floor(temp)), C_TEXT)
      setLabel(V.tiles[4].footer, fmtNum("tempMax", "max %d", math.floor(tempMax)),
               C_YELLOW)
    else
      setLabel(V.tiles[4].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
      setLabel(V.tiles[4].footer, "", C_DIM)
    end
  end
  updateBottom()
end

-- RotorFlight 2.3 battery-profile picker ------------------------------------
-- This is the GX15 Dash RF Tool integration adapted to KSE4's responsive
-- retained UI. RF Tool remains the sole transport and queue owner.
local batteryProfiles = (function()
local EVT_TOUCH_TAP = rawget(_G, "EVT_TOUCH_TAP") or _G.EVT_TOUCH_TAP
local MSP_BATTERY_CONFIG = 32
local MSP_BATTERY_STATE = 130
local MSP_BATTERY_PROFILE = 175
local MSP_SET_BATTERY_PROFILE = 176
local MSP_EEPROM_WRITE = 250
local ROTORFLIGHT_23_MSP_API = 12.09
local RF_TOOL_WIDGET_API = 1.00
local BATTERY_CAPACITY_MAX = 20000
local PROFILE_SELECTION_NOTICE = 100
local PROFILE_CONNECT_SETTLE = 40
local PROFILE_HOST_DISCOVERY = 20
local PROFILE_READ_TIMEOUT = 800
local PROFILE_SELECT_TIMEOUT = 2000
local PROFILE_ACTIVE_CAPACITY_TIMEOUT = 300
local PROFILE_SNAPSHOT_ACTIVE_TIMEOUT = 500
local PROFILE_SNAPSHOT_CAPACITY_TIMEOUT = 1200
local PROFILE_FLIGHT_STATS_TIMEOUT = 200

local function profileNow()
  return (getTime and getTime()) or 0
end

local function profileRf2()
  local value = rawget(_G, "rf2") or _G.rf2
  return type(value) == "table" and value or nil
end

local function profileRfToolInstanceLive()
  local shared = profileRf2()
  if not shared then return nil end
  local seenAt = tonumber(shared.rfToolInstanceSeenAt)
  local clock = shared.clock
  if not seenAt or type(clock) ~= "function" then return nil end
  local ok, current = pcall(clock)
  current = ok and tonumber(current) or nil
  if not current or current - seenAt > 2 then return nil end
  return shared
end

local function profileRadioLinkLive()
  local reader = rawget(_G, "getRSSI") or _G.getRSSI
  if type(reader) ~= "function" then return false end
  local ok, value = pcall(reader)
  return ok and tonumber(value) ~= nil and tonumber(value) > 0
end

local function profileStandaloneRf2bgCore(shared)
  shared = shared or profileRf2()
  if type(shared) ~= "table" then return false end
  local api = tonumber(shared.apiVersion)
  return api and api >= ROTORFLIGHT_23_MSP_API
         and type(shared.useApi) == "function"
         and type(shared.mspQueue) == "table"
         and type(shared.mspQueue.add) == "function"
         and shared.rfToolApiVersion == nil
         and shared.registerWidget == nil
         and shared.widget == nil
         and shared.rfToolInstanceSeenAt == nil
end

local function profileRfToolProvider()
  local shared = profileRf2()
  if not shared then return nil end
  local toolApi = tonumber(shared.rfToolApiVersion)
  local hasConsumerApi = toolApi and toolApi >= RF_TOOL_WIDGET_API
                         and type(shared.registerWidget) == "function"
  local mspApi = tonumber(shared.apiVersion)
  local hasQueue = type(shared.mspQueue) == "table"
                   and type(shared.mspQueue.add) == "function"
  local hasRfToolCore = hasQueue
                        and (type(shared.widget) == "table"
                             or (mspApi and mspApi >= ROTORFLIGHT_23_MSP_API
                                 and profileRfToolInstanceLive() == shared))
  if not hasConsumerApi and not hasRfToolCore then return nil end
  return shared
end

local function profileSharedQueue()
  local shared = profileRfToolProvider()
  local mspApi = shared and tonumber(shared.apiVersion) or nil
  if not shared or not mspApi or mspApi < ROTORFLIGHT_23_MSP_API
     or type(shared.mspQueue) ~= "table"
     or type(shared.mspQueue.add) ~= "function" then return nil end
  return shared.mspQueue
end

local function profileRfApi(name)
  local shared = profileRfToolProvider()
  if not shared or type(shared.useApi) ~= "function" then return nil end
  local ok, api = pcall(shared.useApi, name)
  return ok and type(api) == "table" and api or nil
end

local function profileTransport()
  return profileSharedQueue() and "shared" or nil
end

local function profileStartEmbeddedRfTool(wgt)
  -- FC count can create the hidden host before profile discovery finishes.
  -- That host is the shared runtime; retain and service it instead of loading
  -- a second instance or leaving the first one stranded in STARTING.
  if profileRfToolInstanceLive() or profileRfToolProvider()
     or wgt.profileRfToolHost then return end
  if profileStandaloneRf2bgCore() then
    wgt.profileRfToolHostError = "DISABLE rf2bg SPECIAL FUNCTION"
    return
  end
  local now = profileNow()
  if not wgt.profileRfToolDiscoveryAt then
    wgt.profileRfToolDiscoveryAt = now + PROFILE_HOST_DISCOVERY
    return
  end
  if now < wgt.profileRfToolDiscoveryAt then return end
  if wgt.profileRfToolHostNextTick
     and now < wgt.profileRfToolHostNextTick then return end

  local loader = rawget(_G, "loadScript") or _G.loadScript
  if type(loader) ~= "function" then
    wgt.profileRfToolHostError = "INSTALL RF TOOL 2.3"
    wgt.profileRfToolHostNextTick = now + 500
    return
  end
  local ok, factory = pcall(loader, "/WIDGETS/RfTool/app.lua")
  if not ok or type(factory) ~= "function" then
    wgt.profileRfToolHostError = "INSTALL RF TOOL 2.3"
    wgt.profileRfToolHostNextTick = now + 500
    return
  end
  local hostOk, host = pcall(factory, { x=0, y=0, w=1, h=1 }, {
    Source=0, Color=C_TEXT, ["Hide Model"]=1,
    ["Hide State"]=1, ["Hide Telemetry"]=1,
    sourceName="", sourceUnit="",
  })
  if not hostOk or type(host) ~= "table"
     or type(host.background) ~= "function" then
    wgt.profileRfToolHostError = "RF TOOL HOST FAILED"
    wgt.profileRfToolHostNextTick = now + 500
    return
  end
  wgt.profileRfToolHost = host
  wgt.profileRfToolHostCore = profileRf2()
  wgt.profileRfToolHostError = nil
  wgt.profileRfToolHostNextTick = nil
end

local function profileServiceEmbeddedRfTool(wgt)
  profileStartEmbeddedRfTool(wgt)
  local shared = profileRf2()
  local host = wgt.profileRfToolHost
               or (shared and type(shared.widget) == "table"
                   and shared.widget or nil)
  if host == wgt.profileRfToolHost and wgt.profileRfToolHostCore
     and shared ~= wgt.profileRfToolHostCore then
    wgt.profileRfToolHost = nil
    wgt.profileRfToolHostCore = nil
    host = shared and type(shared.widget) == "table" and shared.widget or nil
  end

  local function serviceQueue(core, currentHost)
    local state = currentHost and currentHost.state or wgt.profileRfState
    local hostReady = state == "connected" or state == "armed"
                      or state == "disarmed"
    local coreReady = not currentHost and profileRadioLinkLive()
    local queue = core and core.mspQueue or nil
    local api = core and tonumber(core.apiVersion) or nil
    if not (hostReady or coreReady)
       or not api or api < ROTORFLIGHT_23_MSP_API
       or type(queue) ~= "table"
       or type(queue.processQueue) ~= "function" then return false end
    local queueOk = pcall(queue.processQueue, queue)
    if not queueOk then
      wgt.profileRfToolHostError = "RF TOOL QUEUE ERROR"
      wgt.profileQueueFault = true
    elseif wgt.profileRfToolHostError == "RF TOOL QUEUE ERROR" then
      wgt.profileRfToolHostError = nil
      wgt.profileQueueFault = nil
    end
    return true
  end

  -- Poll every KSE-owned in-flight MSP operation before RF Tool background
  -- services. This keeps profiles, FC stats, and arming diagnostics on one
  -- consistent queue-ownership policy.
  local priorityPass = wgt.profileOperation ~= nil
                       or (OPT.heliType ~= HELI_OMPHOBBY
                           and wgt.armingStatusPending == true)
  local priorityServiced = priorityPass and serviceQueue(shared, host) or false
  if host and type(host.background) == "function" and not priorityServiced then
    local ok = pcall(host.background, host, true)
    if not ok then
      wgt.profileRfToolHostError = "RF TOOL HOST ERROR"
      return
    end
  end
  if not priorityServiced then
    serviceQueue(profileRf2(), host)
  end
end

local function profileRfToolStatus(wgt)
  if wgt.profileRfToolHostError then return wgt.profileRfToolHostError end
  local shared = profileRfToolProvider()
  if not shared then return "STARTING RF TOOL 2.3" end
  local state = wgt.profileRfState
  if state == "compiling" or state == "loading"
     or state == "unknown protocol" or state == "ready"
     or state == "initializing" then
    return "RF TOOL: " .. string.upper(state)
  end
  local mspApi = tonumber(shared.apiVersion)
  if mspApi and mspApi < ROTORFLIGHT_23_MSP_API then
    return "ROTORFLIGHT 2.3 FC REQUIRED"
  end
  if not profileSharedQueue() then return "WAITING FOR RF TOOL API" end
  if state == "disconnected" then return "RF TOOL: DISCONNECTED" end
  return "WAITING FOR RF TOOL CONNECTION"
end

local function profileSetMessage(wgt, text, color)
  wgt.profileMessage = text
  wgt.profileMessageColor = color or C_DIM
end

local function profileSetNotice(wgt, title, detail, color, duration, compact)
  wgt.profileNoticeTitle = title
  wgt.profileNoticeDetail = detail
  wgt.profileNoticeColor = color or C_DIM
  wgt.profileNoticeCompact = compact == true
  wgt.profileNoticeUntil = profileNow() + (duration or 300)
end

local function profileRefreshSelectionNotice(wgt, title, detail, color)
  local now = profileNow()
  if not wgt.profileNoticeCompact or not wgt.profileNoticeUntil
     or now >= wgt.profileNoticeUntil then return end
  wgt.profileNoticeTitle = title
  wgt.profileNoticeDetail = detail
  wgt.profileNoticeColor = color or C_DIM
end

local function profileBuildEntryPrompt()
  local promptW = math.min(G.w - math.max(12, G.x(24)), G.compact and 300 or 360)
  local promptH = G.compact and 56 or 64
  local x = G.originX + math.floor((G.w - promptW) / 2)
  local y = G.originY + math.floor((G.h - promptH) / 2)
  local titleY = y + (G.compact and 5 or 7)
  local detailY = y + (G.compact and 34 or 39)
  local prompt = {
    fill=newRect(x, y, promptW, promptH, C_TILE, true,
                 math.max(2, G.min(6)), 1),
    border=newRect(x, y, promptW, promptH, C_LINE, false,
                   math.max(2, G.min(6)), 2),
    accent=newRect(x + 2, y + 2, math.max(3, G.x(5)), promptH - 4,
                   C_GREEN, true, math.max(1, G.min(2)), 1),
    title=newLabel(x + 10, titleY, promptW - 20, "",
                   G.fontSmall, C_TEXT, CENTERED),
    detail=newLabel(x + 10, detailY, promptW - 20, "",
                    G.fontSmall, C_DIM, CENTERED),
  }
  prompt.objects = {
    prompt.fill, prompt.border, prompt.accent, prompt.title, prompt.detail,
  }
  V.profilePrompt = prompt
  for _, object in ipairs(prompt.objects) do setVisible(object, false) end
end

local function profileBuildArmingBanner()
  if OPT.heliType == HELI_OMPHOBBY then return end
  local inset = math.max(5, G.x(10))
  local y = G.originY + math.max(40, G.y(48))
  local h = math.max(20, G.y(24))
  local banner = {
    fill=newRect(G.originX + inset, y, G.w - inset * 2, h,
                 C_RED, true, math.max(2, G.min(3)), 1),
    border=newRect(G.originX + inset, y, G.w - inset * 2, h,
                   C_YELLOW, false, math.max(2, G.min(3)), 1),
    label=newLabel(G.originX + inset * 2, y + math.max(2, G.y(4)),
                   G.w - inset * 4, "", G.fontSmall, C_TEXT, CENTERED),
  }
  banner.objects = { banner.fill, banner.border, banner.label }
  V.armingBanner = banner
  for _, object in ipairs(banner.objects) do setVisible(object, false) end
end

local function profileSetEntryPrompt(visible, title, detail, color, compact)
  local prompt = V.profilePrompt
  if not prompt then return end
  if visible then
    setObject(prompt.accent, { color=color or C_GREEN })
    setLabel(prompt.title, title or "BATTERY PROFILE READY", C_TEXT)
    setLabel(prompt.detail, detail or "SELECT A BATTERY PROFILE", C_DIM)
  end
  for _, object in ipairs(prompt.objects) do setVisible(object, visible) end
  if visible and compact then setVisible(prompt.accent, false) end
end

local function profileOperationOwnsMessage(operation, message)
  if not operation or not message then return false end
  for _, ownMessage in ipairs(operation.messages or {}) do
    if ownMessage == message then return true end
  end
  return false
end

local function profileCancelOperationQueue(operation)
  local queue = operation and operation.queue or nil
  if not queue or type(queue.clear) ~= "function" then return false end
  if queue.currentMessage
     and not profileOperationOwnsMessage(operation, queue.currentMessage) then
    return false
  end
  for _, message in pairs(queue.messageQueue or {}) do
    if message and not profileOperationOwnsMessage(operation, message) then
      return false
    end
  end
  local ok = pcall(queue.clear, queue)
  return ok
end

local function profileOperationFailed(wgt, text, token)
  local operation = wgt.profileOperation
  if token and (not operation or operation.token ~= token) then return end
  local kind = operation and operation.kind or nil
  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  if kind == "snapshot" then
    wgt.profileInitialReadFinished = true
    wgt.profileCapacityReadFinished = true
    if wgt.profileInitialReadValid and wgt.profileActive then
      profileSetMessage(wgt, "MSP 32 mAh NOT RECEIVED", C_YELLOW)
    else
      profileSetMessage(wgt, text or "PROFILE DATA UNAVAILABLE", C_DIM)
    end
    return
  end
  if kind == "activeCapacity" then
    profileSetMessage(wgt,
      "PROFILE " .. tostring(operation and operation.target or "")
        .. " SELECTED", C_DIM)
    return
  end
  profileSetMessage(wgt, text or "PROFILE COMMAND FAILED", C_RED)
  profileSetNotice(wgt, "BATTERY PROFILE ERROR",
                   text or "PROFILE COMMAND FAILED", C_RED, 500)
end

local function profileSelectionVerified(wgt, zeroBased, token)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token
     or operation.kind ~= "select" then return end

  local index = tonumber(zeroBased)
  if not index or index ~= math.floor(index)
     or index < 0 or index >= BATTERY_PROFILE_COUNT then
    profileCancelOperationQueue(operation)
    profileOperationFailed(wgt, "INVALID PROFILE REPLY", token)
    return
  end

  local displayProfile = index + 1
  wgt.profileActive = displayProfile
  F.battProfile = displayProfile
  if displayProfile ~= operation.target then
    profileCancelOperationQueue(operation)
    profileOperationFailed(wgt,
      "FC REMAINS ON PROFILE " .. tostring(displayProfile), token)
    return
  end

  operation.verified = true
  operation.stage = "save"
  operation.stageStartedAt = profileNow()
  profileSetMessage(wgt,
    "SAVING PROFILE " .. tostring(displayProfile) .. " TO FC...", C_YELLOW)
end

local function profileSelectionSaved(wgt, displayProfile, token)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token
     or operation.kind ~= "select" or not operation.verified
     or operation.target ~= displayProfile then return end
  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  wgt.profileActive = displayProfile
  PROFILE_CONFIRMED.value = displayProfile
  PROFILE_CONFIRMED.tick = profileNow()
  F.battProfile = displayProfile
  -- MSP 130 is a compact capacity read queued only after the verified EEPROM
  -- commit has drained from RF Tool's shared queue.
  wgt.profileActiveCapacityRequested = displayProfile
  profileSetMessage(wgt,
    "PROFILE " .. tostring(displayProfile) .. " SAVED TO FC", C_GREEN)
  local capacity = wgt.profileCapacities
                   and wgt.profileCapacities[displayProfile] or nil
  local capacityText = capacity == nil and "PERSISTS AFTER FC REBOOT"
                       or (capacity > 0 and (tostring(capacity) .. " mAh")
                           or "CAPACITY NOT SET")
  profileSetNotice(wgt,
    "PROFILE " .. tostring(displayProfile) .. " SAVED",
    capacityText, C_GREEN, PROFILE_SELECTION_NOTICE, true)
end

local function profileReadByte(buf, index)
  local value = type(buf) == "table" and tonumber(buf[index]) or nil
  if not value or value ~= math.floor(value) or value < 0 or value > 255 then
    return nil
  end
  return value
end

local function profileReadU16(buf, index)
  local low = profileReadByte(buf, index)
  local high = profileReadByte(buf, index + 1)
  if low == nil or high == nil then return nil end
  return low + high * 256
end

local function profileActiveCapacityReceived(wgt, buf, token)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token
     or operation.kind ~= "activeCapacity" then return end
  local capacity = profileReadU16(buf, 3)
  local replyProfile = profileReadByte(buf, 12)
  local displayProfile = replyProfile and (replyProfile + 1)
                         or tonumber(operation.target)
  if not capacity or capacity > BATTERY_CAPACITY_MAX
     or not displayProfile or displayProfile < 1
     or displayProfile > BATTERY_PROFILE_COUNT then
    profileOperationFailed(wgt, "ACTIVE CAPACITY NOT RECEIVED", token)
    return
  end
  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  wgt.profileActive = displayProfile
  wgt.profileCapacities = wgt.profileCapacities or {}
  wgt.profileCapacities[displayProfile] = capacity
  wgt.profileCapacitiesReady = true
  wgt.profileCapacitiesComplete = false
  local capacityText = capacity > 0 and (tostring(capacity) .. " mAh")
                       or "CAPACITY NOT SET"
  profileSetMessage(wgt,
    "PROFILE " .. tostring(displayProfile) .. ": " .. capacityText, C_GREEN)
  profileRefreshSelectionNotice(wgt,
    "PROFILE " .. tostring(displayProfile) .. " SELECTED",
    capacityText, C_GREEN)
end

local function profileDecodeCapacityConfig(wgt, config)
  local source = type(config) == "table" and config.batteryCapacity or nil
  local capacities = {}
  local allProfiles = type(source) == "table"
  for i = 1, BATTERY_PROFILE_COUNT do
    local entry = allProfiles and source[i - 1] or nil
    local capacity = type(entry) == "table" and tonumber(entry.value)
                     or tonumber(entry)
    if not capacity or capacity ~= math.floor(capacity)
       or capacity < 0 or capacity > BATTERY_CAPACITY_MAX then
      allProfiles = false
      break
    end
    capacities[i] = capacity
  end
  if not allProfiles then
    capacities = {}
    local activeCapacity = type(source) == "table"
                           and tonumber(source.value) or nil
    local activeProfile = tonumber(wgt.profileActive)
    if activeCapacity == nil or activeCapacity ~= math.floor(activeCapacity)
       or activeCapacity < 0 or activeCapacity > BATTERY_CAPACITY_MAX then
      return nil, false
    end
    if activeProfile and activeProfile >= 1
       and activeProfile <= BATTERY_PROFILE_COUNT then
      capacities[activeProfile] = activeCapacity
    end
  end
  return capacities, allProfiles
end

local function profileDecodeCapacityRaw(wgt, buf)
  local capacities = {}
  local allProfiles = true
  for i = 1, BATTERY_PROFILE_COUNT do
    local capacity = profileReadU16(buf, 16 + (i - 1) * 2)
    if capacity == nil or capacity > BATTERY_CAPACITY_MAX then
      allProfiles = false
      break
    end
    capacities[i] = capacity
  end
  if not allProfiles then
    capacities = {}
    local activeCapacity = profileReadU16(buf, 1)
    local activeProfile = tonumber(wgt.profileActive)
    if activeCapacity == nil or activeCapacity > BATTERY_CAPACITY_MAX then
      return nil, false
    end
    if activeProfile and activeProfile >= 1
       and activeProfile <= BATTERY_PROFILE_COUNT then
      capacities[activeProfile] = activeCapacity
    end
  end
  return capacities, allProfiles
end

local function profileQueueIdle(queue)
  if type(queue.isProcessed) ~= "function" then return true end
  local ok, idle = pcall(queue.isProcessed, queue)
  return ok and idle == true
end

local function profileQueueMessageSet(queue)
  local messages = {}
  if type(queue) ~= "table" then return messages end
  if queue.currentMessage then messages[queue.currentMessage] = true end
  for _, message in pairs(queue.messageQueue or {}) do
    if message then messages[message] = true end
  end
  return messages
end

local function profileCallApiAndCollect(queue, operation, callback)
  local before = profileQueueMessageSet(queue)
  local ok = pcall(callback)
  local added = 0
  local after = profileQueueMessageSet(queue)
  for message in pairs(after) do
    if not before[message] then
      operation.messages[#operation.messages + 1] = message
      added = added + 1
    end
  end
  return ok, added > 0 or type(queue.messageQueue) ~= "table"
end

local function profileInstallErrorHandler(messages, failed)
  for _, message in ipairs(messages or {}) do
    if type(message) == "table" then message.errorHandler = failed end
  end
end

-- RotorFlight arming blockers ----------------------------------------------
-- MSP 101 is read-only. ARM_SWITCH is the normal reason while the arm switch
-- is off, so the banner reports only the actionable blockers beside it.
local ARMING_DISABLE_NAMES = {
  [0]="NO GYRO", [1]="FAILSAFE", [2]="RX FAILSAFE",
  [3]="RX RECOVERY", [4]="FAILSAFE MODE", [5]="GOVERNOR",
  [6]="RPM SIGNAL", [7]="THROTTLE", [8]="ANGLE",
  [9]="BOOT GRACE", [10]="PREARM", [11]="CPU LOAD",
  [12]="CALIBRATING", [13]="CLI", [14]="CMS MENU", [15]="BST",
  [16]="MSP", [17]="PARALYZE", [18]="GPS", [19]="RESCUE",
  [20]="RPM FILTER", [21]="REBOOT REQUIRED", [22]="DSHOT",
  [23]="ACC CAL", [24]="MOTOR PROTOCOL",
}
local ARMING_STATUS_INTERVAL = 100
local ARMING_STATUS_TIMEOUT = 200
local ARMING_STATUS_STALE = 500
local ARMING_DISABLED_CALIBRATING = 4096
local ARMING_DISABLED_ARM_SWITCH = 67108864

local function armingBannerText(flags)
  local value = tonumber(flags)
  if not value then return nil end
  -- gyro_cal_on_first_arm reports CALIBRATING without ARM_SWITCH while idle.
  -- A real block during an arm attempt carries both flags.
  if bit32.band(value, ARMING_DISABLED_CALIBRATING) ~= 0
     and bit32.band(value, ARMING_DISABLED_ARM_SWITCH) == 0 then
    value = value - ARMING_DISABLED_CALIBRATING
  end
  local reasons = {}
  for index = 0, 24 do
    if bit32.band(value, bit32.lshift(1, index)) ~= 0 then
      reasons[#reasons + 1] = ARMING_DISABLE_NAMES[index]
    end
  end
  if #reasons == 0 then return nil end
  local shown = math.min(2, #reasons)
  local text = reasons[1]
  if shown == 2 then text = text .. ", " .. reasons[2] end
  if #reasons > shown then
    text = text .. " +" .. tostring(#reasons - shown)
  end
  return "ARMING BLOCKED: " .. text
end

local function profileShowArmingBanner(wgt)
  local banner = V.armingBanner
  if not banner then return end
  local visible = type(wgt.armingBlockerText) == "string"
                  and wgt.armingBlockerText ~= ""
  if visible then
    setLabel(banner.label, wgt.armingBlockerText, C_TEXT)
  end
  for _, object in ipairs(banner.objects) do setVisible(object, visible) end
end

local function profileFailArmingStatus(wgt, token)
  local operation = wgt and wgt.armingStatusOperation or nil
  if not operation or operation.token ~= token then return end
  profileCancelOperationQueue(operation)
  wgt.armingStatusOperation = nil
  wgt.armingStatusPending = false
  wgt.armingStatusNextAt = profileNow() + ARMING_STATUS_INTERVAL * 2
end

local function profileFinishArmingStatus(wgt, status, token)
  local operation = wgt and wgt.armingStatusOperation or nil
  if not operation or operation.token ~= token then return end
  wgt.armingStatusOperation = nil
  wgt.armingStatusPending = false
  if OPT.heliType == HELI_OMPHOBBY then
    wgt.armingStatusNextAt = nil
    wgt.armingDisableFlags = nil
    wgt.armingBlockerText = nil
    wgt.armingStatusUpdatedAt = nil
    return
  end
  wgt.armingStatusNextAt = profileNow() + ARMING_STATUS_INTERVAL
  wgt.armingDisableFlags = type(status) == "table"
                           and tonumber(status.armingDisableFlags) or nil
  wgt.armingBlockerText = armingBannerText(wgt.armingDisableFlags)
  wgt.armingStatusUpdatedAt = profileNow()
end

local function profileBeginArmingStatus(wgt)
  if OPT.heliType == HELI_OMPHOBBY then return false end
  if wgt.armingStatusPending or wgt.profileBusy then return false end
  local queue = profileSharedQueue()
  if not queue or not profileQueueIdle(queue) then return false end
  local api = profileRfApi("mspStatus")
  if not api or type(api.getStatus) ~= "function" then return false end

  wgt.armingStatusToken = (wgt.armingStatusToken or 0) + 1
  local token = wgt.armingStatusToken
  local operation = {
    token=token, kind="armingStatus", startedAt=profileNow(),
    queue=queue, messages={},
  }
  wgt.armingStatusOperation = operation
  wgt.armingStatusPending = true
  local ok, added = profileCallApiAndCollect(queue, operation, function()
    api.getStatus(function(_, status)
      profileFinishArmingStatus(wgt, status, token)
    end, wgt)
  end)
  local decorated = false
  if ok and added then
    for _, message in ipairs(operation.messages) do
      if type(message) == "table" and message.command == 101 then
        decorated = true
        message.retryDelay = 86400
        message.errorHandler = function()
          profileFailArmingStatus(wgt, token)
        end
      end
    end
  end
  if not ok or not added or not decorated then
    profileFailArmingStatus(wgt, token)
    return false
  end
  return true
end

local function profileServiceArmingStatus(wgt, connected, now, allowUi)
  if OPT.heliType == HELI_OMPHOBBY or not connected then
    if wgt.armingStatusOperation then
      profileCancelOperationQueue(wgt.armingStatusOperation)
    end
    wgt.armingStatusOperation = nil
    wgt.armingStatusPending = false
    wgt.armingStatusNextAt = nil
    wgt.armingDisableFlags = nil
    wgt.armingBlockerText = nil
    wgt.armingStatusUpdatedAt = nil
    if allowUi then profileShowArmingBanner(wgt) end
    return
  end
  local operation = wgt.armingStatusOperation
  if operation and now - operation.startedAt >= ARMING_STATUS_TIMEOUT then
    profileFailArmingStatus(wgt, operation.token)
  end
  if wgt.armingStatusUpdatedAt
     and now - wgt.armingStatusUpdatedAt >= ARMING_STATUS_STALE then
    wgt.armingStatusUpdatedAt = nil
    wgt.armingDisableFlags = nil
    wgt.armingBlockerText = nil
  end
  if allowUi then profileShowArmingBanner(wgt) end
  local flightStatsDue = OPT.flightCounter == FC.ROTORFLIGHT
                         and FC.wanted and not FC.pending
                         and FC.stableSince ~= nil
                         and now - FC.stableSince >= FC.disarmStableTicks
  if not wgt.armingStatusPending
     and now >= (wgt.armingStatusNextAt or now)
     and not wgt.profileBusy and not flightStatsDue then
    profileBeginArmingStatus(wgt)
  end
end

local function profileYieldArmingStatusToFlightStats(wgt, now)
  local operation = wgt and wgt.armingStatusOperation or nil
  if not operation then return true end
  -- Cancel only if the queue contains this widget's MSP 101 and no message
  -- owned by another RF Tool consumer.
  if not profileCancelOperationQueue(operation) then return false end
  wgt.armingStatusOperation = nil
  wgt.armingStatusPending = false
  wgt.armingStatusNextAt = now + ARMING_STATUS_INTERVAL
  return true
end

-- RotorFlight persistent flight counter ------------------------------------
-- Each MSP 14 message is a single bounded send. After a real arm/disarm, up
-- to six fresh reads allow the FC's persistent total time to settle.
local function profileFlightCounterSelected()
  return OPT.flightCounter == FC.ROTORFLIGHT
end

local function profileClearFlightStatsRefresh()
  FC.refreshBase = nil
  FC.refreshAttempts = 0
end

local function profileRequestFlightStatsRefresh(now, afterFlight)
  FC.wanted = true
  FC.stableSince = now
  if afterFlight and FC.count ~= nil then
    FC.refreshBase = FC.count
    FC.refreshAttempts = 0
    FC.stale = true
  end
end

local function profileFinishFlightStats(wgt, stats, token)
  local operation = wgt and wgt.profileOperation or nil
  if not operation or operation.kind ~= "flightStats"
     or operation.token ~= token then return end
  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  FC.pending = false
  if not profileFlightCounterSelected()
     or operation.model ~= flightModel then return end
  if type(stats) ~= "table" or type(stats.statsEnabled) ~= "table"
     or tonumber(stats.statsEnabled.value) ~= 1 then
    FC.count, FC.stale, FC.status = nil, false, "STATS OFF"
    profileClearFlightStatsRefresh()
    return
  end
  local count = type(stats.stats_total_flights) == "table"
                and tonumber(stats.stats_total_flights.value) or nil
  if not count or count < 0 or count ~= math.floor(count) then
    FC.count, FC.stale, FC.status = nil, false, "BAD REPLY"
    profileClearFlightStatsRefresh()
    return
  end
  if operation.refreshBase ~= nil
     and count == operation.refreshBase
     and operation.refreshAttempt < FC.confirmMaxReads then
    FC.stale, FC.status = true, "CONFIRMING"
    FC.wanted = true
    FC.stableSince = profileNow()
    return
  end
  FC.count, FC.stale, FC.status = count, false, "AVAILABLE"
  profileClearFlightStatsRefresh()
end

local function profileFailFlightStats(wgt, token, status)
  local operation = wgt and wgt.profileOperation or nil
  if not operation or operation.kind ~= "flightStats"
     or (token and operation.token ~= token) then return end
  profileCancelOperationQueue(operation)
  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  FC.pending = false
  FC.stale = FC.count ~= nil
  FC.status = status or "NO REPLY"
  local retryable = status == "NO REPLY" or status == "QUEUE ERROR"
                    or status == "REQUEST ERROR"
  if retryable and profileFlightCounterSelected()
     and operation.model == flightModel
     and operation.refreshBase ~= nil
     and operation.refreshAttempt < FC.confirmMaxReads then
    FC.wanted = true
    FC.stableSince = profileNow()
    FC.status = "RETRYING"
  end
end

local function profileBeginFlightStats(wgt)
  if wgt.profileBusy then return false end
  local queue = profileSharedQueue()
  if not queue or not profileQueueIdle(queue) then return false end
  local api = profileRfApi("mspFlightStats")
  if not api or type(api.read) ~= "function" then
    FC.status = "NO API"
    return false
  end

  wgt.profileOperationToken = (wgt.profileOperationToken or 0) + 1
  local token = wgt.profileOperationToken
  local refreshAttempt = 0
  if FC.refreshBase ~= nil then
    FC.refreshAttempts = FC.refreshAttempts + 1
    refreshAttempt = FC.refreshAttempts
  end
  local operation = {
    token=token, kind="flightStats", startedAt=profileNow(),
    queue=queue, messages={}, model=flightModel,
    refreshBase=FC.refreshBase, refreshAttempt=refreshAttempt,
  }
  wgt.profileOperation = operation
  wgt.profileBusy = true
  FC.pending, FC.wanted, FC.status = true, false, "LOADING"

  local apiOk, messageAdded = profileCallApiAndCollect(
    queue, operation,
    function()
      api.read(function(_, stats)
        profileFinishFlightStats(wgt, stats, token)
      end, wgt)
    end)
  local decorated = false
  if apiOk and messageAdded then
    for _, message in ipairs(operation.messages) do
      if type(message) == "table" and message.command == 14 then
        decorated = true
        message.retryDelay = 86400
        message.errorHandler = function()
          profileFailFlightStats(wgt, token, "NO REPLY")
        end
      end
    end
  end
  if not apiOk or not messageAdded or not decorated then
    profileFailFlightStats(wgt, token, "REQUEST ERROR")
    return false
  end
  return true
end

local function profileFinishSnapshotIfReady(wgt, token)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token
     or operation.kind ~= "snapshot"
     or not operation.activeDone or not operation.capacityDone then return end
  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  wgt.profileInitialReadFinished = true
  wgt.profileCapacityReadFinished = true
  if wgt.profileCapacitiesReady then
    local summary = {}
    for i = 1, BATTERY_PROFILE_COUNT do
      local capacity = wgt.profileCapacities
                       and tonumber(wgt.profileCapacities[i]) or nil
      summary[i] = capacity and tostring(math.floor(capacity)) or "-"
    end
    profileSetMessage(wgt, "mAh  " .. table.concat(summary, " / "), C_DIM)
  elseif wgt.profileInitialReadValid and wgt.profileActive then
    local length = tonumber(wgt.profileCapacityReplyLength)
    profileSetMessage(wgt,
      length and ("MSP 32: " .. tostring(length) .. " BYTES, NO mAh")
        or "MSP 32 mAh NOT RECEIVED", C_YELLOW)
  else
    profileSetMessage(wgt, "PROFILE DATA UNAVAILABLE", C_DIM)
  end
end

local function profileSnapshotActiveReceived(wgt, zeroBased, token)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token
     or operation.kind ~= "snapshot" then return end
  local index = tonumber(zeroBased)
  if index and index == math.floor(index)
     and index >= 0 and index < BATTERY_PROFILE_COUNT then
    wgt.profileActive = index + 1
    wgt.profileInitialReadValid = true
    F.battProfile = index + 1
  else
    wgt.profileInitialReadValid = false
  end
  operation.activeDone = true
  operation.capacityStartedAt = profileNow()
  if wgt.profileInitialReadValid and wgt.profileActive then
    profileSetMessage(wgt,
      "PROFILE " .. tostring(wgt.profileActive) .. " ACTIVE - READING mAh...",
      C_YELLOW)
  end
  profileFinishSnapshotIfReady(wgt, token)
end

local function profileSnapshotCapacitiesReceived(wgt, value, token, raw)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token
     or operation.kind ~= "snapshot" then return end
  local capacities, allProfiles
  if raw then
    wgt.profileCapacityReplyLength = type(value) == "table" and #value or 0
    capacities, allProfiles = profileDecodeCapacityRaw(wgt, value)
  else
    capacities, allProfiles = profileDecodeCapacityConfig(wgt, value)
  end
  if capacities then
    wgt.profileCapacities = capacities
    wgt.profileCapacitiesReady = true
    wgt.profileCapacitiesComplete = allProfiles
  else
    wgt.profileCapacities = nil
    wgt.profileCapacitiesReady = false
    wgt.profileCapacitiesComplete = false
  end
  operation.capacityDone = true
  profileFinishSnapshotIfReady(wgt, token)
end

local function profileBeginSnapshot(wgt)
  if wgt.profileBusy then return false end
  local queue = profileSharedQueue()
  if not queue then
    profileSetMessage(wgt, "RF TOOL 2.3 REQUIRED", C_RED)
    return false
  end
  if not profileQueueIdle(queue) then
    profileSetMessage(wgt, "WAITING FOR RF TOOL QUEUE...", C_YELLOW)
    return false
  end
  wgt.profileOperationToken = (wgt.profileOperationToken or 0) + 1
  local token = wgt.profileOperationToken
  local operation = {
    token=token, kind="snapshot", startedAt=profileNow(),
    queue=queue, messages={}, activeDone=false, capacityDone=false,
  }
  wgt.profileOperation = operation
  wgt.profileBusy = true
  wgt.profileInitialReadRequested = true
  wgt.profileCapacityReadRequested = true
  profileSetMessage(wgt, "READING BATTERY PROFILE DATA...", C_YELLOW)

  local function failed()
    profileCancelOperationQueue(operation)
    profileOperationFailed(wgt, "PROFILE DATA NOT RECEIVED", token)
  end
  local function activeRaw(_, buf)
    profileSnapshotActiveReceived(wgt,
      type(buf) == "table" and buf[1] or nil, token)
  end
  local function capacitiesRaw(_, buf)
    profileSnapshotCapacitiesReceived(wgt, buf, token, true)
  end
  local function activeConfig(_, config)
    local value = type(config) == "table"
                  and type(config.batteryProfile) == "table"
                  and config.batteryProfile.value or nil
    profileSnapshotActiveReceived(wgt, value, token)
  end
  local function capacitiesConfig(_, config)
    profileSnapshotCapacitiesReceived(wgt, config, token, false)
  end

  local activeApi = profileRfApi("mspBatteryProfile")
  local capacityApi = profileRfApi("mspBatteryConfig")
  if activeApi and type(activeApi.read) == "function"
     and capacityApi and type(capacityApi.read) == "function" then
    local activeOk, activeAdded = profileCallApiAndCollect(
      queue, operation, function() activeApi.read(activeConfig, wgt) end)
    local capacityOk, capacityAdded = false, false
    if activeOk and activeAdded then
      capacityOk, capacityAdded = profileCallApiAndCollect(
        queue, operation, function() capacityApi.read(capacitiesConfig, wgt) end)
    end
    if activeOk and activeAdded and capacityOk and capacityAdded then
      for _, message in ipairs(operation.messages) do
        if message.command == MSP_BATTERY_CONFIG then
          message.processReply = capacitiesRaw
          message.retryDelay = 4
        end
      end
      profileInstallErrorHandler(operation.messages, failed)
      return true
    end
    profileCancelOperationQueue(operation)
    operation.messages = {}
  end

  local activeMessage = {
    command=MSP_BATTERY_PROFILE,
    processReply=activeRaw,
  }
  local capacityMessage = {
    command=MSP_BATTERY_CONFIG,
    processReply=capacitiesRaw,
    retryDelay=4,
  }
  operation.messages[#operation.messages + 1] = activeMessage
  operation.messages[#operation.messages + 1] = capacityMessage
  queue:add(activeMessage)
  queue:add(capacityMessage)
  profileInstallErrorHandler(operation.messages, failed)
  return true
end

local function profileBeginOperation(wgt, kind, target)
  if wgt.profileBusy then return false end
  local queue = profileSharedQueue()
  if not queue then
    profileSetMessage(wgt, "RF TOOL 2.3 REQUIRED", C_RED)
    return false
  end
  if not profileQueueIdle(queue) then
    profileSetMessage(wgt, "WAITING FOR RF TOOL QUEUE...", C_YELLOW)
    return false
  end
  wgt.profileOperationToken = (wgt.profileOperationToken or 0) + 1
  local token = wgt.profileOperationToken
  local operation = {
    token=token, kind=kind, target=target, startedAt=profileNow(),
    queue=queue, messages={}, stage=kind == "select" and "set" or nil,
  }
  wgt.profileOperation = operation
  wgt.profileBusy = true
  wgt.profilePending = kind == "select" and target or nil
  profileSetMessage(wgt,
    kind == "select" and ("SETTING PROFILE " .. tostring(target) .. "...")
      or ("READING PROFILE " .. tostring(target) .. " mAh..."), C_YELLOW)
  local function failed()
    profileCancelOperationQueue(operation)
    profileOperationFailed(wgt,
      kind == "select"
        and (operation.stage == "save"
             and "PROFILE ACTIVE BUT SAVE FAILED"
             or "PROFILE CHANGE NOT CONFIRMED")
       or "ACTIVE CAPACITY NOT RECEIVED", token)
  end

  if kind == "activeCapacity" then
    local message = {
      command=MSP_BATTERY_STATE,
      processReply=function(_, buf)
        profileActiveCapacityReceived(wgt, buf, token)
      end,
      errorHandler=failed,
    }
    operation.messages[#operation.messages + 1] = message
    queue:add(message)
    return true
  end

  -- A profile change is not complete until the FC acknowledges the runtime
  -- selection, MSP 175 reads the same profile back, and MSP 250 commits it to
  -- EEPROM. All three messages stay on RF Tool's one shared MSP queue.
  local setMessage = {
    command=MSP_SET_BATTERY_PROFILE,
    payload={ target - 1 },
    processReply=function()
      local current = wgt.profileOperation
      if not current or current.token ~= token then return end
      current.stage = "verify"
      current.stageStartedAt = profileNow()
      profileSetMessage(wgt,
        "VERIFYING PROFILE " .. tostring(target) .. "...", C_YELLOW)
    end,
    errorHandler=failed,
  }
  local verifyMessage = {
    command=MSP_BATTERY_PROFILE,
    processReply=function(_, buf)
      profileSelectionVerified(wgt,
        type(buf) == "table" and buf[1] or nil, token)
    end,
    errorHandler=failed,
  }
  local saveMessage = {
    command=MSP_EEPROM_WRITE,
    processReply=function()
      profileSelectionSaved(wgt, target, token)
    end,
    errorHandler=failed,
  }
  operation.messages[#operation.messages + 1] = setMessage
  operation.messages[#operation.messages + 1] = verifyMessage
  operation.messages[#operation.messages + 1] = saveMessage
  queue:add(setMessage)
  queue:add(verifyMessage)
  queue:add(saveMessage)
  return true
end

local function profileCheckOperationTimeout(wgt, now)
  local operation = wgt.profileOperation
  if not operation then return end
  local timeout, startedAt
  startedAt = operation.startedAt
  if operation.kind == "snapshot" then
    if operation.activeDone then
      timeout = PROFILE_SNAPSHOT_CAPACITY_TIMEOUT
      startedAt = operation.capacityStartedAt or startedAt
    else
      timeout = PROFILE_SNAPSHOT_ACTIVE_TIMEOUT
    end
  elseif operation.kind == "activeCapacity" then
    timeout = PROFILE_ACTIVE_CAPACITY_TIMEOUT
  elseif operation.kind == "select" then
    timeout = PROFILE_SELECT_TIMEOUT
    startedAt = operation.stageStartedAt or startedAt
  elseif operation.kind == "flightStats" then
    timeout = PROFILE_FLIGHT_STATS_TIMEOUT
  else
    timeout = PROFILE_READ_TIMEOUT
  end
  if now - startedAt < timeout and not wgt.profileQueueFault then return end
  if operation.kind == "flightStats" then
    profileFailFlightStats(wgt, operation.token,
      wgt.profileQueueFault and "QUEUE ERROR" or "NO REPLY")
    wgt.profileQueueFault = nil
    return
  end
  profileCancelOperationQueue(operation)
  local message = wgt.profileQueueFault and "RF TOOL QUEUE ERROR"
                  or (operation.kind == "snapshot"
                      and "PROFILE DATA NOT RECEIVED"
                      or (operation.kind == "activeCapacity"
                          and "ACTIVE CAPACITY NOT RECEIVED"
                          or (operation.kind == "select"
                              and (operation.stage == "save"
                                   and "PROFILE ACTIVE BUT SAVE TIMED OUT"
                                   or "PROFILE CHANGE NOT CONFIRMED")
                              or "PROFILE REQUEST TIMED OUT")))
  wgt.profileQueueFault = nil
  profileOperationFailed(wgt, message, operation.token)
end

local function profileCapacityInProgress(wgt)
  local operation = wgt and wgt.profileOperation or nil
  return wgt and wgt.profileBusy and operation
         and operation.kind == "activeCapacity"
end

local function profileStopCapacityRead(wgt)
  if not profileCapacityInProgress(wgt) then return true end
  local operation = wgt.profileOperation
  if not profileCancelOperationQueue(operation) then return false end
  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  profileSetMessage(wgt, "CAPACITY READ SKIPPED", C_DIM)
  return true
end

local function profileSwitchUnsafe(wgt)
  if wgt and wgt.profileRfState == "armed" then
    return true, "DISARM TO CHANGE PROFILE"
  end
  local armRaw, armCurrent = get("ARM")
  local arm = tonumber(armRaw)
  -- Explicit unsafe telemetry blocks the change; a missing sensor does not
  -- create a permanent lock.
  if armCurrent == true and arm ~= nil and math.floor(arm) % 2 == 1 then
    return true, "DISARM TO CHANGE PROFILE"
  end
  local governorMode = getGovernorMode()
  if governorMode ~= nil and GOV_RUNNING_STATE[governorMode] then
    return true, "STOP GOVERNOR TO CHANGE PROFILE"
  end
  local headspeed = getHeadspeed()
  if D.rpmValid and headspeed >= 1 then
    return true, "STOP ROTOR TO CHANGE PROFILE"
  end
  return false, nil
end

local closeBatteryProfileMenu
local showBatteryProfileMenu

local function profileCapacityText(wgt, profileIndex)
  if not wgt.profileCapacitiesReady then
    if wgt.profileCapacityReadRequested
       and not wgt.profileCapacityReadFinished then return "READING..." end
    return ""
  end
  local capacity = wgt.profileCapacities
                   and tonumber(wgt.profileCapacities[profileIndex]) or nil
  if capacity == nil then return "" end
  if capacity <= 0 then return "NOT SET" end
  return tostring(math.floor(capacity)) .. " mAh"
end

local function profileButtonText(wgt, profileIndex, multiline)
  local capacity = profileCapacityText(wgt, profileIndex)
  local text = "P" .. tostring(profileIndex)
  local active = wgt.profileActive == profileIndex
  if multiline and capacity ~= "" then
    if active then text = text .. "  ACTIVE" end
    text = text .. "\n" .. capacity
  else
    if capacity ~= "" then text = text .. "  " .. capacity end
    if active then text = text .. "  ACTIVE" end
  end
  return text
end

local function showNativeBatteryProfileMenu(wgt)
  if not lvgl or type(lvgl.menu) ~= "function" then return false end
  local title = "BATTERY PROFILES"
  if wgt.profileActive then
    title = title .. " - P" .. tostring(wgt.profileActive) .. " ACTIVE"
  end
  local unsafe, unsafeMessage = profileSwitchUnsafe(wgt)
  local profileIndexes = {}
  local values = {}
  for i = 1, BATTERY_PROFILE_COUNT do
    local capacity = wgt.profileCapacities
                     and tonumber(wgt.profileCapacities[i]) or nil
    if capacity and capacity > 0 then
      profileIndexes[#profileIndexes + 1] = i
      values[#values + 1] = profileButtonText(wgt, i, false)
    end
  end
  if #profileIndexes == 0 then
    values[#values + 1] = "NO CONFIGURED PROFILES"
  end
  local safetyIndex
  if unsafe then
    safetyIndex = #values + 1
    values[safetyIndex] = "LOCKED: " .. tostring(unsafeMessage)
  end
  values[#values + 1] = "CLOSE"
  local ok = pcall(lvgl.menu, {
    title=title,
    values=values,
    get=function()
      for valueIndex, profileIndex in ipairs(profileIndexes) do
        if wgt.profileActive == profileIndex then return valueIndex end
      end
      return 0
    end,
    set=function(selected)
      local valueIndex = tonumber(selected)
      wgt.profileAutoShown = true
      if safetyIndex and valueIndex == safetyIndex then
        profileSetNotice(wgt, "PROFILE CHANGE LOCKED",
                         unsafeMessage, C_RED, 500)
        return
      end
      local profileIndex = valueIndex and profileIndexes[valueIndex] or nil
      if not profileIndex then return end
      local ready = profileTransport() ~= nil
                    and (wgt.profileRfState == "connected"
                         or wgt.profileRfState == "armed"
                         or wgt.profileRfState == "disarmed")
      if not ready or (wgt.profileBusy
                       and not profileCapacityInProgress(wgt)) then
        profileSetNotice(wgt, "BATTERY PROFILE ERROR",
                         profileRfToolStatus(wgt), C_RED, 500)
        return
      end
      if wgt.profileActive == profileIndex then
        profileSetNotice(wgt,
          "PROFILE " .. tostring(profileIndex) .. " IS ACTIVE",
          profileCapacityText(wgt, profileIndex) ~= ""
            and profileCapacityText(wgt, profileIndex) or "CURRENTLY ACTIVE",
          C_GREEN, PROFILE_SELECTION_NOTICE, true)
        return
      end
      local blocked, blockedMessage = profileSwitchUnsafe(wgt)
      if blocked then
        profileSetMessage(wgt, blockedMessage, C_RED)
        profileSetNotice(wgt, "PROFILE CHANGE LOCKED",
                         blockedMessage, C_RED, 500)
        return
      end
      wgt.profileSelectionRequested = profileIndex
      profileSetMessage(wgt,
        "SETTING PROFILE " .. tostring(profileIndex) .. "...", C_YELLOW)
    end,
  })
  if not ok then
    profileSetNotice(wgt, "BATTERY PROFILE ERROR",
                     "NATIVE MENU FAILED", C_RED, 500)
  end
  return ok
end

closeBatteryProfileMenu = function(wgt)
  local dialog = wgt and wgt.profileDialog or nil
  if wgt then wgt.profileDialog = nil end
  if dialog and type(dialog.close) == "function" then
    pcall(dialog.close, dialog)
  end
end

showBatteryProfileMenu = function(wgt)
  if wgt.profileDialog then return true end
  if G.w < 430 or G.h < 300
     or not lvgl or type(lvgl.dialog) ~= "function" then
    return showNativeBatteryProfileMenu(wgt)
  end
  local title = "KSE4 BATTERY PROFILES"
  if wgt.profileActive then
    title = title .. " - P" .. tostring(wgt.profileActive) .. " ACTIVE"
  end
  local dialogOk, dialog = pcall(lvgl.dialog, {
    title=title, w=400, h=285,
    close=function() wgt.profileDialog = nil end,
  })
  if not dialogOk or type(dialog) ~= "table"
     or type(dialog.build) ~= "function" then
    return showNativeBatteryProfileMenu(wgt)
  end
  wgt.profileDialog = dialog
  local profileIndexes = {}
  for i = 1, BATTERY_PROFILE_COUNT do
    local capacity = wgt.profileCapacities
                     and tonumber(wgt.profileCapacities[i]) or nil
    if capacity and capacity > 0 then
      profileIndexes[#profileIndexes + 1] = i
    end
  end
  local children = {}
  for buttonIndex, profileIndex in ipairs(profileIndexes) do
    local col = (buttonIndex - 1) % 2
    local row = math.floor((buttonIndex - 1) / 2)
    children[#children + 1] = {
      type="button", x=18 + col * 190, y=22 + row * 52,
      w=174, h=46, font=SMLSIZE, cornerRadius=6,
      color=function()
        if wgt.profileActive == profileIndex then return C_GREEN end
        if wgt.profilePending == profileIndex then return C_YELLOW end
        return C_TILE
      end,
      textColor=C_TEXT,
      text=profileButtonText(wgt, profileIndex, true),
      active=function()
        local unsafe = profileSwitchUnsafe(wgt)
        return profileTransport() ~= nil and not unsafe
               and (not wgt.profileBusy or profileCapacityInProgress(wgt))
               and wgt.profileActive ~= profileIndex
      end,
      press=function()
        if (wgt.profileBusy and not profileCapacityInProgress(wgt))
           or wgt.profileActive == profileIndex then return end
        local blocked, blockedMessage = profileSwitchUnsafe(wgt)
        if blocked then
          profileSetNotice(wgt, "PROFILE CHANGE LOCKED",
                           blockedMessage, C_RED, 500)
          return
        end
        wgt.profileSelectionRequested = profileIndex
        wgt.profileAutoShown = true
        profileSetMessage(wgt,
          "SETTING PROFILE " .. tostring(profileIndex) .. "...", C_YELLOW)
        closeBatteryProfileMenu(wgt)
      end,
    }
  end
  children[#children + 1] = {
    type="label", x=18, y=181, w=364, h=22,
    font=SMLSIZE,
    color=(function()
      local unsafe = profileSwitchUnsafe(wgt)
      return unsafe and C_RED or (wgt.profileMessageColor or C_DIM)
    end)(),
    align=CENTERED,
    text=(function()
      local unsafe, unsafeMessage = profileSwitchUnsafe(wgt)
      if unsafe then return unsafeMessage end
      if #profileIndexes == 0 then return "NO CONFIGURED PROFILES" end
      return wgt.profileMessage or "SELECT A PROFILE"
    end)(),
  }
  children[#children + 1] = {
    type="button", x=18, y=213, w=174, h=40,
    text="TRY mAh", color=C_TILE, textColor=C_TEXT,
    font=SMLSIZE, cornerRadius=6,
    active=function() return not wgt.profileBusy end,
    press=function()
      if wgt.profileBusy then return end
      wgt.profileCapacityRefreshRequested = true
      wgt.profileAutoShown = false
      closeBatteryProfileMenu(wgt)
    end,
  }
  children[#children + 1] = {
    type="button", x=208, y=213, w=174, h=40,
    text="CLOSE", color=C_TILE, textColor=C_TEXT,
    font=SMLSIZE, cornerRadius=6,
    press=function()
      wgt.profileAutoShown = true
      closeBatteryProfileMenu(wgt)
    end,
  }
  local buildOk = pcall(dialog.build, dialog, children)
  if not buildOk then
    closeBatteryProfileMenu(wgt)
    return showNativeBatteryProfileMenu(wgt)
  end
  return true
end

local function profileRegisterWithRfTool(wgt)
  local shared = profileRfToolProvider()
  if wgt.profileRfProviderRef ~= shared then
    wgt.profileRfProviderRef = shared
    wgt.profileRfToolRegistered = false
    wgt.profileProviderChanged = true
  end
  if not shared then return end
  local toolApi = tonumber(shared.rfToolApiVersion)
  local canRegister = toolApi and toolApi >= RF_TOOL_WIDGET_API
                      and type(shared.registerWidget) == "function"
  if canRegister and not wgt.profileRfToolRegistered then
    wgt.onStateChanged = function(widget, newState)
      widget.profileRfState = newState
    end
    local ok = pcall(shared.registerWidget, wgt)
    wgt.profileRfToolRegistered = ok
  end
  local state
  if shared.widget and shared.widget.state then
    state = shared.widget.state
  elseif not canRegister and tonumber(shared.apiVersion)
         and tonumber(shared.apiVersion) >= ROTORFLIGHT_23_MSP_API
         and (profileRfToolInstanceLive() == shared
              or profileRadioLinkLive()) then
    state = "connected"
  end
  if state and state ~= wgt.profileRfState then wgt.profileRfState = state end
end

local function profileControllerConnected(wgt)
  local state = wgt.profileRfState
  return profileSharedQueue() ~= nil
         and (state == "connected" or state == "armed" or state == "disarmed")
end

local function profileOnlyConfigured(wgt)
  if not wgt.profileCapacitiesReady
     or not wgt.profileCapacitiesComplete
     or type(wgt.profileCapacities) ~= "table" then return nil end
  local onlyProfile
  for i = 1, BATTERY_PROFILE_COUNT do
    local capacity = tonumber(wgt.profileCapacities[i])
    if not capacity or capacity ~= math.floor(capacity)
       or capacity < 0 or capacity > BATTERY_CAPACITY_MAX then return nil end
    if capacity > 0 then
      if onlyProfile then return nil end
      onlyProfile = i
    end
  end
  return onlyProfile
end

local function profileResetConnection(wgt)
  if not wgt then return end
  if wgt.armingStatusOperation then
    profileCancelOperationQueue(wgt.armingStatusOperation)
  end
  if wgt.profileOperation
     and wgt.profileOperation.kind == "flightStats" then
    profileFailFlightStats(wgt, wgt.profileOperation.token, "DISCONNECTED")
  elseif wgt.profileOperation then
    profileCancelOperationQueue(wgt.profileOperation)
  end
  closeBatteryProfileMenu(wgt)
  profileSetEntryPrompt(false)
  wgt.profileWasConnected = false
  wgt.profileConnectedForDisplay = false
  G.profileConnectedForDisplay = false
  wgt.profileAutoShown = false
  wgt.profileSingleConfigured = nil
  wgt.profileInitialReadRequested = false
  wgt.profileInitialReadFinished = false
  wgt.profileInitialReadValid = false
  wgt.profileCapacityReadRequested = false
  wgt.profileCapacityReadFinished = false
  wgt.profileCapacitiesReady = false
  wgt.profileCapacitiesComplete = false
  wgt.profileCapacities = nil
  wgt.profileCapacityReplyLength = nil
  wgt.profileSelectionRequested = nil
  wgt.profileActiveCapacityRequested = nil
  wgt.profileCapacityRefreshRequested = nil
  wgt.profileConnectReadyAt = nil
  wgt.profileMenuRetryAt = nil
  wgt.profileDisconnectedSince = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  wgt.profileOperation = nil
  wgt.profileMessage = nil
  wgt.profileNoticeTitle = nil
  wgt.profileNoticeDetail = nil
  wgt.profileNoticeColor = nil
  wgt.profileNoticeCompact = nil
  wgt.profileNoticeUntil = nil
  wgt.profileActive = nil
  wgt.profileUnsafe = nil
  wgt.profileUnsafeMessage = nil
  wgt.profileTransportReady = nil
  wgt.profileQueueFault = nil
  wgt.armingStatusOperation = nil
  wgt.armingStatusPending = false
  wgt.armingStatusNextAt = nil
  wgt.armingDisableFlags = nil
  wgt.armingBlockerText = nil
  wgt.armingStatusUpdatedAt = nil
  PROFILE_CONFIRMED.value, PROFILE_CONFIRMED.tick = nil, nil
end

local function profileFlightCounterArmState(wgt)
  if wgt.profileRfState == "armed" then return true end
  if wgt.profileRfState == "disarmed" then return false end
  local value, current, _, known = get("ARM")
  value = tonumber(value)
  if current ~= true or known ~= true or value == nil then return nil end
  return math.floor(value) % 2 == 1
end

local function profileFlightCounterSourceChanged(wgt)
  if wgt and wgt.profileOperation
     and wgt.profileOperation.kind == "flightStats" then
    profileFailFlightStats(wgt, wgt.profileOperation.token, "SOURCE CHANGED")
  end
  FC.count, FC.stale, FC.pending = nil, false, false
  FC.stableSince, FC.state, FC.armState = nil, nil, nil
  FC.flightSeenArmed = false
  profileClearFlightStatsRefresh()
  FC.model = flightModel
  if profileFlightCounterSelected() then
    FC.status, FC.wanted = "STARTING", true
  else
    FC.status, FC.wanted = "RADIO", false
  end
end

local function profileServiceFlightCounter(wgt, connected, now)
  if not profileFlightCounterSelected() then return end
  if FC.model ~= flightModel then
    if wgt.profileOperation
       and wgt.profileOperation.kind == "flightStats" then
      profileFailFlightStats(wgt, wgt.profileOperation.token, "MODEL CHANGED")
    end
    FC.count, FC.stale, FC.pending = nil, false, false
    FC.status, FC.wanted = "WAITING", true
    FC.stableSince, FC.model = nil, flightModel
    FC.flightSeenArmed = false
    profileClearFlightStatsRefresh()
  end

  local state = wgt.profileRfState
  if not connected then
    if wgt.profileOperation
       and wgt.profileOperation.kind == "flightStats" then
      profileFailFlightStats(wgt, wgt.profileOperation.token, "DISCONNECTED")
    end
    FC.state, FC.armState, FC.stableSince = state, nil, nil
    FC.count, FC.stale, FC.pending = nil, false, false
    FC.flightSeenArmed = false
    profileClearFlightStatsRefresh()
    FC.wanted = true
    FC.status = state == "disconnected" and "DISCONNECTED" or "STARTING"
    return
  end

  if state ~= FC.state then
    local previous = FC.state
    FC.state = state
    if state == "armed" then
      FC.wanted, FC.stableSince = false, nil
      FC.flightSeenArmed = true
      profileClearFlightStatsRefresh()
    elseif state == "disarmed" or state == "connected" then
      if previous == nil or previous == "armed"
         or previous == "disconnected" then
        local afterFlight = FC.flightSeenArmed
        FC.flightSeenArmed = false
        profileRequestFlightStatsRefresh(now, afterFlight)
      end
    end
  end

  local armed = profileFlightCounterArmState(wgt)
  if armed ~= FC.armState then
    local previous = FC.armState
    FC.armState = armed
    if armed == true then
      FC.wanted, FC.stableSince = false, nil
      FC.flightSeenArmed = true
      profileClearFlightStatsRefresh()
      if wgt.profileOperation
         and wgt.profileOperation.kind == "flightStats" then
        profileFailFlightStats(wgt, wgt.profileOperation.token, "ARMED")
      end
    elseif armed == false and previous ~= false then
      local afterFlight = FC.flightSeenArmed
      FC.flightSeenArmed = false
      profileRequestFlightStatsRefresh(now, afterFlight)
    end
  end

  if armed == nil then
    FC.stableSince = nil
    if not FC.pending then FC.status = "NO ARM SENSOR" end
    return
  elseif armed then
    FC.stableSince = nil
    if FC.count == nil and not FC.pending then FC.status = "ARMED" end
    return
  end

  FC.stableSince = FC.stableSince or now
  if FC.wanted and not FC.pending then
    FC.status = "WAITING"
    if now - FC.stableSince >= FC.disarmStableTicks then
      if profileYieldArmingStatusToFlightStats(wgt, now) then
        profileBeginFlightStats(wgt)
      end
    end
  end
end

local function profilePointInBatteryBar(touchState)
  if type(touchState) ~= "table" then return false end
  local x, y = tonumber(touchState.x), tonumber(touchState.y)
  local bar = V.bottom
  return x and y and bar
         and x >= bar.x and x < bar.x + bar.w
         and y >= bar.y and y < bar.barY + bar.barH + math.max(8, G.y(20))
end

local function profileModeAccess()
  local live = not OPT.simTelemetry
  -- Nitro has no RotorFlight battery profiles. It still keeps RF Tool alive
  -- for read-only arming diagnostics and, when selected, MSP 14 flight stats.
  local profiles = live and OPT.heliType == HELI_ELECTRIC
  local arming = live and OPT.heliType ~= HELI_OMPHOBBY
  local flightStats = live and OPT.flightCounter == FC.ROTORFLIGHT
  return profiles, arming, flightStats, arming or flightStats
end

local function serviceBatteryProfileFeature(wgt, allowUi, event, touchState)
  if not wgt then return end
  local profileEligible, armingEligible, counterEligible, rfToolNeeded =
    profileModeAccess()
  if rfToolNeeded then
    profileServiceEmbeddedRfTool(wgt)
    profileRegisterWithRfTool(wgt)
  end
  if wgt.profileProviderChanged then
    wgt.profileProviderChanged = false
    profileResetConnection(wgt)
  end
  local now = profileNow()
  local connected = rfToolNeeded and profileControllerConnected(wgt)
  local showConnected = rfToolNeeded and connected or false
  G.profileConnectedForDisplay = showConnected
  wgt.profileConnectedForDisplay = showConnected
  if profileEligible and connected then
    wgt.profileDisconnectedSince = nil
    if not wgt.profileWasConnected then
      wgt.profileWasConnected = true
      wgt.profileAutoShown = false
      wgt.profileInitialReadRequested = false
      wgt.profileInitialReadFinished = false
      wgt.profileInitialReadValid = false
      wgt.profileCapacityReadRequested = false
      wgt.profileCapacityReadFinished = false
      wgt.profileCapacitiesReady = false
      wgt.profileCapacitiesComplete = false
      wgt.profileCapacities = nil
      wgt.profileCapacityReplyLength = nil
      wgt.profileSelectionRequested = nil
      wgt.profileActiveCapacityRequested = nil
      wgt.profileCapacityRefreshRequested = nil
      wgt.profileConnectReadyAt = now + PROFILE_CONNECT_SETTLE
      wgt.profileMenuRetryAt = nil
      profileSetMessage(wgt, "SELECT A BATTERY PROFILE", C_DIM)
    end

    if wgt.profileCapacityRefreshRequested and not wgt.profileBusy then
      wgt.profileCapacityRefreshRequested = nil
      wgt.profileInitialReadRequested = false
      wgt.profileInitialReadFinished = false
      wgt.profileCapacityReadRequested = false
      wgt.profileCapacityReadFinished = false
      wgt.profileCapacitiesReady = false
      wgt.profileCapacitiesComplete = false
      wgt.profileCapacities = nil
      wgt.profileCapacityReplyLength = nil
      wgt.profileNoticeUntil = nil
      wgt.profileConnectReadyAt = now
      profileSetMessage(wgt, "READING PROFILE CAPACITIES...", C_YELLOW)
    end

    local telemetryProfile = getBattProfile()
    if telemetryProfile and telemetryProfile ~= wgt.profileActive
       and not wgt.profileBusy then
      wgt.profileActive = telemetryProfile
      wgt.profileInitialReadValid = true
      profileSetMessage(wgt,
        "CURRENT PROFILE " .. tostring(telemetryProfile), C_DIM)
    end

    profileCheckOperationTimeout(wgt, now)
    local unsafe, unsafeMessage = profileSwitchUnsafe(wgt)
    local transportReady = profileTransport() ~= nil
    local connectionSettled = now >= (wgt.profileConnectReadyAt or now)
    if transportReady and connectionSettled and not unsafe
       and not wgt.profileInitialReadRequested
       and not wgt.profileCapacityReadRequested and not wgt.profileBusy then
      profileBeginSnapshot(wgt)
    end

    local snapshotReady = wgt.profileInitialReadFinished
                          and wgt.profileCapacityReadFinished
    local onlyProfile = snapshotReady and profileOnlyConfigured(wgt) or nil
    if onlyProfile then
      wgt.profileAutoShown = true
      wgt.profileSingleConfigured = onlyProfile
      if wgt.profileActive ~= onlyProfile and not unsafe
         and not wgt.profileBusy and not wgt.profileSelectionRequested then
        wgt.profileSelectionRequested = onlyProfile
        profileSetMessage(wgt,
          "USING ONLY PROFILE " .. tostring(onlyProfile) .. "...", C_YELLOW)
      elseif wgt.profileActive == onlyProfile then
        local capacity = wgt.profileCapacities[onlyProfile]
        profileSetMessage(wgt,
          "PROFILE " .. tostring(onlyProfile) .. ": "
            .. tostring(capacity) .. " mAh", C_GREEN)
      end
    else
      wgt.profileSingleConfigured = nil
    end

    local requestedProfile = wgt.profileSelectionRequested
    local selectionQueuedThisPass = false
    if requestedProfile and profileCapacityInProgress(wgt) then
      -- A user choice outranks the optional post-selection capacity read.
      -- Queue ownership checks prevent disturbing another RF Tool consumer.
      profileStopCapacityRead(wgt)
    end
    if requestedProfile and not wgt.profileBusy then
      wgt.profileSelectionRequested = nil
      local blocked, blockedMessage = profileSwitchUnsafe(wgt)
      if profileTransport() == nil then
        profileSetMessage(wgt, profileRfToolStatus(wgt), C_RED)
        profileSetNotice(wgt, "BATTERY PROFILE ERROR",
                         profileRfToolStatus(wgt), C_RED, 500)
      elseif blocked then
        profileSetMessage(wgt, blockedMessage, C_RED)
        profileSetNotice(wgt, "PROFILE CHANGE LOCKED",
                         blockedMessage, C_RED, 500)
      elseif not profileBeginOperation(wgt, "select", requestedProfile) then
        wgt.profileSelectionRequested = requestedProfile
      else
        selectionQueuedThisPass = true
      end
    end

    local activeCapacityProfile = wgt.profileActiveCapacityRequested
    if activeCapacityProfile and not selectionQueuedThisPass
       and not wgt.profileBusy and not unsafe then
      if profileBeginOperation(wgt, "activeCapacity",
                               activeCapacityProfile) then
        wgt.profileActiveCapacityRequested = nil
      end
    end

    local wasAutoShown = wgt.profileAutoShown
    if allowUi then
      local blockingRead = wgt.profileBusy
                           and not profileCapacityInProgress(wgt)
                           and not (wgt.profileOperation
                                    and wgt.profileOperation.kind
                                        == "flightStats")
      if blockingRead then
        profileSetEntryPrompt(true, "BATTERY PROFILES",
                              wgt.profileMessage or "READING CONTROLLER...",
                              C_YELLOW)
      elseif wgt.profileNoticeUntil and now < wgt.profileNoticeUntil then
        profileSetEntryPrompt(true,
                              wgt.profileNoticeTitle,
                              wgt.profileNoticeDetail,
                              wgt.profileNoticeColor,
                              wgt.profileNoticeCompact)
      elseif snapshotReady and not wgt.profileAutoShown
             and (not wgt.profileMenuRetryAt
                  or now >= wgt.profileMenuRetryAt) then
        profileSetEntryPrompt(false)
        local opened = showBatteryProfileMenu(wgt) == true
        wgt.profileAutoShown = opened
        if not opened then wgt.profileMenuRetryAt = now + 500 end
      elseif not snapshotReady and not wgt.profileAutoShown then
        profileSetEntryPrompt(true,
          unsafe and "BATTERY PROFILE LOCKED" or "READING BATTERY PROFILES",
          wgt.profileMessage or "WAITING FOR RF TOOL...",
          unsafe and C_RED or C_YELLOW)
      else
        profileSetEntryPrompt(false)
      end
    end

    if wasAutoShown and snapshotReady
       and (not wgt.profileBusy or profileCapacityInProgress(wgt))
       and EVT_TOUCH_TAP and event == EVT_TOUCH_TAP
       and profilePointInBatteryBar(touchState) then
      wgt.profileAutoShown = true
      showBatteryProfileMenu(wgt)
    end
  else
    if wgt.profileWasConnected then
      if not wgt.profileDisconnectedSince then
        wgt.profileDisconnectedSince = now
      end
      local explicit = wgt.profileRfToolRegistered
                       and wgt.profileRfState == "disconnected"
      if explicit or now - wgt.profileDisconnectedSince >= 500 then
        profileResetConnection(wgt)
      end
    end
    if allowUi then profileSetEntryPrompt(false) end
  end
  local controllerConnected = connected == true
  profileServiceFlightCounter(wgt,
    counterEligible and controllerConnected, now)
  local armingConnected = armingEligible and controllerConnected
  profileServiceArmingStatus(wgt, armingConnected, now, allowUi)
end

return {
  service=serviceBatteryProfileFeature,
  reset=profileResetConnection,
  buildPrompt=profileBuildEntryPrompt,
  buildArmingBanner=profileBuildArmingBanner,
  flightSourceChanged=profileFlightCounterSourceChanged,
}
end)()

local function buildUi()
  if not lvgl then return end
  lvgl.clear()
  V = {}
  OBJECT_STATE = {}
  if not OPT.bgTransparent then
    newRect(G.originX, G.originY, G.w, G.h, C_BG, true, 0, 0)
  end
  buildTopBar()
  buildModelPanel()
  buildGovernor()
  buildHero()
  buildTiles()
  buildBottom()
  batteryProfiles.buildArmingBanner()
  batteryProfiles.buildPrompt()
  updateUiState()
end

local function ensureLayout(widget, fullScreen)
  local x, y, w, h = G.bounds(widget.zone, fullScreen)
  local signature = G.signature(x, y, w, h)
  if widget.layoutSignature == signature then return false end
  G.configure(x, y, w, h)
  widget.layoutSignature = signature
  buildUi()
  return true
end

local function refresh(widget, event, touchState)
  clearFrameCache()
  ensureLayout(widget, event ~= nil)
  local serviced
  if OPT.simTelemetry then
    serviced = G.serviceSimulation(widget)
  else
    serviced = serviceTelemetry(true)
    batteryProfiles.service(widget, true, event, touchState)
  end
  if serviced then updateUiState() end
end
local function background(widget)
  clearFrameCache()
  -- Session extrema are flight data too; keep them current while another page
  -- is visible instead of recording only the moments this dashboard is open.
  if OPT.simTelemetry then
    G.serviceSimulation(widget)
  else
    serviceTelemetry(true)
    batteryProfiles.service(widget, false, nil, nil)
  end
end
local function create(zone, options)
  -- Drop any stale frame cache (e.g. cached model name) before loading flights.
  clearFrameCache()
  applyOptions(options)
  if OPT.flightCounter ~= FC.ROTORFLIGHT then
    loadModelFlights()
  else
    flightModel = modelKey(getModelName())
    modelFlights = 0
    timerThresholdArmed = nil
    resetSessionStats()
    resetSessionEvidence()
  end
  -- Dashboard state is intentionally module-wide. The supported deployment is
  -- one active instance; layout geometry follows that instance's current zone.
  local x, y, w, h = G.bounds(zone, false)
  G.configure(x, y, w, h)
  local widget = {
    zone = zone,
    options = options,
    layoutSignature = G.signature(x, y, w, h),
    lastSimTick = -1,
    profileWasConnected = false,
    profileConnectedForDisplay = false,
    profileAutoShown = false,
    profileBusy = false,
  }
  batteryProfiles.flightSourceChanged(widget)
  return widget
end
local function update(widget, options)
  widget.options = options
  local previousHeliType = OPT.heliType
  local previousSimulation = OPT.simTelemetry
  local previousFlightCounter = OPT.flightCounter
  local previousReserve = OPT.reservePct
  local previousRxMin = OPT.rxPackMin
  local previousRxMax = OPT.rxPackMax
  local previousRxValid = OPT.rxPackValid
  local previousMotorSource = SRC.motorSwitch
  applyOptions(options)
  local heliChanged = previousHeliType ~= OPT.heliType
  local simulationChanged = previousSimulation ~= OPT.simTelemetry
  local flightCounterChanged = previousFlightCounter ~= OPT.flightCounter
  local reserveChanged = previousReserve ~= OPT.reservePct
  local rxSettingsChanged = previousRxMin ~= OPT.rxPackMin
                            or previousRxMax ~= OPT.rxPackMax
                            or previousRxValid ~= OPT.rxPackValid
  local motorChanged = previousMotorSource ~= SRC.motorSwitch

  if heliChanged or simulationChanged then
    resetSessionStats()
    resetSessionEvidence()
  else
    if reserveChanged then
      -- Changing usable reserve changes percentage meaning, but a visual/theme
      -- edit must never erase live low-battery or Nitro warning state.
      if not OPT.simTelemetry then resetBatteryAlertState("flight") end
      A.displayPercent = 0
      A.displayPercentInit = false
    end
    if rxSettingsChanged and not OPT.simTelemetry then
      resetBatteryAlertState("rx")
    end
  end

  if motorChanged and not OPT.simTelemetry then
    resetMotorAlertGate(frameNow())
    if A.flightDeadVoiceLatched and not A.flightDeadVoiceAcknowledged then
      A.flightDeadVoiceStartPosition = nil
    end
    if A.rxDeadVoiceLatched and not A.rxDeadVoiceAcknowledged then
      A.rxDeadVoiceStartPosition = nil
    end
  end
  if simulationChanged then
    widget.lastSimTick = -1
    timerThresholdArmed = nil
  end
  if flightCounterChanged then
    if OPT.flightCounter ~= FC.ROTORFLIGHT then
      loadModelFlights()
    else
      flightModel = modelKey(getModelName())
      timerThresholdArmed = nil
    end
    batteryProfiles.flightSourceChanged(widget)
  end
  if heliChanged or simulationChanged then batteryProfiles.reset(widget) end
  if heliChanged or reserveChanged or simulationChanged then
    D.hasBattData = false
  end
  if heliChanged or rxSettingsChanged or simulationChanged then
    D.rxVoltage = nil
    D.rxCellVoltage = nil
    D.rxPercent = 0
  end
  A.lastDataTick = -1
  clearFrameCache()
  local x, y, w, h = G.bounds(widget.zone, false)
  G.configure(x, y, w, h)
  widget.layoutSignature = G.signature(x, y, w, h)
  buildUi()
end
-- The reverse-switch setting is unnecessary: the widget
-- detects movement of the whole switch and validates it against Gov/Hspd or NR.
-- Telemetry sensor sources are intentionally omitted: the widget auto-detects standard
-- Rotorflight sensor names (Hspd, Tspd, Vbec, Vcel, Cel#, Curr, Capa, Bat%,
-- Tesc, Gov, BAT#, Vbat, and RQly). Nitro Rx pack voltage uses Vbec only.
-- OMPHOBBY uses NR, RxBt, Curr, Capa, Bat%, and Tmp; its cell count comes
-- from M1/M2 in the model name, and it has no tail-RPM telemetry source.
-- CountSrc occupies slot 10 so the original nine saved option indices remain
-- unchanged. Rotorflight FC is the default and reads command 14 through
-- RF Tool, and Sim Preview retains the isolated Companion display path.
-- "Motor Switch" is a raw SOURCE so settings select the physical control (SG),
-- not one of its individual position conditions (SG up/middle/down). A movement
-- suppresses Electric/OMPHOBBY flight-pack alerts only after current aircraft
-- telemetry corroborates a stopped state; missing evidence fails loud. After
-- the first dead.wav playback, movement separately acknowledges only repeats.
local options = {
  { "Theme",    CHOICE, 1, { "Dark", "Light", "Transparent",
                             "Orange", "Red", "Blue", "Pink", "Green",
                             "Purple", "Reef", "Royal", "Ember",
                             "Graphite", "Glacier", "Sunset", "Synthwave",
                             "Gulf", "Voltage", "Transparent Light",
                             "Titanium Ember", "Aurora", "Desert Night" } },
  { "TxBatt",   CHOICE, 1, { "LiPo", "Li-Ion" } },
  { "MinFlight", VALUE, TOPBAR_MIN_DUR_DEFAULT, -30, 120 },
  { "HeliType", CHOICE, 1, { "Electric", "Nitro", "OMPHOBBY" } },
  { "BattRsv", VALUE, 20, 0, 50 },
  { "BattVoice", BOOL, 0 },
  { "RxPackMin", STRING, "6.60" },
  { "RxPackMax", STRING, "8.40" },
  { "MotorSw", SOURCE, (function()
      local info = type(getFieldInfo) == "function" and getFieldInfo("SG") or nil
      return type(info) == "table" and info.id or 0
    end)() },
  { "CountSrc", CHOICE, 2, { "KSE Counter", "Rotorflight FC", "Sim Preview" } },
}
local OPTION_LABELS = {
  TxBatt   = "TX Battery",
  MinFlight= "KSE Counter Min (sec)",
  HeliType = "Heli Type",
  BattRsv  = "Batt Reserve %",
  BattVoice= "Battery Voice",
  RxPackMin= "Rx Pack Minimum",
  RxPackMax= "Rx Pack Maximum",
  MotorSw  = "Motor Switch",
  CountSrc = "Flight Counter",
}
local function translate(name, language)
  return OPTION_LABELS[name] or name
end
return {
  name       = "KSE4",
  options    = options,
  create     = create,
  update     = update,
  refresh    = refresh,
  background = background,
  translate  = translate,
  useLvgl    = true,
}
