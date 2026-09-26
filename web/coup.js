// Coup no navegador: jogador e tabuleiro (games/coup/screens/coup_game.gd).
// Desafiar e bloquear vão com a hora do host (acertada por pings), pra valer quem apertou primeiro.
"use strict";

(() => {
  const { h, button, card, player, mount, toast, sound, vibrate, act, send, st } = GH;
  const PCOLORS = ["#2B59C3", "#C8392B", "#2F7D5B", "#E0A21F", "#6E3B93", "#D9772B"];
  const NAMES = { duque: "Duque", assassino: "Assassino", capitao: "Capitão", embaixador: "Embaixador", inquisidor: "Inquisidor", condessa: "Condessa" };
  const WITH = { duque: "o Duque", assassino: "o Assassino", capitao: "o Capitão", embaixador: "o Embaixador", inquisidor: "o Inquisidor", condessa: "a Condessa" };
  const RCOLORS = { duque: "#6E3B93", assassino: "#2B2A33", capitao: "#2B59C3", embaixador: "#2F7D5B", inquisidor: "#D9772B", condessa: "#C8392B" };
  const ACTIONS = { renda: "Renda", ajuda: "Ajuda Externa", golpe: "Golpe de Estado", imposto: "Imposto", assassinar: "Assassinar", extorquir: "Extorquir", trocar: "Trocar", examinar: "Examinar" };
  const INFO = {
    renda: "+1 moeda. Ninguém impede.", ajuda: "+2 moedas. Quem diz ter o Duque bloqueia.", golpe: "Paga 7: alguém perde uma carta.",
    imposto: "+3 moedas com o Duque.", assassinar: "Paga 3: alguém perde uma carta. A Condessa bloqueia.", extorquir: "Pega 2 moedas de alguém.",
    trocar: "Troca cartas com o baralho.", examinar: "Olha uma carta de alguém e pode obrigar a trocar.",
  };
  const COSTS = { golpe: 7, assassinar: 3 };
  const TARGET = ["golpe", "assassinar", "extorquir", "examinar"];
  const WINDOW_MS = 5000;

  const nowUs = () => Math.round(performance.now() * 1000);
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
    maxRtt() { let m = 0; for (const s of this.samples.slice(-8)) m = Math.max(m, s.rtt); return Math.floor(m / 1000); },
  };
  let pingTimer = null;
  function startPings() {
    clearTimeout(pingTimer);
    let n = 0;
    const tick = () => { send({ type: "ping", c: nowUs(), rtt: clock.maxRtt() }); n += 1; pingTimer = setTimeout(tick, n < 12 ? 100 : 1000); };
    tick();
  }

  let v = null;
  let lastPhase = "";
  let hideCards = false;
  let reacted = false;
  let keep = [];
  let barEl = null;
  let barLeft = 0;
  let barTotal = WINDOW_MS;

  const byId = (id) => (v.players || []).find((p) => p.id === id) || { name: "?", color: 0, coins: 0, cards: [], alive: true, connected: true };
  const nameOf = (id) => byId(id).name;
  const board = () => st.papel === "board";
  const playing = () => !board() && !!v.you;
  const me = () => byId(v.you);
  const hiddenMine = () => me().cards.filter((c) => !c.up);
  const has = (r) => hiddenMine().some((c) => c.role === r);
  const tint = (c, pct) => `color-mix(in srgb, var(--superficie) ${100 - pct}%, ${c})`;
  const variant = (id) => Math.max(0, v.players.findIndex((p) => p.id === id));

  function big(title, bg, sub) {
    return card(bg || null, h("h2.title", title), sub ? h("p.center.bold", sub) : null);
  }

  // Carta: retrato do Nano Banana se existir; senão o emblema. role "" = de costas.
  function roleCard(role, cls, up, varIdx, onTap) {
    if (!role) return h("div.cp-card.back" + (cls ? "." + cls : ""), h("img", { src: "assets/coup_verso.svg", alt: "" }));
    const el = h("div.cp-card" + (cls ? "." + cls : "") + (up ? ".up" : ""), { style: { "--c": RCOLORS[role] } });
    const tries = [`${role}_${(varIdx || 0) % 2 + 1}.webp`, `${role}_1.webp`, `${role}_2.webp`, `${role}.webp`];
    const img = h("img.portrait", { src: `assets/coup/${tries.shift()}`, alt: "" });
    img.onerror = () => { if (tries.length) img.src = `assets/coup/${tries.shift()}`; else { img.src = `assets/coup_${role}.svg`; img.className = "emblem"; img.onerror = null; } };
    el.append(img, h("b", NAMES[role]));
    if (onTap) el.addEventListener("click", () => onTap(role));
    return el;
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

  function myBlock() {
    if (!playing()) return null;
    const m = me();
    return card(null, h("div.row", h("p.sub.grow", "Suas cartas"), h("img.cp-coin", { src: "assets/coup_moeda.svg", alt: "" }), h("b.big", String(m.coins)),
      button(hideCards ? "Mostrar" : "Esconder", "secondary", () => { hideCards = !hideCards; render(); }, null, "small")),
      h("div.cp-mine", m.cards.map((c) => roleCard(c.up || !hideCards ? c.role : "", "", c.up, variant(v.you)))),
      m.alive ? null : h("p.caption.bold", "Você está fora: agora só assiste."));
  }

  function table() {
    return card("var(--papel)", v.players.filter((p) => board() || p.id !== v.you).map((p) => h("div.cp-row" + (p.id === v.turn && v.phase !== "game_over" ? ".turn" : ""),
      h("div.avatar" + (p.connected ? "" : ".off"), { style: { background: PCOLORS[p.color % 6] } }, p.name.charAt(0).toUpperCase()),
      h("div.grow", h("b", p.name + (p.id === v.turn && v.phase !== "game_over" ? " · vez" : "")), p.alive ? null : h("small", "fora")),
      h("img.cp-coin", { src: "assets/coup_moeda.svg", alt: "" }), h("b.cp-n", String(p.coins)),
      p.cards.map((c) => roleCard(c.up ? c.role : "", "mini", c.up, variant(p.id))))));
  }

  function logLine(e) {
    const who = nameOf(e.id);
    switch (e.k) {
      case "declared": return `${who}: ${ACTIONS[e.action]}${e.target ? " em " + nameOf(e.target) : ""}${e.claim ? ` (diz ter ${WITH[e.claim]})` : ""}`;
      case "challenge": return `${who} desafiou ${nameOf(e.target)}: ${e.had ? `tinha ${WITH[e.role]}!` : "era blefe!"}`;
      case "blocked": return `${who} bloqueou com ${WITH[e.role]}`;
      case "lost": return `${who} perdeu ${WITH[e.role]}`;
      case "exchanged": return `${who} trocou cartas`;
      case "examined": return `${who} examinou ${nameOf(e.target)}${e.force ? " e mandou trocar" : ""}`;
      case "done": return `${who}: ${ACTIONS[e.action]} aconteceu`;
    }
    return "";
  }

  function logBlock() {
    if (!v.log.length) return null;
    const lines = v.log.map(logLine).reverse().slice(0, 6);
    return card("var(--papel)", h("p.sub", "O que aconteceu"), lines.map((l, i) => h("p" + (i ? ".caption" : ".bold"), { style: { textAlign: "left" } }, l)));
  }

  function claimText(p) {
    const tgt = p.target ? ` em ${nameOf(p.target)}` : "";
    return p.claim ? `${nameOf(p.actor)} diz ter ${WITH[p.claim]}: ${ACTIONS[p.action]}${tgt}` : `${nameOf(p.actor)} pede ${ACTIONS[p.action]}${tgt}`;
  }

  function react(type, role) {
    const us = nowUs();
    if (reacted) return;
    reacted = true;
    const a = { type, t: clock.toHostMs(us) };
    if (role) a.role = role;
    act(a);
    vibrate(20);
    render();
  }

  // --- Trocar aparelho --------------------------------------------------------
  let swapSeat = "";
  let swapWasOn = false;
  function swapList() {
    swapSeat = "";
    GH.overlay("Trocar aparelho", "A bateria de alguém acabou ou o celular travou? Escolha a pessoa e leia o QR com outro aparelho. Ele entra no lugar dela, com as mesmas cartas e moedas.", [
      ...v.players.map((p) => button(`${p.name}${p.connected ? "" : " (desconectado)"}`, p.connected ? "secondary" : "", () => {
        if (p.connected && !confirm(`${p.name} ainda está conectado. Quando o outro aparelho ler o QR, o de agora sai da partida. Trocar?`)) return;
        swapSeat = p.id;
        swapWasOn = p.connected;
        GH.send({ type: "pedir_vaga", id: p.id });
      }, "phone")),
      button("Fechar", "secondary", GH.closeOverlay)]);
  }

  // --- Fases ----------------------------------------------------------------

  function lobby() {
    const capa = h("img.av-banner", { src: "assets/coup/capa.webp", alt: "" });
    capa.onerror = () => capa.remove();
    return [header("Sala do Coup"), capa,
      card(null, h("p.sub", `Na mesa (${v.players.length})`), v.players.map((p, i) => player(`${i + 1}. ${p.name}`, PCOLORS[p.color % 6], p.connected, p.id === v.you ? "você" : ""))),
      card("var(--papel)", h("p.sub", "Partida"), h("p.bold", `Quinto personagem: ${NAMES[v.config.fifth]}`)),
      h("p.caption", board() ? "Este aparelho é o tabuleiro. Esperando o host começar..." : "Esperando o host começar a partida...")];
  }

  function actions() {
    const coins = me().coins;
    const must = coins >= 10;
    const claims = { imposto: "duque", assassinar: "assassino", extorquir: "capitao", trocar: v.config.fifth, examinar: "inquisidor" };
    const items = v.actions.map((a) => {
      const claim = claims[a] || "";
      const b = button(ACTIONS[a], claim && !has(claim) ? "secondary" : "", () => chooseAction(a), null, "small");
      b.disabled = (must && a !== "golpe") || coins < (COSTS[a] || 0);
      return h("div.cp-act", { style: claim ? { background: tint(RCOLORS[claim], 25) } : null }, b,
        h("small", INFO[a] + (claim && !has(claim) ? " (blefe: você não tem)" : "")));
    });
    return [big("Sua vez", "var(--mostarda)", must ? "Com 10 moedas, o Golpe é obrigatório." : "Escolha uma ação. Pode dizer que tem qualquer personagem."), h("div.cp-acts", items)];
  }

  function chooseAction(a) {
    if (!TARGET.includes(a)) { act({ type: "act", action: a }); return; }
    GH.overlay(`${ACTIONS[a]} em quem?`, "", [
      ...v.players.filter((p) => p.id !== v.you && p.alive).map((p) => button(`${p.name} · ${p.coins} moeda${p.coins === 1 ? "" : "s"}`, "secondary", () => { GH.closeOverlay(); act({ type: "act", action: a, target: p.id }); })),
      button("Cancelar", "secondary", GH.closeOverlay)]);
  }

  function windowPhase() {
    const p = v.pending;
    const blockOnly = p.stage === "block_only";
    barLeft = p.window_left_ms || 0;
    barTotal = p.window_total_ms || WINDOW_MS;
    barEl = h("div.cp-bar", h("i", { style: { width: `${barLeft / barTotal * 100}%` } }));
    const out = [big(claimText(p), p.claim ? tint(RCOLORS[p.claim], 35) : null, blockOnly ? "Ainda dá pra bloquear." : "Alguém desafia ou bloqueia?"), barEl];
    if (!playing()) return out;
    if (reacted) { out.push(h("p.caption", "Foi! Esperando...")); return out; }
    const btns = [];
    if (v.can_challenge) btns.push(button("Desafiar", "danger", () => react("challenge"), "close"));
    for (const r of v.can_block) btns.push(button(`Bloquear com ${WITH[r]}`, "", () => react("block", r)));
    if (btns.length) out.push(h("div.cp-btns", btns));
    else if (p.actor === v.you) out.push(h("p.caption", "Esperando os outros reagirem..."));
    return out;
  }

  function blockPhase() {
    const p = v.pending;
    const out = [big(`${nameOf(p.blocker)} bloqueia com ${WITH[p.block_claim]}`, tint(RCOLORS[p.block_claim], 35), `${ACTIONS[p.action]} de ${nameOf(p.actor)}`)];
    if (p.accepted.length) out.push(h("p.caption", `Aceitaram: ${p.accepted.map(nameOf).join(", ")}`));
    if (!playing() || p.blocker === v.you || !me().alive) { out.push(h("p.caption", `Esperando ${nameOf(p.actor)} aceitar ou alguém desafiar o bloqueio...`)); return out; }
    if (reacted) { out.push(h("p.caption", "Foi! Esperando...")); return out; }
    const btns = [];
    if (v.can_challenge) btns.push(button("Desafiar o bloqueio", "danger", () => react("challenge"), "close"));
    if (!p.accepted.includes(v.you)) btns.push(button("Aceitar", p.actor === v.you ? "success" : "secondary", () => act({ type: "accept" }), "check"));
    out.push(h("div.cp-btns", btns), h("p.caption", `Só quando ${p.actor === v.you ? "você" : nameOf(p.actor)} aceitar o jogo segue.`));
    return out;
  }

  function pickCards(onTap) {
    return h("div.cp-mine", me().cards.map((c, i) => c.up ? null : roleCard(c.role, "pick", false, variant(v.you), () => onTap(i))));
  }

  function center() {
    const p = v.pending || {};
    switch (v.phase) {
      case "turn": return playing() && v.turn === v.you ? actions() : [big(`Vez de ${nameOf(v.turn)}`, null, "Escolhendo a ação...")];
      case "window": return windowPhase();
      case "block": return blockPhase();
      case "lose":
        if (playing() && v.loser === v.you) {
          return [big("Você perde uma carta", tint("var(--vermelho)", 35), "Toque na que vai virar pra cima."),
            pickCards((i) => GH.overlay(`Perder ${WITH[me().cards[i].role]}?`, "A carta vira pra cima e fica à mostra.", [button("Perder", "danger", () => { GH.closeOverlay(); act({ type: "lose", index: i }); }), button("Cancelar", "secondary", GH.closeOverlay)]))];
        }
        return [big(`${nameOf(v.loser)} perde uma carta`, null, "Escolhendo qual vira...")];
      case "exchange":
        if (!(playing() && p.actor === v.you)) return [big(`${nameOf(p.actor)} está trocando cartas`, null, `Com ${WITH[v.config.fifth]}.`)];
        if (v.config.fifth === "embaixador") {
          const mine = hiddenMine().map((c) => c.role);
          const pool = mine.concat(v.exchange);
          const ok = button("Ficar com essas", "success", () => { const k = keep; keep = []; act({ type: "exchange", keep: k }); }, "check");
          ok.disabled = keep.length !== mine.length;
          return [big(`Escolha ${mine.length} pra ficar`, "var(--mostarda)", "As outras voltam pro baralho."),
            h("div.cp-mine", pool.map((r, i) => { const el = roleCard(r, "pick" + (keep.includes(i) ? ".on" : ""), false, 0, () => { if (keep.includes(i)) keep = keep.filter((x) => x !== i); else if (keep.length < mine.length) keep.push(i); render(); }); return el; })), ok];
        } else {
          const mine = hiddenMine().map((c) => c.role);
          return [big("Você comprou", "var(--mostarda)", "Troque por uma das suas, ou devolva."), h("div.cp-mine", roleCard(v.exchange[0] || "", "", false, 0)),
            ...mine.map((r, i) => button(`Trocar ${r === "condessa" ? "pela minha Condessa" : "pelo meu " + NAMES[r]}`, "", () => act({ type: "exchange", swap: i }))),
            button("Devolver", "secondary", () => act({ type: "exchange", swap: -1 }))];
        }
      case "examine_show":
        if (playing() && p.target === v.you) return [big(`Mostre uma carta pra ${nameOf(p.actor)}`, "var(--mostarda)", `Só ${nameOf(p.actor)} vai ver.`), pickCards((i) => act({ type: "show", index: i }))];
        return [big(`${nameOf(p.actor)} examina ${nameOf(p.target)}`, null, `${nameOf(p.target)} escolhe a carta que mostra...`)];
      case "examine_decide":
        if (playing() && p.actor === v.you && v.examined) {
          return [big(`A carta de ${nameOf(p.target)}`, "var(--mostarda)", "Só você vê. Devolve, ou obriga a trocar?"), h("div.cp-mine", roleCard(v.examined, "", false, 0)),
            h("div.grid2", button("Devolver", "secondary", () => act({ type: "examine", force: false })), button("Obrigar a trocar", "", () => act({ type: "examine", force: true })))];
        }
        return [big(`${nameOf(p.actor)} examina ${nameOf(p.target)}`, null, "Decidindo...")];
    }
    return [];
  }

  function pickFirst() {
    if (playing() && v.first_options.length) {
      return [header("Coup"), big("Escolha a sua primeira carta", "var(--mostarda)", "Com 2 jogadores, cada um escolhe uma entre as 5. A outra vem sorteada."),
        h("div.cp-mine", v.first_options.map((r) => roleCard(r, "pick", false, 0, () => act({ type: "pick_first", role: r }))))];
    }
    return [header("Coup"), big("Escolhendo as cartas", null, "Cada um escolhe a primeira carta...")];
  }

  function gameOver() {
    return [big(`${nameOf(v.winner)} venceu!`, tint("var(--salvia)", 45), "O último com influência na corte."),
      card("var(--papel)", h("p.sub", "As cartas de cada um"), v.players.map((p) => h("div.cp-row", h("b.grow", { style: { color: PCOLORS[p.color % 6] } }, p.name), p.cards.map((c) => roleCard(c.role, "mini", c.up, variant(p.id)))))),
      logBlock(), h("p.caption", "Se o host quiser, a próxima começa daqui."), button("Sair", "secondary", GH.confirmLeave)];
  }

  function render() {
    barEl = null;
    let body;
    if (v.phase === "lobby") body = lobby();
    else if (v.phase === "pick_first") body = pickFirst();
    else if (v.phase === "game_over") body = gameOver();
    else body = [header("Coup"), ...center(), myBlock(), table(), logBlock()];
    mount(h("div.col" + (board() ? ".av-board.cp-board" : ""), body));
  }

  let lastTick = performance.now();
  setInterval(() => {
    const now = performance.now();
    if (barLeft > 0) barLeft = Math.max(0, barLeft - (now - lastTick));
    lastTick = now;
    if (barEl && barEl.firstChild) barEl.firstChild.style.width = `${barLeft / barTotal * 100}%`;
  }, 50);

  function events(list) {
    for (const e of list) {
      switch (e.type) {
        case "player_joined": sound("join"); break;
        case "player_connection": toast(`${e.name} ${e.connected ? "voltou" : "caiu da rede"}`); break;
        case "turn": if (e.id === v.you && playing()) { sound("hg_turn"); vibrate([40, 70, 40]); } break;
        case "declared": sound("pop"); break;
        case "challenge": sound(e.had ? "hit" : "buzzer"); vibrate(40); break;
        case "blocked": sound("hg_flip"); break;
        case "lost": sound("hg_out"); break;
        case "game_over": sound("win"); break;
      }
    }
  }

  GH.games.coup = {
    onOpen: startPings,
    onRejected(msg) { toast(msg, "red"); },
    onMessage(msg) {
      if (msg.type === "pong") { clock.add(msg.c, msg.h, nowUs()); return; }
      if (msg.type !== "vaga" || msg.id !== swapSeat) return;
      const url = `http://${location.host}/?v=${msg.token}`;
      GH.overlay(`Vaga de ${nameOf(msg.id)}`, "Leia com a câmera do outro aparelho. O QR vale uma vez só, por 5 minutos.", [
        h("img.qr", { src: `qr.svg?d=${encodeURIComponent(url)}`, alt: "" }), h("p.caption", url), button("Voltar", "secondary", swapList)]);
    },
    render(view, evs) {
      v = view;
      if (swapSeat && !swapWasOn && byId(swapSeat).connected) {
        toast(`${nameOf(swapSeat)} entrou no aparelho novo.`, "green");
        swapSeat = "";
        GH.closeOverlay();
      }
      for (const e of evs) {
        if (["phase", "blocked", "block_window"].includes(e.type)) reacted = false;
        if (e.type === "started") { hideCards = false; keep = []; }
      }
      if (view.phase !== lastPhase) {
        GH.closeOverlay();
        GH.keepAwake(view.phase !== "lobby");
      }
      lastPhase = view.phase;
      render();
      events(evs);
    },
  };
})();
