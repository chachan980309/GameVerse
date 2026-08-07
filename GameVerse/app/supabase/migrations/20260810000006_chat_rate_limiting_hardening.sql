-- Hardening de Seguridad Anti-Spam / Anti-Flood para Mensajería de GameVerse

-- 1. Crear la función unificada de Rate-Limiting para Inserciones de Mensajes
create or replace function public.check_message_rate_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_message_count integer;
  v_limit_window interval := interval '3 seconds';
  v_max_messages integer := 5;
begin
  -- Excluir al rol de servicio (service_role) o procesos internos de sistema de los rate limits
  if (current_setting('role') = 'service_role') then
    return new;
  end if;

  -- Contar los mensajes recientes del usuario según la tabla origen del trigger
  if (tg_table_name = 'clan_messages') then
    select count(*) into v_message_count 
    from public.clan_messages 
    where sender_id = auth.uid() and created_at > now() - v_limit_window;
  elsif (tg_table_name = 'direct_messages') then
    select count(*) into v_message_count 
    from public.direct_messages 
    where sender_id = auth.uid() and created_at > now() - v_limit_window;
  elsif (tg_table_name = 'voice_channel_messages') then
    select count(*) into v_message_count 
    from public.voice_channel_messages 
    where user_id = auth.uid() and created_at > now() - v_limit_window;
  end if;

  -- Si el usuario excede la cuota de inundación (5 mensajes en 3 segundos), bloqueamos la inserción
  if coalesce(v_message_count, 0) >= v_max_messages then
    raise exception 'Filtro Anti-Spam: Has excedido el límite de 5 mensajes en 3 segundos. Por favor, espera antes de enviar más.' USING ERRCODE = '42501';
  end if;

  return new;
end;
$$;

-- 2. Instalar el Trigger BEFORE INSERT en la tabla de Mensajes Privados (direct_messages)
drop trigger if exists check_direct_messages_rate_limit_trigger on public.direct_messages;
create trigger check_direct_messages_rate_limit_trigger
before insert on public.direct_messages
for each row execute function public.check_message_rate_limit();

-- 3. Instalar el Trigger BEFORE INSERT en la tabla de Mensajes de Clanes (clan_messages)
drop trigger if exists check_clan_messages_rate_limit_trigger on public.clan_messages;
create trigger check_clan_messages_rate_limit_trigger
before insert on public.clan_messages
for each row execute function public.check_message_rate_limit();

-- 4. Instalar el Trigger BEFORE INSERT en la tabla de Mensajes de Canales de Voz (voice_channel_messages)
drop trigger if exists check_voice_channel_messages_rate_limit_trigger on public.voice_channel_messages;
create trigger check_voice_channel_messages_rate_limit_trigger
before insert on public.voice_channel_messages
for each row execute function public.check_message_rate_limit();
