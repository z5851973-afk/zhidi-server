import 'package:flutter/material.dart';
import '../../app/owner_app_scope.dart';
import '../../app/owner_models.dart';
import '../../design/tokens.dart';

const _primary = ZdColors.primary;
const _primaryBg = Color(0xFFFFF7F0);
const _textDark = ZdColors.textPrimary;
const _textMid = Color(0xFF666666);
const _textLight = ZdColors.textSecondary;
const _bg = ZdColors.background;
const _cardBg = Colors.white;
const _green = Color(0xFF4CAF50);
const _greenBg = Color(0xFFE8F5E9);
const _divider = Color(0xFFEEEEEE);

class RenovationArchivePage extends StatelessWidget {
  const RenovationArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final archives = state.archives.toList()
      ..sort((a, b) => b.phaseIndex.compareTo(a.phaseIndex));

    final allPhases = const ['打拆', '水电', '防水', '泥工', '木工', '美缝', '安装', '清洁'];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          '装修档案',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _cardBg,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _textDark),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          // ── 概要卡片 ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primaryBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_special,
                    color: _primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '麓湖新居翻新',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '已完成 ${archives.length}/${allPhases.length} 道工序',
                        style: const TextStyle(fontSize: 13, color: _textMid),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _greenBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    archives.length == allPhases.length ? '已完工' : '施工中',
                    style: TextStyle(
                      fontSize: 12,
                      color: archives.length == allPhases.length
                          ? _green
                          : _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── 工序进度条 ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '工序总览',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 14),
                for (int i = 0; i < allPhases.length; i++) ...[
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Column(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: i < archives.length
                                      ? _green
                                      : const Color(0xFFE8E8E8),
                                  shape: BoxShape.circle,
                                ),
                                child: i < archives.length
                                    ? const Icon(
                                        Icons.check,
                                        size: 13,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: i == archives.length
                                              ? _primary
                                              : _textLight,
                                        ),
                                      ),
                              ),
                              if (i < allPhases.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    color: i < archives.length
                                        ? _green
                                        : _divider,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: i < allPhases.length - 1 ? 16 : 0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allPhases[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: i < archives.length
                                        ? _textMid
                                        : (i == archives.length
                                              ? _primary
                                              : _textLight),
                                    fontWeight: i == archives.length
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (i < archives.length)
                                  Text(
                                    archives
                                        .firstWhere((a) => a.phaseIndex == i)
                                        .workerName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _textLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (i < archives.length)
                          Text(
                            '${archives.firstWhere((a) => a.phaseIndex == i).completedAt.month}/${archives.firstWhere((a) => a.phaseIndex == i).completedAt.day}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (archives.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              ' 各工序档案',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 10),
            for (final arch in archives) _ArchiveCard(archive: arch),
          ],
        ],
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.archive});
  final RenovationArchive archive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 头部 ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: _greenBg),
              child: Row(
                children: [
                  if (archive.avatarEmoji != null)
                    Text(
                      archive.avatarEmoji!,
                      style: const TextStyle(fontSize: 22),
                    ),
                  if (archive.avatarEmoji != null) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          archive.phaseName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${archive.workerName} · ${archive.trade}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textMid,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: _green,
                            ),
                            const SizedBox(width: 2),
                            const Text(
                              '验收合格',
                              style: TextStyle(
                                fontSize: 12,
                                color: _green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${archive.completedAt.month}月${archive.completedAt.day}日完工',
                        style: const TextStyle(fontSize: 11, color: _textLight),
                      ),
                      if (archive.rating != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Color(0xFFFFB800),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${archive.rating!.toStringAsFixed(1)}分',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFFB800),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 施工周期 ──
                  if (archive.startedAt != null) ...[
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: '施工周期',
                      value:
                          '${archive.startedAt!.month}/${archive.startedAt!.day} — ${archive.completedAt.month}/${archive.completedAt.day} '
                          '（${archive.completedAt.difference(archive.startedAt!).inDays}天）',
                    ),
                    const SizedBox(height: 10),
                  ],
                  // ── 技能标签 ──
                  if (archive.skills.isNotEmpty) ...[
                    _InfoRow(
                      icon: Icons.build_outlined,
                      label: '施工内容',
                      value: '',
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: archive.skills
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ZdColors.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textMid,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // ── 日报记录 ──
                  if (archive.dailyNotes.isNotEmpty) ...[
                    _InfoRow(
                      icon: Icons.menu_book_outlined,
                      label: '施工日报',
                      value: '',
                    ),
                    const SizedBox(height: 6),
                    ...archive.dailyNotes.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.key + 1}.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textLight,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textMid,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // ── 现场照片 ──
                  if (archive.photoUrls.isNotEmpty) ...[
                    _InfoRow(
                      icon: Icons.photo_library_outlined,
                      label: '现场照片',
                      value: '${archive.photoUrls.length}张',
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: archive.photoUrls.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                backgroundColor: Colors.black,
                                appBar: AppBar(
                                  backgroundColor: Colors.black,
                                  iconTheme: const IconThemeData(
                                    color: Colors.white,
                                  ),
                                ),
                                body: Center(
                                  child: InteractiveViewer(
                                    child: Image.network(
                                      archive.photoUrls[i],
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) =>
                                          const _ArchiveImagePlaceholder(
                                            expanded: true,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              archive.photoUrls[i],
                              width: 140,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const _ArchiveImagePlaceholder(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // ── 验收意见 ──
                  if (archive.inspectionNote != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _greenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified, size: 16, color: _green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '验收意见',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  archive.inspectionNote!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textMid,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveImagePlaceholder extends StatelessWidget {
  const _ArchiveImagePlaceholder({this.expanded = false});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? double.infinity : 140,
      height: expanded ? double.infinity : 100,
      color: expanded ? Colors.black26 : const Color(0xFFF0EBE6),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: expanded ? Colors.white70 : _textLight,
        size: expanded ? 44 : 24,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _textLight),
        const SizedBox(width: 6),
        Text(
          '$label${value.isNotEmpty ? '  $value' : ''}',
          style: TextStyle(
            fontSize: 12,
            color: value.isNotEmpty ? _textMid : _textLight,
          ),
        ),
      ],
    );
  }
}
