<script setup lang="ts">
import { computed, ref } from 'vue'
import { useData } from 'vitepress'

const { frontmatter, page } = useData()
const copyStatus = ref<'idle' | 'copied' | 'failed'>('idle')
const hidden = computed(() => frontmatter.value.layout === 'home' || frontmatter.value.pageTools === false)
const copyLabel = computed(() => {
  if (copyStatus.value === 'copied') return '已复制'
  if (copyStatus.value === 'failed') return '复制失败'
  return '复制本页'
})

async function copyPage() {
  const text = `${page.value.title}\n\n${window.location.href}`
  try {
    await navigator.clipboard.writeText(text)
    copyStatus.value = 'copied'
  } catch {
    copyStatus.value = 'failed'
  }
  window.setTimeout(() => (copyStatus.value = 'idle'), 1600)
}
</script>

<template>
  <div v-if="!hidden" class="page-tools">
    <span class="page-tools__context">知识条目</span>
    <button type="button" @click="copyPage" :aria-label="copyLabel">
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M8 7V5a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2M5 8h9a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2Z" />
      </svg>
      {{ copyLabel }}
    </button>
    <span class="page-tools__feedback" aria-live="polite">{{ copyStatus === 'idle' ? '' : copyLabel }}</span>
  </div>
</template>
