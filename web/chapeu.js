// Chapéu no navegador: as mesmas telas do jogador no Wi-Fi (games/chapeu/screens/chapeu_game.gd).
"use strict";

(() => {
  const { h, button, card, player, mount, toast, sound, vibrate, act } = GH;
  const TEAM = {
    azul: { nome: "Time Azul", cor: "var(--azul)", escuro: "var(--azul-e)", btn: "azul" },
    vermelho: { nome: "Time Vermelho", cor: "var(--vermelho)", escuro: "var(--vermelho-e)", btn: "vermelho" },
  };
  const ROUNDS = {
    descrever: { nome: "Descrever", regra: "Explique com quantas palavras quiser, só não pode dizer a palavra (nem parte dela).", curta: "Explique sem dizer a palavra", icone: "rodada_descrever", cor: "var(--azul)" },
    uma_palavra: { nome: "Uma palavra", regra: "Só pode dar UMA palavra de dica. Pense bem antes de falar!", curta: "Só uma palavra de dica", icone: "rodada_uma_palavra", cor: "var(--mostarda)" },
    mimica: { nome: "Mímica", regra: "Só gestos, sem som nenhum. Vale apontar, dançar e fazer careta.", curta: "Só mímica, sem som", icone: "rodada_mimica", cor: "var(--salvia)" },
  };
  const CRITERIA = {
    pontos: "Mais pontos no total.",
    rodadas: "Empatou nos pontos: venceu quem ganhou mais rodadas.",
    mimica: "Empatou nos pontos e nas rodadas: venceu quem fez mais na mímica.",
    empate: "Empate em tudo: pontos, rodadas vencidas e mímica.",
  };

  let v = null;
  let timeMs = 0;
  let lastFrame = 0;
  let lastSec = -1;

  const me = () => (v.players || []).find((p) => p.id === v.you) || null;
  const byId = (id) => (v.players || []).find((p) => p.id === id) || null;
  const round = () => ROUNDS[v.round_key] || ROUNDS.descrever;
  const plural = (n, a, b) => `${n} ${n === 1 ? a : b}`;

  function scoreboard(highlight) {
    const t = v.totals || { azul: 0, vermelho: 0 };
    return h("div.score", ["azul", "vermelho"].map((k) => {
      const d = h("div", { style: { background: `color-mix(in srgb, var(--superficie) 80%, ${TEAM[k].cor})` } },
        TEAM[k].nome, h("b", t[k] || 0));
      if (highlight && highlight !== k) d.classList.add("dim");
      return d;
    }));
  }

  function header(text) {
    return h("div.row", h("h1.title.left.grow", text), button("", "secondary", GH.confirmLeave, "close", "icon-btn"));
  }

  // Cronômetro em anel (atualizado a cada quadro sem remontar a tela).
  function ring(size) {
    const r = size / 2 - 10;
    const c = 2 * Math.PI * r;
    // SVG precisa nascer com o namespace certo: monta pelo HTML.
    return h("div", {
      html: `<svg class="ring" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">` +
        `<circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="var(--superficie)" stroke="var(--linha)" stroke-width="12"/>` +
        `<circle id="timer-arc" cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="var(--tinta)" stroke-width="12" stroke-linecap="round" ` +
        `stroke-dasharray="${c}" stroke-dashoffset="0" transform="rotate(-90 ${size / 2} ${size / 2})"/>` +
        `<text id="timer-text" x="50%" y="54%" text-anchor="middle" dominant-baseline="middle" font-size="${size * 0.3}">60</text></svg>`,
    });
  }

  function updateTimer() {
    const arc = document.getElementById("timer-arc");
    const txt = document.getElementById("timer-text");
    if (!arc || !txt) return;
    const total = v.turn_ms || 60000;
    const c = parseFloat(arc.getAttribute("stroke-dasharray"));
    const frac = Math.max(0, Math.min(1, timeMs / total));
    arc.setAttribute("stroke-dashoffset", String(c * (1 - frac)));
    const sec = Math.ceil(timeMs / 1000);
    txt.textContent = String(sec);
    const urgent = sec <= 10;
    arc.setAttribute("stroke", urgent ? "var(--vermelho)" : "var(--tinta)");
    txt.setAttribute("fill", urgent ? "var(--vermelho-e)" : "var(--tinta)");
  }

  function frame(t) {
    const dt = lastFrame ? t - lastFrame : 0;
    lastFrame = t;
    if (v && v.phase === "turn" && !v.paused) {
      timeMs = Math.max(0, timeMs - dt);
      updateTimer();
      const sec = Math.ceil(timeMs / 1000);
      if (sec !== lastSec) {
        lastSec = sec;
        if (sec <= 10 && sec > 0) {
          sound("tick", 1 + (10 - sec) * 0.03);
          if (sec <= 5) vibrate(35);
        }
      }
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  // --- Fases ----------------------------------------------------------------

  function lobby() {
    const mine = me();
    const teams = ["azul", "vermelho"].map((k) => {
      const members = v.players.filter((p) => p.team === k);
      return card(null,
        h("div.row", h("div.avatar", { style: { background: TEAM[k].cor, width: "26px", height: "26px" } }), h("p.sub.grow", `${TEAM[k].nome} (${members.length})`)),
        members.length ? members.map((p) => player(p.name, TEAM[k].cor, p.connected, !p.connected ? "desconectado" : (p.id === v.you ? "você" : ""))) : h("p.caption", "Ninguém ainda"),
        mine && mine.team !== k ? button(`Entrar no ${TEAM[k].nome}`, TEAM[k].btn, () => act({ type: "set_team", team: k }), null, "small") : null);
    });
    const cfg = v.config;
    const lines = [];
    if (cfg.source === "jogadores") lines.push(`Palavras dos jogadores: ${cfg.words_per_player} por pessoa`);
    if (cfg.source === "lista") lines.push(`Lista pronta: ${cfg.list_count} palavras`);
    if (cfg.source === "mistura") lines.push(`Mistura: ${cfg.words_per_player} por pessoa + ${cfg.list_count} da lista`);
    lines.push(`Adversário vê a palavra: ${cfg.opponent_sees_word ? "sim" : "não"}`);
    lines.push("60 s por vez · pular custa 1 ponto · 3 rodadas");
    return [header("Sala do Chapéu"), h("p.caption", "Escolha seu time. O host começa quando todo mundo entrar."), ...teams,
      card("var(--papel)", h("p.sub", "Partida"), lines.map((l) => h("div", l))),
      h("p.caption", "Esperando o host começar a partida...")];
  }

  function writing() {
    const n = v.config.words_per_player;
    const done = v.submitted.includes(v.you);
    const list = card(null, v.players.map((p) => player(p.name, TEAM[p.team].cor, p.connected, v.submitted.includes(p.id) ? "pronto ✓" : "escrevendo...")));
    if (done) {
      return [header("Palavras"), card(null, h("h2.title", "Pronto!"), h("p.caption", "Suas palavras estão no chapéu. Esperando os outros..."),
        h("p.center.bold", `${v.submitted.length} de ${v.players.length} já escreveram`)), list];
    }
    const inputs = [];
    for (let i = 0; i < n; i++) {
      const inp = h("input.field", { placeholder: `Palavra ${i + 1}`, maxlength: 40, "data-keep": `w${i}`, enterkeyhint: i + 1 < n ? "next" : "send" });
      inp.addEventListener("keydown", (e) => {
        if (e.key !== "Enter") return;
        if (inputs[i + 1]) inputs[i + 1].focus();
        else submit();
      });
      inputs.push(inp);
    }
    function submit() {
      const words = inputs.map((i) => i.value.trim().replace(/\s+/g, " "));
      const empty = words.findIndex((w) => !w);
      if (empty >= 0) {
        toast("Preencha todas as palavras", "red");
        inputs[empty].focus();
        return;
      }
      document.activeElement && document.activeElement.blur();
      act({ type: "submit_words", words });
    }
    return [header("Palavras"), h("p.sub.center", `Escreva ${plural(n, "palavra", "palavras")} em segredo`),
      h("p.caption", "Nomes de famosos, objetos, filmes... o que quiser! Ninguém vai ver quem escreveu."),
      card(null, inputs), button("Enviar pro chapéu", "success", submit, "check"), list];
  }

  function roundIntro() {
    const r = round();
    return [header("Chapéu"),
      card(r.cor, h("p.sub.center", `Rodada ${v.round + 1} de 3`),
        h("img", { src: `assets/${r.icone}.svg`, style: { width: "130px", height: "130px", margin: "0 auto" }, alt: "" }),
        h("h2.title", { style: { fontSize: "46px" } }, r.nome), h("p.center.bold.big", r.regra)),
      h("p.caption", `${v.word_count} palavras no chapéu`),
      v.round > 0 ? scoreboard() : null, h("p.caption", "Esperando o host...")];
  }

  function turnReady() {
    const team = v.team_turn;
    const mine = me();
    const ex = byId(v.explainer);
    const carrying = v.carry_ms > 0 && ex;
    const canChoose = !carrying && mine && mine.team === team;
    const out = [header("Chapéu"),
      card(TEAM[team].cor, h("p.sub.center", "Vez do"), h("h2.title", { style: { fontSize: "46px" } }, TEAM[team].nome), h("p.center.bold", round().curta))];
    const choices = (small) => v.players.filter((p) => p.team === team).map((p) => {
      const label = !p.connected ? `${p.name} (desconectado)` : (p.explained > 0 ? `${p.name} · explicou ${p.explained}×` : p.name);
      const b = button(label, small ? "secondary" : TEAM[team].btn, () => act({ type: "choose_explainer", id: p.id }), null, small ? "small" : "");
      b.disabled = !p.connected || p.id === v.explainer;
      return b;
    });
    if (ex) {
      const iExplain = mine && mine.id === ex.id;
      out.push(card(null, h("div.avatar", { style: { background: TEAM[team].cor, width: "90px", height: "90px", fontSize: "44px", margin: "0 auto" } }, ex.name.charAt(0).toUpperCase()),
        h("h2.title", iExplain ? "Você vai explicar!" : `${ex.name} vai explicar`),
        carrying ? h("p.center.bold", `Continua com o tempo que sobrou: ${Math.ceil(v.carry_ms / 1000)} s`) : null));
      if (iExplain) out.push(button("Começar!", "success", () => act({ type: "start_turn" }), "play", "huge"));
      else out.push(h("p.caption", `Esperando ${ex.name} começar...`));
      if (canChoose) out.push(h("p.bold", "Trocar quem explica:"), ...choices(true));
    } else if (canChoose) {
      out.push(h("p.sub.center", "Quem vai explicar?"), ...choices(false));
    } else {
      out.push(h("p.sub.center", `O ${TEAM[team].nome} está escolhendo quem explica...`));
    }
    out.push(scoreboard());
    return out;
  }

  function turn() {
    const team = v.team_turn;
    const mine = me();
    const ex = byId(v.explainer) || { name: "" };
    const r = round();
    const iExplain = mine && mine.id === v.explainer;
    const top = h("div.row", card(r.cor, h("div.center.bold", `${r.nome}: ${r.curta}`)));
    top.firstChild.classList.add("grow");
    top.firstChild.style.padding = "10px 14px";
    if (iExplain && !v.paused) top.append(button("", "secondary", () => act({ type: "pause" }), "pause", "icon-btn"));
    const stats = h("p.caption.bold", `Acertos: ${v.turn_hits} · Pulos: ${v.turn_skips}`);
    if (v.paused) {
      const dis = v.pause_reason === "disconnect";
      return [top,
        card("var(--mostarda)", h("h2.title", dis ? `Esperando ${ex.name} voltar...` : "Pausado"),
          h("p.center.bold", dis ? "A conexão caiu. O tempo está parado." : `Restam ${Math.ceil(timeMs / 1000)} s`)),
        !dis && iExplain ? button("Continuar", "success", () => act({ type: "resume" }), "play", "huge") : null,
        !dis && !iExplain ? h("p.caption", `${ex.name} pausou o jogo.`) : null,
        scoreboard(team)];
    }
    if (iExplain) {
      return [top, ring(170), card(null, h("div.word.pop", v.word)), stats,
        h("div.grid2",
          button("Pular", "danger", () => act({ type: "skip" }), "skip", "huge"),
          button("Acertou!", "success", () => act({ type: "hit" }), "check", "huge")),
        h("p.caption", "Pular custa 1 ponto")];
    }
    const myTeam = mine && mine.team === team;
    return [top, ring(220),
      myTeam ? card(TEAM[team].cor, h("h2.title", { style: { fontSize: "52px" } }, "Adivinhe!"), h("p.center.bold", `${ex.name} está explicando`))
        : [h("p.sub.center", `Vez do ${TEAM[team].nome}`), h("p.caption", `${ex.name} está explicando. Fica de olho!`),
          v.config.opponent_sees_word && v.word ? card("var(--papel)", h("p.caption", "A palavra é"), h("div.word", { style: { fontSize: "34px", minHeight: "0" } }, v.word)) : null],
      stats, scoreboard(team)];
  }

  function summary() {
    const team = v.team_turn;
    const ex = byId(v.explainer) || { name: "" };
    const saldo = v.turn_hits - v.turn_skips;
    const mine = me();
    return [header("Chapéu"),
      card(TEAM[team].cor, h("h2.title", v.turn_round_over ? "O chapéu esvaziou!" : "Tempo esgotado!"),
        h("p.center.bold", { style: { fontSize: "28px", fontFamily: "Fraunces" } }, `${saldo >= 0 ? "+" : ""}${saldo} pro ${TEAM[team].nome}`),
        h("p.center.bold", `${v.turn_hits} acertos · ${v.turn_skips} pulos`)),
      v.hit_words.length ? card(null, h("p.sub", "Acertaram"), h("div.chips", v.hit_words.map((w) => h("span.chip", w)))) : null,
      v.turn_round_over && v.carry_ms > 0 ? h("p.caption", `${ex.name} começa a próxima rodada com ${Math.ceil(v.carry_ms / 1000)} s.`) : null,
      scoreboard(),
      mine && mine.id === v.explainer ? button("Continuar", "", () => act({ type: "next" }), "play") : h("p.caption", `Esperando ${ex.name} continuar...`)];
  }

  function roundEnd() {
    const r = round();
    const pts = v.scores[v.round];
    const w = pts[0] === pts[1] ? "" : (pts[0] > pts[1] ? "azul" : "vermelho");
    return [header("Chapéu"),
      card(r.cor, h("p.sub.center", `Fim da rodada ${v.round + 1}`), h("h2.title", r.nome),
        h("p.center.bold.big", w ? `Rodada do ${TEAM[w].nome}!` : "Rodada empatada!"), h("p.center.bold", `Azul ${pts[0]} × ${pts[1]} Vermelho`)),
      h("p.sub.center", "Placar geral"), scoreboard(), h("p.caption", "Esperando o host...")];
  }

  function gameOver() {
    const res = v.result || {};
    const w = res.winner || "";
    const rw = res.rounds_won || {};
    const names = ["Descrever", "Uma palavra", "Mímica"];
    v.totals = res.totals || v.totals;
    return [
      card(w ? TEAM[w].cor : "var(--mostarda)", h("div", { style: { fontSize: "72px", textAlign: "center" } }, "🏆"),
        h("h2.title", { style: { fontSize: "44px" } }, w ? `${TEAM[w].nome} venceu!` : "Empate!"), h("p.center.bold", CRITERIA[res.criterion] || "")),
      scoreboard(w),
      card(null, h("p.bold", `Rodadas vencidas: Azul ${rw.azul || 0} × ${rw.vermelho || 0} Vermelho`),
        (res.scores || []).map((s, i) => h("div.row", h("div.grow.bold", names[i]),
          h("b", { style: { color: "var(--azul-e)", width: "50px", textAlign: "center" } }, s[0]),
          h("b", { style: { color: "var(--vermelho-e)", width: "50px", textAlign: "center" } }, s[1])))),
      h("p.caption", "Se o host quiser, a próxima começa daqui.")];
  }

  const PHASES = { lobby, writing, round_intro: roundIntro, turn_ready: turnReady, turn, turn_summary: summary, round_end: roundEnd, game_over: gameOver };

  function events(list) {
    for (const e of list) {
      switch (e.type) {
        case "hit": sound("hit"); vibrate(40); break;
        case "skip": sound("skip"); vibrate([30, 60, 30]); break;
        case "time_up": sound("buzzer"); vibrate(400); break;
        case "turn_started": sound("start"); break;
        case "player_joined": sound("join"); break;
        case "words_submitted": sound("pop"); break;
        case "player_connection": toast(`${e.name} ${e.connected ? "voltou" : "caiu da rede"}`); break;
        case "phase": if (e.phase === "round_intro") sound("round"); break;
        case "game_over": sound("win"); break;
      }
    }
  }

  GH.games.chapeu = {
    render(view, evs) {
      const phaseChanged = !v || v.phase !== view.phase;
      v = view;
      timeMs = view.time_ms || 0;
      if (phaseChanged) lastSec = -1;
      GH.keepAwake(view.phase !== "lobby");
      mount(h("div.col", (PHASES[view.phase] || lobby)()));
      updateTimer();
      events(evs);
    },
    onMessage(msg) {
      if (msg.type === "tempo" && v) timeMs = msg.ms;
    },
  };
})();
