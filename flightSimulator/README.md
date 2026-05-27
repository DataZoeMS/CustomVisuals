# Flight Simulator

A 3D flight simulator built as a Power BI custom visual. Features a cockpit view, five working instruments, real satellite ground imagery, collision detection, and engine audio synthesis. Ships with a Sofia (Bulgaria) ground map by default and includes a script to regenerate the map for any city.

![Flight Simulator](screenshot.jpg)

## What It Does

Drop this visual onto a Power BI report page, click it to focus, and fly. You get a first-person cockpit view with a horizon, real satellite ground imagery, sky, and scattered 3D buildings, trees and a small runway. Five flight instruments on the cockpit panel respond in real time to your inputs.

This was built for keynotes and demos -- it tends to get a good reaction when you alt-tab from a slide deck into a live Power BI report and start flying around.

## Controls

| Key          | Action                          |
| ------------ | ------------------------------- |
| Up / Down    | Pitch (nose up / nose down)     |
| Left / Right | Roll (bank left / right)        |
| W / S        | Throttle (increase / decrease)  |
| A / D        | Rudder (yaw left / right)       |
| Space        | Level flight (auto-correct)     |
| R            | Reset / restart                 |
| M            | Toggle mini-map                 |

## Instruments

- **Artificial Horizon** -- shows pitch and roll attitude
- **Altimeter** -- current altitude above ground
- **Airspeed Indicator** -- current forward speed
- **Heading Indicator** -- compass bearing
- **Vertical Speed** -- rate of climb or descent

## Features

- **GPU-accelerated ground rendering** via WebGL with trilinear and anisotropic filtering -- gives a sharp, flicker-free horizon
- Real satellite imagery from Esri World Imagery (4096x4096 mosaic, JPEG-compressed to ~4 MB)
- Synthesised engine audio that responds to throttle position
- Collision detection with buildings, trees, and the ground
- Crash screen with Sofia-themed messages
- Mini-map radar display showing nearby objects
- "Sofia Data Navigator" panel with tongue-in-cheek fake analytics metrics for presentations
- Small runway for fly-in/out fun
- Sofia-flavoured scenery: central tower (Alexander Nevsky-ish), NDK-style hall, boulevard rows, park trees

## Data Roles

| Field    | Type     | Description                       |
| -------- | -------- | --------------------------------- |
| Category | Grouping | Category values for data binding  |
| Measure  | Measure  | Numeric values for data binding   |

The flight simulator runs independently of bound data. Data roles are available for future integration.

## How to Run

```
cd flightSimulator
npm install
pbiviz start
```

Open Power BI and add the Developer Visual to a report page. Click the visual to give it keyboard focus, then use the controls above.

## Changing the Ground Map (any city)

The ground texture is generated from real satellite tiles by `tools/fetch_ground_map.py`. You need Python with Pillow (`pip install Pillow`).

```
# Sofia (default)
python tools/fetch_ground_map.py

# New York
python tools/fetch_ground_map.py --lat 40.7484 --lon -73.9857 --label nyc

# London
python tools/fetch_ground_map.py --lat 51.5074 --lon -0.1278 --label london

# Tokyo
python tools/fetch_ground_map.py --lat 35.6895 --lon 139.6917 --label tokyo
```

The script downloads 256 tiles from Esri World Imagery, stitches them into a 4096x4096 JPEG, and writes the base64-encoded version to `src/ground-map-data.ts` (the visual loads from that to satisfy Power BI's CSP). Run `pbiviz package` afterwards to rebuild the `.pbiviz` with the new map.

Options:

- `--zoom 14` (default): ~9.5 metres per pixel. Lower for wider view, higher for more detail.
- `--tiles 16` (default): grid size, 16x16 = 4096x4096 image. Use 8 for a smaller 2048x2048 image.
- `--quality 85` (default): JPEG quality. 85 is the sweet spot.

Esri World Imagery is free for non-commercial use with attribution.
