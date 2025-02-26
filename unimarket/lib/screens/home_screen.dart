import 'package:flutter/cupertino.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bienvenido'),
      ),
      child: Center(
        child: Text(
          'Bienvenido a UniMarket',
          style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
        ),
      ),
    );
  }
}
