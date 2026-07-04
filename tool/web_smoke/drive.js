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
//   4. Phase 10 square macro: two taps on the (reloaded, empty) canvas,
//      assert all four sides render and the hidden scaffolding
//      (perpendiculars past the side extents, compass circles) does not.
//   5. Phase 11 keyboard shortcuts: Esc leaves the tool, Ctrl+Z removes
//      the whole square (macro = one undo unit), P + clicks place points,
//      = / 0 zoom in and back about the center, ArrowRight nudges the
//      view, ? raises the cheat-sheet barrier and Esc drops it.

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
// Current action order (main.dart + panels/toolbar.dart, Phase 17):
// 0 file, then the five tool flyout groups — 1 Points, 2 Lines,
// 3 Circles, 4 Angles, 5 Macros — then 6 fit, 7 reset, 8 cheat sheet,
// 9 theme toggle, 10 undo, 11 redo (undo/redo start disabled and greyed
// below the glyph threshold, so a fresh app detects 10 icons and the
// theme toggle is the last — index it from the end, not from the front).
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
  check(icons.length >= 9, `found ${icons.length} app-bar icons (>= 9)`);
  const [fileX, pointsX] = icons;
  const themeX = icons[icons.length - 1];

  // ---- Phase 8: place two points, zoom, blobs spread ----
  // Phase 13: the point tool lives in the Points flyout now (first item);
  // menu rows are 48 px below ~8 px padding. With only 9 icons the whole
  // action cluster sits right of the window midline, so *every* popup
  // menu opens left-aligned to its button (Flutter grows the menu toward
  // the side with more room) — click left of the icon, not right.
  await page.mouse.click(pointsX, 28);
  await page.waitForTimeout(500);
  await page.mouse.click(pointsX - 60, 8 + 24); // first item: Point
  await page.waitForTimeout(300);
  await page.mouse.click(400, 300);
  await page.waitForTimeout(200);
  await page.mouse.click(560, 400);
  await page.waitForTimeout(200);
  await page.keyboard.press('Escape'); // deactivate (no toggle icon anymore)
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
  // Items are 48 px rows below ~8 px padding: New, Open…, Save…. Click
  // left of the icon (see the Points-menu note above).
  await page.mouse.click(fileX, 28);
  await page.waitForTimeout(500);
  const downloadPromise = page.waitForEvent('download', { timeout: 5000 });
  await page.mouse.click(fileX - 30, 8 + 2 * 48 + 24); // third item: Save…
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

  // ---- Phase 10: square macro on the fresh post-reload construction ----
  // Taps at A(400,400), B(520,400) put the derived corners one side
  // length up (y-up world): C(520,280), D(400,280). Side BC lies on the
  // hidden perpendicular's carrier, so pixels beyond the segment extent
  // (x=520 below B) tell "hidden line drawn" from "side drawn" apart.
  const shapesX = icons[5];
  await page.mouse.click(shapesX, 28);
  await page.waitForTimeout(500);
  // The menu would overflow the right window edge, so it opens shifted
  // *left* of the button — click left of shapesX, unlike the file menu.
  await page.mouse.click(shapesX - 60, 8 + 24); // first item: Square
  await page.waitForTimeout(300);
  await page.mouse.click(400, 400);
  await page.waitForTimeout(200);
  await page.mouse.click(520, 400);
  await page.waitForTimeout(400);

  const squareShot = PNG.sync.read(await page.screenshot());
  const darkNear = (x, y, r) => {
    for (let dy = -r; dy <= r; dy++) {
      for (let dx = -r; dx <= r; dx++) {
        const i = (squareShot.width * (y + dy) + x + dx) << 2;
        if (squareShot.data[i] + squareShot.data[i + 1] +
            squareShot.data[i + 2] < 450) return true;
      }
    }
    return false;
  };
  check(darkNear(460, 400, 2) && darkNear(520, 340, 2) &&
        darkNear(460, 280, 2) && darkNear(400, 340, 2),
        'square macro renders all four sides');
  check(darkNear(400, 400, 2) && darkNear(520, 400, 2) &&
        darkNear(520, 280, 2) && darkNear(400, 280, 2),
        'square macro renders all four corner points');
  check(!darkNear(520, 500, 3) && !darkNear(400, 500, 3),
        'hidden perpendiculars do not render past the side extents');
  check(!darkNear(605, 485, 3) && !darkNear(315, 485, 3),
        'hidden compass circles do not render');
  check(!darkNear(460, 340, 3), 'square interior stays empty');

  // ---- Phase 11: keyboard shortcuts ----
  // Esc leaves the still-active square tool; Ctrl+Z then removes the
  // whole square — the macro is one undo unit, so the canvas must be
  // completely empty afterwards.
  await page.keyboard.press('Escape');
  await page.waitForTimeout(200);
  await page.keyboard.press('Control+z');
  await page.waitForTimeout(400);
  const afterUndo = darkBlobs(PNG.sync.read(await page.screenshot()), 70);
  check(afterUndo.length === 0,
        `Ctrl+Z removes the whole square in one step (${afterUndo.length} blobs left)`);

  // P activates the point tool from the keyboard; two clicks place
  // isolated dots (the connected square outline would defeat the blob
  // spread measurement below).
  await page.keyboard.press('p');
  await page.waitForTimeout(200);
  await page.mouse.click(400, 300);
  await page.waitForTimeout(200);
  await page.mouse.click(560, 400);
  await page.waitForTimeout(200);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(200);
  const placed = darkBlobs(PNG.sync.read(await page.screenshot()), 70);
  check(placed.length === 2,
        `P + two clicks place two points (${placed.length} blobs)`);

  // = twice zooms in about the canvas center (1.2 each, spread ×1.44);
  // 0 returns to exactly 100 % keeping the center pinned.
  await page.keyboard.press('=');
  await page.waitForTimeout(150);
  await page.keyboard.press('=');
  await page.waitForTimeout(300);
  const zoomed = darkBlobs(PNG.sync.read(await page.screenshot()), 70);
  const zoomRatio = spread(zoomed) / spread(placed);
  console.log('keyboard zoom spread ratio:', zoomRatio.toFixed(3),
              '(expected ~1.44)');
  check(zoomed.length === 2 && zoomRatio > 1.35 && zoomRatio < 1.55,
        'two = presses spread the points by ~1.44');

  await page.keyboard.press('0');
  await page.waitForTimeout(300);
  const restored = darkBlobs(PNG.sync.read(await page.screenshot()), 70);
  check(restored.length === 2 &&
        Math.abs(spread(restored) - spread(placed)) < 3,
        '0 returns to 100 % (spread back to the original)');

  // ArrowRight looks further right: content shifts 32 px left.
  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(300);
  const nudged = darkBlobs(PNG.sync.read(await page.screenshot()), 70);
  const meanX = (blobs) => blobs.reduce((s, b) => s + b.x, 0) / blobs.length;
  const shift = meanX(nudged) - meanX(restored);
  console.log('nudge shift:', shift.toFixed(1), 'px (expected -32)');
  check(nudged.length === 2 && Math.abs(shift + 32) < 2,
        'ArrowRight nudges the content 32 px left');

  // ? raises the cheat sheet: its barrier darkens the canvas outside
  // the card (sampled left of the centered 780 px card); Esc drops it
  // without disturbing the construction.
  const bareCanvas = await canvasSample(page, 60, 650);
  await page.keyboard.press('?');
  await page.waitForTimeout(400);
  const behindBarrier = await canvasSample(page, 60, 650);
  console.log('cheat-sheet barrier luminance:', bareCanvas, '→', behindBarrier);
  check(bareCanvas > 700 && behindBarrier > 300 && behindBarrier < 620,
        '? raises the cheat-sheet barrier');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);
  check(await canvasSample(page, 60, 650) > 700,
        'Esc drops the cheat sheet');
  const afterSheet = darkBlobs(PNG.sync.read(await page.screenshot()), 70);
  check(afterSheet.length === 2, 'the construction survived the sheet');

  console.log('console errors:', errors.length ? errors : 'none');
  check(errors.length === 0, 'no console errors');

  console.log(failures.length ? 'SMOKE FAIL' : 'SMOKE PASS');
  await browser.close();
  process.exit(failures.length ? 1 : 0);
})();
