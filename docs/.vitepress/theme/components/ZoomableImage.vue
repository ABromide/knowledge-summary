<script setup lang="ts">
import { computed, ref } from 'vue'
import { withBase } from 'vitepress'

const props = defineProps<{ src: string; alt: string }>()

const dialog = ref<HTMLDialogElement | null>(null)
const zoom = ref(1)
const resolvedSrc = computed(() => withBase(props.src))

function open() {
  zoom.value = 1
  dialog.value?.showModal()
}

function close() {
  dialog.value?.close()
  zoom.value = 1
}

function adjust(delta: number) {
  zoom.value = Math.min(3, Math.max(0.75, Number((zoom.value + delta).toFixed(2))))
}
</script>

<template>
  <figure class="zoomable-image">
    <button type="button" class="zoomable-image__trigger" :aria-label="`放大查看：${alt}`" @click="open">
      <img :src="resolvedSrc" :alt="alt" loading="lazy" />
      <span aria-hidden="true">点击放大</span>
    </button>
    <figcaption>{{ alt }}</figcaption>
    <dialog ref="dialog" class="zoomable-image__dialog" @click.self="close" @cancel="zoom = 1">
      <header>
        <strong>{{ alt }}</strong>
        <button type="button" aria-label="关闭图片预览" @click="close">关闭</button>
      </header>
      <div class="zoomable-image__viewport">
        <img :src="resolvedSrc" :alt="alt" :style="{ transform: `scale(${zoom})` }" />
      </div>
      <footer>
        <button type="button" :disabled="zoom <= 0.75" @click="adjust(-0.25)">缩小</button>
        <output aria-live="polite">{{ Math.round(zoom * 100) }}%</output>
        <button type="button" :disabled="zoom >= 3" @click="adjust(0.25)">放大</button>
        <button type="button" @click="zoom = 1">还原</button>
      </footer>
    </dialog>
  </figure>
</template>
