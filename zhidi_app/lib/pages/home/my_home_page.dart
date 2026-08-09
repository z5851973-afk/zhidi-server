import 'package:flutter/material.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/app/owner_appointment.dart';

import '../../design/tokens.dart';
import '../../models/house_info.dart';
import '../../models/renovation.dart' show Trade;
import '../../models/payment_models.dart';
import '../../services/service_request_api_client.dart';
import '../../services/worker_quote_api_client.dart';
import '../../services/auth_api_client.dart';
import '../../services/chat_api_client.dart';
import '../../services/payment_api_client.dart';
import '../../services/inspection_api_client.dart';
import '../../models/chat_models.dart';
import '../chat/chat_detail_page.dart';
import '../renovation/construction_standards_page.dart';
import '../renovation/trade_select_page.dart';
import 'renovation_archive_page.dart';
import 'owner_quote_compare_page.dart';
import 'owner_inspection_page.dart';
import '../../services/daily_report_api_client.dart';
import 'owner_payment_page.dart';
import 'owner_after_sale_page.dart';
import 'worker/candidate_picker_page.dart';

const _primary = ZdColors.primary;
const _bg = ZdColors.background;
const _card = ZdColors.surfaceWarm;
const _textDark = ZdColors.textPrimary;
const _textMid = ZdColors.textSecondary;
const _textLight = Color(0xFF9B8F86);
const _line = Color(0xFFF0E4D8);
const _green = ZdColors.success;
const _orangeSoft = Color(0xFFFFF1E7);
const _gold = Color(0xFFC8871A);

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.serviceRequestApi,
    this.paymentApi,
    this.quoteApi,
    this.inspectionApi,
    this.refreshEpoch = 0,
    this.initialServiceRequestId,
    this.initialBookingId,
  });

  final ServiceRequestApi? serviceRequestApi;
  final PaymentApiClient? paymentApi;
  final WorkerQuoteApiClient? quoteApi;
  final InspectionApi? inspectionApi;
  final int refreshEpoch;
  final String? initialServiceRequestId;
  final String? initialBookingId;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Map<String, List<RemoteQuote>> _quotes = {};
  final Map<String, PaymentOrderModel> _paymentOrdersByBookingId = {};
  bool _supplementaryLoading = true;
  bool _paymentStatusLoading = true;
  String? _paymentStatusError;
  String? _targetError;
  bool _loaded = false;
  int _loadSequence = 0;
  int _paymentLoadSequence = 0;
  String? _loadedSessionUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessionUserId = OwnerAppScope.of(context).sessionUserId;
    if (!_loaded || sessionUserId != _loadedSessionUserId) {
      _loaded = true;
      _loadedSessionUserId = sessionUserId;
      _quotes.clear();
      _paymentOrdersByBookingId.clear();
      _loadRequests();
    }
  }

  @override
  void didUpdateWidget(covariant MyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshEpoch != oldWidget.refreshEpoch) {
      _quotes.clear();
      _loadRequests();
    }
  }

  Future<void> _loadRequests() async {
    final sequence = ++_loadSequence;
    final paymentSequence = ++_paymentLoadSequence;
    _paymentOrdersByBookingId.clear();
    _paymentStatusLoading = true;
    _paymentStatusError = null;
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _quotes.clear();
          _paymentOrdersByBookingId.clear();
          _supplementaryLoading = false;
          _paymentStatusLoading = false;
          _paymentStatusError = null;
          _targetError = '请先登录';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _supplementaryLoading = true;
        _targetError = null;
      });
    }
    try {
      await state.fetchRemoteBookings();
      await state.fetchRemoteServiceRequests(
        serviceRequestApi: widget.serviceRequestApi,
      );
      if (!mounted || sequence != _loadSequence) return;
      final displayList = _targetedRequests(state.remoteServiceRequests);
      if (displayList == null) {
        if (mounted && sequence == _loadSequence) {
          setState(() {
            _quotes.clear();
            _paymentOrdersByBookingId.clear();
            _supplementaryLoading = false;
            _targetError = '该订单已更新或不再可用';
          });
        }
        return;
      }
      Map<String, PaymentOrderModel> paymentOrders = const {};
      String? paymentStatusError;
      try {
        paymentOrders = await _loadPaymentOrders(
          token,
          displayList
              .expand((request) => request.candidates)
              .map((item) => item.id),
        );
      } catch (_) {
        paymentStatusError = '付款状态暂时无法加载';
      }
      final quoteMap = await _loadQuotesForCandidates(token, displayList);
      if (mounted && sequence == _loadSequence) {
        setState(() {
          _quotes
            ..clear()
            ..addAll(quoteMap);
          if (paymentSequence == _paymentLoadSequence) {
            _paymentOrdersByBookingId
              ..clear()
              ..addAll(paymentOrders);
            _paymentStatusLoading = false;
            _paymentStatusError = paymentStatusError;
          }
          _supplementaryLoading = false;
        });
      }
    } on AuthApiException catch (e) {
      if (mounted && sequence == _loadSequence) {
        setState(() {
          _supplementaryLoading = false;
          if (paymentSequence == _paymentLoadSequence) {
            _paymentOrdersByBookingId.clear();
            _paymentStatusLoading = false;
            _paymentStatusError = '付款状态暂时无法加载';
          }
          _targetError = e.message;
        });
      }
    } catch (e) {
      if (mounted && sequence == _loadSequence) {
        setState(() {
          _supplementaryLoading = false;
          if (paymentSequence == _paymentLoadSequence) {
            _paymentOrdersByBookingId.clear();
            _paymentStatusLoading = false;
            _paymentStatusError = '付款状态暂时无法加载';
          }
          _targetError = '加载失败：$e';
        });
      }
    }
  }

  List<RemoteServiceRequest>? _targetedRequests(
    List<RemoteServiceRequest> requests,
  ) {
    final requestId = widget.initialServiceRequestId;
    final bookingId = widget.initialBookingId;
    if (requestId == null && bookingId == null) return requests;
    if (requestId == null || bookingId == null) return null;
    final matchingRequests = requests.where(
      (request) => request.id == requestId,
    );
    if (matchingRequests.isEmpty) return null;
    final request = matchingRequests.first;
    final matchingCandidates = request.candidates.where(
      (candidate) =>
          candidate.id == bookingId && candidate.serviceRequestId == requestId,
    );
    if (matchingCandidates.isEmpty) return null;
    return [
      RemoteServiceRequest(
        id: request.id,
        ownerUserId: request.ownerUserId,
        trade: request.trade,
        serviceCity: request.serviceCity,
        serviceAddress: request.serviceAddress,
        remark: request.remark,
        houseInfo: request.houseInfo,
        status: request.status,
        candidates: [matchingCandidates.first],
        createdAt: request.createdAt,
        updatedAt: request.updatedAt,
      ),
    ];
  }

  Future<Map<String, PaymentOrderModel>> _loadPaymentOrders(
    String token,
    Iterable<String> bookingIds,
  ) async {
    final visibleBookingIds = bookingIds.toSet();
    final api = widget.paymentApi ?? PaymentApiClient();
    final orders = await api.listOrders(token);
    return _latestPaymentOrdersByBookingId(
      orders.where((order) => visibleBookingIds.contains(order.bookingId)),
    );
  }

  Future<void> _retryPaymentOrders() async {
    final paymentSequence = ++_paymentLoadSequence;
    final state = OwnerAppScope.of(context);
    final sessionUserId = state.sessionUserId;
    setState(() {
      _paymentOrdersByBookingId.clear();
      _paymentStatusLoading = true;
      _paymentStatusError = null;
    });
    final token = await state.getAccessToken();
    final requests = _targetedRequests(state.remoteServiceRequests);
    if (token == null || sessionUserId == null || requests == null) {
      if (mounted && paymentSequence == _paymentLoadSequence) {
        setState(() {
          _paymentStatusLoading = false;
          _paymentStatusError = '付款状态暂时无法加载';
        });
      }
      return;
    }
    try {
      final paymentOrders = await _loadPaymentOrders(
        token,
        requests
            .expand((request) => request.candidates)
            .map((candidate) => candidate.id),
      );
      if (!mounted ||
          paymentSequence != _paymentLoadSequence ||
          state.sessionUserId != sessionUserId ||
          await state.getAccessToken() != token) {
        return;
      }
      setState(() {
        _paymentOrdersByBookingId
          ..clear()
          ..addAll(paymentOrders);
        _paymentStatusLoading = false;
        _paymentStatusError = null;
      });
    } catch (_) {
      if (!mounted ||
          paymentSequence != _paymentLoadSequence ||
          state.sessionUserId != sessionUserId) {
        return;
      }
      setState(() {
        _paymentOrdersByBookingId.clear();
        _paymentStatusLoading = false;
        _paymentStatusError = '付款状态暂时无法加载';
      });
    }
  }

  Future<Map<String, List<RemoteQuote>>> _loadQuotesForCandidates(
    String token,
    List<RemoteServiceRequest> requests,
  ) async {
    final result = <String, List<RemoteQuote>>{};
    final api = widget.quoteApi ?? WorkerQuoteApiClient();
    for (final req in requests) {
      for (final c in req.candidates) {
        if (!_shouldFetchQuotesForCost(c.status)) continue;
        try {
          result[c.id] = await api.listQuotesForBooking(token, c.id);
        } catch (_) {
          result[c.id] = const [];
        }
      }
    }
    return result;
  }

  List<RemoteQuote> _quotesForCandidate(RemoteCandidateBooking c) {
    return _quotes[c.id] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final targetedRequests = _targetedRequests(state.remoteServiceRequests);
    final requests = targetedRequests ?? const <RemoteServiceRequest>[];
    final exactTargetMode =
        widget.initialServiceRequestId != null ||
        widget.initialBookingId != null;
    final hasMissingExactTarget = targetedRequests == null && exactTargetMode;
    final loading =
        state.isFetchingRemoteServiceRequests &&
        state.remoteServiceRequests.isEmpty;
    return Material(
      color: _bg,
      child: _MyHomeManagementView(
        requests: requests,
        appointments: exactTargetMode ? const [] : state.appointments,
        loading:
            loading ||
            (_supplementaryLoading && state.remoteServiceRequests.isEmpty),
        error: _targetError ?? state.remoteServiceRequestError,
        onRetry: _loadRequests,
        quotesForCandidate: _quotesForCandidate,
        serviceRequestApi: widget.serviceRequestApi,
        paymentApi: widget.paymentApi,
        paymentOrders: hasMissingExactTarget
            ? const []
            : _paymentOrdersByBookingId.values.toList(),
        paymentStatusLoading: _paymentStatusLoading,
        paymentStatusError: _paymentStatusError,
        onPaymentRetry: _retryPaymentOrders,
        quotesByBookingId: _quotes,
        inspectionApi: widget.inspectionApi,
        exactBookingId: widget.initialBookingId,
        exactTargetMode: exactTargetMode,
      ),
    );
  }
}

