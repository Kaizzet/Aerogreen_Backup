import 'package:share_plus/share_plus.dart';

import 'history_export_service.dart';

Future<void> presentHistoryExport(HistoryExportFile file) =>
    SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            file.bytes,
            mimeType: file.mimeType,
            name: file.fileName,
          ),
        ],
        fileNameOverrides: [file.fileName],
      ),
    );
