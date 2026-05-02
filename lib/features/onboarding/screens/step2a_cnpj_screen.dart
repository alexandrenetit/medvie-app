// lib/features/onboarding/screens/step2a_cnpj_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/medico.dart';
import '../../../core/providers/onboarding_provider.dart';

class Step2aCnpjScreen extends StatefulWidget {
  final VoidCallback onNext;
  const Step2aCnpjScreen({super.key, required this.onNext});

  @override
  State<Step2aCnpjScreen> createState() => _Step2aCnpjScreenState();
}

class _Step2aCnpjScreenState extends State<Step2aCnpjScreen> {
  final _cnpjCtrl         = TextEditingController();
  final _inscricaoCtrl    = TextEditingController();
  final _razaoSocialCtrl  = TextEditingController();
  final _municipioCtrl    = TextEditingController();
  bool  _consultado       = false;
  bool  _salvando         = false;
  bool  _modoManual       = false;
  late  OnboardingProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<OnboardingProvider>();
    _syncControllers();
    _provider.addListener(_syncControllers);
  }

  /// Sincroniza controllers com provider — chamado no init e a cada notifyListeners.
  /// Garante que ao navegar de volta ou após restore assíncrono os campos fiquem preenchidos.
  void _syncControllers() {
    if (_cnpjCtrl.text.isEmpty && _provider.cnpjAtual.isNotEmpty) {
      _cnpjCtrl.text = _provider.cnpjAtual;
    }
    if (_inscricaoCtrl.text.isEmpty && _provider.inscricaoMunicipalAtual.isNotEmpty) {
      _inscricaoCtrl.text = _provider.inscricaoMunicipalAtual;
    }
    if (!_consultado &&
        _provider.cnpjAtual.isNotEmpty &&
        _provider.razaoSocialAtual.isNotEmpty) {
      if (mounted) setState(() => _consultado = true);
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_syncControllers);
    _cnpjCtrl.dispose();
    _inscricaoCtrl.dispose();
    _razaoSocialCtrl.dispose();
    _municipioCtrl.dispose();
    super.dispose();
  }

  // ── Consultar CNPJ ────────────────────────────────────────────────────────

  Future<void> _consultar() async {
    final cnpj = _cnpjCtrl.text.trim();
    if (cnpj.replaceAll(RegExp(r'[.\-\/]'), '').length != 14) {
      _snack('CNPJ deve ter 14 dígitos');
      return;
    }
    final p = context.read<OnboardingProvider>();
    final ok = await p.buscarCnpj(cnpj);
    if (!mounted) return;

    if (ok) {
      setState(() { _consultado = true; _modoManual = false; });
    } else if (p.erroCnpjApiDown) {
      p.ativarModoManual(cnpj);
      setState(() { _consultado = true; _modoManual = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Não foi possível consultar a Receita Federal. '
          'Preencha os dados manualmente.'),
        backgroundColor: Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      setState(() { _consultado = true; _modoManual = false; });
    }
  }

  // ── Avançar para 2b ───────────────────────────────────────────────────────

  Future<void> _avancar() async {
    final p = context.read<OnboardingProvider>();

    if (p.razaoSocialAtual.isEmpty) {
      _snack('Consulte e confirme seu CNPJ antes de continuar');
      return;
    }
    if (p.inscricaoMunicipalAtual.isEmpty) {
      _snack('Informe a Inscrição Municipal antes de continuar');
      return;
    }

    setState(() => _salvando = true);
    try {
      // Persiste CNPJ no backend — POST /api/v1/cnpjs-proprios
      final cnpj = CnpjComTomadores(
        cnpj:               p.cnpjAtual,
        razaoSocial:        p.razaoSocialAtual,
        municipio:          p.municipioAtual,
        uf:                 p.ufAtual,
        tomadores:          const [],
        inscricaoMunicipal: p.inscricaoMunicipalAtual,
        regime:             p.regimeAtual,
        metodoAssinatura:   MetodoAssinatura.certificadoA1, // default; step 2b atualiza
        statusCertificado:  StatusCertificado.pendente,
      );
      await p.salvarCnpj(cnpj);
      if (mounted) widget.onNext();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OnboardingProvider>();
    // consultaOk derivado do provider — funciona ao voltar e no restore
    final consultaOk = p.cnpjAtual.isNotEmpty && p.razaoSocialAtual.isNotEmpty;


    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seu CNPJ',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('O CNPJ da sua pessoa jurídica — de onde você emite as NFS-e.',
              style: TextStyle(color: AppColors.textMid, fontSize: 14)),
          const SizedBox(height: 28),

          // ── CNPJ ──────────────────────────────────────────────────────────
          _label('CNPJ'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _cnpjCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-\/]')),
                  LengthLimitingTextInputFormatter(18),
                ],
                style: GoogleFonts.jetBrainsMono(fontSize: 15, color: Colors.white),
                decoration: _decor('00.000.000/0001-00'),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: p.buscandoCnpj ? null : _consultar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.green,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.green),
                ),
              ),
              child: p.buscandoCnpj
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green))
                  : Text('Consultar',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),

          // Resultado erro (CNPJ inválido)
          if (_consultado && p.erroCnpj != null && !_modoManual)
            _ResultadoCard(erro: p.erroCnpj!),

          // Modo manual — campos desbloqueados quando Receita Federal indisponível
          if (_modoManual) ...[
            const SizedBox(height: 12),
            _label('Razão Social'),
            const SizedBox(height: 8),
            TextField(
              controller: _razaoSocialCtrl,
              textCapitalization: TextCapitalization.characters,
              onChanged: (v) => context.read<OnboardingProvider>().setRazaoSocial(v),
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white),
              decoration: _decor('Nome da pessoa jurídica', obrigatorio: true).copyWith(
                suffixIcon: const Icon(Icons.edit_outlined,
                    size: 16, color: Color(0xFFF59E0B)),
              ),
            ),
            const SizedBox(height: 16),
            _label('Município'),
            const SizedBox(height: 8),
            TextField(
              controller: _municipioCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => context.read<OnboardingProvider>().setMunicipio(v),
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white),
              decoration: _decor('Cidade de emissão das NFS-e').copyWith(
                suffixIcon: const Icon(Icons.edit_outlined,
                    size: 16, color: Color(0xFFF59E0B)),
              ),
            ),
          ],

          // Resultado sucesso
          if (consultaOk && !_modoManual) ...[
            _ResultadoCard(
              razaoSocial:   p.razaoSocialAtual,
              nomeFantasia:  p.nomeFantasiaAtual,
              situacao:      p.situacaoAtual,
              porte:         p.porteAtual,
              municipio:     p.municipioAtual,
              uf:            p.ufAtual,
              abertura:      p.aberturaAtual,
            ),
            if (p.situacaoAtual != null && p.situacaoAtual!.toUpperCase() != 'ATIVA')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Este CNPJ não está ativo na Receita Federal. Verifique antes de continuar.',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: const Color(0xFFF59E0B), height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ),
          ],

          // ── Inscrição Municipal ────────────────────────────────────────────
          if (consultaOk) ...[
            const SizedBox(height: 24),
            _label('Inscrição Municipal'),
            const SizedBox(height: 8),
            TextField(
              controller: _inscricaoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => context.read<OnboardingProvider>().setInscricaoMunicipal(v.trim()),
              style: GoogleFonts.jetBrainsMono(fontSize: 15, color: Colors.white),
              decoration: _decor('Número da inscrição municipal da sua PJ', obrigatorio: true),
            ),
          ],

          // ── Regime tributário ──────────────────────────────────────────────
          if (consultaOk) ...[
            const SizedBox(height: 24),
            _label('Regime Tributário'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RegimeTributario>(
                  value: p.regimeAtual,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    RegimeTributario.simplesNacional,
                    RegimeTributario.lucroPresumido,
                  ].map((regime) => DropdownMenuItem(
                    value: regime,
                    child: Text(regime.label,
                        style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) context.read<OnboardingProvider>().setRegime(v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Card explicativo dinâmico
            _RegimeInfoCard(regime: p.regimeAtual),
          ],

          const SizedBox(height: 40),

          // ── Botão Continuar ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _salvando ? null : _avancar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _salvando
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black54)))
                  : const Text('Continuar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: AppColors.textMid, fontSize: 13, fontWeight: FontWeight.w500));

  InputDecoration _decor(String hint, {bool obrigatorio = false}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textDim),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border:             OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.green)),
        errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      );
}

