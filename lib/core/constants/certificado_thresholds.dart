// lib/core/constants/certificado_thresholds.dart

/// Limiares de validade do certificado digital A1, usados pelo semáforo do
/// `CertificadoStatusCard`. Mantidos centralizados aqui para que UI e
/// (eventual) lógica de alerta no provider compartilhem os mesmos valores.
///
/// Faixas (aplicadas quando `status == ativo`):
/// - `diasParaVencer > diasAviso`  → válido (verde)
/// - `diasParaVencer <= diasAviso` → aviso (amarelo)
/// - `diasParaVencer <= diasUrgente` → crítico (vermelho)
/// - `diasParaVencer <= 0` → expirado (vermelho, ícone distinto)
abstract class CertificadoThresholds {
  /// Abaixo deste número de dias → status visual amarelo (amber).
  static const int diasAviso = 30;

  /// Abaixo deste número de dias → status visual vermelho (red).
  static const int diasUrgente = 7;
}
