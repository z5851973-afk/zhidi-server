import 'dart:math';
import 'package:flutter/material.dart';
import 'worker_detail_page.dart';

// ====== 顶层数据 ======
const _allFilterTags = [
  '全部工种',
  '拆除师傅',
  '水电师傅',
  '泥工师傅',
  '防水师傅',
  '木工师傅',
  '油漆师傅',
  '美缝师傅',
];

const _designerFilterTags = ['全部工种', '室内设计师', '软装设计师', '全屋定制设计师'];

const _inspectorFilterTags = ['全部工种', '水电验收', '泥工验收', '综合验收'];

const _maintenanceFilterTags = ['全部工种', '家电维修', '管道疏通', '电路维修', '防水补漏'];

const _jobMenuOrder = ['拆除师傅', '水电师傅', '泥工师傅', '防水师傅', '木工师傅', '油漆师傅', '美缝师傅'];
const _designerJobMenuOrder = ['室内设计师', '软装设计师', '全屋定制设计师'];
const _inspectorJobMenuOrder = ['水电验收', '泥工验收', '综合验收'];
const _maintenanceJobMenuOrder = ['家电维修', '管道疏通', '电路维修', '防水补漏'];

const _allWorkers = [
  _Worker(
    id: 'worker-li-electrician',
    name: '李师傅',
    job: '水电师傅',
    years: '18',
    orders: '326',
    rate: '98%',
    score: '4.9',
    match: '95',
    specialties: '水电改造、管道维修、电路布线',
    sitePhotoCount: 12,
    reviewCount: 56,
    distance: '1.6km',
    review: _Review(
      content: '李师傅干活特别细致，我家老房子水电全改，走线横平竖直，比之前装修公司强太多了！',
      owner: '南山张先生',
      rating: '5.0',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('低投诉', _BadgeColor.green),
      _BadgeData('服务保障', _BadgeColor.blue),
    ],
  ),
  _Worker(
    id: 'worker-wang-carpenter',
    name: '王师傅',
    job: '木工师傅',
    years: '15',
    orders: '278',
    rate: '96%',
    score: '4.8',
    match: '88',
    specialties: '全屋定制、衣柜橱柜、吊顶安装',
    sitePhotoCount: 23,
    reviewCount: 89,
    distance: '680m',
    review: _Review(
      content: '衣柜和橱柜都是王师傅做的，封边处理得很好，细节到位，邻居来看了都说要找他。',
      owner: '福田李女士',
      rating: '4.9',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('金牌师傅', _BadgeColor.gold),
    ],
  ),
  _Worker(
    id: 'worker-zhang-mason',
    name: '张师傅',
    job: '泥工师傅',
    years: '12',
    orders: '198',
    rate: '97%',
    score: '4.7',
    match: '82',
    specialties: '贴砖、砌墙、地面找平、防水',
    sitePhotoCount: 8,
    reviewCount: 35,
    distance: '2.3km',
    review: _Review(
      content: '瓷砖贴得特别平整，阴阳角处理得非常好，防水也做得很到位，很放心的师傅！',
      owner: '宝安王先生',
      rating: '4.8',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('低投诉', _BadgeColor.green),
    ],
  ),
  // ---- 防水师傅 ----
  _Worker(
    id: 'worker-yang-waterproof',
    name: '杨师傅',
    job: '防水师傅',
    years: '11',
    orders: '245',
    rate: '98%',
    score: '4.8',
    match: '92',
    specialties: '厨卫防水、阳台防水、屋面防水、地下室防潮',
    sitePhotoCount: 6,
    reviewCount: 43,
    distance: '1.4km',
    review: _Review(
      content: '杨师傅做防水很专业，闭水试验48小时滴水不漏，以后再也不担心楼下投诉了！',
      owner: '福田孙先生',
      rating: '4.9',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('金牌师傅', _BadgeColor.gold),
    ],
  ),
  _Worker(
    id: 'worker-tan-waterproof',
    name: '谭师傅',
    job: '防水师傅',
    years: '8',
    orders: '167',
    rate: '96%',
    score: '4.7',
    match: '85',
    specialties: '卫生间防水、厨房防水、外墙防水、堵漏',
    sitePhotoCount: 3,
    reviewCount: 27,
    distance: '2.9km',
    review: _Review(
      content: '老房子漏水找谭师傅修的，查得准、修得快，价格也合理！',
      owner: '宝安廖女士',
      rating: '4.8',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('服务保障', _BadgeColor.blue),
    ],
  ),
  // ---- 拆除师傅 ----
  _Worker(
    id: 'worker-he-demolition',
    name: '何师傅',
    job: '拆除师傅',
    years: '14',
    orders: '312',
    rate: '98%',
    score: '4.8',
    match: '90',
    specialties: '墙体拆除、旧装修拆除、垃圾清运、地面破除',
    sitePhotoCount: 6,
    reviewCount: 48,
    distance: '950m',
    review: _Review(
      content: '何师傅干活麻利，两天就把旧装修拆得干干净净，垃圾也清得很彻底！',
      owner: '宝安刘先生',
      rating: '4.9',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('低投诉', _BadgeColor.green),
    ],
  ),
  _Worker(
    id: 'worker-huang-demolition',
    name: '黄师傅',
    job: '拆除师傅',
    years: '10',
    orders: '215',
    rate: '96%',
    score: '4.7',
    match: '83',
    specialties: '拆墙、铲墙皮、拆吊顶、拆地板',
    sitePhotoCount: 4,
    reviewCount: 32,
    distance: '1.8km',
    review: _Review(
      content: '拆墙很专业，承重墙一眼就认出来了，帮我们避开了大坑！',
      owner: '南山赵女士',
      rating: '4.8',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('服务保障', _BadgeColor.blue),
    ],
  ),
  // ---- 油漆师傅 ----
  _Worker(
    id: 'worker-song-painter',
    name: '宋师傅',
    job: '油漆师傅',
    years: '13',
    orders: '267',
    rate: '97%',
    score: '4.8',
    match: '89',
    specialties: '墙面刷漆、木器漆、艺术漆、硅藻泥',
    sitePhotoCount: 15,
    reviewCount: 62,
    distance: '1.2km',
    review: _Review(
      content: '宋师傅刷的墙面特别平整，颜色调得跟效果图一模一样，很满意！',
      owner: '福田王先生',
      rating: '4.9',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('金牌师傅', _BadgeColor.gold),
    ],
  ),
  _Worker(
    id: 'worker-zheng-painter',
    name: '郑师傅',
    job: '油漆师傅',
    years: '9',
    orders: '178',
    rate: '95%',
    score: '4.7',
    match: '85',
    specialties: '乳胶漆、艺术涂料、旧墙翻新、补墙',
    sitePhotoCount: 10,
    reviewCount: 38,
    distance: '3.5km',
    review: _Review(
      content: '老房子墙面发霉全铲了重做，郑师傅做得很细致，半年了没出问题。',
      owner: '罗湖钟女士',
      rating: '4.7',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('低投诉', _BadgeColor.green),
    ],
  ),
  // ---- 美缝师傅 ----
  _Worker(
    id: 'worker-peng-grout',
    name: '彭师傅',
    job: '美缝师傅',
    years: '7',
    orders: '332',
    rate: '99%',
    score: '4.9',
    match: '93',
    specialties: '瓷砖美缝、环氧彩砂、马贝填缝、美容胶收边',
    sitePhotoCount: 18,
    reviewCount: 95,
    distance: '720m',
    review: _Review(
      content: '彭师傅美缝做得太漂亮了，环氧彩砂颜色配得绝了，朋友都问哪家做的！',
      owner: '龙华林女士',
      rating: '5.0',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('金牌师傅', _BadgeColor.gold),
      _BadgeData('服务保障', _BadgeColor.blue),
    ],
  ),
  _Worker(
    id: 'worker-ding-grout',
    name: '丁师傅',
    job: '美缝师傅',
    years: '5',
    orders: '198',
    rate: '96%',
    score: '4.7',
    match: '82',
    specialties: '美缝、填缝、防水胶收边、厨房台面美容',
    sitePhotoCount: 9,
    reviewCount: 41,
    distance: '4.2km',
    review: _Review(
      content: '小丁师傅年轻但手艺好，做活认真，价格也实惠，推荐！',
      owner: '宝安黄女士',
      rating: '4.8',
    ),
    badges: [_BadgeData('平台认证', _BadgeColor.orange)],
  ),
  // ---- 设计师 ----
  _Worker(
    id: 'worker-hu-interior-designer',
    name: '胡设计师',
    job: '室内设计师',
    years: '12',
    orders: '189',
    rate: '97%',
    score: '4.8',
    match: '91',
    specialties: '全屋设计、户型优化、效果图制作、施工图深化',
    sitePhotoCount: 28,
    reviewCount: 112,
    distance: '1.1km',
    review: _Review(
      content: '胡设计师非常有经验，帮我们把89平的老房改出了120平的感觉，朋友来都说房子变大了！',
      owner: '南山刘先生',
      rating: '4.9',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('金牌设计', _BadgeColor.gold),
    ],
  ),
  _Worker(
    id: 'worker-lin-soft-designer',
    name: '林设计师',
    job: '软装设计师',
    years: '8',
    orders: '134',
    rate: '96%',
    score: '4.7',
    match: '85',
    specialties: '软装搭配、家具选型、窗帘布艺、灯光设计',
    sitePhotoCount: 36,
    reviewCount: 78,
    distance: '2.3km',
    review: _Review(
      content: '林设计师审美很好，帮我们挑的家具和窗帘非常搭，整个家提升了好几个档次！',
      owner: '福田陈女士',
      rating: '4.8',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('服务保障', _BadgeColor.blue),
    ],
  ),
  _Worker(
    id: 'worker-zhou-custom-designer',
    name: '周设计师',
    job: '全屋定制设计师',
    years: '10',
    orders: '201',
    rate: '98%',
    score: '4.9',
    match: '93',
    specialties: '全屋定制、衣柜橱柜设计、收纳规划、板材选型',
    sitePhotoCount: 22,
    reviewCount: 95,
    distance: '980m',
    review: _Review(
      content: '周设计师帮我们规划的全屋收纳特别实用，柜子内部结构设计合理，再也不用担心东西没地方放！',
      owner: '宝安周先生',
      rating: '4.9',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('金牌设计', _BadgeColor.gold),
      _BadgeData('服务保障', _BadgeColor.blue),
    ],
  ),
  _Worker(
    id: 'worker-su-interior-designer',
    name: '苏设计师',
    job: '室内设计师',
    years: '6',
    orders: '98',
    rate: '95%',
    score: '4.6',
    match: '80',
    specialties: '室内设计、效果图表现、软装搭配、空间规划',
    sitePhotoCount: 19,
    reviewCount: 56,
    distance: '3.6km',
    review: _Review(
      content: '苏设计师虽然年轻但很有想法，给我们提了很多实用的建议，效果图做出来跟实际几乎一样！',
      owner: '龙华孙女士',
      rating: '4.7',
    ),
    badges: [_BadgeData('平台认证', _BadgeColor.orange)],
  ),
  // ---- 验收师 ----
  _Worker(
    id: 'worker-zhao-electric-inspector',
    name: '赵验收',
    job: '水电验收',
    years: '14',
    orders: '342',
    rate: '99%',
    score: '4.9',
    match: '94',
    specialties: '水电验收、管道检测、电路测试、隐蔽工程验收',
    sitePhotoCount: 8,
    reviewCount: 128,
    distance: '1.5km',
    review: _Review(
      content: '赵工验收非常专业，用仪器测出了好几处隐蔽的电路问题，要不是他验出来后面麻烦就大了！',
      owner: '罗湖张女士',
      rating: '5.0',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('金牌验收', _BadgeColor.gold),
    ],
  ),
  _Worker(
    id: 'worker-ma-mason-inspector',
    name: '马验收',
    job: '泥工验收',
    years: '11',
    orders: '287',
    rate: '97%',
    score: '4.8',
    match: '89',
    specialties: '贴砖验收、防水验收、墙面平整度检测、空鼓检查',
    sitePhotoCount: 5,
    reviewCount: 86,
    distance: '2.1km',
    review: _Review(
      content: '马工用空鼓锤一个个敲，找出了好几处空鼓，督促工长整改后才让我们签收，放心多了！',
      owner: '南山李先生',
      rating: '4.8',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('服务保障', _BadgeColor.blue),
    ],
  ),
  _Worker(
    id: 'worker-sun-general-inspector',
    name: '孙验收',
    job: '综合验收',
    years: '16',
    orders: '423',
    rate: '98%',
    score: '4.9',
    match: '96',
    specialties: '全屋综合验收、竣工验收、质量评估、问题诊断',
    sitePhotoCount: 12,
    reviewCount: 156,
    distance: '890m',
    review: _Review(
      content: '孙工验收经验非常丰富，一眼就能看出问题，帮我们新房验出了20多处细节问题，省了一大笔后期维修费！',
      owner: '宝安黄先生',
      rating: '5.0',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('金牌验收', _BadgeColor.gold),
      _BadgeData('服务保障', _BadgeColor.blue),
    ],
  ),
  // ---- 维修师傅 ----
  _Worker(
    id: 'worker-liu-appliance',
    name: '刘师傅',
    job: '家电维修',
    years: '15',
    orders: '512',
    rate: '98%',
    score: '4.8',
    match: '92',
    specialties: '空调维修、冰箱维修、洗衣机维修、热水器维修',
    sitePhotoCount: 7,
    reviewCount: 203,
    distance: '680m',
    review: _Review(
      content: '刘师傅技术过硬，空调不制冷的问题一下就找到了，收费也合理，以后家电坏了就找他！',
      owner: '龙岗吴先生',
      rating: '4.9',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('金牌师傅', _BadgeColor.gold),
    ],
  ),
  _Worker(
    id: 'worker-deng-pipe',
    name: '邓师傅',
    job: '管道疏通',
    years: '9',
    orders: '389',
    rate: '97%',
    score: '4.7',
    match: '86',
    specialties: '下水道疏通、马桶疏通、地漏疏通、化粪池清理',
    sitePhotoCount: 4,
    reviewCount: 141,
    distance: '1.3km',
    review: _Review(
      content: '邓师傅来得很快，工具专业，堵了一个星期的下水道半小时就通了，解决了大问题！',
      owner: '宝安杨女士',
      rating: '4.7',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('低投诉', _BadgeColor.green),
    ],
  ),
  _Worker(
    id: 'worker-cheng-circuit',
    name: '程师傅',
    job: '电路维修',
    years: '13',
    orders: '276',
    rate: '96%',
    score: '4.8',
    match: '88',
    specialties: '电路检修、开关插座更换、跳闸排查、灯具安装',
    sitePhotoCount: 6,
    reviewCount: 98,
    distance: '1.8km',
    review: _Review(
      content: '程师傅干活很规范，把老房子里乱七八糟的线路都整理好了，安全多了！',
      owner: '罗湖赵先生',
      rating: '4.8',
    ),
    badges: [
      _BadgeData('平台认证', _BadgeColor.orange),
      _BadgeData('服务保障', _BadgeColor.blue),
    ],
  ),
  _Worker(
    id: 'worker-tian-leak',
    name: '田师傅',
    job: '防水补漏',
    years: '11',
    orders: '198',
    rate: '95%',
    score: '4.6',
    match: '82',
    specialties: '屋顶防水、卫生间补漏、外墙防水、地下室防潮',
    sitePhotoCount: 5,
    reviewCount: 73,
    distance: '2.6km',
    review: _Review(
      content: '田师傅找到了漏水的根源，不是简单做表面文章，修了一年了再也没漏过！',
      owner: '南山潘女士',
      rating: '4.7',
    ),
    badges: [_BadgeData('平台认证', _BadgeColor.orange)],
  ),
];

