"""Publish measured emulator timing evidence alongside the signed APK."""
import json
import shutil
import sys
from pathlib import Path

source, output = map(Path, sys.argv[1:])
files = list(source.rglob('frame-timings.json'))
if len(files) != 1:
    raise SystemExit(f'Expected exactly one frame-timing report, found {len(files)}')
data = json.loads(files[0].read_text())
required = ['tab_navigation', 'home_scroll', 'route_transitions', 'pdf_open', 'ambient_hero']
rows = []
for name in required:
    sample = data[name]
    if sample['frame_count'] <= 0:
        raise SystemExit(f'Empty performance sample: {name}')
    rows.append('| {} | {} | {:.2f} | {:.2f} | {} | {} |'.format(
        name, sample['frame_count'],
        sample['90th_percentile_frame_build_time_millis'],
        sample['90th_percentile_frame_rasterizer_time_millis'],
        sample['missed_frame_build_budget_count'],
        sample['missed_frame_rasterizer_budget_count']))
output.mkdir(parents=True, exist_ok=True)
shutil.copyfile(files[0], output / 'frame-timings.json')
(output / 'profile-summary.md').write_text('''# Emulator profile measurements

Flutter profile mode, API 35 x86_64 emulator using SwiftShader. The 60 Hz frame
budget is approximately 16.7 ms. These measurements include the looping Home
hero; screenshots are captured outside the measured windows.

| Scenario | Frames | UI p90 ms | Raster p90 ms | UI over budget | Raster over budget |
| --- | ---: | ---: | ---: | ---: | ---: |
''' + '\n'.join(rows) + '''

These are software-emulator measurements and do not establish physical-device
60 FPS. Device GPU, camera/OCR, large live documents and sustained battery/memory
usage still need verification. See frame-timings.json for the raw captured data.
''')
print((output / 'profile-summary.md').read_text())
