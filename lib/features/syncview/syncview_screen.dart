// lib/features/syncview/syncview_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/certificado_provider.dart';
import '../../core/providers/dashboard_provider.dart';
import '../../core/providers/nota_fiscal_provider.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/servico_provider.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../agenda/agenda_screen.dart';
import '../certificado/screens/certificado_detalhe_screen.dart';
import '../notas/notas_screen.dart';
import '../relatorios/relatorios_screen.dart';
import 'widgets/add_servico_modal.dart';
import 'widgets/app_header.dart';
import 'widgets/pipeline_card.dart';
import 'widgets/precisa_de_voce.dart';
import 'widgets/primeiro_uso.dart';
import 'widgets/proximo_plantao_card.dart';
import 'widgets/simulador_bottom_sheet.dart';
import 'widgets/syncview_hero.dart';
import 'widgets/ultimos_lancamentos.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ServicoProvider>().sincronizarStatusPorTempo();
      final cnpjId = _cnpjProprioId;
      if (cnpjId != null && cnpjId.isNotEmpty) {
        context.read<CertificadoProvider>().carregar(cnpjId);
      }
    });
  }

  /// CNPJ próprio ativo (id backend). Prioriza o CNPJ atual; cai para o primeiro
  /// cadastrado quando `cnpjAtual` ainda não foi restaurado.
  String? get _cnpjProprioId {
    final onboarding = context.read<OnboardingProvider>();
    return onboarding.cnpjProprioIdsPorCnpj[onboarding.cnpjAtual] ??
        onboarding.cnpjProprioIdsPorCnpj.values.firstOrNull;
  }

  Future<void> _showAddServicoModal() async {
    // Cap altura em 92% da tela para o modal não cobrir system bars nem a
    // BottomNav da rota pai.
    final maxH = MediaQuery.of(context).size.height * 0.92;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: maxH),
      builder: (_) => const AddServicoModal(),
    );
    if (!mounted) return;
    final cnpjProprioId = _cnpjProprioId;
    if (cnpjProprioId != null && cnpjProprioId.isNotEmpty) {
      context.read<ServicoProvider>().carregar(cnpjProprioId: cnpjProprioId);
    }
  }

  Future<void> _showSimulador() async {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: maxH),
      builder: (_) => const SimuladorBottomSheet(),
    );
  }

  void _abrirDetalhesFiscais() {
    final cnpjId = _cnpjProprioId;
    if (cnpjId == null || cnpjId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CertificadoDetalheScreen(cnpjId: cnpjId),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentNav) {
      case 0:
        return _SyncViewHome(
          onIrParaAgenda: () => setState(() => _currentNav = 1),
          onIrParaNotas: () => setState(() => _currentNav = 2),
          onAbrirFiscal: _abrirDetalhesFiscais,
          onRegistrar: () {
            _showAddServicoModal();
          },
          onSimular: () {
            _showSimulador();
          },
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
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentNav,
        onTap: (i) => setState(() => _currentNav = i),
        onAddServico: () {
          _showAddServicoModal();
        },
      ),
    );
  }
}

/// Home (aba SyncView) — provê um [DashboardProvider] próprio e monta o pipeline
/// financeiro (opção 1b). Escopo de aba: o provider vive enquanto a aba está
/// ativa, espelhando o comportamento anterior do `SyncViewCard`.
class _SyncViewHome extends StatelessWidget {
  final VoidCallback onIrParaAgenda;
  final VoidCallback onIrParaNotas;
  final VoidCallback onAbrirFiscal;
  final VoidCallback onRegistrar;
  final VoidCallback onSimular;

  const _SyncViewHome({
    required this.onIrParaAgenda,
    required this.onIrParaNotas,
    required this.onAbrirFiscal,
    required this.onRegistrar,
    required this.onSimular,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DashboardProvider>(
      create: (ctx) => DashboardProvider(ctx.read<OnboardingProvider>().api),
      child: _SyncViewHomeBody(
        onIrParaAgenda: onIrParaAgenda,
        onIrParaNotas: onIrParaNotas,
        onAbrirFiscal: onAbrirFiscal,
        onRegistrar: onRegistrar,
        onSimular: onSimular,
      ),
    );
  }
}

class _SyncViewHomeBody extends StatefulWidget {
  final VoidCallback onIrParaAgenda;
  final VoidCallback onIrParaNotas;
  final VoidCallback onAbrirFiscal;
  final VoidCallback onRegistrar;
  final VoidCallback onSimular;

  const _SyncViewHomeBody({
    required this.onIrParaAgenda,
    required this.onIrParaNotas,
    required this.onAbrirFiscal,
    required this.onRegistrar,
    required this.onSimular,
  });

  @override
  State<_SyncViewHomeBody> createState() => _SyncViewHomeBodyState();
}

class _SyncViewHomeBodyState extends State<_SyncViewHomeBody> {
  late final DateTime _mes;
  int _retryCount = 0;
  static const int _maxRetries = 5;

