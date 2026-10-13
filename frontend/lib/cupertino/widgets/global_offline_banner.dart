import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../services/connectivity_service.dart';

class GlobalOfflineBanner extends StatelessWidget {
  final Widget child;

  const GlobalOfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService?>();
    final isOffline = connectivity?.isOffline ?? false;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          if (isOffline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Semantics(
                  container: true,
                  label: 'Cảnh báo mất kết nối mạng. Bạn đang offline. Hiển thị dữ liệu gần nhất.',
                  liveRegion: true,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100), // High-contrast amber/orange
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          CupertinoIcons.wifi_slash,
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bạn đang offline. Hiển thị dữ liệu gần nhất.',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