bool _shouldFetchQuotesForCost(String status) =>
    status == 'QUOTE_PENDING' ||
    status == 'READY_TO_START' ||
    status == 'HIRED' ||
    status == 'COMPLETED';

Map<String, PaymentOrderModel> _latestPaymentOrdersByBookingId(
  Iterable<PaymentOrderModel> orders,
) {
  final byBookingId = <String, PaymentOrderModel>{};
  for (final order in orders) {
    final existing = byBookingId[order.bookingId];
    if (existing == null || order.updatedAt.compareTo(existing.updatedAt) > 0) {
      byBookingId[order.bookingId] = order;
    }
  }
  return byBookingId;
}

class _MyHomeManagementView extends StatelessWidget {
  const _MyHomeManagementView({
    this.requests = const [],
    this.appointments = const [],
    this.loading = false,
    this.error,
    this.onRetry,
    this.quotesForCandidate,
    this.serviceRequestApi,
    this.paymentApi,
    this.paymentOrders = const [],
    this.paymentStatusLoading = false,
    this.paymentStatusError,
    this.onPaymentRetry,
    this.quotesByBookingId = const {},
    this.inspectionApi,
    this.exactBookingId,
    this.exactTargetMode = false,
  });

  final List<RemoteServiceRequest> requests;
  final List<OrderItem> appointments;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final List<RemoteQuote> Function(RemoteCandidateBooking)? quotesForCandidate;
  final ServiceRequestApi? serviceRequestApi;
  final PaymentApiClient? paymentApi;
  final List<PaymentOrderModel> paymentOrders;
  final bool paymentStatusLoading;
  final String? paymentStatusError;
  final VoidCallback? onPaymentRetry;
  final Map<String, List<RemoteQuote>> quotesByBookingId;
  final InspectionApi? inspectionApi;
  final String? exactBookingId;
  final bool exactTargetMode;

  Future<T?> _push<T>(BuildContext context, Widget page) {
    return Navigator.of(
      context,
    ).push<T>(MaterialPageRoute(builder: (_) => page));
  }

