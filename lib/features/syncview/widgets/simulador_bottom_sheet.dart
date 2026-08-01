// lib/features/syncview/widgets/simulador_bottom_sheet.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/medico.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/servico_provider.dart';
import '../../../core/utils/formatters.dart';
import 'add_servico_modal.dart';
import 'preview_fiscal_cnpj_card.dart';

/// Simular honorário: preview fiscal da reforma (IBS/CBS + retenções "a definir
/// no envio") espelhando o fluxo Empresa/Convênio (`atendimento_cnpj_flow`).
///
/// O cálculo oficial vem do backend (`ServicoProvider.previewFiscalAtendimento`,
/// keyed por `cnpjProprioId` + valor + competência). A UI NÃO infere alíquota
/// local — ISS/IRRF só são conhecidos no envio (dependem do tomador). Substitui
/// o simulador legado que aplicava a tabela IRRF progressiva client-side.
class SimuladorBottomSheet extends StatefulWidget {
  const SimuladorBottomSheet({super.key});

  @override
  State<SimuladorBottomSheet> createState() => _SimuladorBottomSheetState();
}

class _SimuladorBottomSheetState extends State<SimuladorBottomSheet> {
  final _valorController = TextEditingController();
  Timer? _debounce;
  Tomador? _tomadorSelecionado;

  // Preview fiscal oficial (backend). Zerado até o primeiro retorno válido.
  double _ibs = 0;
  double _cbs = 0;
  double _liquido = 0;
  double _issRetido = 0;
  double _irrfRetido = 0;
  double _csrfRetido = 0;
  bool _backendCalculado = false;
  bool _carregando = false;

  /// `true` quando o preview em tela foi pedido COM tomador — guardado junto dos
  /// valores para que trocar o dropdown não rotule de "avaliado" um preview
  /// calculado sem tomador.
  bool _retencoesAvaliadas = false;

