// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> downloadCsv(List<int> bytes, String filename) async {
  final url = html.Url.createObjectUrlFromBlob(
    html.Blob([bytes], 'text/csv;charset=utf-8'),
  );
  html.AnchorElement(href: url)..download = filename..click();
  html.Url.revokeObjectUrl(url);
}
