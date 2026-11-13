/* Arrow Escape website: hero animation + playable demo puzzle + Google Play button */
(function () {
  'use strict';

  var PAL = ['#ff5c8a', '#ff9f1c', '#f5b800', '#1fbfae', '#3da5f4', '#845ef7', '#45c45b', '#ff6b6b', '#e64980', '#15aabf'];
  var DIRS = { R: [1, 0], D: [0, 1], L: [-1, 0], U: [0, -1] };
  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  function $(s) { return document.querySelector(s); }

  /* ------------------------------------------------------------ site basics */
  (function basics() {
    var y = $('#year'); if (y) y.textContent = new Date().getFullYear();
    var cfg = window.SITE || {};
    if (cfg.contactEmail) {
      ['#mail1', '#mail2'].forEach(function (id) {
        var a = $(id); if (!a) return;
        a.href = 'mailto:' + cfg.contactEmail;
        if (id === '#mail1') a.textContent = cfg.contactEmail;
      });
    }
    if (cfg.live && cfg.playUrl) {
      document.querySelectorAll('.play-link').forEach(function (a) {
        a.href = cfg.playUrl; a.target = '_blank'; a.rel = 'noopener'; a.removeAttribute('aria-disabled');
        if (a.id === 'playBtn') a.textContent = 'Get it on Google Play';
      });
      var t = $('#getText'); if (t) t.textContent = 'Free on Google Play. Download it and start escaping.';
    }
  })();

  /* -------------------------------------------------------- hero background */
  (function hero() {
    var c = $('#heroBg'); if (!c) return;
    var ctx = c.getContext('2d');
    var W = 0, H = 0, dpr = 1, arrows = [], CS = 64;

    function build() {
      arrows = [];
      var cols = Math.ceil(W / CS), rows = Math.ceil(H / CS);
      var n = Math.min(28, Math.floor(cols * rows / 8));
      var keys = ['R', 'D', 'L', 'U'];
      for (var i = 0; i < n; i++) {
        arrows.push({
          x: Math.floor(Math.random() * cols), y: Math.floor(Math.random() * rows),
          d: DIRS[keys[Math.floor(Math.random() * 4)]], len: 2 + Math.floor(Math.random() * 3),
          col: PAL[i % PAL.length], t0: Math.random() * 9
        });
      }
    }
    function resize() {
      var r = c.parentElement.getBoundingClientRect();
      dpr = Math.min(2, window.devicePixelRatio || 1);
      W = r.width; H = r.height;
      c.width = Math.round(W * dpr); c.height = Math.round(H * dpr);
      build(); draw(0);
    }
    function draw(ms) {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, W, H);
      ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      var time = ms / 1000;
      for (var i = 0; i < arrows.length; i++) {
        var a = arrows[i];
        var p = ((time + a.t0) % 9) / 9;                    // 0..1 cycle
        var slide = p < .55 ? 0 : Math.pow((p - .55) / .45, 2) * 16;
        var alpha = p < .55 ? 1 : Math.max(0, 1 - (p - .55) / .35);
        if (reduceMotion) { slide = 0; alpha = 1; }
        var hx = (a.x + .5 + a.d[0] * slide) * CS, hy = (a.y + .5 + a.d[1] * slide) * CS;
        var tx = hx - a.d[0] * a.len * CS * .6, ty = hy - a.d[1] * a.len * CS * .6;
        ctx.globalAlpha = alpha;
        ctx.strokeStyle = ctx.fillStyle = a.col;
        ctx.lineWidth = 9;
        ctx.beginPath(); ctx.moveTo(tx, ty); ctx.lineTo(hx, hy); ctx.stroke();
        var px = -a.d[1], py = a.d[0];
        ctx.beginPath();
        ctx.moveTo(hx + a.d[0] * 26, hy + a.d[1] * 26);
        ctx.lineTo(hx + px * 17, hy + py * 17); ctx.lineTo(hx - px * 17, hy - py * 17);
        ctx.closePath(); ctx.fill();
      }
      ctx.globalAlpha = 1;
    }
    function loop(ts) { draw(ts); requestAnimationFrame(loop); }
    window.addEventListener('resize', resize);
    resize();
    if (!reduceMotion) requestAnimationFrame(loop);
  })();

  /* ------------------------------------------------------------- demo puzzle */
  (function demo() {
    var board = $('#board'), wrap = $('#boardWrap'), conf = $('#confetti');
    if (!board || !window.ARROW_PUZZLES || !window.ARROW_PUZZLES.length) return;
    var dropsEl = $('#drops'), info = $('#demoInfo'), btnHint = $('#btnHint'), btnReset = $('#btnReset'), btnNext = $('#btnNext'), hintCount = $('#hintCount');
    var ctx = board.getContext('2d');
    var DROP = '<svg viewBox="0 0 34 40" aria-hidden="true"><path d="M17 2C12 11 4 17 4 25a13 13 0 0 0 26 0C30 17 22 11 17 2z" fill="#3da5f4" stroke="#151515" stroke-width="3" stroke-linejoin="round"/><ellipse cx="11.5" cy="26" rx="3" ry="4.5" fill="#fff" opacity=".7"/></svg>';
    var MAX_LIVES = 4;
    var pIdx = 0, W = 6, H = 6, arrows = [], grid = [], lives = MAX_LIVES, hints = 3, hintId = -1, alive = 0, over = false, won = false;
    var size = 400, cs = 60, offX = 0, offY = 0, dpr = 1, raf = 0, last = 0, tHint = 0;

    function setInfo(t) { info.textContent = t; }
    function renderDrops() {
      var h = '';
      for (var i = 0; i < MAX_LIVES; i++) h += DROP.replace('<svg', '<svg class="' + (i < lives ? '' : 'lost') + '"');
      dropsEl.innerHTML = h;
    }
    function resize() {
      var r = wrap.getBoundingClientRect();
      size = r.width; dpr = Math.min(2, window.devicePixelRatio || 1);
      board.width = Math.round(size * dpr); board.height = Math.round(size * dpr);
      conf.width = board.width; conf.height = board.height;
      cs = size / (W + .6); offX = (size - W * cs) / 2; offY = (size - H * cs) / 2;
      draw();
    }

    function load(i) {
      var p = window.ARROW_PUZZLES[i];
      W = p.w; H = p.h; arrows = []; grid = new Array(W * H).fill(-1);
      p.a.forEach(function (s, id) {
        var parts = s.split(':'), idx = parseInt(parts[0], 10);
        var x = idx % W, y = Math.floor(idx / W), cells = [[x, y]];
        for (var k = 0; k < parts[1].length; k++) { var v = DIRS[parts[1][k]]; x += v[0]; y += v[1]; cells.push([x, y]); }
        var d = DIRS[parts[2]];
        var pts = cells.map(function (c) { return [c[0] + .5, c[1] + .5]; });
        if (cells.length === 1) pts.unshift([pts[0][0] - d[0] * .34, pts[0][1] - d[1] * .34]);
        var body = 0; for (var j = 1; j < pts.length; j++) body += Math.hypot(pts[j][0] - pts[j - 1][0], pts[j][1] - pts[j - 1][1]);
        var head = cells[cells.length - 1], ray = 0, rx = head[0] + d[0], ry = head[1] + d[1];
        while (rx >= 0 && ry >= 0 && rx < W && ry < H) { ray++; rx += d[0]; ry += d[1]; }
        var last = pts[pts.length - 1];
        var far = W + H + 8 + body;
        var ext = pts.concat([[last[0] + d[0] * far, last[1] + d[1] * far]]);
        arrows.push({ cells: cells, d: d, pts: pts, ext: ext, body: body, ray: ray, st: 0, s: 0, speed: 0, limit: 0, phase: 0, flash: 0, ci: 0 });
        cells.forEach(function (c) { grid[c[1] * W + c[0]] = id; });
      });
      // neighbour-aware colours (same idea as the game)
      arrows.forEach(function (a, i) {
        var used = {};
        a.cells.forEach(function (c) {
          [[1, 0], [-1, 0], [0, 1], [0, -1]].forEach(function (dd) {
            var nx = c[0] + dd[0], ny = c[1] + dd[1];
            if (nx < 0 || ny < 0 || nx >= W || ny >= H) return;
            var o = grid[ny * W + nx]; if (o !== -1 && o < i) used[arrows[o].ci] = true;
          });
        });
        var start = (i * 7 + 3) % PAL.length, pick = start;
        for (var t = 0; t < PAL.length; t++) { var cand = (start + t) % PAL.length; if (!used[cand]) { pick = cand; break; } }
        a.ci = pick;
      });
      alive = arrows.length; lives = MAX_LIVES; hints = 3; hintId = -1; over = false; won = false;
      hintCount.textContent = '(3)'; btnNext.disabled = false;
      renderDrops(); setInfo('Tap an arrow that can slide out!');
      conf.getContext('2d').clearRect(0, 0, conf.width, conf.height);
      resize();
    }

    function rayInfo(id) {
      var a = arrows[id], h = a.cells[a.cells.length - 1], x = h[0] + a.d[0], y = h[1] + a.d[1], free = 0;
      while (x >= 0 && y >= 0 && x < W && y < H) {
        var o = grid[y * W + x]; if (o !== -1) return { free: free, blocker: o };
        free++; x += a.d[0]; y += a.d[1];
      }
      return { free: free, blocker: -1 };
    }

    function slice(ext, from, to) {
      var out = [], acc = 0;
      for (var i = 0; i < ext.length - 1; i++) {
        var p0 = ext[i], p1 = ext[i + 1], l = Math.hypot(p1[0] - p0[0], p1[1] - p0[1]), s0 = acc, s1 = acc + l;
        if (s1 > from && s0 < to && l > 0) {
          var u0 = Math.max(from, s0), u1 = Math.min(to, s1);
          var q0 = [p0[0] + (p1[0] - p0[0]) * (u0 - s0) / l, p0[1] + (p1[1] - p0[1]) * (u0 - s0) / l];
          var q1 = [p0[0] + (p1[0] - p0[0]) * (u1 - s0) / l, p0[1] + (p1[1] - p0[1]) * (u1 - s0) / l];
          if (!out.length || Math.hypot(out[out.length - 1][0] - q0[0], out[out.length - 1][1] - q0[1]) > 1e-4) out.push(q0);
          out.push(q1);
        }
        acc = s1; if (acc >= to) break;
      }
      return out;
    }

    function draw() {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, size, size);
      // faint cell dots
      ctx.fillStyle = 'rgba(21,21,21,.10)';
      for (var gy = 0; gy < H; gy++) for (var gx = 0; gx < W; gx++) {
        ctx.beginPath(); ctx.arc(offX + (gx + .5) * cs, offY + (gy + .5) * cs, 2, 0, 6.2832); ctx.fill();
      }
      ctx.setTransform(dpr * cs, 0, 0, dpr * cs, dpr * offX, dpr * offY);
      ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      for (var i = 0; i < arrows.length; i++) {
        var a = arrows[i]; if (a.st === 3) continue;
        var col = PAL[a.ci], w = .13;
        if (a.flash > 0) col = '#e11313';
        if (i === hintId) {
          var pulse = .5 + .5 * Math.sin(performance.now() / 120);
          ctx.strokeStyle = 'rgba(132,94,247,' + (.3 + .3 * pulse) + ')'; ctx.lineWidth = .5 + .2 * pulse;
          path(a.pts); ctx.stroke(); w = .17;
        }
        var pts = a.s === 0 ? a.pts : slice(a.ext, a.s, a.s + a.body);
        if (!pts.length) continue;
        ctx.strokeStyle = col; ctx.fillStyle = col; ctx.lineWidth = w;
        if (pts.length > 1) { path(pts); ctx.stroke(); }
        var f = pts[pts.length - 1], d = a.d, px = -d[1], py = d[0];
        ctx.beginPath();
        ctx.moveTo(f[0] + d[0] * .44, f[1] + d[1] * .44);
        ctx.lineTo(f[0] - d[0] * .04 + px * .27, f[1] - d[1] * .04 + py * .27);
        ctx.lineTo(f[0] - d[0] * .04 - px * .27, f[1] - d[1] * .04 - py * .27);
        ctx.closePath(); ctx.fill();
      }
    }
    function path(pts) { ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]); }

    function hit(px, py) {
      var qx = (px - offX) / cs, qy = (py - offY) / cs, best = -1, bd = .62;
      arrows.forEach(function (a, i) {
        if (a.st !== 0) return;
        var dmin = 1e9, P = a.pts;
        if (P.length === 1) dmin = Math.hypot(qx - P[0][0], qy - P[0][1]);
        for (var j = 0; j < P.length - 1; j++) dmin = Math.min(dmin, segDist(qx, qy, P[j], P[j + 1]));
        var L = P[P.length - 1]; dmin = Math.min(dmin, Math.hypot(qx - (L[0] + a.d[0] * .3), qy - (L[1] + a.d[1] * .3)));
        if (dmin < bd) { bd = dmin; best = i; }
      });
      return best;
    }
    function segDist(x, y, a, b) {
      var dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy, t = l2 ? Math.max(0, Math.min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / l2)) : 0;
      return Math.hypot(x - (a[0] + dx * t), y - (a[1] + dy * t));
    }

    function tap(id) {
      if (over || won || id < 0) return;
      var a = arrows[id]; if (a.st !== 0) return;
      var r = rayInfo(id);
      if (hintId === id) hintId = -1;
      if (r.blocker === -1) {
        a.st = 1; a.s = 0; a.speed = 7; alive--;
        a.cells.forEach(function (c) { grid[c[1] * W + c[0]] = -1; });
        setInfo(alive ? alive + ' arrow' + (alive === 1 ? '' : 's') + ' left' : 'Last one!');
      } else {
        a.st = 2; a.limit = r.free + .3; a.phase = 0; a.flash = .7; arrows[r.blocker].flash = .7;
        lives--; renderDrops();
        wrap.classList.remove('shake'); void wrap.offsetWidth; wrap.classList.add('shake');
        if (navigator.vibrate) { try { navigator.vibrate(40); } catch (e) { /* ignore */ } }
        if (lives <= 0) { over = true; setInfo('Out of drops! Press Restart.'); }
        else setInfo('Blocked! You lost a drop (' + lives + ' left).');
      }
      kick();
    }

    function kick() { if (!raf) { last = performance.now(); raf = requestAnimationFrame(tick); } }
    function tick(ts) {
      var dt = Math.min(.05, (ts - last) / 1000); last = ts;
      var busy = hintId >= 0;
      arrows.forEach(function (a) {
        if (a.st === 1) {
          busy = true; a.speed += 75 * dt; a.s += a.speed * dt;
          if (a.s > a.body + a.ray + 1.3) a.st = 3;
        } else if (a.st === 2) {
          busy = true;
          if (a.phase === 0) { a.s += Math.max(16, a.limit / .22) * dt; if (a.s >= a.limit) { a.s = a.limit; a.phase = 1; } }
          else { a.s -= Math.max(11, a.limit / .3) * dt; if (a.s <= 0) { a.s = 0; a.st = 0; } }
        }
        if (a.flash > 0) { a.flash -= dt; busy = true; }
      });
      draw();
      if (alive === 0 && !won && !arrows.some(function (a) { return a.st === 1; })) { won = true; setInfo('Cleared! Press Next puzzle.'); confetti(); }
      raf = busy ? requestAnimationFrame(tick) : 0;
    }

    function hint() {
      if (over || won || hints <= 0) { if (hints <= 0) setInfo('No hints left in the demo - the app gives you more!'); return; }
      for (var i = 0; i < arrows.length; i++) {
        if (arrows[i].st === 0 && rayInfo(i).blocker === -1) {
          hintId = i; hints--; hintCount.textContent = '(' + hints + ')'; setInfo('Try the glowing arrow!'); kick(); return;
        }
      }
    }

    function confetti() {
      if (reduceMotion) return;
      var c = conf.getContext('2d'), n = 90, ps = [], t0 = performance.now();
      for (var i = 0; i < n; i++) ps.push({ x: Math.random() * size, y: -10 - Math.random() * size * .4, vx: (Math.random() - .5) * 260, vy: 80 + Math.random() * 260, r: Math.random() * 6, vr: (Math.random() - .5) * 12, w: 7 + Math.random() * 8, col: PAL[i % PAL.length] });
      (function frame(now) {
        var t = (now - t0) / 1000; c.setTransform(dpr, 0, 0, dpr, 0, 0); c.clearRect(0, 0, size, size);
        ps.forEach(function (p) {
          p.vy += 520 * .016; p.x += p.vx * .016; p.y += p.vy * .016; p.r += p.vr * .016;
          c.save(); c.translate(p.x, p.y); c.rotate(p.r); c.fillStyle = p.col; c.fillRect(-p.w / 2, -p.w / 3, p.w, p.w * .66); c.restore();
        });
        if (t < 2.8) requestAnimationFrame(frame); else c.clearRect(0, 0, size, size);
      })(t0);
    }

    board.addEventListener('click', function (e) {
      var r = board.getBoundingClientRect();
      tap(hit(e.clientX - r.left, e.clientY - r.top));
    });
    btnHint.addEventListener('click', hint);
    btnReset.addEventListener('click', function () { load(pIdx); });
    btnNext.addEventListener('click', function () { pIdx = (pIdx + 1) % window.ARROW_PUZZLES.length; load(pIdx); });
    window.addEventListener('resize', resize);
    load(0);
  })();
})();
