import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';

/// 提交报价的单个项目（阶段 3：仅传 name + quantity）
final class CatalogSubmitItem {
  const CatalogSubmitItem({
    required this.name,
    required this.quantity,
  });

  final String name;
  final double quantity;

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
  };
}

final class RemoteQuoteItem {
  const RemoteQuoteItem({
    this.name,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.snapshotCatalogId,
    this.subtotal,
    // legacy fields
    this.tradeName = '',
    this.laborFee = 0,
    this.auxiliaryFee = 0,
    this.mainMaterialFee = 0,
  });

  factory RemoteQuoteItem.fromJson(Map<String, dynamic> json) {
    return RemoteQuoteItem(
      name: json['name'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      snapshotCatalogId: json['snapshotCatalogId'] as String?,
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      tradeName: json['tradeName'] as String? ?? '',
      laborFee: (json['laborFee'] as num?)?.toDouble() ?? 0,
      auxiliaryFee: (json['auxiliaryFee'] as num?)?.toDouble() ?? 0,
      mainMaterialFee: (json['mainMaterialFee'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (tradeName.isNotEmpty) 'tradeName': tradeName,
    'laborFee': laborFee,
    'auxiliaryFee': auxiliaryFee,
    'mainMaterialFee': mainMaterialFee,
  };

  final String? name;
  final double? quantity;
  final String? unit;
  final double? unitPrice;
  final String? snapshotCatalogId;
  final double? subtotal;

  final String tradeName;
  final double laborFee;
  final double auxiliaryFee;
  final double mainMaterialFee;
}

final class RemoteQuote {
  const RemoteQuote({
    required this.id,
    required this.bookingId,
    required this.workerUserId,
    this.workerName,
    required this.items,
    required this.status,
    this.rejectReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteQuote.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <RemoteQuoteItem>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        items.add(RemoteQuoteItem.fromJson(Map<String, dynamic>.from(e as Map)));
      }
    }
    return RemoteQuote(
      id: json['id'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      workerUserId: json['workerUserId'] as String? ?? '',
      workerName: json['workerName'] as String?,
      items: items,
      status: json['status'] as String? ?? 'SUBMITTED',
      rejectReason: json['rejectReason'] as String?,
      createdAt: DateTime.parse((json['createdAt'] as String?) ?? ''),
      updatedAt: DateTime.parse((json['updatedAt'] as String?) ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookingId': bookingId,
    'workerUserId': workerUserId,
    if (workerName != null) 'workerName': workerName,
    'items': items.map((e) => e.toJson()).toList(),
    'status': status,
    if (rejectReason != null) 'rejectReason': rejectReason,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  final String id;
  final String bookingId;
  final String workerUserId;
  final String? workerName;
  final List<RemoteQuoteItem> items;
  final String status;
  final String? rejectReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get totalPrice {
    double t = 0;
    for (final item in items) {
      t += item.subtotal ?? (item.unitPrice ?? 0) * (item.quantity ?? 0);
    }
    return t;
  }
}

final class WorkerQuoteApiClient {
  WorkerQuoteApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  Future<RemoteQuote> submitQuote(
    String accessToken,
    String bookingId,
    List<CatalogSubmitItem> items,
  ) async {
    final response = await _post(
      '/api/v1/bookings/$bookingId/quotes',
      accessToken,
      jsonEncode({
        'items': items.map((e) => e.toJson()).toList(),
      }),
    );
    return _parseQuote(response);
  }

  Future<List<RemoteQuote>> listQuotesForBooking(
    String accessToken,
    String bookingId,
  ) async {
    final response =
        await _get('/api/v1/bookings/$bookingId/quotes', accessToken);
    return _parseQuoteList(response);
  }

  Future<List<RemoteQuote>> listWorkerQuotes(String accessToken) async {
    final response = await _get('/api/v1/workers/me/quotes', accessToken);
    return _parseQuoteList(response);
  }

  Future<RemoteQuote> acceptQuote(
    String accessToken,
    String quoteId,
  ) async {
    final response = await _put(
      '/api/v1/quotes/$quoteId/accept',
      accessToken,
      null,
    );
    return _parseQuote(response);
  }

  Future<RemoteQuote> rejectQuote(
    String accessToken,
    String quoteId,
    String reason,
  ) async {
    final response = await _put(
      '/api/v1/quotes/$quoteId/reject',
      accessToken,
      jsonEncode({'reason': reason}),
    );
    return _parseQuote(response);
  }

  Future<List<RemoteQuote>> listQuotesForServiceRequest(
    String accessToken,
    String requestId,
  ) async {
    final response = await _get(
      '/api/v1/service-requests/$requestId/quotes',
      accessToken,
    );
    return _parseQuoteList(response);
  }

  Future<http.Response> _get(String path, String accessToken) async {
    final request = http.Request('GET', baseUrl.resolve(path))
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
      });

    try {
      return await (() async {
        final streamedResponse = await _httpClient.send(request);
        return http.Response.fromStream(streamedResponse);
      })().timeout(requestTimeout);
    } on TimeoutException {
      throw const AuthApiException(
        code: 'NETWORK_TIMEOUT',
        message: '请求超时，请稍后重试',
      );
    } catch (_) {
      throw const AuthApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接服务器，请检查网络',
      );
    }
  }

  Future<http.Response> _post(
    String path,
    String accessToken,
    String body,
  ) async {
    final request = http.Request('POST', baseUrl.resolve(path))
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
      })
      ..body = body;

    try {
      return await (() async {
        final streamedResponse = await _httpClient.send(request);
        return http.Response.fromStream(streamedResponse);
      })().timeout(requestTimeout);
    } on TimeoutException {
      throw const AuthApiException(
        code: 'NETWORK_TIMEOUT',
        message: '请求超时，请稍后重试',
      );
    } catch (_) {
      throw const AuthApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接服务器，请检查网络',
      );
    }
  }

  Future<http.Response> _put(
    String path,
    String accessToken,
    String? body,
  ) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'authorization': 'Bearer $accessToken',
    };
    if (body != null) {
      headers['content-type'] = 'application/json';
    }
    final request = http.Request('PUT', baseUrl.resolve(path))
      ..headers.addAll(headers);
    if (body != null) {
      request.body = body;
    }

