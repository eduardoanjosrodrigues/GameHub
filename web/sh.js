// Secret Hitler no navegador: jogador e tabuleiro (games/secret_hitler/screens/sh_game.gd).
"use strict";

(() => {
  const { h, button, card, player, mount, toast, sound, vibrate, act, st } = GH;
  const COLORS = ["#2B59C3", "#C8392B", "#2F7D5B", "#E0A21F", "#6E3B93", "#1E7F86", "#D9772B", "#C4467A"];
  const LIB = "var(--azul)";
  const FAS = "var(--vermelho)";
  const ROLES = {
    liberal: ["Liberal", "Você não sabe quem é quem. Aprove 5 leis liberais ou descubra e execute o Hitler."],
    fascista: ["Fascista", "Você conhece seus parceiros e sabe quem é o Hitler. Aprove 6 leis fascistas ou, depois de 3, coloque o Hitler como chanceler. Sem se entregar."],
    hitler: ["Hitler", "Seu time é o fascista. Pareça liberal, ganhe a confiança da mesa e, depois de 3 leis fascistas, seja eleito chanceler."],
  };
  const VARIANTS = { liberal: 4, fascista: 3, hitler: 1 };
  const POWER = {
    investigate: ["Investigar", "O presidente vê, só no celular dele, o partido de alguém."],
    peek: ["Espiar o baralho", "O presidente vê, só no celular dele, as 3 leis do topo do baralho."],
    special_election: ["Eleição especial", "O presidente escolhe quem é o próximo candidato a presidente."],
    execution: ["Execução", "O presidente executa alguém. Se for o Hitler, os liberais vencem."],
  };
  const SHORT = { investigate: "Investigar", peek: "Espiar", special_election: "Eleição", execution: "Execução" };
  const REASONS = {
    liberal_policies: "5 leis liberais aprovadas.",
    hitler_executed: "O Hitler foi executado!",
    fascist_policies: "6 leis fascistas aprovadas.",
    hitler_chancellor: "O Hitler foi eleito chanceler!",
  };
  // Fases em que só o governo age: todo mundo vibra e toca igual (§4.3).
  const SECRET = ["leg_president", "leg_chancellor", "veto", "power"];

  let v = null;
  let lastPhase = "";
  // Quem assumiu a vaga pelo QR "Trocar aparelho" recebe a carta virada.
  let hidden = !!st.vaga;
  let timerMs = -1;
  let timerEl = null;

  const color = (i) => COLORS[i % COLORS.length];
  const byId = (id) => (v.players || []).find((p) => p.id === id) || { name: "?", color: 0, connected: true, alive: true };
  const nameOf = (id) => byId(id).name;
  const names = (ids) => ids.map(nameOf).join(", ");
  const board = () => st.papel === "board";
  const isPres = () => !board() && v.president === v.you;
  const isChanc = () => !board() && v.chancellor === v.you;
  const meAlive = () => !board() && v.role && v.alive;
  const canContinue = () => board() || isPres();
  const img = (file, cls, style) => h("img" + (cls ? "." + cls : ""), { src: `assets/sh_${file}.svg`, alt: "", style });
  const lawImg = (c, cls) => img(c === "L" ? "lei_liberal" : "lei_fascista", cls);

  function big(title, bg, sub) {
    return card(bg || null, h("h2.title", title), sub ? h("p.center.bold", sub) : null);
  }

  function header(text) {
    const kids = [h("h1.title.left.grow", text)];
    if (!board() && v.role && !["lobby", "reveal"].includes(v.phase)) {
      const b = button("Meu papel", "secondary", peek, null, "small");
      b.style.width = "auto";
      kids.push(b);
    }
    if (board() && v.phase !== "lobby") kids.push(button("", "secondary", swapList, "phone", "icon-btn"));
    kids.push(button("", "secondary", GH.confirmLeave, "close", "icon-btn"));
    const out = [h("div.row", kids)];
    const off = v.players.filter((p) => !p.connected);
    if (board() && v.phase !== "lobby" && off.length) out.push(button(`${names(off.map((p) => p.id))} caiu · Trocar aparelho`, "danger", swapList, "phone", "small"));
    if (!board() && v.role && !v.alive && v.phase !== "game_over") out.push(big("Você foi executado", "var(--papel)", "Não vota, não pode ser indicado e não pode falar do seu papel."));
    return out;
  }

  // Placar: trilha liberal (5), fascista (6, com os poderes), marcador de eleições, baralho.
  function track() {
    const slot = (filled, kind, pw) => {
      if (filled) return h("div.sh-slot", lawImg(kind));
      const icon = pw === "win" ? "fascista" : pw;
      return h("div.sh-slot.empty." + (kind === "L" ? "lib" : "fas"),
        icon ? h("span.sh-ico", { style: { "--m": `url(assets/sh_emblema_${icon === "fascista" ? "fascista" : "poder_" + icon}.svg)` } }) : null);
    };
    const lib = [0, 1, 2, 3, 4].map((i) => h("div.sh-cell", slot(i < v.liberal, "L", ""), h("small", " ")));
    const fas = [0, 1, 2, 3, 4, 5].map((i) => {
      const pw = i < 5 ? (v.powers[i + 1] || v.powers[String(i + 1)] || "") : "win";
      return h("div.sh-cell", slot(i < v.fascist, "F", pw), h("small", i < 5 ? (SHORT[pw] || " ") : "Vitória"));
    });
    const dots = [0, 1, 2].map((k) => h("span.av-r" + (k < v.tracker ? ".sh-on" : "")));
    let gov = v.president ? `Presidente: ${nameOf(v.president)}` : "";
    if (v.chancellor && v.phase !== "nominate") gov += ` · Chanceler: ${nameOf(v.chancellor)}`;
    return h("div.sh-track",
      h("p.sh-lbl.lib", `Leis liberais ${v.liberal} de 5`), h("div.sh-row.five", lib),
      h("p.sh-lbl.fas", `Leis fascistas ${v.fascist} de 6`), h("div.sh-row", fas),
      h("p.caption", "Da 3ª em diante, o Hitler eleito chanceler vence · Na 5ª, o governo pode vetar"),
      h("div.row.sh-foot", h("small", "Eleições fracassadas"), dots, h("small.grow", { style: { textAlign: "right" } }, `Baralho ${v.deck_count} · Descarte ${v.discard_count}`)),
      gov ? h("p.caption.bold", gov) : null,
      v.not_hitler.length ? h("p.caption.bold", { style: { color: "var(--azul-e)" } }, `Não são o Hitler: ${names(v.not_hitler)}`) : null);
  }

  function playersBlock(extra) {
    return card(null, v.players.map((p) => player(p.name, color(p.color), p.connected, extra(p))));
  }

  function roleCard() {
    const r = v.role;
    const lib = r === "liberal";
    const idx = Math.max(0, v.players.findIndex((p) => p.id === v.you));
    const n = VARIANTS[r] || 1;
    const file = n > 1 ? `${r}_${idx % n + 1}` : r;
    const el = h("div.av-card" + (hidden ? ".hidden" : ""), { style: { "--side": lib ? LIB : (r === "hitler" ? "var(--tinta)" : FAS) }, onclick: () => { hidden = !hidden; render(); } });
    if (hidden) {
      el.append(h("img", { src: "assets/secret_hitler.svg", alt: "" }), h("span", "Toque pra ver seu papel"));
      return el;
    }
    const tries = [`${file}.jpg`, `${file}.png`, `${file}.webp`];
    if (file !== r) tries.push(`${r}_1.jpg`, `${r}_1.png`);
    const pic = h("img.portrait", { src: `assets/sh/${tries.shift()}`, alt: "" });
    const emb = h("span.emblem", { style: { "--m": `url(assets/sh_emblema_${r}.svg)`, background: lib ? LIB : FAS } });
    emb.style.display = "none";
    pic.onerror = () => {
      if (tries.length) pic.src = `assets/sh/${tries.shift()}`;
      else { pic.remove(); emb.style.display = ""; }
    };
    el.append(pic, emb, h("b", ROLES[r][0]));
    return el;
  }

  function roleInfo() {
    const r = v.role;
    const lib = r === "liberal";
    const head = lib ? "Você é LIBERAL" : r === "hitler" ? "Você é o HITLER (time fascista)" : "Você é FASCISTA";
    const out = [h("p.center.big.bold", { style: { color: lib ? "var(--azul-e)" : "var(--vermelho-e)", fontFamily: "Fraunces" } }, head), h("p.center", ROLES[r][1])];
    const knows = v.knows || [];
    if (r === "fascista") {
      const others = knows.filter((k) => k.tag === "fascista").map((k) => k.id);
      const hit = knows.filter((k) => k.tag === "hitler").map((k) => k.id);
      if (others.length) out.push(h("p.center.bold", `Os outros fascistas: ${names(others)}`));
      out.push(h("p.center.bold.big", { style: { color: "var(--vermelho-e)" } }, `O Hitler é: ${names(hit)}`));
    } else if (r === "hitler") {
      out.push(h("p.center.bold", knows.length ? `O fascista é: ${names(knows.map((k) => k.id))}` : "Você não sabe quem são os fascistas, mas eles sabem quem você é."));
    }
    for (const s of v.investigations || []) out.push(h("p.center.bold", `Você investigou: ${nameOf(s.id)} é ${s.party === "liberal" ? "LIBERAL" : "FASCISTA"}`));
    return card(lib ? LIB : FAS, ...out);
  }

  function peek() {
    const was = hidden;
    hidden = false;
    GH.overlay("Seu papel", "", [roleCard(), roleInfo(), button("Fechar", "", GH.closeOverlay)]);
    hidden = was;
  }

  // Escolher alguém (indicar, investigar, executar...). ok: ids que podem; why: motivo pra quem não pode.
  function choose(ok, pick, why, variant) {
    return card(null, v.players.filter((p) => p.id !== v.you && p.alive).map((p) => {
      const can = ok.includes(p.id);
      const b = button(can ? p.name : `${p.name} · ${why(p.id)}`, variant || "secondary", () => pick(p.id));
      b.disabled = !can;
      return b;
    }));
  }

  function confirmThen(title, body, yes, fn, danger) {
    GH.overlay(title, body, [button(yes, danger ? "danger" : "", () => { GH.closeOverlay(); fn(); }), button("Cancelar", "secondary", GH.closeOverlay)]);
  }

  function continueButton() {
    return canContinue() ? button("Continuar", "", () => act({ type: "continue" }), "play") : h("p.caption", `Esperando ${nameOf(v.president)} continuar...`);
  }

  // --- Trocar aparelho (net/seat_transfer.gd) ---------------------------------
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
      h("img.qr", { src: `qr.svg?d=${encodeURIComponent(url)}`, alt: "" }),
      h("p.caption", url),
      button("Voltar", "secondary", swapList)]);
  }

  // --- Fases ----------------------------------------------------------------

  function lobby() {
    const n = v.players.length;
    const f = v.fascist_count;
    const capa = h("img.av-banner", { src: "assets/sh/capa.jpg", alt: "" });
    capa.onerror = () => capa.remove();
    return [header("Sala do Secret Hitler"), capa,
      card(null, h("p.sub", `Ordem da mesa (${n})`),
        h("p.caption", { style: { textAlign: "left" } }, "A presidência passa de cima pra baixo. Quem criou a sala arruma a ordem."),
        v.players.map((p, i) => player(`${i + 1}. ${p.name}`, color(p.color), p.connected, !p.connected ? "desconectado" : (p.id === v.you ? "você" : "")))),
      card("var(--papel)", h("p.sub", "Partida"),
        n >= 5 ? h("p.caption", { style: { textAlign: "left" } }, `Com ${n}: ${n - f - 1} liberais, ${f} fascista${f === 1 ? "" : "s"} e o Hitler.`) : null,
        h("p.caption", { style: { textAlign: "left" } }, `Cronômetro: ${v.config.timer_min > 0 ? v.config.timer_min + " min" : "desligado"}`)),
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

  function nominate() {
    timerEl = v.timer_left_ms >= 0 ? h("p.center.bold.big", { style: { color: "var(--vermelho-e)", fontFamily: "Fraunces" } }) : null;
    const out = [header("Eleição"), track(), timerEl];
    if (isPres()) {
      out.push(big("Você é o candidato a presidente", "var(--mostarda)", "Indique quem vai ser o chanceler."),
        choose(v.eligible, (id) => confirmThen(`Indicar ${nameOf(id)}?`, `${nameOf(id)} vai ser o candidato a chanceler. Todo mundo vota o governo.`, "Indicar", () => act({ type: "nominate", id })),
          (id) => id === v.last_chancellor ? "último chanceler" : "último presidente"));
      return out;
    }
    const blocked = [v.last_president, v.last_chancellor].filter((x) => x);
    out.push(big(`${nameOf(v.president)} é o candidato a presidente`, null, "Escolhendo quem vai ser o chanceler..."),
      blocked.length ? h("p.caption", `Não podem ser chanceler agora (último governo eleito): ${names(blocked)}`) : null,
      h("p.caption", "Conversem! Em quem vocês confiam?"));
    return out;
  }

  function ballot(ja) {
    const fire = () => { vibrate(20); act({ type: "vote", ja }); };
    return h("div.av-choice", { onclick: fire }, img(ja ? "voto_ja" : "voto_nein"),
      h("span.btn." + (ja ? "success" : "vermelho"), ja ? "Ja!" : "Nein"), h("small.caption", ja ? "sim" : "não"));
  }

  function vote() {
    const out = [header("Votação"), track(), big(`Presidente ${nameOf(v.president)} · Chanceler ${nameOf(v.chancellor)}`, null, "Vocês aprovam esse governo?")];
    if (meAlive()) {
      if (v.my_vote === null || v.my_vote === undefined) {
        out.push(h("div.grid2", ballot(true), ballot(false)), h("p.caption", "Os votos aparecem todos juntos, com o nome de cada um, quando o último votar."));
      } else out.push(big(`Você votou: ${v.my_vote ? "Ja!" : "Nein"}`, v.my_vote ? "var(--salvia)" : FAS));
    }
    out.push(playersBlock((p) => !p.alive ? "executado" : v.voted.includes(p.id) ? "votou ✓" : "pensando..."));
    return out;
  }

  function voteResult() {
    const hist = v.history[v.history.length - 1] || {};
    const yes = Object.values(v.last_votes).filter((x) => x).length;
    let sub = `${yes} Ja, ${Object.keys(v.last_votes).length - yes} Nein`;
    if (!hist.elected) {
      sub += `. A presidência passa. Eleições fracassadas: ${v.tracker} de 3.`;
      if (v.tracker >= 3) sub += " Caos: a lei do topo entra direto!";
    } else if (v.not_hitler.includes(v.chancellor)) sub += `. ${nameOf(v.chancellor)} não é o Hitler.`;
    return [header("Resultado do voto"), track(),
      big(hist.elected ? "Governo eleito!" : "Governo recusado", hist.elected ? "var(--salvia)" : FAS, sub),
      card(null, v.players.filter((p) => p.id in v.last_votes).map((p) => h("div.player",
        h("div.avatar", { style: { background: color(p.color) } }, p.name.charAt(0).toUpperCase()),
        h("div.name", p.name), img(v.last_votes[p.id] ? "voto_ja" : "voto_nein", null, { width: board() ? "56px" : "40px" })))),
      continueButton()];
  }

  function lawChoice(hand, pick) {
    return [h("div.sh-hand", hand.map((c, i) => h("div.av-choice", { onclick: () => pick(i) }, lawImg(c),
      h("b", { style: { color: c === "L" ? "var(--azul-e)" : "var(--vermelho-e)" } }, c === "L" ? "Liberal" : "Fascista")))),
      h("p.caption", "Toque na lei.")];
  }

  function legislative() {
    const out = [header("Sessão legislativa"), track()];
    const hand = v.hand || [];
    if (v.phase === "leg_president" && isPres() && hand.length) {
      out.push(big("Descarte uma lei", "var(--mostarda)", "As outras duas vão pro chanceler. Ninguém mais vê."),
        ...lawChoice(hand, (i) => confirmThen("Descartar esta lei?", `A lei ${hand[i] === "L" ? "liberal" : "fascista"} vai pro descarte, sem ninguém ver.`, "Descartar", () => act({ type: "discard", index: i }))));
      return out;
    }
    if (v.phase === "leg_chancellor" && isChanc() && hand.length) {
      out.push(big("Aprove uma lei", "var(--mostarda)", "A outra vai pro descarte, sem ninguém ver."),
        ...lawChoice(hand, (i) => confirmThen("Aprovar esta lei?", `A lei ${hand[i] === "L" ? "liberal" : "fascista"} vai ser aprovada. Todo mundo vê.`, "Aprovar", () => act({ type: "enact", index: i }))));
      if (v.veto_unlocked && !v.veto_refused) out.push(button("Pedir veto das duas", "danger", () => confirmThen("Pedir veto?", "Se o presidente aceitar, as duas leis vão pro descarte e o marcador de eleições sobe.", "Pedir veto", () => act({ type: "veto" }), true), "close"));
      else if (v.veto_refused) out.push(h("p.caption", "O presidente recusou o veto: aprove uma das duas."));
      return out;
    }
    if (v.phase === "veto") {
      if (isPres()) {
        out.push(big("O chanceler pediu veto", "var(--mostarda)", "Aceitar descarta as duas leis e sobe o marcador de eleições."),
          h("div.grid2", button("Aceitar o veto", "danger", () => act({ type: "veto_answer", accept: true })), button("Recusar", "", () => act({ type: "veto_answer", accept: false }))));
      } else out.push(big("O chanceler pediu veto", null, `Esperando ${nameOf(v.president)} responder...`));
      return out;
    }
    // Quem espera: a mesma tela pra todo mundo (§4.3).
    out.push(big("O governo está decidindo a lei", null, `Presidente ${nameOf(v.president)} · Chanceler ${nameOf(v.chancellor)}`),
      h("div.sh-hand.backs", [0, 1, 2].map(() => img("verso_lei"))),
      h("p.caption", "Sem conversa agora: quem está com as leis não pode falar delas até a lei sair."));
    return out;
  }

  function policy() {
    const lp = v.last_policy || {};
    const out = [header("Nova lei")];
    if (lp.vetoed) out.push(big("Veto aceito", "var(--papel)", `Nenhuma lei entrou. Eleições fracassadas: ${v.tracker} de 3.`));
    else {
      const lib = lp.policy === "L";
      out.push(big(`Lei ${lib ? "liberal" : "fascista"} aprovada`, lib ? LIB : FAS, lp.chaos ? "Caos: 3 eleições fracassadas, a lei do topo entrou direto, sem poder." : ""),
        h("div.sh-hand", lawImg(lp.policy, "sh-new")));
    }
    if (v.power) out.push(big(`Poder do presidente: ${POWER[v.power][0]}`, "var(--mostarda)", POWER[v.power][1]));
    out.push(track(), continueButton());
    return out;
  }

  function power() {
    const [pname, pinfo] = POWER[v.power] || [v.power, ""];
    const out = [header(pname), track()];
    if (!isPres()) {
      out.push(big(`${nameOf(v.president)} está usando o poder`, null, `${pname}: ${pinfo}`));
      return out;
    }
    const alive = v.players.filter((p) => p.alive && p.id !== v.you).map((p) => p.id);
    switch (v.power) {
      case "peek":
        out.push(big("As 3 leis do topo", "var(--mostarda)", "Da de cima pra de baixo. Só você vê. Conte (ou minta) o que quiser."),
          h("div.sh-hand", (v.peek || []).map((c) => lawImg(c))), button("Visto", "", () => act({ type: "power" }), "check"));
        break;
      case "investigate":
        out.push(big("Investigue alguém", "var(--mostarda)", "Você vê, só no seu celular, o partido da pessoa."),
          choose(alive.filter((id) => !v.investigated.includes(id)), (id) => confirmThen(`Investigar ${nameOf(id)}?`, "Só você vai ver o partido.", "Investigar", () => act({ type: "power", id })), () => "já investigado"));
        break;
      case "special_election":
        out.push(big("Eleição especial", "var(--mostarda)", "Escolha quem vai ser o próximo candidato a presidente. Depois, a ordem volta ao normal."),
          choose(alive, (id) => confirmThen(`${nameOf(id)} como próximo candidato?`, "", "Escolher", () => act({ type: "power", id })), () => ""));
        break;
      case "execution":
        out.push(big("Execução", FAS, "Escolha quem vai ser executado. Se for o Hitler, os liberais vencem."),
          choose(alive, (id) => confirmThen(`Executar ${nameOf(id)}?`, "Não dá pra voltar atrás.", "Executar", () => act({ type: "power", id }), true), () => "", "danger"));
        break;
    }
    return out;
  }

  function powerResult() {
    const [pname] = POWER[v.power] || [v.power];
    const who = nameOf(v.president);
    const target = nameOf(v.power_target);
    const out = [header(pname)];
    if (v.power === "investigate") {
      if (isPres()) {
        const seen = (v.investigations || []).filter((s) => s.id === v.power_target).pop();
        const lib = seen && seen.party === "liberal";
        out.push(big(`${target} é ${lib ? "LIBERAL" : "FASCISTA"}`, lib ? LIB : FAS, "Só você vê isso. Conte (ou minta) o que quiser."),
          h("div.sh-hand", img(lib ? "partido_liberal" : "partido_fascista", "sh-new")));
      } else out.push(big(`${who} investigou ${target}`, null, `Só ${who} viu o partido.`));
    } else if (v.power === "peek") out.push(big(`${who} espiou o baralho`, null, "Viu as 3 leis do topo."));
    else if (v.power === "special_election") out.push(big("Eleição especial", null, `${who} escolheu ${target} como próximo candidato a presidente.`));
    else if (v.power === "execution") {
      if (v.power_target === v.you) out.push(big("Você foi executado", "var(--papel)", "Não conte seu papel. Você continua vendo a partida."));
      else out.push(big(`${who} executou ${target}`, FAS, `${target} não era o Hitler. O papel não é revelado.`));
    }
    out.push(track(), continueButton());
    return out;
  }

  function gameOver() {
    const lib = v.winner === "liberal";
    let n = 0;
    const lines = [];
    for (const hh of v.history) {
      if (hh.chaos) { lines.push(h("p.caption", { style: { textAlign: "left" } }, `Caos: entrou uma lei ${hh.policy === "L" ? "liberal" : "fascista"} direto do baralho.`)); continue; }
      n += 1;
      const yes = Object.values(hh.votes || {}).filter((x) => x).length;
      lines.push(h("p.bold", `${n}. ${nameOf(hh.president)} e ${nameOf(hh.chancellor)} · ${yes} Ja, ${Object.keys(hh.votes || {}).length - yes} Nein${hh.elected ? "" : " · recusado"}`));
      if (hh.drawn) {
        let d = `Presidente recebeu ${hh.drawn.join(" ")}, descartou ${hh.discarded_p || ""}`;
        if (hh.passed) d += `; chanceler recebeu ${hh.passed.join(" ")}`;
        d += hh.vetoed ? "; vetaram" : hh.policy ? `; aprovou ${hh.policy}` : "";
        lines.push(h("p.caption", { style: { textAlign: "left" } }, d));
      }
    }
    return [big(`Os ${lib ? "liberais" : "fascistas"} venceram!`, lib ? LIB : FAS, REASONS[v.win_reason] || ""), track(),
      card(null, h("p.sub", "Quem era quem"), v.players.map((p) => {
        const r = v.all_roles[p.id] || "";
        return player(p.name, r === "liberal" ? LIB : r === "hitler" ? "var(--tinta)" : FAS, true, (ROLES[r] || [r])[0] + (p.alive ? "" : " · executado"));
      })),
      card("var(--papel)", h("p.sub", "O que aconteceu"), lines.length ? lines : h("p.caption", "Nenhum governo.")),
      h("p.caption", "Se o host quiser, a próxima começa daqui."), button("Sair", "secondary", GH.confirmLeave)];
  }

  const PHASES = { lobby, reveal, nominate, vote, vote_result: voteResult, leg_president: legislative, leg_chancellor: legislative, veto: legislative,
    policy, power, power_result: powerResult, game_over: gameOver };

  function render() {
    timerEl = null;
    const col = h("div.col" + (board() ? ".av-board.sh-board" : ""), (PHASES[v.phase] || lobby)());
    mount(col);
    tickTimer();
  }

  function tickTimer() {
    if (!timerEl || !document.body.contains(timerEl)) return;
    const s = Math.ceil(timerMs / 1000);
    timerEl.textContent = s <= 0 ? "Tempo esgotado! Presidente, indique." : `Discussão: ${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
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
        case "vote_result": sound(e.elected ? "hit" : "skip"); vibrate(40); break;
        case "policy": sound(e.policy === "L" ? "round" : "buzzer"); vibrate(40); break;
        case "not_hitler": toast(`${nameOf(e.id)} não é o Hitler.`, "green"); break;
        case "executed": sound("buzzer"); vibrate(300); break;
        case "phase":
          if (SECRET.includes(e.phase)) { sound("pop"); vibrate(20); }
          else if (e.phase === "nominate" && isPres()) { sound("hg_turn"); vibrate([40, 70, 40]); }
          else if (e.phase === "vote") sound("pop");
          break;
        case "game_over": sound("win"); break;
      }
    }
  }

  GH.games.secret_hitler = {
    onMessage,
    render(view, evs) {
      v = view;
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