// ─── Card resultado consulta ────────────────────────────────────────────────

class _ResultadoCard extends StatelessWidget {
  final String? razaoSocial;
  final String? erro;
  final String? nomeFantasia;
  final String? situacao;
  final String? porte;
  final String? municipio;
  final String? uf;
  final String? abertura;

  const _ResultadoCard({
    this.razaoSocial,
    this.erro,
    this.nomeFantasia,
    this.situacao,
    this.porte,
    this.municipio,
    this.uf,
    this.abertura,
  });

  /// Converte "yyyy-MM-dd" → "dd/MM/yyyy"; passa adiante se já estiver noutro formato.
  String _formatarData(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final partes = raw.split('-');
    if (partes.length == 3 && partes[0].length == 4) {
      return '${partes[2]}/${partes[1]}/${partes[0]}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    // ── Card de erro ────────────────────────────────────────────────────────
    if (erro != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(erro!,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.redAccent)),
          ),
        ]),
      );
    }

    // ── Card de sucesso expandido ────────────────────────────────────────────
    final situacaoUpper = (situacao ?? '').toUpperCase();
    final situacaoAtiva = situacaoUpper == 'ATIVA';
    final corSituacao = situacaoAtiva
        ? const Color(0xFF00C98A)
        : const Color(0xFFF59E0B);

    final municipioUf = [
      if (municipio != null && municipio!.isNotEmpty) municipio!,
      if (uf != null && uf!.isNotEmpty) uf!,
    ].join(' / ');

    final mostrarFantasia = nomeFantasia != null &&
        nomeFantasia!.isNotEmpty &&
        nomeFantasia!.toUpperCase() != (razaoSocial ?? '').toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1 — razão social
          Row(children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.green, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (razaoSocial ?? '').toUpperCase(),
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green),
              ),
            ),
          ]),

          // Linha 2 — nome fantasia (condicional)
          if (mostrarFantasia) ...[
            const SizedBox(height: 6),
            _InfoRow(label: 'Fantasia', valor: nomeFantasia!),
          ],

          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // Linha 3 — situação
          if (situacaoUpper.isNotEmpty)
            _InfoRow(
              label: 'Situação',
              valor: situacaoUpper,
              corValor: corSituacao,
              icone: situacaoAtiva ? null : Icons.warning_amber_rounded,
            ),

          // Linha 4 — porte
          if (porte != null && porte!.isNotEmpty)
            _InfoRow(label: 'Porte', valor: porte!),

          // Linha 5 — município/UF
          if (municipioUf.isNotEmpty)
            _InfoRow(label: 'Município', valor: municipioUf),

          // Linha 6 — abertura
          if (abertura != null && abertura!.isNotEmpty)
            _InfoRow(label: 'Abertura', valor: _formatarData(abertura)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String valor;
  final Color? corValor;
  final IconData? icone;

  const _InfoRow({
    required this.label,
    required this.valor,
    this.corValor,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 11, color: const Color(0xFF94A3B8))),
          ),
          if (icone != null) ...[
            Icon(icone, size: 13, color: corValor ?? const Color(0xFFCBD5E1)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(valor,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: corValor ?? const Color(0xFFCBD5E1),
                    fontWeight: corValor != null ? FontWeight.w600 : FontWeight.normal)),
          ),
        ],
      ),
    );
  }
}

