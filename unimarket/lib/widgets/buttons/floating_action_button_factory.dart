import 'package:flutter/cupertino.dart';
import 'package:unimarket/theme/app_colors.dart';

class FloatingActionButtonFactory extends StatelessWidget {
  final String buttonText;
  final Widget destinationScreen; // Pantalla a la que irá

  const FloatingActionButtonFactory({
    Key? key,
    required this.buttonText,
    required this.destinationScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: CupertinoButton(
        color: AppColors.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        borderRadius: BorderRadius.circular(30),
        child: Text(
          buttonText,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (ctx) => destinationScreen),
          );
        },
      ),
    );
  }
}