  void _showHint(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _confirmArrival(
    BuildContext context,
    RemoteCandidateBooking candidate,
  ) async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (context.mounted) _showHint(context, '登录已过期，请重新登录');
      return;
    }
    try {
      final api = serviceRequestApi ?? ServiceRequestApiClient();
      await api.ownerConfirmArrival(token, candidate.id);
      if (context.mounted) {
        _showHint(context, '已确认师傅到场');
        onRetry?.call();
      }
    } on AuthApiException catch (e) {
      if (context.mounted) _showHint(context, e.message);
    } catch (e) {
      if (context.mounted) _showHint(context, '确认失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerAppScope.of(context);
    final workers = exactTargetMode
        ? <BookedWorker>[]
        : (_uniqueServiceWorkers(state.bookedWorkers)
            ..sort((a, b) => a.phaseIndex.compareTo(b.phaseIndex)));
    final cost = exactTargetMode
        ? const _CostSummary(confirmed: 0, labor: 0, material: 0)
        : _CostSummary.fromState(
            state,
            workers,
            paymentOrders,
            quotesByBookingId,
          );
    final featuredProject = _featuredWorkbenchProject(requests);
    final featuredPaymentOrder = featuredProject == null
        ? null
        : _latestPaymentOrdersByBookingId(
            paymentOrders,
          )[featuredProject.bookingId];
    final paymentStatusAvailable =
        !paymentStatusLoading && paymentStatusError == null;

    void openCurrentQuote() {
      final project = featuredProject;
      if (project == null) {
        _showHint(context, '暂无报价清单，先开始找师傅');
        return;
      }
      _push(
        context,
        OwnerQuoteComparePage(
          serviceRequestId: project.serviceRequestId,
          workerNamesById: {
            for (final candidate in project.request.candidates)
              candidate.workerUserId: candidate.workerName,
          },
        ),
      );
    }

    void openCurrentInspection() {
      final project = featuredProject;
      if (project == null) {
        _push(context, const RenovationArchivePage());
        return;
      }
      _push(
        context,
        OwnerInspectionPage(bookingId: project.bookingId, api: inspectionApi),
      );
    }

    void openCurrentPayment() {
      if (!paymentStatusAvailable) {
        _showHint(context, '付款状态暂时无法加载，请重试');
        return;
      }
      final project = featuredProject;
      if (project == null) {
        _showHint(context, '暂无付款记录');
        return;
      }
      _push(
        context,
        OwnerPaymentPage(
          bookingId: project.bookingId,
          initialPaymentOrderId: featuredPaymentOrder?.id,
          paymentApi: paymentApi,
        ),
      );
    }

    void openCurrentCost() {
      if (featuredPaymentOrder != null) {
        openCurrentPayment();
      } else {
        openCurrentQuote();
      }
    }

    return ColoredBox(
      color: _bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            const _PageHeader(),
            const SizedBox(height: 16),
            if (featuredProject != null) ...[
              _ProjectWorkbenchCard(
                request: featuredProject.request,
                candidate: featuredProject.booking,
                quotes:
                    quotesByBookingId[featuredProject.bookingId] ?? const [],
                paymentOrder: featuredPaymentOrder,
                paymentStatusAvailable: paymentStatusAvailable,
                paymentStatusLoading: paymentStatusLoading,
                onOpenDetail: () async {
                  final changed = await _push<bool>(
                    context,
                    _ServiceRequestDetailPage(
                      request: featuredProject.request,
                      exactBookingId: exactBookingId,
                      quotesForCandidate: quotesForCandidate,
                      serviceRequestApi: serviceRequestApi,
                      paymentApi: paymentApi,
                    ),
                  );
                  if (changed == true) onRetry?.call();
                },
                onOpenQuote: () async {
                  final changed = await _push<bool>(
                    context,
                    OwnerQuoteComparePage(
                      serviceRequestId: featuredProject.serviceRequestId,
                      workerNamesById: {
                        for (final c in featuredProject.request.candidates)
                          c.workerUserId: c.workerName,
                      },
                    ),
                  );
                  if (changed == true) onRetry?.call();
                },
                onOpenInspection: () async {
                  await _push(
                    context,
                    OwnerInspectionPage(
                      bookingId: featuredProject.bookingId,
                      api: inspectionApi,
                    ),
                  );
                  onRetry?.call();
                },
                onOpenPayment: openCurrentPayment,
                onConfirmArrival: () =>
                    _confirmArrival(context, featuredProject.booking),
              ),
              const SizedBox(height: 12),
            ],
            if (paymentStatusError != null) ...[
              _PaymentStatusErrorCard(onRetry: onPaymentRetry),
              const SizedBox(height: 12),
            ],
            // ── ServiceRequest 区域 ──
            _ServiceRequestsSection(
              requests: requests,
              appointments: appointments,
              loading: loading,
              error: error,
              onRetry: onRetry,
              onFindWorker: () async {
                await _push(context, const TradeSelectPage());
                onRetry?.call();
              },
              onTapRequest: (req) async {
                final changed = await _push<bool>(
                  context,
                  _ServiceRequestDetailPage(
                    request: req,
                    exactBookingId: exactBookingId,
                    quotesForCandidate: quotesForCandidate,
                    serviceRequestApi: serviceRequestApi,
                    paymentApi: paymentApi,
                  ),
                );
                if (changed == true) {
                  onRetry?.call();
                }
              },
            ),
            if (!exactTargetMode) ...[
              const SizedBox(height: 12),
              _CostCard(
                key: const Key('my-home-cost-card'),
                summary: cost,
                onDetail: openCurrentCost,
              ),
              const SizedBox(height: 12),
              _DocumentsCard(
                key: const Key('my-home-documents-card'),
                onQuote: openCurrentQuote,
                onStandard: () =>
                    _push(context, const ConstructionStandardsPage()),
                onInspection: openCurrentInspection,
                onPayment: paymentStatusAvailable ? openCurrentPayment : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _FeaturedWorkbenchProject {
  const _FeaturedWorkbenchProject({
    required this.request,
    required this.booking,
  });

  final RemoteServiceRequest request;
  final RemoteCandidateBooking booking;

  String get serviceRequestId => request.id;
  String get bookingId => booking.id;
}

_FeaturedWorkbenchProject? _featuredWorkbenchProject(
  List<RemoteServiceRequest> requests,
) {
  final actionableRequests =
      requests.where(_isActionableServiceRequest).toList()
        ..sort(_compareLatestServiceRequest);
  for (final request in actionableRequests) {
    final booking = _bestBookingForRequest(
      request,
      _isActionableCandidateStatus,
    );
    if (booking != null) {
      return _FeaturedWorkbenchProject(request: request, booking: booking);
    }
  }

  final ongoingProject = _latestProjectBooking(requests, 'HIRED');
  if (ongoingProject != null) return ongoingProject;
  if (actionableRequests.isNotEmpty) return null;
  return _latestProjectBooking(requests, 'COMPLETED');
}

bool _isActionableServiceRequest(RemoteServiceRequest request) {
  if (request.status == 'CANCELLED' || request.status == 'COMPLETED') {
    return false;
  }
  if (request.status == 'OPEN' || request.status == 'COMPARING') return true;
  return request.candidates.any(
    (candidate) =>
        _belongsToRequest(request, candidate) &&
        _isActionableCandidateStatus(candidate.status),
  );
}

_FeaturedWorkbenchProject? _latestProjectBooking(
  List<RemoteServiceRequest> requests,
  String status,
) {
  final projects = <_FeaturedWorkbenchProject>[];
  for (final request in requests) {
    if (request.status == 'CANCELLED') continue;
    final booking = _bestBookingForRequest(
      request,
      (candidateStatus) => candidateStatus == status,
    );
    if (booking != null) {
      projects.add(
        _FeaturedWorkbenchProject(request: request, booking: booking),
      );
    }
  }
  if (projects.isEmpty) return null;
  projects.sort((a, b) {
    final requestDiff = _compareLatestServiceRequest(a.request, b.request);
    if (requestDiff != 0) return requestDiff;
    return b.booking.updatedAt.compareTo(a.booking.updatedAt);
  });
  return projects.first;
}

RemoteCandidateBooking? _bestBookingForRequest(
  RemoteServiceRequest request,
  bool Function(String status) acceptsStatus,
) {
  final bookings = request.candidates
      .where(
        (candidate) =>
            _belongsToRequest(request, candidate) &&
            acceptsStatus(candidate.status),
      )
      .toList();
  if (bookings.isEmpty) return null;
  bookings.sort((a, b) {
    final rankDiff = _candidateStatusRank(
      b.status,
    ).compareTo(_candidateStatusRank(a.status));
    if (rankDiff != 0) return rankDiff;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return bookings.first;
}

int _compareLatestServiceRequest(
  RemoteServiceRequest a,
  RemoteServiceRequest b,
) {
  final createdDiff = b.createdAt.compareTo(a.createdAt);
  if (createdDiff != 0) return createdDiff;
  return b.updatedAt.compareTo(a.updatedAt);
}

bool _belongsToRequest(
  RemoteServiceRequest request,
  RemoteCandidateBooking candidate,
) => candidate.serviceRequestId == request.id;

bool _isCandidateTerminalStatus(String status) {
  return switch (status) {
    'REJECTED' ||
    'CANCELLED' ||
    'NOT_SELECTED' ||
    'HIRED' ||
    'COMPLETED' => true,
    _ => false,
  };
}

bool _isActionableCandidateStatus(String status) =>
    !_isCandidateTerminalStatus(status);

bool _isProjectCandidateStatus(String status) =>
    status == 'HIRED' || status == 'COMPLETED';

bool _isEndedCandidateStatus(String status) =>
    _isCandidateTerminalStatus(status) && !_isProjectCandidateStatus(status);

RemoteQuote? _preferredQuote(Iterable<RemoteQuote> quotes) {
  RemoteQuote? latest;
  RemoteQuote? latestAccepted;
  for (final quote in quotes) {
    if (latest == null || _isLaterQuote(quote, latest)) latest = quote;
    if (quote.status == 'ACCEPTED' &&
        (latestAccepted == null || _isLaterQuote(quote, latestAccepted))) {
      latestAccepted = quote;
    }
  }
  return latestAccepted ?? latest;
}

bool _isLaterQuote(RemoteQuote candidate, RemoteQuote current) {
  final updatedDiff = candidate.updatedAt.compareTo(current.updatedAt);
  if (updatedDiff != 0) return updatedDiff > 0;
  final createdDiff = candidate.createdAt.compareTo(current.createdAt);
  if (createdDiff != 0) return createdDiff > 0;
  return candidate.id.compareTo(current.id) > 0;
}

String _endedCandidateStatusLabel(String status) {
  return switch (status) {
    'REJECTED' => '已拒绝',
    'CANCELLED' => '已取消',
    'NOT_SELECTED' => '未选中',
    _ => status,
  };
}

int _candidateStatusRank(String status) {
  return switch (status) {
    'COMPLETED' => 10,
    'HIRED' => 9,
    'READY_TO_START' => 8,
    'QUOTE_PENDING' => 7,
    'ON_SITE' => 6,
    'ARRIVAL_PENDING' => 5,
    'VISIT_SCHEDULED' => 4,
    'VISIT_PROPOSED' => 3,
    'ACCEPTED' => 2,
    'PENDING' => 1,
    _ => 0,
  };
}

int _serviceRequestProgressRank(String status) {
  return switch (status) {
    'COMPLETED' => 6,
    'WORKER_SELECTED' => 5,
    'ASSIGNED' => 5,
    'COMPARING' => 4,
    'OPEN' => 3,
    'CANCELLED' => 1,
    _ => 2,
  };
}

class _ProjectWorkbenchCard extends StatelessWidget {
  const _ProjectWorkbenchCard({
    required this.request,
    required this.candidate,
    required this.quotes,
    this.paymentOrder,
    required this.paymentStatusAvailable,
    required this.paymentStatusLoading,
    required this.onOpenDetail,
    required this.onOpenQuote,
    required this.onOpenInspection,
    required this.onOpenPayment,
    required this.onConfirmArrival,
  });

  final RemoteServiceRequest request;
  final RemoteCandidateBooking candidate;
  final List<RemoteQuote> quotes;
  final PaymentOrderModel? paymentOrder;
  final bool paymentStatusAvailable;
  final bool paymentStatusLoading;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenQuote;
  final VoidCallback onOpenInspection;
  final VoidCallback onOpenPayment;
  final VoidCallback onConfirmArrival;

  bool get _isConstructionStarted =>
      candidate.status == 'HIRED' || candidate.status == 'COMPLETED';

  String get _projectName => _isConstructionStarted
      ? '${_tradeLabel(request.trade)}改造项目'
      : '${_tradeLabel(request.trade)}师傅 · 候选';

  String get _stageLabel {
    return switch (candidate.status) {
      'PENDING' => '待接单',
      'ACCEPTED' || 'VISIT_PROPOSED' || 'VISIT_SCHEDULED' => '待上门',
      'ARRIVAL_PENDING' || 'ON_SITE' => '待报价',
      'QUOTE_PENDING' => '报价待确认',
      'HIRED' => '施工中',
      'COMPLETED' => '已完成',
      _ => serviceRequestStatusLabel(candidate.status),
    };
  }

  int get _progressIndex {
    if (!_isConstructionStarted) {
      return switch (candidate.status) {
        'PENDING' => 0,
        'ACCEPTED' || 'VISIT_PROPOSED' || 'VISIT_SCHEDULED' => 1,
        'ARRIVAL_PENDING' || 'ON_SITE' => 2,
        'QUOTE_PENDING' => 3,
        _ => 0,
      };
    }
    return switch (candidate.status) {
      'HIRED' => 1,
      'COMPLETED' => 3,
      _ => 0,
    };
  }

  List<String> get _progressSteps => _isConstructionStarted
      ? const ['待开工', '施工中', '待验收', '已完成']
      : const ['待接单', '待上门', '待报价', '待选定'];

  String get _primaryLabel {
    return switch (candidate.status) {
      'ARRIVAL_PENDING' => '确认师傅已到场',
      'QUOTE_PENDING' => '确认报价',
      'HIRED' => '验收进度',
      'COMPLETED' when !paymentStatusAvailable =>
        paymentStatusLoading ? '付款状态加载中' : '付款状态暂不可用',
      'COMPLETED' when paymentOrder?.isPaid == true => '已支付 · 查看记录',
      'COMPLETED' when paymentOrder?.isAwaitingPlatformFeeReview == true =>
        '平台核验中',
      'COMPLETED' when paymentOrder?.isAwaitingWorkerReceipt == true =>
        '待师傅确认收款',
      'COMPLETED' => '去支付',
      _ => '查看进度',
    };
  }

  Color get _primaryButtonColor {
    if (candidate.status != 'COMPLETED') return _primary;
    if (!paymentStatusAvailable) return _textLight;
    if (paymentOrder?.isPaid == true) return _green;
    if (paymentOrder?.isAwaitingPlatformFeeReview == true) return _gold;
    if (paymentOrder?.isAwaitingWorkerReceipt == true) return _gold;
    return _primary;
  }

  IconData? get _primaryIcon {
    if (candidate.status != 'COMPLETED') return null;
    if (!paymentStatusAvailable) {
      return paymentStatusLoading ? Icons.sync : Icons.cloud_off_outlined;
    }
    if (paymentOrder?.isPaid == true) return Icons.check_circle_outline;
    if (paymentOrder?.isAwaitingPlatformFeeReview == true) {
      return Icons.verified_user_outlined;
    }
    if (paymentOrder?.isAwaitingWorkerReceipt == true) {
      return Icons.hourglass_top_rounded;
    }
    return Icons.payment;
  }

  VoidCallback? get _primaryAction {
    return switch (candidate.status) {
      'ARRIVAL_PENDING' => onConfirmArrival,
      'QUOTE_PENDING' => onOpenQuote,
      'HIRED' => onOpenInspection,
      'COMPLETED' when paymentStatusAvailable => onOpenPayment,
      'COMPLETED' => null,
      _ => onOpenDetail,
    };
  }

  @override
  Widget build(BuildContext context) {
    final quoteTotal = _preferredQuote(quotes)?.totalPrice ?? 0;
    final scheduledVisitAt = switch (candidate.status) {
      'VISIT_SCHEDULED' ||
      'ARRIVAL_PENDING' ||
      'ON_SITE' ||
      'QUOTE_PENDING' ||
      'READY_TO_START' ||
      'HIRED' ||
      'COMPLETED' => candidate.scheduledVisitAt ?? candidate.proposedTime,
      _ => null,
    };
    final actualOnSiteAt = candidate.actualOnSiteAt ?? candidate.onSiteAt;
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _projectName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _stageLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _primary.withValues(alpha: 0.12),
                child: Text(
                  candidate.workerName.isEmpty ? '师' : candidate.workerName[0],
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.workerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '约定上门时间：${_formatDateTime(scheduledVisitAt).isEmpty ? '待确认' : _formatDateTime(scheduledVisitAt)}',
                      style: const TextStyle(fontSize: 12, color: _textMid),
                    ),
                    if (scheduledVisitAt != null || actualOnSiteAt != null)
                      Text(
                        '实际到场时间：${_formatDateTime(actualOnSiteAt).isEmpty ? '待到场' : _formatDateTime(actualOnSiteAt)}',
                        style: const TextStyle(fontSize: 12, color: _textMid),
                      ),
                  ],
                ),
              ),
              if (quoteTotal > 0)
                Text(
                  _money(quoteTotal),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _ProjectProgressStrip(
            currentIndex: _progressIndex,
            steps: _progressSteps,
          ),
          const SizedBox(height: 18),
          _WorkbenchSection(
            title: _isConstructionStarted ? '施工记录' : '预约记录',
            trailing: _isConstructionStarted ? '查看详情 >' : '查看候选 >',
            onTap: onOpenDetail,
            child: Text(
              _isConstructionStarted
                  ? '日报、现场照片和施工说明会在师傅提交后同步展示。'
                  : '当前只是候选/预约阶段，师傅接单、确认上门和报价后，您再决定是否选定。',
              style: const TextStyle(
                fontSize: 13,
                color: _textMid,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _WorkbenchSection(
            title: _isConstructionStarted ? '验收' : '报价与比价',
            trailing: _isConstructionStarted ? '查看进度 >' : '查看报价 >',
            onTap: _isConstructionStarted ? onOpenInspection : onOpenQuote,
            child: Row(
              children: [
                Icon(
                  _isConstructionStarted
                      ? Icons.fact_check_outlined
                      : Icons.receipt_long_outlined,
                  size: 18,
                  color: _primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isConstructionStarted
                        ? '平台验收标准保障，验收通过后再进入付款。'
                        : '师傅上门后提交报价，您可以对比后再最终选择。',
                    style: const TextStyle(fontSize: 13, color: _textMid),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenDetail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text('联系师傅'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  key: const Key('my-home-primary-action'),
                  onPressed: _primaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryButtonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: _primaryIcon == null
                      ? Text(_primaryLabel)
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_primaryIcon, size: 17),
                              const SizedBox(width: 6),
                              Text(_primaryLabel, maxLines: 1, softWrap: false),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectProgressStrip extends StatelessWidget {
  const _ProjectProgressStrip({
    required this.currentIndex,
    required this.steps,
  });
  final int currentIndex;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: i <= currentIndex
                        ? _primary
                        : const Color(0xFFE7DED6),
                    shape: BoxShape.circle,
                  ),
                  child: i < currentIndex
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == currentIndex
                        ? FontWeight.w900
                        : FontWeight.w600,
                    color: i <= currentIndex ? _primary : _textLight,
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 22),
                color: i < currentIndex ? _primary : const Color(0xFFE7DED6),
              ),
            ),
        ],
      ],
    );
  }
}

class _WorkbenchSection extends StatelessWidget {
  const _WorkbenchSection({
    required this.title,
    required this.trailing,
    required this.child,
    required this.onTap,
  });

  final String title;
  final String trailing;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                const Spacer(),
                Text(
                  trailing,
                  style: const TextStyle(fontSize: 12, color: _textLight),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '我的家',
          style: TextStyle(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: _textDark,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '管理我的装修服务，让每一步装修都有记录、有保障。',
          style: TextStyle(fontSize: 14, height: 1.45, color: _textMid),
        ),
      ],
    );
  }
}

class _CostCard extends StatelessWidget {
  const _CostCard({super.key, required this.summary, required this.onDetail});

  final _CostSummary summary;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(title: '装修费用'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _orangeSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '固定工价 · 报价透明',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CostMetric(
                  label: '已确认费用',
                  value: _money(summary.confirmed),
                  prominent: true,
                  valueKey: const Key('cost-confirmed-value'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CostMetric(
                  label: '人工费用',
                  value: _money(summary.labor),
                  valueKey: const Key('cost-labor-value'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CostMetric(
                  label: '辅材费用',
                  value: _money(summary.material),
                  valueKey: const Key('cost-material-value'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: onDetail,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: Color(0xFFFFC7A3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '查看费用详情',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({
    super.key,
    required this.onQuote,
    required this.onStandard,
    required this.onInspection,
    required this.onPayment,
  });

  final VoidCallback onQuote;
  final VoidCallback onStandard;
  final VoidCallback onInspection;
  final VoidCallback? onPayment;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DocEntry(Icons.receipt_long_rounded, '报价清单', onQuote),
      _DocEntry(Icons.verified_user_outlined, '施工标准', onStandard),
      _DocEntry(Icons.fact_check_outlined, '验收记录', onInspection),
      _DocEntry(Icons.account_balance_wallet_outlined, '付款记录', onPayment),
    ];
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '装修资料'),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.65,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final enabled = item.onTap != null;
              return InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _orangeSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          size: 18,
                          color: enabled ? _primary : _textLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: enabled ? _textDark : _textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: ZdShadow.cardSoft,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _textDark,
      ),
    );
  }
}

class _CostMetric extends StatelessWidget {
  const _CostMetric({
    required this.label,
    required this.value,
    this.prominent = false,
    this.valueKey,
  });

  final String label;
  final String value;
  final bool prominent;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: prominent ? _orangeSoft : const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textMid)),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: valueKey,
              style: TextStyle(
                fontSize: prominent ? 18 : 15,
                fontWeight: FontWeight.w900,
                color: prominent ? _primary : _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocEntry {
  const _DocEntry(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _CostSummary {
  const _CostSummary({
    required this.confirmed,
    required this.labor,
    required this.material,
  });

  final double confirmed;
  final double labor;
  final double material;

  static _CostSummary fromState(
    OwnerAppState state,
    List<BookedWorker> workers,
    List<PaymentOrderModel> paymentOrders,
    Map<String, List<RemoteQuote>> quotesByBookingId,
  ) {
    double paidLabor = 0;
    double paidMaterial = 0;
    for (final order in paymentOrders.where(_countsAsConfirmedPayment)) {
      final split = _paidCostSplitForOrder(
        order,
        quotesByBookingId[order.bookingId] ?? const [],
      );
      paidLabor += split.labor;
      paidMaterial += split.material;
    }
    final quoteTotal = state.savedQuotes.fold<double>(
      0.0,
      (sum, quote) => sum + quote.grandTotal,
    );
    final fallbackLabor = workers.isEmpty ? 0.0 : workers.length * 1800.0;
    final hasPaidCost = paidLabor > 0 || paidMaterial > 0;
    final labor = hasPaidCost
        ? paidLabor
        : quoteTotal > 0
        ? quoteTotal
        : fallbackLabor;
    final localMaterial = state.materialEstimates.fold<double>(
      0.0,
      (sum, estimate) => sum + estimate.selectedTotal,
    );
    final material = paidMaterial + localMaterial;
    return _CostSummary(
      confirmed: labor + material,
      labor: labor,
      material: material,
    );
  }
}

bool _countsAsConfirmedPayment(PaymentOrderModel order) =>
    order.isPaid ||
    order.isAwaitingWorkerReceipt ||
    order.isAwaitingPlatformFeeReview;

_CostSummary _paidCostSplitForOrder(
  PaymentOrderModel order,
  List<RemoteQuote> quotes,
) {
  final quote = _quoteForPaymentOrder(order, quotes);
  if (quote == null) {
    return _CostSummary(
      confirmed: order.amount,
      labor: order.amount,
      material: 0,
    );
  }
  final labor = quote.items.fold<double>(0, (sum, item) => sum + item.laborFee);
  final explicitMaterial = quote.items.fold<double>(
    0,
    (sum, item) => sum + item.auxiliaryFee + item.mainMaterialFee,
  );
  if (labor <= 0 && explicitMaterial <= 0) {
    return _CostSummary(
      confirmed: order.amount,
      labor: order.amount,
      material: 0,
    );
  }
  final clampedLabor = labor.clamp(0.0, order.amount).toDouble();
  final material = (order.amount - clampedLabor)
      .clamp(0.0, double.infinity)
      .toDouble();
  return _CostSummary(
    confirmed: clampedLabor + material,
    labor: clampedLabor,
    material: material,
  );
}

RemoteQuote? _quoteForPaymentOrder(
  PaymentOrderModel order,
  List<RemoteQuote> quotes,
) {
  if (quotes.isEmpty) return null;
  for (final quote in quotes) {
    if (quote.id == order.quoteId) return quote;
  }
  return _preferredQuote(quotes);
}

Trade? _tradeFromWorker(BookedWorker worker) {
  final text = '${worker.trade} ${worker.phaseName}';
  if (text.contains('拆')) return Trade.demolition;
  if (text.contains('水电')) return Trade.plumbing;
  if (text.contains('泥') || text.contains('瓦') || text.contains('贴砖')) {
    return Trade.masonry;
  }
  if (text.contains('防水')) return Trade.waterproof;
  if (text.contains('木')) return Trade.carpentry;
  if (text.contains('油漆') || text.contains('涂')) return Trade.painting;
  if (text.contains('安装')) return Trade.installation;
  if (text.contains('清洁') || text.contains('保洁')) return Trade.cleaning;
  return null;
}

List<BookedWorker> _uniqueServiceWorkers(List<BookedWorker> workers) {
  final byService = <String, BookedWorker>{};
  for (final worker in workers) {
    final key = _serviceKey(worker);
    final existing = byService[key];
    if (existing == null || _preferWorker(worker, existing)) {
      byService[key] = worker;
    }
  }
  return byService.values.toList();
}

String _serviceKey(BookedWorker worker) {
  if (worker.phaseIndex >= 0) return 'phase-${worker.phaseIndex}';
  final trade = _tradeFromWorker(worker);
  if (trade != null) return 'trade-${trade.name}';
  final normalized = '${worker.phaseName}-${worker.trade}'.trim();
  return normalized.isEmpty ? worker.id : normalized;
}

bool _preferWorker(BookedWorker candidate, BookedWorker current) {
  if (!candidate.isCompleted && current.isCompleted) return true;
  if (candidate.isCompleted && !current.isCompleted) return false;
  final candidateTime = candidate.bookedAt;
  final currentTime = current.bookedAt;
  if (candidateTime != null && currentTime != null) {
    return candidateTime.isAfter(currentTime);
  }
  if (candidateTime != null) return true;
  return false;
}

String _money(double value) {
  if (value <= 0) return '¥0';
  return '¥${value.toStringAsFixed(0)}';
}

// ══════════════════════════════════════════
// ServiceRequest 区域 — 替代旧 CurrentServiceCard / ServiceListCard
// ══════════════════════════════════════════

String _tradeLabel(String apiTrade) {
  return switch (apiTrade) {
    'demolition' => '拆除',
    'plumbing' => '水电',
    'masonry' => '泥瓦',
    'waterproof' => '防水',
    'carpentry' => '木工',
    'painting' => '油漆',
    'installation' => '安装',
    _ => apiTrade,
  };
}

String serviceRequestStatusLabel(String status) {
  return switch (status) {
    'OPEN' => '待匹配',
    'COMPARING' => '比价中',
    'WORKER_SELECTED' => '已选定',
    'ASSIGNED' => '已选定',
    'PENDING' => '待接单',
    'ACCEPTED' => '已接单',
    'VISIT_PROPOSED' => '待确认上门时间',
    'VISIT_SCHEDULED' => '上门时间已确认',
    'ARRIVAL_PENDING' => '等待到场确认',
    'ON_SITE' => '已到场',
    'QUOTE_PENDING' => '待确认报价',
    'HIRED' => '已选定',
    'COMPLETED' => '已完成',
    'IN_PROGRESS' => '施工中',
    'CANCELLED' => '已取消',
    _ => status,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'OPEN' => ZdColors.primary,
    'COMPARING' => _gold,
    'WORKER_SELECTED' => _green,
    'ASSIGNED' => _green,
    'COMPLETED' => _green,
    _ => _textMid,
  };
}

String _formatDateTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

String _bookingStatusLabel(String status) {
  return switch (status) {
    'VISIT_PROPOSED' => '工人已建议上门时间',
    'VISIT_SCHEDULED' => '上门时间已确认',
    'ARRIVAL_PENDING' => '双方已标记到达',
    'ON_SITE' => '师傅已到场',
    'HIRED' => '已选定',
    _ => status,
  };
}

class _ServiceRequestsSection extends StatelessWidget {
  const _ServiceRequestsSection({
    required this.requests,
    required this.appointments,
    required this.loading,
    this.error,
    this.onRetry,
    required this.onFindWorker,
    required this.onTapRequest,
  });

  final List<RemoteServiceRequest> requests;
  final List<OrderItem> appointments;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback onFindWorker;
  final ValueChanged<RemoteServiceRequest> onTapRequest;

  @override
  Widget build(BuildContext context) {
    final activeAppointments = appointments
        .where((item) => item.status != '已取消' && item.status != '已拒绝')
        .toList();
    final displayRequests = _deduplicatedServiceRequestsById(requests);
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '我的装修需求',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              TextButton.icon(
                onPressed: onFindWorker,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('找师傅'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: _primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (loading && displayRequests.isEmpty) ...[
            const SizedBox(height: 32),
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(height: 32),
          ] else ...[
            if (error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(error: error!, onRetry: onRetry),
            ],
            if (displayRequests.isEmpty && activeAppointments.isEmpty) ...[
              const SizedBox(height: 32),
              _EmptyGuide(onFindWorker: onFindWorker),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 12),
              ...displayRequests.map(
                (r) => _ServiceRequestCard(
                  key: ValueKey('service-request-${r.id}'),
                  request: r,
                  onTap: () => onTapRequest(r),
                ),
              ),
              if (displayRequests.isEmpty)
                ...activeAppointments.map(_DirectAppointmentCard.new),
            ],
          ],
        ],
      ),
    );
  }
}

List<RemoteServiceRequest> _deduplicatedServiceRequestsById(
  List<RemoteServiceRequest> requests,
) {
  final selectedById = <String, RemoteServiceRequest>{};
  for (final request in requests) {
    final key = request.id;
    final existing = selectedById[key];
    if (existing == null || _isBetterServiceRequest(request, existing)) {
      selectedById[key] = request;
    }
  }
  return selectedById.values.toList();
}

bool _isBetterServiceRequest(
  RemoteServiceRequest candidate,
  RemoteServiceRequest current,
) {
  final createdDiff = candidate.createdAt.compareTo(current.createdAt);
  if (createdDiff != 0) return createdDiff > 0;

  final statusDiff = _serviceRequestProgressRank(
    candidate.status,
  ).compareTo(_serviceRequestProgressRank(current.status));
  if (statusDiff != 0) return statusDiff > 0;

  final candidateActiveCount = candidate.candidates
      .where((c) => _isActionableCandidateStatus(c.status))
      .length;
  final currentActiveCount = current.candidates
      .where((c) => _isActionableCandidateStatus(c.status))
      .length;
  final activeDiff = candidateActiveCount.compareTo(currentActiveCount);
  if (activeDiff != 0) return activeDiff > 0;

  final inviteDiff = candidate.candidates.length.compareTo(
    current.candidates.length,
  );
  if (inviteDiff != 0) return inviteDiff > 0;

  final candidateBestStatus = candidate.candidates
      .map((c) => _candidateStatusRank(c.status))
      .fold<int>(0, (best, rank) => rank > best ? rank : best);
  final currentBestStatus = current.candidates
      .map((c) => _candidateStatusRank(c.status))
      .fold<int>(0, (best, rank) => rank > best ? rank : best);
  final candidateDiff = candidateBestStatus.compareTo(currentBestStatus);
  if (candidateDiff != 0) return candidateDiff > 0;

  return candidate.updatedAt.isAfter(current.updatedAt);
}

class _DirectAppointmentCard extends StatelessWidget {
  const _DirectAppointmentCard(this.appointment);

  final OrderItem appointment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: _primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.workerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.description.isEmpty
                      ? appointment.address
                      : appointment.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _orangeSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              appointment.status,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGuide extends StatelessWidget {
  const _EmptyGuide({required this.onFindWorker});
  final VoidCallback onFindWorker;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 40,
            color: _primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          const Text(
            '还没有装修需求',
            style: TextStyle(fontSize: 14, color: _textMid),
          ),
          const SizedBox(height: 4),
          const Text(
            '发布需求后，平台为你匹配同城师傅',
            style: TextStyle(fontSize: 12, color: _textLight),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onFindWorker,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('开始找师傅'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusErrorCard extends StatelessWidget {
  const _PaymentStatusErrorCard({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: _gold, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '付款状态暂时无法加载',
              style: TextStyle(color: _textDark, fontSize: 13),
            ),
          ),
          TextButton(
            key: const Key('payment-status-retry'),
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, this.onRetry});
  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('重试', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _ServiceRequestCard extends StatelessWidget {
  const _ServiceRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });
  final RemoteServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayStatus = _serviceRequestCardStatus(request);
    final statusColor = _statusColor(displayStatus);
    final activeCount = request.candidates
        .where((candidate) => _isActionableCandidateStatus(candidate.status))
        .length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.handyman_outlined,
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_tradeLabel(request.trade)}师傅',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          serviceRequestStatusLabel(displayStatus),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${request.serviceCity} · $activeCount位候选师傅 · ${request.candidates.length}次邀请',
                    style: const TextStyle(fontSize: 12, color: _textLight),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.houseInfo?.summaryLabel ?? missingHouseInfoLabel,
                    style: const TextStyle(fontSize: 12, color: _textMid),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _textLight),
          ],
        ),
      ),
    );
  }
}

String _serviceRequestCardStatus(RemoteServiceRequest request) {
  final hasCompletedWorker = request.candidates.any(
    (candidate) => candidate.status == 'COMPLETED',
  );
  return hasCompletedWorker ? 'COMPLETED' : request.status;
}

// ══════════════════════════════════════════
// ServiceRequest 候选详情页（含取消）
// ══════════════════════════════════════════
class _ServiceRequestDetailPage extends StatefulWidget {
  const _ServiceRequestDetailPage({
    required this.request,
    this.exactBookingId,
    this.quotesForCandidate,
    this.serviceRequestApi,
    this.paymentApi,
  });

  final RemoteServiceRequest request;
  final String? exactBookingId;
  final List<RemoteQuote> Function(RemoteCandidateBooking)? quotesForCandidate;
  final ServiceRequestApi? serviceRequestApi;
  final PaymentApiClient? paymentApi;

  @override
  State<_ServiceRequestDetailPage> createState() =>
      _ServiceRequestDetailPageState();
}

class _ServiceRequestDetailPageState extends State<_ServiceRequestDetailPage> {
  late RemoteServiceRequest _request;
  Map<String, PaymentOrderModel> _paymentOrdersByBookingId = const {};
  bool _paymentStatusLoading = true;
  String? _paymentStatusError;
  String? _observedSessionUserId;
  bool _targetUnavailable = false;
  int _detailEpoch = 0;
  bool _cancelling = false;
  bool _visitLoading = false;
  bool _quoteLoading = false;
  bool _candidateLifecycleLoading = false;
  int _paymentRefreshEpoch = 0;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRequest();
      _refreshPaymentOrders();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessionUserId = OwnerAppScope.of(context).sessionUserId;
    if (_observedSessionUserId != null &&
        sessionUserId != _observedSessionUserId) {
      _markTargetUnavailable();
    }
    _observedSessionUserId = sessionUserId;
  }

  void _markTargetUnavailable() {
    if (!mounted) return;
    _detailEpoch += 1;
    _paymentRefreshEpoch += 1;
    setState(() {
      _targetUnavailable = true;
      _paymentOrdersByBookingId = const {};
      _paymentStatusLoading = false;
      _paymentStatusError = null;
    });
  }

  Future<bool> _isCurrentDetailSession({
    required String? sessionUserId,
    required String accessToken,
    required int detailEpoch,
  }) async {
    if (!mounted || detailEpoch != _detailEpoch) return false;
    final state = OwnerAppScope.of(context);
    if (sessionUserId == null || state.sessionUserId != sessionUserId) {
      return false;
    }
    final currentToken = await state.getAccessToken();
    return mounted &&
        detailEpoch == _detailEpoch &&
        state.sessionUserId == sessionUserId &&
        currentToken == accessToken;
  }

  Future<void> _refreshRequest() async {
    final sessionUserId = OwnerAppScope.of(context).sessionUserId;
    final detailEpoch = _detailEpoch;
    final token = await _getToken();
    if (token == null ||
        !await _isCurrentDetailSession(
          sessionUserId: sessionUserId,
          accessToken: token,
          detailEpoch: detailEpoch,
        )) {
      return;
    }
    try {
      final api = widget.serviceRequestApi ?? ServiceRequestApiClient();
      final requests = await api.listOwnerRequests(token);
      if (!await _isCurrentDetailSession(
        sessionUserId: sessionUserId,
        accessToken: token,
        detailEpoch: detailEpoch,
      )) {
        return;
      }
      RemoteServiceRequest? latest;
      for (final request in requests) {
        if (request.id == widget.request.id) {
          latest = request;
          break;
        }
      }
      final refreshed = latest;
      if (refreshed == null) {
        _markTargetUnavailable();
        return;
      }
      final exactBookingId = widget.exactBookingId;
      final candidates = exactBookingId == null
          ? refreshed.candidates
          : refreshed.candidates
                .where((candidate) => candidate.id == exactBookingId)
                .toList();
      if (exactBookingId != null && candidates.isEmpty) {
        _markTargetUnavailable();
        return;
      }
      if (!mounted || detailEpoch != _detailEpoch) return;
      setState(
        () => _request = RemoteServiceRequest(
          id: refreshed.id,
          ownerUserId: refreshed.ownerUserId,
          trade: refreshed.trade,
          serviceCity: refreshed.serviceCity,
          serviceAddress: refreshed.serviceAddress,
          remark: refreshed.remark,
          houseInfo: refreshed.houseInfo,
          status: refreshed.status,
          candidates: candidates,
          createdAt: refreshed.createdAt,
          updatedAt: refreshed.updatedAt,
        ),
      );
    } catch (_) {
      // 详情刷新失败不阻断页面原有数据；用户操作仍会走后端真实校验。
    }
  }

  Future<void> _refreshPaymentOrders() async {
    final paymentRefreshEpoch = ++_paymentRefreshEpoch;
    if (mounted) {
      setState(() {
        _paymentOrdersByBookingId = const {};
        _paymentStatusLoading = true;
        _paymentStatusError = null;
      });
    }
    final sessionUserId = OwnerAppScope.of(context).sessionUserId;
    final detailEpoch = _detailEpoch;
    final token = await _getToken();
    if (token == null ||
        !await _isCurrentDetailSession(
          sessionUserId: sessionUserId,
          accessToken: token,
          detailEpoch: detailEpoch,
        )) {
      return;
    }
    try {
      final api = widget.paymentApi ?? PaymentApiClient();
      final orders = await api.listOrders(token);
      final byBookingId = _latestPaymentOrdersByBookingId(orders);
      if (await _isCurrentDetailSession(
            sessionUserId: sessionUserId,
            accessToken: token,
            detailEpoch: detailEpoch,
          ) &&
          paymentRefreshEpoch == _paymentRefreshEpoch) {
        setState(() {
          _paymentOrdersByBookingId = byBookingId;
          _paymentStatusLoading = false;
          _paymentStatusError = null;
        });
      }
    } catch (_) {
      if (await _isCurrentDetailSession(
            sessionUserId: sessionUserId,
            accessToken: token,
            detailEpoch: detailEpoch,
          ) &&
          paymentRefreshEpoch == _paymentRefreshEpoch) {
        setState(() {
          _paymentOrdersByBookingId = const {};
          _paymentStatusLoading = false;
          _paymentStatusError = '付款状态暂时无法加载';
        });
      }
    }
  }

  Future<void> _continueSelecting() async {
    final token = await _getToken();
    if (token == null || !mounted) return;
    final result = await Navigator.of(context).push<CandidatePickerResult>(
      MaterialPageRoute(
        builder: (_) => CandidatePickerPage(
          requestId: _request.id,
          accessToken: token,
          trade: _request.trade,
          serviceCity: _request.serviceCity,
          houseInfo: _request.houseInfo,
          serviceRequestApi: widget.serviceRequestApi,
        ),
      ),
    );
    if (result != null && mounted) await _refreshRequest();
  }

  Future<void> _reopenRequest() async {
    if (_candidateLifecycleLoading) return;
    setState(() => _candidateLifecycleLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = widget.serviceRequestApi ?? ServiceRequestApiClient();
      final reopened = await api.reopenRequest(token, _request.id);
      if (!mounted) return;
      await Navigator.of(context).push<CandidatePickerResult>(
        MaterialPageRoute(
          builder: (_) => CandidatePickerPage(
            requestId: reopened.id,
            accessToken: token,
            trade: reopened.trade,
            serviceCity: reopened.serviceCity,
            houseInfo: reopened.houseInfo,
            serviceRequestApi: widget.serviceRequestApi,
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthApiException catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _candidateLifecycleLoading = false);
    }
  }

  Future<String?> _getToken() async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
    }
    return token;
  }

  void _handleError(Object e) {
    if (!mounted) return;
    final msg = e is AuthApiException ? e.message : '操作失败：$e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _acceptVisit(RemoteCandidateBooking candidate) async {
    setState(() => _visitLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = widget.serviceRequestApi ?? ServiceRequestApiClient();
      await api.acceptVisit(token, candidate.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已确认上门时间')));
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _visitLoading = false);
    }
  }

  Future<void> _rejectVisit(RemoteCandidateBooking candidate) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拒绝上门时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${candidate.workerName} 建议 '
              '${_formatDateTime(candidate.proposedTime)} 上门',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '拒绝原因（必填）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('请填写拒绝原因')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认拒绝'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _visitLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = widget.serviceRequestApi ?? ServiceRequestApiClient();
      await api.rejectVisit(token, candidate.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已拒绝上门时间，工人可重新提出')));
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _visitLoading = false);
    }
  }

  Future<void> _ownerArrive(RemoteCandidateBooking candidate) async {
    setState(() => _visitLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = widget.serviceRequestApi ?? ServiceRequestApiClient();
      await api.ownerArrive(token, candidate.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已标记到达')));
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _visitLoading = false);
    }
  }

  Future<void> _ownerConfirmArrival(RemoteCandidateBooking candidate) async {
    setState(() => _visitLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = widget.serviceRequestApi ?? ServiceRequestApiClient();
      await api.ownerConfirmArrival(token, candidate.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已确认师傅到场')));
        Navigator.pop(context, true);
      }
    } on Exception catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _visitLoading = false);
    }
  }

  Future<void> _acceptQuote(
    RemoteCandidateBooking candidate,
    RemoteQuote quote,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => QuoteSelectionConfirmationDialog(
        workerName: candidate.workerName,
        totalPrice: quote.totalPrice,
      ),
    );

    if (confirmed != true) return;

    setState(() => _quoteLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = WorkerQuoteApiClient();
      await api.acceptQuote(token, quote.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已选定 ${candidate.workerName} 师傅')),
        );
        Navigator.pop(context, true);
      }
    } on AuthApiException catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> _rejectQuote(
    RemoteCandidateBooking candidate,
    RemoteQuote quote,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拒绝报价'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('确定拒绝 ${candidate.workerName} 的报价？'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '拒绝原因（必填）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('请填写拒绝原因')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认拒绝'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _quoteLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final api = WorkerQuoteApiClient();
      await api.rejectQuote(token, quote.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已拒绝报价，工人可重新报价')));
        Navigator.pop(context);
      }
    } on AuthApiException catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> _openComparePage() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerQuoteComparePage(
          serviceRequestId: widget.request.id,
          workerNamesById: {
            for (final c in widget.request.candidates)
              c.workerUserId: c.workerName,
          },
        ),
      ),
    );
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _openDailyReport(RemoteCandidateBooking candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerDailyReportViewPage(bookingId: candidate.id),
      ),
    );
  }

  void _openInspection(RemoteCandidateBooking candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerInspectionPage(bookingId: candidate.id),
      ),
    );
  }

  void _openChat(RemoteCandidateBooking candidate) async {
    final state = OwnerAppScope.of(context);
    final token = await state.getAccessToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
      }
      return;
    }

    // get/create chat room by booking ID
    final chatApi = ChatApiClient();
    ChatRoomModel room;
    try {
      room = await chatApi.getOrCreateRoom(token, candidate.id);
    } on AuthApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 401) {
          await state.logout();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法创建聊天：${e.message}')));
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法创建聊天：$e')));
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          roomId: room.id,
          otherUserName: candidate.workerName,
          accessToken: token,
          currentUserId: candidate.ownerUserId,
        ),
      ),
    );
  }

  Future<void> _openPayment(RemoteCandidateBooking candidate) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerPaymentPage(
          bookingId: candidate.id,
          paymentApi: widget.paymentApi,
        ),
      ),
    );
    if (mounted) _refreshPaymentOrders();
  }

  void _openAfterSale(RemoteCandidateBooking candidate) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerAfterSalePage(bookingId: candidate.id),
      ),
    );
  }

  Future<void> _cancelCandidate(RemoteCandidateBooking candidate) async {
    if (candidate.status == 'CANCELLED') return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消候选'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('确定要取消与 ${candidate.workerName} 的预约吗？'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '取消原因（必填）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('请填写取消原因')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _cancelling = true);
    try {
      // ignore: use_build_context_synchronously
      final state = OwnerAppScope.of(context);
      // ignore: await_only_futures
      final token = await state.getAccessToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('登录已过期，请重新登录')));
        }
        return;
      }
      final api = widget.serviceRequestApi ?? ServiceRequestApiClient();
      await api.cancelAsOwner(token, candidate.id, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已取消与 ${candidate.workerName} 的预约')),
      );
      Navigator.pop(context); // return to my_home_page
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取消失败：${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取消失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetUnavailable) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('订单详情'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: _textDark,
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '该订单已更新或不再可用',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: _textMid),
            ),
          ),
        ),
      );
    }
    final req = _request;
    final active = req.candidates
        .where(
          (candidate) =>
              _isActionableCandidateStatus(candidate.status) ||
              _isProjectCandidateStatus(candidate.status),
        )
        .toList();
    final ended = req.candidates
        .where((candidate) => _isEndedCandidateStatus(candidate.status))
        .toList();
    final actionableCount = req.candidates
        .where((candidate) => _isActionableCandidateStatus(candidate.status))
        .length;
    final paymentStatusAvailable =
        !_paymentStatusLoading && _paymentStatusError == null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('${_tradeLabel(req.trade)}师傅 · 候选'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _textDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 需求摘要
          _GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(req.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        serviceRequestStatusLabel(req.status),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(req.status),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      req.serviceCity,
                      style: const TextStyle(fontSize: 13, color: _textLight),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '已邀请 ${req.candidates.length} 位师傅，当前 $actionableCount 位候选',
                  style: const TextStyle(fontSize: 14, color: _textMid),
                ),
                const SizedBox(height: 6),
                Text(
                  req.houseInfo?.summaryLabel ?? missingHouseInfoLabel,
                  style: const TextStyle(fontSize: 14, color: _textMid),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_paymentStatusError != null) ...[
            _PaymentStatusErrorCard(onRetry: _refreshPaymentOrders),
            const SizedBox(height: 12),
          ],
          if (active.isEmpty &&
              (req.status == 'OPEN' || req.status == 'COMPARING')) ...[
            _CandidateLifecycleActionCard(
              title: '还没有可继续推进的候选师傅',
              description: '已拒绝或已移除的师傅不会占用名额，可在同一需求中继续补位。',
              actionLabel: '继续选师傅',
              loading: _candidateLifecycleLoading,
              onPressed: _continueSelecting,
            ),
            const SizedBox(height: 12),
          ] else if (req.status == 'CANCELLED') ...[
            _CandidateLifecycleActionCard(
              title: '该需求已取消',
              description: '重新寻找会复制为一条新需求，旧记录会完整保留。',
              actionLabel: '重新找师傅',
              loading: _candidateLifecycleLoading,
              onPressed: _reopenRequest,
            ),
            const SizedBox(height: 12),
          ],
          // 候选列表
          if (active.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '候选师傅',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ),
            ...active.map(
              (c) => _CandidateTile(
                candidate: c,
                onCancel: _cancelling ? null : () => _cancelCandidate(c),
                onAcceptVisit: () => _acceptVisit(c),
                onRejectVisit: () => _rejectVisit(c),
                onArrive: () => _ownerArrive(c),
                onConfirmArrival: () => _ownerConfirmArrival(c),
                visitLoading: _visitLoading,
                quoteLoading: _quoteLoading,
                onAcceptQuote: (quote) => _acceptQuote(c, quote),
                onRejectQuote: (quote) => _rejectQuote(c, quote),
                quotesFor: widget.quotesForCandidate?.call(c) ?? [],
                onViewDailyReport: () => _openDailyReport(c),
                onViewInspection: () => _openInspection(c),
                onChat: () => _openChat(c),
                onPayment: paymentStatusAvailable
                    ? () => _openPayment(c)
                    : null,
                paymentOrder: _paymentOrdersByBookingId[c.id],
                onAfterSale:
                    paymentStatusAvailable &&
                        c.status == 'COMPLETED' &&
                        _paymentOrdersByBookingId[c.id]?.isPaid == true
                    ? () => _openAfterSale(c)
                    : null,
              ),
            ),
          ],
          // 多人比价入口
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _openComparePage,
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: const Text('查看所有报价'),
              style: TextButton.styleFrom(foregroundColor: _primary),
            ),
          ),
          const SizedBox(height: 12),
          if (ended.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '已结束',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textLight,
                ),
              ),
            ),
            ...ended.map((c) => _CandidateTile(candidate: c, onCancel: null)),
          ],
        ],
      ),
    );
  }
}

