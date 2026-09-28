// Base do Wordle e do Senha no navegador (games/desafio_base/desafio_net_screen.gd): relógio do
// host (o palpite vai com a hora do host, como no Halli Galli), sala, contagem, mini-grades e
// resultado. Cada jogo (wordle.js, senha.js) desenha a sua grade e a sua entrada.
"use strict";

GH.desafio = (() => {
  const { h, button, card, player, toast, st } = GH;
  const COLORS = ["#2B59C3", "#C8392B", "#2F7D5B", "#E0A21F", "#6E3B93", "#1E7F86", "#D9772B", "#C4467A"];
  const CRITERIA = { tentativas: "Menos tentativas", primeiro: "Primeiro a acertar", pontos: "Pontos em rodadas" };
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
    hostMs() { return Math.floor((nowUs() + this.offset()) / 1000); },
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
      GH.send({ type: "ping", c: nowUs(), rtt: clock.maxRtt() });
      n += 1;
      pingTimer = setTimeout(tick, n < 12 ? 100 : 1000);
    };
    tick();
  }

  const color = (i) => COLORS[i % COLORS.length];
  const byId = (v, id) => (v.players || []).find((p) => p.id === id) || { name: "?", color: 0, connected: true };
  const secs = (ms) => ms < 60000 ? `${(ms / 1000).toFixed(1)} s` : `${Math.floor(ms / 60000)}:${String(Math.floor(ms / 1000) % 60).padStart(2, "0")}`;

  function header(text) {
    return h("div.row", h("h1.title.left.grow", text), button("", "secondary", GH.confirmLeave, "close", "icon-btn"));
  }

  function raceLines(cfg) {
    return [`Vence: ${CRITERIA[cfg.criterio]}${cfg.criterio === "pontos" ? ` (${cfg.rodadas} rodadas)` : ""}`,
      `Tempo: ${cfg.tempo_min > 0 ? cfg.tempo_min + " min" : "sem limite"}`];
  }

  function lobby(v, game, lines) {
    return [header(`Sala do ${game}`),
      card(null, h("p.sub", `Na sala (${v.players.length})`), v.players.map((p) => player(p.name, color(p.color), p.connected, p.id === v.you ? "você" : ""))),
      card("var(--papel)", h("p.sub", "Partida"), lines.map((l) => h("p.bold", l))),
      h("p.caption", "Esperando o host começar a partida...")];
  }

  let countEnd = 0;
  let countEl = null;
  function countdown(v, title, lines) {
    countEnd = performance.now() + v.countdown_ms;
    countEl = h("div.dz-count", "3");
    tickCount();
    return [header(title), card("var(--mostarda)", h("p.center.bold", roundText(v)), countEl, h("p.center.bold", "Prepare-se!")),
      lines.map((l) => h("p.caption", l))];
  }
  function tickCount() {
    if (!countEl || !document.body.contains(countEl)) return;
    const left = countEnd - performance.now();
    countEl.textContent = left > 0 ? String(Math.max(1, Math.ceil(left / 1000))) : "Já!";
    if (left > -500) setTimeout(tickCount, 100);
  }

  function roundText(v) {
    return v.rounds_total > 1 ? `Rodada ${v.round} de ${v.rounds_total}` : "Todo mundo tenta o mesmo segredo";
  }

  // Tempo limite da rodada, contando aqui (o host manda quanto falta a cada estado).
  let timerEnd = 0;
  let timerEl = null;
  function timer(v) {
    if (v.timer_left_ms < 0) return null;
    timerEnd = performance.now() + v.timer_left_ms;
    timerEl = h("p.center.dz-timer");
    tickTimer();
    return timerEl;
  }
  function tickTimer() {
    if (!timerEl || !document.body.contains(timerEl)) return;
    const s = Math.max(0, Math.ceil((timerEnd - performance.now()) / 1000));
    timerEl.textContent = s > 0 ? `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}` : "Tempo esgotado!";
    if (s > 0) setTimeout(tickTimer, 250);
  }

  function status(me) {
    if (me.solved) return `Acertou em ${me.guesses.length}! Esperando os outros...`;
    if (me.done) return "Acabaram suas tentativas. Esperando os outros...";
    return "";
  }

  // miniBoard(guessesColors) -> elemento só com as cores.
  function minis(v, miniBoard) {
    return h("div.dz-minis", (v.others || []).map((o) => {
      const p = byId(v, o.id);
      return h("div.dz-mini" + (p.connected ? "" : ".off"), h("p.bold", (o.solved ? "✓ " : "") + p.name), miniBoard(o.c));
    }));
  }

  // fullBoard(boardView) -> grade com as letras/símbolos (fim da rodada).
  function results(v, secretEl, fullBoard) {
    const over = v.phase === "game_over";
    const pontos = v.config.criterio === "pontos";
    const out = [header(over ? "Fim de jogo" : "Fim da rodada"),
      card("var(--salvia)", h("p.center.bold", v.time_up ? "Tempo esgotado! O segredo era:" : "O segredo era:"), secretEl)];
    if (pontos && over) {
      out.push(card("var(--mostarda)", h("p.sub", "Placar final"),
        v.standings.map((s, i) => player(`${i + 1}º ${byId(v, s.id).name}`, color(byId(v, s.id).color), true, `${s.score} pontos`))));
    }
    out.push(card(null, h("p.sub", pontos ? "Resultado da rodada" : "Classificação"), v.results.map((r) => {
      let extra = r.solved ? `${r.tries} tent. · ${secs(r.ms)}${pontos ? ` · +${r.points}` : ""}` : "não acertou";
      return player(`${r.pos}º ${byId(v, r.id).name}`, color(byId(v, r.id).color), true, extra);
    })));
    out.push(h("div.dz-minis", v.results.filter((r) => v.boards[r.id]).map((r) => h("div.dz-mini", h("p.bold", byId(v, r.id).name), fullBoard(v.boards[r.id])))));
    out.push(h("p.caption", over ? "Se o host quiser, a próxima começa daqui." : "Esperando o host chamar a próxima rodada..."));
    out.push(button("Sair", "secondary", GH.confirmLeave, "close"));
    return out;
  }

  function onRejected(msg) {
    toast(msg, "red");
    GH.vibrate(80);
  }

  return { clock, startPings, color, byId, header, raceLines, lobby, countdown, timer, status, minis, results, onRejected, secs, CRITERIA };
})();
