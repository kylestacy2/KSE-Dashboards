--[[
  KSE5 - retained LVGL telemetry dashboard for EdgeTX color radios.

  Functional behavior follows the immutable StacyDashV4 reference engine.
  The visual adapter intentionally retains KSE5's ring-card design while
  deriving its geometry from the current EdgeTX screen or widget zone.
]]

local G = {
  referenceW=480, referenceH=320,
  screenW=tonumber(_G.LCD_W) or 480,
  screenH=tonumber(_G.LCD_H) or 320,
  originX=0, originY=0, w=480, h=320,
  scaleX=1, scaleY=1, scaleMin=1,
  compact=true, largeScreen=false,
}
local SMLSIZE      = rawget(_G, "SMLSIZE")      or SMLSIZE      or 0
local MIDSIZE      = rawget(_G, "MIDSIZE")      or MIDSIZE      or 0
local BOLD_FONT    = _G.BOLD or SMLSIZE
G.fontSmall, G.fontRingValue, G.fontTileValue = SMLSIZE, MIDSIZE, MIDSIZE
G.fontGovernorValue, G.fontTop, G.fontTimer = MIDSIZE, MIDSIZE, MIDSIZE
G.signalHeights = { 6, 10, 14, 18 }
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
  G.originX, G.originY, G.w, G.h = x, y, w, h
  G.scaleX = w / G.referenceW
  G.scaleY = h / G.referenceH
  G.scaleMin = math.min(G.scaleX, G.scaleY)
  G.compact = w <= 520
  G.largeScreen = w >= 700 and h >= 420

  -- EdgeTX font constants are discrete selectors, not arithmetic style flags.
  -- Keep general values at MIDSIZE. On compact governor tiles, standalone
  -- BOLD is the useful step between SMLSIZE and MIDSIZE; it must not be added
  -- to another font selector. Fall back to SMLSIZE if firmware omits BOLD.
  G.fontSmall = SMLSIZE
  G.fontRingValue = MIDSIZE
  G.fontTileValue = MIDSIZE
  G.fontGovernorValue = G.compact and BOLD_FONT or MIDSIZE
  G.fontTop = MIDSIZE
  G.fontTimer = MIDSIZE
end
local C_BG, C_TOP, C_PANEL, C_PANEL_ALT, C_BORDER, C_TRACK
local C_TEXT, C_DIM, C_ACCENT, C_IMAGE_BG
local C_GREEN, C_YELLOW, C_RED, C_BLUE, C_CYAN, C_ORANGE

-- RotorFlight 2.3 exposes six battery-profile slots. MSP uses zero-based
-- indexes while the BAT# telemetry sensor and the user-facing UI use 1..6.
local BATTERY_PROFILE_COUNT = 6

local GOV_STATES = {
  [0]="OFF",      [1]="IDLE",     [2]="SPOOLUP", [3]="RECOVERY",
  [4]="ACTIVE",   [5]="THR-OFF",  [6]="LOST-HS",
  [7]="AUTOROT",  [8]="BAILOUT",  [9]="BYPASS",
}
local GOV_RUNNING_STATE = { [2]=true, [3]=true, [4]=true, [8]=true, [9]=true }
local GOV_STOP_STATE = { [0]=true, [5]=true, [7]=true }
local GOV_PAUSE_HOLD_STATE = { [0]=true, [1]=true, [5]=true, [7]=true }
local GOV_COLOR, GOV_FALLBACK = {}, {}

local function applyTheme(name)
  local rgb = lcd.RGB
  C_GREEN  = rgb(28, 232, 119)
  C_YELLOW = rgb(255, 196, 48)
  C_ORANGE = rgb(255, 112, 28)
  C_RED    = rgb(255, 64, 80)
  C_BLUE   = rgb(55, 136, 255)
  C_CYAN   = rgb(30, 220, 240)
  -- KSE4-inspired opaque palettes. Each entry retains KSE4's background,
  -- tile, border, muted-text, and accent colors; KSE5 derives its additional
  -- top-bar, alternate-panel, and ring-track layers from those five anchors.
  -- Only the selected palette is allocated, which keeps radio memory bounded.
  local p
  if name == "red" then
    p = {100,18,18, 130,28,28, 180,50,50, 240,165,165, 255,95,95}
  elseif name == "blue" then
    p = {4,20,54, 10,32,74, 28,72,124, 150,180,220, 80,165,255}
  elseif name == "pink" then
    p = {145,0,83, 184,0,105, 255,20,147, 255,196,225, 255,222,239}
  elseif name == "green" then
    p = {6,54,22, 12,74,34, 24,120,58, 150,215,175, 60,220,120}
  elseif name == "purple" then
    p = {34,12,60, 50,22,82, 92,46,140, 190,165,225, 175,110,245}
  elseif name == "reef" then
    p = {8,22,58, 8,46,50, 24,96,104, 150,190,218, 70,200,230}
  elseif name == "royal" then
    p = {40,16,66, 52,40,12, 112,88,28, 202,172,228, 180,120,248}
  elseif name == "ember" then
    p = {70,18,10, 92,52,8, 150,88,26, 235,175,150, 255,150,50}
  elseif name == "graphite" then
    p = {18,21,25, 34,39,46, 75,85,98, 165,175,188, 215,225,235}
  elseif name == "glacier" then
    p = {8,28,42, 18,52,68, 46,105,126, 155,203,218, 117,225,250}
  elseif name == "sunset" then
    p = {96,12,10, 160,48,8, 230,105,20, 255,191,145, 255,190,48}
  elseif name == "synthwave" then
    p = {22,10,55, 59,13,70, 147,35,126, 205,154,226, 71,229,255}
  elseif name == "gulf" then
    p = {10,48,65, 16,72,88, 204,102,36, 162,205,216, 255,139,59}
  elseif name == "voltage" then
    p = {9,19,10, 26,37,17, 83,117,31, 183,204,145, 185,255,50}
  elseif name == "titanium_ember" then
    p = {11,14,18, 41,49,58, 100,113,125, 174,184,193, 255,138,61}
  elseif name == "aurora" then
    p = {6,27,24, 23,27,59, 52,84,122, 159,185,200, 116,242,206}
  elseif name == "desert_night" then
    p = {26,21,12, 52,51,27, 118,101,59, 201,187,139, 245,196,81}
  end
  if p then
    C_BG        = rgb(p[1], p[2], p[3])
    C_TOP       = rgb(math.floor((p[1] * 2 + p[4]) / 3 + 0.5),
                      math.floor((p[2] * 2 + p[5]) / 3 + 0.5),
                      math.floor((p[3] * 2 + p[6]) / 3 + 0.5))
    C_PANEL     = rgb(p[4], p[5], p[6])
    C_PANEL_ALT = rgb(math.floor((p[4] * 2 + p[7]) / 3 + 0.5),
                      math.floor((p[5] * 2 + p[8]) / 3 + 0.5),
                      math.floor((p[6] * 2 + p[9]) / 3 + 0.5))
    C_BORDER    = rgb(p[7], p[8], p[9])
    C_TRACK     = rgb(math.floor((p[4] + p[7]) / 2 + 0.5),
                      math.floor((p[5] + p[8]) / 2 + 0.5),
                      math.floor((p[6] + p[9]) / 2 + 0.5))
    C_TEXT      = rgb(245, 245, 245)
    C_DIM       = rgb(p[10], p[11], p[12])
    C_ACCENT    = rgb(p[13], p[14], p[15])
    C_IMAGE_BG  = C_PANEL_ALT
  elseif name == "light" then
    C_BG        = rgb(223, 236, 247)
    C_TOP       = rgb(250, 253, 255)
    C_PANEL     = rgb(244, 250, 255)
    C_PANEL_ALT = rgb(231, 242, 251)
    C_BORDER    = rgb(145, 177, 202)
    C_TRACK     = rgb(195, 217, 234)
    C_TEXT      = rgb(8, 27, 43)
    C_DIM       = rgb(61, 88, 111)
    C_ACCENT    = rgb(0, 137, 224)
    C_IMAGE_BG  = C_PANEL_ALT
    C_GREEN     = rgb(0, 143, 76)
    C_YELLOW    = rgb(176, 112, 0)
    C_ORANGE    = rgb(224, 82, 0)
    C_RED       = rgb(211, 35, 56)
    C_BLUE      = rgb(0, 98, 218)
    C_CYAN      = C_ACCENT
  elseif name == "arctic" then
    C_BG        = rgb(2, 10, 21)
    C_TOP       = rgb(4, 19, 37)
    C_PANEL     = rgb(7, 29, 53)
    C_PANEL_ALT = rgb(9, 40, 70)
    C_BORDER    = rgb(24, 85, 128)
    C_TRACK     = rgb(14, 55, 88)
    C_TEXT      = rgb(239, 249, 255)
    C_DIM       = rgb(115, 172, 208)
    C_ACCENT    = rgb(26, 211, 255)
    C_IMAGE_BG  = C_PANEL_ALT
  elseif name == "violet" then
    C_BG        = rgb(11, 8, 19)
    C_TOP       = rgb(18, 13, 29)
    C_PANEL     = rgb(25, 18, 38)
    C_PANEL_ALT = rgb(33, 24, 49)
    C_BORDER    = rgb(73, 55, 96)
    C_TRACK     = rgb(53, 39, 67)
    C_TEXT      = rgb(247, 242, 255)
    C_DIM       = rgb(167, 152, 184)
    C_ACCENT    = rgb(181, 140, 255)
    C_IMAGE_BG  = C_PANEL_ALT
  elseif name == "orange" then
    C_BG        = rgb(18, 5, 0)
    C_TOP       = rgb(44, 12, 0)
    C_PANEL     = rgb(62, 18, 0)
    C_PANEL_ALT = rgb(86, 26, 0)
    C_BORDER    = rgb(190, 68, 0)
    C_TRACK     = rgb(126, 35, 0)
    C_TEXT      = rgb(255, 250, 238)
    C_DIM       = rgb(255, 176, 92)
    C_ACCENT    = rgb(255, 132, 0)
    C_IMAGE_BG  = C_PANEL_ALT
  else
    C_BG        = rgb(2, 2, 2)
    C_TOP       = rgb(5, 5, 5)
    C_PANEL     = rgb(10, 10, 10)
    C_PANEL_ALT = rgb(15, 15, 15)
    C_BORDER    = rgb(42, 42, 42)
    C_TRACK     = rgb(26, 26, 26)
    C_TEXT      = rgb(245, 245, 245)
    C_DIM       = rgb(150, 150, 150)
    C_ACCENT    = rgb(230, 230, 230)
    C_IMAGE_BG  = C_PANEL_ALT
  end
  GOV_COLOR.ACTIVE      = C_GREEN
  GOV_COLOR.IDLE        = C_YELLOW
  GOV_COLOR.SPOOLUP     = C_YELLOW
  GOV_COLOR.RECOVERY    = C_YELLOW
  GOV_COLOR.OFF         = C_RED
  GOV_COLOR["THR-OFF"] = C_RED
  GOV_COLOR["LOST-HS"] = C_RED
  GOV_COLOR.AUTOROT     = C_BLUE
  GOV_COLOR.BAILOUT     = C_BLUE
  GOV_COLOR.BYPASS      = C_BLUE
  GOV_FALLBACK          = C_DIM
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function round(v)
  if v >= 0 then return math.floor(v + 0.5) end
  return math.ceil(v - 0.5)
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
-- Flight totals can belong either to StacyDash's Timer 1/CSV counter or to
-- RotorFlight's persistent FC statistics. Keeping the FC runtime in one table
-- makes source changes explicit and avoids adding another telemetry transport.
local FC = {
  STACYDASH=1, ROTORFLIGHT=2, SIM_PREVIEW=3,
  disarmStableTicks=150,
  confirmMaxReads=6,
  count=nil, status="STACYDASH", stale=false,
  wanted=false, pending=false, stableSince=nil,
  state=nil, armState=nil, model=nil, flightSeenArmed=false,
  refreshBase=nil, refreshAttempts=0,
}
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
  rxPackMin     = 6.6,
  rxPackMax     = 8.4,
  rxPackValid   = true,
  bgTransparent = false,
  themeName     = "dark",
  simTelemetry  = false,
  flightCounter = FC.ROTORFLIGHT,
}
local BATTERY_VOICE = {
  levels       = { 50, 40, 30, 20, 10, 0 },
  path         = "/WIDGETS/KSE5/BatterySounds/",
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
  ompMotorZeroConfirmTicks = 30,   -- require 0.3s of displayed-zero RPM telemetry
  ompMotorRunningRpm = 1, -- raw RPM below 1 matches the displayed zero state
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
  local themeNames = {
    [1]="dark", [2]="light", [3]="arctic", [4]="violet",
    [5]="orange", [6]="red", [7]="blue", [8]="pink",
    [9]="green", [10]="purple", [11]="reef", [12]="royal",
    [13]="ember", [14]="graphite", [15]="glacier", [16]="sunset",
    [17]="synthwave", [18]="gulf", [19]="voltage",
    [20]="titanium_ember", [21]="aurora", [22]="desert_night",
  }
  OPT.bgTransparent = false
  OPT.themeName = themeNames[rawTheme] or "dark"
  applyTheme(OPT.themeName)
  -- Slot 10 used to be SimTelem. CountSrc keeps that slot, folds preview into
  -- the same choice, and preserves the first nine saved option positions.
  local rawCounter = tonumber(opts and (opts.CountSrc
                                         or opts["Flight Counter"]))
  if rawCounter == nil and opts
     and (opts.SimTelem == 1 or opts.SimTelem == true
          or opts["Simulate Telemetry"] == 1
          or opts["Simulate Telemetry"] == true) then
    rawCounter = FC.SIM_PREVIEW
  end
  if rawCounter ~= FC.STACYDASH
     and rawCounter ~= FC.ROTORFLIGHT
     and rawCounter ~= FC.SIM_PREVIEW then
    rawCounter = FC.ROTORFLIGHT
  end
  OPT.flightCounter = rawCounter
  OPT.simTelemetry = rawCounter == FC.SIM_PREVIEW
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
  local sgInfo = type(getFieldInfo) == "function" and getFieldInfo("SG") or nil
  local defaultMotorSwitch = type(sgInfo) == "table" and sgInfo.id or 0
  SRC.motorSwitch = defaultMotorSwitch
  if opts then
    -- The Motor Switch is the only mapped source. Rotorflight Gov/Hspd or OMP
    -- RPM telemetry validates what a movement means; other sensors auto-detect.
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
end
local modelImageCache = { key=nil, path=nil }
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
local function getModelInfo()
  local v = F.modelInfo
  if v ~= nil then return v ~= false and v or nil end
  local ok, info = pcall(model.getInfo)
  v = ok and type(info) == "table" and info or false
  F.modelInfo = v
  return v ~= false and v or nil
end
local function getModelName()
  local v = F.modelName
  if v ~= nil then return v end
  local info = getModelInfo()
  local n = info and info.name or nil
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
  headspeed        = "RPM",
  packVoltage      = "RxBt",
  current          = "Curr",
  capacity         = "Capa",
  batteryPercent   = "Bat%",
  escTemperature   = "Temp",
}
local function activeSensorName(key)
  local sensors = OPT.heliType == HELI_OMPHOBBY
                  and OMPHOBBY_SENSOR or ROTORFLIGHT_SENSOR
  return sensors[key]
