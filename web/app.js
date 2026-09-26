// gamehub no navegador: núcleo comum (conexão com o host, entrar na sala, sons, avisos).
// A página é servida pelo próprio celular do host (net/web_gateway.gd). Cada jogo registra um
// módulo em GH.games[jogo] com render(view, events) e, se quiser, onMessage(msg).
"use strict";

const GH = (() => {
  const RECONNECT_MS = 2000;
  const RECONNECT_FOR_MS = 60000;
  const FATAL = ["versao", "partida_em_andamento", "cheia", "invalido", "outro_jogo", "vaga_passada", "vaga_invalida"];

  const st = {
    cfg: {}, ws: null, you: "", view: null, welcomed: false, ended: false,
    reconnecting: false, reconnectStart: 0, device: "", name: "", papel: "player",
  };
  const games = {};

  // --- Elementos ------------------------------------------------------------

  // h("div.card.tinted", {onclick}, filhos...)
  function h(spec, attrs, ...kids) {
    const [tag, ...classes] = spec.split(".");
    const el = document.createElement(tag || "div");
    if (classes.length) el.className = classes.join(" ");
    if (attrs && (typeof attrs !== "object" || attrs instanceof Node || Array.isArray(attrs))) {
      kids.unshift(attrs);
      attrs = null;
    }
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === undefined || v === null || v === false) continue;
      if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
      else if (k === "style" && typeof v === "object") {
        // Variáveis CSS (--x) só entram com setProperty.
        for (const [sk, sv] of Object.entries(v)) {
          if (sk.startsWith("--")) el.style.setProperty(sk, sv);
          else el.style[sk] = sv;
        }
      }
      else if (k === "html") el.innerHTML = v;
      else el.setAttribute(k, v === true ? "" : v);
    }
    for (const kid of kids.flat(Infinity)) {
      if (kid === null || kid === undefined || kid === false) continue;
      el.append(kid instanceof Node ? kid : document.createTextNode(String(kid)));
    }
    return el;
  }

  function icon(name) {
    return h("span.ico", { style: { "--m": `url(assets/icon_${name}.svg)` } });
  }

  // Botão. variant: "" (tinta), secondary, success, danger, accent, azul, vermelho; extra: huge/small.
  function button(text, variant, onclick, iconName, extra) {
    const b = h(`button.btn${variant ? "." + variant : ""}${extra ? "." + extra : ""}`, { onclick: (e) => { sound("tap"); onclick && onclick(e); } });
    if (iconName) b.append(icon(iconName));
    if (text) b.append(text);
    return b;
  }

  function card(color, ...kids) {
    const c = h("div.card" + (color ? ".tinted" : ""), ...kids);
    if (color) {
      c.style.background = `color-mix(in srgb, var(--superficie) 86%, ${color})`;
      c.style.borderColor = `color-mix(in srgb, var(--superficie) 65%, ${color})`;
    }
    return c;
  }

  function player(name, color, connected = true, extra = "") {
    return h("div.player",
      h("div.avatar" + (connected ? "" : ".off"), { style: { background: color } }, (name || "?").trim().charAt(0).toUpperCase()),
      h("div.name", name), extra ? h("div.extra", extra) : null);
  }

  // Troca o conteúdo da página, guardando o que já foi digitado nos campos com data-keep.
  function mount(...nodes) {
    const app = document.getElementById("app");
    const kept = {};
    let focus = null;
    app.querySelectorAll("input[data-keep]").forEach((i) => {
      kept[i.dataset.keep] = i.value;
      if (document.activeElement === i) focus = i.dataset.keep;
    });
    const scroll = window.scrollY;
    app.replaceChildren(...nodes.flat());
    app.querySelectorAll("input[data-keep]").forEach((i) => {
      if (kept[i.dataset.keep] !== undefined) i.value = kept[i.dataset.keep];
      if (focus === i.dataset.keep) i.focus();
    });
    window.scrollTo(0, scroll);
  }

  function toast(text, kind) {
    const t = h("div.toast" + (kind ? "." + kind : ""), text);
    document.getElementById("toasts").append(t);
    setTimeout(() => t.remove(), 2900);
  }

  let shadeEl = null;
  function overlay(title, body, buttons = []) {
    closeOverlay();
    shadeEl = h("div.shade", h("div.card", h("h2.title", title), body ? h("p.caption", body) : null, ...buttons));
    document.body.append(shadeEl);
  }
  function closeOverlay() {
    if (shadeEl) shadeEl.remove();
    shadeEl = null;
  }

  // --- Som e vibração -------------------------------------------------------

  let audio = null;
  const buffers = {};
  function unlockAudio() {
    if (audio) return;
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    audio = new Ctx();
    // iPhone: o som só é liberado dentro de um toque; um som vazio destrava.
    const b = audio.createBuffer(1, 1, 22050);
    const s = audio.createBufferSource();
    s.buffer = b;
    s.connect(audio.destination);
    s.start(0);
  }
  function loadSound(name) {
    if (!audio) return Promise.resolve(null);
    if (!buffers[name]) {
      buffers[name] = fetch(`assets/${name}.wav`).then((r) => r.arrayBuffer())
        .then((a) => new Promise((ok) => audio.decodeAudioData(a, ok, () => ok(null)))).catch(() => null);
    }
    return buffers[name];
  }
  function sound(name, rate = 1) {
    if (!audio) return;
    if (audio.state === "suspended") audio.resume();
    loadSound(name).then((buf) => {
      if (!buf) return;
      const s = audio.createBufferSource();
      s.buffer = buf;
      s.playbackRate.value = rate;
      const g = audio.createGain();
      g.gain.value = 0.8;
      s.connect(g).connect(audio.destination);
      s.start(0);
    });
  }
  function preload(names) {
    names.forEach(loadSound);
  }
  // Vibra onde o navegador deixa (Android). O Safari do iPhone não vibra.
  function vibrate(pattern) {
    if (navigator.vibrate) navigator.vibrate(pattern);
  }

  // Tela ligada durante a partida (onde o navegador tiver Wake Lock).
  let wake = null;
  async function keepAwake(on) {
    try {
      if (on && !wake && navigator.wakeLock) {
        wake = await navigator.wakeLock.request("screen");
        wake.addEventListener("release", () => { wake = null; });
      } else if (!on && wake) {
        await wake.release();
        wake = null;
      }
    } catch (e) { /* sem permissão: segue sem */ }
  }
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible" && st.view && st.view.phase !== "lobby") keepAwake(true);
  });

  // --- Conexão --------------------------------------------------------------

  function newId() {
    const a = new Uint8Array(12);
    (window.crypto || window.msCrypto).getRandomValues(a);
    return Array.from(a, (b) => b.toString(16).padStart(2, "0")).join("");
  }

  function store(k, v) {
    try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; }
  }

  function send(msg) {
    if (!st.ws || st.ws.readyState !== 1) return false;
    msg.v = st.cfg.v;
    st.ws.send(JSON.stringify(msg));
    return true;
  }

  function act(action) {
    if (st.reconnecting) {
      toast("Reconectando ao host...", "red");
      return;
    }
    send({ type: "acao", action });
  }

  function connect() {
    const ws = new WebSocket(`ws://${location.hostname}:${st.cfg.ws_port || 7781}/`);
    st.ws = ws;
    ws.onopen = () => {
      // O tabuleiro tem id próprio: no mesmo navegador pode ter um jogador e um tabuleiro. Quem
      // entra pelo QR "Trocar aparelho" também (dá pra assumir a vaga até num celular que já joga).
      const device = st.vaga ? `${st.device}-v-${st.vaga}` : st.papel === "board" ? st.device + "-mesa" : st.device;
      send({ type: "hello", jogo: st.cfg.jogo, device, nome: st.name, papel: st.papel, vaga: st.vaga || "" });
      game().onOpen && game().onOpen();
    };
    ws.onmessage = (e) => {
      let msg;
      try { msg = JSON.parse(e.data); } catch (err) { return; }
      onMessage(msg);
    };
    ws.onclose = () => {
      if (st.ws !== ws || st.ended) return;
      if (!st.welcomed && !st.reconnecting) {
        showEnded("Não consegui entrar na sala. Confira se você está no mesmo Wi-Fi do host.");
        return;
      }
      if (!st.reconnecting) {
        st.reconnecting = true;
        st.reconnectStart = Date.now();
        overlay("Reconectando...", "Não feche esta página. Se a rede voltar, você volta pro mesmo lugar.");
      }
      if (Date.now() - st.reconnectStart > RECONNECT_FOR_MS) {
        showEnded("Não deu pra reconectar ao host.");
        return;
      }
      setTimeout(connect, RECONNECT_MS);
    };
  }

  function onMessage(msg) {
    switch (msg.type) {
      case "bem_vindo":
        st.welcomed = true;
        st.you = msg.id || "";
        try {
          sessionStorage.setItem("gh_room", st.cfg.codigo);
          sessionStorage.setItem("gh_papel", st.papel);
        } catch (e) { /* sem sessionStorage */ }
        if (st.reconnecting) {
          st.reconnecting = false;
          closeOverlay();
          toast("Reconectado!", "green");
        }
        break;
      case "estado":
        st.view = msg.view;
        game().render(msg.view, msg.events || []);
        break;
      case "erro":
        if (FATAL.includes(msg.codigo)) showEnded(msg.mensagem || "Não deu pra entrar.");
        else if (msg.codigo === "acao") game().onRejected ? game().onRejected(msg.mensagem) : toast(msg.mensagem, "red");
        else toast(msg.mensagem || "Erro.", "red");
        break;
      default:
        game().onMessage && game().onMessage(msg);
    }
  }

  function game() {
    return games[st.cfg.jogo] || { render() {} };
  }

  function showEnded(reason) {
    st.ended = true;
    closeOverlay();
    keepAwake(false);
    if (st.ws) st.ws.close();
    try { sessionStorage.removeItem("gh_room"); } catch (e) { /* sem sessionStorage */ }
    mount(h("div.col", logo(), card(null, h("h2.title", "Fim da conexão"), h("p.caption", reason)),
      button("Entrar de novo", "", () => location.reload(), "enter")));
  }

  // Sair da sala de propósito (não volta sozinho ao recarregar).
  function leave() {
    showEnded("Você saiu da partida.");
  }

  function confirmLeave() {
    overlay("Sair da partida?", "Você pode entrar de novo pelo QR enquanto a sala estiver aberta.", [
      button("Sair", "danger", leave), button("Voltar", "secondary", closeOverlay)]);
  }

  // --- Entrada --------------------------------------------------------------

  function logo() {
    return h("h1.logo", "game", h("span", "hub"), h("i", "."));
  }

  function join(name, papel = "player") {
    st.papel = papel;
    name = (name || "").trim().replace(/\s+/g, " ").slice(0, 20);
    if (!name && papel === "board") name = "Tabuleiro";
    if (!name) {
      toast("Digite seu nome", "red");
      return;
    }
    unlockAudio();
    st.name = name;
    if (papel !== "board") store("gh_name", name);
    mount(h("div.col", logo(), card(null, h("h2.title", "Entrando..."), h("p.caption", st.cfg.sala || "Conectando à sala"))));
    connect();
  }

  function showJoin() {
    const g = GH.meta[st.cfg.jogo] || { nome: "gamehub", icone: "halli_galli" };
    const input = h("input.field", { placeholder: "Como te chamam?", maxlength: 20, value: store("gh_name") || "", "data-keep": "nome",
      onkeydown: (e) => { if (e.key === "Enter") join(input.value); } });
    const android = /Android/i.test(navigator.userAgent);
    mount(h("div.col",
      logo(),
      card(null,
        h("img", { src: `assets/${g.icone}.svg`, style: { width: "150px", height: "150px", margin: "0 auto" }, alt: "" }),
        h("h2.title", g.nome),
        h("p.caption", st.cfg.sala || ""),
        h("p.sub", "Seu nome"), input,
        button("Entrar na sala", "success", () => join(input.value), "enter"),
        GH.boardGames.includes(st.cfg.jogo) ? button("Sou o tabuleiro (TV ou notebook)", "secondary", () => join("Tabuleiro", "board"), null, "small") : null),
      android ? card(st.cfg.jogo ? "var(--mostarda)" : null,
        h("p.bold", "Tem o app gamehub no celular?"),
        h("p", "Jogar pelo app é melhor: vibra, fica em tela cheia e o toque é mais preciso."),
        h("a", { href: `gamehub://entrar?c=${encodeURIComponent(st.cfg.codigo || "")}`, style: { textDecoration: "none" } },
          h("span.btn", "Abrir no app"))) : null,
      h("p.caption", "Mantenha esta página aberta durante a partida.")));
  }

  async function boot() {
    st.device = store("gh_device") || newId();
    store("gh_device", st.device);
    document.addEventListener("pointerdown", unlockAudio, { once: false, passive: true });
    try {
      st.cfg = await (await fetch("config.json", { cache: "no-store" })).json();
    } catch (e) {
      mount(h("div.col", logo(), card(null, h("h2.title", "Sala fechada"), h("p.caption", "Essa sala não está mais aberta. Peça o QR de novo pra quem criou."))));
      return;
    }
    document.title = (GH.meta[st.cfg.jogo] || {}).nome || "gamehub";
    // QR "Trocar aparelho": entra direto na vaga de alguém que já está na partida.
    st.vaga = new URLSearchParams(location.search).get("v") || "";
    if (st.vaga) {
      st.papel = "player";
      st.name = "";
      mount(h("div.col", logo(), card(null, h("h2.title", "Assumindo a vaga..."), h("p.caption", st.cfg.sala || "Conectando à sala"))));
      unlockAudio();
      connect();
      return;
    }
    // Recarregou a página no meio da partida: volta direto, com o mesmo nome.
    let again = false;
    try { again = sessionStorage.getItem("gh_room") === st.cfg.codigo; } catch (e) { /* sem sessionStorage */ }
    let papel = "player";
    try { papel = sessionStorage.getItem("gh_papel") || "player"; } catch (e) { /* sem sessionStorage */ }
    if (again && (store("gh_name") || papel === "board")) join(store("gh_name") || "Tabuleiro", papel);
    else showJoin();
  }

  return {
    st, games, h, icon, button, card, player, mount, toast, overlay, closeOverlay,
    sound, preload, vibrate, keepAwake, send, act, boot, logo, leave, confirmLeave,
    meta: { chapeu: { nome: "Chapéu", icone: "chapeu" }, halli: { nome: "Halli Galli", icone: "halli_galli" }, avalon: { nome: "Avalon", icone: "avalon" },
      secret_hitler: { nome: "Secret Hitler", icone: "secret_hitler" }, sintonia: { nome: "Sintonia", icone: "sintonia" }, ito: { nome: "Ito", icone: "ito" },
      quem_foi: { nome: "Quem Foi?", icone: "quem_foi" } },
    boardGames: ["avalon", "secret_hitler", "sintonia", "ito", "quem_foi"],
  };
})();