// ─── Card informativo dinâmico de regime ────────────────────────────────────

class _RegimeInfoCard extends StatelessWidget {
  final RegimeTributario regime;
  const _RegimeInfoCard({required this.regime});

  @override
  Widget build(BuildContext context) {
    final (cor, icone, titulo, detalhe) = switch (regime) {
      RegimeTributario.simplesNacional => (
        AppColors.green,
        Icons.check_circle_outline,
        'Simples Nacional',
        'Alíquota efetiva sobre a receita bruta (Anexo III ou V).\n'
        'ISS incluso no DAS. IRPJ + CSLL + PIS + COFINS unificados.\n'
        'Carga real: 6% a 19,5% dependendo do Fator R.',
      ),
      RegimeTributario.lucroPresumido => (
        AppColors.cyan,
        Icons.info_outline,
        'Lucro Presumido',
        'Presunção de lucro: 32% da receita bruta para serviços médicos.\n'
        'IRPJ 15% + CSLL 9% + PIS 0,65% + COFINS 3% + ISS municipal.\n'
        'IBS 0,1% e CBS 0,9% obrigatórios na NFS-e desde 01/01/2026.',
      ),
      _ => (
        AppColors.amber,
        Icons.warning_amber_outlined,
        'Regime não recomendado',
        'Lucro Real exige escrituração contábil completa.\n'
        'Recomendamos Simples Nacional ou Lucro Presumido para médicos PJ.',
      ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icone, color: cor, size: 15),
            const SizedBox(width: 6),
            Text(titulo,
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w700, color: cor)),
          ]),
          const SizedBox(height: 6),
          Text(detalhe,
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.textMid, height: 1.5)),
        ],
      ),
    );
  }
}
