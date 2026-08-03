import { createClient } from "npm:@supabase/supabase-js@2";
import {
  AccessToken,
  RoomServiceClient,
} from "npm:livekit-server-sdk@2";

let credentialsVerifiedAt = 0;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const decodeJwtPart = (part: string) => {
  const normalized = part.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return JSON.parse(new TextDecoder().decode(
    Uint8Array.from(atob(padded), (character) => character.charCodeAt(0)),
  )) as Record<string, unknown>;
};

const verifyGeneratedToken = async (
  token: string,
  apiKey: string,
  apiSecret: string,
  room: string,
  identity: string,
) => {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Generated JWT has an invalid shape");
  const header = decodeJwtPart(parts[0]);
  const claims = decodeJwtPart(parts[1]);
  const video = claims.video as Record<string, unknown> | undefined;
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
  if (video?.room !== room || video?.roomJoin !== true ||
      video?.canPublish !== true || video?.canSubscribe !== true) {
    throw new Error("JWT VideoGrant is incomplete");
  }
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(apiSecret),
    { name: "HMAC", hash: "SHA-256" }, false, ["verify"],
  );
  const signaturePart = parts[2].replace(/-/g, "+").replace(/_/g, "/");
  const paddedSignature = signaturePart.padEnd(
    Math.ceil(signaturePart.length / 4) * 4, "=",
  );
  const signature = Uint8Array.from(
    atob(paddedSignature), (character) => character.charCodeAt(0),
  );
  const signatureValid = await crypto.subtle.verify(
    "HMAC", key, signature,
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!signatureValid) throw new Error("Generated JWT signature is invalid");
  return { claims, video, expiresIn: (claims.exp as number) - now };
};

Deno.serve(async (req: Request) => {
  const requestId = crypto.randomUUID();
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return json({ error: "Authentication required" }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return json({ error: "Invalid session" }, 401);

    const body = await req.json() as {
      room?: unknown;
      userId?: unknown;
      username?: unknown;
    };
    const room = typeof body.room === "string" ? body.room.trim() : "";
    if (!room || room.length > 128 || !/^[a-zA-Z0-9_-]+$/.test(room)) {
      console.warn("livekit-token invalid room", { requestId, room });
      return json({ error: "Invalid room" }, 400);
    }

    const { data: channel, error: channelError } = await supabase
      .from("voice_channels")
      .select("id")
      .eq("room_name", room)
      .eq("is_active", true)
      .maybeSingle();
    if (channelError || !channel) {
      return json({ error: "Voice channel not found" }, 404);
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("username, avatar_url")
      .eq("id", user.id)
      .maybeSingle();
    const requestedUsername = typeof body.username === "string"
      ? body.username.trim()
      : "";
    const username = profile?.username?.toString().trim() ||
      requestedUsername || user.email || "Usuario";

    const livekitUrl = Deno.env.get("LIVEKIT_URL");
    const apiKey = Deno.env.get("LIVEKIT_API_KEY");
    const apiSecret = Deno.env.get("LIVEKIT_API_SECRET");
    if (!livekitUrl || !apiKey || !apiSecret) {
      console.error("livekit-token missing configuration", {
        requestId,
        hasUrl: Boolean(livekitUrl),
        hasApiKey: Boolean(apiKey),
        hasApiSecret: Boolean(apiSecret),
      });
      return json({ error: "LiveKit is not configured" }, 500);
    }

    let livekitHost: string;
    let livekitApiUrl: string;
    try {
      const parsedUrl = new URL(livekitUrl);
      if (parsedUrl.protocol !== "wss:") throw new Error("LIVEKIT_URL must use wss://");
      livekitHost = parsedUrl.host;
      parsedUrl.protocol = "https:";
      livekitApiUrl = parsedUrl.toString().replace(/\/$/, "");
    } catch (error) {
      console.error("livekit-token invalid URL", {
        requestId,
        error: error instanceof Error ? error.message : String(error),
      });
      return json({ error: "LiveKit URL is invalid" }, 500);
    }

    if (Date.now() - credentialsVerifiedAt > 5 * 60 * 1000) {
      try {
        const roomService = new RoomServiceClient(
          livekitApiUrl,
          apiKey,
          apiSecret,
        );
        await roomService.listRooms();
        credentialsVerifiedAt = Date.now();
        console.info("livekit-token credentials accepted by LiveKit", {
          requestId,
          livekitHost,
          apiKeySuffix: apiKey.slice(-4),
        });
      } catch (error) {
        console.error("livekit-token credentials rejected by LiveKit", {
          requestId,
          livekitHost,
          apiKeySuffix: apiKey.slice(-4),
          error: error instanceof Error ? error.message : String(error),
          stack: error instanceof Error ? error.stack : undefined,
        });
        return json({
          error: "LiveKit rejected the configured URL or credentials",
          requestId,
        }, 502);
      }
    }

    const accessToken = new AccessToken(apiKey, apiSecret, {
      identity: user.id,
      name: username,
      ttl: "15m",
      metadata: JSON.stringify({
        avatarUrl: profile?.avatar_url?.toString() ?? "",
      }),
    });
    accessToken.addGrant({
      room,
      roomJoin: true,
      roomAdmin: false,
      canPublish: true,
      canPublishData: false,
      canSubscribe: true,
    });

    const token = await accessToken.toJwt();
    const validation = await verifyGeneratedToken(
      token, apiKey, apiSecret, room, user.id,
    );
    console.info("livekit-token generated", {
      requestId,
      livekitHost,
      apiKeySuffix: apiKey.slice(-4),
      room,
      identity: user.id,
      roomJoin: validation.video?.roomJoin,
      canPublish: validation.video?.canPublish,
      canSubscribe: validation.video?.canSubscribe,
      expiresInSeconds: validation.expiresIn,
      signatureVerified: true,
    });
    return json({ token, url: livekitUrl });
  } catch (error) {
    console.error("livekit-token failed", {
      requestId,
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    return json({ error: "Could not create LiveKit token", requestId }, 500);
  }
});
