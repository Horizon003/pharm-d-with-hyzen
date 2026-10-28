import csv
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec=importlib.util.spec_from_file_location('preflight',Path(__file__).parents[1]/'quiz_csv_preflight.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
TAX={'schema_version':1,'years':{'2':{'subjects':{'pharm-id':{'topics':['insulin-id']}}}}}
ROW=['q-1','2','pharm-id','insulin-id','A private question, with comma\nand second line','Option one','Option two','Option three','Option four','B','Private explanation','easy','draft']
def data(rows,header=m.COLUMNS):
 s=io.StringIO(newline='');w=csv.writer(s);w.writerow(header);w.writerows(rows);return s.getvalue().encode()

class PreflightTests(unittest.TestCase):
 def test_bom_quoted_multiline_is_valid_and_report_contains_no_keys_or_content(self):
  r=m.preflight(b'\xef\xbb\xbf'+data([ROW]),TAX)
  self.assertTrue(r['valid']);self.assertEqual(1,r['valid_rows']);self.assertFalse(r['published'])
  output=json.dumps(r)
  for secret in [ROW[4],ROW[5],ROW[10],'correct_option','explanation']:
   self.assertNotIn(secret,output)
 def test_line_numbers_duplicates_and_revision_conflicts_are_explicit(self):
  r=m.preflight(data([ROW,ROW]),TAX,['q-1']);errors=r['errors']
  self.assertIn({'line':4,'field':'question_id','code':'duplicate_in_batch'},errors)
  self.assertIn({'line':2,'field':'question_id','code':'existing_id_requires_revision_review'},errors)
  self.assertFalse(r['valid'])
 def test_unknown_year_subject_topic_and_option_shape_fail(self):
  for field,value,code in [(1,'3','unknown_year'),(2,'invented','unknown_subject_for_year'),(3,'invented','unknown_topic_for_subject'),(9,'E','must_be_A_B_C_D')]:
   row=ROW.copy();row[field]=value;r=m.preflight(data([row]),TAX)
   self.assertIn(code,[e['code'] for e in r['errors']])
  row=ROW.copy();row[6]=row[5].upper();self.assertIn('options_must_be_distinct',[e['code'] for e in m.preflight(data([row]),TAX)['errors']])
 def test_headers_malformed_csv_utf8_and_limits_fail_closed(self):
  self.assertEqual('duplicate_column',m.preflight(data([],m.COLUMNS+('question',)),TAX)['errors'][0]['code'])
  self.assertFalse(m.preflight(b'\xff',TAX)['valid'])
  self.assertFalse(m.preflight(b'x'*(m.MAX_BYTES+1),TAX)['valid'])
  self.assertFalse(m.preflight(data([])+b'"unterminated',TAX)['valid'])
  self.assertFalse(m.preflight(data([]),TAX)['valid'])
  self.assertFalse(m.preflight(data([ROW+['extra']]),TAX)['valid'])
 def test_script_formula_and_limits_are_rejected_without_echoing_payload(self):
  for text,code in [(' <script>alert(1)</script>','html_not_allowed'),('=HYPERLINK("bad")','spreadsheet_formula_prefix'),('x'*8001,'too_long')]:
   row=ROW.copy();row[4]=text;r=m.preflight(data([row]),TAX)
   self.assertIn(code,[e['code'] for e in r['errors']]);self.assertNotIn(text,json.dumps(r))
 def test_active_rows_are_counted_but_never_published_and_taxonomy_required(self):
  row=ROW.copy();row[-1]='active';r=m.preflight(data([row]),TAX)
  self.assertTrue(r['valid']);self.assertEqual(1,r['active_rows_requiring_server_approval']);self.assertFalse(r['server_authorization_verified'])
  with self.assertRaises(ValueError):m.preflight(data([ROW]),{})
 def test_cli_does_not_write_inputs_or_hide_failures(self):
  with tempfile.TemporaryDirectory() as folder:
   path=Path(folder);bank=path/'bank.csv';tax=path/'taxonomy.json';bank.write_bytes(data([ROW]));tax.write_text(json.dumps(TAX));before=bank.read_bytes()
   run=subprocess.run([sys.executable,str(Path(m.__file__)),str(bank),'--taxonomy',str(tax)],capture_output=True,text=True)
   self.assertEqual(0,run.returncode);self.assertFalse(json.loads(run.stdout)['published']);self.assertEqual(before,bank.read_bytes())
   tax.write_text('not-json');run=subprocess.run([sys.executable,str(Path(m.__file__)),str(bank),'--taxonomy',str(tax)],capture_output=True,text=True)
   self.assertEqual(2,run.returncode);self.assertNotIn(ROW[4],run.stderr)

if __name__=='__main__':unittest.main()
