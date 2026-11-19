import 'package:flutter/services.dart';

class SelectedDataFile {
  const SelectedDataFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

const _files = MethodChannel('com.hyzen.pharmd/csv_files');
Future<List<SelectedDataFile>> pickDataFiles() async {
  final files = await _files.invokeListMethod<dynamic>('pickDataFiles');
  return [
    for (final f in files ?? [])
      SelectedDataFile(f['name'] as String, f['bytes'] as Uint8List),
  ];
}

Future<bool> saveDataText(String name, String text, String mime) async =>
    await _files.invokeMethod<bool>('saveFile', {
      'name': name,
      'text': text,
      'mime': mime,
    }) ??
    false;

Future<bool> saveDataBytes(String name, Uint8List bytes, String mime) async =>
    await _files.invokeMethod<bool>('saveFile', {
      'name': name,
      'bytes': bytes,
      'mime': mime,
    }) ??
    false;
