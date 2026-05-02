// lib/features/relatorios/relatorios_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/medico.dart';
import '../../core/models/servico.dart';
import '../../core/providers/servico_provider.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/relatorio_anual_provider.dart';
import '../../core/services/medvie_api_service.dart';
import '../../shared/widgets/pdf_viewer_sheet.dart';

// ---------------------------------------------------------------------------
// MOTOR DE CÁLCULO TRIBUTÁRIO (validado contra legislação vigente março/2026)
// ---------------------------------------------------------------------------

class _CalculoTributario {
  // ── Simples Nacional ──────────────────────────────────────────────────────
  // Tabela Anexo III – LC 123/2006, vigente 2026 (sem alterações relevantes vs 2025)
  // Faixas: RBT12 em R$ | aliquota nominal | parcela a deduzir
  static const List<Map<String, double>> _anexoIII = [
    {'ate': 180000, 'aliq': 0.060, 'ded': 0},
    {'ate': 360000, 'aliq': 0.112, 'ded': 9360},
    {'ate': 720000, 'aliq': 0.135, 'ded': 17640},
    {'ate': 1800000, 'aliq': 0.160, 'ded': 35640},
    {'ate': 3600000, 'aliq': 0.210, 'ded': 125640},
  ];

  // Tabela Anexo V – LC 123/2006, vigente 2026
  static const List<Map<String, double>> _anexoV = [
    {'ate': 180000, 'aliq': 0.155, 'ded': 0},
    {'ate': 360000, 'aliq': 0.180, 'ded': 4500},
    {'ate': 720000, 'aliq': 0.195, 'ded': 9900},
    {'ate': 1800000, 'aliq': 0.205, 'ded': 17100},
    {'ate': 3600000, 'aliq': 0.230, 'ded': 62100},
  ];

  /// Calcula alíquota efetiva do Simples Nacional para um dado faturamento anual.
  /// [rbt12] = receita bruta acumulada 12 meses
  /// [folha12] = folha de pagamento + pró-labore 12 meses (para Fator R)
  static double calcularSimples({
    required double rbt12,
    required double folha12,
  }) {
    if (rbt12 <= 0) return 0.0;
    final fatorR = folha12 / rbt12;
    final tabela = fatorR >= 0.28 ? _anexoIII : _anexoV;

    Map<String, double> faixa = tabela.last;
    for (final f in tabela) {
      if (rbt12 <= f['ate']!) {
        faixa = f;
        break;
      }
    }
    final aliqEfetiva = ((rbt12 * faixa['aliq']!) - faixa['ded']!) / rbt12;
    return aliqEfetiva.clamp(0.0, 1.0);
  }

  // ── Lucro Presumido ───────────────────────────────────────────────────────
  // Fonte: RIR/2018, LC 224/2025 (vigente jan/2026 para IRPJ; abr/2026 para CSLL)
  // Presunção serviços médicos: 32% (sócio único, sem equiparação hospitalar)
  // Para fins do protótipo, usamos cálculo mensal (não trimestral) como estimativa.
  static const double _presuncao = 0.32;
  static const double _irpj = 0.15;
  static const double _csll = 0.09;
  static const double _pis = 0.0065;
  static const double _cofins = 0.03;

  /// Retorna a carga tributária aproximada mensal no Lucro Presumido.
  /// Nota: IRPJ e CSLL são apurados trimestralmente; aqui calculamos a
  /// estimativa mensal proporcional para exibição amigável no protótipo.
  /// ISS default 3% (varia por município — o app deve usar dado do tomador quando disponível).
  static double calcularLucroPresumido({
    required double receitaMensal,
    double issAliquota = 0.03,
  }) {
    if (receitaMensal <= 0) return 0.0;

    final basePresumida = receitaMensal * _presuncao;
    final irpjMensal = basePresumida * _irpj;
    // Adicional IRPJ: 10% sobre lucro presumido que exceder R$20k/mês (equivalente a R$60k/trim)
    final adicionalIrpj = basePresumida > 20000 ? (basePresumida - 20000) * 0.10 : 0.0;
    final csllMensal = basePresumida * _csll;
    final pisMensal = receitaMensal * _pis;
    final cofinsMensal = receitaMensal * _cofins;
    final issMensal = receitaMensal * issAliquota;

    final totalImpostos =
        irpjMensal + adicionalIrpj + csllMensal + pisMensal + cofinsMensal + issMensal;
    return totalImpostos / receitaMensal;
  }

}

