// lib/core/models/servico.dart

import 'package:flutter/material.dart';

enum TipoServico {
  plantao,
  atoAnestesico,
  laudo,
  procedimentoCirurgico,
  consulta,
  outros,
}

extension TipoServicoExtension on TipoServico {
  String get label {
    switch (this) {
      case TipoServico.plantao:
        return 'Plantão';
      case TipoServico.atoAnestesico:
        return 'Ato Anestésico';
      case TipoServico.laudo:
        return 'Laudo / Exame';
      case TipoServico.procedimentoCirurgico:
        return 'Procedimento Cirúrgico';
      case TipoServico.consulta:
        return 'Consulta / Atendimento';
      case TipoServico.outros:
        return 'Outros';
    }
  }

  String get icone {
    switch (this) {
      case TipoServico.plantao:
        return '🏥';
      case TipoServico.atoAnestesico:
        return '💉';
      case TipoServico.laudo:
        return '🔬';
      case TipoServico.procedimentoCirurgico:
        return '🔪';
      case TipoServico.consulta:
        return '👨‍⚕️';
      case TipoServico.outros:
        return '📋';
    }
  }

  String get codigoNbs {
    switch (this) {
      case TipoServico.plantao:
        return '40119';
      case TipoServico.atoAnestesico:
        return '40119';
      case TipoServico.laudo:
        return '40201';
      case TipoServico.procedimentoCirurgico:
        return '40119';
      case TipoServico.consulta:
        return '40101';
      case TipoServico.outros:
        return '40119';
    }
  }

  String get toJson => name;