class _CandidateLifecycleActionCard extends StatelessWidget {
  const _CandidateLifecycleActionCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.loading,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String actionLabel;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 13, height: 1.5, color: _textMid),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: Key('service-request-$actionLabel'),
              onPressed: loading ? null : onPressed,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    this.onCancel,
    this.onAcceptVisit,
    this.onRejectVisit,
    this.onArrive,
    this.onConfirmArrival,
    this.visitLoading = false,
    this.quoteLoading = false,
    this.onAcceptQuote,
    this.onRejectQuote,
    this.quotesFor = const [],
    this.onViewDailyReport,
    this.onViewInspection,
    this.onChat,
    this.onPayment,
    this.paymentOrder,
    this.onAfterSale,
  });
  final RemoteCandidateBooking candidate;
  final VoidCallback? onCancel;
  final VoidCallback? onAcceptVisit;
  final VoidCallback? onRejectVisit;
  final VoidCallback? onArrive;
  final VoidCallback? onConfirmArrival;
  final bool visitLoading;
  final bool quoteLoading;
  final void Function(RemoteQuote)? onAcceptQuote;
  final void Function(RemoteQuote)? onRejectQuote;
  final List<RemoteQuote> quotesFor;
  final VoidCallback? onViewDailyReport;
  final VoidCallback? onViewInspection;
  final VoidCallback? onChat;
  final VoidCallback? onPayment;
  final PaymentOrderModel? paymentOrder;
  final VoidCallback? onAfterSale;

  @override
  Widget build(BuildContext context) {
    final status = candidate.status;
    final isEnded = _isEndedCandidateStatus(status);
    final isVisitFlow =
        status == 'VISIT_PROPOSED' ||
        status == 'VISIT_SCHEDULED' ||
        status == 'ARRIVAL_PENDING' ||
        status == 'ON_SITE' ||
        status == 'QUOTE_PENDING' ||
        status == 'HIRED' ||
        status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _primary.withValues(alpha: 0.12),
                child: Text(
                  candidate.workerName.isNotEmpty
                      ? candidate.workerName[0]
                      : '师',
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.workerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isEnded ? _textLight : _textDark,
                      ),
                    ),
                    if (isEnded && candidate.cancelReason != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        candidate.cancelReason!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isEnded && !isVisitFlow && onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('取消', style: TextStyle(fontSize: 13)),
                )
              else if (isEnded)
                Text(
                  _endedCandidateStatusLabel(status),
                  style: const TextStyle(fontSize: 12, color: _textLight),
                ),
            ],
          ),
          if (isVisitFlow) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _VisitFlowSection(
              status: status,
              proposedTime: candidate.proposedTime,
              onSiteAt: candidate.onSiteAt,
              scheduledVisitAt: candidate.scheduledVisitAt,
              actualOnSiteAt: candidate.actualOnSiteAt,
              arrivalConfirmedByOwner: candidate.arrivalConfirmedByOwner,
              arrivalConfirmedByWorker: candidate.arrivalConfirmedByWorker,
              onAcceptVisit: onAcceptVisit,
              onRejectVisit: onRejectVisit,
              onArrive: onArrive,
              onConfirmArrival: onConfirmArrival,
              onCancel: onCancel,
              loading: visitLoading,
              quoteLoading: quoteLoading,
              onAcceptQuote: onAcceptQuote,
              onRejectQuote: onRejectQuote,
              quotes: quotesFor,
              workerName: candidate.workerName,
              workerUserId: candidate.workerUserId,
              bookingId: candidate.id,
              onViewDailyReport: onViewDailyReport,
              onViewInspection: onViewInspection,
              onChat: onChat,
              onPayment: onPayment,
              paymentOrder: paymentOrder,
              onAfterSale: onAfterSale,
            ),
          ],
        ],
      ),
    );
  }
}

