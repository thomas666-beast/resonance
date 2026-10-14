import { defineStore } from 'pinia'
import { ref } from 'vue'

export type Theme = 'dark' | 'light' | 'system'

const STORAGE_KEY = 'resonance_theme'

function systemPrefersDark(): boolean {
  return window.matchMedia('(prefers-color-scheme: dark)').matches
}

function resolve(theme: Theme): 'dark' | 'light' {
  if (theme === 'system') return systemPrefersDark() ? 'dark' : 'light'
  return theme
}

export const useThemeStore = defineStore('theme', () => {
  const theme = ref<Theme>((localStorage.getItem(STORAGE_KEY) as Theme) ?? 'dark')
  const effective = ref<'dark' | 'light'>(resolve(theme.value))

  function apply() {
    const eff = resolve(theme.value)
    effective.value = eff
    const html = document.documentElement
    if (eff === 'light') html.classList.add('light')
    else                 html.classList.remove('light')
  }

  function set(next: Theme) {
    theme.value = next
    localStorage.setItem(STORAGE_KEY, next)
    apply()
  }

  function toggle() {
    // Cycle: dark → light → system → dark
    const order: Theme[] = ['dark', 'light', 'system']
    const idx = order.indexOf(theme.value)
    set(order[(idx + 1) % order.length])
  }

  // React to OS changes when theme === 'system'
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    if (theme.value === 'system') apply()
  })

  // Apply immediately on store creation
  apply()

  return { theme, effective, set, toggle, apply }
})
