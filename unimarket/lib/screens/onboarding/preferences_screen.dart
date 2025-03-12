import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  _PreferencesScreenState createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final List<String> preferences = [
    "Selling Items",
    "Turbo Delivery",
    "Buying Major Specific Materials",
    "Buying Class Specific Materials",
    "Extra Curricular Supplies",
    "School Supplies Exchange",
    "Advanced Browsing",
    "Everything"
  ];

  final Set<String> selectedPreferences = {}; // Permite múltiples selecciones

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Personalise your experience"),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de progreso
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Stack(
                  children: [
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Container(
                      height: 6,
                      width: MediaQuery.of(context).size.width * 0.75, // 75% de progreso
                      decoration: BoxDecoration(
                        color: const Color(0xFF66B7F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),

              // Título
              const SizedBox(height: 10),
              Text(
                "Personalise your experience",
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Subtítulo
              const SizedBox(height: 5),
              Text(
                "Choose your interests.",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),

              const SizedBox(height: 20),

              // Lista de opciones (Múltiples selecciones)
              Expanded(
                child: ListView.builder(
                  itemCount: preferences.length,
                  itemBuilder: (context, index) {
                    String option = preferences[index];
                    bool isSelected = selectedPreferences.contains(option); // 🔹 Verifica si está seleccionado

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedPreferences.remove(option); // 🔹 Si está, lo quita
                          } else {
                            selectedPreferences.add(option); // 🔹 Si no está, lo añade
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEAF3FF) : CupertinoColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF66B7F0) : CupertinoColors.systemGrey5,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                CupertinoIcons.checkmark_alt_circle_fill,
                                color: Color(0xFF66B7F0),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Botón Next (Envia las selecciones)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: const Color(0xFF66B7F0),
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    onPressed: () {
                      // Aquí se enviarán los datos a Firebase (comentado por ahora)
                      // sendPreferencesToFirebase(selectedPreferences);
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    child: Text(
                      "Next",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
