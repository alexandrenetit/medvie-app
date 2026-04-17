// lib/core/models/perfil_atuacao.dart

/// Grupo de atuação do médico PJ.
/// Valores espelham o enum C# PerfilAtuacao no backend.
/// Determina quais telas do onboarding são exibidas e os defaults fiscais.
enum PerfilAtuacao {
  medicoClinico(1),
  procedimentalistaAmbulatorial(2),
  plantonistaHospitalar(3),
  cirurgiao(4);

  const PerfilAtuacao(this.value);

  /// Valor inteiro enviado/recebido do backend.
  final int value;

  /// Desserializa a partir do inteiro retornado pelo backend.
  /// Default: [medicoClinico] (valor 1) para médicos sem perfil definido.
  static PerfilAtuacao fromValue(int value) =>
      PerfilAtuacao.values.firstWhere(
        (e) => e.value == value,
        orElse: () => PerfilAtuacao.medicoClinico,
      );

  /// Desserializa a partir do nome string retornado pelo backend (C# enum name).
  /// Ex: "MedicoClinico", "PlantonistaHospitalar"
  static PerfilAtuacao fromName(String name) {
    const map = {
      'MedicoClinico': PerfilAtuacao.medicoClinico,
      'ProcedimentalistaAmbulatorial': PerfilAtuacao.procedimentalistaAmbulatorial,
      'PlantonistaHospitalar': PerfilAtuacao.plantonistaHospitalar,
      'Cirurgiao': PerfilAtuacao.cirurgiao,
    };
    return map[name] ?? PerfilAtuacao.medicoClinico;
  }

  /// Desserializa aceitando int ou string (robusto para qualquer formato do backend).
  /// Default: [medicoClinico] para valores nulos ou não reconhecidos.
  static PerfilAtuacao fromJson(dynamic value) {
    if (value is int) return fromValue(value);
    if (value is String) {
      final asInt = int.tryParse(value);
      if (asInt != null) return fromValue(asInt);
      return fromName(value);
    }
    return PerfilAtuacao.medicoClinico;
  }
}
