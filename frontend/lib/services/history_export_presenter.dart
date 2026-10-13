import 'history_export_presenter_stub.dart'
    if (dart.library.io) 'history_export_presenter_io.dart'
    if (dart.library.html) 'history_export_presenter_web.dart'
    as platform;
import 'history_export_service.dart';

Future<void> presentHistoryExport(HistoryExportFile file) =>
    platform.presentHistoryExport(file);
