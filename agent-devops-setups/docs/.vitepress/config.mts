import { defineConfig } from 'vitepress'
import { createSiteMeta } from './site-meta.mjs'

const siteMeta = createSiteMeta()

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: 'agent-devops-setups',
  description: 'Agent devops setups and policy',
  srcDir: '.',
  
  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }]
  ],
  
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Architecture', link: '/architecture' },
      { text: 'Plan', link: '/PLAN' },
      { text: 'Scope Map', link: '/scope-map' },
      { text: 'Sessions', link: '/sessions/' },
      {
        text: 'Languages',
        items: [
          { text: 'English', link: '/' },
          { text: '简体中文', link: '/zh-CN/' },
          { text: '繁體中文', link: '/zh-TW/' },
          { text: 'فارسی', link: '/fa/' },
          { text: 'Farsi (Latin)', link: '/fa-Latn/' }
        ]
      }
    ],
    
    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'Home', link: '/' },
          { text: 'Architecture', link: '/architecture' },
          { text: 'Plan', link: '/PLAN' },
          { text: 'Scope Map', link: '/scope-map' }
        ]
      },
      {
        text: 'Sessions',
        items: [
          { text: 'Session Index', link: '/sessions/' }
        ]
      },
      {
        text: 'Languages',
        items: [
          { text: 'English', link: '/' },
          { text: '简体中文', link: '/zh-CN/' },
          { text: '繁體中文', link: '/zh-TW/' },
          { text: 'فارسی', link: '/fa/' },
          { text: 'Farsi (Latin)', link: '/fa-Latn/' }
        ]
      }
    ],
    
    socialLinks: [
      { icon: 'github', link: 'https://github.com/Phenotype/agent-devops-setups' }
    ],
    
    search: {
      provider: 'local'
    },
    
    footer: {
      message: 'Released under the MIT License.',
      copyright: `Copyright © ${new Date().getFullYear()} Phenotype`
    }
  },
  
  locales: siteMeta.locales
})