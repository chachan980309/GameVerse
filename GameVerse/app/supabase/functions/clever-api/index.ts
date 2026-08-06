import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

let accessToken = ''
let tokenExpiresAt = 0

async function getAccessToken() {
  if (accessToken && Date.now() < tokenExpiresAt) return accessToken
  const clientId = Deno.env.get('TWITCH_CLIENT_ID')
  const clientSecret = Deno.env.get('TWITCH_CLIENT_SECRET')
  if (!clientId || !clientSecret) throw new Error('Faltan las credenciales de Twitch.')

  const response = await fetch('https://id.twitch.tv/oauth2/token', {
    method: 'POST',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: new URLSearchParams({client_id: clientId, client_secret: clientSecret, grant_type: 'client_credentials'}),
  })
  if (!response.ok) throw new Error('No se pudo autenticar con IGDB.')
  const data = await response.json()
  accessToken = data.access_token
  tokenExpiresAt = Date.now() + (data.expires_in - 60) * 1000
  return accessToken
}

serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders})
  try {
    const {query} = await request.json()
    const search = String(query ?? '').trim()
    if (search.length < 2) return Response.json({games: []}, {headers: corsHeaders})

    const token = await getAccessToken()
    const safeSearch = search.replace(/["\\]/g, ' ')
    const response = await fetch('https://api.igdb.com/v4/games', {
      method: 'POST',
      headers: {'Client-ID': Deno.env.get('TWITCH_CLIENT_ID')!, Authorization: `Bearer ${token}`, 'Content-Type': 'text/plain'},
      body: `search "${safeSearch}"; fields id,name,cover.url,artworks.url,artworks.width,artworks.height,screenshots.url,screenshots.width,screenshots.height,videos.video_id,platforms.name; limit 8;`,
    })
    if (!response.ok) throw new Error('IGDB no pudo buscar los juegos.')
    const results = await response.json()
    const games = results.map((game: any) => ({
      id: game.id,
      name: game.name,
      cover_url: game.cover?.url ? game.cover.url : null,
      artworks: (game.artworks ?? []).map((art: any) => ({
        url: art.url,
        width: art.width,
        height: art.height
      })),
      screenshots: (game.screenshots ?? []).map((sc: any) => ({
        url: sc.url,
        width: sc.width,
        height: sc.height
      })),
      videos: (game.videos ?? []).map((v: any) => v.video_id),
      platforms: (game.platforms ?? []).map((platform: any) => platform.name).filter(Boolean),
    }))
    return Response.json({games}, {headers: corsHeaders})
  } catch (error) {
    return Response.json({error: error instanceof Error ? error.message : 'Error al buscar.'}, {status: 500, headers: corsHeaders})
  }
})
