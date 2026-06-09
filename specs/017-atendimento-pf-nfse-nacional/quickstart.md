# Quickstart: App Atendimento PF

## Prerequisites

- Backend running with spec 017 endpoints or compatible mock.
- `API_BASE_URL` configured through existing app pattern.
- Medvie Sandbox enabled in backend for PF emission validation.

## Manual smoke flow

1. Login as medico with CNPJ proprio and certificate active.
2. Open SyncView.
3. Tap FAB / "Novo atendimento".
4. Select "Paciente PF".
5. Fill:
   - nome: `Julia M. Ramos`
   - CPF sintetico valido
   - CEP: `01311000`
   - numero: `1000`
   - email optional
6. Confirm address autofill.
7. Select "Consulta particular".
8. Confirm preview:
   - ISS/IRRF zero
   - IBS/CBS visible when backend returns values
   - status "pronto para emitir"
9. Save without emission.
10. Reopen the service and emit NFS-e.
11. Verify Notas shows `Processando` or `Autorizada`.

## Negative smoke

1. Repeat flow without `numero`.
2. Confirm app saves attendance but blocks "Emitir agora".
3. Complete `numero`.
4. Emit.

## Validation commands

Run from Windows:

```powershell
cd C:\Projects\medvie\medvie-app
dart analyze
flutter test
wsl --cd /mnt/c/Projects/medvie/medvie-app -e ./run_dcm.sh
```

Build only when implementation touches shared/platform code:

```powershell
flutter build apk --debug
```

## Safety checks

- Search for CPF logging before PR:

```powershell
rg -n "cpf|documento|debugPrint|print\\(" lib test
```

Manual review required for any occurrence that could expose raw patient CPF.
