import importlib.util,json,tempfile,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('release_evidence',Path(__file__).parents[1]/'release_evidence.py')
release=importlib.util.module_from_spec(spec);spec.loader.exec_module(release)
class ReleaseEvidenceTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
  root=Path(self.temp.name);self.source=root/'source';self.output=root/'release'
  self.source.mkdir();self.output.mkdir();(self.source/'lib').mkdir();(self.source/'lib/main.dart').write_text('built source')
  for p in ['pubspec.yaml','pubspec.lock']:(self.source/p).write_text('fixture')
  (self.source/'review_assembly_manifest.json').write_text(json.dumps({'debug_tests':False,'inputs_sha256':{'fixture':'abc'}}))
  (self.output/'PharmD-With-Hyzen.apk').write_bytes(b'fixture APK')
  (self.output/'signing-report.txt').write_text('Signer #1 certificate SHA-256 digest: '+release.CERT+'\n')
 def run_evidence(self):return release.evidence(self.source,self.output,'a'*40,'1.5.0','12')
 def test_records_actual_built_bytes_and_detects_tampered_apk(self):
  value=self.run_evidence();self.assertEqual(value['normalized_source_sha256']['lib/main.dart'],release.digest(self.source/'lib/main.dart'))
  original=value['apk_sha256'];(self.output/'PharmD-With-Hyzen.apk').write_bytes(b'changed');self.assertNotEqual(original,release.digest(self.output/'PharmD-With-Hyzen.apk'))
  self.assertIn(original,(self.output/'SHA256SUMS').read_text())
 def test_wrong_multiple_or_missing_signer_rejected(self):
  for report in ['', 'Signer #1 certificate SHA-256 digest: '+'b'*64, 'Signer #1 certificate SHA-256 digest: '+release.CERT+'\nSigner #2 certificate SHA-256 digest: '+release.CERT]:
   (self.output/'signing-report.txt').write_text(report)
   with self.assertRaises(AssertionError):self.run_evidence()
 def test_debug_source_rejected(self):
  (self.source/'review_assembly_manifest.json').write_text('{"debug_tests":true}')
  with self.assertRaises(AssertionError):self.run_evidence()
 def test_v2_signer_report_from_current_android_tool(self):
  (self.output/'signing-report.txt').write_text('V2 Signer: certificate SHA-256 digest: '+release.CERT+'\n')
  self.assertEqual(self.run_evidence()['certificate_sha256'],release.CERT)
