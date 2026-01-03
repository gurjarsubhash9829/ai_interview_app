import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface, // ✅ FIXED
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}