end
local function getSensorNumber(key)
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
  if OPT.heliType == HELI_OMPHOBBY then
    -- OMP receivers do not stream cell count. Model names containing M2 are
    -- 3S; names containing M1 are 2S LiHV (8.5-8.7 V fully charged). Match
    -- case-insensitively anywhere and make the M1 chemistry deterministic
    -- instead of waiting for a high-voltage sample to identify it.
    local modelName = string.upper(getModelName())
    if string.find(modelName, "M2", 1, true) then
      v = 3
    elseif string.find(modelName, "M1", 1, true) then
      v = 2
      D.isLiHV = true
      A.liHvHighSamples = SAFETY.liHvConfirmSamples
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

  -- BAT# can take a few telemetry cycles to reflect an RF Tool profile request,
  -- so retain the locally selected value briefly instead of flashing the prior
  -- telemetry value while MSP 176 is being delivered.
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
  -- A raw switch move is never enough to silence a warning. Rotorflight must
  -- corroborate it with Gov or Hspd; OMPHOBBY uses stopped RPM telemetry.
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
  if OPT.battBarMode == 1 then
    local rx = getRxBatt()
    updateRxPackAlert(rx)
    BATTERY_VOICE.updateRxDead(voiceEnabled, rx)
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
  -- the existing count for visual fidelity, but every write/count path below
  -- remains restricted to the real StacyDash/Radio source.
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
  if OPT.flightCounter ~= FC.STACYDASH then return false end
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
    -- Running RPM telemetry can persist during rotor coast-down. Do not relabel the new
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
  local thisModel = modelKey(getModelName())
  if flightModel ~= thisModel then
    flightModel = thisModel
    if OPT.flightCounter == FC.STACYDASH then
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
  if OPT.flightCounter ~= FC.STACYDASH then return end
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
  tickFlightCount()
  tick(now)
  if trackStats then updateStats() end
  return true
end

-- Simulation is a display-only 36-second loop. It bypasses tick(), so none of
-- the flight counter, audio, haptic, motor-gate, or safety-alert code can run.
-- The synthetic values live only in the same per-frame cache consumed by the
-- retained UI and are discarded before returning to live mode.
local SIM_INTERVAL_TICKS = 10
local function applySimulatedTelemetry(now)
  now = tonumber(now) or 0
  local phase = (now % 3600) / 3600
  local wave = (math.sin(phase * math.pi * 2) + 1) * 0.5
  local motorRunning = phase >= 0.08 and phase < 0.92
  local rpm = motorRunning and round(650 + wave * 1750) or 0
  local current = motorRunning and round(15 + wave * 235) or 0
  local temp = round(32 + phase * 68)
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
  D.capacity = round(180 + phase * 4100)
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
  D.tailRpmValid = OPT.heliType ~= HELI_OMPHOBBY
  D.govValid = OPT.heliType ~= HELI_OMPHOBBY
  D.govCurrentInvalid = false
  D.minCellVoltage = cell - 0.05

  if OPT.heliType == HELI_NITRO then
    local rx = 8.25 - phase * 1.35
    local rxPercent = clamp((rx - OPT.rxPackMin)
                            / math.max(0.1, OPT.rxPackMax - OPT.rxPackMin)
                            * 100, 0, 100)
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

  F.rqly = round(88 + wave * 11)
  F.txVolt = 7.55 + wave * 0.65
  F.timerSecs = 182 + math.floor(phase * 815)
  F.cellCount = cells
  F.batPct = rawPercent
  F.capa = D.capacity
  F.curr = current
  F.temp = temp
  F.rpm = rpm
  F.trpm = round(rpm * 4.55)
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

