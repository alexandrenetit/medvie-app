// lib/features/syncview/syncview_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/servico_provider.dart';
import '../../shared/widgets/bottom_nav.dart';
import 'widgets/app_header.dart';
import 'widgets/syncview_card.dart';
import 'widgets/stats_row.dart';
import 'widgets/mini_calendar.dart';
import 'widgets/servico_list.dart';
import 'widgets/add_servico_fab.dart';
import 'widgets/add_servico_modal.dart';
import '../agenda/agenda_screen.dart';
import '../notas/notas_screen.dart';
import '../relatorios/relatorios_screen.dart';

class SyncViewScreen extends StatefulWidget {
  const SyncViewScreen({super.key});

  @override
  State<SyncViewScreen> createState() => _SyncViewScreenState();
}

class _SyncViewScreenState extends State<SyncViewScreen> {
  int _currentNav = 0;

  @override
  void initState() {
    super.initState();
    // Promove plantões planejados cuja data/hora já passou para confirmado.
    // Roda após o primeiro frame para garantir que o Provider está disponível.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicoProvider>().sincronizarStatusPorTempo();
    });
  }

  void _showAddServicoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddServicoModal(),
    );
  }

  Widget _buildBody() {
    switch (_currentNav) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(),
              const SyncViewCard(),
              const StatsRow(),
              MiniCalendar(
                onVerAgenda: () => setState(() => _currentNav = 1),
              ),
              const ServicoList(),
            ],
          ),
        );
      case 1:
        return const AgendaScreen();
      case 2:
        return const NotasScreen();
      case 3:
        return const RelatoriosScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: MedvieBottomNav(
        currentIndex: _currentNav,
        onTap: (i) => setState(() => _currentNav = i),
      ),
      floatingActionButton: _currentNav == 0
          ? AddServicoFab(onTap: _showAddServicoModal)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}