import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    port: 5173,
    host: 'localhost',
    strictPort: true,
    hmr: {
      port: 5174
    }
  },
  preview: {
    port: 5173,
    host: 'localhost',
    strictPort: true
  },
  optimizeDeps: {
    include: ['@tauri-apps/api']
  },
  build: {
    rollupOptions: {
      external: (id) => {
        // 大きなメディアファイルを外部化
        return id.includes('.mp4') || id.includes('.webp') || id.includes('.png');
      }
    }
  }
});

