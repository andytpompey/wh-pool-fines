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
    __LAST_UPDATED__: JSON.stringify(getLastUpdated()),
  },
})
