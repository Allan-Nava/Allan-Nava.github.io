/*
 * Ridge run: the game on /play/ (play.html). One button: jump the rocks and pines, and time
 * the jump under or over the choughs. Plain canvas, no libraries.
 *
 * - Colours are the site's tokens (nava-ui), read from :root and read again when the theme
 *   changes, so the game follows dark and light like the rest of the site.
 * - The two mountain ranges in the background are the ridges of the channel banner
 *   (_includes/channel-banner.html), x 0-2560 and y 540-1080 of that canvas; a tile is drawn
 *   then mirrored, so the range never shows a seam.
 * - The best distance stays in localStorage; when storage is blocked the game works without it.
 * - The file is static (no front matter), so neither Liquid nor jemoji touch it.
 * - Difficulty grows in two stages. Up to MAX_SPEED (about 54 s, 2,600 m) the speed rises
 *   quickly and new obstacles join: choughs from 250 m, rock piles from 600 m. After that it
 *   keeps rising, slower, up to TOP_SPEED (about 160 s); from 1,500 m a low chough can come
 *   with a high one right behind it (jump, land, stay down), and from 2,000 m the gaps
 *   tighten, down to 90% at 5,000 m. Every gap stays longer than a tapped jump (about
 *   0.55 s in the air), so a run can always be survived.
 */
