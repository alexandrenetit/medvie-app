// lib/features/syncview/syncview_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/servico_provider.dart';
import '../../shared/widgets/bottom_nav.dart';
import 'widgets/app_header.dart';
import 'widgets/syncview_card.dart';
import 'widgets/stats_row.dart';
import 'widgets/mini_calendar.dart';
import 'widgets/servico_list.dart';
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
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicoProvider>().sincronizarStatusPorTempo();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Dispara carregarMais quando o usuário está a 300px do fim da lista.
  void _onScroll() {
    if (_currentNav != 0) return;
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      final cnpjProprioId = context
          .read<OnboardingProvider>()
          .cnpjProprioIdsPorCnpj
          .values
          .firstOrNull;
      if (cnpjProprioId != null) {
        context.read<ServicoProvider>().carregarMais(cnpjProprioId);
      }
    }
  }

  Future<void> _showAddServicoModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddServicoModal(),
    );
    if (!mounted) return;
    final cnpjProprioId =
        context.read<OnboardingProvider>().cnpjProprioIdsPorCnpj.values.firstOrNull;
    if (cnpjProprioId != null) {
      context.read<ServicoProvider>().carregar(cnpjProprioId: cnpjProprioId);
    }
  }

  Widget _buildBody() {
    switch (_currentNav) {
      case 0:
        return SingleChildScrollView(
          controller: _scrollCtrl,
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
      bottomNavigationBar: BottomNav(
        currentIndex: _currentNav,
        onTap: (i) => setState(() => _currentNav = i),
        onAddServico: _showAddServicoModal,
      ),
    );
  }
}