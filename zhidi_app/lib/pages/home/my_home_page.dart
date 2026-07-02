import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../chat/chat_page.dart';
import '../message/message_page.dart';
import '../profile/support_page.dart';
import '../project/project_pages.dart';
import 'worker/worker_detail_page.dart';

class _ProjectWorker {
  const _ProjectWorker(this.idSuffix, this.name, this.trade);
  final String idSuffix;
  final String name;
  final String trade;

  String get label => '$name · $trade';
  String idFor(String projectId) => '$projectId-worker-$idSuffix';
}

class _ProjectDashboardData {
  const _ProjectDashboardData({
    required this.members,
    required this.workers,
    required this.inspections,
    required this.archives,
    required this.progress,
  });

  final List<String> members;
  final List<_ProjectWorker> workers;
  final List<String> inspections;
  final List<String> archives;
  final List<String> progress;

  factory _ProjectDashboardData.forProject({
    required OwnerProject project,
    required OwnerProfile owner,
    required int projectIndex,
    required String Function(DateTime) formatDate,
  }) {
    final alternate = projectIndex.isOdd;
    final workers = alternate
        ? const [
            _ProjectWorker('electrician-chen', '陈师傅', '水电工'),
            _ProjectWorker('mason-zhao', '赵师傅', '瓦工'),
            _ProjectWorker('painter-sun', '孙师傅', '油漆工'),
          ]
        : const [
            _ProjectWorker('electrician-li', '李师傅', '水电工'),
            _ProjectWorker('mason-wang', '王师傅', '瓦工'),
            _ProjectWorker('carpenter-zhang', '张师傅', '木工'),
          ];
    final manager = alternate ? '郑工' : '周工';
    final designer = alternate ? '设计师宋女士' : '设计师林女士';
    final inspector = alternate ? '平台监理何工' : '平台监理陈工';
    final drawingCount = alternate ? 9 : 12;
    final contractCount = alternate ? 5 : 8;
    final recordCount = alternate ? 14 : 36;
    final reportCount = alternate ? 0 : 2;
    return _ProjectDashboardData(
      members: [
        '${owner.name} · 业主',
        '$manager · 项目经理',
        workers.first.label,
        designer,
        inspector,
      ],
      workers: workers,
      inspections: [
        '水电验收 · ${formatDate(project.startDate.add(const Duration(days: 15)))} · ${project.status}',
        '防水验收 · ${formatDate(project.startDate.add(const Duration(days: 20)))} · 待安排',
        '泥瓦验收 · 待安排',
      ],
      archives: [
        '施工图纸 · $drawingCount份',
        '合同文件 · $contractCount份',
        '施工记录 · $recordCount份',
        '验收报告 · $reportCount份',
      ],
      progress: [
        '设计方案 · ${alternate ? '待确认' : '已完成'}',
        '签约开工 · ${alternate ? '待开始' : '已完成'}',
        '当前项目状态 · ${project.status}',
        '瓦泥施工 · 待开始',
        '竣工验收 · 待开始',
      ],
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _notice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectProject(BuildContext context) async {
    final state = OwnerAppScope.of(context);
    final selected = await Navigator.push<OwnerProject>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectSelectionPage(
          projects: state.projects,
          selectedId: state.selectedProjectId,
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await state.selectProject(selected.id);
    } catch (_) {
      if (context.mounted) _notice(context, '切换失败，请重试');
    }
  }

  Future<void> _editProject(BuildContext context, OwnerProject project) async {
    final state = OwnerAppScope.of(context);
    final updated = await Navigator.push<OwnerProject>(
      context,
      MaterialPageRoute(builder: (_) => ProjectEditPage(project: project)),
    );
    if (updated == null || !context.mounted) return;
    try {
      await state.updateProject(updated);
      if (context.mounted) _notice(context, '项目已保存');
    } catch (_) {
      if (context.mounted) _notice(context, '保存失败，请重试');
    }
  }

  Future<void> _completeReminder(
    BuildContext context,
    OwnerReminder reminder,
  ) async {
    final state = OwnerAppScope.of(context);
    try {
      await state.completeReminder(reminder.id);
      if (context.mounted) _notice(context, '提醒已完成');
    } catch (_) {
      if (context.mounted) _notice(context, '操作失败，请重试');
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final project = state.selectedProject;
    if (project == null) {
      return const Center(child: Text('暂无项目，请先创建项目'));
    }
    final reminders = state.reminders
        .where((item) => item.projectId == null || item.projectId == project.id)
        .where((item) => !item.isCompleted)
        .toList();
    final nextDate = project.startDate.add(const Duration(days: 16));
    final projectIndex = state.projects.indexWhere(
      (item) => item.id == project.id,
    );
    final dashboard = _ProjectDashboardData.forProject(
      project: project,
      owner: state.profile,
      projectIndex: projectIndex < 0 ? 0 : projectIndex,
      formatDate: _date,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _TopBar(
            unread: state.unreadMessageCount,
            onNotifications: () => _push(
              context,
              Scaffold(
                appBar: AppBar(title: const Text('通知消息')),
                body: const MessagePage(),
              ),
            ),
          ),
          _section(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _selectProject(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 106,
                        height: 82,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.home_work_outlined,
                              color: Color(0xFFFF6B35),
                            ),
                            SizedBox(height: 6),
                            Text('切换项目', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  project.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _editProject(context, project),
                              ),
                            ],
                          ),
                          Text(
                            '${project.city} · ${project.address}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(project.status),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Action(
                      label: '项目成员',
                      suffix: '${dashboard.members.length}人',
                      icon: Icons.people_outline,
                      onTap: () => _push(
                        context,
                        ProjectInfoPage(
                          title: '项目成员',
                          description: '当前项目：${project.name}',
                          items: dashboard.members,
                        ),
                      ),
                    ),
                    _Action(
                      label: '项目群聊',
                      icon: Icons.chat_bubble_outline,
                      onTap: () => _push(
                        context,
                        ChatPage(workerName: '${project.name}项目群'),
                      ),
                    ),
                    _Action(
                      label: '项目设置',
                      icon: Icons.settings_outlined,
                      onTap: () =>
                          _push(context, ProjectSettingsPage(project: project)),
                    ),
                    _Action(
                      label: '分享家',
                      icon: Icons.share_outlined,
                      onTap: () => _notice(context, '项目分享信息已准备'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _section(
            title: '装修进度',
            action: '查看全部进度',
            onAction: () => _push(
              context,
              ProjectInfoPage(
                title: '装修进度',
                description: '当前项目：${project.name}',
                items: dashboard.progress,
              ),
            ),
            child: const LinearProgressIndicator(value: .42, minHeight: 8),
          ),
          _section(
            title: '今日提醒',
            badge: '${reminders.length}项待处理',
            child: reminders.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('今日事项已处理完成')),
                  )
                : Column(
                    children: [
                      for (final reminder in reminders)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.notifications_active_outlined),
                          ),
                          title: Text(reminder.title),
                          subtitle: Text('截止：${_date(reminder.dueAt)}'),
                          trailing: TextButton(
                            onPressed: () =>
                                _completeReminder(context, reminder),
                            child: const Text('完成'),
                          ),
                        ),
                    ],
                  ),
          ),
          _section(
            title: '下一步计划',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.construction)),
              title: const Text('瓦泥施工'),
              subtitle: Text('预计开始：${_date(nextDate)}'),
              trailing: TextButton(
                onPressed: () => _push(
                  context,
                  ProjectInfoPage(
                    title: '下一步计划',
                    description: '水电验收通过后进入瓦泥施工，预计 ${_date(nextDate)} 开始。',
                    items: const ['确认水电验收结果', '材料进场核验', '安排瓦工施工'],
                  ),
                ),
                child: const Text('查看下一步'),
              ),
            ),
          ),
          _section(
            title: '我的工人',
            action: '查看全部工人',
            onAction: () => _push(
              context,
              _ProjectWorkersPage(project: project, workers: dashboard.workers),
            ),
            child: Column(
              children: [
                for (final worker in dashboard.workers)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(worker.label),
                    onTap: () => _push(
                      context,
                      WorkerDetailPage(
                        workerId: worker.idFor(project.id),
                        name: worker.name,
                        workerJob: worker.trade,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          _push(context, ChatPage(workerName: worker.name)),
                      child: const Text('联系'),
                    ),
                  ),
              ],
            ),
          ),
          _section(
            title: '平台验收',
            action: '查看验收记录',
            onAction: () => _push(
              context,
              ProjectInfoPage(
                title: '验收记录',
                description: '当前项目：${project.name}',
                items: dashboard.inspections,
              ),
            ),
            child: const Text('平台监理按节点留存验收记录，不达标项目将记录整改。'),
          ),
          _section(
            title: '装修档案',
            action: '查看全部档案',
            onAction: () => _push(
              context,
              ProjectInfoPage(
                title: '装修档案',
                description: '当前项目：${project.name}',
                items: dashboard.archives,
              ),
            ),
            child: Wrap(
              spacing: 8,
              children: [
                for (final archive in dashboard.archives.take(2))
                  Chip(label: Text(archive.replaceFirst(' · ', ' '))),
                Chip(
                  label: Text(dashboard.archives.last.replaceFirst(' · ', ' ')),
                ),
              ],
            ),
          ),
          _section(
            title: '资金托管',
            action: '了解资金托管',
            onAction: () => _push(
              context,
              const ProjectInfoPage(
                title: '资金托管说明',
                description: '本页仅说明平台托管流程，不展示虚构余额，也不模拟付款。实际款项以订单、合同和支付机构记录为准。',
                items: ['签约后查看真实订单金额', '按合同节点申请验收', '验收确认后按协议处理款项'],
              ),
            ),
            child: const Text('了解平台托管流程与节点验收规则'),
          ),
          _section(
            title: '售后保障',
            action: '申请售后',
            onAction: () => _push(context, const SupportPage()),
            child: const Text('服务留痕 · 验收记录 · 售后协助'),
          ),
        ],
      ),
    );
  }

  Widget _section({
    String? title,
    String? action,
    String? badge,
    VoidCallback? onAction,
    required Widget child,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
    child: Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Text(
                      badge,
                      style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 12,
                      ),
                    ),
                  if (action != null)
                    TextButton(onPressed: onAction, child: Text(action)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}

class _ProjectWorkersPage extends StatelessWidget {
  const _ProjectWorkersPage({required this.project, required this.workers});
  final OwnerProject project;
  final List<_ProjectWorker> workers;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('全部工人')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('当前项目：${project.name}'),
        const SizedBox(height: 8),
        for (final worker in workers)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(worker.label),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkerDetailPage(
                    workerId: worker.idFor(project.id),
                    name: worker.name,
                    workerJob: worker.trade,
                  ),
                ),
              ),
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatPage(workerName: worker.name),
                  ),
                ),
                child: const Text('联系'),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.unread, required this.onNotifications});
  final int unread;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    child: Row(
      children: [
        const Spacer(),
        const Text(
          '我的家',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: IconButton(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_outlined),
          ),
        ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.suffix,
  });
  final String label;
  final String? suffix;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
          if (suffix != null)
            Text(
              suffix!,
              style: const TextStyle(fontSize: 10, color: Color(0xFFFF6B35)),
            ),
        ],
      ),
    ),
  );
}
