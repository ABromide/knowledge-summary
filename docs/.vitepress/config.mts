import { defineConfig } from 'vitepress'

const base = process.env.BASE_PATH || '/'

export default defineConfig({
  lang: 'zh-CN',
  title: '知汇',
  description: '把零散知识沉淀为可复用的认知体系',
  base,
  cleanUrls: true,
  lastUpdated: true,
  head: [
    ['meta', { name: 'theme-color', content: '#0071e3' }],
    ['meta', { name: 'keywords', content: '知识总结,知识管理,学习笔记,技术文档' }],
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}assets/mark.svg` }]
  ],
  themeConfig: {
    logo: '/assets/logo.svg',
    siteTitle: false,
    nav: [
      { text: '首页', link: '/' },
      { text: '知识方法', link: '/methods/capture' },
      { text: '技术专题', link: '/topics/ai-foundation' },
      { text: '阅读笔记', link: '/reading/how-to-read' },
      { text: '实践案例', link: '/cases/project-retro' },
      {
        text: '简体中文',
        items: [{ text: '简体中文', link: '/' }]
      }
    ],
    sidebar: [
      {
        text: '第一章 建立知识系统',
        collapsed: false,
        items: [
          { text: '从零散到体系', link: '/' },
          { text: '知识地图', link: '/guide/knowledge-map' }
        ]
      },
      {
        text: '第二章 捕获与整理',
        collapsed: false,
        items: [
          { text: '高质量捕获', link: '/methods/capture' },
          { text: '渐进式总结', link: '/methods/progressive-summary' }
        ]
      },
      {
        text: '第三章 技术专题',
        collapsed: false,
        items: [
          { text: 'AI 基础认知', link: '/topics/ai-foundation' },
          { text: '前端工程地图', link: '/topics/frontend-map' }
        ]
      },
      {
        text: '第四章 阅读与实践',
        collapsed: false,
        items: [
          { text: '如何做主题阅读', link: '/reading/how-to-read' },
          { text: '项目复盘模板', link: '/cases/project-retro' }
        ]
      },
      {
        text: '附录',
        collapsed: true,
        items: [
          { text: '内容维护指南', link: '/appendix/maintenance' },
          { text: 'Markdown 组件示例', link: '/appendix/components' }
        ]
      }
    ],
    outline: {
      level: [2, 3],
      label: '页面导航'
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/ABromide/knowledge-summary' }
    ],
    editLink: {
      pattern: 'https://github.com/ABromide/knowledge-summary/edit/main/docs/:path',
      text: '在 GitHub 上编辑此页'
    },
    lastUpdated: {
      text: '最后更新于',
      formatOptions: {
        dateStyle: 'medium',
        timeStyle: 'short'
      }
    },
    docFooter: {
      prev: '上一篇',
      next: '下一篇'
    },
    returnToTopLabel: '返回顶部',
    sidebarMenuLabel: '目录',
    darkModeSwitchLabel: '外观',
    lightModeSwitchTitle: '切换到浅色模式',
    darkModeSwitchTitle: '切换到深色模式'
  },
  markdown: {
    theme: { light: 'github-light', dark: 'github-dark' },
    lineNumbers: true
  },
  sitemap: {
    hostname: 'https://abromide.github.io/knowledge-summary/'
  }
})
