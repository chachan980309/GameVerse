$ErrorActionPreference = 'Stop'

flutter build web --release --no-tree-shake-icons
if ($LASTEXITCODE -ne 0) {
  throw 'Flutter no pudo generar build/web.'
}

# Wrangler lee wrangler.toml y publica exclusivamente build/web.
npx wrangler deploy
