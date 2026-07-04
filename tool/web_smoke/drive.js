// Web smoke for Phase 8 (viewport navigation) + Phase 9 (persistence,
// theme). Drives the Flutter web build by raw coordinates (no semantics —
// see Session 7 STATUS gotcha: semantics reroutes clicks to node centers).
//
// Flow:
//   1. Phase 8: activate point tool, place two points, scroll-zoom about a
//      fixed cursor position, confirm the point blobs spread apart.
//   2. Phase 9 save: File > Save…, capture the browser download, assert it
//      parses as a version-1 document with the two points and the zoomed
//      viewport.
//   3. Phase 9 theme: toggle dark, assert the canvas darkens, reload and
//      assert the choice persisted (shared_preferences → localStorage),
//      toggle back to light.

const fs = require('fs');
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
    return r + g + b < 450; // dark object dot on near-white canvas
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

// Centers of the app-bar action icons, left to right (x > 300 skips the
// leading object-tree toggle and the title). Column runs separated by
// less than 8 px merge into one icon (outlined glyphs have gaps).
// Current action order (main.dart): 0 file, 1 point tool, 2 two-point,
// 3 point-on-object, 4 line constructions, 5 circles, 6 angles,
// 7 triangle centers, 8 fit, 9 reset, 10 theme toggle, 11 undo, 12 redo
// (undo/redo start disabled and greyed below the glyph threshold, so a
// fresh app detects 11 icons and the theme toggle is the last).
function appBarIcons(png) {
  const isGlyphCol = (x) => {
    for (let y = 8; y < 48; y++) {
      const i = (png.width * y + x) << 2;
      if (png.data[i] < 120 && png.data[i + 1] < 120) return true;
    }
    return false;
  };
  const icons = [];
  let start = -1, lastGlyph = -1;
  for (let x = 300; x < png.width; x++) {
    if (isGlyphCol(x)) {
      if (start < 0) start = x;
      lastGlyph = x;
    } else if (start >= 0 && x - lastGlyph >= 8) {
      icons.push((start + lastGlyph) / 2);
      start = -1;
    }
  }
  if (start >= 0) icons.push((start + lastGlyph) / 2);
  return icons;
}

async function canvasSample(page, x, y) {
  const shot = PNG.sync.read(await page.screenshot());
  const i = (shot.width * y + x) << 2;
  return shot.data[i] + shot.data[i + 1] + shot.data[i + 2];
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 1000, height: 700 },
    acceptDownloads: true,
  });
  const errors = [];
  const failures = [];
  const check = (ok, label) => {
    console.log((ok ? 'ok   ' : 'FAIL ') + label);
    if (!ok) failures.push(label);
  };
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(String(e)));

  await page.goto(URL, { waitUntil: 'networkidle' });
  await page.waitForTimeout(4000); // canvaskit warm-up

  const icons = appBarIcons(PNG.sync.read(await page.screenshot()));
  console.log('app-bar icons at:', icons.map((x) => x.toFixed(0)).join(' '));
  check(icons.length >= 11, `found ${icons.length} app-bar icons (>= 11)`);
  const [fileX, pointToolX] = icons;
  const themeX = icons[10];

  // ---- Phase 8: place two points, zoom, blobs spread ----
  await page.mouse.click(pointToolX, 28);
  await page.waitForTimeout(300);
  await page.mouse.click(400, 300);
  await page.waitForTimeout(200);
  await page.mouse.click(560, 400);
  await page.waitForTimeout(200);
  await page.mouse.click(pointToolX, 28); // toggle tool off
  await page.waitForTimeout(300);

  const before = darkBlobs(PNG.sync.read(await page.screenshot()), 70);

  await page.mouse.move(480, 350);
  for (let i = 0; i < 3; i++) {
    await page.mouse.wheel(0, -100);
    await page.waitForTimeout(120);
  }
  await page.waitForTimeout(400);

  const after = darkBlobs(PNG.sync.read(await page.screenshot()), 70);

  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const spread = (blobs) => blobs.length >= 2
    ? Math.max(...blobs.flatMap((p, i) => blobs.slice(i + 1).map((q) => dist(p, q))))
    : 0;
  console.log('spread before:', spread(before).toFixed(1),
              'after:', spread(after).toFixed(1));
  check(before.length >= 2 && after.length >= 2 &&
        spread(after) > spread(before) * 1.5,
        'zoom spreads the two point blobs about the cursor');

  // ---- Phase 9: Save… downloads a parseable version-1 document ----
  // The popup opens over the button (top of the bar); items are 48 px
  // rows below ~8 px padding: New, Open…, Save….
  await page.mouse.click(fileX, 28);
  await page.waitForTimeout(500);
  const downloadPromise = page.waitForEvent('download', { timeout: 5000 });
  await page.mouse.click(fileX + 30, 8 + 2 * 48 + 24); // third item: Save…
  let doc = null;
  try {
    const download = await downloadPromise;
    const path = await download.path();
    doc = JSON.parse(fs.readFileSync(path, 'utf8'));
  } catch (e) {
    console.log('download failed:', String(e));
  }
  check(doc !== null, 'Save… triggers a download that parses as JSON');
  if (doc) {
    check(doc.version === 1, 'saved document has version 1');
    check(Array.isArray(doc.objects) && doc.objects.length === 2 &&
          doc.objects.every((o) => o.type === 'FreePoint'),
          'saved document carries the two placed free points');
    check(doc.viewport && doc.viewport.scale > 1.5,
          `saved viewport keeps the zoom (scale ${doc.viewport && doc.viewport.scale})`);
  }
  await page.waitForTimeout(400);

  // ---- Phase 9: theme toggle darkens the canvas and persists ----
  const lightCanvas = await canvasSample(page, 800, 600);
  await page.mouse.click(themeX, 28);
  await page.waitForTimeout(600);
  const darkCanvas = await canvasSample(page, 800, 600);
  console.log('canvas luminance sum light:', lightCanvas, 'dark:', darkCanvas);
  check(lightCanvas > 700 && darkCanvas < 250,
        'theme toggle flips the canvas from light to dark');

  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForTimeout(4000);
  const afterReload = await canvasSample(page, 800, 600);
  check(afterReload < 250, 'dark theme survives a reload (persisted)');

  // Back to light for the next run (same icon position, theme-independent).
  await page.mouse.click(themeX, 28);
  await page.waitForTimeout(600);
  check(await canvasSample(page, 800, 600) > 700, 'toggle back to light');

  console.log('console errors:', errors.length ? errors : 'none');
  check(errors.length === 0, 'no console errors');

  console.log(failures.length ? 'SMOKE FAIL' : 'SMOKE PASS');
  await browser.close();
  process.exit(failures.length ? 1 : 0);
})();
