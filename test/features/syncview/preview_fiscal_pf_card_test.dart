import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:medvie/core/constants/app_colors.dart';
import 'package:medvie/features/syncview/widgets/preview_fiscal_pf_card.dart';

final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

Future<void> _pump(
  WidgetTester tester, {
  required double bruto,
  required bool enderecoCompleto,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PreviewFiscalPfCard(
            bruto: bruto,
            ibs: 0.5,
            cbs: 4.0,
            liquido: bruto,
            enderecoCompleto: enderecoCompleto,
          ),
        ),
      ),
    ),
  );
}

Color _statusColor(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byKey(const ValueKey('preview-pf-status')),
      matching: find.byType(Text),
    ),
  );
  return text.style!.color!;
}

void main() {
  group('PreviewFiscalPfCard (T042/FR-007)', () {
    testWidgets('mostra ISS e IRRF retido (PF) zerados', (tester) async {
      await _pump(tester, bruto: 500, enderecoCompleto: true);

      expect(find.text('ISS retido (PF)'), findsOneWidget);
      expect(find.text('IRRF retido (PF)'), findsOneWidget);
      // Dois valores zerados (ISS + IRRF).
      expect(find.text(_fmt.format(0)), findsNWidgets(2));
    });

    testWidgets('exibe IBS/CBS com tag REFORMA e valor da NFS-e', (
      tester,
    ) async {
      await _pump(tester, bruto: 500, enderecoCompleto: true);

      expect(find.text('IBS'), findsOneWidget);
      expect(find.text('CBS'), findsOneWidget);
      expect(find.text('REFORMA'), findsNWidgets(2));
      expect(find.text('Valor da NFS-e'), findsOneWidget);
      // bruto e líquido valem 500 → aparece em "Valor do serviço" e "NFS-e".
      expect(find.text(_fmt.format(500)), findsNWidgets(2));
    });

    testWidgets('prontoParaEmitir só com valor e endereço completo', (
      tester,
    ) async {
      await _pump(tester, bruto: 500, enderecoCompleto: true);
      expect(find.text('Pronto para emitir'), findsOneWidget);
      expect(_statusColor(tester), AppColors.green);
    });

    testWidgets('sem valor → pede o valor (âmbar)', (tester) async {
      await _pump(tester, bruto: 0, enderecoCompleto: true);
      expect(find.text('Informe o valor'), findsOneWidget);
      expect(_statusColor(tester), AppColors.amber);
    });

    testWidgets('valor sem endereço completo → bloqueia (âmbar)', (
      tester,
    ) async {
      await _pump(tester, bruto: 500, enderecoCompleto: false);
      expect(
        find.text('Complete o endereço para emitir'),
        findsOneWidget,
      );
      expect(_statusColor(tester), AppColors.amber);
    });
  });
}
