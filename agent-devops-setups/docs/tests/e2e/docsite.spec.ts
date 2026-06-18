import { test, expect } from '@playwright/test'

const BASE_URL = process.env.BASE_URL || 'http://localhost:4173'

test.describe('agent-devops-setups docs', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(BASE_URL)
  })

  test('homepage loads', async ({ page }) => {
    await expect(page).toHaveTitle(/agent-devops-setups/i)
  })

  for (const route of [
    '/',
    '/architecture',
    '/PLAN',
    '/scope-map',
    '/sessions/',
    '/zh-CN/',
    '/zh-TW/',
    '/fa/',
    '/fa-Latn/',
  ] as const) {
    test(`route ${route} is reachable`, async ({ page }) => {
      await page.goto(`${BASE_URL}${route}`)
      await expect(page.locator('#VPContent')).toBeVisible()
    })
  }
})
