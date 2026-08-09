import 'package:flutter/material.dart';

import '../../services/payment_api_client.dart';
import '../home/owner_after_sale_page.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key, this.paymentApi});

  final PaymentApiClient? paymentApi;

  @override
  Widget build(BuildContext context) =>
      OwnerAfterSalePage(title: '保障与售后', paymentApi: paymentApi);
}
