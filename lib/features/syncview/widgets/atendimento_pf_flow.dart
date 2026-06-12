// lib/features/syncview/widgets/atendimento_pf_flow.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/models/medico.dart';
import '../../../core/models/servico.dart';
import '../../../core/providers/nota_fiscal_provider.dart';
import '../../../core/providers/servico_provider.dart';
import '../../../core/services/medvie_api_service.dart';
import '../../notas/widgets/emissao_confirmacao_sheet.dart';
import 'endereco_fiscal_form.dart';
import 'paciente_pf_form.dart';
import 'preview_fiscal_pf_card.dart';

/// Fluxo de captura de atendimento PF (FR-014..FR-017 / T040).
///
/// Orquestra [PacientePfForm] + [EnderecoFiscalForm] + seleção de serviço +
/// valor + [PreviewFiscalPfCard]. Ao salvar, chama
/// `ServicoProvider.confirmarAtendimentoPf` (`emitirAgora=false`) e, quando o
/// endereço fiscal está completo, abre o `EmissaoConfirmacaoSheet` e emite via
/// `ServicoProvider.emitirNf` — mesma mecânica do plantonista (FR-017).
class AtendimentoPfFlow extends StatefulWidget {
  /// Guid do CNPJ próprio do médico.
  final String cnpjProprioId;

  /// CNPJ emissor (somente dígitos) — usado na emissão via `POST /notas`.
  final String cnpjEmissor;

  /// Chamado após salvar/emitir com sucesso (fecha o modal).
  final VoidCallback onConcluido;

  /// Tipos de serviço oferecidos ao paciente PF.
  static const List<TipoServico> tiposPf = [
    TipoServico.consulta,
    TipoServico.procedimentoCirurgico,
    TipoServico.laudo,
    TipoServico.outros,
  ];

  const AtendimentoPfFlow({
    super.key,
    required this.cnpjProprioId,
    required this.cnpjEmissor,
    required this.onConcluido,
  });

  @override
  State<AtendimentoPfFlow> createState() => _AtendimentoPfFlowState();
}

class _AtendimentoPfFlowState extends State<AtendimentoPfFlow> {
  final _valor = TextEditingController();
  final _descricao = TextEditingController();

  PacientePfDados _paciente = const PacientePfDados();
  EnderecoFiscalTomador _endereco = const EnderecoFiscalTomador();
  TipoServico _tipoServico = TipoServico.consulta;
  DateTime _competencia = DateTime.now();
  double _bruto = 0;
  bool _salvando = false;

  // Endereço vindo do lookup; chave força re-init do form ao reconhecer.
  EnderecoFiscalTomador? _enderecoInicial;
  int _enderecoFormSeed = 0;

  @override
  void initState() {
    super.initState();
    _descricao.text = _tipoServico.label;
  }

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  // ─── Valor / preview ─────────────────────────────────────────────────────

  double get _valorNumerico {
    final raw = _valor.text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0.0;
  }

  // ─── Lookup / CEP ────────────────────────────────────────────────────────

  Future<LookupTomadorResponse> _lookupCpf(String cpf) =>
      context.read<ServicoProvider>().lookupPacientePorCpf(
            cnpjProprioId: widget.cnpjProprioId,
            documentoCpf: cpf,
          );

  Future<EnderecoFiscalTomador?> _resolverCep(String cep) async {
    try {
      return await context.read<ServicoProvider>().buscarEnderecoFiscal(cep);
    } catch (_) {
      return null; // falha → preenchimento manual (FR-004)
    }
  }

  void _aoReconhecerPaciente(LookupTomadorResponse res) {
    setState(() {
      if (res.endereco != null) {
        _enderecoInicial = res.endereco;
        _endereco = res.endereco!;
        _enderecoFormSeed++; // recria o form com o endereço carregado
      }
      final ultimo = res.ultimoServico;
      if (ultimo != null && ultimo.tipoServico.isNotEmpty) {
        _tipoServico = _tipoDeBackend(ultimo.tipoServico);
        _descricao.text =
            ultimo.descricao.isNotEmpty ? ultimo.descricao : _tipoServico.label;
      }
    });
  }

  static TipoServico _tipoDeBackend(String nome) => TipoServico.values
      .firstWhere((t) => t.backendEnumName == nome,
          orElse: () => TipoServico.consulta);

  // ─── Confirmação ─────────────────────────────────────────────────────────

