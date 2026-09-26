// Quem Foi? no navegador: jogador e tabuleiro (games/quem_foi/screens/quem_foi_game.gd).
// A corrida é justa como o sino do Halli Galli: o toque vai com a hora do host, acertada por pings.
"use strict";

(() => {
  const { h, button, card, player, mount, toast, sound, vibrate, act, send, st } = GH;
  const COLORS = ["#2B59C3", "#C8392B", "#2F7D5B", "#E0A21F", "#6E3B93", "#D9772B"];
  const NAMES = { gato: "Gato", peixe: "Peixe", tartaruga: "Tartaruga", coelho: "Coelho", hamster: "Hamster", papagaio: "Papagaio" };
  const MINE = { gato: "o meu gato", peixe: "o meu peixe", tartaruga: "a minha tartaruga", coelho: "o meu coelho", hamster: "o meu hamster", papagaio: "o meu papagaio" };
  const WITH = { gato: "o gato", peixe: "o peixe", tartaruga: "a tartaruga", coelho: "o coelho", hamster: "o hamster", papagaio: "o papagaio" };
  const MISS_LOCK_MS = 1000;

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
    toHostMs(localUs) { return Math.floor((localUs + this.offset()) / 1000); },
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

  let v = null;
  let lastPhase = "";
  let openPlay = ""; // abertura: o bicho escolhido pra jogar, antes de acusar
  let lockUntil = 0;
  let sentRace = -1;
  let flash = "";

  const pcolor = (i) => COLORS[i % COLORS.length];
  const byId = (id) => (v.players || []).find((p) => p.id === id) || { name: "?", color: 0, connected: true, poops: 0, cards: 0 };
  const nameOf = (id) => byId(id).name;
  const board = () => st.papel === "board";
  const playing = () => !board() && !!v.you;
  const tint = (c, pct) => `color-mix(in srgb, var(--superficie) ${100 - pct}%, ${c})`;

  function big(title, bg, sub) {
    return card(bg || null, h("h2.title", title), sub ? h("p.center.bold", sub) : null);
  }

  function pic(name, cls) {
    const img = h("img" + (cls ? "." + cls : ""), { src: `assets/qf/${name}.webp`, alt: NAMES[name] || "", draggable: "false" });
    return img;
  }

  // Carta do bicho com a cor do dono.
  function animalCard(animal, color, onTap, dim) {
    const el = h("div.qf-card" + (dim ? ".dim" : ""), { style: { "--c": color } }, pic(animal), h("b", NAMES[animal]));
    if (onTap) el.addEventListener("pointerdown", (e) => { e.preventDefault(); onTap(animal, nowUs(), el); });
    return el;
  }

  function poops(n) {
    const out = [];
    for (let i = 0; i < n; i++) out.push(pic("coco", "qf-poop"));
    return out;
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
    return h("div.qf-score", v.players.map((p) => h("div.qf-chip", { style: { background: tint(pcolor(p.color), p.id === v.accuser ? 50 : 25) } },
      h("div.avatar" + (p.connected ? "" : ".off"), { style: { background: pcolor(p.color) } }, p.name.charAt(0).toUpperCase()),
      h("div", h("b", p.name), h("small", p.cards > 0 ? `${p.cards} bicho${p.cards === 1 ? "" : "s"}` : "a salvo")), poops(p.poops))));
  }

  function pile() {
    if (!v.top || !v.top.animal) return h("div.qf-pile", pic("coco", "qf-bigpoop"));
    return h("div.qf-pile", animalCard(v.top.animal, pcolor(byId(v.top.owner).color)));
  }

  function phrase() {
    if (!v.accused || !v.top || !v.top.animal) return null;
    return card("var(--mostarda)", h("p.center.bold", `${nameOf(v.accuser)}: "Não foi ${MINE[v.top.animal]}…"`),
      h("h2.title", `Acho que foi ${WITH[v.accused].replace(/ (.*)/, (m, x) => " " + x.toUpperCase())} de alguém!`));
  }

  function memory() {
    if (!v.config.memory_help || !Object.keys(v.played || {}).length) return null;
    const parts = v.animals.filter((a) => v.played[a]).map((a) => `${NAMES[a]} ${v.played[a]}`);
    return h("p.caption.bold", `Já saíram: ${parts.join(", ")} (de ${v.players.length})`);
  }

  function hand(animals, onTap, dim, color) {
    const c = color || pcolor(byId(v.you).color);
    return h("div.qf-hand", animals.map((a) => animalCard(a, c, onTap, dim)));
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

  // --- Fases ----------------------------------------------------------------

  function lobby() {
    const capa = h("img.av-banner", { src: "assets/qf/capa.webp", alt: "" });
    capa.onerror = () => capa.remove();
    return [header("Sala do Quem Foi?"), capa,
      card(null, h("p.sub", `Na mesa (${v.players.length})`), v.players.map((p) => player(p.name, pcolor(p.color), p.connected, p.id === v.you ? "você" : ""))),
      card("var(--papel)", h("p.sub", "Partida"),
        h("p.bold", `Acaba com ${v.config.max_poops} cocôs · ajuda de memória ${v.config.memory_help ? "ligada" : "desligada"}`),
        h("p.caption", { style: { textAlign: "left" } }, "De 3 a 6 pessoas, cada uma com os 6 bichos de uma cor.")),
      h("p.caption", board() ? "Este aparelho é o tabuleiro. Esperando o host começar..." : "Esperando o host começar a partida...")];
  }

  function accuse() {
    const out = [header("Quem Foi?"), score(), pile(), memory()];
    const mine = playing() && v.accuser === v.you;
    if (!mine) {
      out.push(big(`${nameOf(v.accuser)} está acusando`, null, v.top && v.top.animal ? "Ganhou a corrida! Agora acusa o próximo bicho." : "Vai jogar um bicho e acusar outro."));
      if (playing() && v.hand.length) out.push(h("p.caption", "Seus bichos:"), hand(v.hand, null, true));
      return out;
    }
    const opening = !v.top || !v.top.animal;
    if (opening && !openPlay) {
      out.push(big("Você começa!", "var(--mostarda)", "Escolha o bicho que você joga na mesa."), hand(v.hand, (a) => { openPlay = a; render(); }));
      return out;
    }
    const played = opening ? openPlay : v.top.animal;
    out.push(big(`"Não foi ${MINE[played]}…"`, "var(--mostarda)", "…acho que foi de alguém! Toque no bicho que você acusa."),
      hand(v.animals, (a) => { const x = { type: "accuse", animal: a }; if (opening) x.play = openPlay; openPlay = ""; act(x); }, false, "var(--suave)"));
    if (opening) out.push(button("Trocar o bicho que eu jogo", "secondary", () => { openPlay = ""; render(); }, null, "small"));
    return out;
  }

  function raceTap(animal, us, el) {
    const now = performance.now();
    if (now < lockUntil || sentRace === v.race_no) return;
    if (animal === v.accused) {
      sentRace = v.race_no;
      act({ type: "tap", animal, t: clock.toHostMs(us) });
      sound("tap");
      render();
      return;
    }
    lockUntil = now + MISS_LOCK_MS;
    act({ type: "miss" });
    sound("hg_wrong");
    vibrate([60, 40, 60]);
    const box = el.closest(".qf-hand");
    if (box) {
      box.classList.add("locked");
      setTimeout(() => box.classList.remove("locked"), MISS_LOCK_MS);
    }
  }

  function race() {
    const out = [header("Quem Foi?"), score(), pile(), phrase(), memory()];
    if (board()) {
      if (flash) out.push(h("p.center.bold.big", { style: { color: "var(--salvia-e)" } }, flash));
      out.push(h("p.caption", "Quem tem esse bicho corre pra jogar primeiro!"));
      return out;
    }
    if (v.accuser === v.you) {
      out.push(h("p.caption", "Você acusou. Agora é com os outros!"), hand(v.hand, null, true));
      return out;
    }
    if (!v.hand.length) {
      out.push(big("Seus bichos são inocentes!", tint("var(--salvia)", 40), "Agora é só assistir."));
      return out;
    }
    const sent = sentRace === v.race_no;
    out.push(h("p.caption", sent ? "Foi! Esperando o resultado..." : "Tem esse bicho? Ache e toque, rápido!"), hand(v.hand, raceTap, sent));
    return out;
  }

  function roundEnd() {
    const last = v.last || {};
    const g = byId(last.guilty);
    const head = last.reason === "ninguem_tem"
      ? [h("h2.title", `Ninguém tem mais ${(NAMES[last.accused] || "").toLowerCase()}!`), h("p.center.bold.big", `Então foi ${WITH[last.animal]} de ${g.name}!`)]
      : [h("h2.title", `Só ${g.name} ficou com bichos!`), h("p.center.bold", "Não tem mais ninguém pra quem passar a culpa.")];
    const hands = last.hands || {};
    const proof = v.players.map((p) => h("div.row.qf-proof", h("b", { style: { color: pcolor(p.color), minWidth: "96px" } }, p.name),
      (hands[p.id] || []).length ? (hands[p.id] || []).map((a) => pic(a, "qf-mini")) : h("small.caption.bold", "nada, a salvo")));
    const most = Math.max(...v.players.map((p) => p.poops));
    return [header("Quem foi?"),
      card(tint("#7A4A2A", 25), ...head, h("div.row", { style: { justifyContent: "center" } }, animalCard(last.animal, pcolor(g.color)), pic("coco", "qf-bigpoop")),
        h("p.center.bold", `${g.name} leva um cocô.`)),
      score(), card("var(--papel)", h("p.sub", "O que cada um tinha"), proof),
      playing() || board() ? button(most < v.max_poops ? "Próxima rodada" : "Ver o resultado", "success", () => act({ type: "continue" }), "play") : null];
  }

  function gameOver() {
    const names = v.winners.map(nameOf);
    const sorted = [...v.players].sort((a, b) => a.poops - b.poops);
    return [big(names.length === 1 ? `${names[0]} venceu!` : `${names.join(" e ")} venceram!`, tint("var(--salvia)", 45), "Menos cocôs, dono mais cuidadoso."),
      card("var(--papel)", sorted.map((p) => h("div.row", player(p.name, pcolor(p.color), true, p.poops ? "" : "nenhum!"), h("div.row", poops(p.poops))))),
      h("p.caption", "Se o host quiser, a próxima começa daqui."), button("Sair", "secondary", GH.confirmLeave)];
  }

  const PHASES = { lobby, accuse, race, round_end: roundEnd, game_over: gameOver };

  function render() {
    mount(h("div.col" + (board() ? ".av-board.qf-board" : ""), (PHASES[v.phase] || lobby)()));
  }

  function events(list) {
    for (const e of list) {
      switch (e.type) {
        case "player_joined": sound("join"); break;
        case "player_connection": toast(`${e.name} ${e.connected ? "voltou" : "caiu da rede"}`); break;
        case "accused": sound("qf_pum"); vibrate(30); break;
        case "won_race": if (e.id === v.you) { sound("qf_plim"); vibrate(40); } else sound("pop"); break;
        case "guilty": sound("qf_descarga"); vibrate(300); break;
        case "game_over": sound("win"); break;
      }
    }
  }

  GH.games.quem_foi = {
    onOpen: startPings,
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
        if (e.type === "round" || e.type === "started") openPlay = "";
        if (e.type === "accused") lockUntil = 0;
        if (e.type === "won_race") flash = `${nameOf(e.id)} jogou primeiro!`;
      }
      if (view.phase !== lastPhase) {
        GH.closeOverlay();
        GH.keepAwake(view.phase !== "lobby");
        if (view.phase === "accuse") GH.preload(["qf_pum", "qf_plim", "qf_descarga", "hg_wrong"]);
      }
      lastPhase = view.phase;
      render();
      events(evs);
    },
  };
})();