// ---------------------------------------------------------------------------
// RELATÓRIOS SCREEN
// ---------------------------------------------------------------------------

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _mesSelecionado = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _mesAnterior() => setState(() {
        _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month - 1);
      });

  void _mesSeguinte() {
    final agora = DateTime.now();
    final proximo = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1);
    if (!proximo.isAfter(DateTime(agora.year, agora.month + 1))) {
      setState(() => _mesSelecionado = proximo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FechamentoMensalTab(mesSelecionado: _mesSelecionado),
                  _ResumoAnualTab(anoSelecionado: _mesSelecionado.year),
                  _InformeRendimentosTab(anoSelecionado: _mesSelecionado.year),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Text(
            'Relatórios',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          // Navegação de mês (visível apenas na aba Fechamento)
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, _) {
              if (_tabController.index != 0) return const SizedBox.shrink();
              return Row(
                children: [
                  GestureDetector(
                    onTap: _mesAnterior,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.chevron_left, color: AppColors.textMid, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _labelMes(_mesSelecionado),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _mesSeguinte,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.chevron_right, color: AppColors.textMid, size: 20),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.green,
        unselectedLabelColor: AppColors.textDim,
        labelStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Fechamento'),
          Tab(text: 'Anual'),
          Tab(text: 'Informe IR'),
        ],
      ),
    );
  }

  String _labelMes(DateTime dt) {
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${meses[dt.month - 1]} ${dt.year}';
  }
}

// ---------------------------------------------------------------------------
// ABA 1 — FECHAMENTO MENSAL
// ---------------------------------------------------------------------------

class _FechamentoMensalTab extends StatefulWidget {
  final DateTime mesSelecionado;

  const _FechamentoMensalTab({required this.mesSelecionado});

  @override
  State<_FechamentoMensalTab> createState() => _FechamentoMensalTabState();
}

class _FechamentoMensalTabState extends State<_FechamentoMensalTab> {
  bool _baixandoPdf = false;

  Future<void> _exportarFechamento(BuildContext context, OnboardingProvider onboardingP) async {
    final cnpj = onboardingP.medico?.cnpjs.firstOrNull?.cnpj;
    final cnpjProprioId = cnpj != null ? onboardingP.cnpjProprioIdsPorCnpj[cnpj] : null;
    if (cnpjProprioId == null) return;
    setState(() => _baixandoPdf = true);
    try {
      final api = context.read<RelatorioAnualProvider>().api;
      await PdfViewerSheet.abrir(
        context,
        titulo: 'Fechamento ${_labelMesCurto(widget.mesSelecionado)}',
        carregar: () => api.baixarPdf(
          tipo: TipoPdf.fechamentoMensal,
          referenciaId: cnpjProprioId,
          mes: widget.mesSelecionado.month,
          ano: widget.mesSelecionado.year,
        ),
      );
    } finally {
      if (mounted) setState(() => _baixandoPdf = false);
    }
  }

