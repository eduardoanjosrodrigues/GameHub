// Ito no navegador: jogador e tabuleiro (games/ito/screens/ito_game.gd).
"use strict";

(() => {
  const { h, button, card, player, mount, toast, sound, vibrate, act, st } = GH;
  const COLORS = ["#2B59C3", "#C8392B", "#2F7D5B", "#E0A21F", "#6E3B93", "#1E7F86", "#D9772B", "#C4467A"];
  const STEP_MS = 600;

  let v = null;
  let lastPhase = "";
  let sel = ""; // carta escolhida pra pôr ou mudar de lugar
  let selNew = false;
  let animRound = -1;
  let timers = [];
  let timerMs = -1;
  let timerEl = null;

  const color = (i) => COLORS[i % COLORS.length];
  const byId = (id) => (v.players || []).find((p) => p.id === id) || { name: "?", color: 0, connected: true };
  const nameOf = (id) => byId(id).name;
  const board = () => st.papel === "board";
  const member = () => !board() && !!v.you;
  const desafio = () => v.config.mode === "desafio";
  const tint = (c, pct) => `color-mix(in srgb, var(--superficie) ${100 - pct}%, ${c})`;

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

  function hearts() {
    const out = [];
    for (let i = 0; i < v.max_lives; i++) out.push(h("span.ito-heart" + (i < v.lives ? ".on" : "")));
    return out;
  }

  function status() {
    const row = desafio()
      ? h("div.row.ito-status", h("b", `Nível ${v.level}`), h("span", hearts()), v.best > 0 ? h("small", `recorde ${v.best}`) : null)
      : h("div.row.ito-status", h("b", `Rodada ${v.round_no}`));
    return [row, v.extreme ? h("p.caption.bold", { style: { color: "var(--vermelho)" } }, "Modo extremo: a fila não mostra de quem é cada carta.") : null];
  }

  function numCard(n, cls, accent) {
    return h("div.ito-card" + (n < 0 ? ".back" : "") + (cls ? "." + cls : ""), { style: accent ? { borderColor: accent } : null }, n >= 0 ? String(n) : "?");
  }

  // --- Trocar aparelho (igual ao Avalon) --------------------------------------
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

  // Pede um texto (palavra-chave, tema digitado).
  function prompt(title, hint, placeholder, value, max, onOk) {
    const input = h("input.field", { placeholder, maxlength: max, value: value || "" });
    const ok = () => { GH.closeOverlay(); onOk(input.value.trim()); };
    input.addEventListener("keydown", (e) => { if (e.key === "Enter") ok(); });
    GH.overlay(title, hint, [input, button("Salvar", "success", ok, "check"), button("Cancelar", "secondary", GH.closeOverlay)]);
    setTimeout(() => input.focus(), 50);
  }

  // --- Fases ----------------------------------------------------------------

  function lobby() {
    const cfg = v.config;
    return [header("Sala do Ito"),
      card(null, h("p.sub", `Na mesa (${v.players.length})`),
        v.players.map((p, i) => player(`${i + 1}. ${p.name}`, color(p.color), p.connected, !p.connected ? "desconectado" : (p.id === v.you ? "você" : "")))),
      card("var(--papel)", h("p.sub", "Partida"),
        h("p.bold", cfg.mode === "desafio" ? "Desafio: 3 vidas, cada acerto dá mais uma carta pra alguém" : `Rodada solta: ${cfg.cards} carta${cfg.cards > 1 ? "s" : ""} por pessoa, sem vidas`),
        h("p.caption", { style: { textAlign: "left" } }, `Cronômetro: ${cfg.timer_min > 0 ? cfg.timer_min + " min" : "desligado"}`)),
      h("p.caption", board() ? "Este aparelho é o tabuleiro. Esperando o host começar..." : "Esperando o host começar a partida...")];
  }

  function themeBlock() {
    if (v.phase === "theme") {
      return card("var(--mostarda)", h("h2.title", "Escolham o tema"),
        v.theme_options.map((t, i) => { const b = button(t, "secondary", () => act({ type: "pick_theme", index: i })); b.disabled = !member(); return b; }),
        member() ? button("Digitar outro tema", "secondary", () => prompt("Tema", "Uma frase, tipo \"O quão barulhento é um lugar\". 1 é o mínimo e 100 é o máximo.", "O quão ...", "", 80,
          (t) => { if (t) act({ type: "custom_theme", text: t }); }), null, "small") : h("p.caption", "Escolham no celular."));
    }
    return card(tint("var(--mostarda)", 45), h("p.caption.bold", "Tema"), h("h2.title", v.theme), h("p.caption", "1 = o mínimo · 100 = o máximo. Sem falar números!"));
  }

  function handBlock() {
    const items = v.hand.map((c) => h("div.ito-hand",
      numCard(c.n, "", c.placed ? "var(--salvia)" : null),
      h("p.caption.bold", c.word || "sem palavra-chave"),
      button("Palavra-chave", "secondary", () => prompt("Palavra-chave", "Opcional: uma palavra pra lembrar a sua dica. Aparece embaixo da carta na fila. Sem números!", "ex: tubarão", c.word, 24,
        (t) => act({ type: "word", card: c.card, text: t })), null, "small"),
      v.phase !== "play" ? null : c.placed ? h("p.caption.bold", { style: { color: "var(--salvia-e)" } }, "na fila")
        : button(sel === c.card ? "Escolhida" : "Pôr na fila", sel === c.card ? "" : "success", () => pick(c.card, true), null, "small")));
    return card(null, h("p.sub", v.hand.length === 1 ? "Seu número" : "Seus números"), h("div.ito-hands", items),
      v.phase === "play" && v.hand.some((c) => !c.placed) ? h("p.caption", "Toque em \"Pôr na fila\" e depois em \"Colocar aqui\" no lugar certo.") : null);
  }

  function pick(id, fromHand) {
    if (sel === id) sel = "";
    else { sel = id; selNew = fromHand; }
    render();
  }

  function drop(to) {
    const id = sel;
    const fresh = selNew;
    sel = "";
    act({ type: fresh ? "place" : "move", card: id, to });
    vibrate(15);
  }

  function rowBlock() {
    const list = [h("div.ito-end", "0 · o mínimo")];
    const row = v.row;
    const selI = row.findIndex((r) => r.card === sel);
    for (let i = 0; i <= row.length; i++) {
      if (sel && member() && (selNew || (i !== selI && i !== selI + 1))) {
        const to = selNew || i <= selI ? i : i - 1;
        list.push(h("div.ito-gap", button("Colocar aqui", "accent", () => drop(to), null, "small")));
      }
      if (i < row.length) {
        const r = row[i];
        const c = r.owner ? color(byId(r.owner).color) : "var(--papel)";
        const el = h("div.ito-item" + (r.card === sel ? ".sel" : ""), { style: { background: r.card === sel ? "var(--mostarda)" : tint(c, 25) },
          onclick: member() ? () => pick(r.card, false) : null },
          h("div.grow", h("b", r.owner ? nameOf(r.owner) : "?"), r.word ? h("small", `“${r.word}”`) : null),
          r.n >= 0 ? numCard(r.n, "mini", "var(--salvia)") : null,
          r.card === sel && r.mine ? button("Tirar", "secondary", (e) => { e.stopPropagation(); sel = ""; act({ type: "take_back", card: r.card }); }, null, "small") : null);
        list.push(el);
      }
    }
    list.push(h("div.ito-end", "100 · o máximo"));
    return card(null, h("p.sub", "A fila"), h("div.ito-thread", list),
      row.length ? null : h("p.caption", "Ninguém pôs carta ainda. Quem acha que tem um número bem baixo começa!"));
  }

  function pendingText() {
    const p = v.pending || {};
    if (!Object.keys(p).length) return `Faltam ${v.pending_total} carta${v.pending_total === 1 ? "" : "s"} na fila.`;
    return "Falta pôr na fila: " + v.players.filter((pl) => p[pl.id]).map((pl) => p[pl.id] > 1 ? `${pl.name} (${p[pl.id]})` : pl.name).join(", ");
  }

  function table() {
    timerEl = v.timer_left_ms >= 0 ? h("p.center.bold.big", { style: { color: "var(--vermelho-e)", fontFamily: "Fraunces" } }) : null;
    const out = [header("Ito"), status(), themeBlock()];
    if (member() && v.hand.length) out.push(handBlock());
    if (v.phase === "theme") {
      out.push(h("p.caption", "Olhem os seus números e pensem num exemplo. Depois de escolher o tema, montem a fila."));
      return out;
    }
    out.push(timerEl, rowBlock());
    if (v.all_placed) {
      out.push(member() ? button("Revelar", "success", () => GH.overlay("Revelar a fila?", "Todo mundo concorda com a ordem?", [
        button("Revelar", "success", () => { GH.closeOverlay(); act({ type: "reveal" }); }), button("Ainda não", "secondary", GH.closeOverlay)]), "play", "huge")
        : h("p.caption", "Quando todo mundo concordar, alguém revela no celular."));
    } else out.push(h("p.caption", pendingText()));
    return out;
  }

  function reveal() {
    timers.forEach(clearTimeout);
    timers = [];
    const res = v.result || {};
    const errors = res.errors || [];
    const slots = [];
    const items = v.row.map((r) => {
      const holder = h("div.ito-slot");
      const el = h("div.ito-item", { style: { background: tint(color(byId(r.owner).color), 25) } },
        h("div.grow", h("b", nameOf(r.owner)), r.word ? h("small", `“${r.word}”`) : null), holder);
      slots.push({ holder, el, n: r.n, bad: errors.includes(r.card) });
      return el;
    });
    const flip = (s) => {
      s.holder.replaceChildren(numCard(s.n, "mini", s.bad ? "var(--vermelho)" : "var(--salvia)"));
      if (s.bad) s.el.style.background = tint("var(--vermelho)", 35);
    };
    const errs = errors.length;
    let resCard;
    if (res.ok) resCard = big("Acertaram!", tint("var(--salvia)", 45), desafio() ? (res.won ? "Venceram o Desafio!" : "Próximo nível: uma pessoa ganha mais uma carta.") : "Todos em ordem!");
    else {
      let sub = `${errs} fora de ordem.`;
      if (desafio()) sub = `${errs} fora de ordem: −${res.lost} vida${res.lost === 1 ? "" : "s"}.` + (res.next === "game_over" ? " Acabaram as vidas!" : " O nível se repete com números novos.");
      resCard = big("Quase!", tint("var(--vermelho)", 35), sub);
    }
    const cont = member() || board() ? button(res.next === "round" ? "Próxima rodada" : "Ver o fim", "success", () => act({ type: "continue" }), "play") : null;
    if (animRound === v.round_no) slots.forEach(flip);
    else {
      resCard.style.display = "none";
      if (cont) cont.disabled = true;
      slots.forEach((s, i) => timers.push(setTimeout(() => { flip(s); sound(s.bad ? "buzzer" : "tick"); if (s.bad) vibrate(60); }, STEP_MS * (i + 1))));
      timers.push(setTimeout(() => {
        animRound = v.round_no;
        resCard.style.display = "";
        if (cont) cont.disabled = false;
        sound(res.ok ? "win" : "skip");
      }, STEP_MS * (slots.length + 1) + 300));
    }
    return [header("Revelação"), status(), themeBlock(),
      card(null, h("div.ito-thread", h("div.ito-end", "0 · o mínimo"), items, h("div.ito-end", "100 · o máximo"))), resCard, cont];
  }

  function gameOver() {
    let head;
    if (v.end_reason === "won") head = big("Vocês venceram!", tint("var(--salvia)", 45), `Chegaram ao nível ${v.best} sem perder todas as vidas.`);
    else if (v.end_reason === "lives") head = big("Acabaram as vidas", tint("var(--vermelho)", 30), v.best > 0 ? `Maior nível vencido: ${v.best}` : "Nenhum nível vencido. Na próxima vai!");
    else head = big("Fim de jogo", "var(--mostarda)", `${v.rounds.length} rodada${v.rounds.length === 1 ? "" : "s"}`);
    const lines = v.rounds.map((r, k) => h("div",
      h("p.bold", desafio() ? `${k + 1}. Nível ${r.level} · ${r.theme}` : `${k + 1}. ${r.theme}`),
      h("p.caption", { style: { textAlign: "left" } }, `${r.cards.map((c) => c.n).join(" ")} · ${r.errors ? r.errors + " fora de ordem" : "tudo em ordem"}`)));
    return [head, card("var(--papel)", h("p.sub", "As rodadas"), lines.length ? lines : h("p.caption", "Nenhuma rodada revelada.")),
      h("p.caption", "Se o host quiser, a próxima começa daqui."), button("Sair", "secondary", GH.confirmLeave)];
  }

  const PHASES = { lobby, theme: table, play: table, reveal, game_over: gameOver };

  function render() {
    timerEl = null;
    if (v.phase !== "reveal") { timers.forEach(clearTimeout); timers = []; }
    mount(h("div.col" + (board() ? ".av-board" : ""), (PHASES[v.phase] || lobby)()));
    tickTimer();
  }

  function tickTimer() {
    if (!timerEl || !document.body.contains(timerEl)) return;
    const s = Math.ceil(timerMs / 1000);
    timerEl.textContent = s <= 0 ? "Tempo esgotado! Hora de revelar." : `Tempo: ${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
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
        case "dealt": sound("round"); vibrate(40); break;
        case "theme": sound("pop"); break;
        case "row": if (e.by !== v.you) sound("tap"); break;
        case "game_over": sound("win"); break;
      }
    }
  }

  GH.games.ito = {
    onMessage,
    render(view, evs) {
      v = view;
      if (swapSeat && !swapWasOn && byId(swapSeat).connected) {
        toast(`${nameOf(swapSeat)} entrou no aparelho novo.`, "green");
        swapSeat = "";
        GH.closeOverlay();
      }
      if (evs.some((e) => e.type === "started")) animRound = -1;
      if (evs.some((e) => e.type === "dealt")) sel = "";
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
