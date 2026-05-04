import 'package:flutter/material.dart';

class PaymentScreen extends StatelessWidget {
  final String leaseId;
  const PaymentScreen({super.key, required this.leaseId});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Paiement — TODO')),
    );
  }
} 
