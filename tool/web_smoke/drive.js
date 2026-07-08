// Web smoke for Phase 8 (viewport navigation) + Phase 9 (persistence,
// theme). Drives the Flutter web build by raw coordinates (no semantics —
// see Session 7 STATUS gotcha: semantics reroutes clicks to node centers).
//
// Flow:
//   1. Phase 8/14: activate point tool, place two points; Ctrl+scroll
//      zooms about a fixed cursor position (blobs spread apart), then a
//      plain scroll *pans* (Phase 14 Figma-style mapping: blobs translate,
//      spread unchanged).
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

// Since Phase 23 every placed point renders a dot *plus* an auto-name
// label ("A") ~(6, -18) px away — one or two raw blobs per point,
// depending on whether antialiased pixels bridge them. Merge blobs
// within 40 px into one marker (pixel-count-weighted centroid) so blob
// counting still means "how many points"; the label offset is constant
// per point, so spread/shift measurements stay valid across shots.
function markers(rawBlobs, radius = 40) {
  const groups = [];
  for (const blob of rawBlobs) {
    const near = groups.find((g) =>
      g.some((m) => Math.hypot(m.x - blob.x, m.y - blob.y) < radius));
    if (near) near.push(blob); else groups.push([blob]);
  }
  return groups.map((g) => {
    const n = g.reduce((s, m) => s + m.n, 0);
    return {
      x: g.reduce((s, m) => s + m.x * m.n, 0) / n,
      y: g.reduce((s, m) => s + m.y * m.n, 0) / n,
      n,
    };
  });
}

