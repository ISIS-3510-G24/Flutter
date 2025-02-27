import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class NotImplementedScreen extends StatelessWidget {
  const NotImplementedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Not Implemented",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "The feature you were trying to access is not yet implemented. We are so sorry.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    borderRadius: BorderRadius.circular(8),
                    color: CupertinoColors.white,
                    onPressed: () {
                       if (Navigator.canPop(context)) {
                        Navigator.maybePop(context);
                      }
                    },
                    child: Text(
                      "Vote for feature",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF66B7F0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                    const SizedBox(width: 10),
                    CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF66B7F0),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                      Navigator.maybePop(context);
                      }
                    },
                    child: Text(
                      "Go Back",
                      style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.white,
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
