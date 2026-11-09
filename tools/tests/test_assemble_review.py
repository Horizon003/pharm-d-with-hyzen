import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

spec=importlib.util.spec_from_file_location('assemble',Path(__file__).parents[1]/'assemble_review.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class AssemblyTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.repo=self.root/'repo';self.repo.mkdir();self.out=self.root/'assembled'
  for name in ['lib','android/app','phase02_assets/fonts']:(self.repo/name).mkdir(parents=True,exist_ok=True)
  (self.repo/'lib/a.dart').write_text('root source');(self.repo/'android/app/build.gradle.kts').write_text('testBuildType = "release"\nrelease guard retained')
  (self.repo/'phase02_assets/fonts/test.ttf').write_bytes(b'font')
  for i,name in enumerate(m.PATCHES):(self.repo/name).write_text(json.dumps({'lib/a.dart':f'patch {i}'}))
  with zipfile.ZipFile(self.repo/m.BASE,'w') as z:z.writestr('hyzen_flutter/lib/a.dart','base');z.writestr('hyzen_flutter/pubspec.yaml','name: fixture')
 def test_order_binary_assets_and_manifest_are_reproducible(self):
  a=m.assemble(self.repo,self.out);b=m.assemble(self.repo,self.root/'again')
  self.assertEqual(a,b);self.assertEqual(f'patch {len(m.PATCHES)-1}',(self.out/'lib/a.dart').read_text());self.assertEqual(b'font',(self.out/'assets/fonts/test.ttf').read_bytes())
  self.assertTrue(a['review_only']);self.assertFalse(a['debug_tests']);self.assertEqual(1,a['overlay_owned_paths'])
 def test_existing_output_is_never_overwritten(self):
  self.out.mkdir();marker=self.out/'my-notes';marker.write_text('keep')
  with self.assertRaises(ValueError):m.assemble(self.repo,self.out)
  self.assertEqual('keep',marker.read_text())
 def test_patch_escape_signing_and_wrong_value_rejected_before_output(self):
  for path,value in [('lib//a.dart','bad'),('lib/./a.dart','bad'),('../outside','bad'),('/absolute','bad'),('android/key.properties','bad'),('android/signing/key','bad'),('lib/a.dart',123)]:
   (self.repo/m.PATCHES[-1]).write_text(json.dumps({path:value}))
   with self.assertRaises(ValueError):m.assemble(self.repo,self.out)
   self.assertFalse(self.out.exists())
 def test_zip_escape_and_symlink_are_rejected(self):
  for name in ['hyzen_flutter/../../outside','/absolute']:
   with zipfile.ZipFile(self.repo/m.BASE,'w') as z:z.writestr(name,'bad')
   with self.assertRaises(ValueError):m.assemble(self.repo,self.out)
   self.assertFalse(self.out.exists())
  with zipfile.ZipFile(self.repo/m.BASE,'w') as z:
   entry=zipfile.ZipInfo('hyzen_flutter/linked');entry.create_system=3;entry.external_attr=(0o120777<<16);z.writestr(entry,'/outside')
  with self.assertRaises(ValueError):m.assemble(self.repo,self.out)
 def test_source_symlink_and_output_inside_input_rejected(self):
  (self.repo/'lib/linked').symlink_to(self.repo/'lib/a.dart')
  with self.assertRaises(ValueError):m.assemble(self.repo,self.out)
  (self.repo/'lib/linked').unlink()
  with self.assertRaises(ValueError):m.assemble(self.repo,self.repo/'lib/output')
 def test_debug_test_mode_changes_only_review_setting(self):
  report=m.assemble(self.repo,self.out,True)
  self.assertTrue(report['debug_tests']);self.assertIn('testBuildType = "debug"',(self.out/'android/app/build.gradle.kts').read_text());self.assertIn('release guard retained',(self.out/'android/app/build.gradle.kts').read_text());self.assertIn('release',(self.repo/'android/app/build.gradle.kts').read_text())

if __name__=='__main__':unittest.main()
