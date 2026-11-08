"""Convert the addon's current artwork for the web Reader. Requires ffmpeg.

Run from any directory: python3 dev/tools/sync_reader_art.py
Keeps the original dimensions and alpha; the book frame uses the populated atlas region.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Textures'
OUTPUT = ROOT / 'docs/reader/img'


def manifest():
    assets = {}
    for png in sorted(OUTPUT.glob('*.png')):
        source = SOURCE / (png.stem + '.tga')
        if png.stem.startswith('b_'):
            source = SOURCE / 'skald2' / (png.stem[2:] + '.tga')
        if source.exists():
            assets[png.stem] = (source, None)
    # Include new loot/profession icons too, so category lookups never lag behind.
    for pattern in ['it_*.tga', 'pf_*.tga', 'ev_*.tga', 'ui_saga_*.tga', 'ui_laurel_*.tga']:
        for source in sorted(SOURCE.glob(pattern)):
            assets[source.stem] = (source, None)
    book = SOURCE / 'skald2'
    for source, target in {
        'cover9': 'book_frame', 'spine': 'book_spine', 'parchment': 'paper_clean',
        'parchment_travel': 'paper_travel', 'parchment_war': 'paper_war',
        'parchment_old': 'paper_old', 'quill': 'b_quill', 'rule': 'b_rule',
        'sun': 'b_sun', 'moon': 'b_moon',
    }.items():
        assets[target] = (book / (source + '.tga'), 'crop=192:175:0:0' if source == 'cover9' else None)
    for side in ['l', 'r']:
        for suffix in ['', '_travel', '_war', '_old']:
            name = 'ui_corner_' + side + suffix
            assets[name] = (book / (name + '.tga'), None)
    return assets


def main():
    assets = manifest()
    missing = [str(source) for source, _ in assets.values() if not source.is_file()]
    if missing:
        raise SystemExit('Missing artwork: ' + ', '.join(missing))
    for name, (source, crop) in sorted(assets.items()):
        cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(source)]
        if crop:
            cmd += ['-vf', crop]
        subprocess.run(cmd + ['-frames:v', '1', str(OUTPUT / (name + '.png'))], check=True)
    print('Reader artwork synchronized:', len(assets), 'PNGs, original alpha preserved')


if __name__ == '__main__':
    main()
