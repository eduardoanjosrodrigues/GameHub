// Avalon no navegador: jogador e tabuleiro (games/avalon/screens/avalon_game.gd).
"use strict";

(() => {
  const { h, button, card, player, mount, toast, sound, vibrate, act, st } = GH;
  const COLORS = ["#2B59C3", "#C8392B", "#2F7D5B", "#E0A21F", "#6E3B93", "#1E7F86", "#D9772B", "#C4467A"];
  const BEM = "var(--azul)";
  const MAL = "var(--vermelho)";
  const ROLES = {
    merlin: ["Merlin", true, "Você sabe quem é do mal (menos Mordred). Ajude o bem sem se entregar: se no fim o Assassino descobrir quem você é, o mal vence."],
    percival: ["Percival", true, "Você vê Merlin e Morgana, mas não sabe quem é quem. Descubra qual é o verdadeiro Merlin e proteja ele."],
    servo: ["Servo leal de Arthur", true, "Você não sabe de nada. Preste atenção em quem vota e em quem falha as missões."],
    assassino: ["Assassino", false, "Sabote as missões. Se o bem completar 3 missões, você tem uma última chance: adivinhar quem é Merlin."],
    morgana: ["Morgana", false, "Pro Percival, você aparece como se fosse Merlin. Use isso pra enganar ele."],
    mordred: ["Mordred", false, "Merlin não sabe que você é do mal. Aproveite a confiança."],
    oberon: ["Oberon", false, "Você é do mal, mas não sabe quem são os outros, e eles não sabem que você é. Sabote sozinho."],
    lacaio: ["Lacaio de Mordred", false, "Sabote as missões sem ser descoberto."],
  };
  const REASONS = {
    rejects: "5 times recusados seguidos: o mal venceu.",
    quests: "3 missões decidiram o jogo.",
    assassin_hit: "O Assassino acertou quem era Merlin!",
    assassin_miss: "O Assassino errou: Merlin estava salvo.",
  };

  let v = null;
  let lastPhase = "";
  // Quem assumiu a vaga pelo QR "Trocar aparelho" recebe a carta virada (quem emprestou não vê).
  let hidden = !!st.vaga;
  let timerMs = -1;
  let timerEl = null;

  const color = (i) => COLORS[i % COLORS.length];
  const byId = (id) => (v.players || []).find((p) => p.id === id) || { name: "?", color: 0, connected: true };
  const nameOf = (id) => byId(id).name;
  const names = (ids) => ids.map(nameOf).join(", ");
  const board = () => st.papel === "board";
  const isLeader = () => !board() && v.leader === v.you;
  const canContinue = () => board() || isLeader();
  const good = (r) => (ROLES[r] || [0, true])[1];

  // Arte do Nano Banana, se existir (senão a imagem some).
  function art(file, cls) {
    const img = h("img." + cls, { src: `assets/avalon/${file}`, alt: "" });
    img.onerror = () => img.remove();
    return img;
  }

  function big(title, bg, sub) {
    return card(bg || null, h("h2.title", title), sub ? h("p.center.bold", sub) : null);
  }

  function header(text) {
    const kids = [h("h1.title.left.grow", text)];
    if (!board() && v.role && !["lobby", "reveal"].includes(v.phase)) {
      kids.push(button("Meu papel", "secondary", peek, null, "small"));
      kids[1].style.width = "auto";
    }
    if (board() && v.phase !== "lobby") kids.push(button("", "secondary", swapList, "phone", "icon-btn"));
    kids.push(button("", "secondary", GH.confirmLeave, "close", "icon-btn"));
    const out = [h("div.row", kids)];
    const off = v.players.filter((p) => !p.connected);
    if (board() && v.phase !== "lobby" && off.length) out.push(button(`${names(off.map((p) => p.id))} caiu · Trocar aparelho`, "danger", swapList, "phone", "small"));
    return out;
  }

  // --- Trocar aparelho (net/seat_transfer.gd) ---------------------------------
  let swapSeat = "";
  let swapWasOn = false; // a pessoa estava conectada quando o QR abriu

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
      h("img.qr", { src: `qr.svg?d=${encodeURIComponent(url)}`, alt: "" }),
      h("p.caption", url),
      button("Voltar", "secondary", swapList)]);
  }

  // Trilha das 5 missões e das recusas.
  function track() {
    const circles = [0, 1, 2, 3, 4].map((i) => {
      const r = v.results[i];
      const cur = i === v.quest && i >= v.results.length;
      const c = h("div.av-q" + (r === "ok" ? ".ok" : r === "fail" ? ".fail" : "") + (cur ? ".cur" : ""),
        r === "ok" ? "✓" : r === "fail" ? "✗" : String(v.quest_sizes[i] || ""));
      const sub = i < v.results.length && v.quest_fails[i] > 0 ? `${v.quest_fails[i]} falha${v.quest_fails[i] === 1 ? "" : "s"}` : (i === 3 && v.two_fails ? "2 falhas" : "");
      return h("div.av-qbox", c, h("small", sub || " "));
    });
    const rej = [0, 1, 2, 3, 4].map((k) => h("span.av-r" + (k < v.rejects ? ".on" : "")));
    return h("div.av-track",
      h("div.av-quests", circles),
      h("div.av-rejects", h("small", "Recusas"), rej),
      h("p.caption.bold", `Líder: ${nameOf(v.leader)} · Missão ${v.quest + 1} · ${v.evil_count} do mal na mesa`),
      v.lady_on && v.lady ? h("p.caption", `Dama do Lago: ${nameOf(v.lady)}`) : null);
  }

  function playersBlock(extra) {
    return card(null, v.players.map((p) => player(p.name, color(p.color), p.connected, extra(p))));
  }

  function teamCard(title, ids, need) {
    return card(null, h("p.sub", title + (need ? ` (${ids.length}/${need})` : "")),
      ids.length ? ids.map((id) => player(nameOf(id), color(byId(id).color), byId(id).connected)) : h("p.caption", "Ninguém ainda"));
  }

  function roleCard() {
    const r = v.role;
    const variant = Math.max(0, v.players.findIndex((p) => p.id === v.you)) % 3 + 1;
    const file = ["servo", "lacaio"].includes(r) ? `${r}_${variant}` : r;
    const el = h("div.av-card" + (hidden ? ".hidden" : ""), { style: { "--side": good(r) ? BEM : MAL }, onclick: () => { hidden = !hidden; render(); } });
    if (hidden) {
      el.append(h("img", { src: "assets/avalon.svg", alt: "" }), h("span", "Toque pra ver seu papel"));
      return el;
    }
    // Tenta a arte em cada formato; se nenhuma existir, mostra o emblema.
    const tries = [`${file}.png`, `${file}.jpg`, `${file}.webp`];
    if (file !== r) tries.push(`${r}_1.jpg`, `${r}_1.png`);
    const img = h("img.portrait", { src: `assets/avalon/${tries.shift()}`, alt: "" });
    const emb = h("span.emblem", { style: { "--m": `url(assets/emblema_${r}.svg)` } });
    emb.style.display = "none";
    img.onerror = () => {
      if (tries.length) img.src = `assets/avalon/${tries.shift()}`;
      else { img.remove(); emb.style.display = ""; }
    };
    el.append(img, emb, h("b", ROLES[r][0]));
    return el;
  }

  function roleInfo() {
    const r = v.role;
    const out = [h("p.center.big.bold", { style: { color: good(r) ? "var(--azul-e)" : "var(--vermelho-e)", fontFamily: "Fraunces" } }, `Você é do ${good(r) ? "BEM" : "MAL"}`),
      h("p.center", ROLES[r][2])];
    const ids = (v.knows || []).map((k) => k.id);
    if (ids.length) {
      const text = r === "merlin" ? `Estes são do mal: ${names(ids)}` : r === "percival" ? `Um destes é Merlin e o outro é Morgana: ${names(ids)}` : `Seus parceiros do mal: ${names(ids)}`;
      out.push(h("p.center.bold.big", text));
    } else if (r === "oberon") out.push(h("p.center.bold", "Você não sabe quem são os outros do mal."));
    for (const s of v.lady_seen || []) out.push(h("p.center.bold", `Dama do Lago: ${nameOf(s.id)} é do ${s.evil ? "mal" : "bem"}`));
    return card(good(r) ? BEM : MAL, ...out);
  }

  function peek() {
    const was = hidden;
    hidden = false;
    GH.overlay("Seu papel", "", [roleCard(), roleInfo(), button("Fechar", "", GH.closeOverlay)]);
    hidden = was;
  }

  // --- Fases ----------------------------------------------------------------

  function lobby() {
    const cfg = v.config;
    const n = v.players.length;
    return [header("Sala do Avalon"), art("capa.jpg", "av-banner"),
      card(null, h("p.sub", `Ordem da mesa (${n})`),
        h("p.caption", { style: { textAlign: "left" } }, "A liderança passa de cima pra baixo. Quem criou a sala arruma a ordem."),
        v.players.map((p, i) => player(`${i + 1}. ${p.name}`, color(p.color), p.connected, !p.connected ? "desconectado" : (p.id === v.you ? "você" : "")))),
      card("var(--papel)", h("p.sub", "Personagens"),
        n >= 5 ? h("p.caption", { style: { textAlign: "left" } }, `Com ${n}: ${n - v.evil_count} do bem e ${v.evil_count} do mal.`) : null,
        h("p", cfg.roles.length ? cfg.roles.map((r) => ROLES[r][0]).join(", ") : "Só servos e lacaios"),
        h("p.caption", { style: { textAlign: "left" } }, `Dama do Lago: ${cfg.lady ? "sim" : "não"} · Cronômetro: ${cfg.timer_min > 0 ? cfg.timer_min + " min" : "desligado"}`)),
      h("p.caption", board() ? "Este aparelho é o tabuleiro. Esperando o host começar..." : "Esperando o host começar a partida...")];
  }

  function reveal() {
    const total = v.players.length;
    const done = v.ready.length;
    if (board()) {
      return [header("Seus papéis"), big("Cada um está vendo o seu papel", "var(--mostarda)", `Olhe só o seu celular! ${done} de ${total} prontos`),
        playersBlock((p) => v.ready.includes(p.id) ? "pronto ✓" : "vendo...")];
    }
    return [header("Seu papel"), h("p.caption", "Não mostre pra ninguém. Toque na carta pra esconder ou mostrar."),
      roleCard(), hidden ? null : roleInfo(),
      v.ready.includes(v.you) ? h("p.caption", `Esperando os outros: ${done} de ${total} prontos`)
        : button("Pronto, já vi", "success", () => act({ type: "ready" }), "check", "huge")];
  }

  function team() {
    const need = v.quest_sizes[v.quest];
    timerEl = v.timer_left_ms >= 0 ? h("p.center.bold.big", { style: { color: "var(--vermelho-e)", fontFamily: "Fraunces" } }) : null;
    if (isLeader()) {
      const picks = v.players.map((p) => {
        const on = v.team.includes(p.id);
        return button(p.name + (p.id === v.you ? " (você)" : ""), on ? "" : "secondary", () => {
          const t = [...v.team];
          if (on) t.splice(t.indexOf(p.id), 1);
          else if (t.length < need) t.push(p.id);
          else { toast(`A missão leva ${need} pessoas. Desmarque alguém.`); return; }
          act({ type: "select_team", ids: t });
        }, on ? "check" : null);
      });
      const send = button(`Enviar pra votação (${v.team.length}/${need})`, "success", () => act({ type: "propose" }), "play", "huge");
      send.disabled = v.team.length !== need;
      return [header("Montar o time"), track(), timerEl,
        big("Você é o líder!", "var(--mostarda)", `Escolha ${need} pessoas pra missão ${v.quest + 1} (pode ser você).`), card(null, picks), send];
    }
    return [header("Montar o time"), track(), timerEl,
      big(`${nameOf(v.leader)} está montando o time`, null, `Missão ${v.quest + 1} · ${need} pessoas`),
      teamCard("Escolhidos até agora", v.team, need), h("p.caption", "Conversem! Quem vocês confiam pra essa missão?")];
  }

  function vote() {
    const out = [header("Votação"), track(), teamCard(`Time proposto por ${nameOf(v.leader)}`, v.team)];
    if (!board() && v.role) {
      if (v.my_vote === null || v.my_vote === undefined) {
        out.push(h("p.sub.center", "Você aprova esse time?"),
          h("div.grid2", button("Aprovar", "azul", () => act({ type: "vote", approve: true }), "check", "huge"),
            button("Rejeitar", "vermelho", () => act({ type: "vote", approve: false }), "close", "huge")),
          h("p.caption", "Os votos aparecem todos juntos quando o último votar."));
      } else {
        out.push(big(`Você votou: ${v.my_vote ? "Aprovar" : "Rejeitar"}`, v.my_vote ? BEM : MAL));
      }
    }
    out.push(playersBlock((p) => v.voted.includes(p.id) ? "votou ✓" : "pensando..."));
    return out;
  }

  function voteResult() {
    const hist = v.history[v.history.length - 1] || {};
    const yes = Object.values(v.last_votes).filter((x) => x).length;
    let sub = `${yes} aprovaram, ${Object.keys(v.last_votes).length - yes} rejeitaram`;
    if (!hist.approved && v.rejects >= 5) sub += ". Quinta recusa: o mal vence!";
    else if (!hist.approved) sub += `. A liderança passa. Recusas: ${v.rejects} de 5.`;
    return [header("Resultado do voto"), track(),
      big(hist.approved ? "Time aprovado!" : "Time rejeitado", hist.approved ? BEM : MAL, sub),
      card(null, v.players.map((p) => h("div.player",
        h("div.avatar", { style: { background: color(p.color) } }, p.name.charAt(0).toUpperCase()),
        h("div.name", p.name), (hist.team || []).includes(p.id) ? h("div.extra", "no time") : null,
        h("img", { src: `assets/${v.last_votes[p.id] ? "voto_aprovar" : "voto_rejeitar"}.svg`, alt: "", style: { width: board() ? "64px" : "44px" } })))),
      continueButton()];
  }

  function continueButton() {
    return canContinue() ? button("Continuar", "", () => act({ type: "continue" }), "play") : h("p.caption", `Esperando ${nameOf(v.leader)} continuar...`);
  }

  function questCardBtn(success, enabled) {
    const fire = () => {
      if (!enabled) {
        vibrate([30, 60, 30]);
        GH.overlay("Contra as regras", "Os servos leais de Arthur só podem jogar Sucesso. Só quem é do mal pode jogar Falha.", [button("Entendi", "", GH.closeOverlay)]);
        return;
      }
      vibrate(20);
      act({ type: "quest_card", success });
    };
    return h("div.av-choice" + (enabled ? "" : ".off"), { onclick: fire },
      h("img", { src: `assets/${success ? "missao_sucesso" : "missao_falha"}.svg`, alt: "" }),
      h("span.btn." + (success ? "azul" : "vermelho"), success ? "Sucesso" : "Falha"));
  }

  function quest() {
    const inTeam = !board() && v.team.includes(v.you);
    const out = [header(`Missão ${v.quest + 1}`), track()];
    if (inTeam && (v.my_card === null || v.my_card === undefined)) {
      out.push(big("Você está na missão", "var(--mostarda)", "Escolha sua carta em segredo."),
        h("div.grid2", questCardBtn(true, true), questCardBtn(false, v.evil)),
        !v.evil ? h("p.caption", "Servos leais de Arthur só jogam Sucesso.") : (v.quest === 3 && v.two_fails ? h("p.caption", "Nesta missão são precisas 2 Falhas pra derrubar.") : null));
      return out;
    }
    if (inTeam) out.push(big(`Carta jogada: ${v.my_card ? "Sucesso" : "Falha"}`, v.my_card ? BEM : MAL, "Esperando o resto do time..."));
    else out.push(big("O time está na missão", null, names(v.team)));
    out.push(playersBlock((p) => v.team.includes(p.id) ? (v.played.includes(p.id) ? "jogou ✓" : "escolhendo...") : ""));
    return out;
  }

  function questResult() {
    const lq = v.last_quest || {};
    let sub = lq.fails === 0 ? "Nenhuma falha" : `${lq.fails} falha${lq.fails === 1 ? "" : "s"}`;
    if (lq.ok && lq.fails > 0) sub += " (eram precisas 2)";
    const cards = (lq.cards || []).map((c, i) => h("img.av-reveal", { src: `assets/${c ? "missao_sucesso" : "missao_falha"}.svg`, alt: "", style: { animationDelay: `${0.2 + i * 0.35}s` } }));
    return [header(`Missão ${(lq.quest || 0) + 1}`), track(), big(lq.ok ? "Missão cumprida!" : "A missão falhou!", lq.ok ? BEM : MAL, sub),
      h("div.av-cards", cards), continueButton()];
  }

  function lady() {
    const holder = v.lady;
    const target = v.lady_target || "";
    const mine = !board() && holder === v.you;
    const teal = "#1E7F86";
    const out = [header("Dama do Lago"), track(), art("dama_do_lago.jpg", "av-pic")];
    if (!target) {
      if (mine) {
        out.push(big("A Dama do Lago está com você", teal, "Escolha alguém pra ver, só no seu celular, se é do bem ou do mal."));
        v.players.filter((p) => p.id !== holder && !v.lady_used.includes(p.id))
          .forEach((p) => out.push(button(p.name, "secondary", () => act({ type: "lady_examine", id: p.id }))));
        out.push(h("p.caption", "Quem já teve a Dama não pode ser examinado."));
      } else out.push(big(`${nameOf(holder)} está com a Dama do Lago`, teal, "Escolhendo quem examinar..."));
      return out;
    }
    if (mine) {
      const seen = (v.lady_seen || []).filter((s) => s.id === target).pop();
      const evil = seen && seen.evil;
      out.push(big(`${nameOf(target)} é do ${evil ? "MAL" : "BEM"}`, evil ? MAL : BEM, "Só você vê isso. Conte (ou minta) o que quiser."),
        button(`Passar a Dama pra ${nameOf(target)}`, "", () => act({ type: "continue" }), "play"));
    } else {
      out.push(big(`${nameOf(holder)} examinou ${nameOf(target)}`, teal, `A Dama vai passar pra ${nameOf(target)}.`));
      if (board()) out.push(button(`Continuar por ${nameOf(holder)}`, "secondary", () => act({ type: "continue" }), null, "small"));
    }
    return out;
  }

  function assassin() {
    const out = [header("Assassinato"), track()];
    const evilIds = (v.evil_team || []).map((e) => e.id);
    if (!board() && v.role === "assassino") {
      out.push(big("O bem venceu 3 missões...", MAL, "Mas você ainda pode virar o jogo: quem é Merlin?"),
        h("p.caption", `Do mal: ${names(evilIds)}. Conversem antes de escolher.`));
      v.players.filter((p) => !evilIds.includes(p.id)).forEach((p) => out.push(button(p.name, "vermelho", () =>
        GH.overlay(`Assassinar ${p.name}?`, `Se ${p.name} for Merlin, o mal vence. Não dá pra voltar atrás.`, [
          button("Assassinar", "danger", () => { GH.closeOverlay(); act({ type: "assassinate", id: p.id }); }),
          button("Voltar", "secondary", GH.closeOverlay)]))));
    } else if (!board() && v.evil) {
      out.push(big("Ajude o Assassino", MAL, `Do mal: ${names(evilIds)}. Quem vocês acham que é Merlin?`));
    } else {
      out.push(big("O bem venceu 3 missões!", BEM, "Mas o Assassino ainda pode adivinhar quem é Merlin. Os maus estão conversando..."));
    }
    return out;
  }

  function gameOver() {
    const g = v.winner === "bem";
    return [big(`O ${g ? "bem" : "mal"} venceu!`, g ? BEM : MAL, REASONS[v.win_reason] || ""), track(),
      card(null, h("p.sub", "Quem era quem"), v.players.map((p) => {
        const r = v.all_roles[p.id] || "";
        return player(p.name, good(r) ? BEM : MAL, true, (ROLES[r] || [r])[0] + (p.id === v.assassin_target ? " · alvo do Assassino" : ""));
      })),
      h("p.caption", "Se o host quiser, a próxima começa daqui."), button("Sair", "secondary", GH.confirmLeave)];
  }

  const PHASES = { lobby, reveal, team, vote, vote_result: voteResult, quest, quest_result: questResult, lady, assassin, game_over: gameOver };

  function render() {
    const col = h("div.col" + (board() ? ".av-board" : ""), (PHASES[v.phase] || lobby)());
    mount(col);
    tickTimer();
  }

  function tickTimer() {
    if (!timerEl || !document.body.contains(timerEl)) return;
    const s = Math.ceil(timerMs / 1000);
    timerEl.textContent = s <= 0 ? "Tempo esgotado! Líder, feche o time." : `Discussão: ${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
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
        case "player_connection": toast(`${e.name} ${e.connected ? "voltou" : "caiu da rede: o jogo espera"}`); break;
        case "vote_result": sound(e.approved ? "hit" : "skip"); vibrate(40); break;
        case "quest_result": sound(e.ok ? "round" : "buzzer"); vibrate(e.ok ? 40 : 300); break;
        case "phase":
          if (e.phase === "team" && isLeader()) { sound("hg_turn"); vibrate([40, 70, 40]); }
          else if (e.phase === "vote" || e.phase === "quest") sound("pop");
          break;
        case "game_over": sound("win"); break;
      }
    }
  }

  GH.games.avalon = {
    onMessage,
    render(view, evs) {
      v = view;
      // O QR de "Trocar aparelho" fecha sozinho quando a pessoa entra no aparelho novo.
      if (swapSeat && !swapWasOn && byId(swapSeat).connected) {
        toast(`${nameOf(swapSeat)} entrou no aparelho novo.`, "green");
        swapSeat = "";
        GH.closeOverlay();
      }
      if (view.phase !== lastPhase) {
        hidden = !lastPhase && !!st.vaga;
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
