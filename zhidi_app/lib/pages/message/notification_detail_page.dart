import 'package:flutter/material.dart';

import '../../app/owner_models.dart';

class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.message});

  final OwnerMessage message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知详情')),
      backgroundColor: const Color(0xFFF7F7FB),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(color: Color(0xFF888888)),
                  ),
                  const Divider(height: 28),
                  Text(
                    message.content,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.task_alt, color: Color(0xFFFF6B35)),
              title: const Text('相关操作'),
              subtitle: Text(_actionSummary(message.category)),
            ),
          ),
        ],
      ),
    );
  }
}

String _actionSummary(String category) => switch (category) {
  '订单' || '预约' => '可前往“我的预约”查看订单进度与后续安排。',
  '工单' || '项目' => '可前往“我的家”查看施工进度与验收任务。',
  _ => '请根据通知内容完成相关确认，如有疑问可联系平台客服。',
};

String _formatTime(DateTime time) =>
    '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
