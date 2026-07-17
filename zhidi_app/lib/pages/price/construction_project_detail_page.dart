import 'package:flutter/material.dart';

import '../../design/tokens.dart';

class ConstructionProjectDetailPage extends StatelessWidget {
  const ConstructionProjectDetailPage({super.key, required this.project});

  const ConstructionProjectDetailPage.wallDemolition({super.key})
    : project = _wallDemolitionProject;

  final ConstructionProjectData project;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZdColors.background,
      appBar: AppBar(
        title: Text(project.title),
        centerTitle: true,
        backgroundColor: ZdColors.background,
        foregroundColor: ZdColors.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBar: _BottomQuoteBar(project: project),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 118),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProjectHeroSection(project: project),
            const SizedBox(height: 18),
            _StandardPriceSection(project: project),
            const SizedBox(height: 18),
            _PriceReasonSection(project: project),
            const SizedBox(height: 18),
            _ConstructionStepsSection(steps: project.steps),
            const SizedBox(height: 18),
            _ProjectCaseSection(project: project),
            const SizedBox(height: 18),
            _GuaranteeGridSection(guarantees: project.guarantees),
          ],
        ),
      ),
    );
  }
}

class ConstructionProjectData {
  const ConstructionProjectData({
    required this.title,
    required this.subtitle,
    required this.priceRange,
    required this.heroImage,
    required this.tags,
    required this.priceOptions,
    required this.includes,
    required this.excludes,
    required this.priceReasons,
    required this.steps,
    required this.casePhotos,
    required this.caseLocation,
    required this.caseTime,
    required this.guarantees,
  });

  final String title;
  final String subtitle;
  final String priceRange;
  final String heroImage;
  final List<String> tags;
  final List<ProjectPriceOption> priceOptions;
  final List<String> includes;
  final List<String> excludes;
  final List<String> priceReasons;
  final List<ProjectStep> steps;
  final List<ProjectCasePhoto> casePhotos;
  final String caseLocation;
  final String caseTime;
  final List<ProjectGuarantee> guarantees;
}

class ProjectPriceOption {
  const ProjectPriceOption({
    required this.name,
    required this.price,
    required this.description,
  });

  final String name;
  final String price;
  final String description;
}

class ProjectStep {
  const ProjectStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;
}

class ProjectCasePhoto {
  const ProjectCasePhoto({required this.label, required this.imageAsset});

  final String label;
  final String imageAsset;
}

