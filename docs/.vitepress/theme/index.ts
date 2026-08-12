import { h } from 'vue'
import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import PageTools from './components/PageTools.vue'
import SidebarToggle from './components/SidebarToggle.vue'
import SummaryHero from './components/SummaryHero.vue'
import StatGrid from './components/StatGrid.vue'
import InteractiveFlow from './components/InteractiveFlow.vue'
import CapacityLab from './components/CapacityLab.vue'
import TradeoffExplorer from './components/TradeoffExplorer.vue'
import TopologyExplorer from './components/TopologyExplorer.vue'
import ResearchWorkbench from './components/ResearchWorkbench.vue'
import ZoomableImage from './components/ZoomableImage.vue'
import PaperCatalog from './components/PaperCatalog.vue'
import PaperPageNavigator from './components/PaperPageNavigator.vue'
import './style.css'

function scrollToRouteAnchor(href: string) {
  if (typeof window === 'undefined') return

  const hash = new URL(href, window.location.origin).hash
  if (!hash) return

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      const target = document.getElementById(decodeURIComponent(hash.slice(1)))
      if (!target) return

      let cancelled = false
      const align = () => {
        if (cancelled) return
        requestAnimationFrame(() => {
          if (!cancelled) target.scrollIntoView({ block: 'start' })
        })
      }
      const cancel = () => {
        cancelled = true
        window.removeEventListener('wheel', cancel)
        window.removeEventListener('touchstart', cancel)
        window.removeEventListener('keydown', cancel)
      }

      target.scrollIntoView({ block: 'start' })
      target.focus({ preventScroll: true })
      window.addEventListener('wheel', cancel, { passive: true })
      window.addEventListener('touchstart', cancel, { passive: true })
      window.addEventListener('keydown', cancel)

      const imagesBeforeTarget = [...document.querySelectorAll<HTMLImageElement>('.vp-doc img')]
        .filter((image) => image.compareDocumentPosition(target) & Node.DOCUMENT_POSITION_FOLLOWING)
      imagesBeforeTarget.forEach((image) => {
        if (image.complete) return
        image.addEventListener('load', align, { once: true })
        image.addEventListener('error', align, { once: true })
      })
      document.fonts?.ready.then(align)
      window.setTimeout(cancel, 2000)
    })
  })
}

export default {
  extends: DefaultTheme,
  Layout: () =>
    h(DefaultTheme.Layout, null, {
      'nav-bar-title-before': () => h(SidebarToggle),
      'doc-before': () => h(PageTools)
    }),
  enhanceApp({ app, router }) {
    app.component('SummaryHero', SummaryHero)
    app.component('StatGrid', StatGrid)
    app.component('InteractiveFlow', InteractiveFlow)
    app.component('CapacityLab', CapacityLab)
    app.component('TradeoffExplorer', TradeoffExplorer)
    app.component('TopologyExplorer', TopologyExplorer)
    app.component('ResearchWorkbench', ResearchWorkbench)
    app.component('ZoomableImage', ZoomableImage)
    app.component('PaperCatalog', PaperCatalog)
    app.component('PaperPageNavigator', PaperPageNavigator)

    const previousAfterRouteChange = router.onAfterRouteChange
    router.onAfterRouteChange = async (to) => {
      await previousAfterRouteChange?.(to)
      scrollToRouteAnchor(to)
    }
  }
} satisfies Theme
