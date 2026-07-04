# Web smoke drive script

Drives the running Flutter web build with Playwright and verifies
rendering by screenshot analysis (no semantics tree — see the Session 7
STATUS gotcha: enabling semantics reroutes canvas clicks to node
centers, so everything is driven by raw coordinates).

```sh
flutter build web --release
python3 -m http.server 8321 -d build/web    # leave running
cd tool/web_smoke
npm install --no-save playwright pngjs
npx playwright install chromium-headless-shell   # first time only
node drive.js
```

Serve the *release build statically* — do not point the script at
`flutter run -d web-server`: the debug DWDS server wedges after the
first Playwright session disconnects, and every later page load renders
blank white (Session 13 gotcha; cost real debugging time).

`drive.js` currently checks Phase 8 scroll-zoom (places two points,
zooms about a cursor position, asserts the point blobs spread by the
expected exponential factor with the focal point pinned), Phase 9
persistence + theme (Save… must download a parseable version-1 document
carrying the points and the zoomed viewport; the theme toggle must
darken the canvas and the choice must survive a reload), Phase 10's
square macro (all four sides and corners render, the hidden scaffolding
does not), and Phase 11's keyboard shortcuts (Esc, Ctrl+Z undoing the
whole macro as one unit, `P` point placement, `=`/`0` zoom about the
center, arrow-key nudge, `?` cheat-sheet overlay — real browser key
events end to end). Extend it per phase rather than rewriting from
scratch (this file was lost once already in a session scratchpad).

Blob detection is luminance-based (`r+g+b < 450`): the default object
blue fails naive per-channel darkness thresholds. App-bar icons are
found as dark column runs left-to-right, so the checks index into the
*enabled* actions — disabled undo/redo sit below the glyph threshold.
