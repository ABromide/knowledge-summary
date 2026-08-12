<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

interface PaperHeading {
  id: string
  title: string
}

const headings = ref<PaperHeading[]>([])
const activeId = ref('')
const progress = ref(0)
let headingElements: HTMLHeadingElement[] = []
let frame = 0

const activeIndex = computed(() => {
  const index = headings.value.findIndex((heading) => heading.id === activeId.value)
  return index < 0 ? 0 : index
})

const activeTitle = computed(() => headings.value[activeIndex.value]?.title ?? '准备阅读')

function formatIndex(index: number) {
  return String(index + 1).padStart(2, '0')
}

function collectHeadings() {
  headingElements = [...document.querySelectorAll<HTMLHeadingElement>('.VPDoc .vp-doc > div > h2[id]')]
  headings.value = headingElements.map((heading) => ({
    id: heading.id,
    title: heading.textContent?.replaceAll('\u200B', '').trim() || heading.id
  }))
  activeId.value = headingElements[0]?.id ?? ''
  updatePosition()
}

function updatePosition() {
  frame = 0
  if (headingElements.length === 0) return

  const marker = Math.min(window.innerHeight * 0.28, 180)
  let active = headingElements[0]
  for (const heading of headingElements) {
    if (heading.getBoundingClientRect().top > marker) break
    active = heading
  }
  activeId.value = active.id

  const article = document.querySelector<HTMLElement>('.VPDoc .vp-doc')
  if (!article) return
  const articleStart = window.scrollY + article.getBoundingClientRect().top
  const articleRange = Math.max(article.scrollHeight - window.innerHeight, 1)
  progress.value = Math.min(100, Math.max(0, ((window.scrollY - articleStart) / articleRange) * 100))
}

function schedulePositionUpdate() {
  if (frame) return
  frame = window.requestAnimationFrame(updatePosition)
}

onMounted(async () => {
  await nextTick()
  window.requestAnimationFrame(collectHeadings)
  window.addEventListener('scroll', schedulePositionUpdate, { passive: true })
  window.addEventListener('resize', schedulePositionUpdate, { passive: true })
})

onBeforeUnmount(() => {
  if (frame) window.cancelAnimationFrame(frame)
  window.removeEventListener('scroll', schedulePositionUpdate)
  window.removeEventListener('resize', schedulePositionUpdate)
})
</script>

<template>
  <nav id="paper-page-navigation" class="paper-page-navigator" aria-label="本页主题导航">
    <header class="paper-page-navigator__header">
      <div>
        <span>页内导航</span>
        <strong>沿主题阅读</strong>
        <p>选择条目直接定位；滚动时会同步显示当前主题与阅读进度。</p>
      </div>
      <div class="paper-page-navigator__status" aria-live="polite">
        <span>{{ formatIndex(activeIndex) }} / {{ String(headings.length).padStart(2, '0') }}</span>
        <strong>{{ activeTitle }}</strong>
      </div>
    </header>
    <div class="paper-page-navigator__progress" aria-hidden="true">
      <span :style="{ width: `${progress}%` }" />
    </div>
    <div class="paper-page-navigator__list">
      <a
        v-for="(heading, index) in headings"
        :key="heading.id"
        :href="`#${heading.id}`"
        :aria-current="activeId === heading.id ? 'location' : undefined"
        @click="activeId = heading.id"
      >
        <span>{{ formatIndex(index) }}</span>
        <strong>{{ heading.title }}</strong>
      </a>
    </div>
  </nav>
</template>
