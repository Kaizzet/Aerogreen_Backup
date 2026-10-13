// lib/screens/help_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/page_header.dart';
import '../core/widgets/section_chip.dart';
import '../core/theme/app_colors.dart';

/// Help & Support screen – FAQ accordion and a placeholder chat button.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                chip: SectionChip(label: 'Trợ giúp'),
                title: 'Hỗ trợ',
                subtitle: '',
              ),
              const SizedBox(height: 24),
              const _FaqAccordion(),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Placeholder for future chat integration.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat chưa được tích hợp')),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat với chúng tôi'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple FAQ accordion using ExpansionPanelList.
class _FaqAccordion extends StatefulWidget {
  const _FaqAccordion();

  @override
  State<_FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<_FaqAccordion> {
  final List<_FaqItem> _items = [
    _FaqItem(question: 'Cách thêm cây mới?', answer: 'Vào tab "Cây" → nhấn nút "+" và điền thông tin cây.'),
    _FaqItem(question: 'Cách thiết lập cảnh báo?', answer: 'Vào tab "Khác" → "Thông báo" và bật các công tắc cảnh báo.'),
    _FaqItem(question: 'Làm sao thay đổi đơn vị?', answer: 'Vào tab "Khác" → "Tùy chỉnh" để chọn đơn vị và ngôn ngữ.'),
    _FaqItem(question: 'Thu hoạch đã qua?', answer: 'Xem lịch sử thu hoạch trong tab "Lịch sử thu hoạch".'),
  ];

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList.radio(
      expandedHeaderPadding: const EdgeInsets.symmetric(vertical: 4),
      children: _items.map<ExpansionPanelRadio>((_FaqItem item) {
        return ExpansionPanelRadio(
          value: item.question,
          headerBuilder: (context, isExpanded) => ListTile(
            title: Text(item.question, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(item.answer),
          ),
        );
      }).toList(),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  _FaqItem({required this.question, required this.answer});
}
