import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/worker_models.dart';
import '../models/renovation.dart';

const _collection = 'shared_workers';

CollectionReference<Map<String, dynamic>>? _colOrNull() {
  try {
    return FirebaseFirestore.instance.collection(_collection);
  } catch (_) {
    return null;
  }
}

class SharedWorkerProfile {
  const SharedWorkerProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.trade,
    required this.experienceYears,
    required this.rating,
    required this.totalOrders,
    required this.certifications,
    required this.serviceAreas,
    required this.bio,
    required this.isVerified,
    required this.acceptOrders,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final Trade trade;
  final int experienceYears;
  final double rating;
  final int totalOrders;
  final List<String> certifications;
  final List<String> serviceAreas;
  final String bio;
  final bool isVerified;
  final bool acceptOrders;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'trade': trade.name,
    'experienceYears': experienceYears,
    'rating': rating,
    'totalOrders': totalOrders,
    'certifications': certifications,
    'serviceAreas': serviceAreas,
    'bio': bio,
    'isVerified': isVerified,
    'acceptOrders': acceptOrders,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SharedWorkerProfile.fromJson(Map<String, dynamic> json) {
    return SharedWorkerProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      trade: Trade.values.firstWhere(
        (trade) => trade.name == (json['trade'] as String? ?? ''),
        orElse: () => Trade.plumbing,
      ),
      experienceYears: json['experienceYears'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalOrders: json['totalOrders'] as int? ?? 0,
      certifications: List<String>.from(
        json['certifications'] as List<dynamic>? ?? const [],
      ),
      serviceAreas: List<String>.from(
        json['serviceAreas'] as List<dynamic>? ?? const [],
      ),
      bio: json['bio'] as String? ?? '',
      isVerified: json['isVerified'] as bool? ?? false,
      acceptOrders: json['acceptOrders'] as bool? ?? false,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SharedWorkerPublishResult {
  const SharedWorkerPublishResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class SharedWorkerReadResult {
  const SharedWorkerReadResult({
    required this.workers,
    required this.success,
    required this.message,
  });

  final List<SharedWorkerProfile> workers;
  final bool success;
  final String message;
}

Future<SharedWorkerPublishResult> publishWorkerProfile({
  required WorkerProfile profile,
  required WorkerSettings settings,
}) async {
  final col = _colOrNull();
  if (col == null) {
    return const SharedWorkerPublishResult(
      success: false,
      message: 'Firebase 未初始化，无法发布师傅',
    );
  }
  final idSource = profile.phone.trim().isNotEmpty
      ? profile.phone.trim()
      : '${profile.trade.name}-${profile.name}';
  final shared = SharedWorkerProfile(
    id: 'worker-$idSource',
    name: profile.name,
    phone: profile.phone,
    trade: profile.trade,
    experienceYears: profile.experienceYears,
    rating: profile.rating,
    totalOrders: profile.totalOrders,
    certifications: profile.certifications,
    serviceAreas: profile.serviceAreas,
    bio: profile.bio,
    isVerified: profile.isVerified,
    acceptOrders: settings.acceptOrders,
    updatedAt: DateTime.now(),
  );
  try {
    await col.doc(shared.id).set(shared.toJson());
    return SharedWorkerPublishResult(
      success: true,
      message: '师傅池发布成功：${shared.name} · ${shared.trade.label}',
    );
  } on FirebaseException catch (error) {
    return SharedWorkerPublishResult(
      success: false,
      message: '师傅池发布失败：${error.code} ${error.message ?? ''}',
    );
  } catch (_) {
    return const SharedWorkerPublishResult(
      success: false,
      message: '师傅池发布失败：未知错误',
    );
  }
}

Future<SharedWorkerReadResult> readWorkersByTrade(Trade trade) async {
  try {
    final col = _colOrNull();
    if (col == null) {
      return const SharedWorkerReadResult(
        workers: [],
        success: false,
        message: 'Firebase 未初始化，无法读取共享师傅',
      );
    }
    final snap = await col
        .where('trade', isEqualTo: trade.name)
        .where('acceptOrders', isEqualTo: true)
        .get();
    final workers = snap.docs
        .map((doc) => SharedWorkerProfile.fromJson(doc.data()))
        .toList();
    return SharedWorkerReadResult(
      workers: workers,
      success: true,
      message: '共享师傅读取成功：${workers.length}位${trade.label}',
    );
  } on FirebaseException catch (error) {
    return SharedWorkerReadResult(
      workers: const [],
      success: false,
      message: '共享师傅读取失败：${error.code} ${error.message ?? ''}',
    );
  } catch (_) {
    return const SharedWorkerReadResult(
      workers: [],
      success: false,
      message: '共享师傅读取失败：未知错误',
    );
  }
}

Worker sharedToWorker(SharedWorkerProfile shared) {
  return Worker(
    id: shared.id,
    name: shared.name,
    trade: shared.trade,
    experienceYears: shared.experienceYears,
    completedProjects: shared.totalOrders,
    rating: shared.rating,
    avatar: '',
    intro: shared.bio.isNotEmpty ? shared.bio : '平台认证师傅，当前可接单。',
    certifications: shared.certifications,
    creditScore: shared.isVerified ? 96 : 88,
    distance: 0.8,
    isOnline: shared.acceptOrders,
  );
}