// Centers of the app-bar action icons, left to right (x > 300 skips the
// leading object-tree toggle and the title). Column runs separated by
// less than 8 px merge into one icon (outlined glyphs have gaps).
// Current action order (main.dart + panels/toolbar.dart, Phase 15):
// 0 file, then the six tool flyout groups — 1 Points, 2 Lines,
// 3 Circles, 4 Angles, 5 Transform, 6 Macros — then 7 fit, 8 reset,
// 9 cheat sheet, 10 theme toggle, 11 undo, 12 redo (undo/redo start
// disabled and greyed below the glyph threshold, so a fresh app detects
// 11 icons and the theme toggle is the last — index it from the end,
// not from the front).
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

  const before = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));

  // Phase 14 mapping: zoom is Ctrl+scroll now (plain scroll pans below).
  await page.mouse.move(480, 350);
  await page.keyboard.down('Control');
  for (let i = 0; i < 3; i++) {
    await page.mouse.wheel(0, -100);
    await page.waitForTimeout(120);
  }
  await page.keyboard.up('Control');
  await page.waitForTimeout(400);

  const after = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));

  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const spread = (blobs) => blobs.length >= 2
    ? Math.max(...blobs.flatMap((p, i) => blobs.slice(i + 1).map((q) => dist(p, q))))
    : 0;
  console.log('spread before:', spread(before).toFixed(1),
              'after:', spread(after).toFixed(1));
  check(before.length >= 2 && after.length >= 2 &&
        spread(after) > spread(before) * 1.5,
        'Ctrl+scroll spreads the two point blobs about the cursor');

  // Plain scroll pans: content moves against the wheel delta (wheel up
  // = content down), spread untouched. Two −50 notches ≈ +100 px down.
  for (let i = 0; i < 2; i++) {
    await page.mouse.wheel(0, -50);
    await page.waitForTimeout(120);
  }
  await page.waitForTimeout(400);
  const panned = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));
  const centroidY = (blobs) =>
    blobs.reduce((s, b) => s + b.y, 0) / blobs.length;
  console.log('pan spread:', spread(panned).toFixed(1),
              'centroid y:', centroidY(after).toFixed(1),
              '->', centroidY(panned).toFixed(1));
  check(panned.length >= 2 &&
        Math.abs(spread(panned) - spread(after)) < spread(after) * 0.05 &&
        centroidY(panned) - centroidY(after) > 80,
        'plain scroll pans the canvas without zooming');

  // ---- Phase 9: Save… downloads a parseable version-1 document ----
  // Items are 48 px rows below ~8 px padding: New, Open…, Save…. Since
  // the Phase 15 Transform group made it 11 icons, the File button sits
  // *left* of the window midline, so its menu opens right-aligned —
  // click right of the icon (the flyout groups farther right still open
  // left-aligned; see the Points-menu note above).
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

  // ---- Phase 10: square macro on the fresh post-reload construction ----
  // Taps at A(400,400), B(520,400) put the derived corners one side
  // length up (y-up world): C(520,280), D(400,280). Side BC lies on the
  // hidden perpendicular's carrier, so pixels beyond the segment extent
  // (x=520 below B) tell "hidden line drawn" from "side drawn" apart.
  // Activated by its X S chord: the Macros flyout row order is a UI
  // choice that has already moved once (Square sat at row 1 until the
  // triangles were promoted), and the chord survives reorders. Popup-row
  // clicking stays covered by the File > Save… section above.
  await page.keyboard.press('x');
  await page.keyboard.press('s');
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
  const afterUndo = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));
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
  const placed = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));
  check(placed.length === 2,
        `P + two clicks place two points (${placed.length} blobs)`);

  // = twice zooms in about the canvas center (1.2 each, spread ×1.44);
  // 0 returns to exactly 100 % keeping the center pinned.
  await page.keyboard.press('=');
  await page.waitForTimeout(150);
  await page.keyboard.press('=');
  await page.waitForTimeout(300);
  const zoomed = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));
  const zoomRatio = spread(zoomed) / spread(placed);
  console.log('keyboard zoom spread ratio:', zoomRatio.toFixed(3),
              '(expected ~1.44)');
  check(zoomed.length === 2 && zoomRatio > 1.35 && zoomRatio < 1.55,
        'two = presses spread the points by ~1.44');

  await page.keyboard.press('0');
  await page.waitForTimeout(300);
  const restored = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));
  check(restored.length === 2 &&
        Math.abs(spread(restored) - spread(placed)) < 3,
        '0 returns to 100 % (spread back to the original)');

  // ArrowRight moves the drawing right 32 px (content semantics since
  // Session 21, matching the Phase 14 scroll-pan direction).
  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(300);
  const nudged = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));
  const meanX = (blobs) => blobs.reduce((s, b) => s + b.x, 0) / blobs.length;
  const shift = meanX(nudged) - meanX(restored);
  console.log('nudge shift:', shift.toFixed(1), 'px (expected +32)');
  check(nudged.length === 2 && Math.abs(shift - 32) < 2,
        'ArrowRight nudges the content 32 px right');

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
  const afterSheet = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));
  check(afterSheet.length === 2, 'the construction survived the sheet');

  // ---- Phase 20: smart point placement (glue + intersection snap) ----
  // Empty the canvas (two Ctrl+Z for the two Phase 11 points — File >
  // New would raise the discard-confirmation dialog and eat the next
  // clicks), then: a horizontal segment; P-tap 4 px off it (must glue a
  // PointOnObject, not drop a free point); P-tap far away (free point);
  // a vertical segment crossing the first; P-tap ~3 px from the crossing
  // (must snap an IntersectionPoint). Verified through the saved
  // document's types — pixel blobs can't tell a glued dot from a free
  // one.
  await page.keyboard.press('Control+z');
  await page.waitForTimeout(200);
  await page.keyboard.press('Control+z');
  await page.waitForTimeout(300);
  const cleared = markers(darkBlobs(PNG.sync.read(await page.screenshot()), 70));
  check(cleared.length === 0,
        `Ctrl+Z twice empties the canvas for Phase 20 (${cleared.length} blobs left)`);

  const linesX = icons[2];
  const segmentRow = async () => {
    await page.mouse.click(linesX, 28);
    await page.waitForTimeout(500);
    await page.mouse.click(linesX - 60, 8 + 48 + 24); // second item: Segment
    await page.waitForTimeout(300);
  };
  await segmentRow();
  await page.mouse.click(350, 300);
  await page.waitForTimeout(200);
  await page.mouse.click(650, 300);
  await page.waitForTimeout(300);

  await page.keyboard.press('p');
  await page.waitForTimeout(200);
  await page.mouse.click(500, 304); // 4 px off the segment: glue
  await page.waitForTimeout(200);
  await page.mouse.click(500, 150); // empty canvas: free point
  await page.waitForTimeout(200);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(200);

  await segmentRow();
  await page.mouse.click(550, 200);
  await page.waitForTimeout(200);
  await page.mouse.click(550, 400); // crosses the first segment at (550, 300)
  await page.waitForTimeout(300);

  await page.keyboard.press('p');
  await page.waitForTimeout(200);
  await page.mouse.click(552, 302); // ~3 px from the crossing: intersection
  await page.waitForTimeout(200);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);

  await page.mouse.click(fileX, 28);
  await page.waitForTimeout(500);
  const snapDownload = page.waitForEvent('download', { timeout: 5000 });
  await page.mouse.click(fileX + 30, 8 + 2 * 48 + 24); // third item: Save…
  let snapDoc = null;
  try {
    snapDoc = JSON.parse(fs.readFileSync(await (await snapDownload).path(), 'utf8'));
  } catch (e) {
    console.log('download failed:', String(e));
  }
  check(snapDoc !== null, 'Phase 20 scene saves and parses');
  if (snapDoc) {
    const kinds = snapDoc.objects.map((o) => o.type);
    const count = (t) => kinds.filter((k) => k === t).length;
    console.log('Phase 20 saved kinds:', kinds.join(' '));
    check(count('PointOnObject') === 1,
          'P-tap on the segment glued a PointOnObject');
    check(count('IntersectionPoint') === 1,
          'P-tap near the crossing snapped an IntersectionPoint');
    check(count('FreePoint') === 5 && count('Segment') === 2,
          'segment endpoints and the off-curve tap stayed free points');
  }
  await page.waitForTimeout(400);

  console.log('console errors:', errors.length ? errors : 'none');
  check(errors.length === 0, 'no console errors');

  console.log(failures.length ? 'SMOKE FAIL' : 'SMOKE PASS');
  await browser.close();
  process.exit(failures.length ? 1 : 0);
})();