  /// Ressalva de escopo do backend (G-E/A4): é ela que impede o card de passar
  /// por número fiscal final. Vazia até o primeiro preview válido.
  String _ressalvaEscopo = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _valorController.dispose();
    super.dispose();
  }

  double? get _valorParsed {
    final raw = _valorController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(raw);
  }

  /// CNPJ próprio do médico (ownership do preview fiscal). Mesma resolução da
  /// SyncView: CNPJ atual, senão o primeiro cadastrado.
  String? get _cnpjProprioId {
    final onboarding = context.read<OnboardingProvider>();
    return onboarding.cnpjProprioIdsPorCnpj[onboarding.cnpjAtual] ??
        onboarding.cnpjProprioIdsPorCnpj.values.firstOrNull;
  }

  void _onValorChanged(String _) {
    _debounce?.cancel();
    final valor = _valorParsed;
    if (valor == null || valor <= 0) {
      setState(() {
        _ibs = 0;
        _cbs = 0;
        _liquido = 0;
        _issRetido = 0;
        _irrfRetido = 0;
        _csrfRetido = 0;
        _backendCalculado = false;
        _retencoesAvaliadas = false;
        _carregando = false;
        _ressalvaEscopo = '';
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_recalcularPreview()),
    );
  }

  Future<void> _recalcularPreview() async {
    if (!mounted) return;
    final valor = _valorParsed;
    if (valor == null || valor <= 0) return;
    final cnpjProprioId = _cnpjProprioId;
    if (cnpjProprioId == null || cnpjProprioId.isEmpty) return;

    // Fixa o tomador do disparo: trocar o dropdown durante o await invalida
    // este resultado (as retenções seriam de outro cadastro).
    final tomadorId = _tomadorSelecionado?.id;

    setState(() => _carregando = true);
    try {
      final preview = await context.read<ServicoProvider>().previewFiscalAtendimento(
            cnpjProprioId: cnpjProprioId,
            valor: valor,
            competencia: DateTime.now(),
            tomadorId: tomadorId,
          );
      if (!mounted) return;
      if (_valorParsed != valor) return; // valor mudou durante o await
      if (_tomadorSelecionado?.id != tomadorId) return; // tomador mudou
      setState(() {
        _ibs = preview.ibs;
        _cbs = preview.cbs;
        _liquido = preview.liquidoEstimado;
        _issRetido = preview.issRetido;
        _irrfRetido = preview.irrfRetido;
        _csrfRetido = preview.csrfRetido;
        _backendCalculado = true;
        _retencoesAvaliadas = tomadorId != null && tomadorId.isNotEmpty;
        _carregando = false;
        _ressalvaEscopo = preview.ressalvaEscopo;
      });
    } catch (_) {
      if (!mounted) return;
      // Falha de rede: preserva o último preview válido.
      setState(() => _carregando = false);
    }
  }

  void _onTomadorChanged(Tomador? tomador) {
    // Tomador não altera IBS/CBS (keyed por cnpjProprioId), mas altera
    // ISS/IRRF/CSRF e, com eles, o líquido — o preview precisa ser refeito com
    // o `tomadorId`, senão o card mostra "Retém ISS" ao lado de um líquido que
    // não desconta nada.
    setState(() => _tomadorSelecionado = tomador);
    unawaited(_recalcularPreview());
  }

  InputDecoration _inputDec({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: AppColors.textDim, fontSize: 14),
        prefixText: 'R\$ ',
        prefixStyle:
            GoogleFonts.jetBrainsMono(fontSize: 15, color: AppColors.text),
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingProvider>();
    // Empresa/Convênio (Hospital/Clínica) é exclusivo CNPJ — feature 017 (PF)
    // não se aplica ao simulador. Filtra antes de popular o dropdown.
    final todosTomadores = onboarding.tomadores.isNotEmpty
        ? onboarding.tomadores
        : (onboarding.medico?.todosTomadores ?? <Tomador>[]);
    final tomadores = todosTomadores
        .where((t) => t.tipo == TipoTomador.cnpj)
        .toList(growable: false);
    final valor = _valorParsed;
    final temValor = valor != null && valor > 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              'Simular honorário',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 20),

            // Campo valor
            Text(
              'Valor bruto',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valorController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              onChanged: _onValorChanged,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 15, color: AppColors.text),
              decoration: _inputDec(hint: '0,00'),
            ),
            const SizedBox(height: 16),

            // Dropdown tomadores
            Text(
              'Hospital / Clínica',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Tomador>(
                  value: _tomadorSelecionado,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  hint: Text(
                    'Selecione o hospital / clínica',
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: AppColors.textDim),
                  ),
                  items: tomadores.map((t) {
                    return DropdownMenuItem<Tomador>(
                      value: t,
                      child: Text(
                        t.razaoSocial,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onTomadorChanged,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Loading
            if (_carregando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 4),
                  child: CircularProgressIndicator(
                      color: AppColors.green, strokeWidth: 2),
                ),
              ),

            // Preview fiscal oficial (reforma) — mesmo card do fluxo CNPJ.
            if (temValor)
              PreviewFiscalCnpjCard(
                bruto: valor,
                retemIss: _tomadorSelecionado?.retemIss ?? false,
                // Sem declaração no cadastro, exibe o default legal (F-04 / D9).
                retemIrrf: _tomadorSelecionado?.retemIrrfExibicao ?? false,
                ibs: _ibs,
                cbs: _cbs,
                liquido: _backendCalculado ? _liquido : valor,
                backendCalculado: _backendCalculado,
                ressalvaEscopo: _ressalvaEscopo,
                retencoesAvaliadas: _retencoesAvaliadas,
                issRetido: _issRetido,
                irrfRetido: _irrfRetido,
                csrfRetido: _csrfRetido,
              ),
            const SizedBox(height: 16),

            // Botão registrar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final valorBruto = _valorParsed;
                  final tomador = _tomadorSelecionado;
                  final nav = Navigator.of(context);
                  nav.pop();
                  showModalBottomSheet(
                    context: nav.context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    useSafeArea: true,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.92,
                    ),
                    builder: (_) => AddServicoModal(
                      valorInicial: valorBruto,
                      tomadorInicial: tomador,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Registrar este serviço →',
                  style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Fechar
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Fechar',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: AppColors.textDim),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
