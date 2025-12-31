# DataBar Brochure Website

Marketing website for the DataBar macOS application.

## Development

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

The build output will be in the `dist/` directory.

## Deployment

This site is automatically deployed to GitHub Pages when changes are pushed to the `main` branch. The deployment workflow is defined in `.github/workflows/pages.yml`.

The site will be available at: `https://sammarks.github.io/DataBar/`

## Stack

- React 19
- TypeScript
- Vite
- React Router (HashRouter for GitHub Pages compatibility)
