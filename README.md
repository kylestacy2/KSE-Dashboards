# KSE Dashboards for EdgeTX

KSE4 and KSE5 are full-screen EdgeTX telemetry dashboards for RC helicopters. They provide the same core flight information, alerts, battery-profile support, Rotorflight diagnostics, and flight-counter choices. The main difference is the dashboard layout and visual style:

- **KSE4** uses the original information-dense dashboard with a large theme selection.
- **KSE5** uses the newer ring-style dashboard with a smaller, curated theme selection.

Choose the version whose layout you prefer. Both versions can be installed on the same radio, but only one needs to be added to a telemetry screen.

> **Safety:** These widgets are informational aids. They do not replace correctly configured radio alarms, motor safety, telemetry-loss warnings, or failsafe settings. Bench-test a new installation with the motor physically unable to start before flying.

## What is included

Each widget folder contains:

- `main.lua` — the EdgeTX widget source.
- `default.png` — the supplied fallback model image.
- `default1.png` — an alternate fallback image supplied with both widgets.
- `BatterySounds/` — battery percentage announcements and the repeating critical-battery warning.

This repository intentionally does **not** distribute compiled `main.luac` files. If an older installation has a `main.luac`, delete it before installing this source version so EdgeTX cannot run stale compiled code instead of the new `main.lua`.

## Requirements

- One of these supported RadioMaster transmitters running EdgeTX:
  - RadioMaster TX15
  - RadioMaster GX15
  - RadioMaster TX16S MKII
  - RadioMaster TX16S MK3
- A correctly configured Rotorflight helicopter or supported OMPHOBBY model.
- Discovered telemetry sensors using the names listed below.
- The complete official Rotorflight 2.3 EdgeTX Lua package for RF Tool features.

