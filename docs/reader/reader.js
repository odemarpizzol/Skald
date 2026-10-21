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
      empty: 'Paste the text from the game.', diaryOf: 'Diary of %1', level: 'level %1 %2', story: 'The story so far', days: 'Days', index: 'Index',
      day: 'Day %1', pages: 'Pages %1–%2 of %3', cover: 'Cover', first: 'First page written', played: 'Time on the road', goals: 'Goals reached', points: 'Goal points',
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
      empty: 'Cole o texto que veio do jogo.', diaryOf: 'Diário de %1', level: 'nível %1 %2', story: 'A história até aqui', days: 'Dias', index: 'Índice',
      day: 'Dia %1', pages: 'Páginas %1–%2 de %3', cover: 'Capa', first: 'Primeira página escrita', played: 'Tempo na estrada', goals: 'Metas cumpridas', points: 'Pontos de metas',
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
      empty: 'Collez le texte venu du jeu.', diaryOf: 'Journal de %1', level: 'niveau %1 %2', story: 'L’histoire jusqu’ici', days: 'Jours', index: 'Index',
      day: 'Jour %1', pages: 'Pages %1–%2 sur %3', cover: 'Couverture', first: 'Première page écrite', played: 'Temps sur la route', goals: 'Objectifs atteints', points: 'Points d\'objectifs',
      stat: { quest: 'Quêtes accomplies', level: 'Niveaux gagnés', death: 'Fois où je suis tombé', dungeon: 'Donjons visités', boss: 'Boss vaincus', kill: 'Créatures vaincues' },
      date: function (d) { return d.toLocaleDateString('fr-FR'); }, hours: '%1 h %2 min', minutes: '%1 min', tier: ['Trivial', 'Commun', 'Peu commun', 'Rare', 'Épique', 'Légendaire'],
      truncated: 'Le journal compte plus de pages que celles collées.',
      tip: { level: 'Niveau %1', giver: 'Donnée par %1', falls: 'Après %1 chutes', stack: '%1 fabriqués', open: 'Cliquez pour chercher sur Wowhead' }
    }
  };
  var lang = 'ptBR';
  function L() { return T[lang] || T.ptBR; }
  function fmt(s) { var a = arguments; return String(s).replace(/%(\d)/g, function (_, n) { return a[+n] !== undefined ? a[+n] : ''; }); }
  (function pickLanguage() {
    var n = (navigator.language || 'pt-BR').toLowerCase();
    lang = n.indexOf('fr') === 0 ? 'frFR' : n.indexOf('en') === 0 ? 'enUS' : 'ptBR';
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
      return {
        name: unescapeField(f[2] || ''), cls: unescapeField(f[3] || ''), race: unescapeField(f[4] || ''), level: f[5], tone: f[6], locale: f[7],
        total: +f[8], index: +f[9], count: +f[10], sum: +f[11], body: body, valid: checksum(body) === +f[11]
      };
    });
  }
  function build(parts) {
    var first = parts[0];
    var model = { name: first.name, cls: first.cls, race: first.race, level: first.level, tone: first.tone, locale: first.locale, total: first.total,
      first: 0, played: 0, counts: {}, tiers: {}, goals: 0, points: 0, pages: [] };
    parts.forEach(function (p) {
      p.body.split('\n').forEach(function (line) {
        if (!line) return;
        var f = line.split('^').map(unescapeField);
        switch (f[0]) {
          case 'S': model.first = +f[1]; model.played = +f[2]; break;
          case 'N': model.counts[f[1]] = +f[2]; break;
          case 'T': model.tiers[f[1]] = +f[2]; break;
          case 'G': model.goals++; model.points += (+f[4] || 0); break;
          case 'P': model.pages.push({ t: +f[1], kind: f[2], tier: +f[3], fav: f[4] === '1', place: f[5], ic: f[6], text: f[7], note: f[8], info: parseInfo(f[9]) }); break;
        }
      });
    });
    model.pages.sort(function (a, b) { return a.t - b.t; });
    return model;
  }

  // ---- icons -----------------------------------------------------------------------------------------------------
  var KIND_ICON = { quest: 'ev_quest', level: 'ev_level', milestone: 'ev_milestone', death: 'ev_death', boss: 'ev_boss', dungeon: 'ev_dungeon',
    zone: 'ev_zone', mount: 'ev_mount', guild: 'ev_guild', guildleave: 'ev_guild', party: 'ev_party', reunion: 'ev_party', achievement: 'ev_achievement',
    skill: 'ev_profession', profession: 'ev_profession', day: 'b_moon', mark: 'ev_milestone', home: 'st_hearth', hearth: 'st_hearth', rep: 'ev_achievement',
    flight: 'st_flight', tame: 'ev_pet', revive: 'ev_revive', goal: 'ev_goal', note: 'b_quill', loot: 'it_generic' };
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
  function lookupUrl(p) {
    var i = p.info || {};
    if (p.kind === 'quest' && i.q) return 'https://www.wowhead.com/forever/quest=' + encodeURIComponent(i.q);
    if (p.kind === 'loot' && i.iid) return 'https://www.wowhead.com/forever/item=' + encodeURIComponent(i.iid);
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
    if (url) { row.classList.add('linked'); row.addEventListener('click', function () { window.open(url, '_blank', 'noopener'); }); }
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
      var k = dayKey(p.t);
      if (!byKey[k]) { byKey[k] = { key: k, t: p.t, list: [] }; groups.push(byKey[k]); }
      byKey[k].list.push(p);
    });
    var pageH = parseInt(getComputedStyle(document.documentElement).getPropertyValue('--page-h'), 10) || 620;
    var capacity = pageH - 44;   // what is left above the number at the foot
    function newPage(cont, group, n) {
      var page = pageShell(model, false, fmt(L().day, n));
      page.appendChild(el('h2', 'small', cont ? fmt(L().day, n) + ' (…)' : fmt(L().day, n)));
      if (!cont) page.appendChild(el('div', 'sub', L().date(new Date(group.t * 1000))));
      page.appendChild(el('span', 'rule'));
      return page;
    }
    // Measure everything in one go (reading the heights of all the rows after putting them all in, so the browser
    // lays the text out once), then fill the pages by arithmetic.
    var stage = el('div');
    stage.style.cssText = 'position:absolute;left:-9999px;top:0;visibility:hidden;width:' + (parseInt(getComputedStyle(document.documentElement).getPropertyValue('--page-w'), 10) - 60 || 380) + 'px';
    var rows = groups.map(function (g) { return g.list.map(entryRow); });
    rows.forEach(function (list) { list.forEach(function (r) { stage.appendChild(r); }); });
    var sampleFirst = newPage(false, groups[0] || { t: 0 }, 1), sampleCont = newPage(true, groups[0] || { t: 0 }, 1);
    sampleFirst.style.cssText = sampleCont.style.cssText = 'height:auto';
    stage.appendChild(sampleFirst); stage.appendChild(sampleCont);
    document.body.appendChild(stage);
    var headFirst = sampleFirst.lastElementChild.offsetTop + sampleFirst.lastElementChild.offsetHeight + 8;
    var headCont = sampleCont.lastElementChild.offsetTop + sampleCont.lastElementChild.offsetHeight + 8;
    var heights = rows.map(function (list) { return list.map(function (r) { return r.offsetHeight; }); });
    document.body.removeChild(stage);

    var pages = [], days = [];
    groups.forEach(function (g, gi) {
      var n = gi + 1, page = newPage(false, g, n), used = headFirst, count = 0;
      days.push({ n: n, group: g, page: pages.length });
      pages.push(page);
      rows[gi].forEach(function (row, ri) {
        var h = heights[gi][ri];
        if (count > 0 && used + h > capacity) {
          page = newPage(true, g, n); pages.push(page); used = headCont; count = 0;
        }
        page.appendChild(row); used += h; count++;
      });
    });
    return { pages: pages, days: days };
  }

  function coverPages(model) {
    var left = pageShell(model, false, L().cover);
    var c = el('div', 'cover');
    var art = el('div', 'art'); art.appendChild(img('b_quill'));
    c.appendChild(art);
    c.appendChild(el('h2', '', fmt(L().diaryOf, model.name)));
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

  var spreads = [], cur = 0, daysIndex = [];
  function assemble(model) {
    var days = paginate(model);
    // index pages (as many as the days need), then the days
    var perIndex = 18, indexPages = [];
    var chunks = [];
    for (var i = 0; i < days.days.length; i += perIndex) chunks.push(days.days.slice(i, i + perIndex));
    if (!chunks.length) chunks.push([]);
    chunks.forEach(function (chunk, ci) {
      var page = pageShell(model, ci % 2 === 1, L().index);
      page.appendChild(el('h2', 'small', L().index));
      page.appendChild(el('span', 'rule'));
      var wrap = el('div', 'index');
      chunk.forEach(function (d) {
        var a = el('a');
        a.appendChild(el('span', '', fmt(L().day, d.n) + ' — ' + L().date(new Date(d.group.t * 1000))));
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
    var firstDay = all.length;
    days.pages.forEach(function (p) { all.push(p); });
    if (all.length % 2 === 1) all.push(pageShell(model, true, ''));
    // alternate sides and numbers
    all.forEach(function (p, i) {
      p.classList.toggle('left', i % 2 === 0); p.classList.toggle('right', i % 2 === 1);
      if (i >= 2) p.appendChild(el('div', 'pnum', String(i + 1 - 2)));
    });
    // fill the index with the page numbers of the days
    var dayPage = {};
    days.days.forEach(function (d) { dayPage[d.n] = firstDay + d.page; });
    indexPages.forEach(function (p) {
      p.querySelectorAll('a').forEach(function (a) {
        var n = +a.dataset.day; a.querySelector('.n').textContent = String(dayPage[n] + 1 - 2);
        a.addEventListener('click', function () { goToPage(dayPage[n]); });
      });
    });
    spreads = [];
    for (var i = 0; i < all.length; i += 2) spreads.push([all[i], all[i + 1]]);
    daysIndex = days.days.map(function (d) { return { n: d.n, t: d.group.t, page: firstDay + d.page }; });
  }

  // ---- the screen ------------------------------------------------------------------------------------------------
  var $ = function (id) { return document.getElementById(id); };
  var model = null;

  function show(i) {
    cur = Math.max(0, Math.min(i, spreads.length - 1));
    var pair = spreads[cur];
    ['left', 'right'].forEach(function (side, k) {
      var holder = $(side);
      holder.replaceWith(pair[k]);
      pair[k].id = side;
    });
    var total = spreads.length * 2;
    $('where').textContent = fmt(L().pages, cur * 2 + 1, cur * 2 + 2, total);
    $('prev').disabled = cur === 0;
    $('next').disabled = cur >= spreads.length - 1;
    $('cornerL').disabled = cur === 0;
    $('cornerR').disabled = cur >= spreads.length - 1;
    var sel = $('jump'), here = -1;
    daysIndex.forEach(function (d, k) { if (d.page <= cur * 2 + 1) here = k; });
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
    var to = Math.max(0, Math.min(i, spreads.length - 1));
    if (to !== cur) flipSound();
    show(to);
  }
  function setSound(on) {
    soundOn = on;
    var b = $('sound'); b.classList.toggle('off', !on); b.setAttribute('aria-pressed', on ? 'true' : 'false');
    try { window.localStorage.setItem('skaldSound', on ? 'on' : 'off'); } catch (e) {}
  }
  function goToPage(p) { turn(Math.floor(p / 2)); }
  function fit() {
    var book = $('book');
    var w = book.offsetWidth, h = book.offsetHeight;
    var stage = $('stage');
    var s = Math.min((stage.clientWidth - 12) / w, (stage.clientHeight - 8) / h, 1.25);
    book.style.transform = 'scale(' + Math.max(0.3, s) + ')';
  }

  function openBook(m) {
    model = m;
    lang = T[m.locale] ? m.locale : lang;
    applyLanguage();
    assemble(m);
    var sel = $('jump');
    sel.innerHTML = '';
    var cov = document.createElement('option'); cov.textContent = L().cover; cov.value = '0'; sel.appendChild(cov);
    daysIndex.forEach(function (d) {
      var o = document.createElement('option'); o.textContent = fmt(L().day, d.n) + ' — ' + L().date(new Date(d.t * 1000)); o.value = String(d.page); sel.appendChild(o);
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
      pair.forEach(function (p) { s.appendChild(p.cloneNode(true)); });
      sheet.appendChild(s);
    });
    window.print();
  }

  function applyLanguage() {
    var t = L();
    document.documentElement.lang = lang === 'ptBR' ? 'pt-BR' : lang === 'frFR' ? 'fr' : 'en';
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
    $('cornerL').title = t.turnBack; $('cornerR').title = t.turnOn;
  }

  var parsed = [];
  function update() {
    var text = $('paste').value;
    parsed = readParts(text);
    var chips = $('parts'); chips.innerHTML = '';
    var status = $('status'); status.textContent = '';
    $('open').disabled = true;
    if (!parsed.length) { status.textContent = text.trim() ? '' : L().empty; return; }
    var first = parsed[0];
    var same = parsed.every(function (p) { return p.name === first.name && p.count === first.count && p.total === first.total; });
    if (!same) { status.textContent = L().mixed; return; }
    var byIndex = {};
    parsed.forEach(function (p) { if (!byIndex[p.index] || (p.valid && !byIndex[p.index].valid)) byIndex[p.index] = p; });
    var allGood = true;
    for (var i = 1; i <= first.count; i++) {
      var p = byIndex[i];
      var chip = el('span', 'chip');
      if (!p) { chip.className = 'chip wait'; chip.textContent = fmt(L().waiting, i); allGood = false; }
      else if (!p.valid) { chip.className = 'chip bad'; chip.textContent = fmt(L().partBad, i); allGood = false; }
      else { chip.className = 'chip ok'; chip.textContent = '✓ ' + fmt(L().part, i, first.count); }
      chips.appendChild(chip);
    }
    if (allGood) { status.textContent = L().ready; $('open').disabled = false; }
  }
  function orderedParts() {
    var byIndex = {};
    parsed.forEach(function (p) { if (p.valid) byIndex[p.index] = p; });
    var list = [];
    for (var i = 1; i <= parsed[0].count; i++) list.push(byIndex[i]);
    return list;
  }

  function start() {
    applyLanguage();
    $('lang').value = lang;
    $('lang').addEventListener('change', function (e) { lang = e.target.value; applyLanguage(); update(); });
    $('paste').addEventListener('input', update);
    $('clear').addEventListener('click', function () { $('paste').value = ''; update(); });
    $('open').addEventListener('click', function () { openBook(build(orderedParts())); });
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
      turn(cur + (page.classList.contains('left') ? -1 : 1));
    });
    $('back').addEventListener('click', function () { $('reader').hidden = true; $('intake').hidden = false; });
    document.addEventListener('keydown', function (e) {
      if ($('reader').hidden) return;
      if (e.key === 'ArrowLeft') turn(cur - 1);
      if (e.key === 'ArrowRight') turn(cur + 1);
    });
    window.addEventListener('resize', function () { if (!$('reader').hidden) fit(); });
    update();
  }

  // for the tests of the page: the reading functions
  window.SkaldReader = { readParts: readParts, build: build, checksum: checksum, unescapeField: unescapeField };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
