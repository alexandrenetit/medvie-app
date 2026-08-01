# Conventions
- Light theme tokens only: canvas/card/sidebar, brand/info/warn/danger, ink variants; no literal colors/fonts/dimensions when project tokens/components exist.
- Reuse `components/ui` primitives, `data/domain.ts`, `lib/cn.ts`, `lib/format.ts`.
- UI copy pt-BR; short pt-BR file-header comments.
- `.num` for CPF/CNPJ/money numeric presentation.
- Onboarding state stays local to `pages/Onboarding.tsx`; Flutter flow is content/business-rule source, not layout template.
- Tomadores step only for `plantonistaHospitalar`.
- Simulated integrations only; no real API/backend.
- HashRouter; keep StrictMode disabled.