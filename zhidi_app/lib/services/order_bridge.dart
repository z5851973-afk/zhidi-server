import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shared_order.dart';
import '../app/worker_models.dart';

/// ── 共享订单服务（Firestore 版）──
/// 两端通过 Firestore 实时同步订单数据
/// Firestore 不可用时静默降级：读取返回空、写入无操作

const _collection = 'shared_orders';

CollectionReference<Map<String, dynamic>>? _colOrNull() {
  try {
    return FirebaseFirestore.instance.collection(_collection);
  } catch (_) {
    return null;
  }
}

/// 一次性全量读取
Future<List<SharedOrder>> readAll() async {
  try {
    final col = _colOrNull();
    if (col == null) return [];
    final snap = await col.get().timeout(const Duration(seconds: 5));
    return snap.docs
        .map((doc) => SharedOrder.fromJson(doc.data()))
        .toList();
  } catch (_) {
    return [];
  }
}

/// 实时监听（返回取消订阅的函数）
Stream<List<SharedOrder>> watchAll() {
  final col = _colOrNull();
  if (col == null) return Stream.value([]);
  return col.snapshots().map((snap) =>
      snap.docs.map((doc) => SharedOrder.fromJson(doc.data())).toList());
}

/// 更新单条订单（按 id 匹配，不存在则新增）
Future<void> upsert(SharedOrder order) async {
  final col = _colOrNull();
  if (col == null) return;
  try {
    await col.doc(order.id).set(order.toJson()).timeout(const Duration(seconds: 5));
  } catch (_) {
    // Firestore 写入失败时静默忽略
  }
}

// ── WorkerOrder ⟷ SharedOrder ──

SharedOrder workerOrderToShared(WorkerOrder wo) {
  return SharedOrder(
    id: wo.id,
    ownerName: wo.ownerName,
    ownerPhone: wo.ownerPhone,
    ownerAddress: wo.ownerAddress,
    area: wo.area,
    description: wo.description,
    trade: wo.trade,
    phaseIndex: wo.phaseIndex ?? 0,
    phaseName: wo.phaseName ?? '',
    workerName: '张工',
    status: _workerStatusToShared(wo.status),
    quotedPrice: wo.quotedPrice,
    visitTime: wo.visitTime?.toIso8601String(),
    hasVisited: wo.hasVisited,
    createdAt: wo.createdAt,
  );
}

SharedOrderStatus _workerStatusToShared(WorkerOrderStatus s) {
  switch (s) {
    case WorkerOrderStatus.pending:
      return SharedOrderStatus.pending;
    case WorkerOrderStatus.accepted:
      return SharedOrderStatus.accepted;
    case WorkerOrderStatus.inProgress:
      return SharedOrderStatus.inProgress;
    case WorkerOrderStatus.completed:
      return SharedOrderStatus.inspection;
    case WorkerOrderStatus.cancelled:
      return SharedOrderStatus.cancelled;
  }
}

WorkerOrder sharedToWorkerOrder(SharedOrder so) {
  return WorkerOrder(
    id: so.id,
    ownerName: so.ownerName,
    ownerPhone: so.ownerPhone,
    ownerAddress: so.ownerAddress,
    area: so.area,
    requirement: so.description,
    description: so.description,
    trade: so.trade,
    status: _sharedStatusToWorker(so.status),
    quotedPrice: so.quotedPrice,
    visitTime: so.visitTime != null ? DateTime.tryParse(so.visitTime!) : null,
    hasVisited: so.hasVisited,
    createdAt: so.createdAt,
    phaseIndex: so.phaseIndex,
    phaseName: so.phaseName,
  );
}

WorkerOrderStatus _sharedStatusToWorker(SharedOrderStatus s) {
  switch (s) {
    case SharedOrderStatus.pending:
      return WorkerOrderStatus.pending;
    case SharedOrderStatus.accepted:
      return WorkerOrderStatus.accepted;
    case SharedOrderStatus.inProgress:
      return WorkerOrderStatus.inProgress;
    case SharedOrderStatus.inspection:
    case SharedOrderStatus.completed:
      return WorkerOrderStatus.completed;
    case SharedOrderStatus.cancelled:
      return WorkerOrderStatus.cancelled;
  }
}
