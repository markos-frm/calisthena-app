# Calisthena MVP v1 — Edge Functions Spec (Frozen)

## Principles
- Client NEVER updates Elo directly.
- Video bucket is PRIVATE; playback uses signed URLs.
- Pin verification + Elo update happens server-side only.
- OpenAI key is stored as an Edge Function secret (never in mobile app).

---

## 1) getSignedVideoUrl
Purpose: Return a short-lived signed URL for a private video.

Path: /functions/v1/getSignedVideoUrl  
Auth: Required  
Input JSON:
{
  "video_id": "uuid"
}

Server behavior:
- Fetch video by id.
- Allow if:
  - video.status = 'active' OR video.user_id = caller
- Generate signed URL for videos bucket using storage_path (expiry 60–300s).
- Return url.

Output JSON:
{
  "video_id": "uuid",
  "signed_url": "https://..."
}

Errors:
- 401 unauth
- 403 not allowed
- 404 not found

Notes:
- Implement a batch version if needed later (performance):
  /functions/v1/getSignedVideoUrls { "video_ids": ["uuid", ...] }

---

## 2) verifyPinClaim
Purpose: Verify (stub) a user's claim for a pin using one evidence video, then update Elo_v1.

Path: /functions/v1/verifyPinClaim  
Auth: Required  
Input JSON:
{
  "pin_code": "text",            // e.g. planche_adv_tuck
  "evidence_video_id": "uuid"    // must belong to caller
}

Validation rules:
- evidence video must exist AND belong to caller
- video.duration_seconds <= 30
- pin_code must exist and be active
- enforce 1 claim per (user, pin) (unique constraint exists)
- optional rate limit: max 20 verify attempts/day per user

AI stub behavior (MVP):
- Produce:
  - ai_score: int 0..100
  - ai_reasons: JSON tags + short notes
- Compare ai_score to pin.ai_threshold (default 70)
- Decision:
  - if score >= threshold → VERIFIED
  - else → REJECTED

Writes (transaction):
1) Create pin_claims row if not exists, else reuse existing pending claim:
   - status = 'verified'|'rejected'
   - ai_score, ai_reasons, decided_at
2) If verified:
   - Ensure pin points are applied only once (unique (user_id,pin_id) enforces)
   - Recompute Elo_v1 as:
       elo = 1200 + sum(points of VERIFIED pin_claims for that user)
     and update ratings_global.elo
   - (Alternative acceptable: increment elo by pin.points, but must be consistent and safe.)

Output JSON:
{
  "status": "verified|rejected",
  "ai_score": 0,
  "ai_reasons": { "tags": [], "notes": "" },
  "new_elo": 1200
}

Errors:
- 401 unauth
- 400 invalid input
- 403 evidence not owned
- 409 already verified (if claim exists verified)
- 500 server error

---

## 3) coachChat
Purpose: AI Coach response with personality + safety behavior using user context.

Path: /functions/v1/coachChat  
Auth: Required  
Input JSON:
{
  "message": "text",
  "personality": "motivator|instructor|strict|custom",
  "custom_style": "text optional"
}

Server behavior:
- Load user context from DB:
  - profiles: skill_focus, level, goals, coach_personality/custom_style
  - ratings_global: elo
  - verified pins count per skill
  - optionally most recent uploads count (last 7 days)
- Construct system prompt:
  - tone per personality
  - MUST include injury safety: disclaimer; do not diagnose; suggest medical professional when needed
  - provide actionable training guidance; offer "mini-workout" steps in text
- Call OpenAI and return assistant text.
- Store chat logs (optional in MVP; not required).

Output JSON:
{
  "reply": "text"
}

Errors:
- 401 unauth
- 400 invalid input
- 500 OpenAI error (return friendly message)

---

## 4) (Optional) moderateText
Purpose: moderate user-generated text (captions, chat messages if saved, etc.)

Path: /functions/v1/moderateText  
Auth: Required  
Input JSON:
{ "text": "..." }

Output JSON:
{ "allowed": true, "flags": [] }

Note: For MVP this can be merged into coachChat / upload flow if preferred.

