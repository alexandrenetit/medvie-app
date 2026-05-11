// lib/core/models/notas_pagina.dart

import 'nota_fiscal.dart';

class NotasPagina {
  final List<NotaFiscal> notas;
  final int total;
  final int pagina;
  final int tamanhoPagina;

  const NotasPagina({
    required this.notas,
    required this.total,
    required this.pagina,
    required this.tamanhoPagina,
  });

  factory NotasPagina.fromJson(Map<String, dynamic> json) {
    return NotasPagina(
      notas: List.unmodifiable(_parseNotas(json['notas'])),
      total: _parseInt(json['total'], defaultValue: 0, fieldName: 'total'),
      pagina: _parseInt(json['pagina'], defaultValue: 1, fieldName: 'pagina'),
      tamanhoPagina: _parseInt(
        json['tamanhoPagina'],
        defaultValue: 20,
        fieldName: 'tamanhoPagina',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notas': notas.map((nota) => nota.toJson()).toList(),
      'total': total,
      'pagina': pagina,
      'tamanhoPagina': tamanhoPagina,
    };
  }

  NotasPagina copyWith({
    List<NotaFiscal>? notas,
    int? total,
    int? pagina,
    int? tamanhoPagina,
  }) {
    return NotasPagina(
      notas: notas == null ? this.notas : List.unmodifiable(notas),
      total: total ?? this.total,
      pagina: pagina ?? this.pagina,
      tamanhoPagina: tamanhoPagina ?? this.tamanhoPagina,
    );
  }

  static List<NotaFiscal> _parseNotas(Object? rawNotas) {
    if (rawNotas == null) return const <NotaFiscal>[];
    if (rawNotas is! List) {
      throw const FormatException(
        'NotasPagina.fromJson: campo "notas" deve ser uma lista.',
      );
    }

    return rawNotas.map((rawNota) {
      if (rawNota is! Map) {
        throw const FormatException(
          'NotasPagina.fromJson: cada item de "notas" deve ser um objeto.',
        );
      }

      return NotaFiscal.fromJson(Map<String, dynamic>.from(rawNota));
    }).toList();
  }

  static int _parseInt(
    Object? value, {
    required int defaultValue,
    required String fieldName,
  }) {
    if (value == null) return defaultValue;
    if (value is num) return value.toInt();

    throw FormatException(
      'NotasPagina.fromJson: campo "$fieldName" deve ser numerico.',
    );
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotasPagina &&
          runtimeType == other.runtimeType &&
          _listEquals(notas, other.notas) &&
          total == other.total &&
          pagina == other.pagina &&
          tamanhoPagina == other.tamanhoPagina;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(notas), total, pagina, tamanhoPagina);
}
