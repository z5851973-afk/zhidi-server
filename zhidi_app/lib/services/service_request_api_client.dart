import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';
import 'worker_booking_api_client.dart';

abstract interface class ServiceRequestApi {
  Future<RemoteServiceRequest> createRequest(
    String accessToken,
    ServiceRequestDraft draft,
  );

  Future<List<RemoteServiceRequest>> listOwnerRequests(String accessToken);

  Future<RemoteServiceRequest> addCandidate(
    String accessToken,
    String requestId,
    String workerUserId,
  );

  Future<RemoteCandidateBooking> cancelAsOwner(
    String accessToken,
    String bookingId,
    String reason,
  );

  Future<RemoteCandidateBooking> cancelAsWorker(
    String accessToken,
    String bookingId,
    String reason,
  );

  // ——— 阶段 2: 上门时间与到场确认 ———

  Future<RemoteCandidateBooking> proposeVisit(
    String accessToken,
    String bookingId,
    DateTime proposedTime,
  );

  Future<RemoteCandidateBooking> acceptVisit(
    String accessToken,
    String bookingId,
  );

  Future<RemoteCandidateBooking> rejectVisit(
    String accessToken,
    String bookingId,
    String reason,
  );

  Future<RemoteCandidateBooking> ownerArrive(
    String accessToken,
    String bookingId,
  );

  Future<RemoteCandidateBooking> workerArrive(
    String accessToken,
    String bookingId,
  );

  Future<RemoteCandidateBooking> ownerConfirmArrival(
    String accessToken,
    String bookingId,
  );

  Future<RemoteCandidateBooking> workerConfirmArrival(
    String accessToken,
    String bookingId,
  );
}

final class ServiceRequestApiClient implements ServiceRequestApi {
  ServiceRequestApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  @override
  Future<RemoteServiceRequest> createRequest(
    String accessToken,
    ServiceRequestDraft draft,
  ) async {
    final response = await _post(
      '/api/v1/owners/me/service-requests',
      accessToken,
      jsonEncode(draft.toJson()),
    );
    return _parseServiceRequest(response);
  }

  @override
  Future<List<RemoteServiceRequest>> listOwnerRequests(
      String accessToken) async {
    final response =
        await _get('/api/v1/owners/me/service-requests', accessToken);
    return _parseServiceRequestList(response);
  }

  @override
  Future<RemoteServiceRequest> addCandidate(
    String accessToken,
    String requestId,
    String workerUserId,
  ) async {
    final response = await _post(
      '/api/v1/owners/me/service-requests/$requestId/candidates',
      accessToken,
      jsonEncode({'workerUserId': workerUserId}),
    );
    return _parseServiceRequest(response);
  }

  @override
  Future<RemoteCandidateBooking> cancelAsOwner(
    String accessToken,
    String bookingId,
    String reason,
  ) async {
    final response = await _post(
      '/api/v1/owners/me/bookings/$bookingId/cancel',
      accessToken,
      jsonEncode({'reason': reason}),
    );
    return _parseCandidateBooking(response);
  }

  @override
  Future<RemoteCandidateBooking> cancelAsWorker(
    String accessToken,
    String bookingId,
    String reason,
  ) async {
    final response = await _post(
      '/api/v1/workers/me/bookings/$bookingId/cancel',
      accessToken,
      jsonEncode({'reason': reason}),
    );
    return _parseCandidateBooking(response);
  }

  // ——— 阶段 2: 上门时间与到场确认 ———

  @override
  Future<RemoteCandidateBooking> proposeVisit(
    String accessToken,
    String bookingId,
    DateTime proposedTime,
  ) async {
    final response = await _put(
      '/api/v1/bookings/$bookingId/visit-proposal',
      accessToken,
      jsonEncode({'proposedTime': proposedTime.toUtc().toIso8601String()}),
    );
    return _parseCandidateBooking(response);
  }

  @override
  Future<RemoteCandidateBooking> acceptVisit(
    String accessToken,
    String bookingId,
  ) async {
    final response = await _put(
      '/api/v1/owners/me/bookings/$bookingId/accept-visit',
      accessToken,
      null,
    );
    return _parseCandidateBooking(response);
  }

  @override
  Future<RemoteCandidateBooking> rejectVisit(
    String accessToken,
    String bookingId,
    String reason,
  ) async {
    final response = await _put(
      '/api/v1/owners/me/bookings/$bookingId/reject-visit',
      accessToken,
      jsonEncode({'reason': reason}),
    );
    return _parseCandidateBooking(response);
  }

