-- El archivo ya está preparado como bucle espejo; actualizar únicamente la
-- referencia permite cambiar el medio sin publicar una nueva versión web.
update public.app_media_config
set storage_path = 'clans/nubzzz-competitive-heart-seamless.mp4',
    updated_at = now()
where key = 'clans_hero_background';
