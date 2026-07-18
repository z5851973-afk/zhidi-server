import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_client.dart';
import '../models/payment_models.dart';

class PaymentApiClient {
  PaymentApiClient({
    Uri? baseUrl,
    http.Client? httpClient,
  }) : baseUrl = baseUrl ?? Uri.parse(AuthApiClient.configuredBaseUrl),
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

  Future<Map<String, dynamic>> _get(
    String path,
    String accessToken,
  ) async {
    final resp = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(accessToken),
    );
    return _decode(resp);
  }

  // ── 支付订单 ──

  Future<PaymentOrderModel> createOrder(String accessToken, String bookingId) async {
    final body = await _post('/api/v1/payment/orders', accessToken,
        body: {'bookingId': bookingId});
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

  // ── 结算 ──

  Future<List<SettlementModel>> listSettlements(String accessToken) async {
    final body = await _get('/api/v1/settlements', accessToken);
    return (body['data'] as List)
        .map((j) => SettlementModel.fromJson(j))
        .toList();
  }

  // ── 售后 ──

  Future<AfterSaleModel> createAfterSale(
    String accessToken, {
    required String bookingId,
    required String type,
    required String reason,
    String? evidence,
  }) async {
    final body = await _post('/api/v1/after-sales', accessToken, body: {
      'bookingId': bookingId,
      'type': type,
      'reason': reason,
      if (evidence != null) 'evidence': evidence,
    });
    return AfterSaleModel.fromJson(body['data']);
  }

  Future<AfterSaleModel> getAfterSale(String accessToken, String id) async {
    final body = await _get('/api/v1/after-sales/$id', accessToken);
    return AfterSaleModel.fromJson(body['data']);
  }

  Future<List<AfterSaleModel>> listAfterSales(String accessToken) async {
    final body = await _get('/api/v1/after-sales', accessToken);
    return (body['data'] as List)
        .map((j) => AfterSaleModel.fromJson(j))
        .toList();
  }

  Map<String, dynamic> _decode(http.Response resp) {
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('API error ${resp.statusCode}: ${resp.body}');
  }
}