Download the current package from the [official Rotorflight Lua Scripts releases](https://github.com/rotorflight/rotorflight-lua-scripts/releases/latest). Copy the package contents to the root of the transmitter SD card so these exact paths exist:

```text
/WIDGETS/RfTool/app.lua
/WIDGETS/RfStats/app.lua
/SCRIPTS/RF2/
/SCRIPTS/TOOLS/rf2.lua
```

The folder names and capitalization matter:

- **RfTool** supplies the shared Rotorflight connection and MSP API used by KSE for battery profiles, arming-blocker diagnostics, and the optional Rotorflight FC flight counter.
- **RfStats** is Rotorflight's official companion statistics widget. Keep it in `/WIDGETS/RfStats/` as part of the complete Rotorflight package. It does not have to be added to the same telemetry page as KSE.
- The `mspFlightStats` API used by the FC counter is supplied inside `/SCRIPTS/RF2/`.

## `rf2bg` is not needed

Do **not** configure `rf2bg` as an EdgeTX special function or global function for these dashboards. The current RF Tool widget includes the required background runtime, and KSE starts or reuses that official RF Tool host when needed.

If an older model still has an `rf2bg` function configured, disable it before using KSE. Running a separate `rf2bg` alongside the RF Tool host can create competing Rotorflight background activity.

RF Tool does not need to occupy a visible telemetry-screen slot. KSE can invisibly host the installed `/WIDGETS/RfTool/app.lua` when no active RF Tool widget is available.

## Installation

### 1. Install the Rotorflight Lua package

Install the complete official Rotorflight 2.3 EdgeTX package at the SD-card root. Confirm that both `/WIDGETS/RfTool/` and `/WIDGETS/RfStats/` exist and that `/SCRIPTS/RF2/` is present.

### 2. Choose a dashboard

Download this repository and copy the complete dashboard folder to the transmitter SD card:

```text
KSE4 -> /WIDGETS/KSE4/
KSE5 -> /WIDGETS/KSE5/
```

Keep `main.lua`, the image files, and the complete `BatterySounds` folder together. Do not rename the KSE4 or KSE5 folder because the widget uses absolute paths for its images and sounds.

You may install both folders if you want to compare the two layouts on the radio.

### 3. Remove stale compiled files

Delete an older `/WIDGETS/KSE4/main.luac` or `/WIDGETS/KSE5/main.luac` if present. This repository is source-only and the current `main.lua` should be the version EdgeTX loads.

### 4. Discover telemetry

Power the helicopter, establish the receiver/FC connection, and discover telemetry sensors in the EdgeTX model. Verify the relevant sensor names against the telemetry section below.

### 5. Add the widget

Add `KSE4` or `KSE5` to an EdgeTX telemetry screen. Full-screen use is recommended. Open the widget settings and configure the helicopter type, transmitter battery type, Motor Switch, flight counter, and battery options.

### 6. Bench test

With the motor disconnected or otherwise physically unable to start, verify:

- Live telemetry appears and disappears correctly with the FC connection.
- The selected Motor Switch is the actual physical switch.
- Battery warnings and haptics behave as expected.
- Electric battery-profile changes are blocked while armed, while the governor is running, or while headspeed is present.
- The selected flight counter updates according to its documented behavior.

## RF Tool behavior by model type

| Model and counter | RF Tool used | Battery profiles | Arming diagnostics | Rotorflight FC count |
| --- | ---: | ---: | ---: | ---: |
| Electric + KSE Counter | Yes | Yes | Yes | No |
| Electric + Rotorflight counter | Yes | Yes | Yes | Yes |
| Nitro + KSE Counter | Yes | No | Yes | No |
| Nitro + Rotorflight counter | Yes | No | Yes | Yes |
| OMPHOBBY + KSE Counter | No | No | No | No |
| OMPHOBBY + Rotorflight counter | Yes | No | No | Yes |
| Sim Preview | No | No | No | Simulated only |

Normal dashboard telemetry comes directly from EdgeTX telemetry sensors. RF Tool is used for the additional FC-side operations shown above.

### Electric battery profiles

Battery profiles are available only in Electric mode. After RF Tool connects, KSE reads the active Rotorflight battery profile and all six configured capacities. If exactly one profile has a positive configured capacity, KSE can select it automatically.

A profile change is permitted only when the model is disarmed, the governor is stopped, and headspeed is zero. KSE writes the requested profile, reads it back from the FC, and saves it to FC memory before displaying it as confirmed.

### Nitro mode

Nitro has no battery profiles to load or change. RF Tool remains available for read-only arming-blocker diagnostics and, when selected, the Rotorflight FC flight counter. Nitro receiver-battery information comes from normal EdgeTX `Vbec` telemetry rather than a Rotorflight battery profile.

## KSE4 settings

KSE4 provides these ten settings:

| Setting | Default | Explanation |
| --- | --- | --- |
| **Theme** | Dark | Selects the KSE4 color palette. Choices: Dark, Light, Transparent, Orange, Red, Blue, Pink, Green, Purple, Reef, Royal, Ember, Graphite, Glacier, Sunset, Synthwave, Gulf, Voltage, Transparent Light, Titanium Ember, Aurora, and Desert Night. This changes presentation only. |
| **TX Battery** | LiPo | Selects the voltage mapping for the transmitter battery gauge: 2S LiPo or 2S Li-Ion. It does not affect the helicopter battery calculation. |
| **Min. Flight Time (sec)** | 60 | Minimum Timer 1 elapsed time required by the KSE Counter. It does not change Rotorflight FC's own minimum armed-time setting. |
| **Heli Type** | Electric | Selects Electric, Nitro, or OMPHOBBY telemetry and battery behavior. Electric supports Rotorflight battery profiles; Nitro uses receiver-pack voltage and has no battery profiles; OMPHOBBY uses its own telemetry names. |
| **Batt Reserve %** | 20 | Re-scales Electric and OMPHOBBY flight-pack percentage so the selected reserve is displayed as 0%. Range: 0–50%. It does not affect Nitro. |
| **Battery Voice** | Off | Enables the supplied percentage announcements for Electric/OMPHOBBY and critical `dead.wav` warnings. Safety haptics can still operate independently. |
| **Rx Pack Minimum** | 6.60 | Nitro receiver-pack voltage represented as 0%. Valid minimum is at least 4.0 V. |
| **Rx Pack Maximum** | 8.40 | Nitro receiver-pack voltage represented as 100%. Valid maximum is no more than 9.0 V and must be at least 0.1 V above the minimum. |
| **Motor Switch** | Unset | Select the whole physical motor switch, such as `SG`, not an individual position condition or output channel. The widget detects switch movement and validates stopped/running state with current aircraft telemetry. |
| **Flight Counter** | KSE Counter | `KSE Counter` uses Timer 1 and `/flights-count.csv`; `Rotorflight FC` reads the FC's persistent qualified-flight total through RF Tool; `Sim Preview` displays synthetic values for layout review and does not use live RF Tool or telemetry. |

## KSE5 settings

KSE5 provides the same functional settings with a different Theme list:

| Setting | Default | Explanation |
| --- | --- | --- |
| **Theme** | Dark | Selects Dark, Light, Arctic Blue, Midnight Violet, or Orange. This changes presentation only. |
| **TX Battery** | LiPo | Selects the voltage mapping for the transmitter battery gauge: 2S LiPo or 2S Li-Ion. It does not affect the helicopter battery calculation. |
| **Min. Flight Time (sec)** | 60 | Minimum Timer 1 elapsed time required by the KSE Counter. It does not change Rotorflight FC's own minimum armed-time setting. |
| **Heli Type** | Electric | Selects Electric, Nitro, or OMPHOBBY telemetry and battery behavior. Electric supports Rotorflight battery profiles; Nitro uses receiver-pack voltage and has no battery profiles; OMPHOBBY uses its own telemetry names. |
| **Battery Reserve %** | 20 | Re-scales Electric and OMPHOBBY flight-pack percentage so the selected reserve is displayed as 0%. Range: 0–50%. It does not affect Nitro. |
| **Battery Voice** | Off | Enables the supplied percentage announcements for Electric/OMPHOBBY and critical `dead.wav` warnings. Safety haptics can still operate independently. |
| **Rx Pack Minimum** | 6.60 | Nitro receiver-pack voltage represented as 0%. Valid minimum is at least 4.0 V. |
| **Rx Pack Maximum** | 8.40 | Nitro receiver-pack voltage represented as 100%. Valid maximum is no more than 9.0 V and must be at least 0.1 V above the minimum. |
| **Motor Switch** | Unset | Select the whole physical motor switch, such as `SG`, not an individual position condition or output channel. The widget detects switch movement and validates stopped/running state with current aircraft telemetry. |
| **Flight Counter** | KSE Counter | `KSE Counter` uses Timer 1 and `/flights-count.csv`; `RotorFlight` reads the FC's persistent qualified-flight total through RF Tool; `Sim Preview` displays synthetic values for layout review and does not use live RF Tool or telemetry. |

## Flight-counter setup

### KSE Counter

The KSE Counter is stored per model in `/flights-count.csv` at the root of the SD card. It uses EdgeTX Timer 1:

1. Configure Timer 1 to run from the appropriate motor-active condition.
2. Set **Min. Flight Time (sec)** to the desired qualification time.
3. After Timer 1 has reached that duration, resetting Timer 1 counts one KSE flight.

The widget does not configure, start, stop, or reset Timer 1 for you.

### Rotorflight FC counter

The Rotorflight counter reads the FC-owned total through RF Tool. It does not write or reset the FC count and never combines it with `/flights-count.csv`.

For this mode:

- Enable model statistics in Rotorflight/RF Tool.
- Configure the desired Rotorflight minimum armed time.
- Discover and retain the `ARM` telemetry sensor.
- Keep the complete `/WIDGETS/RfTool/` and `/SCRIPTS/RF2/` package installed.

The displayed FC total represents Rotorflight-qualified arm/disarm cycles. Multiple qualifying re-arms during one powered session can therefore add multiple flights.

## Telemetry sensor names

Sensor names are case-sensitive. Discover telemetry while the receiver and FC are connected.

### Common sensors

| Sensor | Purpose |
| --- | --- |
| `RQly`, `RQLY`, or `LQ` | Link-quality display and connection evidence. |
| `ARM` | Armed/disarmed safety state for the Rotorflight FC counter and profile-change checks. |

### Rotorflight Electric and Nitro

| Sensor | Purpose |
| --- | --- |
| `Hspd` | Main headspeed, maximum headspeed, and Electric stopped-rotor proof. |
| `Tspd` | Tail-rotor speed display. |
| `Vbec` | Electric BEC voltage or Nitro receiver-pack voltage. Nitro battery percentage and warnings use this sensor. |
| `Vcel` | Electric cell voltage and minimum-cell tracking. |
| `Cel#` | Electric cell-count display. |
| `Curr` | Current and maximum-current display. |
| `Capa` | Used capacity. |
| `Bat%` | Rotorflight battery percentage, including Smart Fuel when configured on the FC. |
| `Tesc` | ESC temperature and temperature warning. |
| `Gov` | Rotorflight governor state. |
| `BAT#` | Active Electric battery-profile telemetry. |
| `Vbat` | Electric pack voltage and connected-pack evidence. |

### OMPHOBBY

| Sensor | Purpose |
| --- | --- |
| `NR` | Main rotor speed and stopped-rotor proof. |
| `RxBt` | Flight-pack voltage. |
| `Curr` | Current. |
| `Capa` | Used capacity. |
| `Bat%` | Battery percentage. |
| `Tmp` | Temperature. |

The OMPHOBBY model name should contain `M1` or `M2` so the widget can derive the expected cell count. OMPHOBBY mode does not use tail-RPM, governor, BEC, or Rotorflight battery-profile telemetry.

## Model images

The supplied `default.png` is used when no model-specific image is found. Custom and replacement KSE images must meet both of these limits:

- Maximum dimensions: **480 × 272 pixels**.
- Maximum file size: **100 KB**.

Smaller images are acceptable and will be scaled to fit the available image area. Do not use an image that exceeds either limit; oversized images consume additional radio memory and may reduce interface performance or fail to load reliably.

For a custom image, place a PNG or BMP in `/IMAGES/` using the EdgeTX model name as the filename:

```text
Model name: Goblin RAW
Image: /IMAGES/Goblin RAW.png
```

Characters that are unsuitable for filenames are replaced with underscores. For example, `Goblin/RAW` uses `/IMAGES/Goblin_RAW.png`.

Both KSE4 and KSE5 also include `default1.png` as an alternate fallback image. The widgets load `default.png`, so to use the alternate image:

1. Back up or rename the existing `default.png`.
2. Rename `default1.png` to `default.png` inside the selected KSE4 or KSE5 folder.
3. Restart EdgeTX or reload the widget.

The filename must be exactly `default.png`; leaving the alternate image named `default1.png` will not change the displayed fallback.

## Troubleshooting

| Problem | Check |
| --- | --- |
| Widget does not appear | Confirm the exact `/WIDGETS/KSE4/main.lua` or `/WIDGETS/KSE5/main.lua` path, then restart EdgeTX. |
| Old behavior remains | Delete any stale `main.luac` from the KSE folder and restart the radio. |
| `INSTALL RF TOOL` or no RF connection | Confirm `/WIDGETS/RfTool/app.lua`, `/WIDGETS/RfStats/app.lua`, and `/SCRIPTS/RF2/` came from the same current Rotorflight package. |
| Battery profiles do not open | Profiles are Electric-only. Confirm RF Tool connection, valid Rotorflight battery capacities, disarmed state, stopped governor, and zero headspeed. |
| Rotorflight FC count is unavailable | Confirm RF Tool 2.3, the `ARM` sensor, enabled Rotorflight model statistics, a disarmed model, and the complete `/SCRIPTS/RF2/` directory. |
| Nitro battery is missing | Nitro uses `Vbec`; it does not load a battery profile. |
| Model image is missing | Match the EdgeTX model name and `/IMAGES/` filename, including capitalization. |
| Telemetry fields show `--` or `NO DATA` | Re-discover sensors and confirm the exact case-sensitive names above. If needed, try pasting the CLI command above for telemetry sensors. |

## Source and updates

KSE4 and KSE5 are maintained together so functional and safety changes can be applied to both variants. The repository publishes readable Lua source rather than a precompiled radio-specific artifact.

## Disclaimer

Use these dashboards entirely at your own risk. They are provided as-is, without warranties or guarantees of any kind. The author assumes zero liability for injury, crashes, loss of a model, property damage, data loss, incorrect telemetry, missed or incorrect warnings, configuration errors, software failure, or any other direct or indirect consequence arising from their installation, use, or misuse. You are solely responsible for verifying your radio, model, telemetry, alarms, motor safety, and failsafe configuration and for performing appropriate motor-disabled bench testing before flight.

Technical support is offered on a friendly, best-effort basis. I will help where my time and knowledge allow, but support may be limited and a response or resolution cannot be guaranteed. This project is not operated as a formal help desk or ticket-based support service, so users are encouraged to follow this guide carefully and share clear details when asking for help.
