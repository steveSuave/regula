# Web smoke drive script

Drives the running Flutter web build with Playwright and verifies
rendering by screenshot analysis (no semantics tree — see the Session 7
STATUS gotcha: enabling semantics reroutes canvas clicks to node
centers, so everything is driven by raw coordinates).

```sh
flutter run -d web-server --web-port 8321   # leave running
cd tool/web_smoke
npm install --no-save playwright pngjs
npx playwright install chromium-headless-shell   # first time only
node drive.js
```

`drive.js` currently checks Phase 8 scroll-zoom: places two points,
zooms about a cursor position, and asserts the point blobs spread by
the expected exponential factor with the focal point pinned. Extend it
per phase rather than rewriting from scratch (this file was lost once
already in a session scratchpad).

Blob detection is luminance-based (`r+g+b < 450`): the Material 3
primary purple fails naive per-channel darkness thresholds.
