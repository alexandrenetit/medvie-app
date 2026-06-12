import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/features/syncview/widgets/paciente_pf_form.dart';

// CPF sintético válido (dígitos verificadores corretos).
const _cpfValido = '11144477735';

LookupTomadorResponse _encontrado() => const LookupTomadorResponse(
      status: LookupTomadorStatus.encontrado,
      tomadorId: 'tom-1',
      documentoMascarado: '***.***.***-35',
      nome: 'Julia M. Ramos',
      email: 'julia@example.com',
      telefone: '11999990000',
      enderecoFiscalStatus: 'Completo',
    );

Future<void> _pump(
  WidgetTester tester, {
  required Future<LookupTomadorResponse> Function(String) onLookupCpf,
  ValueChanged<LookupTomadorResponse>? onLookupResult,
  ValueChanged<PacientePfDados>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PacientePfForm(
            onLookupCpf: onLookupCpf,
            onLookupResult: onLookupResult ?? (_) {},
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

Future<void> _blurCpf(WidgetTester tester) async {
  // Mover foco para o nome dispara o blur do CPF.
  await tester.tap(find.byKey(const ValueKey('pf-nome')));
  await tester.pumpAndSettle();
}

void main() {
  group('PacientePfForm — CPF-first (FR-014/015/016)', () {
    testWidgets('CPF válido + blur → lookup encontrado auto-preenche', (
      tester,
    ) async {
      String? cpfConsultado;
      LookupTomadorResponse? resultado;
      await _pump(
        tester,
        onLookupCpf: (cpf) async {
          cpfConsultado = cpf;
          return _encontrado();
        },
        onLookupResult: (r) => resultado = r,
      );

      await tester.enterText(
        find.byKey(const ValueKey('pf-cpf')),
        _cpfValido,
      );
      await _blurCpf(tester);

      expect(cpfConsultado, _cpfValido);
      expect(find.byKey(const ValueKey('pf-found')), findsOneWidget);
      expect(find.text('✓ Julia M. Ramos'), findsOneWidget);
      // Nome auto-preenchido no campo.
      expect(find.text('Julia M. Ramos'), findsOneWidget);
      expect(find.text('julia@example.com'), findsOneWidget);
      expect(resultado, isNotNull);
      expect(resultado!.encontrado, isTrue);
    });

    testWidgets('CPF válido + blur → 404 mostra "Novo paciente"', (
      tester,
    ) async {
      await _pump(
        tester,
        onLookupCpf: (_) async => LookupTomadorResponse.novoPaciente(),
      );

      await tester.enterText(
        find.byKey(const ValueKey('pf-cpf')),
        _cpfValido,
      );
      await _blurCpf(tester);

      expect(find.text('Novo paciente'), findsOneWidget);
    });

    testWidgets('CPF inválido → não consulta backend e marca inválido', (
      tester,
    ) async {
      var consultou = false;
      await _pump(
        tester,
        onLookupCpf: (_) async {
          consultou = true;
          return LookupTomadorResponse.novoPaciente();
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('pf-cpf')),
        '12345678900', // DV inválido
      );
      await _blurCpf(tester);

      expect(consultou, isFalse);
      expect(find.text('CPF inválido'), findsOneWidget);
    });

    testWidgets('onChanged emite CPF bruto transiente para o parent', (
      tester,
    ) async {
      PacientePfDados? ultimo;
      await _pump(
        tester,
        onLookupCpf: (_) async => LookupTomadorResponse.novoPaciente(),
        onChanged: (d) => ultimo = d,
      );

      await tester.enterText(
        find.byKey(const ValueKey('pf-cpf')),
        _cpfValido,
      );
      await tester.pump();

      expect(ultimo, isNotNull);
      expect(ultimo!.documentoCpf, _cpfValido);
    });

    testWidgets('CPF incompleto no blur não dispara lookup', (tester) async {
      var consultou = false;
      await _pump(
        tester,
        onLookupCpf: (_) async {
          consultou = true;
          return LookupTomadorResponse.novoPaciente();
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('pf-cpf')),
        '111444',
      );
      await _blurCpf(tester);

      expect(consultou, isFalse);
      expect(find.byKey(const ValueKey('pf-found')), findsNothing);
    });
  });
}
