// lib/features/syncview/widgets/syncview_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/servico_provider.dart';

class SyncViewCard extends StatelessWidget {
  const SyncViewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DashboardProvider(ctx.read<OnboardingProvider>().api),
      child: const _SyncViewCardBody(),
    );
  }
}

class _SyncViewCardBody extends StatefulWidget {
  const _SyncViewCardBody();

  @override
  State<_SyncViewCardBody> createState() => _SyncViewCardBodyState();
}

class _SyncViewCardBodyState extends State<_SyncViewCardBody> {
  double _previousBruto = 0;
  double _previousLiquido = 0;
  double _previousProgresso = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final agora = DateTime.now();
      final onboarding = context.read<OnboardingProvider>();
      final cnpjProprioId =
          onboarding.cnpjProprioIdsPorCnpj[onboarding.cnpjAtual] ?? '';
      context
          .read<DashboardProvider>()
          .carregar(cnpjProprioId, agora.month, agora.year);
    });
  }

  String _formatMoeda(double valor) {
    final inteiro = valor.toInt();
    final str = inteiro.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'R\$ ${buffer.toString()}';
  }

  String _nomeMes(int mes) {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    return meses[mes - 1];
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1F16), Color(0xFF0D1E2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.2),
          width: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dashProvider = context.watch<DashboardProvider>();
    final servicoProvider = context.watch<ServicoProvider>();
    final agora = DateTime.now();

    if (dashProvider.isLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: _cardDecoration,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.green,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final dashboard = dashProvider.dashboard;
    final bruto = dashboard?.totalBruto ??
        servicoProvider.totalBrutoDoMes(agora.year, agora.month);
    final liquido = dashboard?.totalLiquidoEstimado ?? bruto * 0.72;
    final meta = dashboard?.metaMensal ?? 30000.0;
    final progresso = meta > 0 ? (bruto / meta).clamp(0.0, 1.0) : 0.0;

    final fromBruto = _previousBruto;
    final fromLiquido = _previousLiquido;
    final fromProgresso = _previousProgresso;

    _previousBruto = bruto;
    _previousLiquido = liquido;
    _previousProgresso = progresso;

    final mesLabel = '${_nomeMes(agora.month)} ${agora.year}';
    final totalServicos = servicoProvider.doMes(agora.year, agora.month).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hexagon_outlined,
                  color: AppColors.green, size: 14),
              const SizedBox(width: 6),
              Text(
                'SYNCVIEW',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.green,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Text(
                mesLabel,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textDim,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BRUTO',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppColors.textDim,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: fromBruto, end: bruto),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (_, value, _) => Text(
                        _formatMoeda(value),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 24,
                          color: AppColors.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$totalServicos serviço(s)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textDim,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 64,
                color: Colors.white.withValues(alpha: 0.06),
                margin: const EdgeInsets.only(right: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LÍQUIDO EST.',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppColors.textDim,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: fromLiquido, end: liquido),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (_, value, _) => Text(
                        _formatMoeda(value),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 24,
                          color: AppColors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'após ISS + IRPF + INSS',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.textDim,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meta mensal',
                style: GoogleFonts.outfit(
                    fontSize: 11, color: AppColors.textDim),
              ),
              Text(
                '${(progresso * 100).toStringAsFixed(0)}% de ${_formatMoeda(meta)}',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 11, color: AppColors.textMid),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: fromProgresso, end: progresso),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.green),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
