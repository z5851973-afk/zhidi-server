import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';

abstract interface class WorkerBookingApi {
  Future<List<RemoteWorkerBooking>> listWorkerBookings(String accessToken);

  Future<RemoteWorkerBooking> acceptBooking(
      String accessToken, String bookingId);

  Future<RemoteWorkerBooking> rejectBooking(
      String accessToken, String bookingId);

  Future<RemoteWorkerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  );
}

final class RemoteWorkerBooking {
  const RemoteWorkerBooking({
    required this.id,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerPhone,
    required this.serviceRequestId,
    required this.workerUserId,
    required this.workerName,
    required this.trade,
    required this.serviceCity,
    this.serviceAddress,
    this.remark,
    required this.status,
    this.cancelledBy,
    this.cancelReason,
    this.cancelledAt,
    this.arrivalConfirmedByOwner = false,
    this.arrivalConfirmedByWorker = false,
    this.onSiteAt,
    this.proposedTime,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteWorkerBooking.fromJson(Map<String, dynamic> json) {
    return RemoteWorkerBooking(
      id: _requiredString(json, 'id'),
      ownerUserId: _requiredString(json, 'ownerUserId'),
      ownerName: _requiredString(json, 'ownerName'),
      ownerPhone: _requiredString(json, 'ownerPhone'),
      serviceRequestId: _requiredString(json, 'serviceRequestId'),
      workerUserId: _requiredString(json, 'workerUserId'),
      workerName: _requiredString(json, 'workerName'),
      trade: _requiredString(json, 'trade'),
      serviceCity: _requiredString(json, 'serviceCity'),
      serviceAddress: _nullableString(json, 'serviceAddress'),
      remark: _nullableString(json, 'remark'),
      status: _requiredString(json, 'status'),
      cancelledBy: _nullableString(json, 'cancelledBy'),
      cancelReason: _nullableString(json, 'cancelReason'),
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt']).toUtc()
          : null,
      arrivalConfirmedByOwner: json['arrivalConfirmedByOwner'] == true,
      arrivalConfirmedByWorker: json['arrivalConfirmedByWorker'] == true,
      onSiteAt: json['onSiteAt'] != null
          ? DateTime.parse(json['onSiteAt']).toUtc()
          : null,
      proposedTime: json['proposedTime'] != null
          ? DateTime.parse(json['proposedTime']).toUtc()
          : null,
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(json, 'updatedAt')).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerUserId': ownerUserId,
    'ownerName': ownerName,
    'ownerPhone': ownerPhone,
    'serviceRequestId': serviceRequestId,
    'workerUserId': workerUserId,
    'workerName': workerName,
    'trade': trade,
    'serviceCity': serviceCity,
    'serviceAddress': serviceAddress,
    'remark': remark,
    'status': status,
    'cancelledBy': cancelledBy,
    'cancelReason': cancelReason,
    'cancelledAt': cancelledAt?.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  RemoteWorkerBooking copyWith({
    String? id,
    String? ownerUserId,
    String? ownerName,
    String? ownerPhone,
    String? serviceRequestId,
    String? workerUserId,
    String? workerName,
    String? trade,
    String? serviceCity,
    String? serviceAddress,
    String? remark,
    String? status,
    String? cancelledBy,
    String? cancelReason,
    DateTime? cancelledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RemoteWorkerBooking(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      serviceRequestId: serviceRequestId ?? this.serviceRequestId,
      workerUserId: workerUserId ?? this.workerUserId,
      workerName: workerName ?? this.workerName,
      trade: trade ?? this.trade,
      serviceCity: serviceCity ?? this.serviceCity,
      serviceAddress: serviceAddress ?? this.serviceAddress,
      remark: remark ?? this.remark,
      status: status ?? this.status,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  final String id;
  final String ownerUserId;
  final String ownerName;
  final String ownerPhone;
  final String serviceRequestId;
  final String workerUserId;
  final String workerName;
  final String trade;
  final String serviceCity;
  final String? serviceAddress;
  final String? remark;
  final String status;
  final String? cancelledBy;
  final String? cancelReason;
  final DateTime? cancelledAt;
  final bool arrivalConfirmedByOwner;
  final bool arrivalConfirmedByWorker;
  final DateTime? onSiteAt;
  final DateTime? proposedTime;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class WorkerBookingApiClient implements WorkerBookingApi {
  WorkerBookingApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<List<RemoteWorkerBooking>> listWorkerBookings(
    String accessToken,
  ) async {
    final response = await _get('/api/v1/workers/me/bookings', accessToken);
    return _parseBookingList(response);
  }

  @override
  Future<RemoteWorkerBooking> acceptBooking(
    String accessToken,
    String bookingId,
  ) async {
    final response = await _post(
      '/api/v1/workers/me/bookings/$bookingId/accept',
      accessToken,
    );
    return _parseBooking(response);
  }

  @override
  Future<RemoteWorkerBooking> rejectBooking(
    String accessToken,
    String bookingId,
  ) async {
    final response = await _post(
      '/api/v1/workers/me/bookings/$bookingId/reject',
      accessToken,
    );
    return _parseBooking(response);
  }

  @override
  Future<RemoteWorkerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) async {
    final response = await _postJson(
      '/api/v1/workers/me/bookings/$bookingId/cancel',
      accessToken,
      jsonEncode({'reason': reason}),
    );
    return _parseBooking(response);
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

  Future<http.Response> _post(String path, String accessToken) async {
    final request = http.Request('POST', baseUrl.resolve(path))
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
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

  Future<http.Response> _postJson(
      String path, String accessToken, String body) async {
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
}

List<RemoteWorkerBooking> _parseBookingList(http.Response response) {
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
        .map((e) => RemoteWorkerBooking.fromJson(
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

RemoteWorkerBooking _parseBooking(http.Response response) {
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
    return RemoteWorkerBooking.fromJson(data);
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

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _nullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('$key is required');
  }
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('$key must be a string or null');
  }
  return value as String?;
}
