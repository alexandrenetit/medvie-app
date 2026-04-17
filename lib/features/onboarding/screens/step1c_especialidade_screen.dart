// lib/features/onboarding/screens/step1c_especialidade_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/especialidade.dart';
import '../../../core/providers/onboarding_provider.dart';

class Step1cEspecialidadeScreen extends StatefulWidget {
  final VoidCallback onNext;
  const Step1cEspecialidadeScreen({super.key, required this.onNext});

  @override
  State<Step1cEspecialidadeScreen> createState() =>
      _Step1cEspecialidadeScreenState();
}

class _Step1cEspecialidadeScreenState
    extends State<Step1cEspecialidadeScreen> {
  final _buscaCtrl = TextEditingController();

  List<Especialidade> _todas = [];
  List<Especialidade> _filtradas = [];
  Especialidade? _selecionada;
  bool _carregando = true;
  String? _erro;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _selecionada = context.read<OnboardingProvider>().especialidade;
    _buscaCtrl.addListener(_filtrar);
    _carregar();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  // ── Carga ─────────────────────────────────────────────────────────────────

  Future<void> _carregar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      final lista =
          await context.read<OnboardingProvider>().api.listarEspecialidades();
      if (!mounted) return;
      setState(() {
        _todas     = lista;
        _filtradas = lista;
        _carregando = false;
        // Realinha objeto selecionado com instância carregada
        if (_selecionada != null) {
          _selecionada = lista.firstWhere(
            (e) => e.id == _selecionada!.id,
            orElse: () => lista.first,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _erro = 'Erro ao carregar especialidades'; _carregando = false; });
    }
  }

  void _filtrar() {
    final q = _buscaCtrl.text.toLowerCase().trim();
    setState(() {
      _filtradas = q.isEmpty
          ? _todas
          : _todas.where((e) => e.nome.toLowerCase().contains(q)).toList();
    });
  }

  // ── Avançar ───────────────────────────────────────────────────────────────

  Future<void> _avancar() async {
    if (_selecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione uma especialidade para continuar'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    setState(() => _salvando = true);
    try {
      await context.read<OnboardingProvider>().salvarEspecialidade(_selecionada!);
      if (mounted) widget.onNext();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Especialidade',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Selecione sua área de atuação principal.',
              style: TextStyle(color: AppColors.textMid, fontSize: 14)),
          const SizedBox(height: 20),

          // Campo de busca
          TextField(
            controller: _buscaCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar especialidade…',
              hintStyle: TextStyle(color: AppColors.textDim),
              prefixIcon: Icon(Icons.search, color: AppColors.textDim, size: 20),
              suffixIcon: _buscaCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, color: AppColors.textDim, size: 18),
                      onPressed: () { _buscaCtrl.clear(); _filtrar(); },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.cyan)),
            ),
          ),
          const SizedBox(height: 16),

          // Lista
          Expanded(child: _buildLista()),

          const SizedBox(height: 16),

          // Botão continuar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_salvando || _selecionada == null) ? null : _avancar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.green.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _salvando
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black54)))
                  : const Text('Continuar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.green)),
      );
    }

    if (_erro != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
          const SizedBox(height: 12),
          Text(_erro!, style: TextStyle(color: AppColors.textMid)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _carregar,
            style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.green)),
            child: Text('Tentar novamente', style: TextStyle(color: AppColors.green)),
          ),
        ]),
      );
    }

    if (_filtradas.isEmpty) {
      return Center(
        child: Text('Nenhuma especialidade encontrada.',
            style: TextStyle(color: AppColors.textDim)),
      );
    }

    return ListView.separated(
      itemCount: _filtradas.length,
      separatorBuilder: (context, _) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
      itemBuilder: (_, i) {
        final esp = _filtradas[i];
        final isSel = _selecionada?.id == esp.id;
        return InkWell(
          onTap: () => setState(() => _selecionada = esp),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Text(
                  esp.nome,
                  style: TextStyle(
                    color: isSel ? Colors.white : AppColors.textMid,
                    fontSize: 14,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSel)
                Icon(Icons.check_circle, color: AppColors.cyan, size: 20),
            ]),
          ),
        );
      },
    );
  }
}
