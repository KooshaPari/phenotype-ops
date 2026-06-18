/**
 * Site metadata configuration for agent-devops-setups documentation
 * @returns {Object} Site metadata configuration
 */
export function createSiteMeta() {
  return {
    docsRoot: '/docs/',
    locales: {
      root: {
        label: 'English',
        lang: 'en',
        title: 'agent-devops-setups',
        description: 'Agent devops setups and policy'
      },
      'zh-CN': {
        label: '简体中文',
        lang: 'zh-CN',
        title: 'agent-devops-setups',
        description: '代理 DevOps 设置和政策'
      },
      'zh-TW': {
        label: '繁體中文',
        lang: 'zh-TW',
        title: 'agent-devops-setups',
        description: '代理 DevOps 設置和政策'
      },
      'fa': {
        label: 'فارسی',
        lang: 'fa',
        dir: 'rtl',
        title: 'agent-devops-setups',
        description: 'تنظیمات و سیاست‌های DevOps عامل'
      },
      'fa-Latn': {
        label: 'Farsi (Latin)',
        lang: 'fa-Latn',
        title: 'agent-devops-setups',
        description: 'Agent devops setups and policy (Farsi Latin script)'
      }
    }
  }
}