class _VisitFlowSection extends StatelessWidget {
  const _VisitFlowSection({
    required this.status,
    this.proposedTime,
    this.onSiteAt,
    this.scheduledVisitAt,
    this.actualOnSiteAt,
    this.arrivalConfirmedByOwner = false,
    this.arrivalConfirmedByWorker = false,
    this.onAcceptVisit,
    this.onRejectVisit,
    this.onArrive,
    this.onConfirmArrival,
    this.onCancel,
    this.loading = false,
    this.quotes = const [],
    this.quoteLoading = false,
    this.onAcceptQuote,
    this.onRejectQuote,
    this.workerName,
    this.workerUserId,
    this.bookingId,
    this.onViewDailyReport,
    this.onViewInspection,
    this.onChat,
    this.onPayment,
    this.paymentOrder,
    this.onAfterSale,
  });

  final String status;
  final DateTime? proposedTime;
  final DateTime? onSiteAt;
  final DateTime? scheduledVisitAt;
  final DateTime? actualOnSiteAt;
  final bool arrivalConfirmedByOwner;
  final bool arrivalConfirmedByWorker;
  final VoidCallback? onAcceptVisit;
  final VoidCallback? onRejectVisit;
  final VoidCallback? onArrive;
  final VoidCallback? onConfirmArrival;
  final VoidCallback? onCancel;
  final bool loading;
  final List<RemoteQuote> quotes;
  final bool quoteLoading;
  final void Function(RemoteQuote)? onAcceptQuote;
  final void Function(RemoteQuote)? onRejectQuote;
  final String? workerName;
  final String? workerUserId;
  final String? bookingId;
  final VoidCallback? onViewDailyReport;
  final VoidCallback? onViewInspection;
  final VoidCallback? onChat;
  final VoidCallback? onPayment;
  final PaymentOrderModel? paymentOrder;
  final VoidCallback? onAfterSale;

