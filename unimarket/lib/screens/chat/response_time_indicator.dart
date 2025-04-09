import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';

class ChatResponseTimeIndicator extends StatelessWidget {
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final String currentUserId;

  const ChatResponseTimeIndicator({
    Key? key,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Añadir logs para diagnosticar
    print('ChatResponseTimeIndicator - lastMessageTime: $lastMessageTime');
    print('ChatResponseTimeIndicator - lastMessageSenderId: $lastMessageSenderId');
    print('ChatResponseTimeIndicator - currentUserId: $currentUserId');
    
    // Verificar si hay tiempo de último mensaje y si no es del usuario actual
    if (lastMessageTime == null) {
      print('ChatResponseTimeIndicator - No se muestra: lastMessageTime es null');
      return const SizedBox.shrink();
    }
    
    if (lastMessageSenderId == null) {
      print('ChatResponseTimeIndicator - No se muestra: lastMessageSenderId es null');
      return const SizedBox.shrink();
    }
    
    if (lastMessageSenderId == currentUserId) {
      print('ChatResponseTimeIndicator - No se muestra: mensaje enviado por el usuario actual');
      return const SizedBox.shrink();
    }

    // Calcular horas transcurridas (más preciso que días)
    final int hoursPassed = DateTime.now().difference(lastMessageTime!).inHours;
    final int daysPassed = hoursPassed ~/ 24; // División entera
    
    print('ChatResponseTimeIndicator - Horas: $hoursPassed, Días: $daysPassed');
    
    // No mostrar si han pasado menos de 24 horas
    if (hoursPassed < 24) {
      print('ChatResponseTimeIndicator - No se muestra: han pasado menos de 24 horas');
      return const SizedBox.shrink();
    }

    // Determinar la apariencia basada en el tiempo transcurrido
    Color backgroundColor = AppColors.primaryBlue.withOpacity(0.1);
    Color textColor = AppColors.primaryBlue;
    IconData icon = CupertinoIcons.clock;
    String timeText = '$daysPassed ${daysPassed == 1 ? 'día' : 'días'}';
    String messageText = 'Este mensaje lleva esperando respuesta.';

    // Cambiar la apariencia para respuestas urgentes
    if (daysPassed >= 3 && daysPassed < 7) {
      backgroundColor = CupertinoColors.systemOrange.withOpacity(0.1);
      textColor = CupertinoColors.systemOrange;
      icon = CupertinoIcons.exclamationmark_circle;
      messageText = 'Este mensaje lleva varios días sin respuesta.';
    }
    
    if (daysPassed >= 7) {
      backgroundColor = CupertinoColors.systemRed.withOpacity(0.1);
      textColor = CupertinoColors.systemRed;
      icon = CupertinoIcons.exclamationmark_triangle;
      messageText = 'Este mensaje necesita una respuesta urgentemente.';
    }

    print('ChatResponseTimeIndicator - Mostrando indicador: $daysPassed días');

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: textColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esperando hace $timeText',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  messageText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}