import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';
import '../models/payment_models.dart';

final class PaymentApiException implements Exception {
  const PaymentApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'Payment API error $statusCode: $message';
}

class PaymentApiClient {
  PaymentApiClient({Uri? baseUrl, http.Client? httpClient})
    : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
      _httpClient = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _httpClient;

  Map<String, String> _headers(String accessToken) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  Future<Map<String, dynamic>> _post(
    String path,
    String accessToken, {
    Map<String, dynamic>? body,
  }) async {
    final resp = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(accessToken),
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(resp);
  }

  Future<Map<String, dynamic>> _get(String path, String accessToken) async {
    final resp = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(accessToken),
    );
    return _decode(resp);
  }

  // ── 支付订单 ──

  Future<PaymentOrderModel> createOrder(
    String accessToken,
    String bookingId,
  ) async {
    final body = await _post(
      '/api/v1/payment/orders',
      accessToken,
      body: {'bookingId': bookingId},
    );
    return PaymentOrderModel.fromJson(body['data']);
  }

  Future<PaymentOrderModel> getOrder(String accessToken, String orderId) async {
    final body = await _get('/api/v1/payment/orders/$orderId', accessToken);
    return PaymentOrderModel.fromJson(body['data']);
  }

  Future<List<PaymentOrderModel>> listOrders(
    String accessToken, {
    int page = 0,
    int size = 20,
  }) async {
    final body = await _get(
      '/api/v1/payment/orders?page=$page&size=$size',
      accessToken,
    );
    final data = body['data'];
    if (data is Map && data.containsKey('content')) {
      return (data['content'] as List)
          .map((j) => PaymentOrderModel.fromJson(j))
          .toList();
    }
    return (data as List).map((j) => PaymentOrderModel.fromJson(j)).toList();
  }

  Future<PaymentOrderModel> requestRefund(
    String accessToken,
    String orderId,
    String reason,
  ) async {
    final body = await _post(
      '/api/v1/payment/orders/$orderId/refund',
      accessToken,
      body: {'reason': reason},
    );
    return PaymentOrderModel.fromJson(body['data']);
  }

  Future<PaymentOrderModel> reportOfflinePayment(
    String accessToken,
    String orderId, {
    required String channel,
    String? reference,
    String? note,
  }) async {
    final body = await _post(
      '/api/v1/payment/orders/$orderId/offline-payment-report',
      accessToken,
      body: {'channel': channel, 'reference': reference, 'note': note},
    );
    return PaymentOrderModel.fromJson(body['data']);
  }

  Future<PaymentOrderModel> confirmOfflineReceipt(
    String accessToken,
    String orderId,
  ) async {
    final body = await _post(
      '/api/v1/payment/orders/$orderId/receipt-confirmation',
      accessToken,
    );
    return PaymentOrderModel.fromJson(body['data']);
  }

  Future<OfflinePaymentInstructionsModel> getOfflinePaymentInstructions(
    String accessToken,
    String orderId,
  ) async {
    final body = await _get(
      '/api/v1/payment/offline-instructions?orderId=$orderId',
      accessToken,
    );
    return OfflinePaymentInstructionsModel.fromJson(body['data']);
  }

  Future<PaymentOrderModel> reportSplitOfflinePayments(
    String accessToken,
    String orderId, {
    String? constructionChannel,
    String? constructionReference,
    String? platformFeeChannel,
    String? platformFeeReference,
    String? note,
  }) async {
    if (constructionChannel == null && platformFeeChannel == null) {
      throw ArgumentError('At least one split payment component is required');
    }
    final requestBody = <String, dynamic>{};
    if (constructionChannel != null) {
      requestBody['constructionChannel'] = constructionChannel;
    }
    if (constructionReference != null) {
      requestBody['constructionReference'] = constructionReference;
    }
    if (platformFeeChannel != null) {
      requestBody['platformFeeChannel'] = platformFeeChannel;
    }
    if (platformFeeReference != null) {
      requestBody['platformFeeReference'] = platformFeeReference;
    }
    if (note != null && note.isNotEmpty) requestBody['note'] = note;
    final body = await _post(
      '/api/v1/payment/orders/$orderId/offline-split-report',
      accessToken,
      body: requestBody,
    );
    return PaymentOrderModel.fromJson(body['data']);
  }

  Future<PaymentOrderModel> confirmConstructionReceipt(
    String accessToken,
    String orderId,
  ) async {
    final body = await _post(
      '/api/v1/payment/orders/$orderId/construction-receipt-confirmation',
      accessToken,
    );
    return PaymentOrderModel.fromJson(body['data']);
  }

  Future<void> createWechatIntent(String accessToken, String orderId) async {
    await _post('/api/v1/payment/orders/$orderId/wechat-intent', accessToken);
  }

  // ── 结算 ──

  Future<List<SettlementModel>> listSettlements(String accessToken) async {
    final body = await _get('/api/v1/settlements', accessToken);
    return (body['data'] as List)
        .map((j) => SettlementModel.fromJson(j))
        .toList();
  }

  Future<List<WarrantyRetentionModel>> listWarrantyRetentions(
    String accessToken,
  ) async {
    final body = await _get('/api/v1/warranty-retentions', accessToken);
    return (body['data'] as List)
        .map((j) => WarrantyRetentionModel.fromJson(j))
        .toList();
  }

  Future<WorkerWarrantyAccountModel> getWorkerWarrantyAccount(
    String accessToken,
  ) async {
    final body = await _get('/api/v1/worker-warranty/account', accessToken);
    return WorkerWarrantyAccountModel.fromJson(body['data']);
  }

  Future<List<WorkerWarrantyContributionModel>> listWorkerWarrantyContributions(
    String accessToken,
  ) async {
    final body = await _get(
      '/api/v1/worker-warranty/contributions',
      accessToken,
    );
    return (body['data'] as List)
        .map((json) => WorkerWarrantyContributionModel.fromJson(json))
        .toList();
  }

  Future<WorkerWarrantyContributionModel> ensureWorkerWarrantyTopUpObligation(
    String accessToken,
  ) async {
    final body = await _post(
      '/api/v1/worker-warranty/account/top-up-obligation',
      accessToken,
    );
    return WorkerWarrantyContributionModel.fromJson(body['data']);
  }

  Future<WorkerWarrantyContributionModel> reportWarrantyContribution(
    String accessToken,
    String contributionId, {
    required String channel,
    required String reference,
  }) async {
    final body = await _post(
      '/api/v1/worker-warranty/contributions/$contributionId/report',
      accessToken,
      body: {'channel': channel, 'reference': reference},
    );
    return WorkerWarrantyContributionModel.fromJson(body['data']);
  }

  Future<WorkerWarrantyPaymentInstructionsModel>
  getWorkerWarrantyPaymentInstructions(String accessToken) async {
    final body = await _get(
      '/api/v1/worker-warranty/payment-instructions',
      accessToken,
    );
    return WorkerWarrantyPaymentInstructionsModel.fromJson(body['data']);
  }

  // ── 售后 ──

  Future<AfterSaleModel> createAfterSale(
    String accessToken, {
    required String bookingId,
    required String type,
    required String reason,
    List<String> evidenceUrls = const [],
  }) async {
    final body = await _post(
      '/api/v1/after-sales',
      accessToken,
      body: {
        'bookingId': bookingId,
        'type': type,
        'reason': reason,
        'evidenceUrls': evidenceUrls,
      },
    );
    return AfterSaleModel.fromJson(body['data']);
  }

  Future<AfterSaleDetailModel> getAfterSale(
    String accessToken,
    String id,
  ) async {
    final body = await _get('/api/v1/after-sales/$id', accessToken);
    return AfterSaleDetailModel.fromJson(body['data']);
  }

  Future<AfterSaleOrderContextModel> getAfterSaleBookingContext(
    String accessToken,
    String bookingId,
  ) async {
    final body = await _get(
      '/api/v1/after-sales/booking-context/$bookingId',
      accessToken,
    );
    return AfterSaleOrderContextModel.fromJson(body['data']);
  }

  Future<List<AfterSaleModel>> listAfterSales(String accessToken) async {
    final body = await _get('/api/v1/after-sales', accessToken);
    return (body['data'] as List)
        .map((j) => AfterSaleModel.fromJson(j))
        .toList();
  }

  Future<AfterSaleEventModel> appendAfterSaleEvent(
    String accessToken,
    String id, {
    String? content,
    List<String> evidenceUrls = const [],
    required String idempotencyKey,
  }) async {
    final body = await _post(
      '/api/v1/after-sales/$id/events',
      accessToken,
      body: {
        'content': content,
        'evidenceUrls': evidenceUrls,
        'idempotencyKey': idempotencyKey,
      },
    );
    return AfterSaleEventModel.fromJson(body['data']);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    var message = resp.body;
    try {
      final body = jsonDecode(resp.body);
      if (body is Map) {
        final code = body['code']?.toString().trim();
        final detail = body['message']?.toString().trim();
        message = [
          if (code != null && code.isNotEmpty) code,
          if (detail != null && detail.isNotEmpty) detail,
        ].join(': ');
      }
    } catch (_) {
      // Preserve the response body when the server did not return JSON.
    }
    throw PaymentApiException(statusCode: resp.statusCode, message: message);
  }
}
