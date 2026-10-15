import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  server: {
    proxy: {
      '/api/ws': {
        target: 'ws://127.0.0.1:3000',
        ws: true,
        changeOrigin: false,
      },
      '/api': {
        target: 'http://127.0.0.1:3000',
        changeOrigin: false,
      },
      '/rest': {
        target: 'http://127.0.0.1:3000',
        changeOrigin: false,
      },
    },
  },
})
