// lib/core/models/nota_fiscal.dart

import 'package:flutter/foundation.dart';

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
  final String servicoId; // FK para o Servico
  final String tomadorRazaoSocial;
  final String tomadorCnpj;
  final String cnpjEmissor;
  final double valor;

  /// Data em que o serviço FOI prestado — define a competência fiscal.
  /// NUNCA pode ser data futura — legislação NFS-e Nacional (LC 214/2025).
  final DateTime competencia;

  /// Data em que a NFS-e foi transmitida ao middleware / ADN.
  final DateTime emitidaEm;

  final StatusNota status;
  final String? numeroNota;
  final String? chaveAcesso;

  /// URL do DANFSe retornado pelo middleware (simulado no protótipo).
  final String? linkPdf;

  /// Mensagem amigável ao médico — nunca exibir código técnico de erro.
  final String? motivoRejeicao;

  /// Versão monotônica da nota (UpdatedAt.Ticks UTC no backend).
  /// Usada na reconciliação pós-reconexão SSE (item K7) para descartar
  /// atualizações antigas e proteger contra sobrescrita por evento SSE
  /// concorrente que cheguem em paralelo à chamada REST.
  /// Pode ser nulo em respostas legadas que ainda não trafegam o campo.
  final int? versao;

  const NotaFiscal({
    required this.id,
    required this.servicoId,
    required this.tomadorRazaoSocial,
    required this.tomadorCnpj,
    required this.cnpjEmissor,
    required this.valor,
    required this.competencia,
    required this.emitidaEm,
    required this.status,
    this.numeroNota,
    this.chaveAcesso,
    this.linkPdf,
    this.motivoRejeicao,
    this.versao,
  });

  NotaFiscal copyWith({
    String? id,
    String? servicoId,
    String? tomadorRazaoSocial,
    String? tomadorCnpj,
    String? cnpjEmissor,
    double? valor,
    DateTime? competencia,
    DateTime? emitidaEm,
    StatusNota? status,
    String? numeroNota,
    String? chaveAcesso,
    String? linkPdf,
    String? motivoRejeicao,
    int? versao,
  }) {
    return NotaFiscal(
      id: id ?? this.id,
      servicoId: servicoId ?? this.servicoId,
      tomadorRazaoSocial: tomadorRazaoSocial ?? this.tomadorRazaoSocial,
      tomadorCnpj: tomadorCnpj ?? this.tomadorCnpj,
      cnpjEmissor: cnpjEmissor ?? this.cnpjEmissor,
      valor: valor ?? this.valor,
      competencia: competencia ?? this.competencia,
      emitidaEm: emitidaEm ?? this.emitidaEm,
      status: status ?? this.status,
      numeroNota: numeroNota ?? this.numeroNota,
      chaveAcesso: chaveAcesso ?? this.chaveAcesso,
      linkPdf: linkPdf ?? this.linkPdf,
      motivoRejeicao: motivoRejeicao ?? this.motivoRejeicao,
      versao: versao ?? this.versao,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'servicoId': servicoId,
      'tomadorRazaoSocial': tomadorRazaoSocial,
      'tomadorCnpj': tomadorCnpj,
      'cnpjEmissor': cnpjEmissor,
      'valor': valor,
      'competencia': competencia.toIso8601String(),
      'emitidaEm': emitidaEm.toIso8601String(),
      'status': status.toJson,
      'numeroNota': numeroNota,
      'chaveAcesso': chaveAcesso,
      'linkPdf': linkPdf,
      'motivoRejeicao': motivoRejeicao,
      if (versao != null) 'versao': versao,
    };
  }

  factory NotaFiscal.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      debugPrint('[NOTAS] fromJson keys: ${json.keys.toList()}');
      debugPrint('[NOTAS] id=${json['id']} servicoId=${json['servicoId']} '
          'tomadorRazaoSocial=${json['tomadorRazaoSocial']} '
          'tomadorCnpj=${json['tomadorCnpj']} cnpjEmissor=${json['cnpjEmissor']} '
          'competencia=${json['competencia']} emitidaEm=${json['emitidaEm']} '
          'status=${json['status']}');
    }
    return NotaFiscal(
      id: json['id'] as String,
      servicoId: json['servicoId'] as String,
      tomadorRazaoSocial: json['tomadorRazaoSocial'] as String,
      tomadorCnpj: json['tomadorCnpj'] as String,
      cnpjEmissor: json['cnpjEmissor'] as String,
      valor: (json['valor'] as num).toDouble(),
      competencia: DateTime.parse(json['competencia'] as String),
      emitidaEm: DateTime.parse(json['emitidaEm'] as String),
      status: StatusNotaExtension.fromJson(json['status'] as String),
      numeroNota: json['numeroNota'] as String?,
      chaveAcesso: json['chaveAcesso'] as String?,
      linkPdf: json['linkPdf'] as String?,
      motivoRejeicao: json['motivoRejeicao'] as String?,
      versao: (json['versao'] as num?)?.toInt(),
    );
  }
}