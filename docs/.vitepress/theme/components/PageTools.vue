<script setup lang="ts">
import { computed, ref } from 'vue'
import { useData } from 'vitepress'

const { frontmatter, page } = useData()
const copied = ref(false)
const hidden = computed(() => frontmatter.value.layout === 'home' || frontmatter.value.pageTools === false)

async function copyPage() {
  const text = `${page.value.title}\n\n${window.location.href}`
  await navigator.clipboard.writeText(text)
  copied.value = true
  window.setTimeout(() => (copied.value = false), 1600)
}
</script>

<template>
  <div v-if="!hidden" class="page-tools">
    <span>页面导航</span>
    <button type="button" @click="copyPage" :aria-label="copied ? '已复制' : '复制本页链接'">
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M8 7V5a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2M5 8h9a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2Z" />
      </svg>
      {{ copied ? '已复制' : '复制本页' }}
    </button>
  </div>
</template>
