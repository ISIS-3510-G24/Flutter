import 'package:flutter/cupertino.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text("Payment"),
      ),
      child: Center(
        child: Text("Payment Screen"),
      ),
    );
  }
}