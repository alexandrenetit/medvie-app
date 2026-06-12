import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/constants/app_colors.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/features/syncview/widgets/endereco_fiscal_form.dart';

const _enderecoCep = EnderecoFiscalTomador(
  cep: '01311000',
  logradouro: 'Avenida Paulista',
  bairro: 'Bela Vista',
  municipio: 'Sao Paulo',
  uf: 'SP',
  codigoMunicipioIbge: '3550308',
);

Future<void> _pump(
  WidgetTester tester, {
  required Future<EnderecoFiscalTomador?> Function(String) onResolveCep,
  required ValueChanged<EnderecoFiscalTomador> onChanged,
  EnderecoFiscalTomador? initial,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EnderecoFiscalForm(
            initial: initial,
            onResolveCep: onResolveCep,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

String _chipText(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byKey(const ValueKey('endereco-status-chip')),
      matching: find.byType(Text),
    ),
  );
  return text.data!;
}

void main() {
  group('EnderecoFiscalForm (FR-003/004/005)', () {
    testWidgets('estado inicial vazio → chip "Não informado"', (tester) async {
      await _pump(
        tester,
        onResolveCep: (_) async => null,
        onChanged: (_) {},
      );
      expect(_chipText(tester), 'Não informado');
    });

    testWidgets('CEP de 8 dígitos dispara autofill e completa o endereço', (
      tester,
    ) async {
      String? cepResolvido;
      EnderecoFiscalTomador? ultimo;
      await _pump(
        tester,
        onResolveCep: (cep) async {
          cepResolvido = cep;
          return _enderecoCep;
        },
        onChanged: (e) => ultimo = e,
      );

      await tester.enterText(
        find.byKey(const ValueKey('endereco-cep')),
        '01311000',
      );
      await tester.pumpAndSettle();

      expect(cepResolvido, '01311000');
      // Autofill preencheu logradouro/município.
      expect(find.text('Avenida Paulista'), findsOneWidget);
      expect(find.text('Sao Paulo'), findsOneWidget);
      expect(find.text('IBGE: 3550308'), findsOneWidget);

      // Ainda sem número → incompleto (FR-005).
      expect(_chipText(tester), 'Incompleto');

      await tester.enterText(
        find.byKey(const ValueKey('endereco-numero')),
        '1000',
      );
      await tester.pump();

      expect(_chipText(tester), 'Completo');
      expect(ultimo!.completo, isTrue);
      expect(ultimo!.numero, '1000');
      expect(ultimo!.codigoMunicipioIbge, '3550308');
    });

    testWidgets('CEP que falha → mensagem manual e segue incompleto', (
      tester,
    ) async {
      await _pump(
        tester,
        onResolveCep: (_) async => null,
        onChanged: (_) {},
      );

      await tester.enterText(
        find.byKey(const ValueKey('endereco-cep')),
        '99999999',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('CEP não encontrado. Preencha o endereço manualmente.'),
        findsOneWidget,
      );
      expect(_chipText(tester), 'Incompleto');
    });

    testWidgets('initial completo → chip "Completo"', (tester) async {
      await _pump(
        tester,
        initial: _enderecoCep.copyWith(numero: '1000'),
        onResolveCep: (_) async => null,
        onChanged: (_) {},
      );
      expect(_chipText(tester), 'Completo');
    });

    testWidgets('chip Completo usa cor verde', (tester) async {
      await _pump(
        tester,
        initial: _enderecoCep.copyWith(numero: '1000'),
        onResolveCep: (_) async => null,
        onChanged: (_) {},
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('endereco-status-chip')),
          matching: find.byType(Text),
        ),
      );
      expect(text.style!.color, AppColors.green);
    });
  });
}
