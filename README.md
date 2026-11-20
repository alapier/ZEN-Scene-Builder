# ZEN Scene Builder

A single-page browser app for assembling true-scale 3D scenes of solar installations: site map underlay, buildings, roads, trackers, inverters, conduit, and an energy estimate with shading.

## Run it

Windows, nothing to install:

1. Double-click `start.bat` (or run `powershell -ExecutionPolicy Bypass -File serve.ps1`).
2. The app opens at http://localhost:5173/.

The app needs an internet connection for three.js, map tiles, terrain heights, building footprints and solar data.

## What is where

| Path | What it is |
|---|---|
| `index.html` | The whole app (three.js r160, no build step) |
| `serve.ps1` | Small local server; stores the model library and saved scenes on disk |
| `library/` | Your own `.glb` models and `library.json` |
| `scenes/` | Saved scenes (`.zenscene.json`), created when you save; not kept in the repository |
| `datasheets/` | Product datasheets the true-scale parts were sized from |

Customer documents (quotes, contracts, pricing, purchase orders, permit sets) and saved scenes are listed in `.gitignore` and are not part of the repository.

## Units and axes

Metres. +X is east, +Z is south, north is −Z.
