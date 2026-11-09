// Skald Reader: the diary of a character read as a book, in the browser. Everything stays on this page.
// Input: the parts of the text that "/skald reader" makes in the game (see BuildReader in Skald.lua).
(function () {
  'use strict';

  // ---- words of the page, by language of the diary --------------------------------------------------------------
  var T = {
    enUS: {
      title: 'Skald Reader',
      intro: 'Read your World of Warcraft diary as a book, outside the game.',
      steps: ['In the game, type /skald reader.', 'Copy each part of the text (click it, Ctrl+A, Ctrl+C).', 'Paste it below. You can paste the parts one after the other.'],
      label: 'Paste the text of the diary here', open: 'Open the book', clear: 'Clear', back: 'Paste again', print: 'Save as PDF', sound: 'Page-turn sound', turnBack: 'Previous page', turnOn: 'Next page',
      privacy: 'Nothing leaves this page: the text is read by your browser and is not sent anywhere.',
      part: 'Part %1 of %2', partBad: 'Part %1: incomplete copy', waiting: 'waiting for part %1',
      ready: 'All parts are here. You can open the book.', mixed: 'These parts are from different diaries. Clear and paste again.',
      empty: 'Paste the text from the game.', diaryOf: 'Diary of %1', level: 'level %1 %2', story: 'The story so far', saga: 'The Saga', days: 'Days', index: 'Index',
      day: 'Day %1', page: 'Page %1 of %2', pages: 'Pages %1–%2 of %3', cover: 'Cover', first: 'First page written', played: 'Time on the road', goals: 'Goals reached', points: 'Goal points',
      stat: { quest: 'Quests completed', level: 'Levels earned', death: 'Times I fell', dungeon: 'Dungeons visited', boss: 'Bosses defeated', kill: 'Creatures defeated' },
      date: function (d) { return d.toLocaleDateString('en-US'); }, hours: '%1h %2min', minutes: '%1min', tier: ['Trivial', 'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary'],
      truncated: 'The diary has more pages than the ones pasted.',
      tip: { level: 'Level %1', giver: 'Given by %1', falls: 'After %1 falls', stack: '%1 made', open: 'Click to look it up on Wowhead' }
    },
    ptBR: {
      title: 'Skald Leitor',
      intro: 'Leia o diário do seu personagem de World of Warcraft como um livro, fora do jogo.',
      steps: ['No jogo, digite /skald reader.', 'Copie cada parte do texto (clique nele, Ctrl+A, Ctrl+C).', 'Cole aqui embaixo. Pode colar as partes uma depois da outra.'],
      label: 'Cole aqui o texto do diário', open: 'Abrir o livro', clear: 'Limpar', back: 'Colar de novo', print: 'Salvar como PDF', sound: 'Som de virar a página', turnBack: 'Página anterior', turnOn: 'Próxima página',
      privacy: 'Nada sai desta página: o texto é lido pelo seu navegador e não é enviado a lugar nenhum.',
      part: 'Parte %1 de %2', partBad: 'Parte %1: cópia incompleta', waiting: 'falta a parte %1',
      ready: 'Todas as partes chegaram. Pode abrir o livro.', mixed: 'Essas partes são de diários diferentes. Limpe e cole de novo.',
      empty: 'Cole o texto que veio do jogo.', diaryOf: 'Diário de %1', level: 'nível %1 %2', story: 'A história até aqui', saga: 'A Saga', days: 'Dias', index: 'Índice',
      day: 'Dia %1', page: 'Página %1 de %2', pages: 'Páginas %1–%2 de %3', cover: 'Capa', first: 'Primeira página escrita', played: 'Tempo na estrada', goals: 'Metas cumpridas', points: 'Pontos de metas',
      stat: { quest: 'Missões cumpridas', level: 'Níveis conquistados', death: 'Vezes que caí', dungeon: 'Masmorras visitadas', boss: 'Chefes derrotados', kill: 'Criaturas vencidas' },
      date: function (d) { return d.toLocaleDateString('pt-BR'); }, hours: '%1h %2min', minutes: '%1min', tier: ['Trivial', 'Comum', 'Incomum', 'Rara', 'Épica', 'Lendária'],
      truncated: 'O diário tem mais páginas do que as coladas.',
      tip: { level: 'Nível %1', giver: 'Dada por %1', falls: 'Depois de %1 quedas', stack: '%1 feitos', open: 'Clique para procurar no Wowhead' }
    },
    frFR: {
      title: 'Lecteur Skald',
      intro: 'Lisez le journal de votre personnage de World of Warcraft comme un livre, hors du jeu.',
      steps: ['Dans le jeu, tapez /skald reader.', 'Copiez chaque partie du texte (clic, Ctrl+A, Ctrl+C).', 'Collez-la ci-dessous. Vous pouvez coller les parties l’une après l’autre.'],
      label: 'Collez ici le texte du journal', open: 'Ouvrir le livre', clear: 'Effacer', back: 'Coller à nouveau', print: 'Enregistrer en PDF', sound: 'Son des pages', turnBack: 'Page précédente', turnOn: 'Page suivante',
      privacy: 'Rien ne quitte cette page : le texte est lu par votre navigateur et n’est envoyé nulle part.',
      part: 'Partie %1 sur %2', partBad: 'Partie %1 : copie incomplète', waiting: 'partie %1 manquante',
      ready: 'Toutes les parties sont là. Vous pouvez ouvrir le livre.', mixed: 'Ces parties viennent de journaux différents. Effacez et recollez.',
      empty: 'Collez le texte venu du jeu.', diaryOf: 'Journal de %1', level: 'niveau %1 %2', story: 'L’histoire jusqu’ici', saga: 'La Saga', days: 'Jours', index: 'Index',
      day: 'Jour %1', page: 'Page %1 sur %2', pages: 'Pages %1–%2 sur %3', cover: 'Couverture', first: 'Première page écrite', played: 'Temps sur la route', goals: 'Objectifs atteints', points: 'Points d\'objectifs',
      stat: { quest: 'Quêtes accomplies', level: 'Niveaux gagnés', death: 'Fois où je suis tombé', dungeon: 'Donjons visités', boss: 'Boss vaincus', kill: 'Créatures vaincues' },
      date: function (d) { return d.toLocaleDateString('fr-FR'); }, hours: '%1 h %2 min', minutes: '%1 min', tier: ['Trivial', 'Commun', 'Peu commun', 'Rare', 'Épique', 'Légendaire'],
      truncated: 'Le journal compte plus de pages que celles collées.',
      tip: { level: 'Niveau %1', giver: 'Donnée par %1', falls: 'Après %1 chutes', stack: '%1 fabriqués', open: 'Cliquez pour chercher sur Wowhead' }
    }
  };
  T.esES = {
    title: 'Skald Lector',
    intro: 'Lee el diario de tu personaje de World of Warcraft como un libro, fuera del juego.',
    steps: ['En el juego, escribe /skald reader.', 'Copia cada parte del texto (clic, Ctrl+A, Ctrl+C).', 'Pégala aquí. Puedes pegar las partes una tras otra.'],
    label: 'Pega aquí el texto del diario', language: 'Idioma', jumpLabel: 'Día', open: 'Abrir el libro', clear: 'Borrar', back: 'Volver a pegar', print: 'Guardar como PDF', sound: 'Sonido al pasar página', turnBack: 'Página anterior', turnOn: 'Página siguiente',
    privacy: 'Nada sale de esta página: tu navegador lee el texto sin enviarlo a ningún sitio.',
    part: 'Parte %1 de %2', partBad: 'Parte %1: copia incompleta', waiting: 'falta la parte %1',
    ready: 'Ya están todas las partes. Puedes abrir el libro.', mixed: 'Estas partes pertenecen a diarios distintos. Borra el texto y vuelve a pegarlo.',
    empty: 'Pega el texto que has copiado del juego.', diaryOf: 'Diario de %1', level: 'nivel %1 %2', story: 'La historia hasta hoy', saga: 'La Saga', days: 'Días', index: 'Índice',
    day: 'Día %1', page: 'Página %1 de %2', pages: 'Páginas %1–%2 de %3', cover: 'Portada', first: 'Primera página escrita', played: 'Tiempo de camino', goals: 'Metas alcanzadas', points: 'Puntos de metas',
    stat: { quest: 'Misiones completadas', level: 'Niveles ganados', death: 'Veces que caí', dungeon: 'Mazmorras visitadas', boss: 'Jefes derrotados', kill: 'Criaturas vencidas' },
    date: function (d) { return d.toLocaleDateString('es'); }, hours: '%1 h %2 min', minutes: '%1 min', tier: ['Trivial', 'Común', 'Poco común', 'Raro', 'Épico', 'Legendario'],
    truncated: 'El diario tiene más páginas que las que has pegado.',
    tip: { level: 'Nivel %1', giver: 'Encargo de %1', falls: 'Después de %1 caídas', stack: '%1 fabricados', open: 'Haz clic para buscar en Wowhead' }
  };
  T.esMX = T.esES;
  function languageKey(locale) { return locale === 'esMX' ? 'esES' : locale; }
  var lang = 'ptBR';
  function L() { return T[lang] || T.ptBR; }
  function fmt(s) { var a = arguments; return String(s).replace(/%(\d)/g, function (_, n) { return a[+n] !== undefined ? a[+n] : ''; }); }
  (function pickLanguage() {
    var n = (navigator.language || 'pt-BR').toLowerCase();
    lang = n.indexOf('es') === 0 ? 'esES' : n.indexOf('fr') === 0 ? 'frFR' : n.indexOf('en') === 0 ? 'enUS' : 'ptBR';
  })();

  // ---- reading the text ----------------------------------------------------------------------------------------
  function unescapeField(s) {
    return s.replace(/\\(.)/g, function (_, c) { return c === 'p' ? '^' : c === 'n' ? '\n' : c; });
  }
  // The ninth field of a page: key=value pairs joined by "~" (what the tooltip of the game shows).
  function parseInfo(s) {
    var o = {};
    if (!s) return o;
    s.split('~').forEach(function (kv) { var i = kv.indexOf('='); if (i > 0) o[kv.slice(0, i)] = kv.slice(i + 1); });
    return o;
  }
  function checksum(text) {
    var bytes = new TextEncoder().encode(text);
    var h = 5381;
    for (var i = 0; i < bytes.length; i++) h = (h * 31 + bytes[i]) >>> 0;   // the game does (h*31 + b) mod 2^32
    return h;
  }
  // Splits what was pasted into parts (each starts with its H line) and checks each one.
  function readParts(text) {
    var lines = String(text).replace(/\r\n?/g, '\n').split('\n');
    var parts = [], cur = null;
    lines.forEach(function (line) {
      if (line.indexOf('H^SKALDREADER1^') === 0) { cur = { header: line, body: [] }; parts.push(cur); }
      else if (cur) cur.body.push(line);
    });
    return parts.map(function (p) {
      var f = p.header.split('^');
      var body = p.body.join('\n').replace(/\s+$/, '');
      var headerValid = f.length >= 12 && /^\d+$/.test(f[8]) && /^\d+$/.test(f[9]) && /^\d+$/.test(f[10]) &&
        Number.isInteger(+f[11]) && +f[11] >= 0 && +f[11] <= 4294967295 && +f[10] > 0 && +f[10] <= 10000 && +f[9] > 0 && +f[9] <= +f[10];
      return {
        name: unescapeField(f[2] || ''), cls: unescapeField(f[3] || ''), race: unescapeField(f[4] || ''), level: f[5], tone: f[6], locale: f[7],
        total: +f[8], index: +f[9], count: +f[10], sum: +f[11], snapshot: f[12] || '', body: body,
        valid: headerValid && checksum(body) === +f[11]
      };
    });
  }
  function collectParts(parts) {
    if (!parts.length) return { state: 'empty', parts: [] };
    var first = parts[0], byIndex = {}, conflict = false;
    var same = parts.every(function (p) {
      return ['name', 'cls', 'race', 'level', 'tone', 'locale', 'total', 'count', 'snapshot'].every(function (k) { return p[k] === first[k]; });
    });
    if (!same) return { state: 'mixed', parts: [] };
    parts.forEach(function (p) {
      var old = byIndex[p.index];
      if (old && old.valid && p.valid && old.body !== p.body) conflict = true;
      if (!old || (p.valid && !old.valid)) byIndex[p.index] = p;
    });
    if (conflict) return { state: 'mixed', parts: [] };
    var ordered = [], complete = true;
    if (!Number.isInteger(first.count) || first.count < 1 || first.count > 10000) return { state: 'invalid', parts: [] };
    for (var i = 1; i <= first.count; i++) { ordered.push(byIndex[i]); if (!byIndex[i] || !byIndex[i].valid) complete = false; }
    return { state: complete ? 'ready' : 'incomplete', parts: ordered };
  }
  function build(parts) {
    var collected = collectParts(parts);
    if (collected.state !== 'ready') throw new Error(collected.state);
    parts = collected.parts;
    var first = parts[0];
    if (first.snapshot && checksum(parts.map(function (p) { return p.body; }).join('\n')) !== +first.snapshot) throw new Error('mixed');
    var model = { name: first.name, cls: first.cls, race: first.race, level: first.level, tone: first.tone, locale: first.locale, total: first.total,
      first: 0, played: 0, counts: {}, tiers: {}, goals: 0, points: 0, saga: [], pages: [], days: {}, prefs: {}, era: 'forever' };
    parts.forEach(function (p) {
      p.body.split('\n').forEach(function (line) {
        if (!line) return;
        var f = line.split('^').map(unescapeField);
        switch (f[0]) {
          case 'M': if (['era', 'paper', 'ink', 'textSize', 'density', 'coverTitle'].indexOf(f[1]) >= 0) model.prefs[f[1]] = f[2]; break;
          case 'D': model.days[f[1]] = { key: f[1], n: +f[2], t: +f[3], title: f[4], date: f[5] }; break;
          case 'S': model.first = +f[1]; model.played = +f[2]; break;
          case 'N': model.counts[f[1]] = +f[2]; break;
          case 'T': model.tiers[f[1]] = +f[2]; break;
          case 'V': model.saga.push({ key: f[1], title: f[2], text: f[3] || '', art: f[4] || '' }); break;
          case 'G': model.goals++; model.points += (+f[4] || 0); break;
          case 'P': model.pages.push({ t: +f[1], kind: f[2], tier: +f[3], fav: f[4] === '1', place: f[5], ic: f[6], text: f[7], note: f[8], info: parseInfo(f[9]), day: f[10] || '' }); break;
        }
      });
    });
    model.pages.sort(function (a, b) { return a.t - b.t; });
    if (model.pages.length !== model.total) throw new Error('truncated');
    if (['forever', 'tbc', 'classic'].indexOf(model.prefs.era) >= 0) model.era = model.prefs.era;
    return model;
  }

  // ---- icons -----------------------------------------------------------------------------------------------------
  var KIND_ICON = { quest: 'ev_quest', level: 'ev_level', milestone: 'ev_milestone', death: 'ev_death', boss: 'ev_boss', dungeon: 'ev_dungeon',
    zone: 'ev_zone', mount: 'ev_mount', guild: 'ev_guild', guildleave: 'ev_guild', party: 'ev_party', reunion: 'ev_party', achievement: 'ev_achievement',
    skill: 'ev_profession', profession: 'ev_profession', day: 'b_moon', mark: 'ev_milestone', home: 'st_hearth', hearth: 'st_hearth', rep: 'ev_achievement',
    flight: 'st_flight', weather: 'ev_weather', bg: 'ev_bg', tame: 'ev_pet', revive: 'ev_revive', goal: 'ev_goal', note: 'b_quill', loot: 'it_generic' };
  function iconFor(p) {
    if (p.kind === 'quest' && p.tier >= 0 && p.tier <= 5 && p.tier !== 1) return 'seal' + p.tier;
    if (p.kind === 'quest') return 'seal1';
    if (p.ic && p.ic.indexOf('loot:') === 0) return p.ic.slice(5) ? 'it_' + p.ic.slice(5) : 'it_generic';
    return KIND_ICON[p.kind] || 'ev_milestone';
  }
  function img(name, cls) {
    var i = document.createElement('img');
    i.src = 'img/' + name + '.png';
    i.alt = '';
    if (cls) i.className = cls;
    i.onerror = function () { if (!i.dataset.fallback) { i.dataset.fallback = '1'; i.src = 'img/it_generic.png'; } };
    return i;
  }

  // ---- the book --------------------------------------------------------------------------------------------------
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; }
  function pad2(n) { return (n < 10 ? '0' : '') + n; }
  function dayKey(t) { var d = new Date(t * 1000); return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate()); }
  function groupDate(group) {
    var date = group.detail && group.detail.date;
    if (date && /^\d{4}-\d{2}-\d{2}$/.test(date)) {
      var parts = date.split('-').map(Number);
      return L().date(new Date(parts[0], parts[1] - 1, parts[2]));
    }
    return L().date(new Date(group.t * 1000));
  }
  function applyPreferences(prefs) {
    var root = document.documentElement;
    root.dataset.paper = ['clean', 'travel', 'war', 'old'].indexOf(prefs.paper) >= 0 ? prefs.paper : 'clean';
    root.dataset.ink = ['0', '1', '2'].indexOf(prefs.ink) >= 0 ? prefs.ink : '0';
    root.dataset.textSize = ['0', '1', '2'].indexOf(prefs.textSize) >= 0 ? prefs.textSize : '1';
    root.dataset.density = ['compact', 'comfy', 'airy'].indexOf(prefs.density) >= 0 ? prefs.density : 'comfy';
  }
  // Prefer a word boundary when a long block continues on the next page.
  function wordBoundary(chars, start, end) {
    if (end >= chars.length || /\s/.test(chars[end])) return end;
    for (var i = end - 1, min = start + Math.floor((end - start) * .6); i > min; i--) {
      if (/\s/.test(chars[i])) return i + 1;
    }
    return end;
  }
  function duration(secs) {
    var m = Math.floor(secs / 60), h = Math.floor(m / 60);
    return h > 0 ? fmt(L().hours, h, pad2(m % 60)) : fmt(L().minutes, m);
  }

  function pageShell(model, rightSide, label) {
    var page = el('div', 'page ' + (rightSide ? 'right' : 'left'));
    var run = el('div', 'run');
    run.appendChild(el('span', '', model.name));
    run.appendChild(el('span', '', label));
    page.appendChild(run);
    return page;
  }
  // A tooltip over a page, as in the game: the name, the level, what it was about, who gave it; a click looks it up.
  var tipBox = null;
  function lookupUrl(p, era) {
    var i = p.info || {};
    var edition = era || (model && model.era) || 'forever';
    var base = 'https://www.wowhead.com/' + (['forever', 'tbc', 'classic'].indexOf(edition) >= 0 ? edition : 'forever') + '/';
    if (p.kind === 'quest' && /^\d+$/.test(i.q)) return base + 'quest=' + encodeURIComponent(i.q);
    if (p.kind === 'loot' && /^\d+$/.test(i.iid)) return base + 'item=' + encodeURIComponent(i.iid);
    return null;
  }
  function tipLines(p) {
    var i = p.info || {}, tr = L().tip, lines = [];
    if (!i.title && !i.q && !i.iid) return lines;
    lines.push({ cls: 'tip-title t' + p.tier, text: i.title || '' });
    var meta = [];
    if (i.ql) meta.push(fmt(tr.level, i.ql));
    if (p.kind === 'quest' || p.kind === 'loot') meta.push(L().tier[p.tier] || '');
    if (i.tries) meta.push(fmt(tr.falls, i.tries));
    if (i.n) meta.push(fmt(tr.stack, i.n));
    meta = meta.filter(Boolean);
    if (meta.length) lines.push({ cls: 'tip-meta', text: meta.join('  ·  ') });
    if (i.ot) lines.push({ cls: 'tip-text', text: i.ot });
    var foot = [];
    if (i.npc) foot.push(fmt(tr.giver, i.npc));
    if (p.place) foot.push(p.place);
    if (foot.length) lines.push({ cls: 'tip-foot', text: foot.join('  ·  ') });
    lines.push({ cls: 'tip-date', text: L().date(new Date(p.t * 1000)) });
    if (lookupUrl(p)) lines.push({ cls: 'tip-open', text: tr.open });
    return lines;
  }
  function attachTip(row, p) {
    var lines = tipLines(p);
    if (!lines.length) return;
    var url = lookupUrl(p);
    if (url) {
      row.classList.add('linked'); row.tabIndex = 0; row.setAttribute('role', 'link');
      row.addEventListener('click', function () { window.open(url, '_blank', 'noopener,noreferrer'); });
      row.addEventListener('keydown', function (event) { if (event.key === 'Enter') row.click(); });
    }
    row.addEventListener('mouseenter', function (ev) {
      if (!tipBox) { tipBox = el('div', 'tip'); document.body.appendChild(tipBox); }
      tipBox.textContent = '';
      lines.forEach(function (l) { tipBox.appendChild(el('div', l.cls, l.text)); });
      tipBox.style.display = 'block';
      moveTip(ev);
    });
    row.addEventListener('mousemove', moveTip);
    row.addEventListener('mouseleave', function () { if (tipBox) tipBox.style.display = 'none'; });
  }
  function moveTip(ev) {
    if (!tipBox) return;
    var w = tipBox.offsetWidth, h = tipBox.offsetHeight;
    var x = ev.clientX + 16, y = ev.clientY + 18;
    if (x + w > window.innerWidth - 8) x = ev.clientX - w - 16;
    if (y + h > window.innerHeight - 8) y = ev.clientY - h - 16;
    tipBox.style.left = Math.max(8, x) + 'px';
    tipBox.style.top = Math.max(8, y) + 'px';
  }
  function entryRow(p) {
    var row = el('div', 'entry ' + p.kind + ' t' + (p.kind === 'quest' ? p.tier : ''));
    if (p.kind === 'day') {
      row.appendChild(img(iconFor(p)));
      row.appendChild(el('div', 'body', p.text));
      return row;
    }
    row.appendChild(img(iconFor(p)));
    var d = new Date(p.t * 1000);
    row.appendChild(el('div', 'time', pad2(d.getHours()) + ':' + pad2(d.getMinutes())));
    var body = el('div', 'body');
    if (p.kind === 'quest' && p.tier >= 2) body.appendChild(el('span', 'tag', L().tier[p.tier] || ''));
    body.appendChild(document.createTextNode(p.text));
    if (p.note) body.appendChild(el('span', 'note', p.note));
    row.appendChild(body);
    row.appendChild(el('div', 'star', p.fav ? '★' : ''));
    attachTip(row, p);
    return row;
  }

  // The pages of the days: rows are put in until the page is full (measured with the real fonts), then a new page begins.
  function paginate(model, dayStart) {
    var groups = [], byKey = {};
    model.pages.forEach(function (p) {
      var k = p.day || dayKey(p.t);
      if (!byKey[k]) { byKey[k] = { key: k, t: p.t, list: [], detail: model.days[k] }; groups.push(byKey[k]); }
      byKey[k].list.push(p);
    });
    var pageH = parseInt(getComputedStyle(document.documentElement).getPropertyValue('--page-h'), 10) || 620;
    var capacity = pageH - 44;   // what is left above the number at the foot
    function newPage(cont, group, n) {
      var page = pageShell(model, false, fmt(L().day, n));
      page.appendChild(el('h2', 'small', cont ? fmt(L().day, n) + ' (…)' : (group.detail && group.detail.title) || fmt(L().day, n)));
      if (!cont) page.appendChild(el('div', 'sub', groupDate(group)));
      page.appendChild(el('span', 'rule'));
      return page;
    }
    // Batch ordinary row measurements; only unusually long entries need splitting.
    var stage = el('div');
    stage.style.cssText = 'position:absolute;left:-9999px;top:0;visibility:hidden;width:' +
      (parseInt(getComputedStyle(document.documentElement).getPropertyValue('--page-w'), 10) - 60) + 'px';
    var rows = groups.map(function (g) { return g.list.map(entryRow); });
    rows.forEach(function (list) { list.forEach(function (r) { stage.appendChild(r); }); });
    var samples = groups.map(function (g, i) {
      return [false, true].map(function (cont) {
        var page = newPage(cont, g, (g.detail && g.detail.n) || i + 1);
        page.style.height = 'auto'; stage.appendChild(page); return page;
      });
    });
    document.body.appendChild(stage);
    var heads = samples.map(function (pair) { return pair.map(function (p) {
      return p.lastElementChild.offsetTop + p.lastElementChild.offsetHeight + 8;
    }); });
    var heights = rows.map(function (list) { return list.map(function (r) { return r.offsetHeight; }); });
    samples.forEach(function (pair) { pair.forEach(function (p) { p.remove(); }); });
    var pages = [], days = [];
    groups.forEach(function (g, gi) {
      var n = (g.detail && g.detail.n) || gi + 1, page = newPage(false, g, n), used = heads[gi][0], count = 0;
      days.push({ n: n, group: g, page: pages.length }); pages.push(page);
      function add(row, height) {
        if (count > 0 && used + height > capacity) {
          page = newPage(true, g, n); pages.push(page); used = heads[gi][1]; count = 0;
        }
        page.appendChild(row); used += height; count++;
      }
      rows[gi].forEach(function (row, ri) {
        var limit = capacity - Math.max(heads[gi][0], heads[gi][1]);
        if (heights[gi][ri] <= limit) { add(row, heights[gi][ri]); return; }
        var original = g.list[ri], text = Array.from(original.text || ''), note = Array.from(original.note || ''), at = 0;
        var length = text.length + note.length, chars = text.concat(note);
        function fragment(end) {
          var p = Object.assign({}, original, {
            text: text.slice(Math.min(at, text.length), Math.min(end, text.length)).join(''),
            note: note.slice(Math.max(0, at - text.length), Math.max(0, end - text.length)).join('')
          });
          return entryRow(p);
        }
        while (at < length) {
          var lo = at + 1, hi = length, best = lo;
          while (lo <= hi) {
            var mid = Math.floor((lo + hi) / 2), trial = fragment(mid); stage.appendChild(trial);
            var fits = trial.offsetHeight <= limit; trial.remove();
            if (fits) { best = mid; lo = mid + 1; } else hi = mid - 1;
          }
          best = wordBoundary(chars, at, best);
          var part = fragment(best); stage.appendChild(part); var h = part.offsetHeight;
          add(part, h); at = best;
        }
      });
    });
    stage.remove();
    return { pages: pages, days: days };
  }

  // Match the chapter illustrations used by Saga.lua; old exports carry only a chapter key.
  var SAGA_ART = { road: 'walker', stories: 'scroll', war: 'war', falls: 'falls', company: 'company', marks: 'seals', epilogue: 'epilogue' };
  var SAGA_FILES = ['camp_alliance', 'camp_horde', 'walker', 'scroll', 'war', 'falls', 'company', 'seals', 'epilogue'];
  function sagaArtFor(chapter, book) {
    if (SAGA_FILES.some(function (name) { return chapter.art === 'ui_saga_' + name; })) return chapter.art;
    if (chapter.key === 'prologue') {
      // Only legacy exports need this fallback: new exports include the actual faction's art.
      var race = String(book.race || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[\s-]/g, '');
      var alliance = ['human', 'humano', 'humain', 'dwarf', 'anao', 'nain', 'gnome', 'gnomo', 'nightelf', 'elfonoturno', 'elfedelanuit', 'draenei'];
      var horde = ['orc', 'orco', 'tauren', 'troll', 'undead', 'mortovivo', 'mortvivant', 'bloodelf', 'elfosangrento', 'elfedesang'];
      if (alliance.indexOf(race) >= 0) return 'ui_saga_camp_alliance';
      if (horde.indexOf(race) >= 0) return 'ui_saga_camp_horde';
      return 'ui_saga_walker';
    }
    return SAGA_ART[chapter.key] ? 'ui_saga_' + SAGA_ART[chapter.key] : null;
  }
  function sagaPicture(file, closing) {
    var figure = el('div', 'saga-art' + (closing ? ' saga-epilogue' : ''));
    figure.setAttribute('aria-hidden', 'true'); figure.appendChild(img(file)); return figure;
  }

  // Reserve space for the chapter's art before measuring text. Long chapters can still continue.
  function sagaPages(model) {
    var pages = [], stage = el('div');
    stage.style.cssText = 'position:absolute;left:-9999px;top:0;visibility:hidden';
    document.body.appendChild(stage);
    var capacity = parseInt(getComputedStyle(document.documentElement).getPropertyValue('--page-h'), 10) - 44;
    model.saga.forEach(function (c) {
      var page, measuring, firstPage = true, paragraphs = 0, art = sagaArtFor(c, model);
      var closing = c.key === 'epilogue', artRoom = art ? (closing ? 202 : 182) : 0;
      function finish() {
        if (page && firstPage && art) page.appendChild(sagaPicture(art, closing));
      }
      function next() {
        finish();
        if (page) firstPage = false;
        page = pageShell(model, false, L().saga); page.classList.add('saga-page'); page.dataset.chapter = c.key;
        page.appendChild(el('h2', 'small chapter', c.title)); page.appendChild(el('span', 'saga-divider'));
        pages.push(page);
        if (measuring) measuring.remove();
        measuring = page.cloneNode(true); measuring.style.height = 'auto'; stage.appendChild(measuring);
      }
      function paragraph(text) { return el('p', 'saga' + (paragraphs === 0 ? ' saga-lead' : ''), text); }
      function fits(text) {
        var trial = paragraph(text); measuring.appendChild(trial);
        var yes = trial.offsetTop + trial.offsetHeight <= capacity - (firstPage ? artRoom : 0);
        trial.remove(); return yes;
      }
      function add(text) {
        page.appendChild(paragraph(text)); measuring.appendChild(paragraph(text)); paragraphs++;
      }
      next();
      c.text.split('\n\n').forEach(function (para) {
        var remaining = Array.from(para);
        if (!fits(para) && page.querySelector('p.saga')) next();
        while (remaining.length) {
          if (fits(remaining.join(''))) { add(remaining.join('')); break; }
          var lo = 1, hi = remaining.length, best = 1;
          while (lo <= hi) {
            var mid = Math.floor((lo + hi) / 2);
            if (fits(remaining.slice(0, mid).join(''))) { best = mid; lo = mid + 1; } else hi = mid - 1;
          }
          best = wordBoundary(remaining, 0, best);
          add(remaining.slice(0, best).join('')); remaining = remaining.slice(best); next();
        }
      });
      finish(); measuring.remove();
    });
    stage.remove(); return pages;
  }

  function coverPages(model) {
    var left = pageShell(model, false, L().cover);
    var c = el('div', 'cover');
    var art = el('div', 'art'); art.appendChild(img('b_quill'));
    c.appendChild(art);
    c.appendChild(el('h2', '', model.prefs.coverTitle || fmt(L().diaryOf, model.name)));
    c.appendChild(el('span', 'rule'));
    c.appendChild(el('div', 'sub', fmt(L().level, model.level, (model.race ? model.race + ' ' : '') + model.cls)));
    left.appendChild(c);

    var right = pageShell(model, true, 'Skald');
    right.appendChild(el('h2', 'small', L().story));
    right.appendChild(el('span', 'rule'));
    var list = el('ul', 'stats');
    function stat(label, value) {
      var li = el('li'); li.appendChild(el('span', '', label)); li.appendChild(el('span', 'dots')); li.appendChild(el('span', '', String(value)));
      list.appendChild(li);
    }
    var cn = model.counts;
    stat(L().stat.quest, cn.quest || 0);
    stat(L().stat.level, (cn.level || 0) + (cn.milestone || 0));
    stat(L().stat.death, cn.death || 0);
    stat(L().stat.dungeon, cn.dungeon || 0);
    stat(L().stat.boss, cn.boss || 0);
    stat(L().stat.kill, cn.kill || 0);
    stat(L().goals, model.goals);
    if (model.points) stat(L().points, model.points);
    if (model.first) stat(L().first, L().date(new Date(model.first * 1000)));
    stat(L().played, duration(model.played));
    right.appendChild(list);
    var seals = el('div', 'seals');
    for (var t = 0; t <= 5; t++) {
      var s = el('div'); s.appendChild(img('seal' + t)); s.appendChild(el('span', '', String((model.tiers[t] || 0)))); seals.appendChild(s);
    }
    right.appendChild(seals);
    return [left, right];
  }

  var spreads = [], cur = 0, daysIndex = [], singlePage = false;
  function assemble(model) {
    var days = paginate(model);
    // index pages (as many as the days need), then the days
    var perIndex = 14, indexPages = [];
    var chunks = [], hasSaga = model.saga && model.saga.length > 0;
    // the first index page also carries the line of the Saga, so it holds one day less
    for (var i = 0; i < days.days.length;) {
      var size = (chunks.length === 0 && hasSaga) ? perIndex - 1 : perIndex;
      chunks.push(days.days.slice(i, i + size)); i += size;
    }
    if (!chunks.length) chunks.push([]);
    chunks.forEach(function (chunk, ci) {
      var page = pageShell(model, ci % 2 === 1, L().index);
      page.appendChild(el('h2', 'small', L().index));
      page.appendChild(el('span', 'rule'));
      var wrap = el('div', 'index');
      if (ci === 0 && hasSaga) {
        var sa = el('a'); sa.tabIndex = 0; sa.setAttribute('role', 'button');
        sa.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); sa.click(); } });
        sa.appendChild(el('span', '', L().saga));
        sa.appendChild(el('span', 'dots'));
        sa.appendChild(el('span', 'n', ''));
        sa.dataset.saga = '1';
        wrap.appendChild(sa);
      }
      chunk.forEach(function (d) {
        var a = el('a'); a.tabIndex = 0; a.setAttribute('role', 'button');
        a.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); a.click(); } });
        a.appendChild(el('span', '', fmt(L().day, d.n) + ' — ' + groupDate(d.group)));
        a.appendChild(el('span', 'dots'));
        a.appendChild(el('span', 'n', ''));
        a.dataset.day = String(d.n);
        wrap.appendChild(a);
      });
      page.appendChild(wrap);
      indexPages.push(page);
    });
    var cover = coverPages(model);
    var all = [cover[0], cover[1]].concat(indexPages);
    if (all.length % 2 === 1) all.push(pageShell(model, true, ''));
    var sagaAt = all.length;
    if (hasSaga) {
      sagaPages(model).forEach(function (p) { all.push(p); });
      if (all.length % 2 === 1) all.push(pageShell(model, true, ''));
    }
    var firstDay = all.length;
    days.pages.forEach(function (p) { all.push(p); });
    if (all.length % 2 === 1) all.push(pageShell(model, true, ''));
    // alternate sides and numbers
    all.forEach(function (p, i) {
      p.classList.toggle('left', i % 2 === 0); p.classList.toggle('right', i % 2 === 1);
      if (i >= 2) {
        var number = el('div', 'pnum');
        if (p.classList.contains('saga-page')) {
          number.classList.add('saga-number');
          number.appendChild(img('ui_laurel_l'));
          number.appendChild(el('span', '', String(i - 1)));
          number.appendChild(img('ui_laurel_r'));
        } else number.textContent = String(i - 1);
        p.appendChild(number);
      }
    });
    // fill the index with the page numbers of the days
    var dayPage = {};
    days.days.forEach(function (d) { dayPage[d.n] = firstDay + d.page; });
    indexPages.forEach(function (p) {
      p.querySelectorAll('a').forEach(function (a) {
        if (a.dataset.saga) {
          a.querySelector('.n').textContent = String(sagaAt + 1 - 2);
          a.addEventListener('click', function () { goToPage(sagaAt); });
          return;
        }
        var n = +a.dataset.day; a.querySelector('.n').textContent = String(dayPage[n] + 1 - 2);
        a.addEventListener('click', function () { goToPage(dayPage[n]); });
      });
    });
    spreads = [];
    for (var i = 0; i < all.length; i += 2) spreads.push([all[i], all[i + 1]]);
    daysIndex = days.days.map(function (d) { return { n: d.n, t: d.group.t, date: groupDate(d.group), page: firstDay + d.page }; });
  }

  // ---- the screen ------------------------------------------------------------------------------------------------
  var $ = function (id) { return document.getElementById(id); };
  var model = null;

  function show(i) {
    cur = Math.max(0, Math.min(i, viewCount() - 1));
    var pair = singlePage ? [spreads[Math.floor(cur / 2)][cur % 2], el('div', 'page right')] : spreads[cur];
    // Detach both holders first: a page can move from the right to the left on a phone.
    var oldLeft = $('left'), oldRight = $('right');
    oldLeft.removeAttribute('id'); oldRight.removeAttribute('id');
    var leftSlot = el('div'), rightSlot = el('div');
    oldLeft.replaceWith(leftSlot); oldRight.replaceWith(rightSlot);
    leftSlot.id = 'left'; rightSlot.id = 'right';
    ['left', 'right'].forEach(function (side, k) {
      var holder = $(side);
      holder.replaceWith(pair[k]);
      pair[k].id = side;
    });
    var total = spreads.length * 2;
    $('where').textContent = singlePage ? fmt(L().page, cur + 1, total) : fmt(L().pages, cur * 2 + 1, cur * 2 + 2, total);
    $('prev').disabled = cur === 0;
    $('next').disabled = cur >= viewCount() - 1;
    $('cornerL').disabled = cur === 0;
    $('cornerR').disabled = cur >= viewCount() - 1;
    var sel = $('jump'), here = -1;
    daysIndex.forEach(function (d, k) { if (d.page <= cur * (singlePage ? 1 : 2) + (singlePage ? 0 : 1)) here = k; });
    sel.selectedIndex = Math.min(here + 1, sel.options.length - 1);   // 0 is the cover
    fit();
  }
  // The sound of a page: a short burst of filtered noise made in the browser (no file), only when a page really turns.
  var audio = null, soundOn = true;
  try { soundOn = window.localStorage.getItem('skaldSound') !== 'off'; } catch (e) {}
  function flipSound() {
    if (!soundOn) return;
    try {
      audio = audio || new (window.AudioContext || window.webkitAudioContext)();
      if (audio.state === 'suspended') audio.resume();
      var n = Math.floor(audio.sampleRate * 0.24), buf = audio.createBuffer(1, n, audio.sampleRate), d = buf.getChannelData(0);
      for (var k = 0; k < n; k++) {
        var t = k / n;
        d[k] = (Math.random() * 2 - 1) * Math.pow(1 - t, 2.2) * (0.55 + 0.45 * Math.sin(t * 38)) * Math.min(1, t * 25);
      }
      var src = audio.createBufferSource(), band = audio.createBiquadFilter(), gain = audio.createGain();
      src.buffer = buf; band.type = 'bandpass'; band.frequency.value = 2400; band.Q.value = 0.6; gain.gain.value = 0.3;
      src.connect(band); band.connect(gain); gain.connect(audio.destination); src.start();
    } catch (e) {}
  }
  function turn(i) {
    var to = Math.max(0, Math.min(i, viewCount() - 1));
    if (to !== cur) flipSound();
    show(to);
  }
  function setSound(on) {
    soundOn = on;
    var b = $('sound'); b.classList.toggle('off', !on); b.setAttribute('aria-pressed', on ? 'true' : 'false');
    try { window.localStorage.setItem('skaldSound', on ? 'on' : 'off'); } catch (e) {}
  }
  function viewCount() { return spreads.length * (singlePage ? 2 : 1); }
  function goToPage(p) { turn(singlePage ? p : Math.floor(p / 2)); }
  function fit() {
    var book = $('book');
    var w = book.offsetWidth, h = book.offsetHeight;
    var stage = $('stage');
    var s = Math.min((stage.clientWidth - 12) / w, singlePage ? 1.25 : (stage.clientHeight - 8) / h, 1.25);
    if (singlePage) stage.style.minHeight = (h * Math.min(s, 1.25) + 12) + 'px';
    else stage.style.minHeight = '';
    book.style.transform = 'scale(' + Math.max(0.3, s) + ')';
  }

  function openBook(m) {
    model = m;
    lang = T[m.locale] ? languageKey(m.locale) : lang;
    applyLanguage();
    applyPreferences(m.prefs);
    singlePage = window.innerWidth <= 760;
    $('book').dataset.single = String(singlePage);
    assemble(m);
    var sel = $('jump');
    sel.innerHTML = '';
    var cov = document.createElement('option'); cov.textContent = L().cover; cov.value = '0'; sel.appendChild(cov);
    daysIndex.forEach(function (d) {
      var o = document.createElement('option'); o.textContent = fmt(L().day, d.n) + ' — ' + d.date; o.value = String(d.page); sel.appendChild(o);
    });
    $('intake').hidden = true;
    $('reader').hidden = false;
    show(0);
  }
  function printBook() {
    var sheet = $('sheet');
    sheet.innerHTML = '';
    // a fresh copy of each spread (the pages on the screen belong to the book)
    spreads.forEach(function (pair) {
      var s = el('div', 'spread');
      pair.forEach(function (p) {
        var copy = p.cloneNode(true); copy.removeAttribute('id');
        copy.querySelectorAll('[id]').forEach(function (node) { node.removeAttribute('id'); });
        s.appendChild(copy);
      });
      sheet.appendChild(s);
    });
    window.print();
  }

  function applyLanguage() {
    var t = L();
    $('lang').value = languageKey(lang);
    $('lang').setAttribute('aria-label', t.language || 'Language');
    document.documentElement.lang = lang === 'ptBR' ? 'pt-BR' : lang === 'frFR' ? 'fr' : lang === 'esES' ? 'es' : 'en';
    document.title = t.title;
    $('t-title').textContent = t.title;
    $('t-intro').textContent = t.intro;
    var ol = $('t-steps'); ol.innerHTML = '';
    t.steps.forEach(function (s) { ol.appendChild(el('li', '', s)); });
    $('t-label').textContent = t.label;
    $('open').textContent = t.open;
    $('clear').textContent = t.clear;
    $('t-privacy').textContent = t.privacy;
    $('back').textContent = t.back;
    $('print').textContent = t.print;
    $('sound').setAttribute('aria-label', t.sound); $('sound').title = t.sound;
    ['cornerL', 'prev'].forEach(function (id) { $(id).title = t.turnBack; $(id).setAttribute('aria-label', t.turnBack); });
    ['cornerR', 'next'].forEach(function (id) { $(id).title = t.turnOn; $(id).setAttribute('aria-label', t.turnOn); });
    $('jump').setAttribute('aria-label', t.jumpLabel || t.days);
  }

  var parsed = [];
  function update() {
    var text = $('paste').value;
    parsed = readParts(text);
    var chips = $('parts'); chips.innerHTML = '';
    var status = $('status'); status.textContent = '';
    $('open').disabled = true;
    if (!parsed.length) { status.textContent = text.trim() ? '' : L().empty; return; }
    var result = collectParts(parsed);
    if (result.state === 'mixed' || result.state === 'invalid') { status.textContent = L().mixed; return; }
    result.parts.forEach(function (p, k) {
      var i = k + 1, chip = el('span', 'chip');
      if (!p) { chip.className = 'chip wait'; chip.textContent = fmt(L().waiting, i); }
      else if (!p.valid) { chip.className = 'chip bad'; chip.textContent = fmt(L().partBad, i); }
      else { chip.className = 'chip ok'; chip.textContent = '✓ ' + fmt(L().part, i, result.parts.length); }
      chips.appendChild(chip);
    });
    if (result.state === 'ready') {
      try { build(result.parts); status.textContent = L().ready; $('open').disabled = false; }
      catch (e) { status.textContent = e.message === 'mixed' ? L().mixed : L().truncated; }
    }
  }

  function start() {
    applyLanguage();
    $('lang').value = lang;
    $('lang').addEventListener('change', function (e) { lang = e.target.value; applyLanguage(); update(); });
    $('paste').addEventListener('input', update);
    $('clear').addEventListener('click', function () { $('paste').value = ''; update(); });
    $('open').addEventListener('click', function () { $('open').disabled = true;
      Promise.allSettled([document.fonts.ready, document.fonts.load('700 46px "Cinzel Decorative"'), document.fonts.load('400 20px "Caveat"')]).then(function () {
        try { openBook(build(parsed)); }
        catch (e) { $('status').textContent = L().truncated; }
        finally { $('open').disabled = false; }
      }); });
    $('prev').addEventListener('click', function () { turn(cur - 1); });
    $('next').addEventListener('click', function () { turn(cur + 1); });
    $('cornerL').addEventListener('click', function () { turn(cur - 1); });
    $('cornerR').addEventListener('click', function () { turn(cur + 1); });
    $('sound').addEventListener('click', function () { setSound(!soundOn); });
    setSound(soundOn);
    $('jump').addEventListener('change', function (e) { goToPage(+e.target.value); });
    $('print').addEventListener('click', printBook);
    // a click on a page turns it (left page back, right page forward), unless it hit a link or ended a text selection
    // (the pages are swapped on each turn, so the listener sits on the book)
    $('book').addEventListener('click', function (e) {
      var page = e.target.closest('.page');
      if (!page || e.target.closest('.entry.linked, a, button, select, input')) return;
      var sel = window.getSelection && window.getSelection();
      if (sel && String(sel).length) return;
      turn(cur + (singlePage || page.classList.contains('right') ? 1 : -1));
    });
    $('back').addEventListener('click', function () { $('reader').hidden = true; $('intake').hidden = false; });
    document.addEventListener('keydown', function (e) {
      if ($('reader').hidden || e.target.closest('input, textarea, select')) return;
      if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') e.preventDefault();
      if (e.key === 'ArrowLeft') turn(cur - 1);
      if (e.key === 'ArrowRight') turn(cur + 1);
    });
    window.addEventListener('resize', function () {
      if ($('reader').hidden) return;
      var leaf = cur * (singlePage ? 1 : 2);
      singlePage = window.innerWidth <= 760; $('book').dataset.single = String(singlePage);
      show(singlePage ? leaf : Math.floor(leaf / 2));
    });
    update();
  }

  // for the tests of the page: the reading functions
  window.SkaldReader = { readParts: readParts, build: build, checksum: checksum, unescapeField: unescapeField, collectParts: collectParts, lookupUrl: lookupUrl, sagaArtFor: sagaArtFor };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
