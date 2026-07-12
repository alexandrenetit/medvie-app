import { Routes, Route, Navigate } from 'react-router-dom';
import { AppShell } from '@/components/layout/AppShell';
import Login from '@/pages/Login';
import Onboarding from '@/pages/Onboarding';
import Overview from '@/pages/Overview';
import Agenda from '@/pages/Agenda';
import Atendimentos from '@/pages/Atendimentos';
import Notas from '@/pages/Notas';
import Relatorios from '@/pages/Relatorios';
import Simulador from '@/pages/Simulador';
import Perfil from '@/pages/Perfil';
import Configuracoes from '@/pages/Configuracoes';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/onboarding" element={<Onboarding />} />
      <Route element={<AppShell />}>
        <Route path="/" element={<Overview />} />
        <Route path="/agenda" element={<Agenda />} />
        <Route path="/atendimentos" element={<Atendimentos />} />
        <Route path="/notas" element={<Notas />} />
        <Route path="/relatorios" element={<Relatorios />} />
        <Route path="/simulador" element={<Simulador />} />
        <Route path="/perfil" element={<Perfil />} />
        <Route path="/config" element={<Configuracoes />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