  @override
  Future<RemoteCandidateBooking> ownerArrive(
    String accessToken,
    String bookingId,
  ) async {
    final response = await _put(
      '/api/v1/owners/me/bookings/$bookingId/arrive',
      accessToken,
      null,
    );
    return _parseCandidateBooking(response);
  }

  @override
  Future<RemoteCandidateBooking> workerArrive(
    String accessToken,
    String bookingId,
  ) async {
    final response = await _put(
      '/api/v1/workers/me/bookings/$bookingId/arrive',
      accessToken,
      null,
    );
    return _parseCandidateBooking(response);
  }

  @override
  Future<RemoteCandidateBooking> ownerConfirmArrival(
    String accessToken,
    String bookingId,
  ) async {
    final response = await _put(
      '/api/v1/owners/me/bookings/$bookingId/confirm-arrival',
      accessToken,
      null,
    );
    return _parseCandidateBooking(response);
  }

  @override
  Future<RemoteCandidateBooking> workerConfirmArrival(
    String accessToken,
    String bookingId,
  ) async {
    final response = await _put(
      '/api/v1/workers/me/bookings/$bookingId/confirm-arrival',
      accessToken,
      null,
    );
    return _parseCandidateBooking(response);
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

  void close() => _httpClient.close();
}

final class ServiceRequestDraft {
  const ServiceRequestDraft({
    required this.trade,
    required this.serviceCity,
    this.serviceAddress,
    this.remark,
  });

  final String trade;
  final String serviceCity;
  final String? serviceAddress;
  final String? remark;

  Map<String, dynamic> toJson() => {
    'trade': trade,
    'serviceCity': serviceCity,
    'serviceAddress': serviceAddress,
    'remark': remark,
  };
}

final class RemoteServiceRequest {
  const RemoteServiceRequest({
    required this.id,
    required this.ownerUserId,
    required this.trade,
    required this.serviceCity,
    this.serviceAddress,
    this.remark,
    required this.status,
    required this.candidates,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteServiceRequest.fromJson(Map<String, dynamic> json) {
    return RemoteServiceRequest(
      id: _requiredString(json, 'id'),
      ownerUserId: _requiredString(json, 'ownerUserId'),
      trade: _requiredString(json, 'trade'),
      serviceCity: _requiredString(json, 'serviceCity'),
      serviceAddress: _nullableString(json, 'serviceAddress'),
      remark: _nullableString(json, 'remark'),
      status: _requiredString(json, 'status'),
      candidates: (json['candidates'] as List)
          .map((e) =>
              RemoteCandidateBooking.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(json, 'updatedAt')).toUtc(),
    );
  }

  final String id;
  final String ownerUserId;
  final String trade;
  final String serviceCity;
  final String? serviceAddress;
  final String? remark;
  final String status;
  final List<RemoteCandidateBooking> candidates;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class RemoteCandidateBooking {
  const RemoteCandidateBooking({
    required this.id,
    required this.serviceRequestId,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerPhone,
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

  factory RemoteCandidateBooking.fromJson(Map<String, dynamic> json) {
    return RemoteCandidateBooking(
      id: _requiredString(json, 'id'),
      serviceRequestId: _requiredString(json, 'serviceRequestId'),
      ownerUserId: _requiredString(json, 'ownerUserId'),
      ownerName: _requiredString(json, 'ownerName'),
      ownerPhone: _requiredString(json, 'ownerPhone'),
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

  final String id;
  final String serviceRequestId;
  final String ownerUserId;
  final String ownerName;
  final String ownerPhone;
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

  RemoteWorkerBooking toRemoteWorkerBooking() => RemoteWorkerBooking(
    id: id,
    serviceRequestId: serviceRequestId,
    ownerUserId: ownerUserId,
    ownerName: ownerName,
    ownerPhone: ownerPhone,
    workerUserId: workerUserId,
    workerName: workerName,
    trade: trade,
    serviceCity: serviceCity,
    serviceAddress: serviceAddress,
    remark: remark,
    status: status,
    cancelledBy: cancelledBy,
    cancelReason: cancelReason,
    cancelledAt: cancelledAt,
    arrivalConfirmedByOwner: arrivalConfirmedByOwner,
    arrivalConfirmedByWorker: arrivalConfirmedByWorker,
    onSiteAt: onSiteAt,
    proposedTime: proposedTime,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

RemoteServiceRequest _parseServiceRequest(http.Response response) {
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
    return RemoteServiceRequest.fromJson(data);
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

List<RemoteServiceRequest> _parseServiceRequestList(http.Response response) {
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
        .map((e) => RemoteServiceRequest.fromJson(
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

RemoteCandidateBooking _parseCandidateBooking(http.Response response) {
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
    return RemoteCandidateBooking.fromJson(data);
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
