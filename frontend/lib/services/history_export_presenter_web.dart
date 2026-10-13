// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'history_export_service.dart';

Future<void> presentHistoryExport(HistoryExportFile file) async {
  final blob = html.Blob([file.bytes], file.mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..download = file.fileName
      ..click();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
