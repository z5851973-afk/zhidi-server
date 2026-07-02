import 'package:flutter/material.dart';

import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../home/worker/worker_detail_page.dart';
import '../home/worker/worker_list_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final Set<String> _removing = {};

  Future<void> _remove(FavoriteWorker worker) async {
    setState(() => _removing.add(worker.id));
    try {
      await OwnerAppScope.of(context).toggleFavorite(worker);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('取消收藏失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _removing.remove(worker.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final workers = OwnerAppScope.of(context).favoriteWorkers;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        title: const Text(
          '我的收藏',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
      ),
      body: workers.isEmpty
          ? _EmptyFavorites(
              onDiscover: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkerListPage()),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: workers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final worker = workers[index];
                final removing = _removing.contains(worker.id);
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEEE3),
                      child: Icon(
                        Icons.person_rounded,
                        color: Color(0xFFFF6A1A),
                      ),
                    ),
                    title: Text(
                      worker.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${worker.trade} · ${worker.city}'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkerDetailPage(
                          workerId: worker.id,
                          name: worker.name,
                          workerJob: worker.trade,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      key: Key('remove-favorite-${worker.id}'),
                      tooltip: '取消收藏',
                      onPressed: removing ? null : () => _remove(worker),
                      icon: removing
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.onDiscover});

  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.favorite_border_rounded,
          size: 54,
          color: Color(0xFFBBBBBB),
        ),
        const SizedBox(height: 12),
        const Text(
          '暂无收藏',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onDiscover, child: const Text('去发现师傅')),
      ],
    ),
  );
}
