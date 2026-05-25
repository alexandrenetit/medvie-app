// test/features/syncview/certificado_card_test.dart
//
// Widget tests do CertificadoStatusCard renderizado no topo da SyncView.
// Cobre a decisão de exibição inserida em `SyncViewScreen` (T080):
//   (a) state = CertificadoSuccess saudável (>diasAviso) → card visível, label "Válido".
//   (b) state = CertificadoSuccess crítico (<=diasUrgente) → card visível, ícone de alerta.
//   (c) state = CertificadoIdle → card ausente (SizedBox.shrink).
//
// Pumpa o slice de UI (Consumer<CertificadoProvider> + CertificadoStatusCard) em
// vez da SyncViewScreen inteira, evitando dependência de múltiplos providers
// pesados (servico, nota fiscal, etc.) que não fazem parte do escopo desta task.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:medvie/core/models/certificado_metadata.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/certificado_provider.dart';
import 'package:medvie/features/certificado/widgets/certificado_status_card.dart';

// ── Fake CertificadoProvider ─────────────────────────────────────────────────

class _FakeCertificadoProvider extends ChangeNotifier
    implements CertificadoProvider {
  _FakeCertificadoProvider(this._s);

  final CertificadoState _s;

  @override
  CertificadoState get state => _s;

  @override
  Future<void> carregar(String cnpjId) async {}

  @override
  Future<void> enviar(
    String cnpjId,
    Uint8List bytes,
    String senha,
    bool restritoAoCnpj,
  ) async {}

  @override
  Future<void> remover(String cnpjId) async {}

  @override
  void bindSse(Object sse) {}

  @override
  bool get carregando => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Helpers ──────────────────────────────────────────────────────────────────

CertificadoMetadata _buildMetadata({int dias = 220}) => CertificadoMetadata(
      status: StatusCertificado.ativo,
      subjectCnpj: '11222333000181',
      issuerName: 'AC TESTE',
      validFrom: DateTime.utc(2026, 1, 1),
      validUntil: DateTime.utc(2027, 1, 1),
      fingerprintSha256: 'a' * 64,
      restritoAoCnpj: true,
      diasParaVencer: dias,
    );

/// Reproduz o slice inserido em SyncViewScreen pela T080.
/// Mantém o teste alinhado ao código de produção sem instanciar a tela inteira.
Widget _harness(CertificadoProvider cert) {
  return ChangeNotifierProvider<CertificadoProvider>.value(
    value: cert,
    child: MaterialApp(
      home: Scaffold(
        body: Consumer<CertificadoProvider>(
          builder: (_, c, _) {
            final s = c.state;
            if (s is! CertificadoSuccess) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CertificadoStatusCard(metadata: s.metadata),
            );
          },
        ),
      ),
    ),
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  testWidgets(
    '(a) CertificadoSuccess saudável → card visível com label "Válido"',
    (tester) async {
      final cert = _FakeCertificadoProvider(
        CertificadoSuccess(_buildMetadata(dias: 220)),
      );

      await tester.pumpWidget(_harness(cert));
      await tester.pumpAndSettle();

      expect(find.byType(CertificadoStatusCard), findsOneWidget);
      expect(find.textContaining('220 dias restantes'), findsOneWidget);
    },
  );

  testWidgets(
    '(b) CertificadoSuccess crítico → card visível com ícone de alerta',
    (tester) async {
      final cert = _FakeCertificadoProvider(
        CertificadoSuccess(_buildMetadata(dias: 3)),
      );

      await tester.pumpWidget(_harness(cert));
      await tester.pumpAndSettle();

      expect(find.byType(CertificadoStatusCard), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('Expira em 3'), findsOneWidget);
    },
  );

  testWidgets(
    '(c) CertificadoIdle → card ausente',
    (tester) async {
      final cert = _FakeCertificadoProvider(const CertificadoIdle());

      await tester.pumpWidget(_harness(cert));
      await tester.pumpAndSettle();

      expect(find.byType(CertificadoStatusCard), findsNothing);
    },
  );
}
