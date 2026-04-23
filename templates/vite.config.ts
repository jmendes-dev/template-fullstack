// templates/vite.config.ts — Sample para apps/web (copiar e adaptar em /new-project)
//
// Flags obrigatórias para Vite HMR funcionar em Docker+Windows (WSL2):
// - server.host: true  → bind 0.0.0.0 (acessível pelo host)
// - server.hmr.host/clientPort → browser conecta ao host, não ao container
// - server.watch.usePolling → inotify não propaga pelo WSL2 volume mounts
//
// Stack: Vite 8 (Rolldown) + React 19 + Tailwind v4 + React Router v7
// Refs: claude-stacks.md regra 23 (Tailwind v4 CSS-first) e regra 27 (Vite 8).

import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],

  resolve: {
    // Vite 8+ resolve paths do tsconfig nativamente — não precisa de vite-tsconfig-paths
    tsconfigPaths: true,
  },

  server: {
    // Expor em 0.0.0.0 para ser acessível pelo host quando rodando em container
    host: true,
    port: Number(process.env.WEB_PORT) || 5173,
    strictPort: true,

    hmr: {
      // Browser conecta no host — não no hostname do container (`web`)
      host: "localhost",
      port: Number(process.env.WEB_PORT) || 5173,
      clientPort: Number(process.env.WEB_PORT) || 5173,
    },

    watch: {
      // Inotify não funciona em volumes bind-mounted no Docker Desktop (Windows/WSL2)
      // Polling é a única opção confiável. 1000ms = balanço entre CPU e latência de HMR.
      usePolling: true,
      interval: 1000,
    },
  },

  build: {
    // Vite 8: rolldownOptions substitui rollupOptions (auto-convert ainda existe para compat)
    rolldownOptions: {
      output: {
        // Chunking padrão — projetos específicos podem override
      },
    },
  },
});
