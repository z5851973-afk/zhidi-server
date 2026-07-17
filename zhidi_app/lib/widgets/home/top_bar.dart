import 'package:flutter/material.dart';
import '../../design/tokens.dart';

// ── 城市数据（按首字母分组，已去"市/州/盟/地区"后缀排序） ──
const _cities = <String, List<String>>{
  'A': ['阿坝', '阿克苏', '阿拉尔', '阿拉善盟', '阿勒泰', '阿里', '安康', '安庆', '安顺', '安阳', '鞍山'],
  'B': ['巴彦淖尔', '巴中', '白城', '白山', '白银', '百色', '蚌埠', '包头', '宝鸡', '保定', '保山', '北海', '北京', '本溪', '毕节', '滨州', '亳州'],
  'C': ['沧州', '昌都', '昌吉', '长春', '长沙', '长治', '常德', '常州', '朝阳', '潮州', '郴州', '成都', '承德', '池州', '赤峰', '崇左', '滁州', '楚雄'],
  'D': ['达州', '大理', '大连', '大庆', '大同', '丹东', '德宏', '德阳', '德州', '迪庆', '定西', '东莞', '东营'],
  'E': ['鄂尔多斯', '鄂州', '恩施'],
  'F': ['防城港', '佛山', '福州', '抚顺', '抚州', '阜新', '阜阳'],
  'G': ['甘南', '甘孜', '赣州', '广安', '广元', '广州', '贵港', '贵阳', '桂林', '果洛'],
  'H': ['哈尔滨', '哈密', '海口', '海东', '海北', '海南州', '海西', '邯郸', '杭州', '汉中', '合肥', '河池', '河源', '菏泽', '贺州', '鹤壁', '鹤岗', '黑河', '衡水', '衡阳', '红河', '呼和浩特', '呼伦贝尔', '湖州', '葫芦岛', '怀化', '淮安', '淮北', '淮南', '黄冈', '黄南', '黄山', '黄石', '惠州'],
  'J': ['鸡西', '吉安', '吉林', '济南', '济宁', '济源', '佳木斯', '嘉兴', '嘉峪关', '江门', '焦作', '揭阳', '金昌', '金华', '锦州', '晋城', '晋中', '荆门', '荆州', '景德镇', '九江', '酒泉'],
  'K': ['喀什', '开封', '克拉玛依', '克孜勒苏', '昆明'],
  'L': ['拉萨', '来宾', '兰州', '廊坊', '乐山', '丽江', '丽水', '连云港', '凉山', '辽阳', '辽源', '聊城', '林芝', '临沧', '临汾', '临夏', '临沂', '柳州', '六安', '六盘水', '龙岩', '陇南', '娄底', '泸州', '洛阳', '吕梁'],
  'M': ['马鞍山', '茂名', '梅州', '绵阳', '牡丹江'],
  'N': ['那曲', '南昌', '南充', '南京', '南宁', '南平', '南通', '南阳', '内江', '宁波', '宁德', '怒江'],
  'P': ['盘锦', '攀枝花', '平顶山', '平凉', '萍乡', '莆田', '濮阳', '普洱'],
  'Q': ['七台河', '齐齐哈尔', '钦州', '秦皇岛', '青岛', '清远', '庆阳', '曲靖', '衢州', '泉州'],
  'R': ['日喀则', '日照'],
  'S': ['三门峡', '三明', '三亚', '厦门', '山南', '汕头', '汕尾', '商洛', '商丘', '上海', '上饶', '韶关', '邵阳', '绍兴', '深圳', '沈阳', '十堰', '石家庄', '石嘴山', '双鸭山', '朔州', '四平', '松原', '苏州', '宿迁', '宿州', '绥化', '遂宁', '随州'],
  'T': ['塔城', '台州', '太原', '泰安', '泰州', '唐山', '天津', '天水', '铁岭', '通化', '通辽', '铜川', '铜陵', '铜仁', '吐鲁番'],
  'W': ['威海', '潍坊', '渭南', '温州', '文山', '乌海', '乌兰察布', '乌鲁木齐', '无锡', '吴忠', '芜湖', '梧州', '武汉', '武威'],
  'X': ['西安', '西宁', '西双版纳', '锡林郭勒', '咸宁', '咸阳', '湘潭', '香港', '襄阳', '孝感', '忻州', '新乡', '新余', '信阳', '兴安盟', '邢台', '徐州', '许昌', '宣城'],
  'Y': ['雅安', '烟台', '延安', '延边', '盐城', '扬州', '阳江', '阳泉', '伊春', '伊犁', '宜宾', '宜昌', '宜春', '益阳', '银川', '鹰潭', '营口', '永州', '榆林', '玉林', '玉树', '玉溪', '岳阳', '云浮', '运城'],
  'Z': ['枣庄', '湛江', '张家界', '张家口', '张掖', '漳州', '昭通', '肇庆', '镇江', '郑州', '中山', '中卫', '重庆', '舟山', '周口', '珠海', '驻马店', '资阳', '淄博', '自贡', '遵义'],
};

