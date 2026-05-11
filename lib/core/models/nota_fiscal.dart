// lib/core/models/nota_fiscal.dart

/// Número de ticks UTC na época Unix (1970-01-01T00:00:00Z) na escala
/// .NET System.DateTime: 1 tick = 100 ns desde 0001-01-01T00:00:00 UTC.
const int _ticksAt1970 = 621355968000000000;

/// Converte [utc] em ticks compatíveis com System.DateTime.Ticks do .NET.
int _toTicks(DateTime utc) =>
    _ticksAt1970 + utc.toUtc().microsecondsSinceEpoch * 10;

// Enum mantido para UI e lógica de apresentação existente.
// NotaFiscal.status armazena o valor bruto da API como String.
enum StatusNota {
  emProcessamento,
  autorizada,
  rejeitada,
  cancelada,
}

extension StatusNotaExtension on StatusNota {
  String get label {
    switch (this) {
      case StatusNota.emProcessamento:
        return 'Em processamento';
      case StatusNota.autorizada:
        return 'Autorizada';
      case StatusNota.rejeitada:
        return 'Rejeitada';
      case StatusNota.cancelada:
        return 'Cancelada';
    }
  }

  String get toJson => name;

  static StatusNota fromJson(String value) {
    return StatusNota.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StatusNota.emProcessamento,
    );
  }
}

class NotaFiscal {
  final String id;

  /// Status bruto retornado pela API (e.g. "Emitida", "Cancelada", "Rejeitada", "Processando").
  final String status;
  final String codigoNbs;
  final String? numeroNfse;
  final String? chaveAcesso;
  final String? linkPdf;
  final String? motivoRejeicao;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Versão monotônica derivada de [updatedAt] em ticks .NET-compatíveis.
  ///
  /// Compatível com System.DateTime.Ticks (backend .NET):
  /// 1 tick = 100 ns desde 0001-01-01T00:00:00 UTC.
  /// Computado — nunca armazenado — para evitar divergência com [updatedAt]
  /// e garantir versão disponível desde a primeira carga REST.
  int get versao => _toTicks(updatedAt);

  const NotaFiscal({
    required this.id,
    required this.status,
    required this.codigoNbs,
    this.numeroNfse,
    this.chaveAcesso,
    this.linkPdf,
    this.motivoRejeicao,
    required this.createdAt,
    required this.updatedAt,
  });

  NotaFiscal copyWith({
    String? id,
    String? status,
    String? codigoNbs,
    String? numeroNfse,
    String? chaveAcesso,
    String? linkPdf,
    String? motivoRejeicao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotaFiscal(
      id: id ?? this.id,
      status: status ?? this.status,
      codigoNbs: codigoNbs ?? this.codigoNbs,
      numeroNfse: numeroNfse ?? this.numeroNfse,
      chaveAcesso: chaveAcesso ?? this.chaveAcesso,
      linkPdf: linkPdf ?? this.linkPdf,
      motivoRejeicao: motivoRejeicao ?? this.motivoRejeicao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NotaFiscal.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt == null) {
      throw const FormatException(
        'NotaFiscal.fromJson: campo obrigatório "createdAt" ausente ou nulo.',
      );
    }
    final rawUpdatedAt = json['updatedAt'];
    if (rawUpdatedAt == null) {
      throw const FormatException(
        'NotaFiscal.fromJson: campo obrigatório "updatedAt" ausente ou nulo.',
      );
    }
    return NotaFiscal(
      id: json['id'] as String,
      status: json['status'] as String,
      codigoNbs: json['codigoNbs'] as String,
      numeroNfse: json['numeroNfse'] as String?,
      chaveAcesso: json['chaveAcesso'] as String?,
      linkPdf: json['linkPdf'] as String?,
      motivoRejeicao: json['motivoRejeicao'] as String?,
      createdAt: DateTime.parse(rawCreatedAt as String).toUtc(),
      updatedAt: DateTime.parse(rawUpdatedAt as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'codigoNbs': codigoNbs,
      'numeroNfse': numeroNfse,
      'chaveAcesso': chaveAcesso,
      'linkPdf': linkPdf,
      'motivoRejeicao': motivoRejeicao,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotaFiscal &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => id.hashCode ^ updatedAt.hashCode;
}
