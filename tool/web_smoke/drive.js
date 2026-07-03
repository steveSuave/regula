// Web smoke for Phase 8 viewport navigation.
// Drives the Flutter web build by raw coordinates (no semantics — see
// Session 7 STATUS gotcha: semantics reroutes clicks to node centers).
//
// Flow: activate point tool, place two points, deactivate, scroll-zoom
// about a fixed cursor position, then compare screenshots' dark-pixel
// blobs to confirm the points spread apart around the cursor.

const { chromium } = require('playwright');
const { PNG } = require('pngjs');

const URL = 'http://localhost:8321';

// Finds centroids of dark marker blobs in a screenshot, restricted to
// the canvas area (below the app bar). Points render as filled dots.
function darkBlobs(png, minY) {
  const seen = new Uint8Array(png.width * png.height);
  const blobs = [];
  const isDark = (x, y) => {
    const i = (png.width * y + x) << 2;
    const [r, g, b] = [png.data[i], png.data[i + 1], png.data[i + 2]];
    return r + g + b < 450; // M3 primary purple dot on near-white canvas
  };
  for (let y = minY; y < png.height; y++) {
    for (let x = 0; x < png.width; x++) {
      if (seen[png.width * y + x] || !isDark(x, y)) continue;
      // flood fill
      const stack = [[x, y]];
      let sx = 0, sy = 0, n = 0;
      while (stack.length) {
        const [cx, cy] = stack.pop();
        if (cx < 0 || cy < minY || cx >= png.width || cy >= png.height) continue;
        if (seen[png.width * cy + cx] || !isDark(cx, cy)) continue;
        seen[png.width * cy + cx] = 1;
        sx += cx; sy += cy; n++;
        stack.push([cx + 1, cy], [cx - 1, cy], [cx, cy + 1], [cx, cy - 1]);
      }
      if (n >= 12) blobs.push({ x: sx / n, y: sy / n, n });
    }
  }
  return blobs;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1000, height: 700 } });
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e)));

  await page.goto(URL, { waitUntil: 'networkidle' });
  await page.waitForTimeout(4000); // canvaskit warm-up

  // Point tool is the first app-bar action; drive it via tooltip-free
  // raw click: find it by aria-label fallback is unavailable (no
  // semantics), so click by position — actions start right of center.
  // Safer: enable nothing, just probe with keyboard? No shortcuts yet.
  // The point-tool IconButton is the first action; empirically the
  // actions row occupies the app bar's right edge. Click each candidate
  // and verify a point appears after a canvas tap? Keep it simple:
  // the point tool icon sits ~at x = width - 9*48 - some padding. To be
  // robust, screenshot the app bar and click the leftmost action glyph.
  const bar = await page.screenshot();
  const barPng = PNG.sync.read(bar);
  // App bar: y in [0, 56). Find dark glyph columns right of the title.
  const glyphCols = [];
  for (let x = 300; x < barPng.width; x++) {
    let dark = 0;
    for (let y = 8; y < 48; y++) {
      const i = (barPng.width * y + x) << 2;
      if (barPng.data[i] < 120 && barPng.data[i + 1] < 120) dark++;
    }
    glyphCols.push(dark > 0 ? 1 : 0);
  }
  // First run of glyph columns right of x=300 = point-tool icon.
  let runStart = -1;
  for (let i = 0; i < glyphCols.length; i++) {
    if (glyphCols[i]) { runStart = 300 + i; break; }
  }
  if (runStart < 0) throw new Error('no app-bar glyph found');
  const runCols = [];
  for (let i = runStart - 300; i < glyphCols.length && glyphCols[i]; i++) runCols.push(300 + i);
  const toolX = runCols[Math.floor(runCols.length / 2)];
  await page.mouse.click(toolX, 28);
  await page.waitForTimeout(300);

  // Place two points on the canvas (canvas starts below the 56px bar).
  await page.mouse.click(400, 300);
  await page.waitForTimeout(200);
  await page.mouse.click(560, 400);
  await page.waitForTimeout(200);
  // Deactivate the tool (same button toggles off).
  await page.mouse.click(toolX, 28);
  await page.waitForTimeout(300);

  await page.screenshot({ path: 'before.png' });
  const beforeShot = PNG.sync.read(require('fs').readFileSync('before.png'));
  const before = darkBlobs(beforeShot, 70);

  // Scroll-zoom in about (480, 350): 3 wheel notches up.
  await page.mouse.move(480, 350);
  for (let i = 0; i < 3; i++) {
    await page.mouse.wheel(0, -100);
    await page.waitForTimeout(120);
  }
  await page.waitForTimeout(400);

  await page.screenshot({ path: 'after.png' });
  const afterShot = PNG.sync.read(require('fs').readFileSync('after.png'));
  const after = darkBlobs(afterShot, 70);

  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const spread = (blobs) => blobs.length >= 2
    ? Math.max(...blobs.flatMap((p, i) => blobs.slice(i + 1).map((q) => dist(p, q))))
    : 0;

  console.log('before blobs:', JSON.stringify(before));
  console.log('after blobs:', JSON.stringify(after));
  console.log('spread before:', spread(before).toFixed(1),
              'after:', spread(after).toFixed(1));
  console.log('console errors:', errors.length ? errors : 'none');

  const ok = before.length >= 2 && after.length >= 2 &&
    spread(after) > spread(before) * 1.5 && errors.length === 0;
  console.log(ok ? 'SMOKE PASS' : 'SMOKE FAIL');
  await browser.close();
  process.exit(ok ? 0 : 1);
})();