// ── 推荐城市 ──
const _hotCities = ['北京', '上海', '广州', '深圳', '成都', '杭州', '武汉', '重庆', '南京', '西安', '长沙', '郑州'];

// ── 字母列表 ──
const _letters = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
  'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'W', 'X', 'Y', 'Z',
];

// ── Widget ────────────────────────────────────────────────

class HomeTopBar extends StatefulWidget {
  const HomeTopBar({super.key});

  @override
  State<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<HomeTopBar> {
  String _city = '成都';
  bool _isLocating = false;

  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CityPickerSheet(
        currentCity: _city,
        onSelect: (city) {
          setState(() => _city = city);
          Navigator.pop(context);
        },
        onLocate: () {
          setState(() => _isLocating = true);
          Navigator.pop(context);
          _simulateLocation();
        },
      ),
    );
  }

  void _simulateLocation() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _city = '成都';
          _isLocating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已定位到当前城市'), duration: Duration(seconds: 2)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: _openCityPicker,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isLocating ? '定位中…' : _city,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff222222)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Color(0xff444444)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: const Row(
              children: [
                SizedBox(width: 14),
                Icon(Icons.search, size: 22, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(child: Text('找师傅 / 找设计 / 找验收', style: TextStyle(fontSize: 14, color: Color(0xff999999)))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 18),
        Column(children: const [Icon(Icons.support_agent), SizedBox(height: 3), Text('客服', style: TextStyle(fontSize: 12))]),
      ],
    );
  }
}

// ── 城市选择面板 ──────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  final String currentCity;
  final ValueChanged<String> onSelect;
  final VoidCallback onLocate;
  const _CityPickerSheet({required this.currentCity, required this.onSelect, required this.onLocate});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖拽手柄
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
          ),
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: '城市/区县/商场等地点',
                      hintStyle: const TextStyle(fontSize: 14, color: ZdColors.textHint),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFFBBBBBB)),
                      filled: true,
                      fillColor: ZdColors.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(fontSize: 15, color: ZdColors.textPrimary)),
                ),
              ],
            ),
          ),
          // 列表内容
          Expanded(
            child: _query.isNotEmpty ? _buildSearchResult() : _buildFullList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResult() {
    final results = <String>[];
    for (final list in _cities.values) {
      for (final c in list) {
        if (c.contains(_query)) results.add(c);
      }
    }
    if (results.isEmpty) {
      return const Center(child: Text('未找到匹配城市', style: TextStyle(color: ZdColors.textSecondary, fontSize: 14)));
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: results.length,
      itemBuilder: (_, i) => _CityRow(
        name: results[i],
        isCurrent: results[i] == widget.currentCity,
        onTap: () => widget.onSelect(results[i]),
      ),
    );
  }

  Widget _buildFullList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _letters.length + 1, // +1 for hot cities section at top
      itemBuilder: (context, index) {
        if (index == 0) return _buildHotSection();
        final letter = _letters[index - 1];
        final cities = _cities[letter] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LetterHeader(letter: letter),
            ...cities.map((c) => _CityRow(
              name: c,
              isCurrent: c == widget.currentCity,
              onTap: () => widget.onSelect(c),
            )),
          ],
        );
      },
    );
  }

  Widget _buildHotSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('热门城市', style: TextStyle(fontSize: 13, color: ZdColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _hotCities.map((c) {
              final selected = c == widget.currentCity;
              return GestureDetector(
                onTap: () => widget.onSelect(c),
                child: Container(
                  width: (MediaQuery.of(context).size.width - 62) / 3,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFF3E8) : ZdColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? const Color(0xFFFF7A2F) : ZdColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LetterHeader extends StatelessWidget {
  final String letter;
  const _LetterHeader({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: ZdColors.background,
      child: Text(letter, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZdColors.textPrimary)),
    );
  }
}

class _CityRow extends StatelessWidget {
  final String name;
  final bool isCurrent;
  final VoidCallback onTap;
  const _CityRow({required this.name, required this.isCurrent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: ZdColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isCurrent ? const Color(0xFFFF7A2F) : ZdColors.textPrimary,
                ),
              ),
            ),
            if (isCurrent)
              const Icon(Icons.check, size: 18, color: Color(0xFFFF7A2F)),
          ],
        ),
      ),
    );
  }
}
