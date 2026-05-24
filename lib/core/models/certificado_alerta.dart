// lib/core/models/certificado_alerta.dart

/// Evento SSE `certificado_alerta`.
///
/// Disparado pelo backend quando a janela de alerta de validade do
/// certificado A1 do CNPJ é atingida (faixas 30/7/0 dias). O cliente
/// usa esse evento para forçar reload do metadado e atualizar o
/// semáforo do `CertificadoStatusCard`.
///
/// Contrato (payload SSE):
/// ```json
/// {
///   "type": "certificado_alerta",
///   "cnpjProprioId": "<uuid>",
///   "diasRestantes": 7,
///   "recebidoEm": "2026-05-24T13:45:21Z"
/// }
/// ```
///
/// `recebidoEm` é sempre UTC. Qualquer payload sem `Z` ou com offset
/// não-zero é rejeitado em [fromJson] via `ArgumentError`.
class CertificadoAlerta {
  final String cnpjProprioId;
  final int diasRestantes;
  final DateTime recebidoEm;

  const CertificadoAlerta({
    required this.cnpjProprioId,
    required this.diasRestantes,
    required this.recebidoEm,
  });

  factory CertificadoAlerta.fromJson(Map<String, dynamic> json) {
    final cnpjProprioId = json['cnpjProprioId'];
    final diasRestantes = json['diasRestantes'];
    final recebidoEm = json['recebidoEm'];

    if (cnpjProprioId is! String || cnpjProprioId.isEmpty) {
      throw ArgumentError.value(
        cnpjProprioId,
        'cnpjProprioId',
        'Campo obrigatório (string não vazia).',
      );
    }
    if (diasRestantes is! int) {
      throw ArgumentError.value(
        diasRestantes,
        'diasRestantes',
        'Campo obrigatório (int).',
      );
    }
    if (recebidoEm is! String || recebidoEm.isEmpty) {
      throw ArgumentError.value(
        recebidoEm,
        'recebidoEm',
        'Campo obrigatório (string ISO-8601 UTC).',
      );
    }

    final parsed = DateTime.parse(recebidoEm);
    if (!parsed.isUtc) {
      throw ArgumentError.value(
        recebidoEm,
        'recebidoEm',
        'Timestamp deve ser UTC (sufixo Z).',
      );
    }

    return CertificadoAlerta(
      cnpjProprioId: cnpjProprioId,
      diasRestantes: diasRestantes,
      recebidoEm: parsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'cnpjProprioId': cnpjProprioId,
    'diasRestantes': diasRestantes,
    'recebidoEm': recebidoEm.toIso8601String(),
  };
}
