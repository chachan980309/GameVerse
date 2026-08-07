-- Políticas de Almacenamiento (Storage) para el Bucket de Clanes

-- Permitir lectura pública de objetos en el bucket 'clans'
drop policy if exists "Clans public read" on storage.objects;
create policy "Clans public read"
on storage.objects for select to public
using (bucket_id = 'clans');

-- Permitir a usuarios autenticados subir archivos al bucket 'clans'
drop policy if exists "Clans auth insert" on storage.objects;
create policy "Clans auth insert"
on storage.objects for insert to authenticated
with check (bucket_id = 'clans');

-- Permitir a usuarios autenticados borrar archivos en el bucket 'clans'
drop policy if exists "Clans auth delete" on storage.objects;
create policy "Clans auth delete"
on storage.objects for delete to authenticated
using (bucket_id = 'clans');
