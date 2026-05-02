// lib/features/onboarding/screens/step1b_grupo_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/perfil_atuacao.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../widgets/group_selection_card.dart';

class Step1bGrupoScreen extends StatefulWidget {
  final VoidCallback onNext;
  const Step1bGrupoScreen({super.key, required this.onNext});

  @override
  State<Step1bGrupoScreen> createState() => _Step1bGrupoScreenState();
}

class _Step1bGrupoScreenState extends State<Step1bGrupoScreen> {
  late PerfilAtuacao _selecionado;
  bool _salvando = false;

  static const _grupos = [
    _GrupoConfig(
      perfil: PerfilAtuacao.medicoClinico,
      icon: Icons.person_outline,
      title: 'Médico Clínico',
      subtitle: 'Consultas em consultório próprio ou de terceiros',
    ),
    _GrupoConfig(
      perfil: PerfilAtuacao.procedimentalistaAmbulatorial,
      icon: Icons.medical_services_outlined,
      title: 'Procedimentalista Ambulatorial',
      subtitle: 'Procedimentos em clínica ou consultório — dermatologia, oftalmologia, endoscopia, ginecologia',
    ),
    _GrupoConfig(
      perfil: PerfilAtuacao.plantonistaHospitalar,
      icon: Icons.local_hospital_outlined,
      title: 'Plantonista / Prestador Hospitalar',
      subtitle: 'Escalas em hospitais, UTI, emergência ou anestesia — múltiplos tomadores e municípios',
    ),
    _GrupoConfig(
      perfil: PerfilAtuacao.cirurgiao,
      icon: Icons.biotech_outlined,
      title: 'Cirurgião Hospitalar',
      subtitle: 'Cirurgias eletivas ou de urgência — ortopedia, cirurgia geral, neurocirurgia, vascular',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selecionado = context.read<OnboardingProvider>().perfilAtuacao;
  }

  Future<void> _avancar() async {
    setState(() => _salvando = true);
    try {
      await context.read<OnboardingProvider>().salvarPerfilAtuacao(_selecionado);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Como você atua como PJ?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Isso define como o Medvie organiza suas notas e cálculos.',
            style: TextStyle(color: AppColors.textMid, fontSize: 14),
          ),
          const SizedBox(height: 28),

          // Cards de seleção
          Expanded(
            child: ListView.separated(
              itemCount: _grupos.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final g = _grupos[i];
                return GroupSelectionCard(
                  icon: g.icon,
                  title: g.title,
                  subtitle: g.subtitle,
                  isSelected: _selecionado == g.perfil,
                  onTap: () => setState(() => _selecionado = g.perfil),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Botão continuar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _salvando ? null : _avancar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _salvando
                  ? const SizedBox(
                      width: 20, height: 20,
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
}

// Config imutável por grupo — evita alocação por rebuild
class _GrupoConfig {
  final PerfilAtuacao perfil;
  final IconData icon;
  final String title;
  final String subtitle;

  const _GrupoConfig({
    required this.perfil,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
