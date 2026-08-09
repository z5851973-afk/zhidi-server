import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/house_info.dart';

import 'auth_api_client.dart';

abstract interface class OwnerBookingApi {
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  );

  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken);

  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  );
}

final class OwnerBookingApiClient implements OwnerBookingApi {
  OwnerBookingApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) async {
    final response = await _post(
      '/api/v1/bookings',
      accessToken,
      jsonEncode(request.toJson()),
    );
    return _parseBooking(response);
  }

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) async {
    final response = await _get('/api/v1/owners/me/bookings', accessToken);
    return _parseBookingList(response);
  }

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) async {
    final response = await _post(
      '/api/v1/owners/me/bookings/$bookingId/cancel',
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
}

final class OwnerBookingCreateRequest {
  const OwnerBookingCreateRequest({
    required this.workerUserId,
    required this.houseInfo,
    this.trade,
    this.serviceCity,
    this.serviceAddress,
    this.remark,
  });

  final String workerUserId;
  final HouseInfo houseInfo;
  final String? trade;
  final String? serviceCity;
  final String? serviceAddress;
  final String? remark;

  Map<String, dynamic> toJson() => {
    'workerUserId': workerUserId,
    ...houseInfo.toJson(),
    'trade': trade,
    'serviceCity': serviceCity,
    'serviceAddress': serviceAddress,
    'remark': remark,
  };
}

final class RemoteOwnerBooking {
  const RemoteOwnerBooking({
    required this.id,
    required this.ownerUserId,
    required this.serviceRequestId,
    required this.workerUserId,
    required this.workerName,
    required this.trade,
    required this.serviceCity,
    required this.serviceAddress,
    required this.remark,
    this.houseInfo,
    required this.status,
    this.cancelledBy,
    this.cancelReason,
    this.cancelledAt,
    this.proposedTime,
    this.scheduledVisitAt,
    this.onSiteAt,
    this.actualOnSiteAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteOwnerBooking.fromJson(Map<String, dynamic> json) {
    return RemoteOwnerBooking(
      id: _requiredString(json, 'id'),
      ownerUserId: _requiredString(json, 'ownerUserId'),
      serviceRequestId: _requiredString(json, 'serviceRequestId'),
      workerUserId: _requiredString(json, 'workerUserId'),
      workerName: _requiredString(json, 'workerName'),
      trade: _requiredString(json, 'trade'),
      serviceCity: _requiredString(json, 'serviceCity'),
      serviceAddress: _nullableString(json, 'serviceAddress'),
      remark: _nullableString(json, 'remark'),
      houseInfo: HouseInfo.tryFromJson(json),
      status: _requiredString(json, 'status'),
      cancelledBy: _nullableString(json, 'cancelledBy'),
      cancelReason: _nullableString(json, 'cancelReason'),
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt']).toUtc()
          : null,
      proposedTime: json['proposedTime'] != null
          ? DateTime.parse(json['proposedTime']).toUtc()
          : null,
      scheduledVisitAt: json['scheduledVisitAt'] != null
          ? DateTime.parse(json['scheduledVisitAt']).toUtc()
          : _hasAgreedVisitTime(_requiredString(json, 'status')) &&
                json['proposedTime'] != null
          ? DateTime.parse(json['proposedTime']).toUtc()
          : null,
      onSiteAt: json['onSiteAt'] != null
          ? DateTime.parse(json['onSiteAt']).toUtc()
          : null,
      actualOnSiteAt: json['actualOnSiteAt'] != null
          ? DateTime.parse(json['actualOnSiteAt']).toUtc()
          : json['onSiteAt'] != null
          ? DateTime.parse(json['onSiteAt']).toUtc()
          : null,
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(json, 'updatedAt')).toUtc(),
    );
  }

  final String id;
  final String ownerUserId;
  final String serviceRequestId;
  final String workerUserId;
  final String workerName;
  final String trade;
  final String serviceCity;
  final String? serviceAddress;
  final String? remark;
  final HouseInfo? houseInfo;
  final String status;
  final String? cancelledBy;
  final String? cancelReason;
  final DateTime? cancelledAt;
  final DateTime? proposedTime;
  final DateTime? scheduledVisitAt;
  final DateTime? onSiteAt;
  final DateTime? actualOnSiteAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

RemoteOwnerBooking _parseBooking(http.Response response) {
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
    return RemoteOwnerBooking.fromJson(data);
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

List<RemoteOwnerBooking> _parseBookingList(http.Response response) {
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
        .map(
          (e) =>
              RemoteOwnerBooking.fromJson(Map<String, dynamic>.from(e as Map)),
        )
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

bool _hasAgreedVisitTime(String status) => switch (status) {
  'VISIT_SCHEDULED' ||
  'ARRIVAL_PENDING' ||
  'ON_SITE' ||
  'QUOTE_PENDING' ||
  'READY_TO_START' ||
  'HIRED' ||
  'COMPLETED' => true,
  _ => false,
};
