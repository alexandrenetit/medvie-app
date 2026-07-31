// lib/core/constants/irrf_cadastro.dart
//
// Cadastro de IRRF do tomador — lado app do contrato tri-estado (F-04 / A6).
//
// O backend trata `retemIrrf` como TRI-ESTADO
// (medvie-api/docs/fiscal/RETENCAO-IRRF-PJ.md, D9):
//   - ausente/`null` → não informado, cai no default legal do art. 714 do
//     RIR/2018 (tomador que pode ser fonte pagadora PJ retém);
//   - `false`        → recusa explícita do usuário;
//   - `true`         → retenção declarada.
//
// Por isso o app não pode mandar `retemIrrf: false` só porque o Switch nasceu
// desligado: isso transforma silêncio em recusa e devolve o gap F-04.
//
// Fronteira (medvie-api/docs/fiscal/FRONTEIRA-APURACAO-REGIME.md §3/§4): nada
// aqui apura regime ou carga tributária. O arquivo só descreve o default legal
// que o formulário de tomador PJ exibe, traduz um código de erro do backend e
// guarda a copy do aviso de divergência — que é leitura de CADASTRO devolvida
// pelo backend (`retencaoIrrfDivergeRegraGeral`), não diagnóstico fiscal.

/// Alíquota aplicada pelo backend quando o cadastro não informa nenhuma
/// (`FiscalOptions.AliquotaIrrfDefaultPercentual`, D5). Aqui só pré-preenche
/// campo e copy — o valor gravado é sempre o do backend.
const double kIrrfAliquotaPadraoLegal = 1.5;

/// Estado inicial do Switch nos formulários de tomador **PJ**: ligado, porque a
/// retenção do art. 714 é obrigação, não opção. Fluxos de tomador PF não usam
/// esta constante — omitem o campo e deixam o backend resolver.
const bool kRetemIrrfPadraoLegalPj = true;

/// Texto de apoio do Switch nos formulários de tomador PJ.
const String kIrrfHintPadraoLegal =
    'Padrão legal (art. 714 do RIR/2018): a fonte pagadora PJ retém 1,5%. '
    'Desligue apenas se este tomador não retém.';

/// Título do aviso de cadastro divergente.
const String kIrrfDivergenciaTitulo = 'IRRF fora da regra geral';

/// Aviso de cadastro divergente. Descreve o CADASTRO confrontado com a regra
/// geral — não afirma quanto será retido nem que há imposto a pagar.
const String kIrrfDivergenciaTexto =
    'Este cadastro está sem retenção de IRRF, mas a regra geral do art. 714 do '
    'RIR/2018 prevê retenção de 1,5% pela fonte pagadora PJ. Cadastros '
    'anteriores não foram alterados automaticamente — confirme com o tomador e '
    'ajuste se for o caso.';

/// Código de domínio do backend para retenção ligada sem alíquota.
const String kCodigoAliquotaIrrfObrigatoria = 'Tomador.AliquotaIrrfObrigatoria';

/// Copy própria do 400 `Tomador.AliquotaIrrfObrigatoria`.
const String kMensagemAliquotaIrrfObrigatoria =
    'Com a retenção de IRRF ligada, informe uma alíquota maior que zero '
    '(o padrão legal é 1,5%).';
