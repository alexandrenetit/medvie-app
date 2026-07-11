import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';
import { MobileNav } from './MobileNav';
import { CommandPalette } from './CommandPalette';
import { Toaster } from '@/components/ui/Toaster';
import { NovoAtendimento } from '@/components/NovoAtendimento';

export function AppShell() {
  const [mobileNav, setMobileNav] = useState(false);
  return (
    <div className="flex min-h-screen bg-canvas">
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar onOpenMobileNav={() => setMobileNav(true)} />
        <main className="flex-1 px-4 py-6 md:px-6 lg:px-8">
          <div className="mx-auto w-full max-w-[1400px]">
            <Outlet />
          </div>
        </main>
      </div>
      <MobileNav open={mobileNav} onClose={() => setMobileNav(false)} />
      <CommandPalette />
      <NovoAtendimento />
      <Toaster />
    </div>
  );
}