class ProjectGuarantee {
  const ProjectGuarantee({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _wallDemolitionProject = ConstructionProjectData(
  title: '墙体拆除',
  subtitle: '装修第一步，拆对才能装好',
  priceRange: '¥38-55/㎡',
  heroImage: 'assets/images/trades/demolition_banner.jpg',
  tags: ['明码标价', '工艺透明', '平台验收'],
  priceOptions: [
    ProjectPriceOption(
      name: '12墙拆除',
      price: '¥38/㎡',
      description: '轻质隔墙、普通非承重墙拆改',
    ),
    ProjectPriceOption(
      name: '24墙拆除',
      price: '¥45/㎡',
      description: '常规砖墙拆除，需做好边口保护',
    ),
    ProjectPriceOption(
      name: '37墙拆除',
      price: '¥55/㎡',
      description: '厚墙体拆除，施工强度和清理量更高',
    ),
  ],
  includes: ['人工拆除', '基础保护', '垃圾整理'],
  excludes: ['垃圾外运', '特殊墙体处理'],
  priceReasons: [
    '墙体厚度不同，拆除强度、切割时间和清理量不同。',
    '拆除前需要确认非承重结构，并对周边墙面、地面做基础保护。',
    '小区垃圾外运、电梯使用、建渣堆放距离会影响最终现场费用。',
  ],
  steps: [
    ProjectStep(number: '01', title: '定位', description: '确认拆除范围和尺寸'),
    ProjectStep(number: '02', title: '切割', description: '沿线切割，保护周边结构'),
    ProjectStep(number: '03', title: '拆除', description: '分区域施工，避免暴力破坏'),
    ProjectStep(number: '04', title: '清理', description: '现场恢复，垃圾整理'),
  ],
  casePhotos: [
    ProjectCasePhoto(
      label: '施工前',
      imageAsset: 'assets/images/trades/demolition_banner.jpg',
    ),
    ProjectCasePhoto(
      label: '施工过程',
      imageAsset: 'assets/images/trades/demolition.jpg',
    ),
    ProjectCasePhoto(
      label: '施工完成',
      imageAsset: 'assets/images/trades/demolition_banner.jpg',
    ),
  ],
  caseLocation: '成都·金牛区',
  caseTime: '2026.06.30',
  guarantees: [
    ProjectGuarantee(
      icon: Icons.fact_check_outlined,
      title: '平台验收',
      description: '按节点确认标准',
    ),
    ProjectGuarantee(
      icon: Icons.photo_camera_outlined,
      title: '施工照片留档',
      description: '关键过程可追溯',
    ),
    ProjectGuarantee(
      icon: Icons.price_check_outlined,
      title: '价格透明',
      description: '统一工价先说明',
    ),
    ProjectGuarantee(
      icon: Icons.verified_user_outlined,
      title: '售后保障',
      description: '问题协助处理',
    ),
  ],
);

class _ProjectHeroSection extends StatelessWidget {
  const _ProjectHeroSection({required this.project});

  final ConstructionProjectData project;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ZdShadow.cardSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  project.heroImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFE8DED4),
                    child: Icon(Icons.construction, color: ZdColors.primary),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x0D000000), Color(0xB3000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        project.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      project.priceRange,
                      style: const TextStyle(
                        color: ZdColors.primary,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Text(
                        '平台统一人工价',
                        style: TextStyle(
                          color: ZdColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in project.tags) _SoftTag(label: tag),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardPriceSection extends StatelessWidget {
  const _StandardPriceSection({required this.project});

  final ConstructionProjectData project;

  @override
  Widget build(BuildContext context) {
    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '标准工价'),
          const SizedBox(height: 12),
          for (final option in project.priceOptions) ...[
            _PriceOptionRow(option: option),
            if (option != project.priceOptions.last)
              const Divider(height: 18, color: ZdColors.divider),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScopeBox(
                  title: '包含',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF0FA968),
                  items: project.includes,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScopeBox(
                  title: '不包含',
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFF8F8177),
                  items: project.excludes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceOptionRow extends StatelessWidget {
  const _PriceOptionRow({required this.option});

  final ProjectPriceOption option;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.foundation_outlined,
            color: ZdColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.name,
                style: const TextStyle(
                  color: ZdColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                option.description,
                style: ZdText.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          option.price,
          style: const TextStyle(
            color: ZdColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ScopeBox extends StatelessWidget {
  const _ScopeBox({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZdColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Text(
              item,
              style: const TextStyle(
                color: ZdColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _PriceReasonSection extends StatelessWidget {
  const _PriceReasonSection({required this.project});

  final ConstructionProjectData project;

  @override
  Widget build(BuildContext context) {
    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '为什么是这个价格'),
          const SizedBox(height: 12),
          for (final reason in project.priceReasons) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: ZdColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(reason, style: ZdText.body)),
              ],
            ),
            if (reason != project.priceReasons.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ConstructionStepsSection extends StatelessWidget {
  const _ConstructionStepsSection({required this.steps});

  final List<ProjectStep> steps;

  @override
  Widget build(BuildContext context) {
    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '知底施工标准'),
          const SizedBox(height: 14),
          for (int i = 0; i < steps.length; i++)
            _StepCard(step: steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.isLast});

  final ProjectStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: ZdColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: ZdShadow.button,
                ),
                alignment: Alignment.center,
                child: Text(
                  step.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: const Color(0xFFFFD6BC),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZdColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        color: ZdColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(step.description, style: ZdText.caption),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCaseSection extends StatelessWidget {
  const _ProjectCaseSection({required this.project});

  final ConstructionProjectData project;

  @override
  Widget build(BuildContext context) {
    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '真实施工案例'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: ZdColors.primary,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                project.caseLocation,
                style: const TextStyle(
                  color: ZdColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Text(project.caseTime, style: ZdText.caption),
              const Spacer(),
              const Text('施工师傅已认证', style: ZdText.caption),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < project.casePhotos.length; i++) ...[
                Expanded(child: _CasePhoto(photo: project.casePhotos[i])),
                if (i != project.casePhotos.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CasePhoto extends StatelessWidget {
  const _CasePhoto({required this.photo});

  final ProjectCasePhoto photo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              photo.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFECE4DB),
                child: Icon(Icons.image_outlined, color: ZdColors.textHint),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                photo.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuaranteeGridSection extends StatelessWidget {
  const _GuaranteeGridSection({required this.guarantees});

  final List<ProjectGuarantee> guarantees;

  @override
  Widget build(BuildContext context) {
    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '知底保障'),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: guarantees.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.15,
            ),
            itemBuilder: (context, index) {
              final item = guarantees[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ZdColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, color: ZdColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: ZdColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: ZdText.tiny,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BottomQuoteBar extends StatelessWidget {
  const _BottomQuoteBar({required this.project});

  final ConstructionProjectData project;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '按标准工价预估，现场核量后确认',
            style: TextStyle(
              color: ZdColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已为你生成${project.title}报价咨询')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ZdColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '立即获取报价',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarmCard extends StatelessWidget {
  const _WarmCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: ZdShadow.card,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: ZdColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: ZdColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SoftTag extends StatelessWidget {
  const _SoftTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: ZdColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
