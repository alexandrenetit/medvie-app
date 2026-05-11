// lib/core/models/nota_sincronizacao.dart
//
// DTO retornado por GET /api/v1/notas/sincronizar.
// Usado exclusivamente pela reconciliação pós-reconexão SSE (item K7
// do Relatório de Auditoria — RELATORIOWEBHOOK.md).

class NotaSincronizacao {
  final String notaId;
  final String status;

  /// Versão monotônica (UpdatedAt.Ticks UTC no backend), quando enviada.
  /// Maior valor sempre prevalece sobre menor.
  final int? versao;

  final DateTime dataAtualizacao;

  const NotaSincronizacao({
    required this.notaId,
    required this.status,
    this.versao,
    required this.dataAtualizacao,
  });

  factory NotaSincronizacao.fromJson(Map<String, dynamic> json) {
    return NotaSincronizacao(
      notaId: json['notaId'] as String,
      status: json['status'] as String,
      versao: (json['versao'] as num?)?.toInt(),
      dataAtualizacao: DateTime.parse(
        json['dataAtualizacao'] as String,
      ).toUtc(),
    );
  }
}