class WorkerListPage extends StatefulWidget {
  final String? serviceType;
  final bool fromAi;

  const WorkerListPage({super.key, this.serviceType, this.fromAi = false});

  @override
  State<WorkerListPage> createState() => _WorkerListPageState();
}

class _WorkerListPageState extends State<WorkerListPage> {
  String _selectedJob = '全部工种';
  String _selectedSort = '按信用排序';
  String _searchQuery = '';
  final Random _random = Random(DateTime.now().millisecondsSinceEpoch);

  double _parseDistance(String d) {
    if (d.endsWith('km')) {
      return (double.tryParse(d.replaceAll('km', '')) ?? 999) * 1000;
    }
    return double.tryParse(d.replaceAll('m', '')) ?? 999;
  }

  static const _nonTeacherTypes = {'designer', 'inspector', 'maintenance'};

  List<String> get _filterTags {
    switch (widget.serviceType) {
      case 'designer':
        return List<String>.from(_designerFilterTags);
      case 'inspector':
        return List<String>.from(_inspectorFilterTags);
      case 'maintenance':
        return List<String>.from(_maintenanceFilterTags);
      default:
        return List<String>.from(_allFilterTags);
    }
  }

  List<String> get _menuOrder {
    switch (widget.serviceType) {
      case 'designer':
        return List<String>.from(_designerJobMenuOrder);
      case 'inspector':
        return List<String>.from(_inspectorJobMenuOrder);
      case 'maintenance':
        return List<String>.from(_maintenanceJobMenuOrder);
      default:
        return List<String>.from(_jobMenuOrder);
    }
  }

