import { h } from 'vue'
import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import PageTools from './components/PageTools.vue'
import SidebarToggle from './components/SidebarToggle.vue'
import SummaryHero from './components/SummaryHero.vue'
import StatGrid from './components/StatGrid.vue'
import './style.css'

export default {
  extends: DefaultTheme,
  Layout: () =>
    h(DefaultTheme.Layout, null, {
      'nav-bar-title-before': () => h(SidebarToggle),
      'doc-before': () => h(PageTools)
    }),
  enhanceApp({ app }) {
    app.component('SummaryHero', SummaryHero)
    app.component('StatGrid', StatGrid)
  }
} satisfies Theme