local function serviceSimulation(widget)
  local now = frameNow()
  local last = widget.lastSimTick
  if last and last >= 0 and now >= last
     and (now - last) < SIM_INTERVAL_TICKS then
    return false
  end
  widget.lastSimTick = now
  applySimulatedTelemetry(now)
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
  if modelImageCache.key == name then return modelImageCache.path end
  local sanitized = sanitizeFsName(name)
  if not sanitized or sanitized == "" then sanitized = "MODEL" end

  -- Match StacyDashV4's proven radio path resolution: direct io.open() probes
  -- in a fixed order, with no directory enumeration or bitmap-field guessing.
  local candidates = {
    "/IMAGES/" .. sanitized .. ".png",
    "/IMAGES/" .. sanitized .. ".bmp",
    "/WIDGETS/KSE5/default.png",
  }
  candidates[#candidates + 1] = "/IMAGES/default.png"
  candidates[#candidates + 1] = "/IMAGES/defaultmodel.png"
  candidates[#candidates + 1] = "/WIDGETS/KSE5/Rotorflight.png"
  modelImageCache.path = nil
  for _, path in ipairs(candidates) do
    if fileExists(path) then modelImageCache.path = path; break end
  end
  modelImageCache.key = name
  return modelImageCache.path
end

local function buildLayout(zone, fullScreen)
  local x, y, w, h = G.bounds(zone, fullScreen)
  G.configure(x, y, w, h)
  local layout = {
    x=x, y=y, w=w, h=h,
    pad=math.max(3, G.min(5)), gap=math.max(2, G.min(4)),
    signature=G.signature(x, y, w, h),
  }

  layout.top = { x=x, y=y, w=w, h=math.max(28, G.y(34)) }
  layout.ringY = y + layout.top.h + layout.gap
  -- The short 480x272 target needs a fixed minimum for two discrete-font tile
  -- rows; taller screens scale the original 480x320 proportions normally.
  local compactBottomMin = G.compact and math.min(126, h - 118) or 0
  layout.bottomH = math.max(compactBottomMin, G.y(136),
                            math.floor(h * 0.425))
  layout.bottomY = y + h - layout.pad - layout.bottomH
  layout.ringH = math.max(88, layout.bottomY - layout.ringY - layout.gap)

  local right = x + w - layout.pad
  local contentW = w - layout.pad * 2
  local ringW = math.floor((contentW - layout.gap * 3) / 4)
  layout.rings = {}
  for i = 1, 4 do
    local cardX = x + layout.pad + (i - 1) * (ringW + layout.gap)
    layout.rings[i] = {
      x=cardX, y=layout.ringY,
      w=(i == 4) and (right - cardX) or ringW,
      h=layout.ringH,
    }
  end
  local firstRingW = layout.rings[1].w
  layout.ringRadius = math.max(math.max(24, G.min(28)),
      math.min(math.max(28, G.min(44)),
               math.floor(firstRingW / 2) - math.max(5, G.x(8)),
               math.floor((layout.ringH - math.max(26, G.y(30))) / 2)))
  layout.ringThickness = math.max(math.max(5, G.min(6)),
                                  math.floor(layout.ringRadius * 0.20))
  -- Match StacyDashV3's vertically balanced ring placement: the gauge sits
  -- midway between its title baseline and footer instead of being top-biased.
  layout.ringCenterY = layout.ringY + math.floor((layout.ringH + 2) / 2)

  layout.modelX = x + layout.pad
  layout.modelY = layout.bottomY
  -- With Tail RPM and Pack Voltage hidden, split the lower dashboard evenly:
  -- a double-width model panel and a compact 2x2 telemetry grid.
  layout.modelW = math.floor((contentW - layout.gap) / 2)
  layout.modelH = layout.bottomH
  layout.modelFooterH = math.max(22, G.y(24))
  local imageInset = math.max(3, G.min(4))
  layout.modelImageX = layout.modelX + imageInset
  layout.modelImageY = layout.modelY + imageInset
  layout.modelImageW = layout.modelW - imageInset * 2
  layout.modelImageH = layout.modelH - layout.modelFooterH - imageInset * 2

  local statsX = layout.modelX + layout.modelW + layout.gap
  local tileW = math.floor((right - statsX - layout.gap) / 2)
  local tileH = math.floor((layout.bottomH - layout.gap) / 2)
  layout.tiles = {}
  for i = 1, 4 do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local tileX = statsX + col * (tileW + layout.gap)
    layout.tiles[i] = {
      x=tileX,
      y=layout.bottomY + row * (tileH + layout.gap),
      w=(col == 1) and (right - tileX) or tileW,
      h=(row == 1) and (y + h - layout.pad
                         - (layout.bottomY + tileH + layout.gap)) or tileH,
    }
  end
  return layout
end

-- Retained LVGL UI -----------------------------------------------------------
local function rememberObject(wgt, object, properties)
  if not object then return nil end
  local state = { visible=true }
  for key, value in pairs(properties or {}) do state[key] = value end
  wgt.objectState[object] = state
  return object
end

local function setObject(wgt, object, properties)
  if not object then return end
  local state = wgt.objectState[object]
  if not state then
    state = { visible=true }
    wgt.objectState[object] = state
  end
  local changed = false
  for key, value in pairs(properties) do
    if state[key] ~= value then
      state[key] = value
      changed = true
    end
  end
  if changed then object:set(properties) end
end

local function setVisible(wgt, object, visible)
  if not object then return end
  local state = wgt.objectState[object]
  if not state then
    state = { visible=true }
    wgt.objectState[object] = state
  end
  visible = not not visible
  if state.visible == visible then return end
  state.visible = visible
  if visible then object:show() else object:hide() end
end

local function newLabel(wgt, x, y, w, text, font, color, align)
  local properties = {
    x=x, y=y, w=w or 0, h=0, text=text or "",
    font=font or 0, color=color or C_TEXT, align=align or 0,
  }
  return rememberObject(wgt, lvgl.label(properties), properties)
end

local function setLabel(wgt, object, text, color, align)
  local properties = { text=tostring(text or "") }
  if color ~= nil then properties.color = color end
  if align ~= nil then properties.align = align end
  setObject(wgt, object, properties)
end

local function newRect(wgt, x, y, w, h, color, filled, rounded, thickness)
  local properties = {
    x=x, y=y, w=w, h=h, color=color,
    filled=not not filled, rounded=rounded or 0, thickness=thickness or 1,
  }
  return rememberObject(wgt, lvgl.rectangle(properties), properties)
end

local function newPanel(wgt, x, y, w, h, fill, border, rounded)
  return {
    fill=newRect(wgt, x, y, w, h, fill, true, rounded or 4, 1),
    border=newRect(wgt, x, y, w, h, border, false, rounded or 4, 1),
  }
end

local function compactModelName(wgt, maxChars)
  local raw = getModelName()
  wgt.fitNames = wgt.fitNames or {}
  local cached = wgt.fitNames[maxChars]
  if cached and cached.raw == raw then return cached.text end
  local text = raw
  if #text > maxChars then text = string.sub(text, 1, maxChars - 2) .. ".." end
  wgt.fitNames[maxChars] = { raw=raw, text=text }
  return text
end

local function buildTopBar(wgt)
  local l, ui = wgt.layout, wgt.ui
  local t = l.top
  newRect(wgt, t.x, t.y, t.w, t.h, C_TOP, true, 0, 1)
  local lineInset = math.max(4, G.x(5))
  lvgl.hline({ x=t.x + lineInset, y=t.y + t.h - 1,
               w=t.w - lineInset * 2,
               h=1, color=C_BORDER })

  local txBodyW, txBodyH = math.max(11, G.x(13)), math.max(19, G.y(21))
  local txBodyX = t.x + t.w - l.pad - txBodyW
  local txBodyY = t.y + math.max(7, G.y(9))
  local centerY = G.rounded(t.y + t.h / 2)
  -- KSE4's signal geometry is based on an 800x480 reference. Convert those
  -- exact proportions into KSE5's 480x320 reference so both glyphs render at
  -- the same physical size and battery-relative position on every target.
  local sigX = txBodyX - G.x(8.4) - G.x(21.6)
  local timerW = math.max(90, G.x(100))
  local timerX = t.x + math.floor((t.w - timerW) / 2)
  local modelNameX = t.x + math.max(5, G.x(6))
  local modelNameW = math.max(90, timerX - modelNameX - math.max(5, G.x(6)))

  -- On EdgeTX color displays BOLD is a font size of its own, not a style bit.
  -- Combining it with SMLSIZE/MIDSIZE selects an unintended oversized font on
  -- the radio even when a desktop mock happens to look acceptable.
  ui.modelName = newLabel(wgt, modelNameX, t.y + math.max(1, G.y(2)),
                          modelNameW, "", G.fontTop, C_TEXT)
  ui.timer = newLabel(wgt, timerX, t.y + math.max(1, G.y(2)),
                      timerW, "", G.fontTimer, C_TEXT, CENTERED)

  local profileSignalGap = math.max(8, G.x(10))
  local profileMinW = #"Profile 6 / Rate 6" * 9
  local profileX = math.min(timerX + timerW - math.max(20, G.x(28)),
                            sigX - profileSignalGap - profileMinW)
  local profileY = math.floor(centerY - 11)
  if G.screenW == 480 and G.screenH == 320
     and G.w == 480 and G.h == 320 then profileY = profileY + 2 end
  ui.profileStatus = newLabel(
    wgt, profileX, profileY,
    math.max(1, sigX - profileSignalGap - profileX), "",
    SMLSIZE, C_TEXT, RIGHT)

  -- Match KSE4's ascending four-bar link-quality glyph immediately to the
  -- left of the vertical transmitter-battery indicator.
  ui.signal = {}
  for i, referenceH in ipairs(G.signalHeights) do
    local barH = math.max(1, G.y(referenceH * 2 / 3))
    ui.signal[i] = newRect(wgt,
      sigX + (i - 1) * G.x(6),
      centerY + G.y(20 / 3) - barH,
      math.max(1, G.x(3.6)), barH, C_BORDER, true, 0, 0)
  end

  ui.txBody = newPanel(wgt, txBodyX, txBodyY, txBodyW, txBodyH,
                       C_PANEL_ALT, C_DIM, math.max(1, G.min(2)))
  local terminalW = math.max(4, G.x(5))
  newRect(wgt, txBodyX + math.floor((txBodyW - terminalW) / 2),
          txBodyY - math.max(2, G.y(3)), terminalW,
          math.max(2, G.y(2)), C_DIM, true, 1, 1)
  local txInset = math.max(2, G.min(2))
  ui.txFill = newRect(wgt, txBodyX + txInset,
                      txBodyY + txBodyH - txInset,
                      txBodyW - txInset * 2, 1, C_GREEN, true, 1, 1)
  ui.txBodyX, ui.txBodyY = txBodyX, txBodyY
  ui.txBodyW, ui.txBodyH = txBodyW, txBodyH
  ui.txInset = txInset
end

local RING_LABELS = { "BATTERY", "HEAD RPM", "CURRENT", "ESC TEMP" }
local RING_UNITS = { "%", "RPM", "AMPS", "\xC2\xB0C" }
local RING_STANDARD = {
  bottom=90, span=359, -- EdgeTX: 0 is 3 o'clock; 90 is 6 o'clock.
  rpmMin=500, rpmMax=2400,
  currentMin=0, currentMax=250,
  tempMin=32, tempMax=100,
}
local function buildRingCards(wgt)
  local l, ui = wgt.layout, wgt.ui
  ui.rings = {}
  for i = 1, 4 do
    local card = l.rings[i]
    local panel = newPanel(wgt, card.x, card.y, card.w, card.h,
                           C_PANEL, C_BORDER, math.max(2, G.min(4)))
    local inset = math.max(2, G.x(2))
    local accent = newRect(wgt, card.x + inset, card.y + 1,
                           card.w - inset * 2, 1, C_DIM, true, 1, 1)
    -- Arcs are children of the card fill, so EdgeTX clips overdraw at the card
    -- boundary. Keep their geometry immutable: the radio can displace an arc
    -- when object:set() changes its angles. Dynamic property functions update
    -- only the rendered sweep/color while x, y, and radius remain untouched.
    local cx = math.floor(card.w / 2)
    local cy = l.ringCenterY - card.y
    local arcState = { endAngle=RING_STANDARD.bottom, color=C_DIM, opacity=0 }
    local primaryProperties = {
      x=cx, y=cy, radius=l.ringRadius,
      thickness=l.ringThickness,
      startAngle=RING_STANDARD.bottom,
      endAngle=function() return arcState.endAngle end,
      rounded=true,
      color=function() return arcState.color end,
      opacity=function() return arcState.opacity end,
      bgColor=C_TRACK, bgOpacity=255,
      bgStartAngle=0, bgEndAngle=360,
    }
    local primary = rememberObject(wgt, lvgl.arc(panel.fill, primaryProperties),
                                   primaryProperties)
    local ringLabel = i == 1 and OPT.simTelemetry
                      and "SIM \xC2\xB7 BATTERY" or RING_LABELS[i]
    local label = newLabel(wgt, card.x + inset,
                           card.y + math.max(1, G.y(2)),
                           card.w - inset * 2, ringLabel,
                           G.fontSmall, C_DIM, CENTERED)
    local valueOffset = G.largeScreen and math.max(17, G.y(13)) or 13
    local unitOffset = G.largeScreen and math.max(14, G.y(10)) or 12
    -- Keep value and unit locked together; lift both another 2 px so the
    -- complete text group sits optically centered inside the ring.
    local ringTextLift = G.largeScreen and 6 or 2
    local value = newLabel(wgt, card.x + inset,
                           l.ringCenterY - valueOffset - ringTextLift,
                           card.w - inset * 2, "--", G.fontRingValue,
                           C_TEXT, CENTERED)
    local unit = newLabel(wgt, card.x + inset,
                          l.ringCenterY + unitOffset - ringTextLift,
                          card.w - inset * 2, RING_UNITS[i],
                          G.fontSmall, C_DIM, CENTERED)
    local footer = newLabel(wgt, card.x + inset,
                            card.y + card.h - math.max(16, G.y(16)),
                            card.w - inset * 2, "", G.fontSmall,
                            C_DIM, CENTERED)
    ui.rings[i] = {
      accent=accent, primary=primary, arcState=arcState,
      label=label, value=value, unit=unit, footer=footer,
    }
  end
end

local TILE_LABELS = {
  "GOV MODE", "BEC OUTPUT", "CELL VOLT", "USED CAPACITY",
}
local function buildLowerDashboard(wgt)
  local l, ui = wgt.layout, wgt.ui
  newPanel(wgt, l.modelX, l.modelY, l.modelW, l.modelH,
           C_PANEL, C_BORDER, math.max(2, G.min(4)))
  newRect(wgt, l.modelImageX, l.modelImageY, l.modelImageW,
          l.modelImageH, C_IMAGE_BG, true, math.max(2, G.min(3)), 1)
  local imageProperties = {
    x=l.modelImageX, y=l.modelImageY, w=l.modelImageW, h=l.modelImageH,
    file=function() return resolveModelImagePath() or "" end,
    visible=function() return resolveModelImagePath() ~= nil end,
    fill=false,
  }
  ui.modelImage = rememberObject(wgt, lvgl.image(imageProperties), imageProperties)
  ui.noImage = newLabel(wgt, l.modelImageX, l.modelImageY
                        + math.floor(l.modelImageH / 2) - 8,
                        l.modelImageW, "NO IMAGE", G.fontSmall,
                        C_DIM, CENTERED)
  local imagePath = resolveModelImagePath()
  setVisible(wgt, ui.modelImage, imagePath ~= nil)
  setVisible(wgt, ui.noImage, imagePath == nil)
  local footerY = l.modelY + l.modelH - l.modelFooterH
  local footerInset = math.max(4, G.x(5))
  lvgl.hline({ x=l.modelX + footerInset, y=footerY,
               w=l.modelW - footerInset * 2,
               h=1, color=C_BORDER })
  ui.flightCount = newLabel(wgt, l.modelX + math.max(3, G.x(3)),
                            footerY + math.max(2, G.y(3)),
                            l.modelW - math.max(6, G.x(6)), "", G.fontSmall,
                            C_TEXT, CENTERED)

  ui.tiles = {}
  for i = 1, 4 do
    local tile = l.tiles[i]
    newPanel(wgt, tile.x, tile.y, tile.w, tile.h,
             C_PANEL_ALT, C_BORDER, math.max(2, G.min(4)))
    local accentW = math.max(3, G.x(3))
    local accent = newRect(wgt, tile.x + 1, tile.y + math.max(2, G.y(2)),
                           accentW, tile.h - math.max(4, G.y(4)),
                           C_DIM, true, 1, 1)
    local textX = tile.x + math.max(8, G.x(9))
    local textW = tile.w - math.max(15, G.x(16))
    local label = newLabel(wgt, textX, tile.y + math.max(2, G.y(4)),
                           textW, TILE_LABELS[i], G.fontSmall, C_DIM)
    local valueFont = i == 1 and G.fontGovernorValue or G.fontTileValue
    local valueY = tile.y + math.max(19, G.y(21))
    local valueX, valueW = textX, textW
    local valueAlign = RIGHT
    local persistentValueAlign
    if i == 1 and G.compact then
      -- BOLD is a 20 px line on compact EdgeTX color targets. Center the
      -- governor value horizontally, then lower it 4 px from geometric center
      -- for optical balance inside the tile.
      valueX = tile.x + 4
      valueW = tile.w - 8
      valueY = tile.y + math.floor((tile.h - 20) / 2) + 4
      valueAlign = CENTERED
      persistentValueAlign = CENTERED
    end
    local value = newLabel(wgt, valueX, valueY,
                           valueW, "--", valueFont, C_TEXT, valueAlign)
    local footer = newLabel(wgt, textX,
                            tile.y + tile.h - math.max(16, G.y(17)),
                            textW, "", G.fontSmall, C_DIM, RIGHT)
    ui.tiles[i] = {
      accent=accent, label=label, value=value, footer=footer,
      valueAlign=persistentValueAlign,
    }
  end
end

local function buildProfileEntryPrompt(wgt)
  local l, ui = wgt.layout, wgt.ui
  local promptW = math.min(G.largeScreen and 360 or 250,
                           l.w - math.max(24, G.x(24)))
  local promptH = G.largeScreen and 64 or 56
  local titleOffset = G.largeScreen and 7 or 5
  local detailOffset = G.largeScreen and 39 or 34
  local x = l.x + math.floor((l.w - promptW) / 2)
  local y = l.y + math.floor((l.h - promptH) / 2)
  local compactW = promptW
  local compactH = promptH
  local compactX = l.x + math.floor((l.w - compactW) / 2)
  local compactY = l.y + math.floor((l.h - compactH) / 2)
  local prompt = {
    fill=newRect(wgt, x, y, promptW, promptH, C_PANEL_ALT, true,
                 math.max(3, G.min(6)), 1),
    border=newRect(wgt, x, y, promptW, promptH, C_BORDER, false,
                   math.max(3, G.min(6)), 2),
    accent=newRect(wgt, x + 2, y + 2, math.max(4, G.x(5)), promptH - 4,
                   C_GREEN, true, math.max(1, G.min(2)), 1),
    title=newLabel(wgt, x + 10, y + titleOffset,
                   promptW - 20, "", G.fontSmall, C_TEXT, CENTERED),
    detail=newLabel(wgt, x + 10, y + detailOffset,
                    promptW - 20, "", G.fontSmall, C_DIM, CENTERED),
    full={ x=x, y=y, w=promptW, h=promptH,
           titleX=x + 10, titleY=y + titleOffset, titleW=promptW - 20,
           detailX=x + 10, detailY=y + detailOffset, detailW=promptW - 20 },
    compact={ x=compactX, y=compactY, w=compactW, h=compactH,
              titleX=compactX + 10, titleY=compactY + titleOffset,
              titleW=compactW - 20,
              detailX=compactX + 10, detailY=compactY + detailOffset,
              detailW=compactW - 20 },
  }
  prompt.objects = {
    prompt.fill, prompt.border, prompt.accent, prompt.title, prompt.detail,
  }
  ui.profilePrompt = prompt
  for _, object in ipairs(prompt.objects) do setVisible(wgt, object, false) end
end


local function batteryColor(percent)
  local p = tonumber(percent) or 0
  if p >= 50 then return C_GREEN end
  if p >= 20 then return C_YELLOW end
  return C_RED
end

local function txBatteryColor(percent)
  local p = math.floor((tonumber(percent) or 0) + 0.5)
  if p >= 51 then return C_GREEN end
  if p >= 31 then return C_YELLOW end
  return C_RED
end

local function becValueColor(volts)
  local v = tonumber(volts)
  if not v then return C_DIM end
  if v < 4.8 then return C_RED end
  if v < 5.1 then return C_YELLOW end
  return C_TEXT
end

local function formatTimer(seconds)
  local value = math.abs(tonumber(seconds) or 0)
  local minutes = math.floor(value / 60)
  local secs = math.floor(value - minutes * 60)
  return string.format("%d:%02d", minutes, secs)
end

local function updateTopBar(wgt)
  local ui = wgt.ui
  local maxModelChars = G.largeScreen and 28 or 16
  if OPT.simTelemetry then maxModelChars = G.largeScreen and 22 or 10 end
  local modelName = compactModelName(wgt, maxModelChars)
  if OPT.simTelemetry then modelName = "SIM \xC2\xB7 " .. modelName end
  setLabel(wgt, ui.modelName, modelName, C_TEXT)
  setLabel(wgt, ui.timer, formatTimer(getTimer1Secs()), C_TEXT)

  local rq = getRqly()
  local bars = rq >= 80 and 4 or rq >= 60 and 3
               or rq >= 40 and 2 or rq >= 20 and 1 or 0
  local signalColor = bars >= 3 and C_GREEN
                      or bars == 2 and C_YELLOW or C_RED
  for i, bar in ipairs(ui.signal or {}) do
    setObject(wgt, bar, { color=i <= bars and signalColor or C_BORDER })
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
  setLabel(wgt, ui.profileStatus,
    profilesReady and string.format("Profile %d / Rate %d",
      pidProfile, rateProfile) or "", C_TEXT)

  local txPct = txPctFromVolts(getTxVolt(), txIsLiIon)
  if txPct then
    local innerH = ui.txBodyH - ui.txInset * 2
    local fillH = math.max(1, math.floor(innerH * clamp(txPct, 0, 100) / 100))
    setObject(wgt, ui.txFill, {
      y=ui.txBodyY + ui.txBodyH - ui.txInset - fillH,
      w=ui.txBodyW - ui.txInset * 2,
      h=fillH, color=txBatteryColor(txPct),
    })
    setVisible(wgt, ui.txFill, true)
  else
    setVisible(wgt, ui.txFill, false)
  end
end

local function updateRing(wgt, index, value, unit, footer, progress, color,
                          valid, footerColor, invalidMessage)
  local ring = wgt.ui.rings[index]
  local p = valid and clamp(tonumber(progress) or 0, 0, 1) or 0
  local activeColor = valid and (color or C_DIM) or C_DIM
  local sweep = round(p * RING_STANDARD.span)
  setObject(wgt, ring.accent, { color=activeColor })
  -- EdgeTX evaluates these functions from the retained arc without a set()
  -- call, preventing telemetry changes from disturbing the arc geometry.
  ring.arcState.endAngle = (RING_STANDARD.bottom + sweep) % 360
  ring.arcState.color = activeColor
  ring.arcState.opacity = (valid and sweep > 0) and 255 or 0
  local missingText = invalidMessage
                      or (A.linkAvailable and "NO SENSOR" or "")
  setLabel(wgt, ring.value, valid and value or "--", valid and C_TEXT or C_DIM)
  setLabel(wgt, ring.unit, unit, C_DIM)
  setLabel(wgt, ring.footer, valid and footer or missingText,
           valid and (footerColor or C_DIM) or C_DIM)
end

local function batteryFooter()
  if not OPT.simTelemetry and A.motorConfigError then
    return G.compact and "SET MOTOR SW" or "SET MOTOR SWITCH"
  end
  if OPT.heliType == HELI_NITRO then
    if not OPT.rxPackValid then return "INVALID RX RANGE" end
    return D.rxVoltage and string.format("RX %.2fV", D.rxVoltage) or "NO TELEMETRY"
  end
  if OPT.heliType == HELI_OMPHOBBY and getCellCount() == 0 then
    return "ADD M1/M2 NAME"
  end
  local parts = {}
  local profile = getBattProfile()
  if OPT.heliType == HELI_ELECTRIC and profile and profile > 0 then
    parts[#parts+1] = "P" .. tostring(math.floor(profile))
  end
  if D.cellCountValid then parts[#parts+1] = tostring(D.cellsResolved) .. "S" end
  if D.packVoltageValid then parts[#parts+1] = string.format("%.1fV", D.voltage) end
  return #parts > 0 and table.concat(parts, " ") or "SMART FUEL"
end

local function batteryInvalidMessage()
  if not OPT.simTelemetry and A.motorConfigError then
    return G.compact and "SET MOTOR SW" or "SET MOTOR SWITCH"
  end
  if OPT.heliType == HELI_NITRO and not OPT.rxPackValid then
    return "CHECK RX RANGE"
  end
  if OPT.heliType == HELI_OMPHOBBY and getCellCount() == 0 then
    return "ADD M1/M2 NAME"
  end
  return A.linkAvailable and "NO BATTERY DATA" or ""
end

local function updateRings(wgt)
  local batteryValid, batteryPct
  if OPT.heliType == HELI_NITRO then
    batteryValid = OPT.rxPackValid and D.rxVoltage ~= nil and D.rxVoltage > 0
    batteryPct = D.rxPercent or 0
  else
    batteryValid = D.hasBattData
    batteryPct = A.displayPercentInit and A.displayPercent or D.adjustedPercent
  end
  updateRing(wgt, 1, tostring(math.floor(batteryPct or 0)), "%",
    batteryFooter(), (batteryPct or 0) / 100,
    batteryColor(batteryPct), batteryValid, C_DIM,
    batteryInvalidMessage())

  local rpm = getHeadspeed()
  updateRing(wgt, 2, tostring(math.floor(rpm or 0)), "RPM",
    string.format("MAX %d", math.floor(statRpmMax())),
    ((rpm or 0) - RING_STANDARD.rpmMin)
      / (RING_STANDARD.rpmMax - RING_STANDARD.rpmMin),
    C_ACCENT, D.rpmValid, C_YELLOW)

  local curr = getCurr()
  local currentValid = OPT.heliType ~= HELI_NITRO and D.currentValid
  updateRing(wgt, 3, tostring(math.ceil(curr or 0)), "AMPS",
    string.format("MAX %dA", math.ceil(statCurrMax())),
    ((curr or 0) - RING_STANDARD.currentMin)
      / (RING_STANDARD.currentMax - RING_STANDARD.currentMin),
    C_BLUE, currentValid, C_YELLOW,
    OPT.heliType == HELI_NITRO and "NOT USED" or nil)

  local temp = getTemp()
  local tempValid = OPT.heliType ~= HELI_NITRO and D.tempValid
  updateRing(wgt, 4, tostring(math.floor(temp or 0)), "\xC2\xB0C",
    string.format("MAX %d\xC2\xB0C", math.floor(statTempMax())),
    ((temp or 0) - RING_STANDARD.tempMin)
      / (RING_STANDARD.tempMax - RING_STANDARD.tempMin),
    C_ORANGE, tempValid, C_YELLOW,
    OPT.heliType == HELI_NITRO and "NOT USED" or nil)
end

local function updateTile(wgt, index, value, footer, accent, valid,
                          valueColor, footerColor, align)
  local tile = wgt.ui.tiles[index]
  setObject(wgt, tile.accent, { color=valid and accent or C_DIM })
  setLabel(wgt, tile.value, valid and value or "--",
           valid and (valueColor or C_TEXT) or C_DIM,
           align or tile.valueAlign or (valid and RIGHT or CENTERED))
  setLabel(wgt, tile.footer, valid and footer or "", footerColor or C_DIM)
end

local function updateLowerDashboard(wgt)
  local ui = wgt.ui
  local imagePath = resolveModelImagePath()
  setVisible(wgt, ui.modelImage, imagePath ~= nil)
  setVisible(wgt, ui.noImage, imagePath == nil)
  local flightCount = getFlightCount()
  local flightText
  local flightColor = C_TEXT
  if OPT.flightCounter == FC.ROTORFLIGHT then
    if flightCount ~= nil then
      flightText = string.format("%d Flights", flightCount)
      if FC.stale then flightColor = C_YELLOW end
    else
      flightText = FC.status or "WAITING"
      flightColor = (FC.status == "STARTING" or FC.status == "WAITING"
                     or FC.status == "LOADING") and C_YELLOW or C_RED
    end
  else
    flightText = string.format("%d Flights", flightCount or 0)
    if A.flightSaveError then flightText = flightText .. "  SAVE ERROR" end
    if A.flightSaveError then flightColor = C_RED end
  end
  if wgt.profileConnectedForDisplay then
    flightText = flightText .. " - Connected"
  end
  setLabel(wgt, ui.flightCount, flightText,
           flightColor)

  local govState = getGovState()
  local govValid = OPT.heliType ~= HELI_OMPHOBBY and D.govValid
  updateTile(wgt, 1, govState, "",
    GOV_COLOR[govState] or GOV_FALLBACK, govValid,
    GOV_COLOR[govState] or GOV_FALLBACK)

  local bec = getBec()
  local becValid = OPT.heliType ~= HELI_OMPHOBBY and D.becValid
  local becFooter = statBecMin() and string.format("LOW %.1fV", statBecMin()) or ""
  setLabel(wgt, ui.tiles[2].label,
           OPT.heliType == HELI_NITRO and "BATT OUTPUT" or "BEC OUTPUT", C_DIM)
  updateTile(wgt, 2, string.format("%.1fV", bec or 0), becFooter,
    becValueColor(bec), becValid, becValueColor(bec))

  local cell, cellMin, cellValid
  if OPT.heliType == HELI_NITRO then
    cell = D.rxCellVoltage
    cellMin = D.minRxVoltage and D.minRxVoltage / 2 or nil
    cellValid = cell ~= nil and cell > 0
  else
    cell = getCellVoltage()
    cellMin = statCellMin()
    cellValid = D.cellVoltageValid
  end
  local cellColor = C_TEXT
  if OPT.heliType ~= HELI_NITRO and cellMin
     and cellMin <= SAFETY.cellRedThreshold then cellColor = C_RED end
  updateTile(wgt, 3, string.format("%.2fV", cell or 0),
    cellMin and string.format("LOW %.2fV", cellMin) or "",
    cellColor, cellValid, cellColor)

  updateTile(wgt, 4, tostring(math.floor(D.capacity or 0)), "mAh",
    C_ACCENT, D.capacityValid)
end

local function updateUiState(wgt)
  if not wgt.uiBuilt then return end
  updateTopBar(wgt)
  updateRings(wgt)
  updateLowerDashboard(wgt)
end

-- RotorFlight 2.3 battery-profile picker ------------------------------------
-- RF Tool owns the telemetry transport and publishes its connection state and
-- MSP queue for other EdgeTX widgets. KSE5 deliberately uses that API as
-- its sole profile transport so it never competes for telemetry frames.
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
local PROFILE_SELECTION_NOTICE = 100 -- EdgeTX ticks: maximum one second
local PROFILE_CONNECT_SETTLE = 40 -- UltiDash pattern: let RF Tool settle 0.4 s
local PROFILE_HOST_DISCOVERY = 20 -- let an enabled rf2bg function publish first
local PROFILE_READ_TIMEOUT = 800 -- MSP 175 is small; allow slower telemetry links 8 s
local PROFILE_SELECT_TIMEOUT = 2000 -- MSP 176 + 175 verification + EEPROM commit
local PROFILE_CAPACITY_TIMEOUT = 400 -- all six capacities, never wait over 4 seconds
local PROFILE_ACTIVE_CAPACITY_TIMEOUT = 300 -- MSP 130 is a small 12-byte reply
local PROFILE_SNAPSHOT_ACTIVE_TIMEOUT = 500 -- MSP 175 must answer within 5 seconds
local PROFILE_SNAPSHOT_CAPACITY_TIMEOUT = 1200 -- then allow MSP 32 up to 12 seconds
local PROFILE_FLIGHT_STATS_TIMEOUT = 200 -- one command-14 send, two-second reply window

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

  -- RF Tool 2.3 releases before the consumer registration API still publish
  -- the active widget, MSP API version, and queue. Treat that connected core
  -- as a valid provider, but do not accept standalone rf2bg: its custom CRSF
  -- decoder can consume MSP response frames before this queue polls them.
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
  -- A currently serviced external RF Tool owns the one permitted RF2 global
  -- instance, even if it predates the optional consumer-registration API.
  if profileRfToolInstanceLive() or profileRfToolProvider()
     or wgt.profileRfToolHost then return end
  if profileStandaloneRf2bgCore() then
    wgt.profileRfToolHostError = "DISABLE rf2bg SPECIAL FUNCTION"
    return
  end
  local now = profileNow()
  -- EdgeTX may run model special functions just after constructing widgets.
  -- Give rf2bg one scheduler beat to publish its RF2 core before deciding that
  -- KSE5 must create the hidden RF Tool host.
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

  local hostZone = { x=0, y=0, w=1, h=1 }
  local hostOptions = {
    Source=0,
    Color=C_TEXT,
    ["Hide Model"]=1,
    ["Hide State"]=1,
    ["Hide Telemetry"]=1,
    sourceName="",
    sourceUnit="",
  }
  local hostOk, host = pcall(factory, hostZone, hostOptions)
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
  -- When RF Tool is installed as a tile on another EdgeTX screen, its widget
  -- object and queue remain published but that screen may stop receiving
  -- refresh/background time while KSE5 is full screen. Reuse and service that
  -- exact host here; otherwise requests can be queued successfully yet never
  -- transmitted. This also lets the RF Tool tile be removed entirely because
  -- profileStartEmbeddedRfTool() supplies the same host when none exists.
  local host = wgt.profileRfToolHost
               or (shared and type(shared.widget) == "table"
                   and shared.widget or nil)
  if host == wgt.profileRfToolHost and wgt.profileRfToolHostCore
     and shared ~= wgt.profileRfToolHostCore then
    -- A later-starting rf2bg special function replaced the global published by
    -- our hidden host. Drop the stale closure and consume the new shared core.
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

  -- rf2bg's CRSF custom-telemetry decoder pops every waiting CRSF frame and
  -- discards non-custom frames. While one of KSE5's MSP messages is in flight,
  -- poll the MSP queue first and skip that decoder for the entire pass. This is
  -- essential for the slower MSP 32 response; otherwise MSP 175 often works
  -- while the later battery-config reply is consumed before mspQueue sees it.
  local priorityPass = wgt.profileOperation ~= nil
                       or (OPT.heliType ~= HELI_OMPHOBBY
                           and wgt.armingStatusPending == true)
  local priorityServiced = priorityPass and serviceQueue(shared, host) or false

  -- calledFromRefresh=true prevents RF Tool from drawing its own UI. Run its
  -- normal background services only when they cannot steal an in-flight MSP
  -- reply, or when the host is not ready enough for the priority pump.
  if host and type(host.background) == "function" and not priorityServiced then
    local ok = pcall(host.background, host, true)
    if not ok then
      wgt.profileRfToolHostError = "RF TOOL HOST ERROR"
      return
    end
  end

  if not priorityServiced then
    shared = profileRf2()
    serviceQueue(shared, host)
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

local function profileSetFlightCounterStatus(wgt, eligible, connected)
  if not wgt then return end
  local showConnected = eligible and connected or false
  if wgt.profileConnectedForDisplay == showConnected then return end
  wgt.profileConnectedForDisplay = showConnected
  if wgt.uiBuilt then updateLowerDashboard(wgt) end
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

local function profileSetEntryPrompt(wgt, visible, title, detail, color, compact)
  local prompt = wgt.ui and wgt.ui.profilePrompt
  if not prompt then return end
  if visible then
    local geometry = compact and prompt.compact or prompt.full
    setObject(wgt, prompt.fill, {
      x=geometry.x, y=geometry.y, w=geometry.w, h=geometry.h,
    })
    setObject(wgt, prompt.border, {
      x=geometry.x, y=geometry.y, w=geometry.w, h=geometry.h,
    })
    setObject(wgt, prompt.accent, {
      x=geometry.x + 2, y=geometry.y + 2, h=geometry.h - 4,
      color=color or C_GREEN,
    })
    setObject(wgt, prompt.title, {
      x=geometry.titleX, y=geometry.titleY, w=geometry.titleW,
    })
    setObject(wgt, prompt.detail, {
      x=geometry.detailX, y=geometry.detailY, w=geometry.detailW,
    })
    setLabel(wgt, prompt.title, title or "BATTERY PROFILE READY", C_TEXT)
    setLabel(wgt, prompt.detail, detail or "SELECT A BATTERY PROFILE", C_DIM)
  end
  for _, object in ipairs(prompt.objects) do setVisible(wgt, object, visible) end
  if visible and compact then setVisible(wgt, prompt.accent, false) end
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
  if kind == "read" then
    wgt.profileInitialReadFinished = true
    wgt.profileInitialReadValid = false
  end
  if kind == "capacity" then wgt.profileCapacityReadFinished = true end
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
    -- This read is a best-effort enhancement after an already queued profile
    -- selection. Never turn its absence into a profile-selection error.
    profileSetMessage(wgt,
      "PROFILE " .. tostring(operation and operation.target or "")
        .. " SELECTED", C_DIM)
    return
  end
  if kind == "capacity" then
    -- Capacity is optional display data. A slow or unsupported MSP 32 reply
    -- must not turn a usable profile picker into a modal error.
    profileSetMessage(wgt, text or "CAPACITY DATA UNAVAILABLE", C_DIM)
    return
  end
  if kind == "read" then
    -- The six choices can still be used when the active marker is unknown.
    profileSetMessage(wgt, text or "ACTIVE PROFILE UNAVAILABLE", C_YELLOW)
    return
  end
  profileSetMessage(wgt, text or "PROFILE COMMAND FAILED", C_RED)
  profileSetNotice(wgt, "BATTERY PROFILE ERROR",
                   text or "PROFILE COMMAND FAILED", C_RED, 500)
end

local function profileReadbackReceived(wgt, zeroBased, token)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token then return end
  local index = tonumber(zeroBased)
  if not index or index ~= math.floor(index)
     or index < 0 or index >= BATTERY_PROFILE_COUNT then
    profileOperationFailed(wgt, "INVALID PROFILE REPLY", token)
    return
  end

  local displayProfile = index + 1
  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  wgt.profileActive = displayProfile
  wgt.profileInitialReadFinished = true
  wgt.profileInitialReadValid = true
  profileSetMessage(wgt,
    "CURRENT PROFILE " .. tostring(displayProfile), C_DIM)
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
  -- MSP 130 is much smaller than the six-profile MSP 32 response. Queue its
  -- read after selection verification and the EEPROM commit have drained,
  -- never before or by switching profiles behind the user's back.
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

  -- RF 2.3 MSP_BATTERY_STATE: state, cells, configured capacity (U16),
  -- used capacity, voltage, current, remaining %, active profile.
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

local function profileFinishCapacities(wgt, capacities, allProfiles, token)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token
     or operation.kind ~= "capacity" then return end

  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  wgt.profileCapacities = capacities
  wgt.profileCapacitiesReady = true
  wgt.profileCapacitiesComplete = allProfiles
  wgt.profileCapacityReadFinished = true
  profileSetMessage(wgt, "BATTERY PROFILE DATA READY", C_DIM)
end

local function profileDecodeCapacityConfig(wgt, config)
  -- This is RF Tool's supported public callback shape. Rotorflight 2.3 returns
  -- a zero-based table: batteryCapacity[0] through batteryCapacity[5].
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

local function profileCapacityConfigReceived(wgt, config, token)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token
     or operation.kind ~= "capacity" then return end

  local capacities, allProfiles = profileDecodeCapacityConfig(wgt, config)
  if not capacities then
    profileOperationFailed(wgt, "CAPACITY DATA NOT RECEIVED", token)
    return
  end

  profileFinishCapacities(wgt, capacities, allProfiles, token)
end

local function profileDecodeCapacityRaw(wgt, buf)
  -- RF 2.3 appends six little-endian capacities at bytes 16-27. Some radios
  -- have a mixed RF Tool/FC install that returns only the 15-byte legacy body;
  -- byte 1-2 is still the active profile capacity and is useful instead of
  -- incorrectly declaring all capacity data unavailable.
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

local function profileCapacityRawReceived(wgt, buf, token)
  local operation = wgt.profileOperation
  if not operation or operation.token ~= token
     or operation.kind ~= "capacity" then return end

  local capacities, allProfiles = profileDecodeCapacityRaw(wgt, buf)
  if not capacities then
    profileOperationFailed(wgt, "PROFILE CAPACITIES UNAVAILABLE", token)
    return
  end

  profileFinishCapacities(wgt, capacities, allProfiles, token)
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
  -- Do not replace mspQueue.add(), even briefly. RF Tool owns this shared
  -- object and real EdgeTX builds may retain/bind that method differently
  -- from the host harness. The API call is synchronous, so record the queue
  -- before and after it and retain only the newly appended message objects.
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
  -- Older/private queue implementations do not expose messageQueue. The API
  -- call itself is still authoritative there; it began from an idle queue.
  return ok, added > 0 or type(queue.messageQueue) ~= "table"
end

local function profileInstallErrorHandler(messages, failed)
  for _, message in ipairs(messages or {}) do
    if type(message) == "table" then message.errorHandler = failed end
  end
end

-- RotorFlight arming blockers ----------------------------------------------
-- Status is read-only MSP 101. The ARM_SWITCH flag is intentionally omitted
-- from the banner because it is the normal state while the pilot has the arm
-- switch off; every other active flag is a real reason the FC will not arm.
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
  -- During gyro_cal_on_first_arm, RotorFlight remains disarmed and reports
  -- CALIBRATING but intentionally omits ARM_SWITCH so that arm request can
  -- continue once calibration finishes. A real calibration block during an
  -- arm attempt also carries ARM_SWITCH. Use that FC distinction instead of
  -- showing a permanent false blocker while the arm switch is off.
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
  local banner = wgt and wgt.ui and wgt.ui.armingBanner or nil
  if not banner then return end
  local visible = type(wgt.armingBlockerText) == "string"
                  and wgt.armingBlockerText ~= ""
  if visible then
    setLabel(wgt, banner.label, wgt.armingBlockerText, C_TEXT, CENTERED)
  end
  for _, object in ipairs(banner.objects) do
    setVisible(wgt, object, visible)
  end
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
  -- Cancel only when RF Tool's queue contains this KSE5 read and nothing from
  -- another consumer. profileCancelOperationQueue enforces that ownership.
  if not profileCancelOperationQueue(operation) then return false end
  wgt.armingStatusOperation = nil
  wgt.armingStatusPending = false
  wgt.armingStatusNextAt = now + ARMING_STATUS_INTERVAL
  return true
end

-- RotorFlight persistent flight counter ------------------------------------
-- Command 14 is read-only. It is queued only through RF Tool's public API and
-- only after the battery-profile queue is idle. Each queue message remains a
-- single send; after a real arm/disarm event, the widget may issue a bounded
-- series of fresh reads while RotorFlight commits its persistent flight total.
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
  -- RotorFlight can acknowledge command 14 just before its persistent flight
  -- count becomes visible. Do not manufacture a +1; ask for a fresh command-14
  -- reply until the FC reports a changed total or this bounded window expires.
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
        -- RF Tool's official queue retries forever by default. This very long
        -- per-message delay permits the first send but prevents any retry;
        -- profileCheckOperationTimeout releases it after two seconds.
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
    token=token,
    kind=kind,
    target=target,
    startedAt=profileNow(),
    queue=queue,
    messages={},
    stage=kind == "select" and "set" or nil,
  }
  wgt.profileOperation = operation
  wgt.profileBusy = true
  wgt.profilePending = kind == "select" and target or nil
  profileSetMessage(wgt,
    kind == "select" and ("SETTING PROFILE " .. tostring(target) .. "...")
      or (kind == "capacity" and "READING PROFILE CAPACITIES..."
          or (kind == "activeCapacity"
              and ("READING PROFILE " .. tostring(target) .. " mAh...")
                              or "CHECKING CONTROLLER...")),
    C_YELLOW)
  local function failed()
    profileCancelOperationQueue(operation)
    local message = kind == "capacity" and "CAPACITY READ TIMED OUT"
                    or (kind == "activeCapacity"
                        and "ACTIVE CAPACITY NOT RECEIVED"
                    or (kind == "select"
                        and (operation.stage == "save"
                             and "PROFILE ACTIVE BUT SAVE FAILED"
                             or "PROFILE CHANGE NOT CONFIRMED")
                        or "PROFILE REQUEST TIMED OUT"))
    profileOperationFailed(wgt, message, token)
  end
  local function verifiedConfig(_, config)
    local value = type(config) == "table"
                  and type(config.batteryProfile) == "table"
                  and config.batteryProfile.value or nil
    profileReadbackReceived(wgt, value, token)
  end
  local function verifiedRaw(_, buf)
    profileReadbackReceived(wgt, type(buf) == "table" and buf[1] or nil,
      token)
  end
  local function capacitiesConfig(_, config)
    profileCapacityConfigReceived(wgt, config, token)
  end
  local function capacitiesRaw(_, buf)
    profileCapacityRawReceived(wgt, buf, token)
  end
  local function activeCapacityRaw(_, buf)
    profileActiveCapacityReceived(wgt, buf, token)
  end

  if kind == "activeCapacity" then
    local message = {
      command=MSP_BATTERY_STATE,
      processReply=activeCapacityRaw,
      errorHandler=failed,
    }
    operation.messages[#operation.messages + 1] = message
    queue:add(message)
    return true
  end

  if kind == "select" then
    -- Changing the active battery profile is only a mutable runtime update in
    -- RotorFlight. Keep the entire transaction on RF Tool's one shared queue:
    -- set MSP 176, prove the FC accepted it with MSP 175, then persist it with
    -- the same MSP 250 EEPROM command used by RF Tool's Save action. Success
    -- is reported only after the EEPROM command replies.
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

  -- Follow UltiDash's integration path first: ask RF Tool to build and parse
  -- the messages through its public RF2 API modules. Record newly queued
  -- messages without replacing any method on RF Tool's shared queue.
  local api
  local apiCall
  if kind == "capacity" then
    api = profileRfApi("mspBatteryConfig")
    if api and type(api.read) == "function" then
      apiCall = function() api.read(capacitiesConfig, wgt) end
    end
  else
    api = profileRfApi("mspBatteryProfile")
    if api and type(api.read) == "function" then
      apiCall = function() api.read(verifiedConfig, wgt) end
    end
  end
  if apiCall then
    local apiOk, messageAdded =
      profileCallApiAndCollect(queue, operation, apiCall)
    if apiOk and messageAdded then
      profileInstallErrorHandler(operation.messages, failed)
      -- Leave RF Tool's processReply intact. Its public callback supplies
      -- the parsed config object and is the same integration used by its
      -- own Battery page and by UltiDash.
      return true
    end
    profileCancelOperationQueue(operation)
    operation.messages = {}
  end

  -- Compatibility fallback for an older RF Tool core without rf2.useApi().
  if kind == "capacity" then
    local message = {
      command=MSP_BATTERY_CONFIG,
      processReply=capacitiesRaw,
      errorHandler=failed,
    }
    operation.messages[#operation.messages + 1] = message
    queue:add(message)
    return true
  end
  local readMessage = {
    command=MSP_BATTERY_PROFILE,
    processReply=verifiedRaw,
    errorHandler=failed,
  }
  operation.messages[#operation.messages + 1] = readMessage
  queue:add(readMessage)
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
        or "MSP 32 mAh NOT RECEIVED",
      C_YELLOW)
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
    token=token,
    kind="snapshot",
    startedAt=profileNow(),
    queue=queue,
    messages={},
    activeDone=false,
    capacityDone=false,
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

  -- Follow the supported RF Tool 2.3 path used by its own Battery page and by
  -- UltiDash: let mspBatteryProfile and mspBatteryConfig construct and parse
  -- MSP 175/32. The latter exposes batteryCapacity[0]..[5] on MSP API 12.09.
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
      local capacityWrapped = false
      for _, message in ipairs(operation.messages) do
        if message.command == MSP_BATTERY_CONFIG then
          -- RF Tool's 12.09 decoder assumes the full 27-byte response and its
          -- queue deliberately pcall-swallows decoder errors. Capture the raw
          -- body first so a short/variant FC reply is still observable and its
          -- active capacity can be recovered from bytes 1-2.
          message.processReply = capacitiesRaw
          -- Give the larger response breathing room before RF Tool retries it.
          message.retryDelay = 4
          capacityWrapped = true
        end
      end
      if capacityWrapped then
        profileInstallErrorHandler(operation.messages, failed)
        return true
      end
      -- Private queue implementations may hide their queued message objects.
      -- In that case retain RF Tool's parsed callback instead of duplicating
      -- the request merely for diagnostics.
      profileInstallErrorHandler(operation.messages, failed)
      return true
    end
    profileCancelOperationQueue(operation)
    operation.messages = {}
  end

  -- Compatibility fallback for an older/private RF Tool without both public
  -- API modules. The raw decoders accept the RF 2.3 27-byte body and the
  -- 15-byte legacy body.
  local activeMessage = {
    command=MSP_BATTERY_PROFILE,
    processReply=activeRaw,
  }
  local capacityMessage = {
    command=MSP_BATTERY_CONFIG,
    processReply=capacitiesRaw,
    -- A slow telemetry ratio may need longer than RF Tool's default 0.8 s
    -- before the larger response is complete. Avoid restarting it mid-reply.
    retryDelay=4,
  }
  operation.messages[#operation.messages + 1] = activeMessage
  operation.messages[#operation.messages + 1] = capacityMessage
  queue:add(activeMessage)
  queue:add(capacityMessage)

  profileInstallErrorHandler(operation.messages, failed)
  return true
end

local function profileCheckOperationTimeout(wgt, now)
  local operation = wgt.profileOperation
  if not operation then return end
  local timeout
  local timeoutStartedAt = operation.startedAt
  if operation.kind == "snapshot" then
    if operation.activeDone then
      timeout = PROFILE_SNAPSHOT_CAPACITY_TIMEOUT
      timeoutStartedAt = operation.capacityStartedAt or operation.startedAt
    else
      timeout = PROFILE_SNAPSHOT_ACTIVE_TIMEOUT
    end
  elseif operation.kind == "capacity" then
    timeout = PROFILE_CAPACITY_TIMEOUT
  elseif operation.kind == "activeCapacity" then
    timeout = PROFILE_ACTIVE_CAPACITY_TIMEOUT
  elseif operation.kind == "select" then
    timeout = PROFILE_SELECT_TIMEOUT
    timeoutStartedAt = operation.stageStartedAt or operation.startedAt
  elseif operation.kind == "flightStats" then
    timeout = PROFILE_FLIGHT_STATS_TIMEOUT
  else
    timeout = PROFILE_READ_TIMEOUT
  end
  local timedOut = now - timeoutStartedAt >= timeout
  if not timedOut and not wgt.profileQueueFault then return end
  if operation.kind == "flightStats" then
    profileFailFlightStats(wgt, operation.token,
      wgt.profileQueueFault and "QUEUE ERROR" or "NO REPLY")
    wgt.profileQueueFault = nil
    return
  end
  profileCancelOperationQueue(operation)
  local message
  if wgt.profileQueueFault then
    message = "RF TOOL QUEUE ERROR"
  elseif operation.kind == "capacity" then
    message = "CAPACITY READ TIMED OUT"
  elseif operation.kind == "snapshot" then
    message = "PROFILE DATA NOT RECEIVED"
  elseif operation.kind == "activeCapacity" then
    message = "ACTIVE CAPACITY NOT RECEIVED"
  elseif operation.kind == "select" then
    message = operation.stage == "save"
              and "PROFILE ACTIVE BUT SAVE TIMED OUT"
              or "PROFILE CHANGE NOT CONFIRMED"
  else
    message = "PROFILE REQUEST TIMED OUT"
  end
  wgt.profileQueueFault = nil
  profileOperationFailed(wgt, message, operation.token)
end

local function profileCapacityInProgress(wgt)
  local operation = wgt and wgt.profileOperation or nil
  return wgt and wgt.profileBusy and operation
         and (operation.kind == "capacity"
              or operation.kind == "activeCapacity")
end

local function profileStopCapacityRead(wgt)
  if not profileCapacityInProgress(wgt) then return true end
  local operation = wgt.profileOperation
  if not profileCancelOperationQueue(operation) then return false end
  wgt.profileOperation = nil
  wgt.profileBusy = false
  wgt.profilePending = nil
  if operation.kind == "capacity" then
    wgt.profileCapacityReadFinished = true
  end
  profileSetMessage(wgt, "CAPACITY READ SKIPPED", C_DIM)
  return true
end

local function profileSwitchUnsafe(wgt)
  if wgt and wgt.profileRfState == "armed" then
    return true, "DISARM TO CHANGE PROFILE"
  end
  local armRaw, armCurrent = get("ARM")
  local arm = tonumber(armRaw)
  -- Explicit unsafe telemetry blocks the change, but missing ARM, governor,
  -- or headspeed telemetry does not create a permanent lock.
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
  local closeText = "CLOSE"
  if not wgt.profileActive and not wgt.profileCapacitiesReady then
    closeText = "CLOSE - NO MSP 175/32"
  elseif not wgt.profileActive then
    closeText = "CLOSE - NO MSP 175 ACTIVE"
  elseif not wgt.profileCapacitiesReady then
    local length = tonumber(wgt.profileCapacityReplyLength)
    closeText = length and ("CLOSE - MSP 32 " .. tostring(length) .. "B NO mAh")
                or "CLOSE - NO MSP 32 mAh"
  elseif not wgt.profileCapacitiesComplete then
    local length = tonumber(wgt.profileCapacityReplyLength)
    closeText = length and ("CLOSE - MSP 32 " .. tostring(length)
                            .. "B ACTIVE ONLY")
                or "CLOSE - ACTIVE mAh ONLY"
  end
  values[#values + 1] = closeText

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
      local currentState = wgt.profileRfState
      local currentlyReady = profileTransport(wgt) ~= nil
                             and (currentState == "connected"
                                  or currentState == "armed"
                                  or currentState == "disarmed")
      local blockingOperation = wgt.profileBusy
                                and not profileCapacityInProgress(wgt)
      if not currentlyReady or blockingOperation then
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
      -- Leave the native popup callback before touching the RF Tool queue.
      -- The service loop rechecks transport and safety, then starts the write.
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
  if not lvgl or type(lvgl.dialog) ~= "function" then
    return showNativeBatteryProfileMenu(wgt)
  end

  local title = "KSE5 BATTERY PROFILES"
  if wgt.profileActive then
    title = title .. " - P" .. tostring(wgt.profileActive) .. " ACTIVE"
  end
  local dialogW = math.min(400, math.max(240, G.w - 24), G.w)
  local dialogH = math.min(285, math.max(180, G.h - 18), G.h)
  local dialogScaleX = dialogW / 400
  local dialogScaleY = dialogH / 285
  local function dx(value) return math.max(1, G.rounded(value * dialogScaleX)) end
  local function dy(value) return math.max(1, G.rounded(value * dialogScaleY)) end
  local dialogOk, dialog = pcall(lvgl.dialog, {
    title=title,
    w=dialogW,
    h=dialogH,
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
      type="button",
      x=dx(18 + col * 190),
      y=dy(22 + row * 52),
      w=dx(174),
      h=dy(46),
      font=G.fontSmall,
      cornerRadius=math.max(3, G.min(6)),
      color=function()
        if wgt.profileActive == profileIndex then return C_GREEN end
        if wgt.profilePending == profileIndex then return C_YELLOW end
        return C_PANEL_ALT
      end,
      textColor=C_TEXT,
      -- The modal cannot service/update itself. Freeze the completed snapshot
      -- into a plain two-line string before build so EdgeTX does not retain a
      -- stale function result containing only "P1".."P6".
      text=profileButtonText(wgt, profileIndex, true),
      active=function()
        local unsafe = profileSwitchUnsafe(wgt)
        return profileTransport(wgt) ~= nil and not unsafe
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
        -- Defer RF traffic until after EdgeTX has closed this callback/dialog.
        wgt.profileSelectionRequested = profileIndex
        wgt.profileAutoShown = true
        profileSetMessage(wgt,
          "SETTING PROFILE " .. tostring(profileIndex) .. "...", C_YELLOW)
        closeBatteryProfileMenu(wgt)
      end,
    }
  end

  children[#children + 1] = {
    type="label", x=dx(18), y=dy(181), w=dx(364), h=dy(22),
    font=G.fontSmall, color=function()
      local unsafe = profileSwitchUnsafe(wgt)
      return unsafe and C_RED or (wgt.profileMessageColor or C_DIM)
    end,
    align=CENTERED,
    text=(function()
      local unsafe, unsafeMessage = profileSwitchUnsafe(wgt)
      if unsafe then return unsafeMessage end
      if #profileIndexes == 0 then return "NO CONFIGURED PROFILES" end
      return wgt.profileMessage or "SELECT A PROFILE"
    end)(),
  }
  children[#children + 1] = {
    type="button", x=dx(18), y=dy(213), w=dx(174), h=dy(40),
    text="TRY mAh", color=C_PANEL_ALT, textColor=C_TEXT,
    font=G.fontSmall, cornerRadius=math.max(3, G.min(6)),
    active=function() return not wgt.profileBusy end,
    press=function()
      if wgt.profileBusy then return end
      wgt.profileCapacityRefreshRequested = true
      wgt.profileAutoShown = false
      closeBatteryProfileMenu(wgt)
    end,
  }
  children[#children + 1] = {
    type="button", x=dx(208), y=dy(213), w=dx(174), h=dy(40),
    text="CLOSE", color=C_PANEL_ALT, textColor=C_TEXT,
    font=G.fontSmall, cornerRadius=math.max(3, G.min(6)),
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
  -- registerWidget() does not replay the current state. Synchronize it on
  -- every service pass so a widget registered before RF Tool finished loading
  -- cannot remain permanently unaware of an already-connected controller.
  if shared.widget and shared.widget.state then
    wgt.profileRfState = shared.widget.state
  elseif not canRegister and tonumber(shared.apiVersion)
         and tonumber(shared.apiVersion) >= ROTORFLIGHT_23_MSP_API
         and (profileRfToolInstanceLive() == shared
              or profileRadioLinkLive()) then
    -- apiVersion is populated only after RF Tool has received a two-way MSP
    -- reply. Older RF Tool cores and rf2bg do not publish a widget object;
    -- require a current radio link before accepting their initialized core.
    wgt.profileRfState = "connected"
  end
end

local function profileControllerConnected(wgt)
  local state = wgt.profileRfState
  return profileSharedQueue() ~= nil
         and (state == "connected" or state == "armed" or state == "disarmed")
end

local function profileOnlyConfigured(wgt)
  -- Automatic selection is allowed only after a complete MSP 32 snapshot.
  -- A shorter reply may contain just the active profile's capacity and must
  -- never be mistaken for proof that the other five profiles are unused.
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
  if wgt.armingStatusOperation then
    profileCancelOperationQueue(wgt.armingStatusOperation)
  end
  if wgt.profileOperation
     and wgt.profileOperation.kind == "flightStats" then
    profileFailFlightStats(wgt, wgt.profileOperation.token, "DISCONNECTED")
  end
  closeBatteryProfileMenu(wgt)
  profileSetEntryPrompt(wgt, false)
  wgt.profileWasConnected = false
  wgt.profileConnectedForDisplay = false
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
  wgt.profileRfStatusKey = nil
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
    FC.status, FC.wanted = "STACYDASH", false
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

local function profilePointInBatteryCard(wgt, touchState)
  if type(touchState) ~= "table" then return false end
  local x, y = tonumber(touchState.x), tonumber(touchState.y)
  local card = wgt.layout and wgt.layout.rings and wgt.layout.rings[1]
  return x and y and card
         and x >= card.x and x < card.x + card.w
         and y >= card.y and y < card.y + card.h
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
  local providerReady = rfToolNeeded and profileRfToolProvider() ~= nil
  local transportReady = profileEligible and profileTransport(wgt) ~= nil
  local statusKey = tostring(providerReady) .. ":"
                    .. tostring(wgt.profileRfState) .. ":"
                    .. tostring(transportReady)
  if wgt.profileRfStatusKey ~= statusKey then
    wgt.profileRfStatusKey = statusKey
  end

  local linkObserved = profileEligible and A.linkAvailable
  local connected = rfToolNeeded and profileControllerConnected(wgt)
  if allowUi then
    profileSetFlightCounterStatus(wgt, rfToolNeeded, connected)
  end
  if profileEligible and connected then
    wgt.profileDisconnectedSince = nil
    if not wgt.profileWasConnected then
      wgt.profileWasConnected = true
      wgt.profileAutoShown = false
      -- Match UltiDash's controller snapshot: queue the active profile
      -- (MSP 175) and all six configured capacities (MSP 32) together after
      -- the short connection-settle window. The popup opens only after both
      -- callbacks, or after one strict bounded fallback.
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

    transportReady = profileTransport(wgt) ~= nil
    profileCheckOperationTimeout(wgt, now)
    local unsafe, unsafeMessage = profileSwitchUnsafe(wgt)
    local connectionSettled = now >= (wgt.profileConnectReadyAt or now)
    if wgt.profileUnsafe ~= unsafe
       or wgt.profileUnsafeMessage ~= unsafeMessage
       or wgt.profileTransportReady ~= transportReady then
      wgt.profileUnsafe = unsafe
      wgt.profileUnsafeMessage = unsafeMessage
      wgt.profileTransportReady = transportReady
    end
    if transportReady and connectionSettled and not unsafe
       and not wgt.profileInitialReadRequested
       and not wgt.profileCapacityReadRequested and not wgt.profileBusy then
      profileBeginSnapshot(wgt)
    end

    -- lvgl.dialog is modal: on affected EdgeTX builds it suspends this widget's
    -- refresh/background service. Keep it closed until the hidden RF Tool host
    -- has finished MSP 32, otherwise the dialog itself freezes the queue that
    -- must deliver the capacities. A bounded failure still marks this ready.
    local snapshotReady = wgt.profileInitialReadFinished
                          and wgt.profileCapacityReadFinished
    local onlyProfile = snapshotReady and profileOnlyConfigured(wgt) or nil
    if onlyProfile then
      -- A capacity of zero means that profile is not configured. When exactly
      -- one of the six profiles is configured, use it without asking the user
      -- to choose. The normal armed-state gate still protects the MSP 176
      -- write, so a required change waits quietly until the model is disarmed.
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
      -- A user choice takes priority over optional display data. Cancel only
      -- when the RF Tool queue contains KSE5's own capacity message.
      profileStopCapacityRead(wgt)
    end
    if requestedProfile and not wgt.profileBusy then
      wgt.profileSelectionRequested = nil
      transportReady = profileTransport(wgt) ~= nil
      local blocked, blockedMessage = profileSwitchUnsafe(wgt)
      if not transportReady then
        profileSetMessage(wgt, profileRfToolStatus(wgt), C_RED)
        profileSetNotice(wgt, "BATTERY PROFILE ERROR",
                         profileRfToolStatus(wgt), C_RED, 500)
      elseif blocked then
        profileSetMessage(wgt, blockedMessage, C_RED)
        profileSetNotice(wgt, "PROFILE CHANGE LOCKED",
                         blockedMessage, C_RED, 500)
      else
        if not profileBeginOperation(wgt, "select", requestedProfile) then
          wgt.profileSelectionRequested = requestedProfile
        else
          selectionQueuedThisPass = true
        end
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
        profileSetEntryPrompt(wgt, true, "BATTERY PROFILES",
                              wgt.profileMessage or "READING CONTROLLER...",
                              C_YELLOW)
      elseif wgt.profileNoticeUntil and now < wgt.profileNoticeUntil then
        profileSetEntryPrompt(wgt, true,
                              wgt.profileNoticeTitle,
                              wgt.profileNoticeDetail,
                              wgt.profileNoticeColor,
                              wgt.profileNoticeCompact)
      elseif snapshotReady and not wgt.profileAutoShown
             and (not wgt.profileMenuRetryAt
                  or now >= wgt.profileMenuRetryAt) then
        profileSetEntryPrompt(wgt, false)
        local opened = showBatteryProfileMenu(wgt) == true
        wgt.profileAutoShown = opened
        if not opened then wgt.profileMenuRetryAt = now + 500 end
      elseif not snapshotReady and not wgt.profileAutoShown then
        profileSetEntryPrompt(wgt, true,
          unsafe and "BATTERY PROFILE LOCKED" or "READING BATTERY PROFILES",
          wgt.profileMessage or "WAITING FOR RF TOOL...",
          unsafe and C_RED or C_YELLOW)
      else
        profileSetEntryPrompt(wgt, false)
      end
    end

    -- Touch events are available in EdgeTX's interactive widget/App surface;
    -- tapping the battery card reopens the KSE5 dialog after it was dismissed.
    if wasAutoShown and snapshotReady
       and (not wgt.profileBusy or profileCapacityInProgress(wgt))
       and EVT_TOUCH_TAP
       and event == EVT_TOUCH_TAP
       and profilePointInBatteryCard(wgt, touchState) then
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

    -- Connection/setup status is display-only. All profile traffic still
    -- belongs to RF Tool's shared MSP queue.
    if allowUi then profileSetEntryPrompt(wgt, false) end
    if not linkObserved then wgt.profileAutoShown = false end
  end
  -- Flight statistics are model-wide and also apply to OMPHOBBY models; only
  -- the battery-profile picker is restricted by its own eligibility rules.
  local controllerConnected = connected == true
  profileServiceFlightCounter(wgt,
    counterEligible and controllerConnected, now)
  local armingConnected = armingEligible and controllerConnected
  profileServiceArmingStatus(wgt, armingConnected, now, allowUi)
end

return {
  service=serviceBatteryProfileFeature,
  reset=profileResetConnection,
  flightSourceChanged=profileFlightCounterSourceChanged,
}
end)()

local function buildUi(wgt)
  if not lvgl then wgt.uiBuilt = false; return end
  lvgl.clear()
  wgt.profileDialog = nil
  wgt.ui = {}
  wgt.objectState = {}
  newRect(wgt, wgt.layout.x, wgt.layout.y, wgt.layout.w,
          wgt.layout.h, C_BG, true, 0, 1)
  buildTopBar(wgt)
  buildRingCards(wgt)
  buildLowerDashboard(wgt)
  if OPT.heliType ~= HELI_OMPHOBBY then
    local bannerY = wgt.layout.top.y + wgt.layout.top.h
    local bannerH = math.max(20, G.y(22))
    local bannerInset = math.max(5, G.x(5))
    local armingBanner = {
      fill=newRect(wgt, wgt.layout.x + bannerInset, bannerY,
                   wgt.layout.w - bannerInset * 2, bannerH, C_RED, true,
                   math.max(2, G.min(3)), 1),
      border=newRect(wgt, wgt.layout.x + bannerInset, bannerY,
                     wgt.layout.w - bannerInset * 2, bannerH,
                     C_YELLOW, false, math.max(2, G.min(3)), 1),
      label=newLabel(wgt, wgt.layout.x + bannerInset * 2,
                     bannerY + math.max(3, G.y(4)),
                     wgt.layout.w - bannerInset * 4, "", G.fontSmall,
                     C_TEXT, CENTERED),
    }
    armingBanner.objects = {
      armingBanner.fill, armingBanner.border, armingBanner.label,
    }
    wgt.ui.armingBanner = armingBanner
    for _, object in ipairs(armingBanner.objects) do
      setVisible(wgt, object, false)
    end
  end
  buildProfileEntryPrompt(wgt)
  if OPT.simTelemetry then applySimulatedTelemetry(frameNow()) end
  wgt.uiBuilt = true
  updateUiState(wgt)
end

local function ensureLayout(wgt, fullScreen)
  local x, y, w, h = G.bounds(wgt.zone, fullScreen)
  local signature = G.signature(x, y, w, h)
  if wgt.layoutSignature == signature then return false end
  wgt.layout = buildLayout(wgt.zone, fullScreen)
  wgt.layoutSignature = signature
  buildUi(wgt)
  return true
end

local function refresh(widget, event, touchState)
  if not widget then return end
  clearFrameCache()
  ensureLayout(widget, event ~= nil)
  if not widget.uiBuilt then buildUi(widget) end
  if OPT.simTelemetry then
    if serviceSimulation(widget) then updateUiState(widget) end
  elseif serviceTelemetry(true) then
    updateUiState(widget)
  end
  batteryProfiles.service(widget, true, event, touchState)
end

local function background(widget)
  if not widget then return end
  clearFrameCache()
  if OPT.simTelemetry then
    serviceSimulation(widget)
  else
    serviceTelemetry(true)
  end
  batteryProfiles.service(widget, false, nil, nil)
end

local function create(zone, options)
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
  local widget = {
    zone=zone,
    options=options or {},
    layout=buildLayout(zone, false),
    uiBuilt=false,
    lastSimTick=-1,
    profileWasConnected=false,
    profileConnectedForDisplay=false,
    profileAutoShown=false,
    profileBusy=false,
  }
  widget.layoutSignature = widget.layout.signature
  batteryProfiles.flightSourceChanged(widget)
  return widget
end

local function update(widget, options)
  widget.options = options or {}
  local previousHeliType = OPT.heliType
  local previousReserve = OPT.reservePct
  local previousRxMin = OPT.rxPackMin
  local previousRxMax = OPT.rxPackMax
  local previousRxValid = OPT.rxPackValid
  local previousMotorSource = SRC.motorSwitch
  local previousSim = OPT.simTelemetry
  local previousFlightCounter = OPT.flightCounter
  applyOptions(options)
  local heliChanged = previousHeliType ~= OPT.heliType
  local reserveChanged = previousReserve ~= OPT.reservePct
  local rxSettingsChanged = previousRxMin ~= OPT.rxPackMin
                            or previousRxMax ~= OPT.rxPackMax
                            or previousRxValid ~= OPT.rxPackValid
  local motorChanged = previousMotorSource ~= SRC.motorSwitch
  local simChanged = previousSim ~= OPT.simTelemetry
  local flightCounterChanged = previousFlightCounter ~= OPT.flightCounter
  if heliChanged or simChanged then
    resetSessionStats()
    resetSessionEvidence()
  else
    if reserveChanged then
      resetBatteryAlertState("flight")
      A.displayPercent = 0
      A.displayPercentInit = false
    end
    if rxSettingsChanged then resetBatteryAlertState("rx") end
  end
  if motorChanged then
    resetMotorAlertGate(frameNow())
    if A.flightDeadVoiceLatched and not A.flightDeadVoiceAcknowledged then
      A.flightDeadVoiceStartPosition = nil
    end
    if A.rxDeadVoiceLatched and not A.rxDeadVoiceAcknowledged then
      A.rxDeadVoiceStartPosition = nil
    end
  end
  if heliChanged or reserveChanged or simChanged then D.hasBattData = false end
  if heliChanged or rxSettingsChanged or simChanged then
    D.rxVoltage, D.rxCellVoltage, D.rxPercent = nil, nil, 0
  end
  if simChanged then
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
  if heliChanged or simChanged then batteryProfiles.reset(widget) end
  A.lastDataTick = -1
  clearFrameCache()
  widget.layout = buildLayout(widget.zone, false)
  widget.layoutSignature = widget.layout.signature
  buildUi(widget)
end

local options = {
  { "Theme",     CHOICE, 1, {
      "Dark", "Light", "Arctic Blue", "Midnight Violet", "Orange",
      "Red", "Blue", "Pink", "Green", "Purple", "Reef", "Royal",
      "Ember", "Graphite", "Glacier", "Sunset", "Synthwave", "Gulf",
      "Voltage", "Titanium Ember", "Aurora", "Desert Night",
    } },
  { "TxBatt",    CHOICE, 1, { "LiPo", "Li-Ion" } },
  { "MinFlight", VALUE, TOPBAR_MIN_DUR_DEFAULT, -30, 120 },
  { "HeliType",  CHOICE, 1, { "Electric", "Nitro", "OMPHOBBY" } },
  { "BattRsv",   VALUE, 20, 0, 50 },
  { "BattVoice", BOOL, 0 },
  { "RxPackMin", STRING, "6.60" },
  { "RxPackMax", STRING, "8.40" },
  { "MotorSw",   SOURCE, (function()
      local info = type(getFieldInfo) == "function" and getFieldInfo("SG") or nil
      return type(info) == "table" and info.id or 0
    end)() },
  { "CountSrc",  CHOICE, 2,
    { "KSE Counter", "RotorFlight", "Sim Preview" } },
}

local OPTION_LABELS = {
  TxBatt="TX Battery",
  MinFlight="KSE Counter Min (sec)",
  HeliType="Heli Type",
  BattRsv="Battery Reserve %",
  BattVoice="Battery Voice",
  RxPackMin="Rx Pack Minimum",
  RxPackMax="Rx Pack Maximum",
  MotorSw="Motor Switch",
  CountSrc="Flight Counter",
}

local function translate(name, language)
  return OPTION_LABELS[name] or name
end

return {
  name="KSE5",
  options=options,
  create=create,
  update=update,
  background=background,
  refresh=refresh,
  translate=translate,
  useLvgl=true,
}
