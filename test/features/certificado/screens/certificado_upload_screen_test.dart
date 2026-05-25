// test/features/certificado/screens/certificado_upload_screen_test.dart
//
// Widget tests da CertificadoUploadScreen.
// Cobre: renderização, validação client-side, toggle do switch, fluxo de
// envio (sucesso/erro), e indicador de loading durante o envio.
//
// FilePicker.platform.pickFiles abre seletor nativo e é incompatível com
// widget tests. Para cobrir cenários que dependem de bytes selecionados,
// usamos o hook `@visibleForTesting debugInjectArquivo` exposto pelo
// State da tela.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:medvie/core/models/certificado_metadata.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/certificado_provider.dart';
import 'package:medvie/features/certificado/screens/certificado_upload_screen.dart';
import 'package:medvie/features/certificado/widgets/arquivo_picker_tile.dart';
import 'package:medvie/features/certificado/widgets/senha_field.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeCertificadoProvider extends ChangeNotifier
    implements CertificadoProvider {
  CertificadoState _s = const CertificadoIdle();
  @override
  CertificadoState get state => _s;

  // Captures
  String? capturedCnpjId;
  Uint8List? capturedBytes;
  String? capturedSenha;
  bool? capturedRestrito;
  int enviarCalls = 0;

  // Controle do teste
  CertificadoState? resultadoEnviar;
  Completer<void>? bloqueio;

  @override
  Future<void> enviar(
    String cnpjId,
    Uint8List bytes,
    String senha,
    bool restritoAoCnpj,
  ) async {
    enviarCalls++;
    capturedCnpjId = cnpjId;
    capturedBytes = bytes;
    capturedSenha = senha;
    capturedRestrito = restritoAoCnpj;
    _s = const CertificadoUploading();
    notifyListeners();
    if (bloqueio != null) await bloqueio!.future;
    if (resultadoEnviar != null) {
      _s = resultadoEnviar!;
      notifyListeners();
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

CertificadoMetadata _metadataFake() => CertificadoMetadata(
      status: StatusCertificado.ativo,
      subjectCnpj: '12345678000190',
      issuerName: 'AC TESTE',
      validFrom: DateTime.utc(2026, 1, 1),
      validUntil: DateTime.utc(2027, 1, 1),
      fingerprintSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      restritoAoCnpj: true,
      diasParaVencer: 365,
    );

Future<void> _pumpUploadScreen(
  WidgetTester tester, {
  required _FakeCertificadoProvider provider,
  String cnpjId = 'cnpj-test-001',
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CertificadoProvider>.value(
      value: provider,
      child: MaterialApp(
        home: CertificadoUploadScreen(cnpjId: cnpjId),
      ),
    ),
  );
}

CertificadoUploadScreenState _state(WidgetTester tester) =>
    tester.state<CertificadoUploadScreenState>(
      find.byType(CertificadoUploadScreen),
    );

// ── Testes ───────────────────────────────────────────────────────────────────

void main() {
  group('CertificadoUploadScreen', () {
    testWidgets(
      'renderiza form com ArquivoPickerTile, SenhaField, Switch (true) e CTA',
      (t) async {
        final p = _FakeCertificadoProvider();
        await _pumpUploadScreen(t, provider: p);

        expect(find.byType(ArquivoPickerTile), findsOneWidget);
        expect(find.byType(SenhaField), findsOneWidget);
        expect(find.byType(SwitchListTile), findsOneWidget);
        expect(find.text('Anexar'), findsOneWidget);

        final sw = t.widget<SwitchListTile>(find.byType(SwitchListTile));
        expect(sw.value, isTrue);
      },
    );

    testWidgets(
      'tap "Anexar" sem arquivo → SnackBar erro e provider.enviar não chamado',
      (t) async {
        final p = _FakeCertificadoProvider();
        await _pumpUploadScreen(t, provider: p);

        await t.enterText(find.byType(TextFormField), 'senha123');
        await t.tap(find.text('Anexar'));
        await t.pump();

        expect(
          find.text('Selecione um arquivo .pfx ou .p12.'),
          findsOneWidget,
        );
        expect(p.enviarCalls, 0);
      },
    );

    testWidgets('toggle SwitchListTile alterna restritoAoCnpj', (t) async {
      final p = _FakeCertificadoProvider();
      await _pumpUploadScreen(t, provider: p);

      await t.tap(find.byType(SwitchListTile));
      await t.pump();

      final sw = t.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(sw.value, isFalse);
    });

    testWidgets(
      'envio sucesso → captura args, SnackBar verde e pop(true)',
      (t) async {
        final p = _FakeCertificadoProvider()
          ..resultadoEnviar = CertificadoSuccess(_metadataFake());

        bool? popResult;
        await t.pumpWidget(
          ChangeNotifierProvider<CertificadoProvider>.value(
            value: p,
            child: MaterialApp(
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        popResult = await Navigator.of(ctx).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const CertificadoUploadScreen(
                              cnpjId: 'cnpj-X',
                            ),
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await t.tap(find.text('open'));
        await t.pumpAndSettle();

        _state(t).debugInjectArquivo(
          Uint8List.fromList(const [0x30, 0x82, 0x01, 0x02]),
          'cert.pfx',
          4,
        );
        await t.pump();

        await t.enterText(find.byType(TextFormField), 'senha123');
        await t.tap(find.text('Anexar'));
        await t.pumpAndSettle();

        expect(p.enviarCalls, 1);
        expect(p.capturedCnpjId, 'cnpj-X');
        expect(p.capturedSenha, 'senha123');
        expect(p.capturedRestrito, isTrue);
        expect(p.capturedBytes!.length, 4);
        expect(find.text('Certificado enviado.'), findsOneWidget);
        expect(popResult, isTrue);
      },
    );

    testWidgets(
      'envio falha (CertificadoErro) → SnackBar com mensagem traduzida e tela permanece',
      (t) async {
        final p = _FakeCertificadoProvider()
          ..resultadoEnviar = const CertificadoErro(
            'Certificado.SenhaInvalida',
            'Senha do backend.',
          );
        await _pumpUploadScreen(t, provider: p);

        _state(t).debugInjectArquivo(
          Uint8List.fromList(const [0x30, 0x82]),
          'cert.pfx',
          2,
        );
        await t.pump();

        await t.enterText(find.byType(TextFormField), 'errada');
        await t.tap(find.text('Anexar'));
        await t.pumpAndSettle();

        expect(p.enviarCalls, 1);
        // Tradução de Certificado.SenhaInvalida em certificado_error_codes.dart
        expect(find.text('Senha do certificado inválida.'), findsOneWidget);
        expect(find.byType(CertificadoUploadScreen), findsOneWidget);
      },
    );

    testWidgets('CTA exibe CircularProgressIndicator durante envio', (t) async {
      final p = _FakeCertificadoProvider()
        ..bloqueio = Completer<void>()
        ..resultadoEnviar = CertificadoSuccess(_metadataFake());
      await _pumpUploadScreen(t, provider: p);

      _state(t).debugInjectArquivo(
        Uint8List.fromList(const [0x30, 0x82]),
        'cert.pfx',
        2,
      );
      await t.pump();

      await t.enterText(find.byType(TextFormField), 'senha123');
      await t.tap(find.text('Anexar'));
      await t.pump(); // dispara setState _enviando = true

      expect(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      // Liberar o envio e drenar timers para evitar pending timer no teardown.
      p.bloqueio!.complete();
      await t.pumpAndSettle();
    });
  });
}