  void _erro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  Future<void> _confirmar() async {
    if (_salvando) return;

    if (_paciente.documentoCpf.length != 11) {
      _erro('Informe um CPF válido do paciente.');
      return;
    }
    if (_paciente.nome.isEmpty) {
      _erro('Informe o nome do paciente.');
      return;
    }
    if (_valorNumerico <= 0) {
      _erro('Informe o valor do atendimento.');
      return;
    }

    setState(() => _salvando = true);
    final servicoProvider = context.read<ServicoProvider>();
    final notaProvider = context.read<NotaFiscalProvider>();

    try {
      final res = await servicoProvider.confirmarAtendimentoPf(
        cnpjProprioId: widget.cnpjProprioId,
        documentoCpf: _paciente.documentoCpf,
        nomePaciente: _paciente.nome,
        email: _paciente.email.isEmpty ? null : _paciente.email,
        telefone: _paciente.telefone.isEmpty ? null : _paciente.telefone,
        endereco: _endereco,
        tipoServico: _tipoServico,
        descricao:
            _descricao.text.trim().isEmpty ? _tipoServico.label : _descricao.text.trim(),
        valor: _valorNumerico,
        competencia: _competencia,
      );
      if (!mounted) return;

      final pronto = res.preview?.prontoParaEmitir ??
          res.tomador.enderecoFiscalCompleto;

      if (pronto) {
        await _emitir(res.servicoId, servicoProvider, notaProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.amber,
            content: Text(
              'Atendimento salvo. Complete o endereço fiscal para emitir.',
            ),
          ),
        );
        widget.onConcluido();
      }
    } on ApiException catch (e) {
      _erro(MedvieApiService.mensagemErroAtendimentoPf(e.error));
    } catch (e) {
      _erro('Não foi possível salvar o atendimento.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _emitir(
    String servicoId,
    ServicoProvider servicoProvider,
    NotaFiscalProvider notaProvider,
  ) async {
    Servico? servico;
    for (final s in servicoProvider.servicos) {
      if (s.id == servicoId) {
        servico = s;
        break;
      }
    }
    if (servico == null) {
      widget.onConcluido();
      return;
    }

    final confirmar =
        await EmissaoConfirmacaoSheet.showIndividual(context, servico);
    if (!mounted) return;
    if (!confirmar) {
      // Médico optou por revisar — atendimento já está salvo e pendente.
      widget.onConcluido();
      return;
    }

    try {
      await servicoProvider.emitirNf(
        servicoId,
        notaProvider,
        widget.cnpjEmissor,
        cnpjProprioGuidParaReload: widget.cnpjProprioId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.green,
          content: Text('Nota enviada para processamento ✓'),
        ),
      );
    } catch (_) {
      _erro('Falha ao emitir a NFS-e. Tente novamente em Notas.');
    } finally {
      widget.onConcluido();
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PacientePfForm(
          onLookupCpf: _lookupCpf,
          onLookupResult: _aoReconhecerPaciente,
          onChanged: (d) => _paciente = d,
        ),
        const SizedBox(height: 18),
        EnderecoFiscalForm(
          key: ValueKey('endereco-form-$_enderecoFormSeed'),
          initial: _enderecoInicial,
          onResolveCep: _resolverCep,
          onChanged: (e) => setState(() => _endereco = e),
        ),
        const SizedBox(height: 18),
        _label('Serviço prestado'),
        const SizedBox(height: 8),
        _seletorServico(),
        const SizedBox(height: 18),
        _label('Valor do atendimento'),
        const SizedBox(height: 8),
        _campoValor(),
        const SizedBox(height: 16),
        _linhaDataDescricao(),
        PreviewFiscalPfCard(
          bruto: _bruto,
          ibs: 0,
          cbs: 0,
          liquido: _bruto,
          enderecoCompleto: _endereco.completo,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _salvando ? null : () => unawaited(_confirmar()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    'Salvar atendimento',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDim,
        ),
      );

  Widget _seletorServico() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AtendimentoPfFlow.tiposPf.map((t) {
        final sel = t == _tipoServico;
        return GestureDetector(
          key: ValueKey('servico-${t.name}'),
          onTap: () => setState(() {
            _tipoServico = t;
            if (_descricao.text.trim().isEmpty) _descricao.text = t.label;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.green.withValues(alpha: 0.10) : AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel
                    ? AppColors.green.withValues(alpha: 0.45)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.icone, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppColors.green : AppColors.textMid,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _campoValor() {
    return TextField(
      key: const ValueKey('pf-valor'),
      controller: _valor,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      onChanged: (_) => setState(() => _bruto = _valorNumerico),
      style: GoogleFonts.jetBrainsMono(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      decoration: InputDecoration(
        isDense: true,
        prefixText: 'R\$ ',
        prefixStyle: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          color: AppColors.textDim,
        ),
        hintText: '0,00',
        hintStyle: const TextStyle(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green),
        ),
      ),
    );
  }

  Widget _linhaDataDescricao() {
    final fmtData = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => unawaited(_selecionarData()),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Data: ${fmtData.format(_competencia)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                ),
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.textDim),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descricao,
          maxLines: 2,
          minLines: 1,
          style: const TextStyle(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Descrição da NFS-e',
            labelStyle: const TextStyle(color: AppColors.textDim),
            filled: true,
            fillColor: AppColors.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.green),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _competencia,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) setState(() => _competencia = picked);
  }
}
