import 'package:flutter/widgets.dart';

import 'owner_app_state.dart';

class OwnerAppScope extends InheritedNotifier<OwnerAppState> {
  const OwnerAppScope({
    super.key,
    required OwnerAppState state,
    required super.child,
  }) : super(notifier: state);

  static OwnerAppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OwnerAppScope>();
    assert(scope != null, 'No OwnerAppScope found in context.');
    return scope!.notifier!;
  }
}
