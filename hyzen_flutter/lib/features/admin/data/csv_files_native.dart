import 'package:flutter/services.dart';
import 'data_files.dart' as raw;
import '../domain/import_formats.dart';

class SelectedCsv {
  const SelectedCsv(this.name, this.text, [this.error]);
  final String name, text;
  final String? error;
}

const _channel = MethodChannel('com.hyzen.pharmd/csv_files');
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

Future<bool> saveCsvTemplate(String text) async =>
    await _channel.invokeMethod<bool>('saveCsvTemplate', {'text': text}) ??
    false;