  static TipoServico fromJson(String value) {
    return TipoServico.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TipoServico.plantao,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusServico — ciclo de vida sincronizado com backend
//
// Fluxo normal:
//   pendente → nfEmProcessamento → nfEmitida → aguardandoPagamento → pago
//
// Desvio:
//   qualquer status → cancelado
// ─────────────────────────────────────────────────────────────────────────────
enum StatusServico {
  /// Serviço registrado, NFS-e ainda não emitida. Cor: âmbar (#F59E0B).
  pendente,

  /// NFS-e enviada ao middleware, aguardando ADN. Cor: sky (#0EA5E9).
  nfEmProcessamento,

  /// NFS-e autorizada pelo ADN. DANFSe disponível. Cor: índigo (#818CF8).
  nfEmitida,

  /// NFS-e emitida, aguardando repasse do tomador. Cor: laranja (#F97316).
  aguardandoPagamento,

  /// Pagamento recebido. Cor: verde (#00C98A).
  pago,

  /// Cancelado pelo médico ou ADN. Cor: vermelho (#EF4444).
  cancelado,
}

extension StatusServicoExtension on StatusServico {
  String get label {
    switch (this) {
      case StatusServico.pendente:
        return 'Pendente';
      case StatusServico.nfEmProcessamento:
        return 'Em processamento';
      case StatusServico.nfEmitida:
        return 'NF emitida';
      case StatusServico.aguardandoPagamento:
        return 'Aguardando pagamento';
      case StatusServico.pago:
        return 'Pago';
      case StatusServico.cancelado:
        return 'Cancelado';
    }
  }

  Color get color {
    switch (this) {
      case StatusServico.pendente:
        return const Color(0xFFF59E0B);
      case StatusServico.nfEmProcessamento:
        return const Color(0xFF0EA5E9);
      case StatusServico.nfEmitida:
        return const Color(0xFF818CF8);
      case StatusServico.aguardandoPagamento:
        return const Color(0xFFF97316);
      case StatusServico.pago:
        return const Color(0xFF00C98A);
      case StatusServico.cancelado:
        return const Color(0xFFEF4444);
    }
  }

  /// Indica que o serviço foi efetivamente executado (NFS-e em andamento ou concluída).
  bool get foiExecutado {
    switch (this) {
      case StatusServico.nfEmProcessamento:
      case StatusServico.nfEmitida:
      case StatusServico.aguardandoPagamento:
      case StatusServico.pago:
        return true;
      case StatusServico.pendente:
      case StatusServico.cancelado:
        return false;
    }
  }

  /// Serviço na fila "Prontos para emitir NFS-e".
  bool get pendenteDEmissao => this == StatusServico.pendente;

  /// Indica que há uma NFS-e associada (em qualquer estado fiscal).
  bool get temNotaFiscal {
    switch (this) {
      case StatusServico.nfEmProcessamento:
      case StatusServico.nfEmitida:
      case StatusServico.aguardandoPagamento:
      case StatusServico.pago:
        return true;
      default:
        return false;
    }
  }

  String get toJson => name;

  static StatusServico fromJson(String value) {
    return StatusServico.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StatusServico.pendente,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Servico
// ─────────────────────────────────────────────────────────────────────────────
class Servico {
  final String id;
  final TipoServico tipo;
  final DateTime data;
  final String tomadorCnpj;
  final String tomadorNome;
  final double valor;
  final StatusServico status;
  final String observacao;
  final TimeOfDay? horaInicio;
  final TimeOfDay? horaFim;

  const Servico({
    required this.id,
    required this.tipo,
    required this.data,
    required this.tomadorCnpj,
    required this.tomadorNome,
    required this.valor,
    required this.status,
    this.observacao = '',
    this.horaInicio,
    this.horaFim,
  });

  // ── helpers de exibição ───────────────────────────────────────────────────

  String? get duracaoFormatada {
    if (horaInicio == null || horaFim == null) return null;
    final inicioMin = horaInicio!.hour * 60 + horaInicio!.minute;
    final fimMin = horaFim!.hour * 60 + horaFim!.minute;
    int diff = fimMin - inicioMin;
    if (diff <= 0) diff += 24 * 60;
    final horas = diff ~/ 60;
    final min = diff % 60;
    if (min == 0) return '${horas}h';
    return '${horas}h${min.toString().padLeft(2, '0')}';
  }

  String? get horarioFormatado {
    if (horaInicio == null) return null;
    final i =
        '${horaInicio!.hour.toString().padLeft(2, '0')}:${horaInicio!.minute.toString().padLeft(2, '0')}';
    if (horaFim == null) return i;
    final f =
        '${horaFim!.hour.toString().padLeft(2, '0')}:${horaFim!.minute.toString().padLeft(2, '0')}';
    return '$i – $f';
  }

  String get discriminacaoPadrao {
    final mes = _mesExtenso(data.month);
    final ano = data.year;
    switch (tipo) {
      case TipoServico.plantao:
        return 'Plantão médico — $tomadorNome — $mes/$ano';
      case TipoServico.atoAnestesico:
        return 'Ato anestésico — $tomadorNome — $mes/$ano';
      case TipoServico.laudo:
        return 'Emissão de laudo/exame — $tomadorNome — $mes/$ano';
      case TipoServico.procedimentoCirurgico:
        return 'Procedimento cirúrgico — $tomadorNome — $mes/$ano';
      case TipoServico.consulta:
        return 'Consulta / atendimento médico — $tomadorNome — $mes/$ano';
      case TipoServico.outros:
        return 'Prestação de serviços médicos — $tomadorNome — $mes/$ano';
    }
  }

  String get discriminacaoFinal =>
      observacao.trim().isNotEmpty ? observacao.trim() : discriminacaoPadrao;

  // ── copyWith ──────────────────────────────────────────────────────────────

  Servico copyWith({
    String? id,
    TipoServico? tipo,
    DateTime? data,
    String? tomadorCnpj,
    String? tomadorNome,
    double? valor,
    StatusServico? status,
    String? observacao,
    TimeOfDay? horaInicio,
    TimeOfDay? horaFim,
    bool clearHoraInicio = false,
    bool clearHoraFim = false,
  }) {
    return Servico(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      data: data ?? this.data,
      tomadorCnpj: tomadorCnpj ?? this.tomadorCnpj,
      tomadorNome: tomadorNome ?? this.tomadorNome,
      valor: valor ?? this.valor,
      status: status ?? this.status,
      observacao: observacao ?? this.observacao,
      horaInicio: clearHoraInicio ? null : (horaInicio ?? this.horaInicio),
      horaFim: clearHoraFim ? null : (horaFim ?? this.horaFim),
    );
  }

  // ── serialização ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo.toJson,
      'data': data.toIso8601String(),
      'tomadorCnpj': tomadorCnpj,
      'tomadorNome': tomadorNome,
      'valor': valor,
      'status': status.toJson,
      'observacao': observacao,
      'horaInicio': horaInicio != null
          ? '${horaInicio!.hour}:${horaInicio!.minute}'
          : null,
      'horaFim':
          horaFim != null ? '${horaFim!.hour}:${horaFim!.minute}' : null,
    };
  }

  factory Servico.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseHora(String? raw) {
      if (raw == null) return null;
      final parts = raw.split(':');
      if (parts.length != 2) return null;
      return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0);
    }

    return Servico(
      id: json['id'] as String,
      tipo: TipoServicoExtension.fromJson(json['tipo'] as String),
      data: DateTime.parse(json['data'] as String),
      tomadorCnpj: json['tomadorCnpj'] as String,
      tomadorNome: json['tomadorNome'] as String,
      valor: (json['valor'] as num).toDouble(),
      status: StatusServicoExtension.fromJson(json['status'] as String),
      observacao: json['observacao'] as String? ?? '',
      horaInicio: parseHora(json['horaInicio'] as String?),
      horaFim: parseHora(json['horaFim'] as String?),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
String _mesExtenso(int mes) {
  const meses = [
    '',
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];
  return meses[mes];
}