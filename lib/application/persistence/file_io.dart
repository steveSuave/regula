import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../domain/construction/construction.dart';
import '../providers/document_settings_provider.dart';
import '../providers/viewport_provider.dart';
import 'construction_codec.dart';

/// File name offered by the save dialog (and used verbatim by the web
/// download). Plain `.json` — the format is ordinary JSON and this keeps
/// the file openable everywhere without OS file-type registration.
const String defaultConstructionFileName = 'construction.json';

const List<String> _allowedExtensions = ['json'];

/// Serializes [construction] + [viewport] + [settings] and hands the bytes
/// to the platform's save dialog (a download on the web). Completes when
/// the dialog does; a cancelled dialog is not an error.
Future<void> saveConstructionFile(
  Construction construction, {
  required ViewportState viewport,
  DocumentSettings settings = const DocumentSettings(),
}) async {
  final json = encodeDocument(
    construction,
    viewport: viewport,
    settings: settings,
  );
  final bytes = Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
  );
  await FilePicker.saveFile(
    dialogTitle: 'Save construction',
    fileName: defaultConstructionFileName,
    type: FileType.custom,
    allowedExtensions: _allowedExtensions,
    bytes: bytes,
  );
}

/// File name offered for a PNG export.
const String defaultExportPngFileName = 'construction.png';

/// Hands already-encoded PNG [bytes] to the platform's save dialog (a
/// download on the web). Completes when the dialog does; a cancelled
/// dialog is not an error.
Future<void> savePngBytes(Uint8List bytes) async {
  await FilePicker.saveFile(
    dialogTitle: 'Export as PNG',
    fileName: defaultExportPngFileName,
    type: FileType.custom,
    allowedExtensions: const ['png'],
    bytes: bytes,
  );
}

/// Shows the platform's open dialog and decodes the picked file.
///
/// Returns null when the user cancels. Throws [FormatException] for
/// anything wrong with the file itself — invalid UTF-8, invalid JSON, or
/// a document [decodeDocument] rejects — so callers show one dialog for
/// any bad file.
Future<DecodedDocument?> openConstructionFile() async {
  final result = await FilePicker.pickFiles(
    dialogTitle: 'Open construction',
    type: FileType.custom,
    allowedExtensions: _allowedExtensions,
    withData: true,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  final bytes = result.files.single.bytes;
  if (bytes == null) {
    throw const FormatException('Could not read the selected file');
  }
  final Object? json = jsonDecode(utf8.decode(bytes));
  if (json is! Map<String, dynamic>) {
    throw const FormatException('Not a construction file');
  }
  return decodeDocument(json);
}
