#!/usr/bin/env python3
"""Assemble the existing Hyzen repository overlays without installing/building/deploying.

Requires a fresh output directory. Rejects unsafe ZIP/patch paths and symlinks.
The resulting manifest records exact input/output hashes for review.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import zipfile

PATCHES = tuple(f'updates_1_4_{i}.json' for i in range(4)) + tuple(
    f'updates_phase_{i:02}.json' for i in range(1,6)) + (
    'updates_camera.json','updates_phase_06.json','updates_phase_07.json','updates_phase_08.json')
BASE = 'PharmD_With_Hyzen_Source_1.3.3.zip'
MAX_EXPANDED = 1024 * 1024 * 1024


def relative(raw: str) -> Path:
    if not isinstance(raw,str) or not raw or '\\' in raw or '\x00' in raw:
        raise ValueError('Invalid input path.')
    posix=PurePosixPath(raw)
    if posix.is_absolute() or any(p in {'..','.',''} for p in raw.split('/')) or ':' in raw:
        raise ValueError('Invalid input path.')
    return Path(*posix.parts)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_files(folder: Path):
    if not folder.is_dir() or folder.is_symlink():
        raise ValueError('Required source directory unavailable.')
    for path in sorted(folder.rglob('*')):
        if path.is_symlink(): raise ValueError('Source symlinks are unsupported.')
        if path.is_file(): yield path, path.relative_to(folder)


def assemble(repo: Path, output: Path, debug_tests=False) -> dict:
    repo=repo.resolve();output=output.absolute()
    if output.exists() or output.is_symlink(): raise ValueError('Output must not exist; existing files are never replaced.')
    # Avoid copying an output back into itself or changing an input tree.
    if output == repo or any(output.is_relative_to(repo/p) for p in ('lib','android','phase02_assets')):
        raise ValueError('Output overlaps source inputs.')
    if output.parent.resolve()!=output.parent.absolute(): raise ValueError('Output parent must not be a symlink.')
    patches=[];input_hashes={}
    for name in PATCHES:
        data=(repo/name).read_bytes();input_hashes[name]=sha(data)
        patch=json.loads(data)
        if not isinstance(patch,dict): raise ValueError('Patch must be a path/text mapping.')
        entries=[]
        for raw,text in patch.items():
            path=relative(raw)
            if raw.startswith('android/signing') or raw=='android/key.properties' or not isinstance(text,str):
                raise ValueError('Forbidden patch target or value.')
            entries.append((path,text.encode('utf-8')))
        patches.append(entries)
    copies=[]
    for name,destination in [('lib','lib'),('android','android'),('phase02_assets','assets')]:
        copies.append((destination,list(source_files(repo/name))))
    base=repo/BASE
    # Streaming digest avoids loading the base archive into memory.
    with base.open('rb') as stream: input_hashes[BASE]=hashlib.file_digest(stream,'sha256').hexdigest()
    with zipfile.ZipFile(base) as archive:
        files=archive.infolist()
        if len(files)>20000 or sum(f.file_size for f in files)>MAX_EXPANDED: raise ValueError('Base archive exceeds assembly limits.')
        seen=set();members=[]
        for info in files:
            if '\x00' in info.orig_filename: raise ValueError('Invalid ZIP filename.')
            path=relative(info.filename.rstrip('/'))
            if path.parts[0]!='hyzen_flutter': raise ValueError('Unexpected base archive root.')
            if info.filename in seen: raise ValueError('Duplicate ZIP entry.')
            seen.add(info.filename)
            if stat.S_ISLNK(info.external_attr >> 16): raise ValueError('ZIP symlinks are unsupported.')
            if not info.is_dir():
                if len(path.parts)<2: raise ValueError('Invalid base file.')
                members.append((info,Path(*path.parts[1:])))
        output.mkdir(parents=False,exist_ok=False)
        for info,path in members:
            target=output/path;target.parent.mkdir(parents=True,exist_ok=True)
            with archive.open(info) as source,target.open('wb') as destination: shutil.copyfileobj(source,destination)
    for dest,files in copies[:2]:
        for source,path in files:
            target=output/dest/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    expected={}
    for entries in patches:
        for path,data in entries:
            target=output/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);expected[path.as_posix()]=sha(data)
    for dest,files in copies[2:]:
        for source,path in files:
            target=output/dest/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    if debug_tests:
        gradle=output/'android/app/build.gradle.kts';text=gradle.read_text()
        if text.count('testBuildType = "release"')!=1: raise ValueError('Expected review test configuration unavailable.')
        gradle.write_text(text.replace('testBuildType = "release"','testBuildType = "debug"'))
        expected['android/app/build.gradle.kts']=sha(gradle.read_bytes())
    for path,digest in expected.items():
        if sha((output/path).read_bytes())!=digest: raise ValueError('Final overlay was changed by asset/source assembly.')
    outputs={}
    for path in sorted(output.rglob('*')):
        if path.is_symlink(): raise ValueError('Unexpected output symlink.')
        if path.is_file(): outputs[path.relative_to(output).as_posix()]=sha(path.read_bytes())
    manifest={'format':1,'review_only':True,'debug_tests':debug_tests,'overlay_order':list(PATCHES),
              'inputs_sha256':input_hashes,'overlay_owned_paths':len(expected),'outputs_sha256':outputs}
    (output/'review_assembly_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,default=Path.cwd())
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--debug-tests',action='store_true',help='Review-only instrumentation setting; does not bypass release signing.')
    args=parser.parse_args(argv)
    try: report=assemble(args.repo,args.output,args.debug_tests)
    except (ValueError,OSError,zipfile.BadZipFile):
        parser.exit(1,'Assembly failed. Inputs were not modified; inspect any newly created partial output.\n')
    print(json.dumps({'assembled_files':len(report['outputs_sha256']),'overlay_owned_paths':report['overlay_owned_paths'],
                      'debug_tests':report['debug_tests'],'built':False,'deployed':False}))
    return 0


if __name__=='__main__':raise SystemExit(main())

