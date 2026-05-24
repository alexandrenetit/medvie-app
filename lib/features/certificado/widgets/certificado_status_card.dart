// lib/features/certificado/widgets/certificado_status_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/certificado_thresholds.dart';
import '../../../core/models/certificado_metadata.dart';
import '../../../core/models/medico.dart' show StatusCertificado, StatusCertificadoExt;

/// Bundle visual derivado do par `(status, diasParaVencer)` do certificado.
///
/// Cor + ícone + label são os 3 canais que comunicam o estado — nenhum sozinho
/// é suficiente (a11y: usuários com daltonismo dependem do ícone/label).
class _StatusVisual {
  final Color cor;
  final IconData icone;
  final String label;
  const _StatusVisual(this.cor, this.icone, this.label);
}

_StatusVisual _resolve(CertificadoMetadata m) {
  // 1. Removido pelo usuário — bloqueio administrativo, não vencimento.
  if (m.status == StatusCertificado.removido) {
    return const _StatusVisual(AppColors.red, Icons.block, 'Removido');
  }

  // 2. Expirado por status do backend OU por contagem local zerada.
  if (m.status == StatusCertificado.expirado || m.diasParaVencer <= 0) {
    return const _StatusVisual(AppColors.red, Icons.error, 'Expirado');
  }

  // 3. Ativo com prazo crítico (≤ diasUrgente) — ainda válido, mas urgente.
  // Cor distinta de "expirado" (laranja vs vermelho) para diferenciar
  // "expira em breve" de "já expirou".
  if (m.status == StatusCertificado.ativo &&
      m.diasParaVencer <= CertificadoThresholds.diasUrgente) {
    final dia = m.diasParaVencer == 1 ? 'dia' : 'dias';
    return _StatusVisual(
      AppColors.orange,
      Icons.warning_amber_rounded,
      'Expira em ${m.diasParaVencer} $dia',
    );
  }

  // 4. Ativo com aviso (≤ diasAviso).
  if (m.status == StatusCertificado.ativo &&
      m.diasParaVencer <= CertificadoThresholds.diasAviso) {
    return _StatusVisual(
      AppColors.amber,
      Icons.access_time,
      'Expira em ${m.diasParaVencer} dias',
    );
  }

  // 5. Ativo saudável — exibe dias restantes na própria label para que o
  // usuário veja a contagem mesmo fora da faixa de alerta.
  if (m.status == StatusCertificado.ativo) {
    return _StatusVisual(
      AppColors.green,
      Icons.verified,
      'Válido · ${m.diasParaVencer} dias restantes',
    );
  }

  // 6. Pendente / Substituído / Desconhecido — label vem do enum em PT-BR.
  return _StatusVisual(
    AppColors.textDim,
    Icons.help_outline,
    m.status.label,
  );
}

/// Aplica a máscara `XX.XXX.XXX/XXXX-XX` em um CNPJ de 14 dígitos.
/// Se a entrada não tiver exatamente 14 dígitos, devolve a string original
/// (fallback defensivo — backend é a fonte de verdade, mas evita travar a UI).
String _mascararCnpj(String cnpj) {
  final s = cnpj.replaceAll(RegExp(r'\D'), '');
  if (s.length != 14) return cnpj;
  return '${s.substring(0, 2)}.${s.substring(2, 5)}.${s.substring(5, 8)}'
      '/${s.substring(8, 12)}-${s.substring(12)}';
}

/// Card com o semáforo de validade do certificado digital A1.
///
/// Render read-only — alterações partem do provider. Sem chamadas HTTP, sem
/// lógica de negócio além do mapeamento de status para [_StatusVisual].
class CertificadoStatusCard extends StatelessWidget {
  final CertificadoMetadata metadata;

  const CertificadoStatusCard({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final visual = _resolve(metadata);
    final textTheme = Theme.of(context).textTheme;
    final dataValida = DateFormat('dd/MM/yyyy').format(metadata.validUntil);
    final cnpj = _mascararCnpj(metadata.subjectCnpj);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(visual.icone, color: visual.cor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    visual.label,
                    style: textTheme.titleMedium?.copyWith(color: visual.cor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Válido até: $dataValida',
                    style: textTheme.bodySmall,
                  ),
                  Text(
                    'CNPJ: $cnpj',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
