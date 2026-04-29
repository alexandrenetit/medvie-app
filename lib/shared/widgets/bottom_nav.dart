// lib/shared/widgets/bottom_nav.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/servico_provider.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddServico;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddServico,
  });

  @override
  Widget build(BuildContext context) {
    final pendentes = context.watch<ServicoProvider>().countPendentesNf;

    return SizedBox(
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 64,
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavItem(
                          index: 0,
                          icon: Icons.dashboard_outlined,
                          iconActive: Icons.dashboard,
                          label: 'SyncView',
                          current: currentIndex,
                          onTap: onTap,
                        ),
                        _NavItem(
                          index: 1,
                          icon: Icons.calendar_month_outlined,
                          iconActive: Icons.calendar_month,
                          label: 'Agenda',
                          current: currentIndex,
                          onTap: onTap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavItem(
                          index: 2,
                          icon: Icons.receipt_long_outlined,
                          iconActive: Icons.receipt_long,
                          label: 'Notas',
                          current: currentIndex,
                          onTap: onTap,
                          badge: pendentes,
                        ),
                        _NavItem(
                          index: 3,
                          icon: Icons.bar_chart_outlined,
                          iconActive: Icons.bar_chart,
                          label: 'Relatórios',
                          current: currentIndex,
                          onTap: onTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onAddServico,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final IconData iconActive;
  final String label;
  final int current;
  final ValueChanged<int> onTap;
  final int? badge;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.current,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  active ? iconActive : icon,
                  size: 24,
                  color: active ? AppColors.green : AppColors.textDim,
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.green : AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
