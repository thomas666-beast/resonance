import { createI18n } from 'vue-i18n'
import en from './locales/en.json'

const SUPPORTED = ['en']
const DEFAULT = 'en'

function detectLocale(): string {
  const saved = localStorage.getItem('resonance_locale')
  if (saved && SUPPORTED.includes(saved)) return saved

  // Future: inspect navigator.language here
  return DEFAULT
}

export const i18n = createI18n({
  legacy: false,
  globalInjection: true,
  locale: detectLocale(),
  fallbackLocale: DEFAULT,
  messages: { en },
})

export const SUPPORTED_LOCALES = SUPPORTED
