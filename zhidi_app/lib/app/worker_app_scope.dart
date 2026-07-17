// ============================================================
// 工匠端 InheritedNotifier — 状态注入组件
// 严格对齐 owner_app_scope.dart
// ============================================================

import 'package:flutter/widgets.dart';

import 'worker_app_state.dart';

/// 工匠端全局状态注入的 InheritedNotifier
/// 用法：WorkerAppScope.of(context) 获取 WorkerAppState 实例
class WorkerAppScope extends InheritedNotifier<WorkerAppState> {
  const WorkerAppScope({
    super.key,
    required WorkerAppState state,
    required super.child,
  }) : super(notifier: state);

  /// 从 widget 树中获取最近的 WorkerAppState 实例
  static WorkerAppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<WorkerAppScope>();
    assert(scope != null, 'No WorkerAppScope found in context.');
    return scope!.notifier!;
  }
}
