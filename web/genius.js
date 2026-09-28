// Genius no navegador: Corrida no Wi-Fi (games/genius/screens/genius_game.gd). A sequência toca na
// hora marcada pelo host (relógio acertado por pings, como no Halli Galli) e os tons são gerados
// com Web Audio, como no app (games/genius/audio/genius_tones.gd).
"use strict";

(() => {
  const { h, button, card, player, mount, toast, vibrate, act, send, st } = GH;
  const PCOLORS = ["#2B59C3", "#C8392B", "#2F7D5B", "#E0A21F", "#6E3B93", "#1E7F86", "#D9772B", "#C4467A"];
  // Verde, vermelho, amarelo, azul (mesma ordem das regras).
  const BASE = ["#1E9E55", "#D63B2F", "#F2B233", "#2B59C3"];
  const FREQS = [415, 310, 252, 209];
  const GAP_MS = 50;
  const MIN_PRESS_MS = 150;

  const lightMs = (n) => (n <= 5 ? 420 : n <= 13 ? 320 : 220);
  const nowUs = () => Math.round(performance.now() * 1000);

  // --- Relógio do host (mesma conta do net/clock_sync.gd) --------------------
  const clock = {
    samples: [],
    add(t0, hostUs, t1) {
      const rtt = t1 - t0;
      if (rtt < 0) return;
      this.samples.push({ rtt, offset: hostUs - (t0 + t1) / 2 });
      if (this.samples.length > 20) this.samples.shift();
    },
    offset() {
      let best = null;
      for (const s of this.samples) if (!best || s.rtt < best.rtt) best = s;
      return best ? best.offset : 0;
    },
    hostNow() { return Math.floor((nowUs() + this.offset()) / 1000); },
    maxRtt() {
      let m = 0;
      for (const s of this.samples.slice(-8)) m = Math.max(m, s.rtt);
      return Math.floor(m / 1000);
    },
  };
  let pingTimer = null;
  function startPings() {
    clearTimeout(pingTimer);
    let n = 0;
    const tick = () => {
      send({ type: "ping", c: nowUs(), rtt: clock.maxRtt() });
      n += 1;
      pingTimer = setTimeout(tick, n < 12 ? 100 : 1000);
    };
    tick();
  }
  // Hora do host → performance.now() deste aparelho.
  const toLocal = (hostMs) => performance.now() + (hostMs - clock.hostNow());

  // --- Tons ------------------------------------------------------------------
  let ctx = null;
  let voice = null;
  function audioCtx() {
    if (!ctx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return null;
      ctx = new Ctx();
    }
    if (ctx.state === "suspended") ctx.resume();
    return ctx;
  }
  // O iPhone só libera o som dentro de um toque.
  document.addEventListener("pointerdown", audioCtx, { passive: true });

  function toneOn(freq, ms) {
    const a = audioCtx();
    if (!a) return;
    toneOff();
    const osc = a.createOscillator();
    osc.type = "square";
    osc.frequency.value = freq;
    const lp = a.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.value = freq < 100 ? 900 : 2200;
    const g = a.createGain();
    const t = a.currentTime;
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.16, t + 0.004);
    osc.connect(lp).connect(g).connect(a.destination);
    osc.start(t);
    voice = { osc, g };
    if (ms) {
      const v2 = voice;
      setTimeout(() => { if (voice === v2) toneOff(); }, ms);
    }
  }
  function toneOff() {
    if (!voice || !ctx) return;
    const { osc, g } = voice;
    voice = null;
    const t = ctx.currentTime;
    g.gain.cancelScheduledValues(t);
    g.gain.setValueAtTime(g.gain.value, t);
    g.gain.linearRampToValueAtTime(0, t + 0.03);
    osc.stop(t + 0.05);
  }

  // --- Tabuleiro ---------------------------------------------------------------
  function shade(hex, k) {
    // k > 0 clareia, k < 0 escurece (como Color.lightened/darkened do Godot).
    const n = parseInt(hex.slice(1), 16);
    const ch = [n >> 16, (n >> 8) & 255, n & 255].map((c) => Math.round(k > 0 ? c + (255 - c) * k : c * (1 + k)));
    return `rgb(${ch.join(",")})`;
  }

  function sector(r0, r1, a0, a1, half) {
    const pt = (r, a) => `${(160 + Math.cos(a) * r).toFixed(2)} ${(160 + Math.sin(a) * r).toFixed(2)}`;
    const t1 = half / r1;
    const t0 = half / r0;
    return `M${pt(r1, a0 + t1)} A${r1} ${r1} 0 0 1 ${pt(r1, a1 - t1)} L${pt(r0, a1 - t0)} A${r0} ${r0} 0 0 0 ${pt(r0, a0 + t0)} Z`;
  }

  const SPANS = [[Math.PI, Math.PI * 1.5], [Math.PI * 1.5, Math.PI * 2], [Math.PI * 0.5, Math.PI], [0, Math.PI * 0.5]];

  // Um tabuleiro vivo: toca sequências e avisa os toques. onPress(cor).
  function makeBoard(onPress) {
    const ns = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(ns, "svg");
    svg.setAttribute("viewBox", "0 0 320 320");
    svg.setAttribute("class", "gn-board off");
    const el = (tag, attrs) => {
      const e = document.createElementNS(ns, tag);
      for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
      svg.append(e);
      return e;
    };
    const R = 156;
    const inner = R * 0.36;
    const gap = R * 0.05;
    el("circle", { cx: 160, cy: 164, r: R, fill: "rgba(0,0,0,.12)" });
    el("circle", { cx: 160, cy: 160, r: R, fill: "#1F1D1A" });
    const paths = SPANS.map(([a0, a1], i) => {
      const p = el("path", { d: sector(inner + gap, R - gap, a0, a1, gap / 2), fill: shade(BASE[i], -0.4) });
      p.addEventListener("pointerdown", (e) => { e.preventDefault(); down(i); });
      return p;
    });
    el("circle", { cx: 160, cy: 160, r: inner - gap * 0.3, fill: "#2A2723" });
    const big = el("text", { x: 160, y: 168, "text-anchor": "middle", fill: "#FFFCF6", "font-family": "Fraunces, serif", "font-weight": 800, "font-size": 36 });
    const small = el("text", { x: 160, y: 190, "text-anchor": "middle", fill: "rgba(255,252,246,.7)", "font-family": "Manrope, sans-serif", "font-weight": 700, "font-size": 11 });

    const b = { svg, interactive: false, lit: -1, touch: -1, touchAt: 0, seq: null, start: 0, step: -1, flash: -1, flashUntil: 0, alive: true };
    function paint() {
      paths.forEach((p, i) => {
        p.setAttribute("fill", i === b.lit ? shade(BASE[i], 0.38) : shade(BASE[i], b.interactive || b.seq ? -0.28 : -0.4));
      });
      svg.setAttribute("class", "gn-board" + (b.interactive ? "" : " off"));
    }
    function setLit(c) {
      if (c !== b.lit) { b.lit = c; paint(); }
    }
    function down(c) {
      if (!b.interactive || b.touch >= 0) return;
      b.touch = c;
      b.touchAt = performance.now();
      setLit(c);
      toneOn(FREQS[c]);
      vibrate(15);
      onPress(c);
    }
    function up() {
      if (b.touch < 0) return;
      const wait = MIN_PRESS_MS - (performance.now() - b.touchAt);
      const end = () => {
        b.touch = -1;
        // Com a próxima sequência só agendada (ainda não começou a tocar), o botão apaga normalmente.
        if (b.flash < 0 && b.step < 0) { setLit(-1); toneOff(); }
      };
      if (wait > 0) setTimeout(end, wait); else end();
    }
    for (const t of ["pointerup", "pointercancel"]) document.addEventListener(t, up);
    const detach = () => { for (const t of ["pointerup", "pointercancel"]) document.removeEventListener(t, up); };

    function frame() {
      if (!b.alive) return;
      if (!svg.isConnected && b.mounted) { b.alive = false; detach(); toneOff(); return; }
      if (svg.isConnected) b.mounted = true;
      const now = performance.now();
      if (b.seq) {
        const n = b.seq.length;
        const light = lightMs(n);
        const every = light + GAP_MS;
        const t = now - b.start;
        if (t >= 0) {
          const i = Math.floor(t / every);
          if (i >= n) {
            b.seq = null;
            b.step = -1;
            setLit(-1);
            b.onDone && b.onDone();
          } else {
            const on = t % every < light;
            if (on && i !== b.step) {
              b.touch = -1;
              b.step = i;
              const left = light - (t % every);
              if (left > 60) toneOn(FREQS[b.seq[i]], left);
            }
            setLit(on ? b.seq[i] : -1);
          }
        }
      }
      if (b.flash >= 0) {
        if (now >= b.flashUntil) { b.flash = -1; setLit(-1); }
        else setLit(Math.floor(b.flashUntil - now) % 333 > 140 ? b.flash : -1);
      }
      if (b.onFrame) b.onFrame();
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);

    b.play = (seq, startLocal, onDone) => {
      b.seq = seq.slice();
      b.start = startLocal;
      b.step = -1;
      b.onDone = onDone;
      b.interactive = false;
      paint();
    };
    b.setInteractive = (on) => { b.interactive = on; paint(); };
    b.error = (right) => {
      b.interactive = false;
      b.seq = null;
      b.touch = -1;
      toneOn(42, 1500);
      b.flash = right;
      b.flashUntil = performance.now() + 1500;
      paint();
    };
    b.center = (text, sub) => {
      if (big.textContent !== text) big.textContent = text;
      if (small.textContent !== sub) small.textContent = sub;
      big.setAttribute("font-size", String(text).length <= 3 ? 40 : 20);
    };
    paint();
    return b;
  }

  // --- Estado ------------------------------------------------------------------
  let v = null;
  let key = ""; // rodada em que i/state valem
  let i = 0;
  let state = ""; // "", "ok", "fail"
  let brd = null;
  let statusEl = null;
  let boardKey = "";

  const byId = (id) => (v.players || []).find((p) => p.id === id) || { name: "?", color: 0, connected: true };
  const nameOf = (id) => byId(id).name;
  const pcolor = (id) => PCOLORS[byId(id).color % PCOLORS.length];
  const cores = (n) => `${n} cor${n === 1 ? "" : "es"}`;
  const meIn = () => (v.alive || []).includes(v.you);
  const mine = () => state || v.mine || "";

  function header(text) {
    return h("div.row", h("h1.title.left.grow", text), button("", "secondary", GH.confirmLeave, "close", "icon-btn"));
  }

  function big(title, bg, sub) {
    return card(bg || null, h("h2.title", title), sub ? h("p.center.bold", sub) : null);
  }

  function lobby() {
    return [header("Sala do Genius"),
      h("img", { src: "assets/genius.svg", style: { width: "140px", height: "140px", margin: "0 auto" }, alt: "" }),
      card(null, h("p.sub", `Na sala (${v.players.length})`), v.players.map((p) => player(p.name, PCOLORS[p.color % PCOLORS.length], p.connected, p.id === v.you ? "você" : ""))),
      card("var(--papel)", h("p.caption", { style: { textAlign: "left" } }, "A sequência toca junto em todos os celulares e cada um repete no seu. Quem errar sai. Ganha quem sobrar. Aumente o volume!")),
      h("p.caption", "Esperando o host começar a partida...")];
  }

  function statusText() {
    const waiting = v.pending || 0;
    const esp = waiting > 0 ? ` Esperando ${waiting} pessoa${waiting === 1 ? "" : "s"}` : "";
    if (!meIn()) return waiting > 0 && !(brd && brd.seq) ? `Assistindo · faltam ${waiting}` : "Assistindo...";
    if (mine() === "ok") return "Acertou!" + esp;
    if (mine() === "fail" || mine() === "forfeit") return "Errou!" + esp;
    if ((brd && brd.seq) || performance.now() < toLocal(v.input_at)) return "Preste atenção...";
    return "Sua vez!";
  }

  function onPress(c) {
    const seq = v.seq;
    if (i >= seq.length || mine() !== "") return;
    const right = seq[i];
    const action = { type: "press", color: c, i };
    if (c !== right) {
      state = "fail";
      brd.error(right);
      vibrate([60, 40, 60]);
      act(action);
      statusEl.textContent = statusText();
      return;
    }
    i += 1;
    act(action);
    if (i >= seq.length) {
      state = "ok";
      brd.setInteractive(false);
      statusEl.textContent = statusText();
    }
  }

  function round() {
    const n = v.seq.length;
    const out = [header(`Rodada ${v.round_no}`)];
    if (!meIn()) out.push(h("p.caption", "Você saiu. Dá pra assistir até o fim."));
    brd = makeBoard(onPress);
    statusEl = h("p.gn-status", "");
    const repeatRound = v.last && v.last.repeat && v.last.round === v.round_no;
    brd.onFrame = () => {
      const left = toLocal(v.round_at) - performance.now();
      if (left > 0) brd.center(String(Math.ceil(left / 1000)), repeatRound ? "de novo!" : `rodada ${v.round_no}`);
      else brd.center(String(n), n === 1 ? "cor" : "cores");
      const t = statusText();
      if (statusEl.textContent !== t) statusEl.textContent = t;
    };
    if (performance.now() < toLocal(v.input_at)) {
      brd.play(v.seq, toLocal(v.round_at), () => { if (meIn() && mine() === "") brd.setInteractive(true); });
    } else if (meIn() && mine() === "") brd.setInteractive(true);
    out.push(brd.svg, statusEl);
    return out;
  }

  function roundEnd() {
    const last = v.last || {};
    const rows = [
      ...(last.passed || []).map((id) => player(nameOf(id), pcolor(id), true, "✓ passou")),
      ...(last.failed || []).map((id) => player(nameOf(id), pcolor(id), false, last.repeat ? "errou de novo" : "✗ saiu")),
      ...(last.forfeit || []).map((id) => player(nameOf(id), pcolor(id), false, "✗ saiu")),
    ];
    return [header(`Rodada ${last.round || v.round_no}`),
      last.repeat ? big("Todos erraram!", "var(--mostarda)", "Ninguém sai: a rodada se repete.")
        : big(`${cores(last.len || 0)}!`, "color-mix(in srgb, var(--superficie) 65%, var(--salvia))", `Próxima: ${cores((last.len || 0) + 1)}`),
      card(null, h("div.gn-list", rows))];
  }

  function gameOver() {
    const names = (v.winners || []).map(nameOf);
    const best = Math.max(0, ...(v.ranking || []).map((r) => r.best));
    return [header("Genius"),
      names.length ? big(`${names.join(" e ")} venceu!`, "var(--mostarda)", `Chegou a ${cores(best)}`) : big("Fim de jogo", "var(--mostarda)"),
      card(null, h("p.sub", "Classificação"), h("div.gn-list", (v.ranking || []).map((r) => player(nameOf(r.id), pcolor(r.id), true, `${r.pos}º · ${cores(r.best)}`)))),
      h("p.caption", "Se o host quiser, a próxima começa daqui."), button("Sair", "secondary", GH.confirmLeave)];
  }

  const PHASES = { lobby, round, round_end: roundEnd, game_over: gameOver };

  function render() {
    const k = `${v.phase}|${v.round_no}|${v.round_at}`;
    // Durante a rodada, os toques dos outros não remontam a tela (o tabuleiro segue tocando).
    if (v.phase === "round" && k === boardKey && brd && brd.svg.isConnected) {
      statusEl.textContent = statusText();
      return;
    }
    boardKey = k;
    mount(h("div.col", (PHASES[v.phase] || lobby)()));
  }

  GH.games.genius = {
    onOpen: startPings,
    onMessage(msg) {
      if (msg.type === "pong") clock.add(msg.c, msg.h, nowUs());
    },
    render(view, evs) {
      v = view;
      const k = `${v.phase}|${v.round_no}|${v.round_at}`;
      if (v.phase === "round" && k !== key) {
        key = k;
        i = 0;
        state = "";
      }
      if (v.phase !== "round") key = "";
      GH.keepAwake(v.phase !== "lobby");
      render();
      for (const e of evs) {
        if (e.type === "player_joined") GH.sound("join");
        else if (e.type === "player_connection") toast(`${e.name} ${e.connected ? "voltou" : "caiu da rede"}`);
        else if (e.type === "game_over") GH.sound("win");
        else if (e.type === "forfeit") toast(`${e.name} saiu da partida`);
      }
    },
  };
})();