(function () {
  'use strict';

  var FAR = [-40, 815, -5, 788, 32, 756, 54, 725, 97, 683, 124, 666, 157, 638, 191, 619, 215, 613, 259, 616, 300, 634, 322, 647, 358, 660, 380, 676, 413, 682, 457, 683, 503, 676, 545, 679, 591, 704, 614, 713, 640, 747, 672, 774, 701, 800, 732, 824, 768, 849, 813, 866, 859, 874, 906, 871, 931, 872, 978, 868, 1013, 861, 1040, 859, 1076, 848, 1098, 852, 1145, 838, 1187, 838, 1212, 834, 1253, 839, 1275, 835, 1296, 836, 1326, 838, 1373, 834, 1420, 834, 1443, 840, 1464, 837, 1496, 845, 1520, 841, 1564, 849, 1611, 861, 1641, 858, 1676, 860, 1713, 856, 1750, 852, 1784, 831, 1824, 804, 1853, 790, 1887, 755, 1908, 736, 1944, 704, 1981, 693, 2003, 687, 2036, 688, 2066, 694, 2107, 698, 2129, 711, 2175, 708, 2208, 703, 2237, 686, 2266, 668, 2303, 643, 2333, 633, 2355, 624, 2395, 620, 2421, 635, 2448, 643, 2481, 676, 2504, 693, 2533, 730, 2566, 763, 2591, 780];
  var MID = [-40, 841, -20, 827, -1, 805, 24, 768, 52, 734, 78, 706, 97, 696, 132, 676, 154, 685, 192, 703, 218, 732, 236, 747, 259, 757, 279, 775, 314, 790, 343, 798, 369, 789, 387, 773, 408, 771, 435, 753, 464, 749, 488, 757, 520, 764, 550, 792, 587, 828, 610, 851, 629, 855, 663, 869, 691, 876, 722, 892, 752, 894, 776, 890, 806, 884, 833, 884, 871, 871, 903, 859, 935, 864, 974, 866, 997, 860, 1029, 859, 1056, 866, 1076, 869, 1110, 879, 1132, 888, 1168, 891, 1195, 902, 1232, 909, 1268, 900, 1294, 899, 1331, 903, 1351, 887, 1373, 882, 1401, 881, 1423, 865, 1450, 864, 1479, 866, 1511, 852, 1542, 852, 1560, 854, 1594, 856, 1629, 852, 1655, 853, 1686, 859, 1704, 865, 1724, 872, 1742, 870, 1762, 875, 1787, 877, 1824, 889, 1844, 883, 1869, 882, 1888, 885, 1927, 863, 1955, 839, 1974, 829, 1997, 818, 2017, 787, 2055, 766, 2075, 755, 2093, 749, 2131, 755, 2164, 759, 2189, 773, 2223, 799, 2257, 808, 2279, 815, 2318, 798, 2353, 768, 2386, 727, 2414, 708, 2432, 694, 2455, 696, 2487, 719, 2514, 740, 2553, 783, 2578, 800, 2600, 822];

  var root = document.querySelector('[data-ridge-run]');
  if (!root) return;
  var canvas = root.querySelector('canvas');
  var ctx = canvas.getContext('2d');
  var distEl = root.querySelector('[data-distance]');
  var bestEl = root.querySelector('[data-best]');
  var statusEl = root.querySelector('[data-status]');

  var STORE = 'ridge-run-best';
  var PX_PER_M = 12;
  var GRAVITY = 2600;
  var JUMP_V = 720;
  var START_SPEED = 330;
  var MAX_SPEED = 820;
  var TOP_SPEED = 980;

  var W = 0, H = 0, groundY = 0, dpr = 1;
  var colors = {};
  var font = 'system-ui, sans-serif';
  var state = 'ready';
  var speed, distance, obstacles, nextGap, t, far, mid, groundX, best = 0, lastFrame = 0, raf = 0;
  var hiker = { x: 56, y: 0, vy: 0, w: 20, h: 38, onGround: true, holding: false };

  try { best = parseInt(localStorage.getItem(STORE), 10) || 0; } catch (e) { best = 0; }

  function readColors() {
    var cs = getComputedStyle(document.documentElement);
    function v(name, fallback) { return (cs.getPropertyValue(name) || '').trim() || fallback; }
    colors = {
      bg: v('--color-bg', '#050505'),
      fg: v('--color-fg', '#eae4e4'),
      strong: v('--color-fg-strong', '#ffffff'),
      muted: v('--color-fg-muted', '#a9a9b0'),
      accent: v('--color-accent', '#10cf53'),
      accentText: v('--color-accent-text', '#7be8a6')
    };
    font = getComputedStyle(document.body).fontFamily || 'system-ui, sans-serif';
  }

  function resize() {
    var rect = canvas.getBoundingClientRect();
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = Math.max(280, Math.round(rect.width));
    H = Math.round(rect.height) || 240;
    canvas.width = Math.round(W * dpr);
    canvas.height = Math.round(H * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    groundY = H - 34;
    if (hiker.onGround) hiker.y = groundY - hiker.h;
    draw();
  }

  function reset() {
    speed = START_SPEED;
    distance = 0;
    obstacles = [];
    nextGap = 420;
    t = 0;
    far = 0;
    mid = 0;
    groundX = 0;
    hiker.y = groundY - hiker.h;
    hiker.vy = 0;
    hiker.onGround = true;
  }

  function jumpStart() {
    if (state !== 'running') { start(); return; }
    hiker.holding = true;
    if (hiker.onGround) {
      hiker.vy = -JUMP_V;
      hiker.onGround = false;
    }
  }

  function jumpEnd() {
    hiker.holding = false;
    if (!hiker.onGround && hiker.vy < -JUMP_V * 0.45) hiker.vy = -JUMP_V * 0.45;
  }

  function drop() {
    if (state === 'running' && !hiker.onGround) hiker.vy = Math.max(hiker.vy, JUMP_V * 0.9);
  }

  function start() {
    reset();
    state = 'running';
    statusEl.textContent = '';
    lastFrame = 0;
    cancelAnimationFrame(raf);
    raf = requestAnimationFrame(frame);
  }

  function gameOver() {
    state = 'over';
    var m = Math.floor(distance);
    var record = m > best;
    if (record) {
      best = m;
      try { localStorage.setItem(STORE, String(best)); } catch (e) { /* storage blocked */ }
    }
    showScore();
    statusEl.textContent = (record ? 'New best: ' : 'Game over at ') + m + ' m. Press Space or tap to try again.';
    draw();
  }

  function pause() {
    if (state !== 'running') return;
    state = 'paused';
    statusEl.textContent = 'Paused. Press Space or tap to go on.';
    draw();
  }

  function resume() {
    state = 'running';
    statusEl.textContent = '';
    lastFrame = 0;
    raf = requestAnimationFrame(frame);
  }

  function obstacle(kind, x) {
    var o = { kind: kind, x: x, flap: Math.random() * 6 };
    if (kind === 'rock') { o.w = 22 + Math.random() * 16; o.h = 16 + Math.random() * 12; o.y = groundY - o.h; }
    else if (kind === 'rocks') { o.w = 58; o.h = 24; o.y = groundY - o.h; }
    else if (kind === 'pine') { o.w = 24; o.h = 40 + Math.random() * 14; o.y = groundY - o.h; }
    else if (kind === 'bird-low') { o.w = 26; o.h = 14; o.y = groundY - 30; }
    else { o.w = 26; o.h = 14; o.y = groundY - 76; }
    obstacles.push(o);
    return o;
  }

  function spawn() {
    var kinds = ['rock', 'rock', 'pine'];
    if (distance > 250) kinds.push('bird-low', 'bird-high');
    if (distance > 600) kinds.push('rocks');
    if (distance > 1500) kinds.push('bird-pair');
    var kind = kinds[Math.floor(Math.random() * kinds.length)];
    var extra = 0;
    if (kind === 'bird-pair') {
      /* A low chough, then a high one 0.85 s behind it (birds fly 1.12 times the ground
         speed): jump the first, land, and stay down for the second. A held jump peaks
         higher than the high chough, so the landing has to come first. */
      extra = speed * 1.12 * 0.85;
      obstacle('bird-low', W + 20);
      obstacle('bird-high', W + 20 + extra);
    } else {
      obstacle(kind, W + 20);
    }
    /* From 2,000 m the gaps tighten, down to 90% at 5,000 m. At TOP_SPEED the shortest
       gap is still about 0.7 s, longer than a tapped jump. */
    var tighten = distance > 2000 ? Math.max(0.9, 1 - (distance - 2000) / 30000) : 1;
    var minGap = (speed * 0.62 + 170) * tighten;
    nextGap = extra + minGap + Math.random() * minGap * 0.9;
  }

  function hit(o) {
    var pad = 4;
    return hiker.x + pad < o.x + o.w - pad &&
      hiker.x + hiker.w - pad > o.x + pad &&
      hiker.y + pad < o.y + o.h - 2 &&
      hiker.y + hiker.h > o.y + pad;
  }

  function update(dt) {
    t += dt;
    /* Fast ramp up to MAX_SPEED, then a slow one (1.5 px/s per second) up to TOP_SPEED. */
    var ramp = START_SPEED + t * 9;
    speed = ramp <= MAX_SPEED ? ramp : Math.min(TOP_SPEED, MAX_SPEED + (ramp - MAX_SPEED) / 6);
    var dx = speed * dt;
    distance += dx / PX_PER_M;
    far += dx * 0.08;
    mid += dx * 0.22;
    groundX += dx;

    if (!hiker.onGround) {
      hiker.vy += GRAVITY * (hiker.holding && hiker.vy < 0 ? 0.7 : 1) * dt;
      hiker.y += hiker.vy * dt;
      if (hiker.y >= groundY - hiker.h) {
        hiker.y = groundY - hiker.h;
        hiker.vy = 0;
        hiker.onGround = true;
      }
    }

    nextGap -= dx;
    if (nextGap <= 0) spawn();
    for (var i = obstacles.length - 1; i >= 0; i--) {
      var o = obstacles[i];
      o.x -= dx * (o.kind.indexOf('bird') === 0 ? 1.12 : 1);
      o.flap += dt * 12;
      if (o.x + o.w < -10) obstacles.splice(i, 1);
      else if (hit(o)) { gameOver(); return; }
    }
  }

  function frame(now) {
    if (state !== 'running') return;
    if (!lastFrame) lastFrame = now;
    var dt = Math.min(0.05, (now - lastFrame) / 1000);
    lastFrame = now;
    var steps = Math.ceil(dt / (1 / 120));
    for (var s = 0; s < steps && state === 'running'; s++) update(dt / steps);
    draw();
    showScore();
    if (state === 'running') raf = requestAnimationFrame(frame);
  }

  var shown = -1;
  function showScore() {
    var m = Math.floor(distance || 0);
    if (m === shown) return;
    shown = m;
    distEl.textContent = m + ' m';
    bestEl.textContent = best + ' m';
  }

  /* A range as one period of 5120 banner units: the tile clipped to x 0-2560, then mirrored. */
  function period(flat) {
    var pts = [];
    for (var i = 0; i < flat.length; i += 2) {
      var x = flat[i], y = flat[i + 1];
      if (x < 0 || x > 2560) {
        var j = x < 0 ? i + 2 : i - 2;
        var x2 = flat[j], y2 = flat[j + 1], edge = x < 0 ? 0 : 2560;
        y = y + (y2 - y) * (edge - x) / (x2 - x);
        x = edge;
      }
      pts.push([x, y]);
    }
    for (var k = pts.length - 2; k > 0; k--) pts.push([5120 - pts[k][0], pts[k][1]]);
    return pts;
  }
  FAR = period(FAR);
  MID = period(MID);

  /* The banner's ridges: y 600-930 of the banner mapped between top and the ground. */
  function ridge(pts, offset, top, alpha, line) {
    var sy = (groundY - top) / 330;
    var sx = sy * 1.25;
    var span = 5120 * sx;
    var start = -(offset % span);
    ctx.beginPath();
    var first = true;
    for (var base = start; base < W + span; base += span) {
      for (var i = 0; i < pts.length; i++) {
        var x = base + pts[i][0] * sx;
        var y = top + (pts[i][1] - 600) * sy;
        if (first) { ctx.moveTo(x, y); first = false; } else ctx.lineTo(x, y);
      }
    }
    ctx.globalAlpha = alpha;
    if (line) {
      ctx.strokeStyle = colors.accent;
      ctx.lineWidth = 2;
      ctx.lineJoin = 'round';
      ctx.stroke();
    } else {
      ctx.lineTo(W + 10, groundY);
      ctx.lineTo(start - 10, groundY);
      ctx.closePath();
      ctx.fillStyle = colors.fg;
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  function drawHiker() {
    var x = hiker.x, y = hiker.y, phase = hiker.onGround && state === 'running' ? Math.sin(t * 22) : 0.6;
    ctx.fillStyle = colors.strong;
    ctx.strokeStyle = colors.strong;
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(x + 10, y + 26);
    ctx.lineTo(x + 10 + phase * 6, y + hiker.h);
    ctx.moveTo(x + 10, y + 26);
    ctx.lineTo(x + 10 - phase * 6, y + hiker.h);
    ctx.stroke();
    ctx.fillRect(x + 6, y + 10, 9, 17);
    ctx.beginPath();
    ctx.arc(x + 11, y + 6, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = colors.accent;
    ctx.fillRect(x + 1, y + 11, 6, 13);
    ctx.lineWidth = 2;
    ctx.strokeStyle = colors.muted;
    ctx.beginPath();
    ctx.moveTo(x + 16, y + 16);
    ctx.lineTo(x + 22 - phase * 3, y + hiker.h);
    ctx.stroke();
  }

  function drawObstacle(o) {
    ctx.fillStyle = colors.muted;
    if (o.kind === 'rock' || o.kind === 'rocks') {
      var parts = o.kind === 'rocks' ? [[0, 0.5, 1], [0.38, 0.62, 0.7]] : [[0, 1, 1]];
      for (var i = 0; i < parts.length; i++) {
        var px = o.x + parts[i][0] * o.w, pw = parts[i][1] * o.w, ph = parts[i][2] * o.h;
        var py = groundY - ph;
        ctx.beginPath();
        ctx.moveTo(px, groundY);
        ctx.lineTo(px + pw * 0.1, py + ph * 0.35);
        ctx.lineTo(px + pw * 0.4, py);
        ctx.lineTo(px + pw * 0.8, py + ph * 0.15);
        ctx.lineTo(px + pw, groundY);
        ctx.closePath();
        ctx.fill();
      }
    } else if (o.kind === 'pine') {
      ctx.fillRect(o.x + o.w / 2 - 2, groundY - 8, 4, 8);
      for (var k = 0; k < 3; k++) {
        var ty = o.y + k * (o.h - 8) / 3;
        var tw = o.w * (0.55 + k * 0.22);
        ctx.beginPath();
        ctx.moveTo(o.x + o.w / 2, ty);
        ctx.lineTo(o.x + o.w / 2 + tw / 2, ty + (o.h - 8) / 2.2);
        ctx.lineTo(o.x + o.w / 2 - tw / 2, ty + (o.h - 8) / 2.2);
        ctx.closePath();
        ctx.fill();
      }
    } else {
      var wing = Math.sin(o.flap) * 6;
      ctx.strokeStyle = colors.fg;
      ctx.lineWidth = 2.5;
      ctx.lineJoin = 'round';
      ctx.beginPath();
      ctx.moveTo(o.x, o.y + 7 - wing);
      ctx.lineTo(o.x + o.w / 2, o.y + 8);
      ctx.lineTo(o.x + o.w, o.y + 7 - wing);
      ctx.stroke();
      ctx.fillStyle = colors.accentText;
      ctx.fillRect(o.x + 2, o.y + 6 - wing, 3, 2);
    }
  }

  function draw() {
    if (!W) return;
    ctx.fillStyle = colors.bg;
    ctx.fillRect(0, 0, W, H);

    ridge(FAR, far || 0, H * 0.16, 0.05, false);
    ridge(MID, mid || 0, H * 0.34, 0.08, false);
    ridge(MID, mid || 0, H * 0.34, 0.55, true);

    ctx.fillStyle = colors.fg;
    ctx.globalAlpha = 0.04;
    ctx.fillRect(0, groundY, W, H - groundY);
    ctx.globalAlpha = 1;
    ctx.fillStyle = colors.muted;
    ctx.fillRect(0, groundY, W, 2);
    ctx.globalAlpha = 0.5;
    for (var gx = -((groundX || 0) % 46); gx < W; gx += 46) {
      ctx.fillRect(gx, groundY + 9, 6, 2);
      ctx.fillRect(gx + 23, groundY + 17, 3, 2);
    }
    ctx.globalAlpha = 1;

    if (obstacles) for (var i = 0; i < obstacles.length; i++) drawObstacle(obstacles[i]);
    drawHiker();

    if (state !== 'running') {
      ctx.fillStyle = colors.strong;
      ctx.textAlign = 'center';
      ctx.font = '600 16px ' + font;
      var title = state === 'over' ? 'Game over' : state === 'paused' ? 'Paused' : 'Ridge run';
      ctx.fillText(title, W / 2, H * 0.36);
      ctx.fillStyle = colors.muted;
      ctx.font = '14px ' + font;
      ctx.fillText('Space, ↑ or tap to ' + (state === 'paused' ? 'go on' : state === 'over' ? 'try again' : 'start'), W / 2, H * 0.36 + 24);
    }
  }

  function isTyping(el) {
    return el && (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName));
  }

  window.addEventListener('keydown', function (e) {
    if (isTyping(e.target) || e.metaKey || e.ctrlKey || e.altKey) return;
    if (e.code === 'Space' || e.code === 'ArrowUp' || e.code === 'KeyW') {
      if (e.code === 'Space' && e.target !== canvas && e.target.closest && e.target.closest('a, button')) return;
      e.preventDefault();
      if (e.repeat) return;
      if (state === 'paused') resume(); else jumpStart();
    } else if (e.code === 'ArrowDown' || e.code === 'KeyS') {
      if (state === 'running') { e.preventDefault(); drop(); }
    } else if (e.code === 'Escape' || e.code === 'KeyP') {
      if (state === 'running') pause(); else if (state === 'paused') resume();
    }
  });
  window.addEventListener('keyup', function (e) {
    if (e.code === 'Space' || e.code === 'ArrowUp' || e.code === 'KeyW') jumpEnd();
  });
  canvas.addEventListener('pointerdown', function (e) {
    e.preventDefault();
    canvas.focus({ preventScroll: true });
    if (state === 'paused') resume(); else jumpStart();
  });
  canvas.addEventListener('pointerup', jumpEnd);
  canvas.addEventListener('pointercancel', jumpEnd);
  document.addEventListener('visibilitychange', function () { if (document.hidden) pause(); });
  window.addEventListener('blur', pause);

  new MutationObserver(function () { readColors(); draw(); })
    .observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-color-scheme: light)');
    var onScheme = function () { readColors(); draw(); };
    if (mq.addEventListener) mq.addEventListener('change', onScheme); else if (mq.addListener) mq.addListener(onScheme);
  }
  if (window.ResizeObserver) new ResizeObserver(resize).observe(canvas); else window.addEventListener('resize', resize);

  readColors();
  reset();
  resize();
  showScore();
  root.hidden = false;
}());
