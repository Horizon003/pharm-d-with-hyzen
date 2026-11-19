import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class SelectedDataFile {
  const SelectedDataFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

Future<List<SelectedDataFile>> pickDataFiles() {
  final result = Completer<List<SelectedDataFile>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv,.json,.xlsx'
    ..multiple = true;
  input.style.display = 'none';
  web.document.body?.append(input);
  void finish(List<SelectedDataFile> files) {
    if (!result.isCompleted) result.complete(files);
    input.remove();
  }

  input.addEventListener('cancel', ((web.Event _) => finish([])).toJS);
  input.addEventListener(
    'change',
    ((web.Event _) {
      () async {
        try {
          final files = input.files;
          final selected = <SelectedDataFile>[];
          if ((files?.length ?? 0) > 20) {
            throw StateError('Choose at most 20 data files.');
          }
          for (var i = 0; i < (files?.length ?? 0); i++) {
            final f = files!.item(i)!;
            if (f.size > 25 * 1024 * 1024) {
              throw StateError('Each file must be 25 MB or smaller.');
            }
            selected.add(
              SelectedDataFile(
                f.name,
                (await f.arrayBuffer().toDart).toDart.asUint8List(),
              ),
            );
          }
          finish(selected);
        } catch (e, st) {
          input.remove();
          if (!result.isCompleted) result.completeError(e, st);
        }
      }();
    }).toJS,
  );
  input.click();
  return result.future;
}

Future<bool> saveDataText(String name, String text, String mime) async {
  final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(link);
  link.click();
  link.remove();
  Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  return true;
}

Future<bool> saveDataBytes(String name, Uint8List bytes, String mime) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(link);
  link.click();
  link.remove();
  Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  return true;
}
