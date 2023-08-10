import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import type { Plugin } from 'vite'
import type { Adapter } from 'vite-plugin-mix'
import mixPlugin from 'vite-plugin-mix'

interface MixConfig {
  handler: string
  adapter?: Adapter | undefined
}

type MixPlugin = (config: MixConfig) => Plugin

interface Mix {
  default: MixPlugin
}

const mix = (mixPlugin as unknown as Mix).default

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    react(),
    mix({
      handler: './api.ts',
    }),
  ],
})
