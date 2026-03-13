import { execSync } from 'node:child_process'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

function getLastUpdated() {
  try {
    return execSync('git log -1 --format=%cI', { encoding: 'utf8' }).trim()
  } catch {
    return new Date().toISOString()
  }
}

export default defineConfig({
  plugins: [react()],
  define: {
    'import.meta.env.VITE_LAST_UPDATED': JSON.stringify(getLastUpdated()),
  },
})