  List<_Worker> get _sorted {
    var list = _allWorkers;
    // serviceType 初始筛选
    if (_nonTeacherTypes.contains(widget.serviceType)) {
      // 设计师/验收师/维修师傅页面：只显示对应工种
      list = list.where((w) => _menuOrder.contains(w.job)).toList();
    } else {
      // 默认找师傅页面：排除非师傅工种
      list = list.where((w) => _jobMenuOrder.contains(w.job)).toList();
    }
    // 搜索筛选
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (w) =>
                w.name.contains(q) ||
                w.job.contains(q) ||
                w.specialties.toLowerCase().contains(q),
          )
          .toList();
    }
    // 工种筛选
    if (_filterTags.contains(_selectedJob) && _selectedJob != '全部工种') {
      list = list.where((w) => w.job == _selectedJob).toList();
    }
    final result = List<_Worker>.from(list);
    // 排序
    switch (_selectedSort) {
      case '按好评排序':
        result.sort(
          (a, b) => double.parse(b.score).compareTo(double.parse(a.score)),
        );
        break;
      case '按距离排序':
        result.sort(
          (a, b) =>
              _parseDistance(a.distance).compareTo(_parseDistance(b.distance)),
        );
        break;
      case '按信用排序':
        result.sort(
          (a, b) => int.parse(
            b.rate.replaceAll('%', ''),
          ).compareTo(int.parse(a.rate.replaceAll('%', ''))),
        );
        break;
    }
    result.shuffle(_random);
    return result;
  }

  String get _title {
    switch (widget.serviceType) {
      case 'demolition':
        return '找拆除师傅';
      case 'painter':
        return '找油漆师傅';
      case 'caulking':
        return '找美缝师傅';
      case 'designer':
        return '找设计师';
      case 'inspector':
        return '找验收师';
      case 'maintenance':
        return '找维修师傅';
      default:
        return '找师傅';
    }
  }

  String get _subtitle {
    switch (widget.serviceType) {
      case 'designer':
        return '附近设计师';
      case 'inspector':
        return '附近验收师';
      case 'maintenance':
        return '附近维修师傅';
      default:
        return '附近师傅';
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedJob = _initialSelectedJob;
  }

  String get _initialSelectedJob {
    switch (widget.serviceType) {
      case 'demolition':
        return '拆除师傅';
      case 'painter':
        return '油漆师傅';
      case 'caulking':
        return '美缝师傅';
      default:
        return '全部工种';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ===== 搜索 + 筛选 =====
          _SearchFilterBar(
            filterTags: _filterTags,
            searchQuery: _searchQuery,
            onSearchChanged: (q) => setState(() => _searchQuery = q),
            selectedJob: _selectedJob,
            selectedSort: _selectedSort,
            onJobChanged: (j) => setState(() => _selectedJob = j),
            onSortChanged: (s) => setState(() => _selectedSort = s),
          ),

          // ===== AI 推荐横向滑动 =====
          if (widget.fromAi)
            _AiRecommendSection(showDistance: _selectedSort == '按距离排序'),

          const SizedBox(height: 16),

          // ===== 推荐师傅标题 =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _subtitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {}),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: Color(0xFF999999),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '换一批',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ===== 工人列表 =====
          ..._sorted.map(
            (w) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _WorkerListCard(
                worker: w,
                showDistance: _selectedSort == '按距离排序',
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Center(
            child: Text(
              '—— 没有更多了 ——',
              style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),

      // ===== 底部信任栏 =====
      bottomNavigationBar: const _BottomTrustBar(),
    );
  }
}

// ========== 搜索 + 筛选栏 ==========
class _SearchFilterBar extends StatefulWidget {
  final List<String> filterTags;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String selectedJob;
  final String selectedSort;
  final ValueChanged<String> onJobChanged;
  final ValueChanged<String> onSortChanged;

  const _SearchFilterBar({
    required this.filterTags,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedJob,
    required this.selectedSort,
    required this.onJobChanged,
    required this.onSortChanged,
  });

  @override
  State<_SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<_SearchFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(_SearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _sortTags = ['按信用排序', '按好评排序', '按距离排序'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          // 搜索框
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFFBBBBBB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: widget.onSearchChanged,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF333333),
                    ),
                    decoration: const InputDecoration(
                      hintText: '请输入工种/服务/姓名',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFBBBBBB),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    widget.onSearchChanged(_controller.text);
                  },
                  child: const Text(
                    '搜索',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 筛选标签：全部工种→下拉，其余→平铺
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 全部工种：下拉菜单
                _buildJobDropdown(),
                // 排序标签：平铺
                ..._sortTags.map((tag) {
                  final active = tag == widget.selectedSort;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => widget.onSortChanged(tag),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFFFF0E5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: active
                                ? const Color(0xFFFF8C42)
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? const Color(0xFFFF6A1A)
                                : const Color(0xFF666666),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDropdown() {
    final jobList = widget.filterTags.skip(1).toList();
    final isJob = jobList.contains(widget.selectedJob);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 36),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: widget.onJobChanged,
        itemBuilder: (_) => jobList.map((job) {
          final isSelected = job == widget.selectedJob;
          return PopupMenuItem<String>(
            value: job,
            height: 40,
            child: Text(
              job,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFFF6A1A)
                    : const Color(0xFF333333),
              ),
            ),
          );
        }).toList(),
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            color: isJob ? const Color(0xFFFFF0E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isJob ? const Color(0xFFFF8C42) : const Color(0xFFE0E0E0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isJob ? widget.selectedJob : '全部工种',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isJob
                      ? const Color(0xFFFF6A1A)
                      : const Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: isJob
                    ? const Color(0xFFFF6A1A)
                    : const Color(0xFF666666),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== AI 推荐横向滑动 ==========
class _AiRecommendSection extends StatelessWidget {
  final bool showDistance;
  const _AiRecommendSection({required this.showDistance});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/robot_ai.png',
                  width: 24,
                  height: 24,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI 智能推荐',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _allWorkers
                .map(
                  (w) =>
                      _AiRecommendCard(worker: w, showDistance: showDistance),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _AiRecommendCard extends StatelessWidget {
  final _Worker worker;
  final bool showDistance;
  const _AiRecommendCard({required this.worker, required this.showDistance});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkerDetailPage(
            workerId: worker.id,
            name: worker.name,
            fromAi: true,
            workerJob: worker.job,
          ),
        ),
      ),
      child: Container(
        width: 290,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像 + 姓名 + 匹配度
            Row(
              children: [
                // 圆形头像
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEE3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 30,
                    color: Color(0xFFFF6A1A),
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
                              worker.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _creditBadge(worker.rate),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            worker.job,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF999999),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Color(0xFFFF9800),
                          ),
                          Text(
                            ' ${worker.score}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (showDistance)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 11,
                              color: Color(0xFFBBBBBB),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              worker.distance,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 经验 + 单量
            Text(
              '★${worker.score} | ${worker.years}年经验 | ${worker.orders}+单',
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 10),
            // 擅长领域
            Text(
              '擅长：${worker.specialties}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            // 工地 + 评价概览
            Row(
              children: [
                const Icon(
                  Icons.photo_library_rounded,
                  size: 11,
                  color: Color(0xFFBBBBBB),
                ),
                const SizedBox(width: 3),
                Text(
                  '${worker.sitePhotoCount}张工地',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF999999),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.star_rounded,
                  size: 11,
                  color: Color(0xFFFF9800),
                ),
                const SizedBox(width: 3),
                Text(
                  '${worker.reviewCount}条好评',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 底部推荐文案
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9F3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.thumb_up_alt_rounded,
                    size: 13,
                    color: Color(0xFFFF6A1A),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '适合你的装修需求',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFF6A1A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 纵向工人列表卡片 ==========
class _WorkerListCard extends StatelessWidget {
  final _Worker worker;
  final bool showDistance;
  const _WorkerListCard({required this.worker, required this.showDistance});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkerDetailPage(
            workerId: worker.id,
            name: worker.name,
            workerJob: worker.job,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 圆形头像
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEE3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 32,
                color: Color(0xFFFF6A1A),
              ),
            ),
            const SizedBox(width: 12),

            // 中间信息区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 姓名 + 工种标签 + 距离
                  Row(
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _creditBadge(worker.rate),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          worker.job,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ),
                      if (showDistance) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: Color(0xFFBBBBBB),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          worker.distance,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 评分 + 经验 + 单量
                  Text(
                    '★${worker.score} | ${worker.years}年经验 | ${worker.orders}+单',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 擅长
                  Text(
                    '擅长：${worker.specialties}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF777777),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 信任标签
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: worker.badges
                        .map((b) => _TrustBadge(data: b))
                        .toList(),
                  ),
                  const SizedBox(height: 10),

                  // 工地展示
                  _SitePhotosStrip(count: worker.sitePhotoCount),
                  const SizedBox(height: 10),

                  // 业主评价
                  _ReviewSnippet(
                    review: worker.review,
                    totalCount: worker.reviewCount,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),

            // 右侧操作区
            Column(
              children: [
                // 收藏
                const Icon(
                  Icons.favorite_border_rounded,
                  size: 22,
                  color: Color(0xFFCCCCCC),
                ),
                const SizedBox(height: 10),
                // 查看详情按钮
                SizedBox(
                  width: 80,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkerDetailPage(
                          workerId: worker.id,
                          name: worker.name,
                          workerJob: worker.job,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C42),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '查看详情',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========== 信任标签 ==========
class _TrustBadge extends StatelessWidget {
  final _BadgeData data;
  const _TrustBadge({required this.data});

  static const _colors = {
    _BadgeColor.orange: Color(0xFFFF6A1A),
    _BadgeColor.green: Color(0xFF4CAF50),
    _BadgeColor.blue: Color(0xFF2196F3),
    _BadgeColor.gold: Color(0xFFE6A817),
  };

  static const _icons = {
    _BadgeColor.orange: Icons.verified_rounded,
    _BadgeColor.green: Icons.thumb_down_off_alt_rounded,
    _BadgeColor.blue: Icons.shield_rounded,
    _BadgeColor.gold: Icons.workspace_premium_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors[data.color]!;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icons[data.color], size: 10, color: c),
          const SizedBox(width: 3),
          Text(
            data.text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

// ========== 底部信任栏 ==========
class _BottomTrustBar extends StatelessWidget {
  const _BottomTrustBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFFFAF6F0),
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _TrustItem(
              icon: Icons.verified_user_rounded,
              title: '平台保障',
              desc: '专人审核 严格筛选',
            ),
            _TrustItem(
              icon: Icons.shield_rounded,
              title: '服务保障',
              desc: '施工质量 全程把控',
            ),
            _TrustItem(
              icon: Icons.support_agent_rounded,
              title: '投诉保障',
              desc: '纠纷处理 先行赔付',
            ),
            _TrustItem(
              icon: Icons.currency_exchange_rounded,
              title: '资金保障',
              desc: '验收合格 再付工钱',
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _TrustItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: Color(0xFFFF6A1A)),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
        ),
      ],
    );
  }
}

// ========== 工地展示缩略图条 ==========
class _SitePhotosStrip extends StatelessWidget {
  final int count;
  const _SitePhotosStrip({required this.count});

  static const _placeColors = [
    Color(0xFFE8D5B7),
    Color(0xFFD4C5A9),
    Color(0xFFC9B99A),
  ];

  @override
  Widget build(BuildContext context) {
    final showCount = count > 2 ? 2 : count;
    return IntrinsicHeight(
      child: Row(
        children: [
          const Icon(
            Icons.photo_library_rounded,
            size: 13,
            color: Color(0xFFBBBBBB),
          ),
          const SizedBox(width: 4),
          const Text(
            '工地实拍',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(width: 6),
          ...List.generate(
            showCount,
            (i) => Container(
              width: 42,
              height: 30,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: _placeColors[i % 3],
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(
                Icons.image_rounded,
                size: 14,
                color: Color(0x66FFFFFF),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '共$count张',
            style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
          ),
        ],
      ),
    );
  }
}

// ========== 业主评价摘要 ==========
class _ReviewSnippet extends StatelessWidget {
  final _Review review;
  final int totalCount;
  const _ReviewSnippet({required this.review, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.format_quote_rounded,
                  size: 14,
                  color: Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  review.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${review.owner} · 共$totalCount条评价',
            style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}

// ========== 数据模型 ==========
class _Worker {
  final String id, name, job, years, orders, rate, score, match, specialties;
  final int sitePhotoCount, reviewCount;
  final _Review review;
  final List<_BadgeData> badges;
  final String distance;

  const _Worker({
    required this.id,
    required this.name,
    required this.job,
    required this.years,
    required this.orders,
    required this.rate,
    required this.score,
    required this.match,
    required this.specialties,
    required this.sitePhotoCount,
    required this.reviewCount,
    required this.review,
    required this.badges,
    required this.distance,
  });
}

class _Review {
  final String content, owner, rating;
  const _Review({
    required this.content,
    required this.owner,
    required this.rating,
  });
}

enum _BadgeColor { orange, green, blue, gold }

class _BadgeData {
  final String text;
  final _BadgeColor color;
  const _BadgeData(this.text, this.color);
}

// 信用标签
Widget _creditBadge(String rate) {
  final v = int.tryParse(rate.replaceAll('%', '')) ?? 0;
  String label;
  Color color;
  if (v < 85) {
    label = '信用较差';
    color = const Color(0xFF999999);
  } else if (v < 92) {
    label = '信用一般';
    color = const Color(0xFFFF9800);
  } else if (v < 97) {
    label = '信用良好';
    color = const Color(0xFF4CAF50);
  } else {
    label = '信用极好';
    color = const Color(0xFF2E7D32);
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color, width: 0.5),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}
