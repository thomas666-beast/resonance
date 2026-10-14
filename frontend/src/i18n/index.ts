import { createI18n } from 'vue-i18n'
import en from './locales/en.json'
import es from './locales/es.json'

const SUPPORTED = ['en', 'es']
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
  messages: { en, es },
})

export const SUPPORTED_LOCALES = SUPPORTED