  @override
  Widget build(BuildContext context) {
    final selectedQuote = _preferredQuote(quotes);
    final fixedVisitAt = scheduledVisitAt ?? proposedTime;
    final arrivedAt = actualOnSiteAt ?? onSiteAt;
    final hasFixedVisit = switch (status) {
      'VISIT_SCHEDULED' ||
      'ARRIVAL_PENDING' ||
      'ON_SITE' ||
      'QUOTE_PENDING' ||
      'READY_TO_START' ||
      'HIRED' ||
      'COMPLETED' => fixedVisitAt != null,
      _ => false,
    };

    Widget statusRow(String label, [Color? color]) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? _primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? _primary,
          ),
        ),
      );
    }

    Widget actionButton(String label, {VoidCallback? onPressed, Color? color}) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(label),
        ),
      );
    }

    Widget paymentButton() {
      final order = paymentOrder;
      final isAwaitingReceipt = order?.isAwaitingWorkerReceipt == true;
      final isAwaitingPlatformReview =
          order?.isAwaitingPlatformFeeReview == true;
      final isPaid = order?.isPaid == true;
      final label = isPaid
          ? '已支付 · 查看记录'
          : isAwaitingPlatformReview
          ? '平台核验中'
          : isAwaitingReceipt
          ? '待师傅确认收款'
          : '去支付';
      final icon = isPaid
          ? Icons.check_circle_outline
          : isAwaitingPlatformReview
          ? Icons.verified_user_outlined
          : isAwaitingReceipt
          ? Icons.hourglass_top_rounded
          : Icons.payment;
      final backgroundColor = isPaid
          ? _green
          : isAwaitingPlatformReview
          ? _gold
          : isAwaitingReceipt
          ? _gold
          : _primary;

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPayment,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [statusRow(_bookingStatusLabel(status))]),
        const SizedBox(height: 8),
        if (hasFixedVisit) ...[
          Text(
            '约定上门时间：${_formatDateTime(fixedVisitAt)}',
            style: const TextStyle(fontSize: 13, color: _textDark),
          ),
          const SizedBox(height: 4),
          Text(
            '实际到场时间：${arrivedAt == null ? '待到场' : _formatDateTime(arrivedAt)}',
            style: const TextStyle(fontSize: 13, color: _textMid),
          ),
          const SizedBox(height: 8),
        ],
        if (status == 'VISIT_PROPOSED' && proposedTime != null) ...[
          Text(
            '工人建议 ${_formatDateTime(proposedTime)} 上门',
            style: const TextStyle(fontSize: 13, color: _textDark),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              actionButton('确认时间', onPressed: onAcceptVisit),
              const SizedBox(width: 8),
              actionButton(
                '拒绝',
                onPressed: onRejectVisit,
                color: Colors.orange,
              ),
              const Spacer(),
              if (onCancel != null)
                actionButton('取消预约', onPressed: onCancel, color: Colors.red),
            ],
          ),
        ] else if (status == 'VISIT_SCHEDULED' && fixedVisitAt != null) ...[
          Row(
            children: [
              actionButton('我已到达', onPressed: onArrive),
              const Spacer(),
              if (onCancel != null)
                actionButton('取消预约', onPressed: onCancel, color: Colors.red),
            ],
          ),
        ] else if (status == 'ARRIVAL_PENDING') ...[
          Text(
            '工人已标记到达，请确认对方已到场',
            style: const TextStyle(fontSize: 13, color: _textDark),
          ),
          const SizedBox(height: 10),
          actionButton('确认师傅已到场', onPressed: onConfirmArrival),
        ] else if (status == 'ON_SITE') ...[
          const Text(
            '双方已确认到场',
            style: TextStyle(fontSize: 13, color: _textDark),
          ),
        ] else if (status == 'QUOTE_PENDING') ...[
          Text(
            '报价单已提交',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.indigo,
            ),
          ),
          if (selectedQuote != null) ...[
            const SizedBox(height: 8),
            _QuoteSummary(quote: selectedQuote),
            const SizedBox(height: 10),
            if (quoteLoading) ...[
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _QuoteActionBtn(
                      label: '接受报价',
                      color: _primary,
                      onPressed: onAcceptQuote != null
                          ? () => onAcceptQuote!(selectedQuote)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuoteActionBtn(
                      label: '拒绝报价',
                      color: Colors.orange,
                      onPressed: onRejectQuote != null
                          ? () => onRejectQuote!(selectedQuote)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              '报价信息加载中…',
              style: TextStyle(fontSize: 13, color: _textLight),
            ),
          ],
        ] else if (status == 'HIRED' || status == 'COMPLETED') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 16, color: _green),
                const SizedBox(width: 6),
                Text(
                  status == 'COMPLETED'
                      ? '验收已完成'
                      : workerName != null
                      ? '已选定 $workerName 师傅'
                      : '已选定师傅',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
                if (selectedQuote != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '报价 ¥${selectedQuote.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, color: _textDark),
                  ),
                ],
              ],
            ),
          ),
          if (selectedQuote != null) ...[
            const SizedBox(height: 8),
            _QuoteSummary(quote: selectedQuote),
          ],
          if (status == 'HIRED' || status == 'COMPLETED') ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // 联系师傅按钮
            if (onChat != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text('联系${workerName ?? '师傅'}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (onChat != null) const SizedBox(height: 8),
            // 支付入口
            if (onPayment != null) paymentButton(),
            if (onPayment != null) const SizedBox(height: 8),
            // 售后入口
            if (onAfterSale != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAfterSale,
                  icon: const Icon(Icons.support_agent_outlined, size: 18),
                  label: const Text('售后'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (onAfterSale != null) const SizedBox(height: 8),
            DailyReportSection(bookingId: bookingId, workerName: workerName),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewInspection,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('节点验收'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ── 报价摘要组件 ──
class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({required this.quote});

  final RemoteQuote quote;

  double get _total {
    double t = 0;
    for (final item in quote.items) {
      t += item.subtotal ?? (item.unitPrice ?? 0) * (item.quantity ?? 0);
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...quote.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name ?? item.tradeName,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${item.quantity?.toStringAsFixed(0) ?? '-'}${item.unit ?? ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '¥${item.unitPrice?.toStringAsFixed(0) ?? '-'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '¥${item.subtotal?.toStringAsFixed(0) ?? '-'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Row(
            children: [
              const Spacer(),
              const Text('合计 ', style: TextStyle(fontSize: 13)),
              Text(
                '¥${_total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteActionBtn extends StatelessWidget {
  const _QuoteActionBtn({
    required this.label,
    required this.color,
    this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ── 施工日报区域（业主端）──
class DailyReportSection extends StatefulWidget {
  const DailyReportSection({
    super.key,
    required this.bookingId,
    this.workerName,
    this.api,
  });

  final String? bookingId;
  final String? workerName;
  final DailyReportApi? api;

  @override
  State<DailyReportSection> createState() => _DailyReportSectionState();
}

class _DailyReportSectionState extends State<DailyReportSection> {
  List<RemoteDailyReport> _reports = const [];
  bool _loading = true;
  bool _expanded = false;
  bool _loadStarted = false;
  String? _errorText;
  String? _observedSessionUserId;
  int _loadEpoch = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = OwnerAppScope.of(context);
    final sessionUserId = state.isLoggedIn ? state.sessionUserId : null;
    if (!_loadStarted || _observedSessionUserId != sessionUserId) {
      _observedSessionUserId = sessionUserId;
      _loadStarted = true;
      _loadEpoch += 1;
      _reports = const [];
      _expanded = false;
      _errorText = null;
      _loading = true;
      _loadReports();
      return;
    }
    if (_loadStarted) return;
    _loadStarted = true;
    _loadReports();
  }

  @override
  void didUpdateWidget(covariant DailyReportSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingId != widget.bookingId ||
        oldWidget.api != widget.api) {
      _reports = const [];
      _expanded = false;
      _errorText = null;
      _loading = true;
      _loadEpoch += 1;
      _loadReports();
    }
  }

  Future<void> _loadReports() async {
    final loadEpoch = ++_loadEpoch;
    final requestBookingId = widget.bookingId;
    if (mounted) {
      setState(() {
        _loading = true;
        _errorText = null;
      });
    }
    if (requestBookingId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final state = OwnerAppScope.of(context);
    String? requestToken;
    try {
      requestToken = await state.getAccessToken();
      if (!_isCurrentLoad(loadEpoch, requestBookingId)) return;
      if (requestToken == null) {
        if (_isCurrentLoad(loadEpoch, requestBookingId)) {
          setState(() {
            _loading = false;
            _errorText = '登录已过期，请重新登录';
          });
        }
        return;
      }
      final api = widget.api ?? DailyReportApiClient();
      final list = await api.getReportsByBooking(
        requestToken,
        requestBookingId,
      );
      if (!_isCurrentLoad(loadEpoch, requestBookingId)) return;
      final currentToken = await state.getAccessToken();
      if (!_isCurrentLoad(loadEpoch, requestBookingId)) return;
      if (currentToken != requestToken) {
        if (_isCurrentLoad(loadEpoch, requestBookingId)) {
          setState(() {
            _reports = const [];
            _loading = false;
            _errorText = '登录已过期，请重新登录';
          });
        }
        return;
      }
      if (_isCurrentLoad(loadEpoch, requestBookingId)) {
        setState(() {
          _reports = list;
          _loading = false;
          _errorText = null;
        });
      }
    } catch (_) {
      if (!_isCurrentLoad(loadEpoch, requestBookingId)) return;
      final currentToken = await state.getAccessToken();
      if (!_isCurrentLoad(loadEpoch, requestBookingId)) return;
      final sessionChanged =
          requestToken != null && currentToken != requestToken;
      if (_isCurrentLoad(loadEpoch, requestBookingId)) {
        setState(() {
          if (sessionChanged) _reports = const [];
          _loading = false;
          _errorText = sessionChanged ? '登录已过期，请重新登录' : '施工日报加载失败';
        });
      }
    }
  }

  bool _isCurrentLoad(int loadEpoch, String? bookingId) =>
      mounted && loadEpoch == _loadEpoch && widget.bookingId == bookingId;

  @override
  Widget build(BuildContext context) {
    if (_loading && _reports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_reports.isEmpty && _errorText == null) {
      return const SizedBox.shrink();
    }

    if (_reports.isEmpty) {
      return _DailyReportError(error: _errorText!, onRetry: _loadReports);
    }

    final latest = _reports.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 16, color: _primary),
              const SizedBox(width: 6),
              Text(
                '施工日报',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
              const Spacer(),
              Text(
                '${latest.reportDate} · 第${latest.reportRevision}版',
                style: const TextStyle(fontSize: 12, color: _textMid),
              ),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            _DailyReportError(error: _errorText!, onRetry: _loadReports),
          ],
          const SizedBox(height: 6),
          Text(
            latest.content,
            style: const TextStyle(fontSize: 13, color: _textDark),
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.workerName?.trim().isNotEmpty == true ? '${widget.workerName} · ' : ''}'
            '提交于 ${_formatReportCreatedAt(latest.createdAt)}',
            style: const TextStyle(fontSize: 11, color: _textMid),
          ),
          if (latest.photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            _OwnerReportPhotos(report: latest),
          ],
          if (_reports.length > 1 || !_expanded) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? '收起' : '展开全部（${_reports.length}篇）',
                style: const TextStyle(fontSize: 12, color: _primary),
              ),
            ),
          ],
          if (_expanded)
            ..._reports
                .skip(1)
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${r.reportDate} · 第${r.reportRevision}版',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textMid,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.content,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '提交于 ${_formatReportCreatedAt(r.createdAt)}',
                          style: const TextStyle(fontSize: 11, color: _textMid),
                        ),
                        if (r.photos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _OwnerReportPhotos(report: r),
                        ],
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _DailyReportError extends StatelessWidget {
  const _DailyReportError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ZdColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZdColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 18, color: ZdColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 12, color: _textDark),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _OwnerReportPhotos extends StatelessWidget {
  const _OwnerReportPhotos({required this.report});

  final RemoteDailyReport report;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < report.photos.length; index++)
          _OwnerReportPhoto(
            key: Key('owner-report-photo-${report.id}-$index'),
            reportId: report.id,
            index: index,
            url: report.photos[index],
          ),
      ],
    );
  }
}

class _OwnerReportPhoto extends StatefulWidget {
  const _OwnerReportPhoto({
    super.key,
    required this.reportId,
    required this.index,
    required this.url,
  });

  final String reportId;
  final int index;
  final String url;

  @override
  State<_OwnerReportPhoto> createState() => _OwnerReportPhotoState();
}

class _OwnerReportPhotoState extends State<_OwnerReportPhoto> {
  int _attempt = 0;

  Future<void> _retry() async {
    await NetworkImage(dailyReportPhotoDisplayUrl(widget.url)).evict();
    if (mounted) setState(() => _attempt += 1);
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = dailyReportPhotoDisplayUrl(widget.url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Image.network(
        displayUrl,
        key: Key(
          'owner-report-photo-image-${widget.reportId}-${widget.index}-attempt-$_attempt',
        ),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => InkWell(
          key: Key(
            'retry-owner-report-photo-${widget.reportId}-${widget.index}',
          ),
          onTap: _retry,
          child: Container(
            width: 80,
            height: 80,
            color: const Color(0xFFF0ECE7),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 20, color: _textMid),
                SizedBox(height: 3),
                Text('重试图片', style: TextStyle(fontSize: 9, color: _textMid)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatReportCreatedAt(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
