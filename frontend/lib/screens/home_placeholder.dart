// lib/screens/home_placeholder.dart

import 'package:flutter/material.dart';
import '../core/widgets/page_header.dart';

class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: const PageHeader(
          section: 'Home',
          title: 'Trang chủ',
          subtitle: 'Giới thiệu tổng quan',
        ),
      ),
    );
  }
}
