import { createI18n } from 'vue-i18n'
import en from './locales/en.json'

export const i18n = createI18n({
  legacy: false,          // required for Composition API — without this, useI18n() throws [citation:20]
  globalInjection: true,  // makes $t available in templates
  locale: 'en',
  fallbackLocale: 'en',
  messages: { en },
})
