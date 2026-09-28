// Corrida do Wordle no navegador (games/wordle/screens/wordle_net.gd). O que você digita fica aqui
// até mandar; o host confere a palavra e devolve as cores. Os outros aparecem só com as cores.
"use strict";

(() => {
  const { h, card, mount, toast, sound, vibrate, act, st } = GH;
  const D = GH.desafio;
  const ROWS = ["qwertyuiop", "asdfghjkl", "zxcvbnm"];
  const LEN = 5;

  let v = null;
  let typed = "";
  let pending = false;
  let revealRow = -1;
  let shake = false;

  // Sem acento, só letras: "Canção" -> "cancao".
  const norm = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z]/g, "");

  function grid(guesses, opts = {}) {
    const rows = [];
    for (let r = 0; r < 6; r++) {
      const g = guesses[r];
      const cells = [];
      for (let c = 0; c < LEN; c++) {
        let cls = "wd-tile";
        let ch = "";
        if (g) {
          cls += " c" + g.c[c];
          if (!opts.mini) ch = (g.w || "")[c] || "";
          if (r === revealRow && opts.mine) cls += " flip";
        } else if (opts.active && r === guesses.length) {
          ch = typed[c] || "";
          if (ch) cls += " typed";
        }
        cells.push(h("div", { class: cls, style: { animationDelay: `${c * 0.2}s` } }, ch.toUpperCase()));
      }
      rows.push(h("div.wd-row" + (opts.active && r === guesses.length && shake ? ".shake" : ""), cells));
    }
    return h("div.wd-grid" + (opts.mini ? ".mini" : opts.small ? ".small" : ""), rows);
  }

  function keyColors() {
    const best = {};
    for (const g of (v.me.guesses || [])) {
      const n = norm(g.w);
      for (let i = 0; i < n.length; i++) best[n[i]] = Math.max(best[n[i]] ?? -1, g.c[i]);
    }
    return best;
  }

  function keyboard(disabled) {
    const kc = keyColors();
    const key = (k, label, extra) => h("button", {
      class: `wd-key${extra || ""}${kc[k] !== undefined ? " c" + kc[k] : ""}`, disabled: disabled || undefined,
      onclick: () => press(k),
    }, label);
    return h("div.wd-kb",
      h("div.wd-kr", [...ROWS[0]].map((k) => key(k, k.toUpperCase()))),
      h("div.wd-kr", [...ROWS[1]].map((k) => key(k, k.toUpperCase()))),
      h("div.wd-kr", key("enter", "ENVIAR", " wide"), [...ROWS[2]].map((k) => key(k, k.toUpperCase())), key("back", "⌫", " wide")));
  }

  function press(k) {
    if (!v || v.phase !== "play" || v.me.done || pending) return;
    if (k === "back") typed = typed.slice(0, -1);
    else if (k === "enter") {
      if (typed.length < LEN) { toast("Faltam letras", "red"); doShake(); return; }
      pending = true;
      act({ type: "guess", word: typed, t: D.clock.hostMs() });
      return;
    } else if (typed.length < LEN) typed += k;
    render();
  }

  function doShake() {
    shake = true;
    render();
    setTimeout(() => { shake = false; }, 450);
    vibrate(60);
  }

  document.addEventListener("keydown", (e) => {
    if (!v || st.cfg.jogo !== "wordle" || v.phase !== "play") return;
    if (e.key === "Enter") press("enter");
    else if (e.key === "Backspace") press("back");
    else if (norm(e.key).length === 1 && e.key.length === 1) press(norm(e.key));
    else return;
    e.preventDefault();
  });

  function lines() {
    return [...D.raceLines(v.config), `Modo difícil: ${v.config.dificil ? "ligado" : "desligado"}`];
  }

  function play() {
    const out = [D.header("Wordle"), D.timer(v)];
    if (v.rounds_total > 1) out.push(h("p.caption", `Rodada ${v.round} de ${v.rounds_total}`));
    out.push(grid(v.me.guesses || [], { mine: true, active: !v.me.done }));
    out.push(h("p.center.bold", D.status(v.me)));
    out.push(keyboard(v.me.done));
    out.push(D.minis(v, (colors) => grid(colors.map((c) => ({ w: "", c })), { mini: true })));
    return out;
  }

  function render() {
    let body;
    switch (v.phase) {
      case "lobby": body = D.lobby(v, "Wordle", lines()); break;
      case "countdown": body = D.countdown(v, "Wordle", lines()); break;
      case "play": body = play(); break;
      default: body = D.results(v, h("div.dz-secret", String(v.secret || "").toUpperCase()), (b) => grid(b.guesses, { small: true }));
    }
    mount(h("div.col", body));
    revealRow = -1;
  }

  GH.games.wordle = {
    onOpen: D.startPings,
    onMessage(msg) {
      if (msg.type === "pong") D.clock.add(msg.c, msg.h, Math.round(performance.now() * 1000));
    },
    onRejected(msg) {
      pending = false;
      D.onRejected(msg);
    },
    render(view, evs) {
      const prevPhase = v ? v.phase : "";
      v = view;
      for (const e of evs) {
        if (e.type === "round" || e.type === "started") { typed = ""; pending = false; }
        if (e.id !== v.you) {
          if (e.type === "solved") toast(`${D.byId(v, e.id).name} acertou!`, "green");
          continue;
        }
        if (e.type === "guess") { typed = ""; pending = false; revealRow = (v.me.guesses || []).length - 1; sound("pop"); }
        if (e.type === "rejected") { pending = false; D.onRejected(e.msg); shake = true; setTimeout(() => { shake = false; }, 450); }
        if (e.type === "solved") { sound("win"); vibrate([60, 40, 120]); }
      }
      for (const e of evs) {
        if (e.type === "go") sound("round");
        if (e.type === "time_up") sound("buzzer");
      }
      if (view.phase !== prevPhase) GH.keepAwake(view.phase !== "lobby");
      render();
    },
  };
})();
