import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { medico, COMPETENCIA_ATUAL } from '@/data/mock';

export type ToastTipo = 'sucesso' | 'erro' | 'info' | 'atencao';
export interface Toast {
  id: number;
  tipo: ToastTipo;
  titulo: string;
  descricao?: string;
}

interface AppStateValue {
  cnpjAtivoId: string;
  setCnpjAtivoId: (id: string) => void;
  competencia: string; // 'YYYY-MM'
  setCompetencia: (c: string) => void;
  sidebarCollapsed: boolean;
  toggleSidebar: () => void;
  commandOpen: boolean;
  setCommandOpen: (v: boolean) => void;
  novoAtendimentoOpen: boolean;
  setNovoAtendimentoOpen: (v: boolean) => void;
  toasts: Toast[];
  pushToast: (t: Omit<Toast, 'id'>) => void;
  dismissToast: (id: number) => void;
}

const AppStateContext = createContext<AppStateValue | null>(null);

let toastSeq = 0;

export function AppStateProvider({ children }: { children: ReactNode }) {
  const [cnpjAtivoId, setCnpjAtivoId] = useState(medico.cnpjs[0].id);
  const [competencia, setCompetencia] = useState(COMPETENCIA_ATUAL);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [commandOpen, setCommandOpen] = useState(false);
  const [novoAtendimentoOpen, setNovoAtendimentoOpen] = useState(false);
  const [toasts, setToasts] = useState<Toast[]>([]);

  const pushToast = useCallback((t: Omit<Toast, 'id'>) => {
    const id = ++toastSeq;
    setToasts((prev) => [...prev, { ...t, id }]);
    window.setTimeout(() => {
      setToasts((prev) => prev.filter((x) => x.id !== id));
    }, 4200);
  }, []);

  const dismissToast = useCallback((id: number) => {
    setToasts((prev) => prev.filter((x) => x.id !== id));
  }, []);

  const toggleSidebar = useCallback(() => setSidebarCollapsed((v) => !v), []);

  const value = useMemo<AppStateValue>(
    () => ({
      cnpjAtivoId,
      setCnpjAtivoId,
      competencia,
      setCompetencia,
      sidebarCollapsed,
      toggleSidebar,
      commandOpen,
      setCommandOpen,
      novoAtendimentoOpen,
      setNovoAtendimentoOpen,
      toasts,
      pushToast,
      dismissToast,
    }),
    [
      cnpjAtivoId,
      competencia,
      sidebarCollapsed,
      toggleSidebar,
      commandOpen,
      novoAtendimentoOpen,
      toasts,
      pushToast,
      dismissToast,
    ],
  );

  return <AppStateContext.Provider value={value}>{children}</AppStateContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAppState(): AppStateValue {
  const ctx = useContext(AppStateContext);
  if (!ctx) throw new Error('useAppState deve ser usado dentro de AppStateProvider');
  return ctx;
}