  String _labelMesCurto(DateTime d) {
    const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${meses[d.month - 1]}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ServicoProvider, OnboardingProvider>(
      builder: (context, servicoP, onboardingP, _) {
        final servicos = servicoP.doMes(widget.mesSelecionado.year, widget.mesSelecionado.month);
        final totalBruto = servicoP.totalBrutoDoMes(widget.mesSelecionado.year, widget.mesSelecionado.month);
        final medico = onboardingP.medico;
        final regime = medico?.cnpjs.firstOrNull?.regime ?? RegimeTributario.simplesNacional;

        final aliquota = _calcularAliquota(regime, totalBruto);
        final totalImpostos = totalBruto * aliquota;
        final totalLiquido = totalBruto - totalImpostos;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // ── Cards de resumo ──────────────────────────────────────────
            _CardResumoMensal(
              totalBruto: totalBruto,
              totalImpostos: totalImpostos,
              totalLiquido: totalLiquido,
              regime: regime,
              aliquota: aliquota,
            ),

            const SizedBox(height: 16),

            // ── Breakdown tributário ─────────────────────────────────────
            _BreakdownTributario(
              regime: regime,
              receitaMensal: totalBruto,
            ),

            const SizedBox(height: 16),

            // ── Lista de serviços do mês ─────────────────────────────────
            _ListaServicosMes(servicos: servicos),

            const SizedBox(height: 16),

            // ── Botão exportar fechamento mensal ─────────────────────────
            GestureDetector(
              onTap: _baixandoPdf ? null : () => _exportarFechamento(context, onboardingP),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: _baixandoPdf ? 0.06 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_baixandoPdf)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                      )
                    else
                      const Icon(Icons.picture_as_pdf_outlined, color: AppColors.cyan, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _baixandoPdf ? 'Gerando PDF…' : 'Exportar Fechamento',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cyan.withValues(alpha: _baixandoPdf ? 0.5 : 1.0),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Disclaimer obrigatório ───────────────────────────────────
            _DisclaimerCard(),
          ],
        );
      },
    );
  }

  double _calcularAliquota(RegimeTributario regime, double brutoMensal) {
    if (brutoMensal <= 0) return 0.0;
    switch (regime) {
      case RegimeTributario.simplesNacional:
        final rbt12 = brutoMensal * 12;
        final folha12 = rbt12 * 0.30;
        return _CalculoTributario.calcularSimples(rbt12: rbt12, folha12: folha12);
      case RegimeTributario.lucroPresumido:
      case RegimeTributario.lucroReal:
        return _CalculoTributario.calcularLucroPresumido(receitaMensal: brutoMensal);
    }
  }
}

class _CardResumoMensal extends StatelessWidget {
  final double totalBruto;
  final double totalImpostos;
  final double totalLiquido;
  final RegimeTributario regime;
  final double aliquota;

