import { defineStore } from 'pinia'
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'

export const useLocaleStore = defineStore('locale', () => {
  const { locale } = useI18n()
  const current = ref(locale.value)

  function set(lang: string) {
    current.value = lang
    locale.value = lang
    localStorage.setItem('resonance_locale', lang)
    document.documentElement.lang = lang
  }

  return { current, set }
})
