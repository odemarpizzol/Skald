"""Browser checks for the Reader; requires Python Playwright and a local docs server.
Run: node dev/tools/serve_docs.js 8765
     python3 dev/tools/reader_browser_test.py [http://localhost:8765/reader/]
Uses an artificial diary, never a real character's SavedVariables.
"""
from pathlib import Path
import subprocess
import json
import sys
from playwright.sync_api import sync_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:8765/reader/'
OUT = Path('output/reader-review')
OUT.mkdir(parents=True, exist_ok=True)

def checksum(value):
    result = 5381
    for byte in value.encode('utf-8'):
        result = (result * 31 + byte) & 0xffffffff
    return result

def record(*fields):
    def escape(value):
        return str(value).replace('\\', '\\\\').replace('^', '\\p').replace('\n', '\\n')
    return '^'.join(map(escape, fields))

def export(locale='enUS', paper='clean', size=1, density='comfy', entries=30, legacy=False, long=False):
    rows = [] if legacy else [record('M', 'paper', paper), record('M', 'textSize', size), record('M', 'ink', 2), record('M', 'density', density), record('M', 'era', 'tbc'), record('M', 'coverTitle', 'Memories of Azeroth'), record('D', '2026-11-08@1', 7, 1794142800, 'Day 7: A road to remember', '2026-11-08'), record('D', '2026-11-08@2', 8, 1794149900, 'Day 8: Together again', '2026-11-08')]
    rows += [record('S', 1794142800, 3700), record('N', 'quest', entries), record('N', 'milestone', 2), record('N', 'level', 3)]
    story = ('Along the road, every journey left a memory. Árvore, lumière, snow and rain. ' * (80 if long else 3))
    rows.append(record('V', 'road', 'The road ahead', story))
    rows.append(record('V', 'epilogue', 'A quiet evening', 'I closed the book.'))
    expected_text, expected_notes = [], []
    for i in range(entries):
        note = 'A margin note.\nRemember this place. ' * 65 if long and i == 0 else ''
        text = ('I followed the road through Azeroth. ' * 110 + '雪🌧️\nLast line.') if long and i == 0 else 'I watched the rain fall over Teldrassil and kept walking. ' + str(i)
        if i == 1: text = '<img src=x onerror="window.readerXss=true"> & <script>bad()</script>'
        expected_text.append(text); expected_notes.append(note)
        fields = ['P', 1794142800 + i * 120, 'note' if i == 0 else 'quest', 1, 1 if i == 0 else 0, 'Teldrassil', 'note' if i == 0 else 'quest', text, note, 'title=A memory~q=77']
        if not legacy: fields.append('2026-11-08@1' if i < entries // 2 else '2026-11-08@2')
        rows.append(record(*fields))
    body = '\n'.join(rows)
    header = ['H', 'SKALDREADER1', 'Aelyndra', 'Priest', 'Night Elf', 20, 'kin', locale, entries, 1, 1, str(checksum(body)) + '.0']
    if not legacy: header.append(checksum(body))
    return '^'.join(map(str, header)) + '\n' + body, ''.join(expected_text), ''.join(expected_notes), story + 'I closed the book.'

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={'width': 1440, 'height': 960}, timezone_id='America/Sao_Paulo')
    errors, external, missing = [], [], []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('request', lambda req: external.append(req.url) if not req.url.startswith(URL.split('/reader')[0]) and not req.url.startswith('data:') else None)
    page.on('response', lambda res: missing.append(res.url) if res.status >= 400 else None)
    def open_export(text):
        page.goto(URL)
        page.locator('#paste').fill(text)
        assert page.locator('#open').is_enabled(), page.locator('#status').inner_text()
        page.locator('#open').click()
        page.locator('#reader').wait_for(state='visible')
        page.evaluate('document.fonts.ready')

    for locale, paper, size, density in [('enUS', 'clean', 1, 'comfy'), ('ptBR', 'travel', 2, 'airy'), ('frFR', 'war', 0, 'compact'), ('enUS', 'old', 2, 'comfy')]:
        text, expected, notes, story = export(locale, paper, size, density, entries=30, long=True)
        open_export(text)
        assert page.locator('html').get_attribute('data-paper') == paper
        assert len(page.locator('#jump option').all()) == 3, 'session groups merged'
        assert page.locator('#left .cover h2').text_content() == 'Memories of Azeroth'
        page.evaluate('window.print = function () {}')
        page.locator('#print').click()
        page.emulate_media(media='print')
        result = page.evaluate('''() => {
          const pages = [...document.querySelectorAll('#sheet .page')];
          const rows = [...document.querySelectorAll('#sheet .entry')];
          return {
            pages: pages.length,
            text: rows.map(row => { const b = row.querySelector('.body').cloneNode(true); b.querySelectorAll('.note,.tag').forEach(n => n.remove()); return b.textContent; }).join(''),
            notes: rows.map(row => row.querySelector('.note')?.textContent || '').join(''),
            saga: [...document.querySelectorAll('#sheet p.saga')].map(p => p.textContent).join(''),
            clipped: pages.flatMap(p => [...p.children].filter(c => !c.classList.contains('pnum') && c.offsetTop + c.offsetHeight > p.clientHeight - 30).map(c => ({kind:c.className, bottom:c.offsetTop+c.offsetHeight, height:p.clientHeight}))),
            xss: !!window.readerXss
          };
        }''')
        assert result['text'] == expected, 'entry text lost or duplicated'
        assert result['notes'] == notes, 'margin note lost or duplicated'
        assert result['saga'] == story, 'Saga text lost or duplicated'
        assert page.locator('#sheet .saga-art').count() == 2, 'Saga chapter illustrations missing'
        assert page.locator('#sheet .saga-lead').count() == 2, 'chapter opening letters missing'
        assert page.locator('#sheet .saga-epilogue img').get_attribute('src') == 'img/ui_saga_epilogue.png'
        assert not result['clipped'], json.dumps(result['clipped'])
        assert not result['xss']
        if paper == 'clean': page.pdf(path=str(OUT / 'reader-print.pdf'), print_background=True, prefer_css_page_size=True)
        page.emulate_media(media='screen')
        page.locator('#jump').select_option(index=1)
        if paper == 'clean': page.screenshot(path=str(OUT / 'reader-long-text.png'))
        if paper == 'travel':
            page.set_viewport_size({'width': 390, 'height': 844})
            page.wait_for_function("document.querySelector('#book').dataset.single === 'true'")
            page.screenshot(path=str(OUT / 'reader-mobile-long-text.png'), full_page=True)
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), 'horizontal overflow'
            for _ in range(5): page.locator('#next').click()
            assert len(page.locator('#left').all()) == 1 and len(page.locator('#right').all()) == 1, page.locator('#book').inner_html()[:2500]
            page.set_viewport_size({'width': 1440, 'height': 960})
            page.wait_for_function("document.querySelector('#book').dataset.single === 'false'")
        print('ok', locale, paper, 'long entries, notes, Saga, print, session groups:', result['pages'], 'pages')

    # Every native chapter has its artwork, including both faction camps and the Epilogue.
    text, _, _, _ = export(entries=4)
    header, body = text.split('\n', 1)
    art_cases = [('prologue', 'camp_alliance'), ('road', 'walker'), ('stories', 'scroll'), ('war', 'war'), ('falls', 'falls'), ('company', 'company'), ('marks', 'seals'), ('epilogue', 'epilogue')]
    body = '\n'.join(line for line in body.split('\n') if not line.startswith('V^'))
    for key, art in art_cases:
        body += '\n' + record('V', key, key.title(), 'The journey began with a promise. I kept these memories on the road through Azeroth.\n\nThe next chapter is still waiting.', 'ui_saga_' + art)
    fields = header.split('^'); fields[11] = str(checksum(body)); fields[12] = str(checksum(body))
    open_export('^'.join(fields) + '\n' + body)
    page.locator('#next').click()
    page.locator('#book .index a[data-saga]').click()
    page.screenshot(path=str(OUT / 'reader-saga-chapters.png'))
    # Inspect and print all eight chapters to catch missing files and overlap with artwork.
    page.evaluate('window.print = function () {}'); page.locator('#print').click()
    page.emulate_media(media='print')
    assert page.locator('#sheet .saga-art').count() == 8
    assert page.locator('#sheet .saga-lead').count() == 8
    for key, art in art_cases:
        assert page.locator('#sheet [data-chapter="' + key + '"] .saga-art img').get_attribute('src') == 'img/ui_saga_' + art + '.png'
    collisions = page.evaluate("""() => [...document.querySelectorAll('#sheet .saga-page')].flatMap(p => {
      const art = p.querySelector('.saga-art'); if (!art) return [];
      const paragraphs = [...p.querySelectorAll('p.saga')];
      const last = paragraphs[paragraphs.length-1];
      return art.offsetTop + art.offsetHeight > p.clientHeight - 30 || (last && last.offsetTop + last.offsetHeight > art.offsetTop) ? [p.dataset.chapter] : [];
    })""")
    assert not collisions, collisions
    page.emulate_media(media='screen')
    print('ok all eight Saga illustrations, opening letters, closing scene and print layout')

    legacy, _, _, _ = export(legacy=True)
    open_export(legacy)
    assert page.locator('html').get_attribute('data-paper') == 'clean'
    page.locator('#back').click()
    page.locator('#paste').fill(legacy + '\n' + legacy)
    assert page.locator('#open').is_enabled()
    page.locator('#paste').fill(legacy[:-20])
    assert page.locator('#open').is_disabled()
    print('ok legacy import, repeated paste, truncated copy')

    stress, _, _, _ = export(entries=3000)
    page.goto(URL)
    page.wait_for_function("!document.querySelector('#intake').hidden")
    page.locator('#paste').evaluate("(el, text) => { el.value = text; el.dispatchEvent(new Event('input', {bubbles:true})); }", stress)
    start = page.evaluate('performance.now()')
    page.locator('#open').click()
    page.locator('#reader').wait_for(state='visible')
    elapsed = page.evaluate('performance.now()') - start
    assert elapsed < 15000, f'large diary took {elapsed} ms'
    print('ok 3000 entries:', round(elapsed), 'ms to open')
    # Representative screenshots use text produced by the actual addon from its test fixture.
    root = Path(__file__).resolve().parents[2]
    sample = OUT / 'sample-export.txt'
    subprocess.run(['node', str(root / 'dev/tools/reader_sample.js'), str(root / 'dev/tools/fixtures/reader_saved.lua'), str(sample), 'enUS'], check=True, capture_output=True, text=True)
    open_export(sample.read_text())
    page.screenshot(path=str(OUT / 'reader-cover.png'))
    page.locator('#next').click()
    page.locator('#book .index a[data-saga]').click()
    assert page.locator('#book .saga-page .pnum img').count() == 4
    page.evaluate("Promise.all([...document.querySelectorAll('#book img')].map(i => i.decode().catch(() => {})))")
    page.screenshot(path=str(OUT / 'reader-saga.png'))
    page.locator('#jump').select_option(index=1)
    page.screenshot(path=str(OUT / 'reader-desktop.png'))
    page.set_viewport_size({'width': 390, 'height': 844})
    page.wait_for_function("document.querySelector('#book').dataset.single === 'true'")
    page.screenshot(path=str(OUT / 'reader-mobile.png'), full_page=True)
    assert not errors, errors
    assert not missing, missing
    assert not external, external
    print('All browser checks passed; no external requests, missing assets or script errors')
    browser.close()
