import { createClient } from "npm:@supabase/supabase-js@2";
import { AccessToken, RoomServiceClient } from "npm:livekit-server-sdk@2";
let credentialsVerifiedAt = 0;
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
const json = (body: unknown, status = 200) => {
  const responseBody = typeof body === "object" && body !== null
    ? { ...(body as Record<string, unknown>), debug_version: "private-debug-v1" }
    : body;
  return new Response(JSON.stringify(responseBody), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "X-Edge-Version": "private-debug-v1"
    }
  });
};
const decodeJwtPart = (part)=>{
  const normalized = part.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(padded), (character)=>character.charCodeAt(0))));
};
const verifyGeneratedToken = async (token, apiKey, apiSecret, room, identity)=>{
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Generated JWT has an invalid shape");
  const header = decodeJwtPart(parts[0]);
  const claims = decodeJwtPart(parts[1]);
  const video = claims.video;
  const now = Math.floor(Date.now() / 1000);
  if (header.alg !== "HS256") throw new Error("Generated JWT is not HS256");
  if (claims.iss !== apiKey) throw new Error("JWT issuer does not match API key");
  if (claims.sub !== identity) throw new Error("JWT subject does not match authenticated user");
  if (typeof claims.exp !== "number" || claims.exp <= now) {
    throw new Error("JWT expiration is missing or expired");
  }
  if (typeof claims.nbf === "number" && claims.nbf > now + 30) {
    throw new Error("JWT is not valid yet; check server clock");
  }
  if (video?.room !== room || video?.roomJoin !== true || video?.canPublish !== true || video?.canSubscribe !== true) {
    throw new Error("JWT VideoGrant is incomplete");
  }
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(apiSecret), {
    name: "HMAC",
    hash: "SHA-256"
  }, false, [
    "verify"
  ]);
  const signaturePart = parts[2].replace(/-/g, "+").replace(/_/g, "/");
  const paddedSignature = signaturePart.padEnd(Math.ceil(signaturePart.length / 4) * 4, "=");
  const signature = Uint8Array.from(atob(paddedSignature), (character)=>character.charCodeAt(0));
  const signatureValid = await crypto.subtle.verify("HMAC", key, signature, new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  if (!signatureValid) throw new Error("Generated JWT signature is invalid");
  return {
    claims,
    video,
    expiresIn: claims.exp - now
  };
};
Deno.serve(async (req)=>{
  const requestId = crypto.randomUUID();
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") return json({
    error: "Method not allowed"
  }, 405);
  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return json({
        error: "Authentication required"
      }, 401);
    }
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
      global: {
        headers: {
          Authorization: authorization
        }
      }
    });
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return json({
      error: "Invalid session"
    }, 401);

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const body = await req.json();
    const room = typeof body.room === "string" ? body.room.trim() : "";
    if (!room || room.length > 128 || !/^[a-zA-Z0-9_-]+$/.test(room)) {
      return json({
        error: "Invalid room"
      }, 400);
    }
    const roomTypeRaw = typeof body.roomType === "string" ? body.roomType.trim() : "";
    const isLive = roomTypeRaw === "live" || room.startsWith("live-");
    const isPrivateCall = room.startsWith("private_");

    console.log("ROOM:", room);
    console.log("USER:", user.id);
    console.log("isPrivateCall:", room.startsWith("private_"));
    console.log("isLive:", isLive);

    if (isLive) {
      console.log("Entrando en rama live_streams");
      const { data: stream, error: streamError } = await supabase.from("live_streams").select("id").eq("room_name", room).eq("is_live", true).maybeSingle();
      if (streamError || !stream) {
        return json({
          error: "Live stream not found"
        }, 404);
      }
    } else if (isPrivateCall) {
      console.log("[DIAGNOSTIC] --- INICIO DEPURACIÓN EDGE FUNCTION LLAMADAS PRIVADAS ---");
      console.log("[DIAGNOSTIC] Room recibido:", room);
      console.log("[DIAGNOSTIC] User ID recibido:", user.id);

      // Consulta simplificada: Buscar únicamente por room_name
      const { data: allByRoom, error: errorByRoom } = await supabaseAdmin
        .from("voice_channels")
        .select("*")
        .eq("room_name", room);

      console.log("[DIAGNOSTIC] Error consulta básica por room_name:", errorByRoom?.message ?? "ninguno");
      console.log("[DIAGNOSTIC] Cantidad de filas encontradas con ese room_name:", allByRoom?.length ?? 0);

      let foundCall = null;
      if (allByRoom && allByRoom.length > 0) {
        for (const rowObj of allByRoom) {
          console.log("[DIAGNOSTIC] Fila completa de la base de datos:", JSON.stringify(rowObj));
          
          const isPrivateMatch = rowObj.is_private === true;
          const isCreatorMatch = rowObj.created_by === user.id;
          const isInviteeMatch = rowObj.invitee_id === user.id;
          const statusMatch = ["ringing", "accepted"].includes(rowObj.private_status);
          
          console.log(`[DIAGNOSTIC] Evaluación detallada de condiciones para la fila ${rowObj.id}:`);
          console.log(`  - is_private === true? ${isPrivateMatch} (Valor actual: ${rowObj.is_private})`);
          console.log(`  - created_by === user.id? ${isCreatorMatch} (created_by: ${rowObj.created_by}, user.id: ${user.id})`);
          console.log(`  - invitee_id === user.id? ${isInviteeMatch} (invitee_id: ${rowObj.invitee_id}, user.id: ${user.id})`);
          console.log(`  - private_status válido? ${statusMatch} (private_status: ${rowObj.private_status})`);
          
          if (isPrivateMatch && (isCreatorMatch || isInviteeMatch) && statusMatch) {
            foundCall = rowObj;
          }
        }
      }

      if (!foundCall) {
        return json({
          error: `Private call not found or unauthorized (Diagnostics completed, room: ${room}, user: ${user.id})`
        }, 404);
      }
    } else {
      console.log("Entrando en rama voice_channels");
      const { data: channel, error: channelError } = await supabaseAdmin
        .from("voice_channels")
        .select("id, clan_id")
        .eq("room_name", room)
        .eq("is_active", true)
        .maybeSingle();
      if (channelError || !channel) {
        return json({
          error: "Voice channel not found"
        }, 404);
      }

      // Si el canal pertenece a un clan, validar membresía del usuario para evitar IDOR de llamadas grupales
      if (channel.clan_id) {
        const { data: member, error: memberError } = await supabaseAdmin
          .from("clan_members")
          .select("clan_id")
          .eq("clan_id", channel.clan_id)
          .eq("user_id", user.id)
          .maybeSingle();

        if (memberError || !member) {
          return json({
            error: "No estás autorizado para unirte al canal de voz de este clan."
          }, 403);
        }
      }
    }
    const { data: profile } = await supabase.from("profiles").select("username, avatar_url").eq("id", user.id).maybeSingle();
    const requestedUsername = typeof body.username === "string" ? body.username.trim() : "";
    const username = profile?.username?.toString().trim() || requestedUsername || user.email || "Usuario";
    const livekitUrl = Deno.env.get("LIVEKIT_URL");
    const apiKey = Deno.env.get("LIVEKIT_API_KEY");
    const apiSecret = Deno.env.get("LIVEKIT_API_SECRET");
    if (!livekitUrl || !apiKey || !apiSecret) {
      return json({
        error: "LiveKit is not configured"
      }, 500);
    }
    let livekitHost;
    let livekitApiUrl;
    try {
      const parsedUrl = new URL(livekitUrl);
      if (parsedUrl.protocol !== "wss:") throw new Error("LIVEKIT_URL must use wss://");
      livekitHost = parsedUrl.host;
      parsedUrl.protocol = "https:";
      livekitApiUrl = parsedUrl.toString().replace(/\/$/, "");
    } catch (error) {
      return json({
        error: "LiveKit URL is invalid"
      }, 500);
    }
    if (Date.now() - credentialsVerifiedAt > 5 * 60 * 1000) {
      try {
        const roomService = new RoomServiceClient(livekitApiUrl, apiKey, apiSecret);
        await roomService.listRooms();
        credentialsVerifiedAt = Date.now();
      } catch (error) {
        return json({
          error: "LiveKit rejected the configured URL or credentials",
          requestId
        }, 502);
      }
    }
    const accessToken = new AccessToken(apiKey, apiSecret, {
      identity: user.id,
      name: username,
      ttl: "15m",
      metadata: JSON.stringify({
        avatarUrl: profile?.avatar_url?.toString() ?? ""
      })
    });
    accessToken.addGrant({
      room,
      roomJoin: true,
      roomAdmin: false,
      canPublish: true,
      canPublishData: false,
      canSubscribe: true
    });
    const token = await accessToken.toJwt();
    await verifyGeneratedToken(token, apiKey, apiSecret, room, user.id);
    return json({
      token,
      url: livekitUrl
    });
  } catch (error) {
    return json({
      error: "Could not create LiveKit token",
      requestId
    }, 500);
  }
});
