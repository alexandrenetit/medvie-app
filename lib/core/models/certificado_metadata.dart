// lib/core/models/certificado_metadata.dart

import 'medico.dart' show StatusCertificado, StatusCertificadoExt;

/// Metadados do certificado digital A1 sincronizados com o backend Medvie.
///
/// Espelha o fragment OpenAPI `medvie-api/specs/cd-provisionamento/contracts/certificado.openapi.yaml`
/// (pin em `specs/cd-upload/contracts/api-pin.json`).
///
/// Imutável. `fromJson`/`toJson` explícitos. DateTime sempre UTC — parser estrito
/// rejeita valores sem sufixo Z (ver [_parseUtc]).
class CertificadoMetadata {
  final StatusCertificado status;
  final String subjectCnpj;
  final String issuerName;
  final DateTime validFrom;
  final DateTime validUntil;
  final String fingerprintSha256;
  final bool restritoAoCnpj;
  final String? provider;
  final DateTime? provisionadoEm;

  const CertificadoMetadata({
    required this.status,
    required this.subjectCnpj,
    required this.issuerName,
    required this.validFrom,
    required this.validUntil,
    required this.fingerprintSha256,
    required this.restritoAoCnpj,
    this.provider,
    this.provisionadoEm,
  });

  /// Dias inteiros restantes até `validUntil`, computado em UTC.
  ///
  /// Negativo quando o certificado já está vencido.
  int get diasParaVencer {
    final agora = DateTime.now().toUtc();
    return validUntil.difference(agora).inDays;
  }

  Map<String, dynamic> toJson() => {
        'status': status.toJson,
        'subjectCnpj': subjectCnpj,
        'issuerName': issuerName,
        'validFrom': validFrom.toIso8601String(),
        'validUntil': validUntil.toIso8601String(),
        'fingerprintSha256': fingerprintSha256,
        'restritoAoCnpj': restritoAoCnpj,
        'provider': provider,
        'provisionadoEm': provisionadoEm?.toIso8601String(),
      };

  factory CertificadoMetadata.fromJson(Map<String, dynamic> json) {
    return CertificadoMetadata(
      status: StatusCertificadoExt.fromJson(json['status'] as String?),
      subjectCnpj: (json['subjectCnpj'] as String?) ?? '',
      issuerName: (json['issuerName'] as String?) ?? '',
      validFrom: _parseUtc(json['validFrom'], 'validFrom'),
      validUntil: _parseUtc(json['validUntil'], 'validUntil'),
      fingerprintSha256: (json['fingerprintSha256'] as String?) ?? '',
      restritoAoCnpj: (json['restritoAoCnpj'] as bool?) ?? false,
      provider: json['provider'] as String?,
      provisionadoEm:
          _parseUtcNullable(json['provisionadoEm'], 'provisionadoEm'),
    );
  }

  /// Parser ISO-8601 estrito: exige String não vazia, parseável, com flag UTC.
  /// Lança [FormatException] descritiva — sem fallback silencioso.
  static DateTime _parseUtc(Object? value, String campo) {
    if (value is! String || value.isEmpty) {
      throw FormatException(
        'Campo "$campo" ausente ou inválido — esperado ISO-8601 UTC.',
      );
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException(
        'Campo "$campo" não é ISO-8601 válido: "$value".',
      );
    }
    if (!parsed.isUtc) {
      throw FormatException(
        'Campo "$campo" deve estar em UTC (sufixo "Z"): "$value".',
      );
    }
    return parsed;
  }

  static DateTime? _parseUtcNullable(Object? value, String campo) {
    if (value == null) return null;
    return _parseUtc(value, campo);
  }
}
