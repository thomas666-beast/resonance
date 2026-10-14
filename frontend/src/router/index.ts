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

router.beforeEach(async (to) => {
  const auth = useAuthStore()

  // CRITICAL: before any decision, make sure the session has been
  // restored at least once this page-load. init() is idempotent.
  if (!auth.initialized) {
    await auth.init()
  }

  // Now accessToken reflects reality.

  // Logged in → keep out of login/register
  if ((to.name === 'login' || to.name === 'register') && auth.accessToken) {
    return { name: 'home' }
  }

  // Not logged in → keep out of protected routes
  if (to.meta.requiresAuth && !auth.accessToken) {
    return { name: 'login' }
  }

  return true
})

export default router
