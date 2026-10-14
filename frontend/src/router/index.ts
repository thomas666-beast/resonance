import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/login',       name: 'login',    component: () => import('@/views/LoginView.vue') },
    { path: '/register',    name: 'register', component: () => import('@/views/RegisterView.vue') },
    { path: '/',            name: 'home',     component: () => import('@/views/HomeView.vue'),    meta: { requiresAuth: true } },
    { path: '/artists',     name: 'artists',  component: () => import('@/views/ArtistsView.vue'), meta: { requiresAuth: true } },
    { path: '/artists/:id', name: 'artist',   component: () => import('@/views/ArtistView.vue'),  meta: { requiresAuth: true } },
    { path: '/albums/:id',  name: 'album',    component: () => import('@/views/AlbumView.vue'),   meta: { requiresAuth: true } },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()

  if (!auth.initialized) {
    await auth.init()
  }

  if ((to.name === 'login' || to.name === 'register') && auth.accessToken) {
    return { name: 'home' }
  }
  if (to.meta.requiresAuth && !auth.accessToken) {
    return { name: 'login' }
  }
  return true
})

export default router
