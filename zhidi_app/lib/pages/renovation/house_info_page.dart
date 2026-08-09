import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/house_info.dart';

final class HouseInfoPageResult {
  const HouseInfoPageResult(this.houseInfo);

  final HouseInfo houseInfo;
}

final class HouseInfoSubmissionException implements Exception {
  const HouseInfoSubmissionException(this.message);

  final String message;
}

class HouseInfoPage extends StatefulWidget {
  const HouseInfoPage({
    super.key,
    required this.tradeLabel,
    required this.address,
    required this.onSubmit,
    this.failureMessage = '创建需求失败，请重试',
  });

  final String tradeLabel;
  final String address;
  final Future<void> Function(HouseInfo houseInfo) onSubmit;
  final String failureMessage;

  @override
  State<HouseInfoPage> createState() => _HouseInfoPageState();
}

class _HouseInfoPageState extends State<HouseInfoPage> {
  final _areaController = TextEditingController();
  int _bedrooms = 3;
  int _livingRooms = 2;
  int _kitchens = 1;
  int _bathrooms = 2;
  String? _areaError;
  String? _submitError;
  bool _submitting = false;

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final area = double.tryParse(_areaController.text.trim());
    if (area == null || area < 1 || area > 9999) {
      setState(() => _areaError = '请输入 1–9999㎡ 的建筑面积');
      return;
    }
    final info = HouseInfo(
      areaSqm: area,
      bedroomCount: _bedrooms,
      livingRoomCount: _livingRooms,
      kitchenCount: _kitchens,
      bathroomCount: _bathrooms,
    );
    setState(() {
      _areaError = null;
      _submitError = null;
      _submitting = true;
    });
    try {
      await widget.onSubmit(info);
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(HouseInfoPageResult(info));
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _submitError = error is HouseInfoSubmissionException
            ? error.message
            : widget.failureMessage,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('房屋面积与户型')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.tradeLabel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('house-area-field'),
                controller: _areaController,
                enabled: !_submitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,4}(\.\d{0,2})?'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: '建筑面积',
                  suffixText: '㎡',
                  errorText: _areaError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_areaError != null || _submitError != null) {
                    setState(() {
                      _areaError = null;
                      _submitError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              _CounterRow(
                id: 'bedroom',
                label: '卧室',
                value: _bedrooms,
                min: 1,
                max: 20,
                enabled: !_submitting,
                onChanged: (value) => setState(() => _bedrooms = value),
              ),
              _CounterRow(
                id: 'living-room',
                label: '客厅',
                value: _livingRooms,
                min: 0,
                max: 10,
                enabled: !_submitting,
                onChanged: (value) => setState(() => _livingRooms = value),
              ),
              _CounterRow(
                id: 'kitchen',
                label: '厨房',
                value: _kitchens,
                min: 0,
                max: 10,
                enabled: !_submitting,
                onChanged: (value) => setState(() => _kitchens = value),
              ),
              _CounterRow(
                id: 'bathroom',
                label: '卫生间',
                value: _bathrooms,
                min: 1,
                max: 20,
                enabled: !_submitting,
                onChanged: (value) => setState(() => _bathrooms = value),
              ),
              const SizedBox(height: 20),
              Text('默认上门地址', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(widget.address),
              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _submitError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('house-info-submit'),
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? '提交中…' : '确认并选择师傅'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.id,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String id;
  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          key: Key('house-$id-decrement'),
          onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          key: Key('house-$id-increment'),
          onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
