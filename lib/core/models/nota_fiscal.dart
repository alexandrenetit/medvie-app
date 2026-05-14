// lib/core/models/nota_fiscal.dart

/// Número de ticks UTC na época Unix (1970-01-01T00:00:00Z) na escala
/// .NET System.DateTime: 1 tick = 100 ns desde 0001-01-01T00:00:00 UTC.
const int _ticksAt1970 = 621355968000000000;
final _dateOnlyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Converte [utc] em ticks compatíveis com System.DateTime.Ticks do .NET.
int _toTicks(DateTime utc) =>
    _ticksAt1970 + utc.toUtc().microsecondsSinceEpoch * 10;

DateTime? _parseOptionalDate(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) return null;
  final raw = value.trim();
  if (_dateOnlyPattern.hasMatch(raw)) {
    final parts = raw.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }
  return DateTime.parse(raw).toUtc();
}

// Enum mantido para UI e lógica de apresentação existente.
// NotaFiscal.status armazena o valor normalizado usado pela UI.
enum StatusNota { emProcessamento, autorizada, rejeitada, cancelada }

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
    final normalized = value.trim().toLowerCase();
    if (normalized == 'processando' ||
        normalized == 'pendente' ||
        normalized == 'rascunho' ||
        normalized == 'emprocessamento') {
      return StatusNota.emProcessamento;
    }
    if (normalized == 'autorizada' || normalized == 'emitida') {
      return StatusNota.autorizada;
    }
    if (normalized == 'rejeitada') return StatusNota.rejeitada;
    if (normalized == 'cancelada') return StatusNota.cancelada;
    return StatusNota.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
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
  final String? servicoId;
  final String? tomadorNome;
  final double? valorBruto;
  final double? valorLiquido;
  final String? tipoServico;
  final DateTime? dataServico;
  final DateTime? dataEmissao;
  final String? numeroNf;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Versão monotônica derivada de [updatedAt] em ticks .NET-compatíveis.
  ///
  /// Compatível com System.DateTime.Ticks (backend .NET):
  /// 1 tick = 100 ns desde 0001-01-01T00:00:00 UTC.
  /// Computado — nunca armazenado — para evitar divergência com [updatedAt]
  /// e garantir versão disponível desde a primeira carga REST.
  int get versao => _toTicks(updatedAt);

  DateTime get dataReferencia => dataServico ?? dataEmissao ?? createdAt;

  const NotaFiscal({
    required this.id,
    required this.status,
    required this.codigoNbs,
    this.numeroNfse,
    this.chaveAcesso,
    this.linkPdf,
    this.motivoRejeicao,
    this.servicoId,
    this.tomadorNome,
    this.valorBruto,
    this.valorLiquido,
    this.tipoServico,
    this.dataServico,
    this.dataEmissao,
    this.numeroNf,
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
    String? servicoId,
    String? tomadorNome,
    double? valorBruto,
    double? valorLiquido,
    String? tipoServico,
    DateTime? dataServico,
    DateTime? dataEmissao,
    String? numeroNf,
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
      servicoId: servicoId ?? this.servicoId,
      tomadorNome: tomadorNome ?? this.tomadorNome,
      valorBruto: valorBruto ?? this.valorBruto,
      valorLiquido: valorLiquido ?? this.valorLiquido,
      tipoServico: tipoServico ?? this.tipoServico,
      dataServico: dataServico ?? this.dataServico,
      dataEmissao: dataEmissao ?? this.dataEmissao,
      numeroNf: numeroNf ?? this.numeroNf,
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
      status: StatusNotaExtension.fromJson(json['status'] as String).name,
      codigoNbs: json['codigoNbs'] as String,
      numeroNfse: (json['numeroNfse'] ?? json['numeroNf']) as String?,
      chaveAcesso: json['chaveAcesso'] as String?,
      linkPdf: json['linkPdf'] as String?,
      motivoRejeicao: json['motivoRejeicao'] as String?,
      servicoId: json['servicoId'] as String?,
      tomadorNome: json['tomadorNome'] as String?,
      valorBruto: (json['valorBruto'] as num?)?.toDouble(),
      valorLiquido: (json['valorLiquido'] as num?)?.toDouble(),
      tipoServico: json['tipoServico'] as String?,
      dataServico: _parseOptionalDate(json['dataServico']),
      dataEmissao: _parseOptionalDate(json['dataEmissao']),
      numeroNf: json['numeroNf'] as String?,
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
      'servicoId': servicoId,
      'tomadorNome': tomadorNome,
      'valorBruto': valorBruto,
      'valorLiquido': valorLiquido,
      'tipoServico': tipoServico,
      'dataServico': dataServico?.toUtc().toIso8601String(),
      'dataEmissao': dataEmissao?.toUtc().toIso8601String(),
      'numeroNf': numeroNf,
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
