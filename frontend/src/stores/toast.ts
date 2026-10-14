import { defineStore } from 'pinia'
import { ref } from 'vue'

export type ToastType = 'success' | 'error' | 'info'

export interface Toast {
  id: number
  type: ToastType
  message: string
  timeout?: number
}

let nextId = 1

export const useToastStore = defineStore('toast', () => {
  const items = ref<Toast[]>([])

  function push(type: ToastType, message: string, timeout = 3000) {
    const id = nextId++
    items.value.push({ id, type, message, timeout })
    if (timeout > 0) {
      setTimeout(() => dismiss(id), timeout)
    }
    return id
  }

  function dismiss(id: number) {
    items.value = items.value.filter((t) => t.id !== id)
  }

  const success = (msg: string, t?: number) => push('success', msg, t)
  const error   = (msg: string, t?: number) => push('error', msg, t ?? 5000)
  const info    = (msg: string, t?: number) => push('info', msg, t)

  return { items, push, dismiss, success, error, info }
})
