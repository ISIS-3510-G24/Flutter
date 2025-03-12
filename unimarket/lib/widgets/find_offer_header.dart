import 'package:flutter/cupertino.dart';
import 'package:unimarket/theme/app_colors.dart';

class FindOfferHeader extends StatelessWidget {
  final bool isFindSelected;
  final ValueChanged<bool> onChangeTab;
  final VoidCallback onPressedSearch;

  const FindOfferHeader({
    Key? key,
    required this.isFindSelected,
    required this.onChangeTab,
    required this.onPressedSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildToggleButtons(context),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onPressedSearch,
            child: const Icon(CupertinoIcons.search, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButtons(BuildContext context) {
    // Podrías usar CupertinoSegmentedControl en vez de 2 chips
    return Row(
      children: [
        _buildChip("FIND", isFindSelected),
        const SizedBox(width: 4),
        _buildChip("OFFER", !isFindSelected),
      ],
    );
  }

  Widget _buildChip(String text, bool isSelected) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: isSelected ? AppColors.primaryBlue : AppColors.lightGreyBackground,
      borderRadius: BorderRadius.circular(18),
      onPressed: () {
        onChangeTab(text == "FIND");
      },
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: isSelected ? CupertinoColors.white : CupertinoColors.black,
        ),
      ),
    );
  }
}
