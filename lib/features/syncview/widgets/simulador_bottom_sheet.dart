// lib/features/syncview/widgets/simulador_bottom_sheet.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/medico.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/simulador_provider.dart';
import 'add_servico_modal.dart';

class SimuladorBottomSheet extends StatefulWidget {
  const SimuladorBottomSheet({super.key});

  @override
  State<SimuladorBottomSheet> createState() => _SimuladorBottomSheetState();
}

class _SimuladorBottomSheetState extends State<SimuladorBottomSheet> {
  final _valorController = TextEditingController();
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');
  Timer? _debounce;
  Tomador? _tomadorSelecionado;

  @override
  void dispose() {
    _debounce?.cancel();
    _valorController.dispose();
    context.read<SimuladorProvider>().reset();
    super.dispose();
  }

  double? get _valorParsed {
    final raw = _valorController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(raw);
  }

  void _onValorChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _tentarCalcular);
  }

  void _tentarCalcular() {
    final valor = _valorParsed;
    final tomador = _tomadorSelecionado;
    if (valor == null || valor <= 0 || tomador == null) return;
    final medicoId = context.read<OnboardingProvider>().medicoIdSalvo;
    if (medicoId == null) return;
    context.read<SimuladorProvider>().calcular(
          medicoId: medicoId,
          valorBruto: valor,
          tomadorId: tomador.id,
        );
  }

  void _onTomadorChanged(Tomador? tomador) {
    setState(() => _tomadorSelecionado = tomador);
    if (tomador != null) {
      _debounce?.cancel();
      _tentarCalcular();
    }
  }

  InputDecoration _inputDec({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: AppColors.textDim, fontSize: 14),
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
    final simProvider = context.watch<SimuladorProvider>();
    final tomadores = onboarding.tomadores.isNotEmpty
        ? onboarding.tomadores
        : (onboarding.medico?.todosTomadores ?? <Tomador>[]);
    final resultado = simProvider.resultado;

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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              onChanged: _onValorChanged,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 15, color: AppColors.text),
              decoration: _inputDec(hint: 'Ex: 18.000,00'),
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
            const SizedBox(height: 20),

            // Loading
            if (simProvider.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircularProgressIndicator(
                      color: AppColors.green, strokeWidth: 2),
                ),
              ),

            // Painel resultado
            if (resultado != null) ...[
              _ResultadoPanel(resultado: resultado, fmt: _fmt),
              const SizedBox(height: 16),
            ],

            // Banner estimativa
            if (resultado != null && resultado.ehEstimativa) ...[
              const _BannerEstimativa(),
              const SizedBox(height: 16),
            ],

            // Botão registrar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final resultado =
                      context.read<SimuladorProvider>().resultado;
                  final tomador = _tomadorSelecionado;
                  final nav = Navigator.of(context);
                  nav.pop();
                  showModalBottomSheet(
                    context: nav.context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddServicoModal(
                      valorInicial: resultado?.valorLiquido,
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

// ─── Painel de resultado ──────────────────────────────────────────────────────

class _ResultadoPanel extends StatelessWidget {
  final SimuladorResultado resultado;
  final NumberFormat fmt;

  const _ResultadoPanel({required this.resultado, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.green.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (resultado.descontoIss > 0)
            _LinhaDeducao(
              label: 'ISS (${resultado.aliquotaIss.toStringAsFixed(2)}%)',
              valor: resultado.descontoIss,
              fmt: fmt,
            ),
          if (resultado.descontoIrrf > 0)
            _LinhaDeducao(
              label: 'IRRF (${resultado.aliquotaIrrf.toStringAsFixed(2)}%)',
              valor: resultado.descontoIrrf,
              fmt: fmt,
            ),
          if (resultado.descontoIss > 0 || resultado.descontoIrrf > 0)
            const Divider(
                height: 16, thickness: 0.5, color: Color(0xFF1E293B)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Líquido estimado',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                fmt.format(resultado.valorLiquido),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinhaDeducao extends StatelessWidget {
  final String label;
  final double valor;
  final NumberFormat fmt;

  const _LinhaDeducao({
    required this.label,
    required this.valor,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
                fontSize: 13, color: const Color(0xFF94A3B8)),
          ),
          Text(
            '− ${fmt.format(valor)}',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 13, color: const Color(0xFFF87171)),
          ),
        ],
      ),
    );
  }
}

// ─── Banner estimativa ────────────────────────────────────────────────────────

class _BannerEstimativa extends StatelessWidget {
  const _BannerEstimativa();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠',
              style: TextStyle(fontSize: 14, color: Color(0xFFD97706))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Estimativa. Valores finais dependem da retenção aplicada pelo tomador.',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: const Color(0xFFD97706)),
            ),
          ),
        ],
      ),
    );
  }
}
