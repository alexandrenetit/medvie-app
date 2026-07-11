import { createRoot } from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import App from './App';
import { AppStateProvider } from './context/AppState';

// Fontes self-hosted (@fontsource) — sem dependência de rede externa em runtime.
import '@fontsource/inter/400.css';
import '@fontsource/inter/500.css';
import '@fontsource/inter/600.css';
import '@fontsource/inter/700.css';
import '@fontsource/outfit/500.css';
import '@fontsource/outfit/600.css';
import '@fontsource/outfit/700.css';
import '@fontsource/outfit/800.css';
import '@fontsource/jetbrains-mono/500.css';
import '@fontsource/jetbrains-mono/600.css';
import '@fontsource/jetbrains-mono/700.css';

import './index.css';

// Protótipo web Medvie — SPA estática, dados 100% mockados.
// HashRouter para funcionar em qualquer host estático sem config de servidor.
// Primeira carga (sem hash) inicia no login, como no produto.
if (!window.location.hash) {
  window.location.hash = '#/login';
}

// Sem React.StrictMode: overlays (modais, drawers, popovers, toasts) montam e
// desmontam por render condicional simples, sem depender do ciclo de exit do
// AnimatePresence. Manter StrictMode fora evita o double-invoke de efeitos em
// dev interferir nesses ciclos. Não afeta o build de produção.
createRoot(document.getElementById('root')!).render(
  <HashRouter>
    <AppStateProvider>
      <App />
    </AppStateProvider>
  </HashRouter>,
);
