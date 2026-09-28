// Senha no navegador (games/senha/screens/senha_net.gd): Corrida e Duelo. As cores e formas dos
// pinos são as mesmas de games/senha/ui/senha_art.gd.
"use strict";

(() => {
  const { h, card, mount, toast, sound, vibrate, act, st, button } = GH;
  const D = GH.desafio;
  const PEG = ["#C8392B", "#2B59C3", "#F2B233", "#2F7D5B", "#6E3B93", "#D9772B", "#C4467A", "#1E7F86"];
  const TILE = { 2: "#2F7D5B", 1: "#F2B233", 0: "#6B6358" };
  const NS = "http://www.w3.org/2000/svg";
  const TRIES = 10;
  const LEVELS = { facil: "Fácil", medio: "Médio", dificil: "Difícil" };

  let v = null;
  let typed = [];
  let pending = false;
  let shake = false;

  const duel = () => v.config.modo === "duelo";
  const look = () => v.config.aparencia;
  const fbMode = () => v.config.retorno;

  function s(tag, attrs) {
    const el = document.createElementNS(NS, tag);
    for (const [k, val] of Object.entries(attrs || {})) el.setAttribute(k, val);
    return el;
  }
  function poly(n, r, start, cx = 20, cy = 20) {
    const pts = [];
    for (let i = 0; i < n; i++) { const a = start + i * 2 * Math.PI / n; pts.push(`${cx + Math.cos(a) * r},${cy + Math.sin(a) * r}`); }
    return pts.join(" ");
  }
  function shape(i, fill) {
    const r = 8.4;
    switch (i) {
      case 0: return s("circle", { cx: 20, cy: 20, r: r * 0.8, fill });
      case 1: return s("polygon", { points: poly(3, r * 1.1, -Math.PI / 2, 20, 21.3), fill });
      case 2: return s("rect", { x: 20 - r * 0.75, y: 20 - r * 0.75, width: r * 1.5, height: r * 1.5, fill });
      case 3: return s("polygon", { points: poly(4, r * 1.05, -Math.PI / 2), fill });
      case 4: {
        const pts = [];
        for (let k = 0; k < 10; k++) { const a = -Math.PI / 2 + k * Math.PI / 5; const rr = k % 2 ? r * 0.45 : r * 1.1; pts.push(`${20 + Math.cos(a) * rr},${20 + Math.sin(a) * rr}`); }
        return s("polygon", { points: pts.join(" "), fill });
      }
      case 5: { const g = s("g", { fill }); g.append(s("rect", { x: 20 - r, y: 20 - r * 0.32, width: r * 2, height: r * 0.64 }), s("rect", { x: 20 - r * 0.32, y: 20 - r, width: r * 0.64, height: r * 2 })); return g; }
      case 6: return s("polygon", { points: poly(6, r * 0.95, 0), fill });
      default: return s("circle", { cx: 20, cy: 20, r: r * 0.7, fill: "none", stroke: fill, "stroke-width": r * 0.4 });
    }
  }

  // Um pino (svg 40x40). sym < 0 = vaga vazia.
  function peg(sym, size, extra) {
    const svg = s("svg", { viewBox: "0 0 40 40", width: size, height: size, class: "sn-peg" + (extra || "") });
    if (sym < 0) {
      svg.append(s("circle", { cx: 20, cy: 20, r: 17, fill: "none", stroke: "#E3DACB", "stroke-width": 3 }), s("circle", { cx: 20, cy: 20, r: 4, fill: "#E3DACB" }));
      return svg;
    }
    if (look() === "numeros") {
      svg.append(s("circle", { cx: 20, cy: 20, r: 18, fill: "#FFFCF6", stroke: "#1F1D1A", "stroke-width": 2.5 }));
      const t = s("text", { x: 20, y: 27.5, "text-anchor": "middle", "font-size": 21, "font-family": "Fraunces", "font-weight": 800, fill: "#1F1D1A" });
      t.textContent = String(sym + 1);
      svg.append(t);
      return svg;
    }
    svg.append(s("circle", { cx: 20, cy: 20, r: 18, fill: PEG[sym % 8] }));
    svg.append(shape(sym % 8, sym % 8 === 2 ? "#1F1D1A" : "#FFFCF6"));
    return svg;
  }

  function countDots(fb, pins) {
    const box = h("div.sn-dots", { style: { gridTemplateColumns: `repeat(${Math.ceil(pins / 2)}, 1fr)` } });
    for (let i = 0; i < pins; i++) box.append(h("span" + (i < fb[0] ? ".b" : i < fb[0] + fb[1] ? ".w" : "")));
    return box;
  }

  // board: [{w, c}]. opts: mini (só retorno), active (linha atual), small.
  function board(guesses, opts = {}) {
    const pins = v.pins;
    const rows = [];
    const n = opts.compact ? Math.min(TRIES, guesses.length + (opts.active ? 1 : 0)) : TRIES;
    const size = opts.mini ? 14 : opts.small ? 24 : 38;
    for (let r = 0; r < Math.max(1, n); r++) {
      const g = guesses[r];
      const cur = opts.active && r === guesses.length;
      const cells = [];
      for (let i = 0; i < pins; i++) {
        let sym = -1;
        let tile = null;
        if (g) {
          sym = opts.mini ? -2 : g.w[i];
          if (fbMode() === "posicao") tile = TILE[g.c[i]];
        } else if (cur && i < typed.length) sym = typed[i];
        const cell = h("div.sn-cell", tile ? { style: { background: tile } } : null, sym === -2 ? null : peg(sym, size));
        if (cur && i < typed.length) cell.addEventListener("click", () => { typed.splice(i, 1); render(); });
        cells.push(cell);
      }
      rows.push(h("div.sn-row" + (cur ? ".cur" : "") + (cur && shake ? ".shake" : "") + (opts.mini ? ".mini" : ""),
        h("span.sn-n", String(r + 1)), h("div.sn-pegs", cells), g && fbMode() === "contagem" ? countDots(g.c, pins) : fbMode() === "contagem" ? h("div.sn-dots") : null));
    }
    return h("div.sn-board" + (opts.mini ? ".mini" : ""), rows);
  }

  function code(pins, size = 34) {
    return h("div.sn-code", pins.map((p) => peg(p, size)));
  }

  function canPlay() {
    if (v.phase === "create") return !v.codes_ready[v.you];
    if (v.phase !== "play" || v.me.done) return false;
    return !(duel() && v.config.duelo === "alternado" && v.turn !== v.you);
  }

  function input(label) {
    const can = canPlay() && !pending;
    const pal = h("div.sn-pal");
    for (let i = 0; i < v.symbols; i++) {
      const blocked = !v.repeat && typed.includes(i);
      const b = h("button.sn-pick", { disabled: (!can || blocked || typed.length >= v.pins) || undefined, onclick: () => { typed.push(i); render(); } }, peg(i, 44));
      pal.append(b);
    }
    return [pal, h("div.row",
      button("Apagar", "secondary", () => { typed.pop(); render(); }, "back"),
      (() => { const b = button(label || "Enviar", "success", submit, "check"); if (!can || typed.length < v.pins) b.disabled = true; return b; })())];
  }

  function submit() {
    if (!canPlay() || pending || typed.length < v.pins) return;
    if (!v.repeat && new Set(typed).size !== typed.length) { toast("No Fácil, a senha não repete símbolo.", "red"); return; }
    pending = true;
    if (v.phase === "create") act({ type: "set_code", pins: typed.slice() });
    else act({ type: "guess", pins: typed.slice(), t: D.clock.hostMs() });
    render();
  }

  function lines() {
    const c = v.config;
    const out = [`Modo: ${c.modo === "duelo" ? "Duelo · " + (c.duelo === "alternado" ? "Alternado" : "Modo tempo") : "Corrida"}`,
      `Nível: ${LEVELS[c.nivel]} · retorno ${c.retorno === "contagem" ? "por contagem" : "por posição"} · ${c.aparencia === "cores" ? "cores" : "números"}`];
    if (c.modo === "duelo") out.push(`Tempo: ${c.tempo_min > 0 ? c.tempo_min + " min" : "sem limite"}`);
    else out.push(...D.raceLines(c));
    return out;
  }

  function create() {
    const opp = D.byId(v, v.opponent).name;
    if (v.codes_ready[v.you]) {
      return [D.header("Duelo"), card("var(--salvia)", h("h2.title", "Senha criada!"), h("p.center.bold", `Esperando ${opp} criar a senha pra você...`)),
        h("p.center.bold", "A sua senha:"), code(v.my_code)];
    }
    return [D.header("Duelo"), card("var(--mostarda)", h("h2.title", `Crie a senha de ${opp}`), h("p.center.bold", `${opp} vai tentar quebrar. Não deixe ninguém ver!`)),
      board([], { active: true, compact: true }), ...input("Pronto")];
  }

  function turnText() {
    if (v.me.solved) return v.config.duelo === "alternado" ? `Quebrou! Última chance de ${D.byId(v, v.opponent).name}...` : "Quebrou!";
    if (v.config.duelo !== "alternado") return "Os dois ao mesmo tempo: quebre primeiro!";
    return v.turn === v.you ? "Sua vez!" : `Vez de ${D.byId(v, v.turn).name}...`;
  }

  function duelPlay() {
    const opp = D.byId(v, v.opponent).name;
    return [D.header("Duelo"), D.timer(v), h("h2.title", turnText()),
      h("p.caption.bold", `Você quebrando a senha de ${opp}`),
      board(v.me.guesses || [], { active: canPlay() }), ...input(),
      card("var(--papel)", h("p.center.bold", `${opp} atacando a sua senha`), code(v.my_code, 26), board((v.opp_board || {}).guesses || [], { small: true, compact: true }))];
  }

  function duelEnd() {
    const w = v.winner;
    const title = w === "" ? "Empate!" : w === v.you ? "Você venceu!" : `${D.byId(v, w).name} venceu!`;
    return [D.header("Fim do duelo"), card(w === v.you || w === "" ? "var(--salvia)" : "var(--vermelho)", h("h2.title", title), v.time_up ? h("p.center.bold", "Tempo esgotado.") : null),
      h("div.dz-minis", v.players.map((p) => {
        const other = v.players.find((q) => q.id !== p.id) || { id: "", name: "?" };
        const bv = v.boards[p.id] || { guesses: [] };
        return h("div.dz-mini", h("p.bold", `${p.name}: ${bv.solved ? "quebrou em " + bv.guesses.length : "não quebrou"}`),
          h("p.caption", `Senha de ${other.name}:`), code(v.codes[other.id] || [], 24), board(bv.guesses, { small: true, compact: true }));
      })),
      h("p.caption", "Se o host quiser, a próxima começa daqui."), button("Sair", "secondary", GH.confirmLeave, "close")];
  }

  function race() {
    const out = [D.header("Senha"), D.timer(v)];
    if (v.rounds_total > 1) out.push(h("p.caption", `Rodada ${v.round} de ${v.rounds_total}`));
    out.push(board(v.me.guesses || [], { active: !v.me.done }), h("p.center.bold", D.status(v.me)), ...input(),
      D.minis(v, (colors) => board(colors.map((c) => ({ w: [], c })), { mini: true, compact: true })));
    return out;
  }

  function render() {
    let body;
    switch (v.phase) {
      case "lobby": body = D.lobby(v, "Senha", lines()); break;
      case "create": body = create(); break;
      case "countdown": body = D.countdown(v, duel() ? "Duelo" : "Senha", lines()); break;
      case "play": body = duel() ? duelPlay() : race(); break;
      default:
        body = duel() ? duelEnd() : D.results(v, code(v.secret || []), (b) => board(b.guesses, { small: true, compact: true }));
    }
    mount(h("div.col", body));
  }

  GH.games.senha = {
    onOpen: D.startPings,
    onMessage(msg) {
      if (msg.type === "pong") D.clock.add(msg.c, msg.h, Math.round(performance.now() * 1000));
    },
    onRejected(msg) {
      pending = false;
      D.onRejected(msg);
      if (v) render();
    },
    render(view, evs) {
      const prevPhase = v ? v.phase : "";
      v = view;
      for (const e of evs) {
        if (e.type === "round" || e.type === "started") { typed = []; pending = false; }
        if (e.type === "go") sound("round");
        if (e.type === "time_up") sound("buzzer");
        if (e.id !== v.you) {
          if (e.type === "solved" && !duel()) toast(`${D.byId(v, e.id).name} acertou!`, "green");
          continue;
        }
        if (e.type === "code_set") { typed = []; pending = false; }
        if (e.type === "guess") { typed = []; pending = false; sound("pop"); }
        if (e.type === "rejected") { pending = false; D.onRejected(e.msg); shake = true; setTimeout(() => { shake = false; }, 450); }
        if (e.type === "solved") { sound("win"); vibrate([60, 40, 120]); }
        if (e.type === "turn") { sound("tap"); vibrate(40); }
      }
      if (view.phase !== prevPhase) GH.keepAwake(view.phase !== "lobby");
      render();
    },
  };
})();
