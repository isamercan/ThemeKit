// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// GitHub Pages project site: served under https://isamercan.github.io/ThemeKit/
// `base` MUST match the repo name so assets resolve. The Swift DocC API reference
// is deployed alongside this site under /ThemeKit/api/ by the Pages workflow.
export default defineConfig({
  site: 'https://isamercan.github.io',
  base: '/ThemeKit',
  trailingSlash: 'always',
  integrations: [
    starlight({
      title: 'ThemeKit',
      description:
        'A themeable SwiftUI component library — 185 accessible components, design tokens, light/dark, and RTL.',
      tagline: 'Themeable SwiftUI components, built to ship.',
      logo: {
        src: './src/assets/logo.svg',
        replacesTitle: false,
      },
      favicon: '/favicon.svg',
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/isamercan/ThemeKit',
        },
      ],
      editLink: {
        baseUrl: 'https://github.com/isamercan/ThemeKit/edit/main/website/',
      },
      customCss: ['./src/styles/theme.css'],
      components: {
        Footer: './src/components/Footer.astro',
        // Upstream Hero downscales the banner to 400px wide; our override
        // serves it at 1x/2x of its display size so it stays sharp.
        Hero: './src/components/Hero.astro',
      },
      sidebar: [
        {
          label: 'Start Here',
          items: [
            { label: 'Introduction', link: '/' },
            { label: 'Getting Started', link: '/guides/getting-started/' },
            { label: 'Installation', link: '/guides/installation/' },
          ],
        },
        {
          label: 'Guides',
          items: [
            { label: 'Theming', link: '/guides/theming/' },
            { label: 'Customization & Style Protocols', link: '/guides/customization/', badge: { text: 'New', variant: 'success' } },
            { label: 'Accessibility', link: '/guides/accessibility/' },
            { label: 'Form Validation', link: '/guides/form-validation/' },
            { label: 'RTL Support', link: '/guides/rtl/' },
            { label: 'Motion', link: '/guides/motion/' },
          ],
        },
        {
          label: 'MCP Server',
          items: [
            { label: 'Overview', link: '/ai/mcp/', badge: { text: 'AI', variant: 'tip' } },
            { label: 'Design Tokens ⇄ Figma Variables', link: '/ai/figma-variables/', badge: { text: 'New', variant: 'success' } },
          ],
        },
        {
          label: 'Design with AI',
          items: [
            { label: 'DESIGN.md', link: '/ai/design-md/', badge: { text: 'AI', variant: 'tip' } },
          ],
        },
        {
          label: 'Components',
          items: [
            { label: 'Gallery', link: '/components/' },
            { label: 'Atoms', link: '/components/atoms/' },
            { label: 'Molecules', link: '/components/molecules/' },
            { label: 'Organisms', link: '/components/organisms/' },
          ],
        },
        {
          label: 'Design',
          items: [
            { label: 'Design Principles', link: '/design/principles/' },
            { label: 'Feedback Patterns', link: '/design/feedback-patterns/' },
          ],
        },
        {
          label: 'API Reference',
          items: [
            {
              label: 'DocC Reference ↗',
              link: '/api/documentation/themekit/',
              attrs: { target: '_blank', rel: 'noopener' },
              badge: { text: 'Swift', variant: 'note' },
            },
          ],
        },
      ],
    }),
  ],
});