  const _CardResumoMensal({
    required this.totalBruto,
    required this.totalImpostos,
    required this.totalLiquido,
    required this.regime,
    required this.aliquota,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Fechamento do Mês',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMid,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _corRegime(regime).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _corRegime(regime).withValues(alpha: 0.4)),
                ),
                child: Text(
                  _labelRegime(regime),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _corRegime(regime),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Três métricas
          Row(
            children: [
              Expanded(child: _MetricaCard(label: 'Bruto', valor: totalBruto, cor: AppColors.textMid)),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricaCard(
                  label: 'Impostos (~${(aliquota * 100).toStringAsFixed(1)}%)',
                  valor: totalImpostos,
                  cor: AppColors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _MetricaCard(label: 'Líquido est.', valor: totalLiquido, cor: AppColors.green)),
            ],
          ),
          if (totalBruto > 0) ...[
            const SizedBox(height: 16),
            // Barra visual bruto → líquido
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalBruto > 0 ? totalLiquido / totalBruto : 0.0,
                backgroundColor: AppColors.amber.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${((totalLiquido / totalBruto) * 100).toStringAsFixed(1)}% do bruto fica com você',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                color: AppColors.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _corRegime(RegimeTributario r) =>
      r == RegimeTributario.simplesNacional ? AppColors.cyan : AppColors.indigo;

  String _labelRegime(RegimeTributario r) =>
      r == RegimeTributario.simplesNacional ? 'Simples Nacional' : 'Lucro Presumido';
}

class _MetricaCard extends StatelessWidget {
  final String label;
  final double valor;
  final Color cor;

  const _MetricaCard({required this.label, required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: cor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor == 0.0 ? 'A definir' : _formatCurrency(valor),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownTributario extends StatelessWidget {
  final RegimeTributario regime;
  final double receitaMensal;

  const _BreakdownTributario({required this.regime, required this.receitaMensal});

  @override
  Widget build(BuildContext context) {
    final itens = regime == RegimeTributario.simplesNacional
        ? _itensSimplesNacional()
        : _itensLucroPresumido();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Composição dos Tributos',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ...itens.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LinhaImposto(nome: item['nome']!, desc: item['desc']!, aliq: item['aliq']!),
              )),
          if (regime == RegimeTributario.lucroPresumido) ...[
            const Divider(color: AppColors.border, height: 20),
            const _InfoRow(
              icone: Icons.info_outline,
              cor: AppColors.amber,
              texto:
                  'IRPJ e CSLL são apurados trimestralmente. Os valores acima são estimativas mensais proporcionais.',
            ),
          ],
          const Divider(color: AppColors.border, height: 20),
          // Reforma Tributária — informativo
          const _InfoRow(
            icone: Icons.verified_outlined,
            cor: AppColors.green,
            texto:
                'Suas notas já estão em conformidade com a Reforma Tributária (LC 214/2025). '
                'IBS e CBS estão com alíquota zero em 2026 — transição gradual a partir de 2027.',
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _itensSimplesNacional() => [
        {'nome': 'DAS (unificado)', 'desc': 'IRPJ + CSLL + PIS + COFINS + CPP + ISS', 'aliq': 'Anexo III ou V via Fator R'},
        {'nome': 'ISS', 'desc': 'Incluso no DAS (1ª a 5ª faixa)', 'aliq': 'Embutido'},
        {'nome': 'INSS patronal (CPP)', 'desc': 'Incluso no DAS', 'aliq': 'Embutido'},
      ];

  List<Map<String, String>> _itensLucroPresumido() => [
        {'nome': 'IRPJ', 'desc': '15% s/ 32% da receita (+ adic. 10% se base trim > R\$60k)', 'aliq': '~4,8%'},
        {'nome': 'CSLL', 'desc': '9% s/ 32% da receita', 'aliq': '~2,88%'},
        {'nome': 'PIS', 'desc': '0,65% s/ receita bruta (cumulativo)', 'aliq': '0,65%'},
        {'nome': 'COFINS', 'desc': '3% s/ receita bruta (cumulativo)', 'aliq': '3%'},
        {'nome': 'ISS', 'desc': 'Alíquota municipal (default 3% — varia por cidade)', 'aliq': '2%–5%'},
      ];
}

class _LinhaImposto extends StatelessWidget {
  final String nome;
  final String desc;
  final String aliq;

  const _LinhaImposto({required this.nome, required this.desc, required this.aliq});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: AppColors.cyan,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    aliq,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
              Text(
                desc,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String texto;

  const _InfoRow({required this.icone, required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 14, color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              color: cor.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ListaServicosMes extends StatelessWidget {
  final List<Servico> servicos;

  const _ListaServicosMes({required this.servicos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Serviços do Mês',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '${servicos.length} registro${servicos.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
          if (servicos.isEmpty) ...[
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Nenhum serviço registrado neste mês',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: AppColors.textDim,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...servicos.map((s) => _LinhaServico(servico: s)),
          ],
        ],
      ),
    );
  }
}

class _LinhaServico extends StatelessWidget {
  final Servico servico;

  const _LinhaServico({required this.servico});

  @override
  Widget build(BuildContext context) {
    final cor = _corStatus(servico.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servico.tomadorNome,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _labelTipo(servico.tipo),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                servico.valor == 0.0 ? 'A definir' : _formatCurrency(servico.valor),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _labelStatus(servico.status),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _corStatus(StatusServico s) {
    switch (s) {
      case StatusServico.nfEmitida:
        return AppColors.green;
      case StatusServico.pago:
      case StatusServico.pendente:
        return AppColors.cyan;
      case StatusServico.cancelado:
        return AppColors.textDim;
      default:
        return AppColors.amber;
    }
  }

  String _labelStatus(StatusServico s) {
    switch (s) {
      case StatusServico.pendente:
        return 'Pendente';
      case StatusServico.pago:
        return 'Pago';
      case StatusServico.nfEmProcessamento:
        return 'Em emissão';
      case StatusServico.nfEmitida:
        return 'NF emitida';
      case StatusServico.aguardandoPagamento:
        return 'Ag. Pagamento';
      case StatusServico.cancelado:
        return 'Cancelado';
    }
  }

  String _labelTipo(TipoServico t) {
    switch (t) {
      case TipoServico.plantao:
        return 'Plantão';
      case TipoServico.atoAnestesico:
        return 'Ato anestésico';
      case TipoServico.laudo:
        return 'Laudo';
      case TipoServico.procedimentoCirurgico:
        return 'Procedimento cirúrgico';
      case TipoServico.consulta:
        return 'Consulta';
      case TipoServico.outros:
        return 'Outros';
    }
  }
}

class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.amber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Estimativa baseada no regime tributário cadastrado e nas alíquotas vigentes em 2026. '
              'Valores definitivos dependem da apuração contábil do período. '
              'Consulte seu contador para planejamento tributário.',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                color: AppColors.amber,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ABA 2 — RESUMO ANUAL
// ---------------------------------------------------------------------------

class _ResumoAnualTab extends StatefulWidget {
  final int anoSelecionado;

  const _ResumoAnualTab({required this.anoSelecionado});

  @override
  State<_ResumoAnualTab> createState() => _ResumoAnualTabState();
}

class _ResumoAnualTabState extends State<_ResumoAnualTab> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dispararCarga();
  }

  @override
  void didUpdateWidget(_ResumoAnualTab old) {
    super.didUpdateWidget(old);
    if (old.anoSelecionado != widget.anoSelecionado) _dispararCarga();
  }

  void _dispararCarga() {
    final onboardingP = context.read<OnboardingProvider>();
    final cnpj = onboardingP.medico?.cnpjs.firstOrNull?.cnpj;
    if (cnpj == null) return;
    final cnpjProprioId = onboardingP.cnpjProprioIdsPorCnpj[cnpj];
    if (cnpjProprioId == null) return;
    context.read<RelatorioAnualProvider>().carregar(cnpjProprioId, widget.anoSelecionado);
  }

  double _calcAliquotaMedia(RegimeTributario regime, double brutoAnual) {
    if (brutoAnual <= 0) return 0.0;
    final brutoMensal = brutoAnual / 12;
    switch (regime) {
      case RegimeTributario.simplesNacional:
        final folha12 = brutoAnual * 0.30;
        return _CalculoTributario.calcularSimples(rbt12: brutoAnual, folha12: folha12);
      case RegimeTributario.lucroPresumido:
      case RegimeTributario.lucroReal:
        return _CalculoTributario.calcularLucroPresumido(receitaMensal: brutoMensal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ServicoProvider, OnboardingProvider, RelatorioAnualProvider>(
      builder: (context, servicoP, onboardingP, relatorioP, _) {
        final regime =
            onboardingP.medico?.cnpjs.firstOrNull?.regime ??
                RegimeTributario.simplesNacional;

        // Dados: preferir backend quando disponível e para o mesmo ano
        final backendDisponivel =
            relatorioP.data != null && relatorioP.data!.ano == widget.anoSelecionado;

        final brutosPorMes = backendDisponivel
            ? relatorioP.data!.brutosPorMes
            : List.generate(12, (i) => servicoP.totalBrutoDoMes(widget.anoSelecionado, i + 1));

        final brutoAnual = backendDisponivel
            ? relatorioP.data!.totalBruto
            : brutosPorMes.fold(0.0, (a, b) => a + b);

        final impostosAnuais = backendDisponivel
            ? relatorioP.data!.totalImpostos
            : brutoAnual * _calcAliquotaMedia(regime, brutoAnual);

        final liquidoAnual = backendDisponivel
            ? relatorioP.data!.totalLiquido
            : brutoAnual - impostosAnuais;

        final aliquotaMedia = brutoAnual > 0 ? impostosAnuais / brutoAnual : 0.0;

        final lucroPresumidoLiquido = brutoAnual * 0.32 - impostosAnuais;
        final distribuicaoEstimadaAnual = lucroPresumidoLiquido.clamp(0.0, double.infinity);
        final distribuicaoMensalMedia = distribuicaoEstimadaAnual / 12;
        final irpfSobreDividendos = distribuicaoMensalMedia > 50000
            ? (distribuicaoMensalMedia - 50000) * 0.10 * 12
            : 0.0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Cabeçalho ano + badge de origem dos dados
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textDim),
                const SizedBox(width: 6),
                Text(
                  'Ano ${widget.anoSelecionado}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMid,
                  ),
                ),
                const Spacer(),
                if (relatorioP.isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.green,
                    ),
                  )
                else if (relatorioP.erro != null)
                  Tooltip(
                    message: relatorioP.erro!,
                    child: const Icon(Icons.cloud_off_outlined, size: 14, color: AppColors.amber),
                  )
                else if (backendDisponivel)
                  const Icon(Icons.cloud_done_outlined, size: 14, color: AppColors.green),
              ],
            ),

            const SizedBox(height: 16),

            // Cards totais anuais
            Row(
              children: [
                Expanded(
                    child: _CardAnual(
                        label: 'Bruto total', valor: brutoAnual, cor: AppColors.textMid)),
                const SizedBox(width: 8),
                Expanded(
                    child: _CardAnual(
                        label: 'Líquido est.', valor: liquidoAnual, cor: AppColors.green)),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                    child: _CardAnual(
                        label: 'Impostos PJ',
                        valor: impostosAnuais,
                        cor: AppColors.amber,
                        dica: brutoAnual > 0
                            ? '~${(aliquotaMedia * 100).toStringAsFixed(1)}% do bruto'
                            : null)),
                const SizedBox(width: 8),
                Expanded(
                    child: _CardAnual(
                        label: 'IR s/ lucros est.',
                        valor: irpfSobreDividendos,
                        cor: AppColors.indigo,
                        dica: irpfSobreDividendos == 0.0
                            ? 'Isento (distribuição < R\$50k/mês)'
                            : 'Lei 15.270/2025: 10% s/ distribuição > R\$50k/mês')),
              ],
            ),

            const SizedBox(height: 16),

            // Gráfico de barras mensal (sem pacote externo)
            _GraficoBarrasMensal(
              brutosPorMes: brutosPorMes,
              anoSelecionado: widget.anoSelecionado,
            ),

            // Detalhes por mês do backend (quando disponível)
            if (backendDisponivel && relatorioP.data!.meses.isNotEmpty) ...[
              const SizedBox(height: 16),
              _MesDetalheList(meses: relatorioP.data!.meses),
            ],

            const SizedBox(height: 16),

            _CardInfoDistribuicao(distribuicaoMensalMedia: distribuicaoMensalMedia),

            const SizedBox(height: 16),
            _DisclaimerCard(),
          ],
        );
      },
    );
  }
}

class _CardAnual extends StatelessWidget {
  final String label;
  final double valor;
  final Color cor;
  final String? dica;

  const _CardAnual({required this.label, required this.valor, required this.cor, this.dica});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valor == 0.0 ? 'A definir' : _formatCurrency(valor),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
          if (dica != null) ...[
            const SizedBox(height: 4),
            Text(
              dica!,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 9,
                color: AppColors.textDim,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GraficoBarrasMensal extends StatelessWidget {
  final List<double> brutosPorMes;
  final int anoSelecionado;

  const _GraficoBarrasMensal({
    required this.brutosPorMes,
    required this.anoSelecionado,
  });

  @override
  Widget build(BuildContext context) {
    final maxValor = brutosPorMes.fold(0.0, (a, b) => a > b ? a : b);
    const mesesAbrev = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    final mesAtual = DateTime.now().month;
    final anoAtual = DateTime.now().year;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Faturamento Mensal',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final valor = brutosPorMes[i];
                final altura = maxValor > 0 ? (valor / maxValor) : 0.0;
                final isMesAtual = anoSelecionado == anoAtual && (i + 1) == mesAtual;
                final cor = isMesAtual ? AppColors.green : AppColors.cyan.withValues(alpha: 0.6);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (valor > 0)
                          Text(
                            _formatK(valor),
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 8,
                              color: cor,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: 100 * altura,
                          decoration: BoxDecoration(
                            color: cor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mesesAbrev[i],
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: isMesAtual ? FontWeight.w700 : FontWeight.w400,
                            color: isMesAtual ? AppColors.green : AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _formatK(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

class _CardInfoDistribuicao extends StatelessWidget {
  final double distribuicaoMensalMedia;

  const _CardInfoDistribuicao({required this.distribuicaoMensalMedia});

  @override
  Widget build(BuildContext context) {
    final tributado = distribuicaoMensalMedia > 50000;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.indigo),
              SizedBox(width: 6),
              Text(
                'Distribuição de Lucros (2026)',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tributado
                ? 'Atenção: distribuição mensal estimada (${_formatCurrency(distribuicaoMensalMedia)}) '
                    'supera R\$50.000/mês. A Lei 15.270/2025 aplica retenção de 10% sobre o excedente a partir de 2026.'
                : 'Sua distribuição mensal estimada (${_formatCurrency(distribuicaoMensalMedia)}) '
                    'está abaixo de R\$50.000/mês — isenta da nova retenção sobre lucros (Lei 15.270/2025).',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: tributado ? AppColors.amber : AppColors.green,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Split Payment (2027): o imposto passará a ser retido automaticamente no ato do pagamento pelo tomador — '
            'o Medvie avisará quando a implementação estiver próxima.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              color: AppColors.textDim,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ABA 3 — INFORME DE RENDIMENTOS
// ---------------------------------------------------------------------------

class _InformeRendimentosTab extends StatefulWidget {
  final int anoSelecionado;

  const _InformeRendimentosTab({required this.anoSelecionado});

  @override
  State<_InformeRendimentosTab> createState() => _InformeRendimentosTabState();
}

class _InformeRendimentosTabState extends State<_InformeRendimentosTab> {
  bool _baixandoPdf = false;

  Future<void> _exportarInforme(BuildContext context, OnboardingProvider onboardingP) async {
    final cnpj = onboardingP.medico?.cnpjs.firstOrNull?.cnpj;
    final cnpjProprioId = cnpj != null ? onboardingP.cnpjProprioIdsPorCnpj[cnpj] : null;
    if (cnpjProprioId == null) return;
    setState(() => _baixandoPdf = true);
    try {
      final api = context.read<RelatorioAnualProvider>().api;
      await PdfViewerSheet.abrir(
        context,
        titulo: 'Informe de Rendimentos ${widget.anoSelecionado}',
        carregar: () => api.baixarPdf(
          tipo: TipoPdf.informeIr,
          referenciaId: cnpjProprioId,
          ano: widget.anoSelecionado,
        ),
      );
    } finally {
      if (mounted) setState(() => _baixandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anoAtual = DateTime.now().year;
    return Consumer2<ServicoProvider, OnboardingProvider>(
      builder: (context, servicoP, onboardingP, _) {
        final anoSelecionado = widget.anoSelecionado;
        // Agrupa serviços executados por tomador no ano
        final servicosAno = List.generate(12, (i) {
          return servicoP.doMes(anoSelecionado, i + 1);
        }).expand((s) => s).where((s) => s.status.foiExecutado && s.valor > 0).toList();

        // Agrupa por nomeTomador
        final Map<String, _RendimentoTomador> agrupado = {};
        for (final s in servicosAno) {
          agrupado.putIfAbsent(
            s.tomadorNome,
            () => _RendimentoTomador(nome: s.tomadorNome, cnpj: s.tomadorCnpj),
          );
          agrupado[s.tomadorNome]!.adicionar(s.valor, s.status == StatusServico.nfEmitida);
        }

        final tomadores = agrupado.values.toList()
          ..sort((a, b) => b.totalBruto.compareTo(a.totalBruto));

        final totalGeral = tomadores.fold(0.0, (sum, t) => sum + t.totalBruto);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Cabeçalho
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 16, color: AppColors.cyan),
                      const SizedBox(width: 8),
                      Text(
                        'Informe de Rendimentos $anoSelecionado',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Total faturado:',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        totalGeral == 0.0 ? 'A definir' : _formatCurrency(totalGeral),
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tomadores.length} tomador${tomadores.length != 1 ? 'es' : ''} · ${servicosAno.length} serviço${servicosAno.length != 1 ? 's' : ''} executado${servicosAno.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (tomadores.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 32, color: AppColors.textDim),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhum serviço executado em $anoSelecionado',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...tomadores.map((t) => _CardTomadorInforme(tomador: t, totalGeral: totalGeral)),

            const SizedBox(height: 16),

            // Botão exportar Informe de IR (apenas ano fechado)
            if (anoSelecionado < anoAtual)
              GestureDetector(
                onTap: _baixandoPdf ? null : () => _exportarInforme(context, onboardingP),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: _baixandoPdf ? 0.06 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_baixandoPdf)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                        )
                      else
                        const Icon(Icons.picture_as_pdf_outlined, color: AppColors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _baixandoPdf ? 'Gerando PDF…' : 'Exportar Informe de IR',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green.withValues(alpha: _baixandoPdf ? 0.5 : 1.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            _DisclaimerCard(),
          ],
        );
      },
    );
  }
}

class _RendimentoTomador {
  final String nome;
  final String cnpj;
  double totalBruto = 0.0;
  int totalServicos = 0;
  int nfsEmitidas = 0;

  _RendimentoTomador({required this.nome, required this.cnpj});

  void adicionar(double valor, bool nfEmitida) {
    totalBruto += valor;
    totalServicos++;
    if (nfEmitida) nfsEmitidas++;
  }
}

class _CardTomadorInforme extends StatelessWidget {
  final _RendimentoTomador tomador;
  final double totalGeral;

  const _CardTomadorInforme({required this.tomador, required this.totalGeral});

  @override
  Widget build(BuildContext context) {
    final percentual = totalGeral > 0 ? tomador.totalBruto / totalGeral : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tomador.nome,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    if (tomador.cnpj.isNotEmpty)
                      Text(
                        'CNPJ: ${tomador.cnpj}',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(tomador.totalBruto),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra de proporção
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentual,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Chip('${tomador.totalServicos} serviço${tomador.totalServicos != 1 ? 's' : ''}', AppColors.textDim),
              const SizedBox(width: 6),
              _Chip('${tomador.nfsEmitidas} NF${tomador.nfsEmitidas != 1 ? 's' : ''} emitida${tomador.nfsEmitidas != 1 ? 's' : ''}', AppColors.green),
              const Spacer(),
              Text(
                '${(percentual * 100).toStringAsFixed(1)}% do total',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color cor;

  const _Chip(this.label, this.cor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MES DETALHE LIST — exibido na Aba Anual quando há dados do backend
// ---------------------------------------------------------------------------

class _MesDetalheList extends StatelessWidget {
  final List<RelatorioAnualMes> meses;

  const _MesDetalheList({required this.meses});

  static const _nomesMes = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    final mesesComValor = meses.where((m) => m.totalBruto > 0).toList();
    if (mesesComValor.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Detalhamento Mensal',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          ...mesesComValor.map((m) => _MesDetalheItem(mes: m, nomeMes: _nomesMes[m.mes - 1])),
        ],
      ),
    );
  }
}

class _MesDetalheItem extends StatefulWidget {
  final RelatorioAnualMes mes;
  final String nomeMes;

  const _MesDetalheItem({required this.mes, required this.nomeMes});

  @override
  State<_MesDetalheItem> createState() => _MesDetalheItemState();
}

class _MesDetalheItemState extends State<_MesDetalheItem> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.mes;
    return Column(
      children: [
        const Divider(height: 1, color: AppColors.border),
        InkWell(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  widget.nomeMes,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatCurrency(m.totalBruto),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expandido ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppColors.textDim,
                ),
              ],
            ),
          ),
        ),
        if (_expandido) ...[
          // Resumo do mês
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _MiniChip('Impostos: ${_formatCurrency(m.totalImpostos)}', AppColors.amber),
                const SizedBox(width: 6),
                _MiniChip('Líquido: ${_formatCurrency(m.totalLiquido)}', AppColors.green),
              ],
            ),
          ),
          // Tomadores
          if (m.tomadores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receita por tomador',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...m.tomadores.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.nome,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: AppColors.textMid,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatCurrency(t.totalBruto),
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cyan,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color cor;
  const _MiniChip(this.label, this.cor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HELPERS GLOBAIS
// ---------------------------------------------------------------------------

String _formatCurrency(double v) {
  if (v == 0.0) return 'A definir';
  final absV = v.abs();
  String formatted;
  if (absV >= 1000000) {
    formatted = 'R\$ ${(absV / 1000000).toStringAsFixed(2)}M';
  } else if (absV >= 1000) {
    final intPart = (absV ~/ 1000).toString();
    final decPart = ((absV % 1000) / 10).toStringAsFixed(0).padLeft(2, '0');
    formatted = 'R\$ $intPart.${decPart.padRight(3, '0')}';
  } else {
    formatted = 'R\$ ${absV.toStringAsFixed(2).replaceAll('.', ',')}';
  }
  return v < 0 ? '- $formatted' : formatted;
}