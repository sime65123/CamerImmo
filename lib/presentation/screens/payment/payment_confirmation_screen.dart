import 'package:flutter/material.dart';

class PaymentConfirmationScreen extends StatelessWidget {
  final String paymentId;
  const PaymentConfirmationScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Confirmation — TODO')),
    );
  }
} 