    try {
      return await (() async {
        final streamedResponse = await _httpClient.send(request);
        return http.Response.fromStream(streamedResponse);
      })().timeout(requestTimeout);
    } on TimeoutException {
      throw const AuthApiException(
        code: 'NETWORK_TIMEOUT',
        message: '请求超时，请稍后重试',
      );
    } catch (_) {
      throw const AuthApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: '无法连接服务器，请检查网络',
      );
    }
  }
}

RemoteQuote _parseQuote(http.Response response) {
  final envelope = _parseEnvelope(response);
  final data = envelope['data'];
  if (data is! Map<String, dynamic>) {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应缺少数据',
      statusCode: response.statusCode,
    );
  }
  try {
    return RemoteQuote.fromJson(data);
  } on FormatException {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  } on TypeError {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  }
}

List<RemoteQuote> _parseQuoteList(http.Response response) {
  final envelope = _parseEnvelope(response);
  final data = envelope['data'];
  if (data is! List) {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应缺少数据列表',
      statusCode: response.statusCode,
    );
  }
  try {
    return data
        .map((e) => RemoteQuote.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  } on FormatException {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  } on TypeError {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  }
}

Map<String, dynamic> _parseEnvelope(http.Response response) {
  final Map<String, dynamic> envelope;
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('response must be a JSON object');
    }
    envelope = decoded;
  } on FormatException {
    throw AuthApiException(
      code: 'INVALID_RESPONSE',
      message: '服务器响应格式异常',
      statusCode: response.statusCode,
    );
  }

  final apiCode = envelope['code'];
  final apiMessage = envelope['message'];
  if (apiCode != 'OK' ||
      response.statusCode < 200 ||
      response.statusCode >= 300) {
    throw AuthApiException(
      code: apiCode is String ? apiCode : 'REQUEST_FAILED',
      message: apiMessage is String ? apiMessage : '请求失败',
      statusCode: response.statusCode,
    );
  }
  return envelope;
}
