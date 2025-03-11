import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

void showCustomDropdownPicker(
  BuildContext context, {
  required String selectedCategory,
  // OJO: si no necesitas cambiar nada, puedes quitar onCategorySelected
}) {
  // Simplemente definimos la lista estática, pero no haremos nada con ella
  final categories = ["All requests", "Materials", "Technology", "Sports", "Others"];

  // Verificamos índice inicial por si 'selectedCategory' no está en la lista
  int initialIndex = categories.indexOf(selectedCategory);
  if (initialIndex < 0) {
    initialIndex = 0; 
  }

  showCupertinoModalPopup(
    context: context,
    builder: (ctx) {
      return Container(
        height: 300,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            // Barra con botón "Close"
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: const Text("Close"),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: initialIndex,
                ),
                onSelectedItemChanged: (index) {
                  // Aquí NO hacemos nada, ni Navigator.pop, ni setState
                  // Precisamente para "no filtrar" ni crashear la app
                },
                // Mostramos la lista de categorías sin hacer nada extra
                children: categories.map((cat) {
                  return Center(
                    child: Text(
                      cat,
                      style: GoogleFonts.inter(fontSize: 16),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
