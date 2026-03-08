const fs = require('node:fs/promises');
const path = require('node:path');

const buildDir = path.resolve(process.cwd(), 'build/web');

const redirects = `/*    /index.html   200
`;

const headers = `/*
  X-Content-Type-Options: nosniff

/index.html
  Cache-Control: public, max-age=0, must-revalidate

/flutter.js
  Cache-Control: public, max-age=0, must-revalidate

/flutter_bootstrap.js
  Cache-Control: public, max-age=0, must-revalidate

/flutter_service_worker.js
  Cache-Control: public, max-age=0, must-revalidate

/main.dart.js
  Cache-Control: public, max-age=0, must-revalidate

/manifest.json
  Cache-Control: public, max-age=0, must-revalidate

/version.json
  Cache-Control: public, max-age=0, must-revalidate

/assets/*
  Cache-Control: public, max-age=31536000, immutable

/icons/*
  Cache-Control: public, max-age=31536000, immutable

/canvaskit/*
  Cache-Control: public, max-age=31536000, immutable

/favicon.png
  Cache-Control: public, max-age=31536000, immutable
`;

const readme = `# Netlify Deploy

This folder is ready to deploy as a Flutter Web SPA on Netlify.

## Manual deploy

1. Open Netlify.
2. Create a new site or open an existing site.
3. Upload the full contents of this folder as the publish directory.

## CLI deploy

\`\`\`bash
netlify deploy --dir=build/web --prod
\`\`\`

## Important files

- \`_redirects\`: sends every route to \`index.html\` so SPA routes do not 404.
- \`_headers\`: applies cache-control rules for HTML, runtime files, assets, fonts, JS, and WASM files.

## Rebuild

\`\`\`bash
npm run netlify:web:build
\`\`\`
`;

async function ensureBuildDir() {
  const stat = await fs.stat(buildDir).catch(() => null);
  if (!stat || !stat.isDirectory()) {
    throw new Error(`Missing build directory: ${buildDir}`);
  }
}

async function main() {
  await ensureBuildDir();

  await fs.writeFile(path.join(buildDir, '_redirects'), redirects, 'utf8');
  await fs.writeFile(path.join(buildDir, '_headers'), headers, 'utf8');
  await fs.writeFile(path.join(buildDir, 'README-NETLIFY.md'), readme, 'utf8');

  console.log('Prepared build/web for Netlify deployment.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
