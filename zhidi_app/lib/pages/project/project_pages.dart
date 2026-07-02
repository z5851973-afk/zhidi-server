import 'package:flutter/material.dart';

import '../../app/owner_models.dart';

class ProjectSelectionPage extends StatelessWidget {
  const ProjectSelectionPage({
    super.key,
    required this.projects,
    this.selectedId,
  });
  final List<OwnerProject> projects;
  final String? selectedId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('选择项目')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final project in projects)
          Card(
            child: ListTile(
              title: Text(project.name),
              subtitle: Text('${project.city} · ${project.address}'),
              trailing: project.id == selectedId
                  ? const Icon(Icons.check_circle, color: Color(0xFFFF6B35))
                  : null,
              onTap: () => Navigator.pop(context, project),
            ),
          ),
      ],
    ),
  );
}

class ProjectEditPage extends StatefulWidget {
  const ProjectEditPage({super.key, required this.project});
  final OwnerProject project;

  @override
  State<ProjectEditPage> createState() => _ProjectEditPageState();
}

class _ProjectEditPageState extends State<ProjectEditPage> {
  late final TextEditingController _name = TextEditingController(
    text: widget.project.name,
  );
  late final TextEditingController _address = TextEditingController(
    text: widget.project.address,
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('编辑项目')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            key: const Key('project-name-field'),
            controller: _name,
            decoration: const InputDecoration(labelText: '项目名称'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入项目名称' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(labelText: '项目地址'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                widget.project.copyWith(
                  name: _name.text.trim(),
                  address: _address.text.trim(),
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

class ProjectInfoPage extends StatelessWidget {
  const ProjectInfoPage({
    super.key,
    required this.title,
    required this.items,
    this.description,
  });
  final String title;
  final String? description;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (description != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(description!),
            ),
          ),
        for (final item in items)
          Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(item),
            ),
          ),
      ],
    ),
  );
}

class ProjectSettingsPage extends StatelessWidget {
  const ProjectSettingsPage({super.key, required this.project});
  final OwnerProject project;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('项目设置')),
    body: ListView(
      children: [
        ListTile(title: const Text('项目名称'), trailing: Text(project.name)),
        ListTile(title: const Text('所在城市'), trailing: Text(project.city)),
        const SwitchListTile(
          value: true,
          onChanged: null,
          title: Text('接收项目进度通知'),
        ),
      ],
    ),
  );
}
