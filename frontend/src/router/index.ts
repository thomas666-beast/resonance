import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/login',    name: 'login',    component: () => import('@/views/LoginView.vue') },
    { path: '/register', name: 'register', component: () => import('@/views/RegisterView.vue') },
    { path: '/',         name: 'home',     component: () => import('@/views/HomeView.vue'),    meta: { requiresAuth: true } },
    { path: '/artists',  name: 'artists',  component: () => import('@/views/ArtistsView.vue'), meta: { requiresAuth: true } },
  ],
})

// Track whether we've already attempted a silent refresh this page-load.
// Without this, a failed refresh navigates to /login, which re-triggers
// the guard, which calls refresh again — infinite loop.
let bootstrapAttempted = false

router.beforeEach(async (to) => {
  const auth = useAuthStore()

  // Public routes: never touch the guard's refresh logic here.
  if (to.name === 'login' || to.name === 'register') {
    return true
  }

  if (to.meta.requiresAuth && !auth.accessToken) {
    // Only attempt silent refresh once per page load.
    if (!bootstrapAttempted) {
      bootstrapAttempted = true
      const ok = await auth.refresh()
      if (ok) return true
    }
    return { name: 'login' }
  }

  return true
})

export default router
