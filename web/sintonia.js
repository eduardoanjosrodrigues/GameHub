// Sintonia no navegador: jogador e tabuleiro (games/sintonia/screens/sintonia_game.gd).
// A agulha é ao vivo: quem gira manda a posição até 15 vezes por segundo; nas outras telas só a
// agulha se mexe, sem remontar a página.
"use strict";

(() => {
  const { h, button, card, player, mount, toast, sound, vibrate, act, st } = GH;
  const COLORS = ["#2B59C3", "#C8392B", "#2F7D5B", "#E0A21F", "#6E3B93", "#1E7F86", "#D9772B", "#C4467A"];
  const TEAM = { azul: ["Time Azul", "var(--azul)", "var(--azul-e)"], vermelho: ["Time Vermelho", "var(--vermelho)", "var(--vermelho-e)"] };
  const ZONES = [[-10, -6, 2], [-6, -2, 3], [-2, 2, 4], [2, 6, 3], [6, 10, 2]];
  const ZC = { 4: "#2B59C3", 3: "#C8392B", 2: "#F2B233" };
  const SEND_MS = 66;
  const RATING = [[3, "Tá ligado na tomada?"], [6, "Desliga e liga de novo"], [9, "Assopra o cartucho"], [12, "Nada mal. Nada bom, mas nada mal"],
    [15, "Quase!"], [18, "Vocês venceram!"], [21, "Na mesma sintonia"], [24, "Cérebro galáctico"], [999, "Cabeça explodindo"]];

  let v = null;
  let lastPhase = "";
  let dial = null; // {svg, needle, set(pos), dragging}
  let byEl = null;
  let timerMs = -1;
  let timerEl = null;

  const color = (i) => COLORS[i % COLORS.length];
  const byId = (id) => (v.players || []).find((p) => p.id === id) || { name: "?", color: 0, connected: true };
  const nameOf = (id) => byId(id).name;
  const board = () => st.papel === "board";
  const times = () => v.config.mode === "times";
  const other = (t) => t === "azul" ? "vermelho" : "azul";
  const tname = (t) => (TEAM[t] || ["?"])[0];
  const tint = (c, pct) => `color-mix(in srgb, var(--superficie) ${100 - pct}%, ${c})`;
  const isPsy = () => !board() && v.you && v.you === v.psychic;
  const canTurn = () => board() || (!!v.you && v.you !== v.psychic && (!times() || v.my_team === v.turn_team));
  const canBet = () => board() || (!!v.you && !!v.my_team && v.my_team !== v.turn_team);
  const member = () => board() || !!v.you;
  const psyLine = () => times() ? `${nameOf(v.psychic)} (${tname(v.turn_team)})` : nameOf(v.psychic);

  function big(title, bg, sub) {
    return card(bg || null, h("h2.title", title), sub ? h("p.center.bold", sub) : null);
  }

  function header(text) {
    const kids = [h("h1.title.left.grow", text)];
    if (board() && v.phase !== "lobby") kids.push(button("", "secondary", swapList, "phone", "icon-btn"));
    kids.push(button("", "secondary", GH.confirmLeave, "close", "icon-btn"));
    const out = [h("div.row", kids)];
    const off = v.players.filter((p) => !p.connected);
    if (board() && v.phase !== "lobby" && off.length) out.push(button(`${off.map((p) => p.name).join(", ")} caiu · Trocar aparelho`, "danger", swapList, "phone", "small"));
    return out;
  }

  function score() {
    if (times()) {
      return [h("div.score", ["azul", "vermelho"].map((t) => {
        const turn = t === v.turn_team && v.phase !== "game_over";
        return h("div", { style: { background: tint(TEAM[t][1], turn ? 50 : 18), color: TEAM[t][2] } }, tname(t) + (turn ? " · vez" : ""), h("b", { style: { color: "var(--tinta)" } }, String(v.scores[t])));
      })), h("p.caption.bold", `Ganha quem fizer ${v.win_at}${v.sudden ? " · MORTE SÚBITA" : ""}`)];
    }
    const done = v.rounds.length;
    const cur = done + (["reveal", "game_over"].includes(v.phase) ? 0 : 1);
    return h("div.row", { style: { justifyContent: "center" } }, h("b.big", { style: { fontFamily: "Fraunces", fontSize: "28px" } }, `${v.coop_score} pontos`),
      h("small.caption.bold", `rodada ${cur} de ${done + v.cards_left}`));
  }

  // --- Disco ----------------------------------------------------------------

  const NS = "http://www.w3.org/2000/svg";
  function s(tag, attrs) {
    const el = document.createElementNS(NS, tag);
    for (const [k, val] of Object.entries(attrs || {})) el.setAttribute(k, val);
    return el;
  }
  const CX = 200, CY = 196, R = 180;
  const pt = (p, r) => { const a = Math.PI * (1 - p / 100); return [CX + Math.cos(a) * r, CY - Math.sin(a) * r]; };
  function wedge(a, b, r, fill) {
    a = Math.max(0, Math.min(100, a));
    b = Math.max(0, Math.min(100, b));
    if (b <= a) return null;
    const [x1, y1] = pt(a, r);
    const [x2, y2] = pt(b, r);
    return s("path", { d: `M${CX} ${CY} L${x1} ${y1} A${r} ${r} 0 0 1 ${x2} ${y2} Z`, fill });
  }

  // showTarget: alvo à mostra; interactive: arrastar gira a agulha.
  function dialBlock(showTarget, interactive, showNeedle = true) {
    const svg = s("svg", { viewBox: "0 0 400 210", class: "sint-dial" + (interactive ? " live" : "") });
    svg.append(wedge(0, 100, R, "#FFFCF6"));
    const turn = v.phase === "reveal" && v.rounds.length ? v.rounds[v.rounds.length - 1].team : v.turn_team;
    if (times() && ["guess", "reveal"].includes(v.phase) && v.side) {
      const sc = TEAM[other(turn)][1].replace("var(--azul)", "#2B59C3").replace("var(--vermelho)", "#C8392B");
      const w = v.side === "left" ? wedge(0, v.dial, R, sc) : wedge(v.dial, 100, R, sc);
      if (w) { w.setAttribute("opacity", "0.16"); svg.append(w); }
    }
    if (showTarget && v.target >= 0) {
      for (const z of ZONES) { const w = wedge(v.target + z[0], v.target + z[1], R * 0.97, ZC[z[2]]); if (w) svg.append(w); }
      for (const z of ZONES) {
        const mid = v.target + (z[0] + z[1]) / 2;
        if (mid < 0 || mid > 100) continue;
        const [x, y] = pt(mid, R * 0.82);
        const t = s("text", { x, y: y + 6, "text-anchor": "middle", "font-size": 17, "font-family": "Fraunces", "font-weight": 800, fill: z[2] === 2 ? "#1F1D1A" : "#FFFCF6" });
        t.textContent = z[2];
        svg.append(t);
      }
    }
    for (let i = 0; i <= 10; i++) {
      const [x1, y1] = pt(i * 10, R * 0.93);
      const [x2, y2] = pt(i * 10, R);
      svg.append(s("line", { x1, y1, x2, y2, stroke: "rgba(31,29,26,.35)", "stroke-width": 2 }));
    }
    svg.append(s("path", { d: `M${CX - R} ${CY} A${R} ${R} 0 0 1 ${CX + R} ${CY} Z`, fill: "none", stroke: "#1F1D1A", "stroke-width": 5, "stroke-linejoin": "round" }));
    const needle = s("g");
    const line = s("line", { x1: CX, y1: CY, stroke: "#1F1D1A", "stroke-width": 6, "stroke-linecap": "round" });
    const tip = s("circle", { r: 6, fill: "#1F1D1A" });
    needle.append(line, tip);
    if (showNeedle) svg.append(needle);
    svg.append(s("circle", { cx: CX, cy: CY, r: 14, fill: "#2F7D5B", stroke: "#1F1D1A", "stroke-width": 4 }));
    const d = { svg, dragging: false, pos: v.dial, last: 0 };
    d.draw = (p) => { d.pos = p; const [x, y] = pt(p, R * 0.9); line.setAttribute("x2", x); line.setAttribute("y2", y); tip.setAttribute("cx", x); tip.setAttribute("cy", y); };
    d.set = (p) => { if (!d.dragging) d.draw(p); };
    d.draw(v.dial);
    if (interactive) {
      const from = (e) => {
        const r = svg.getBoundingClientRect();
        const x = (e.clientX - r.left) * 400 / r.width - CX;
        const y = (e.clientY - r.top) * 210 / r.height - CY;
        let a = Math.atan2(-y, x);
        if (y > 0) a = x > 0 ? 0 : Math.PI;
        return Math.max(0, Math.min(100, Math.round((1 - a / Math.PI) * 200) / 2));
      };
      const send = (p, force) => {
        const now = performance.now();
        if (force || now - d.last >= SEND_MS) { d.last = now; act({ type: "dial", pos: p }); }
      };
      svg.addEventListener("pointerdown", (e) => { d.dragging = true; svg.setPointerCapture(e.pointerId); const p = from(e); d.draw(p); send(p, true); e.preventDefault(); });
      svg.addEventListener("pointermove", (e) => { if (!d.dragging) return; const p = from(e); d.draw(p); send(p, false); e.preventDefault(); });
      const up = () => { if (!d.dragging) return; d.dragging = false; send(d.pos, true); };
      svg.addEventListener("pointerup", up);
      svg.addEventListener("pointercancel", up);
    }
    dial = d;
    return card("var(--papel)", svg, v.theme.length === 2 ? h("div.row.sint-ends", h("b.grow", { style: { color: "var(--azul-e)" } }, v.theme[0]),
      h("b.grow", { style: { color: "var(--vermelho-e)", textAlign: "right" } }, v.theme[1])) : null);
  }

  function updateBy() {
    if (!byEl) return;
    byEl.textContent = v.dial_by && v.dial_by !== v.you ? `${nameOf(v.dial_by)} está mexendo` : "";
  }

  // --- Trocar aparelho --------------------------------------------------------
  let swapSeat = "";
  let swapWasOn = false;

  function swapList() {
    swapSeat = "";
    GH.overlay("Trocar aparelho", "A bateria de alguém acabou ou o celular travou? Escolha a pessoa e leia o QR com outro aparelho. Ele entra no lugar dela, com tudo que ela tinha.", [
      ...v.players.map((p) => button(`${p.name}${p.connected ? "" : " (desconectado)"}`, p.connected ? "secondary" : "", () => {
        if (p.connected && !confirm(`${p.name} ainda está conectado. Quando o outro aparelho ler o QR, o de agora sai da partida. Trocar?`)) return;
        swapSeat = p.id;
        swapWasOn = p.connected;
        GH.send({ type: "pedir_vaga", id: p.id });
      }, "phone")),
      button("Fechar", "secondary", GH.closeOverlay)]);
  }

  function onMessage(msg) {
    if (msg.type !== "vaga" || msg.id !== swapSeat) return;
    const url = `http://${location.host}/?v=${msg.token}`;
    GH.overlay(`Vaga de ${nameOf(msg.id)}`, "Leia com a câmera do outro aparelho. O QR vale uma vez só, por 5 minutos.", [
      h("img.qr", { src: `qr.svg?d=${encodeURIComponent(url)}`, alt: "" }), h("p.caption", url), button("Voltar", "secondary", swapList)]);
  }

  // --- Fases ----------------------------------------------------------------

  function lobby() {
    const list = times()
      ? ["azul", "vermelho"].map((t) => card(tint(TEAM[t][1], 25), h("p.sub", { style: { color: TEAM[t][2] } }, tname(t)),
        v.players.filter((p) => p.team === t).map((p) => player(p.name, color(p.color), p.connected, p.id === v.you ? "você" : ""))))
      : [card(null, h("p.sub", `Na mesa (${v.players.length})`), v.players.map((p) => player(p.name, color(p.color), p.connected, p.id === v.you ? "você" : "")))];
    return [header("Sala da Sintonia"), ...list,
      card("var(--papel)", h("p.sub", "Partida"), h("p.bold", times() ? "Times: ganha quem fizer 10" : "Cooperativo: 7 rodadas, todo mundo junto"),
        h("p.caption", { style: { textAlign: "left" } }, `Cronômetro: ${v.config.timer_min > 0 ? v.config.timer_min + " min" : "desligado"}`)),
      h("p.caption", board() ? "Este aparelho é o tabuleiro. Esperando o host começar..." : "Esperando o host começar a partida...")];
  }

  function pick() {
    const out = [header("Sintonia"), score()];
    if (isPsy()) {
      out.push(big("Você dá a dica", "var(--mostarda)", "Veja onde está o alvo e escolha um dos temas."), dialBlock(true, false, false));
      v.options.forEach((o, i) => out.push(h("div.card.sint-opt", { onclick: () => act({ type: "pick_theme", index: i }) },
        h("b", { style: { color: "var(--azul-e)" } }, o[0]), h("b", { style: { color: "var(--vermelho-e)" } }, o[1]))));
      out.push(button("Digitar outro tema", "secondary", askTheme, null, "small"), h("p.caption", "Toque num tema. Depois, fale uma dica que leve a agulha até o alvo."));
      return out;
    }
    out.push(big(`${psyLine()} vai dar a dica`, null, "Escolhendo o tema..."), dialBlock(false, false, false));
    return out;
  }

  function askTheme() {
    const l = h("input.field", { placeholder: "Esquerda (ex: Frio)", maxlength: 40 });
    const r = h("input.field", { placeholder: "Direita (ex: Quente)", maxlength: 40 });
    const ok = () => { GH.closeOverlay(); act({ type: "custom_theme", left: l.value.trim(), right: r.value.trim() }); };
    GH.overlay("Tema", "Os dois extremos: um de cada lado do disco.", [l, r, button("Salvar", "success", ok, "check"), button("Cancelar", "secondary", GH.closeOverlay)]);
    setTimeout(() => l.focus(), 50);
  }

  function dialPhase() {
    timerEl = v.timer_left_ms >= 0 ? h("p.center.bold.big", { style: { color: "var(--vermelho-e)", fontFamily: "Fraunces" } }) : null;
    const out = [header("Sintonia"), score(), timerEl];
    byEl = h("p.caption.bold");
    if (isPsy()) {
      out.push(big("Fale a sua dica!", "var(--mostarda)", "Depois, nada de ajudar: nem cara, nem som."), dialBlock(true, false), byEl);
      return out;
    }
    const turning = canTurn();
    const txt = times() ? `O ${tname(v.turn_team)} gira a agulha` : "Todo mundo gira a agulha";
    out.push(h("p.center.bold.big", { style: { fontFamily: "Fraunces" } }, `Dica de ${psyLine()}`), dialBlock(false, turning), byEl);
    if (turning) {
      out.push(h("p.caption", `${txt}. Arraste no disco. Quando concordarem, travem.`),
        button("Travar a agulha", "success", () => GH.overlay("Travar a agulha?", "Todo mundo do time concorda?", [
          button("Travar", "success", () => { GH.closeOverlay(); act({ type: "lock" }); }), button("Ainda não", "secondary", GH.closeOverlay)]), "check"));
    } else out.push(h("p.caption", `${txt}. Vocês ficam só olhando.`));
    return out;
  }

  function guess() {
    const rival = other(v.turn_team);
    const out = [header("Sintonia"), score(), dialBlock(isPsy(), false)];
    if (canBet()) {
      const sideBtn = (key, label) => button(label, v.side === key ? "" : "secondary", () => act({ type: "side", side: key }));
      const lock = button("Travar a aposta", "success", () => act({ type: "lock_side" }), "check");
      lock.disabled = !v.side;
      out.push(big(`${tname(rival)}: esquerda ou direita?`, tint(TEAM[rival][1], 35), "O centro do alvo está pra que lado da agulha? Acertando, 1 ponto."),
        h("div.grid2", sideBtn("left", "← Esquerda"), sideBtn("right", "Direita →")), lock);
      return out;
    }
    out.push(big(`O ${tname(rival)} está apostando`, null, v.side ? `Por enquanto: ${v.side === "left" ? "esquerda" : "direita"}` : "Apostando..."));
    return out;
  }

  function reveal() {
    const last = v.last || {};
    const pts = last.points || 0;
    const r = v.rounds[v.rounds.length - 1] || {};
    const lines = [];
    if (times()) {
      lines.push(`${tname(r.team)} fez ${pts}.`);
      if (r.side) lines.push(last.side_points ? `${tname(other(r.team))} acertou o lado: +1.` : pts === 4 ? `Centro: a aposta do ${tname(other(r.team))} não vale.` : `${tname(other(r.team))} errou o lado.`);
      if (last.catch_up) lines.push(`Recuperação! O ${tname(r.team)} joga de novo.`);
      if (v.sudden && !v.winner) lines.push("Empate: morte súbita!");
    } else if (last.bonus) lines.push("Centro vale 3 e dá uma rodada extra!");
    if (v.winner) lines.push("Fim de jogo!");
    const title = pts === 4 || last.bonus ? "No centro!" : pts > 0 ? `+${pts} ponto${pts === 1 ? "" : "s"}` : "Passou longe!";
    const bg = pts >= 3 ? tint("var(--salvia)", 45) : pts > 0 ? "var(--mostarda)" : tint("var(--vermelho)", 30);
    return [header("Revelação"), score(), dialBlock(true, false), big(title, bg, lines.join(" ")),
      member() ? button(v.winner ? "Ver o resultado" : "Próxima rodada", "success", () => act({ type: "continue" }), "play") : null];
  }

  function gameOver() {
    let head;
    if (times()) head = big(`${tname(v.winner)} venceu!`, tint(TEAM[v.winner][1], 45), `${v.scores[v.winner]} a ${v.scores[other(v.winner)]}`);
    else head = big(`${v.coop_score} pontos`, "var(--mostarda)", (RATING.find((x) => v.coop_score <= x[0]) || [0, ""])[1]);
    const lines = v.rounds.map((r, k) => h("div", h("p.bold", `${k + 1}. ${r.theme[0]} – ${r.theme[1]} · dica de ${nameOf(r.psychic)}`),
      h("p.caption", { style: { textAlign: "left" } }, `alvo ${r.target}, agulha ${r.dial}: ${r.points} ponto${r.points === 1 ? "" : "s"}${r.side_points ? " · aposta certa" : ""}`)));
    return [head, score(), card("var(--papel)", h("p.sub", "As rodadas"), lines),
      h("p.caption", "Se o host quiser, a próxima começa daqui."), button("Sair", "secondary", GH.confirmLeave)];
  }

  const PHASES = { lobby, pick, dial: dialPhase, guess, reveal, game_over: gameOver };

  function render() {
    timerEl = null;
    byEl = null;
    dial = null;
    mount(h("div.col" + (board() ? ".av-board" : ""), (PHASES[v.phase] || lobby)()));
    updateBy();
    tickTimer();
  }

  function tickTimer() {
    if (!timerEl || !document.body.contains(timerEl)) return;
    const sec = Math.ceil(timerMs / 1000);
    timerEl.textContent = sec <= 0 ? "Tempo esgotado! Travem a agulha." : `Tempo: ${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;
  }
  let lastTick = performance.now();
  setInterval(() => {
    const now = performance.now();
    if (timerMs > 0) timerMs = Math.max(0, timerMs - (now - lastTick));
    lastTick = now;
    tickTimer();
  }, 250);

  function events(list) {
    for (const e of list) {
      switch (e.type) {
        case "player_joined": sound("join"); break;
        case "player_connection": toast(`${e.name} ${e.connected ? "voltou" : "caiu da rede"}`); break;
        case "round":
          if (e.psychic === v.you && !board()) { sound("hg_turn"); vibrate([40, 70, 40]); } else sound("pop");
          break;
        case "revealed": sound(e.points >= 4 || e.bonus ? "win" : e.points > 0 ? "hit" : "skip"); vibrate(40); break;
        case "game_over": sound("win"); break;
      }
    }
  }

  GH.games.sintonia = {
    onMessage,
    render(view, evs) {
      const prev = v;
      v = view;
      if (swapSeat && !swapWasOn && byId(swapSeat).connected) {
        toast(`${nameOf(swapSeat)} entrou no aparelho novo.`, "green");
        swapSeat = "";
        GH.closeOverlay();
      }
      // Só a agulha mexeu: move a agulha, sem remontar.
      if (prev && view.phase === lastPhase && evs.length && evs.every((e) => e.type === "dial") && dial && document.body.contains(dial.svg)) {
        dial.set(view.dial);
        updateBy();
        return;
      }
      if (view.phase !== lastPhase) {
        GH.closeOverlay();
        GH.keepAwake(view.phase !== "lobby");
      }
      timerMs = view.timer_left_ms;
      lastPhase = view.phase;
      render();
      events(evs);
    },
  };
})();