  ServicoProvider? _servicoRef;
  OnboardingProvider? _onboardingRef;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = DateTime(agora.year, agora.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _carregarDashboard();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _servicoRef?.removeListener(_onServicosAtualizado);
    _servicoRef = context.read<ServicoProvider>();
    _servicoRef!.addListener(_onServicosAtualizado);
    // Injeta a referência p/ atualização in-memory do dashboard após POST /servicos.
    _servicoRef!.dashboardRef = context.read<DashboardProvider>();

    _onboardingRef?.removeListener(_onOnboardingAtualizado);
    _onboardingRef = context.read<OnboardingProvider>();
    _onboardingRef!.addListener(_onOnboardingAtualizado);
  }

  void _onServicosAtualizado() {
    if (!mounted) return;
    // Só recarrega ao término do carregamento, evitando disparo duplo.
    if (context.read<ServicoProvider>().carregando) return;
    _carregarDashboard();
  }

  void _onOnboardingAtualizado() {
    if (!mounted) return;
    // Só recarrega se o dashboard ainda não foi carregado (cnpj recém-restaurado).
    if (context.read<DashboardProvider>().dashboard != null) return;
    _carregarDashboard();
  }

  String get _cnpjId {
    final o = context.read<OnboardingProvider>();
    return o.cnpjProprioIdsPorCnpj[o.cnpjAtual] ??
        o.cnpjProprioIdsPorCnpj.values.firstOrNull ??
        '';
  }

  void _carregarDashboard() {
    if (!mounted) return;
    final id = _cnpjId;
    if (id.isEmpty) {
      if (_retryCount < _maxRetries) {
        _retryCount++;
        Future.delayed(const Duration(milliseconds: 300), _carregarDashboard);
      }
      return;
    }
    _retryCount = 0;
    context.read<DashboardProvider>().carregar(id, _mes.month, _mes.year);
    // Pendências ("Precisa de você") dependem das NFs rejeitadas — carrega as
    // notas junto com o dashboard para que nunca fiquem escondidas na entrada
    // (princípio 3 do briefing). Silencioso: sem spinner global da lista.
    final notas = context.read<NotaFiscalProvider?>();
    if (notas != null && notas.notas.isEmpty && !notas.carregando) {
      unawaited(notas.carregar(id, silencioso: true));
    }
  }

  Future<void> _refresh() async {
    final id = _cnpjId;
    if (id.isEmpty) return;
    final dash = context.read<DashboardProvider>();
    final servicos = context.read<ServicoProvider>();
    final notas = context.read<NotaFiscalProvider?>();
    await Future.wait<void>([
      dash.carregar(id, _mes.month, _mes.year),
      servicos.carregar(cnpjProprioId: id),
    ]);
    if (notas != null) await notas.carregar(id);
  }

  @override
  void dispose() {
    _servicoRef?.removeListener(_onServicosAtualizado);
    _servicoRef?.dashboardRef = null;
    _onboardingRef?.removeListener(_onOnboardingAtualizado);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final servicoProv = context.watch<ServicoProvider>();

    final carregandoInicial =
        dash.dashboard == null && (dash.isLoading || servicoProv.carregando);
    final erroSemDados = dash.error != null && dash.dashboard == null;

    final pipeline = dash.dashboard?.pipeline;
    final temServicosMes = servicoProv.servicos.any(
      (s) => s.data.year == _mes.year && s.data.month == _mes.month,
    );
    final temAtividade =
        temServicosMes || (pipeline != null && !pipeline.vazio);

    // Primeiro uso: dashboard carregado, sem erro e sem atividade no mês. O
    // guard de loading/erro evita piscar o convite antes dos dados chegarem.
    final primeiroUso = !carregandoInicial && !erroSemDados && !temAtividade;

    // Plantão e "Últimos lançamentos" são mutuamente exclusivos: só há feed
    // quando não existe compromisso futuro na Agenda.
    final temPlantao = ProximoPlantaoCard.proximo(servicoProv.servicos) != null;

    final conteudo = primeiroUso
        ? <Widget>[
            const SyncViewHero(primeiroUso: true),
            PrimeiroUso(
              onRegistrar: widget.onRegistrar,
              onSimular: widget.onSimular,
            ),
          ]
        : <Widget>[
            SyncViewHero(onRetry: _carregarDashboard),
            PipelineCard(
              onRecebidoTap: widget.onIrParaNotas,
              onAReceberTap: widget.onIrParaNotas,
              onAguardandoTap: widget.onIrParaNotas,
            ),
            PrecisaDeVoce(onPendenciaTap: (_) => widget.onIrParaNotas()),
            if (temPlantao)
              ProximoPlantaoCard(onAbrirAgenda: widget.onIrParaAgenda)
            else
              UltimosLancamentos(mes: _mes, onVerTodos: widget.onIrParaNotas),
          ];

    return Column(
      children: [
        AppHeader(onCnpjTap: widget.onAbrirFiscal),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.green,
            backgroundColor: AppColors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: conteudo,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
