import 'data_files.dart' as raw;
import '../domain/import_formats.dart';
import 'package:web/web.dart' as web;

class SelectedCsv {
  const SelectedCsv(this.name, this.text, [this.error]);
  final String name, text;
  final String? error;
}

Future<List<SelectedCsv>> pickCsvFiles() async {
  final files = await raw.pickDataFiles();
  return files.map((file) {
    try {
      return SelectedCsv(file.name, dataFileCsv(file.name, file.bytes));
    } catch (error) {
      return SelectedCsv(file.name, '', '${file.name}: $error');
    }
  }).toList();
}

Future<bool> saveCsvTemplate(String text) async {
  final uri = 'data:text/csv;charset=utf-8,${Uri.encodeComponent(text)}';
  final link = web.HTMLAnchorElement()
    ..href = uri
    ..download = 'hyzen_bulk_import_template.csv';
  link.click();
  return true;
}
