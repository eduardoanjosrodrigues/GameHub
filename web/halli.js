// Halli Galli no navegador: o celular deitado na mesa é a carta do dono (games/halli_galli/).
// Arrastar vira, toque duplo bate o sino. O sino leva o instante exato do toque, convertido pro
// relógio do host pelos pings (mesma conta do net/clock_sync.gd).
"use strict";

(() => {
  const { h, button, card, player, mount, toast, sound, vibrate, act, send } = GH;
  const COLORS = ["#2B59C3", "#C8392B", "#2F7D5B", "#E0A21F", "#6E3B93", "#1E7F86", "#D9772B", "#C4467A"];
  const FRUITS = ["banana", "morango", "limao", "ameixa"];
  const FRUIT_NAMES = ["bananas", "morangos", "limões", "ameixas"];
  const SLOTS = {
    1: [[0.5, 0.5]],
    2: [[0.32, 0.29], [0.68, 0.71]],
    3: [[0.28, 0.24], [0.5, 0.5], [0.72, 0.76]],
    4: [[0.3, 0.27], [0.7, 0.27], [0.3, 0.73], [0.7, 0.73]],
    5: [[0.28, 0.21], [0.72, 0.21], [0.5, 0.5], [0.28, 0.79], [0.72, 0.79]],
  };
  const SCALE = { 1: 0.7, 2: 0.52, 3: 0.44, 4: 0.44, 5: 0.4 };
  const ANGLES = [-8, 10, -4, 6, -10];
  const COOLDOWN_MS = 500;
  const SWIPE_PX = 40;
  const TAP_SLOP_PX = 24;
  const TAP_MAX_MS = 260;
  const DOUBLE_GAP_MS = 300;
  const DOUBLE_DIST_PX = 80;
  const WEAK_RTT_MS = 150;

  const color = (i) => COLORS[i % COLORS.length];
  const nowUs = () => Math.round(performance.now() * 1000);

  // --- Relógio do host -------------------------------------------------------

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
    toHostMs(localUs) { return Math.floor((localUs + this.offset()) / 1000); },
    hostNow() { return this.toHostMs(nowUs()); },
    lastRtt() { return this.samples.length ? this.samples[this.samples.length - 1].rtt / 1000 : 0; },
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

  // --- Estado ---------------------------------------------------------------

  let v = null;
  let lastPhase = "";
  let pending = null; // virada mostrada antes da resposta do host: {preTop, at}
  let ui = null; // elementos da tela de jogo
  let shownTop = -1;
  let pauseKey = "";

  const me = () => (v.players || []).find((p) => p.id === v.you) || null;
  const byId = (id) => (v.players || []).find((p) => p.id === id) || null;

  // --- Carta ----------------------------------------------------------------

  function fillCard(el, c) {
    el.replaceChildren();
    el.className = "hg-card";
    if (c < 0) {
      el.classList.add("empty");
      return;
    }
    const n = c % 10;
    const f = Math.floor(c / 10);
    SLOTS[n].forEach(([x, y], i) => {
      el.append(h("img", {
        src: `assets/${FRUITS[f]}.svg`, alt: "", draggable: "false",
        style: { left: `${x * 100}%`, top: `${y * 100}%`, width: `${SCALE[n] * 100}%`, "--r": `${ANGLES[i]}deg` },
      }));
    });
  }

  function setTop(c) {
    if (!ui || c === shownTop) return;
    const old = shownTop;
    shownTop = c;
    if (c < 0 && old >= 0) {
      // Alguém levou a mesa: a carta sai voando.
      const ghost = ui.card.cloneNode(true);
      ghost.classList.add("leave");
      ghost.style.position = "absolute";
      ui.area.append(ghost);
      setTimeout(() => ghost.remove(), 400);
    }
    fillCard(ui.card, c);
    if (c < 0) ui.card.textContent = v && v.turn === v.you ? "Arraste pra virar" : "Sua carta aparece aqui";
    else {
      ui.card.classList.remove("flip");
      void ui.card.offsetWidth;
      ui.card.classList.add("flip");
    }
  }

  function banner(title, sub, bg) {
    if (!ui) return;
    const b = h("div.hg-banner", { style: { background: bg } }, h("b", title), sub ? h("span", sub) : null);
    ui.root.append(b);
    setTimeout(() => b.remove(), 1450);
  }

  // --- Tela de jogo ----------------------------------------------------------

  function buildPlay() {
    const root = h("div.hg-play");
    const svg = h("div", { html: '<svg class="hg-border"><rect class="base"/><rect class="prog" pathLength="1"/></svg>' }).firstChild;
    const leave = button("", "secondary", GH.confirmLeave, "close", "icon-btn");
    leave.classList.add("hg-leave");
    const status = h("div.hg-status");
    const hint = h("div.hg-hint");
    const cardEl = h("div.hg-card.empty");
    const area = h("div.hg-area", cardEl);
    const count = h("span");
    const pile = h("div.hg-pile", count);
    const name = h("b");
    const down = h("small");
    const weak = h("div.hg-weak");
    root.append(svg, leave, status, hint, area, h("div.hg-bottom", pile, h("div.hg-who", weak, name, down)));
    ui = { root, svg, status, hint, card: cardEl, area, pile, count, name, down, weak };
    shownTop = -2;
    mount(root);
    sizeBorder();
    gestures(root);
  }

  function sizeBorder() {
    if (!ui) return;
    const w = window.innerWidth;
    const hh = window.innerHeight;
    ui.svg.setAttribute("viewBox", `0 0 ${w} ${hh}`);
    for (const r of ui.svg.querySelectorAll("rect")) {
      r.setAttribute("x", 7); r.setAttribute("y", 7);
      r.setAttribute("width", Math.max(0, w - 14)); r.setAttribute("height", Math.max(0, hh - 14));
      r.setAttribute("rx", 26);
    }
  }
  window.addEventListener("resize", sizeBorder);

  function updatePlay() {
    const m = me();
    if (!m || !ui) return;
    const col = color(m.color);
    ui.root.style.setProperty("--c", col);
    if (pending && (v.top !== pending.preTop || v.turn !== v.you)) pending = null;
    const myTurn = !pending && v.turn === v.you && !m.out;
    if (!pending) {
      setTop(v.top);
      if (v.top < 0) ui.card.textContent = v.turn === v.you ? "Arraste pra virar" : "Sua carta aparece aqui";
      ui.count.textContent = m.down;
      ui.pile.classList.toggle("zero", m.down <= 0);
      ui.down.textContent = `${m.down} ${m.down === 1 ? "carta" : "cartas"} no monte`;
    }
    ui.name.textContent = m.name;
    ui.root.classList.toggle("turn", myTurn);
    ui.root.dataset.turn = myTurn ? "1" : "";
    const turnP = byId(v.turn);
    if (pending) {
      ui.status.textContent = "";
      ui.hint.textContent = "Toque duas vezes pra bater o sino";
    } else if (m.out) {
      ui.status.textContent = "Você saiu";
      ui.hint.textContent = "Sua carta continua valendo até alguém levar a mesa";
    } else if (myTurn) {
      ui.status.textContent = "Sua vez!";
      ui.hint.textContent = "Toque duas vezes pra bater o sino";
    } else {
      ui.status.textContent = turnP ? `Vez de ${turnP.name}` : "";
      ui.hint.textContent = "Toque duas vezes pra bater o sino";
    }
  }

  function frame() {
    if (ui && v && v.phase === "playing") {
      const prog = ui.svg.querySelector(".prog");
      const base = ui.svg.querySelector(".base");
      if (ui.root.dataset.turn) {
        const frac = Math.max(0, Math.min(1, 1 - (v.next_flip_at - clock.hostNow()) / COOLDOWN_MS));
        prog.style.display = "";
        base.style.display = "";
        prog.setAttribute("stroke-dasharray", `${frac} 1`);
        prog.classList.toggle("full", frac >= 1);
      } else {
        prog.style.display = "none";
        base.style.display = "none";
      }
      const weak = clock.samples.length >= 3 && clock.lastRtt() > WEAK_RTT_MS;
      ui.weak.textContent = weak ? "sinal fraco" : "";
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  // --- Gestos ---------------------------------------------------------------

  function gestures(root) {
    const touches = {};
    let lastTapAt = 0;
    let lastTapPos = null;
    root.addEventListener("pointerdown", (e) => {
      if (e.target.closest("button")) return;
      e.preventDefault();
      const p = { x: e.clientX, y: e.clientY };
      if (lastTapAt && e.timeStamp - lastTapAt <= DOUBLE_GAP_MS && Math.hypot(p.x - lastTapPos.x, p.y - lastTapPos.y) <= DOUBLE_DIST_PX) {
        lastTapAt = 0;
        touches[e.pointerId] = { start: p, t: e.timeStamp, used: true };
        ripple(p);
        bell(Math.round(e.timeStamp * 1000));
        return;
      }
      touches[e.pointerId] = { start: p, t: e.timeStamp, used: false };
    }, { passive: false });
    root.addEventListener("pointermove", (e) => {
      const t = touches[e.pointerId];
      if (!t || t.used) return;
      if (Math.hypot(e.clientX - t.start.x, e.clientY - t.start.y) >= SWIPE_PX) {
        t.used = true;
        lastTapAt = 0;
        flip();
      }
    });
    const end = (e) => {
      const t = touches[e.pointerId];
      delete touches[e.pointerId];
      if (!t || t.used) return;
      if (Math.hypot(e.clientX - t.start.x, e.clientY - t.start.y) <= TAP_SLOP_PX && e.timeStamp - t.t <= TAP_MAX_MS) {
        lastTapAt = e.timeStamp;
        lastTapPos = { x: e.clientX, y: e.clientY };
      }
    };
    root.addEventListener("pointerup", end);
    root.addEventListener("pointercancel", (e) => { delete touches[e.pointerId]; });
    // iPhone: sem isso o toque duplo dá zoom e o arrastar rola a página.
    root.addEventListener("touchstart", (e) => { if (!e.target.closest("button")) e.preventDefault(); }, { passive: false });
    root.addEventListener("touchmove", (e) => e.preventDefault(), { passive: false });
  }

  function ripple(p) {
    const r = h("div.hg-ripple", { style: { left: `${p.x}px`, top: `${p.y}px` } }, h("img", { src: "assets/sino.svg", alt: "" }));
    ui.root.append(r);
    setTimeout(() => r.remove(), 650);
  }

  function canAct() {
    const m = me();
    return v && v.phase === "playing" && !v.paused && m && !m.out;
  }

  function flip() {
    if (!canAct() || pending) return;
    if (v.turn !== v.you || clock.hostNow() < v.next_flip_at || v.next < 0) {
      vibrate(10);
      return;
    }
    // Mostra a carta na hora; o host confirma em seguida.
    pending = { preTop: v.top, at: performance.now() };
    setTop(v.next);
    const m = me();
    const left = Math.max(0, m.down - 1);
    ui.count.textContent = left;
    ui.down.textContent = `${left} ${left === 1 ? "carta" : "cartas"} no monte`;
    vibrate(15);
    sound("hg_flip");
    act({ type: "flip", t: clock.hostNow() });
    updatePlay();
    setTimeout(() => {
      if (pending && performance.now() - pending.at >= 1400) {
        pending = null;
        updatePlay();
      }
    }, 1500);
  }

  function bell(localUs) {
    if (!canAct()) return;
    vibrate(25);
    sound("hg_bell");
    act({ type: "bell", t: clock.toHostMs(localUs) });
  }

  // --- Eventos --------------------------------------------------------------

  function onBell(e) {
    const who = byId(e.player) || { name: "", color: 0 };
    const margin = e.margin_ms >= 0 ? ` · por ${e.margin_ms} ms` : "";
    if (e.ok) {
      const what = e.fruit >= 0 ? `5 ${FRUIT_NAMES[e.fruit]}` : "";
      if (e.player === v.you) {
        vibrate(200);
        sound("hg_collect");
        banner(`+${e.cards} cartas!`, what + margin, "var(--salvia)");
      } else {
        banner(`${who.name} levou`, what + margin, color(who.color));
      }
    } else if (e.player === v.you) {
      vibrate([45, 45, 45, 45, 45]);
      sound("hg_wrong");
      banner("Errou!", `A mesa voltou pros donos · −${e.cards} ${e.cards === 1 ? "carta" : "cartas"}`, "var(--vermelho)");
    } else if ((e.to || []).includes(v.you)) {
      vibrate(18);
      toast(`${who.name} errou: sua carta voltou pro monte e ganhou +1`);
    } else {
      toast(`${who.name} errou: as cartas voltaram pro monte`);
    }
  }

  function events(list) {
    for (const e of list) {
      switch (e.type) {
        case "turn":
          if (e.player === v.you) { vibrate([40, 70, 40]); sound("hg_turn"); }
          break;
        case "bell": onBell(e); break;
        case "back_in":
          if (e.player === v.you) { vibrate(200); toast("Sua carta voltou: você está de novo no jogo!", "green"); }
          else toast(`${e.name} voltou pro jogo`);
          break;
        case "undo_flip":
          if (e.player === v.you) toast("Alguém bateu antes da sua carta: ela voltou pro monte");
          break;
        case "out":
          if (e.player === v.you) { vibrate(350); sound("hg_out"); banner("Você saiu", "Pode torcer pelos outros", "var(--tinta)"); }
          else toast(`${e.name} saiu do jogo`);
          break;
        case "game_over":
          sound(e.winner === v.you ? "win" : "round");
          if (e.winner === v.you) vibrate([60, 60, 60, 60, 220]);
          break;
        case "player_joined": sound("join"); break;
        case "player_connection": toast(`${e.name} ${e.connected ? "voltou" : "caiu da rede"}`); break;
      }
    }
  }

  function updatePause() {
    const paused = v.phase === "playing" && v.paused;
    const away = (v.players || []).filter((p) => !p.connected);
    const key = paused ? away.map((p) => p.id).join(",") : "";
    if (key === pauseKey) return;
    pauseKey = key;
    if (paused) GH.overlay("Pausado", `Esperando ${away.map((p) => p.name).join(", ")} voltar pra rede...`);
    else GH.closeOverlay();
  }

  // --- Sala e fim -----------------------------------------------------------

  function lobby() {
    const decks = v.config.decks;
    const per = Math.floor(decks * 56 / Math.max(1, v.players.length));
    return h("div.col",
      h("div.row", h("h1.title.left.grow", "Sala do Halli Galli"), button("", "secondary", GH.confirmLeave, "close", "icon-btn")),
      card(null, h("p.sub", `Ordem da mesa (${v.players.length})`),
        h("p.caption", { style: { textAlign: "left" } }, "A vez passa de cima pra baixo. Quem criou a sala arruma a ordem."),
        v.players.map((p, i) => player(`${i + 1}. ${p.name}`, color(p.color), p.connected, !p.connected ? "desconectado" : (p.id === v.you ? "você" : "")))),
      card("var(--papel)", h("p.sub", "Baralhos"), h("p.center", `${decks} ${decks === 1 ? "baralho" : "baralhos"} · ${decks * 56} cartas · uns ${per} pra cada`)),
      card("var(--mostarda)", h("p.bold", "Deixe o celular deitado na mesa, na sua frente: ele é a sua carta. Arraste pra virar na sua vez e toque duas vezes em qualquer lugar pra bater o sino.")),
      h("p.caption", "Esperando o host começar a partida..."));
  }

  function ranking() {
    const ids = [v.winner, ...v.players.filter((p) => !p.out).map((p) => p.id), ...[...v.out_order].reverse()];
    const seen = new Set();
    return ids.map(byId).filter((p) => p && !seen.has(p.id) && seen.add(p.id));
  }

  function gameOver() {
    const w = byId(v.winner);
    const title = v.winner === v.you ? "Você venceu!" : (w ? `${w.name} venceu!` : "Fim de jogo");
    return h("div.col",
      card(w ? color(w.color) : "var(--mostarda)", h("div", { style: { fontSize: "72px", textAlign: "center" } }, "🏆"), h("h2.title", { style: { fontSize: "44px" } }, title)),
      card(null, h("p.sub", "Classificação"), ranking().map((p, i) =>
        player(`${i + 1}º ${p.name}`, color(p.color), true, `${p.ok} certo${p.ok === 1 ? "" : "s"} · ${p.wrong} errado${p.wrong === 1 ? "" : "s"}`))),
      h("p.caption", "Se o host quiser, a próxima começa daqui."));
  }

  GH.games.halli = {
    onOpen: startPings,
    onMessage(msg) {
      if (msg.type === "pong") clock.add(msg.c, msg.h, nowUs());
    },
    onRejected() {
      pending = null;
      if (v) updatePlay();
    },
    render(view, evs) {
      v = view;
      if (view.phase !== lastPhase) {
        pending = null;
        ui = null;
        GH.keepAwake(view.phase === "playing");
        if (view.phase === "playing") {
          buildPlay();
          GH.preload(["hg_bell", "hg_flip", "hg_collect", "hg_wrong", "hg_turn", "hg_out", "win"]);
        }
      }
      if (view.phase === "lobby") mount(lobby());
      else if (view.phase === "playing") updatePlay();
      else if (view.phase === "game_over" && lastPhase !== "game_over") mount(gameOver());
      lastPhase = view.phase;
      updatePause();
      events(evs);
    },
  };
})();
