import { defineConfig } from 'vitepress'

const base = process.env.BASE_PATH || '/'

export default defineConfig({
  lang: 'zh-CN',
  title: '知汇',
  description: '按主题整理 AI、工程与项目实践笔记',
  base,
  cleanUrls: true,
  lastUpdated: true,
  head: [
    ['meta', { name: 'theme-color', content: '#0071e3' }],
    ['meta', { name: 'keywords', content: '知识总结,知识管理,学习笔记,技术文档' }],
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}assets/mark.svg` }]
  ],
  themeConfig: {
    logo: {
      light: '/assets/logo.svg',
      dark: '/assets/logo-dark.svg'
    },
    siteTitle: false,
    nav: [
      { text: '首页', link: '/' },
      { text: 'AI Infra', link: '/ai-infra/' },
      { text: 'Agent 能力', link: '/agents/' },
      { text: '技术棚屋', link: '/shed/projects' },
      {
        text: '简体中文',
        items: [{ text: '简体中文', link: '/' }]
      }
    ],
    sidebar: [
      {
        text: '知识总览',
        collapsed: false,
        items: [
          { text: '分组首页', link: '/' }
        ]
      },
      {
        text: 'AI Infra',
        collapsed: false,
        items: [
          { text: '体系总览', link: '/ai-infra/' },
          { text: '计算、通信与云原生', link: '/ai-infra/compute-network' },
          { text: '训练与推理系统', link: '/ai-infra/training-inference' },
          { text: '模型、数据与应用', link: '/ai-infra/models-data-apps' },
          { text: '算子工程方法', link: '/ai-infra/operator-engineering' }
        ]
      },
      {
        text: 'Agent 能力',
        collapsed: false,
        items: [
          { text: '主题总览', link: '/agents/' },
          { text: '训练、推理与反馈', link: '/agents/training-and-reasoning' },
          { text: 'Prompt 与上下文工程', link: '/agents/prompt-and-context' },
          { text: '研究雷达', link: '/agents/research-radar' }
        ]
      },
      {
        text: '技术棚屋',
        collapsed: false,
        items: [
          { text: '项目与实验', link: '/shed/projects' },
          { text: '工程经验与踩坑', link: '/shed/engineering-notes' }
        ]
      },
      {
        text: '附录',
        collapsed: true,
        items: [
          { text: '内容维护指南', link: '/appendix/maintenance' },
          { text: 'Markdown 组件示例', link: '/appendix/components' },
          { text: '开发守则', link: '/appendix/development-rules' },
          { text: 'Notion 来源索引', link: '/appendix/notion-sources' },
          { text: '来源与许可', link: '/appendix/attribution' }
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
