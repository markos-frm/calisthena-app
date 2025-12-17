# Calisthena MVP v1 — Security + RLS (Frozen)

## Non-negotiable rules
1) Mobile client NEVER has the Supabase service role key.
2) Mobile client NEVER updates ratings/elo directly.
3) Storage bucket `videos` is PRIVATE; playback uses signed URLs from an Edge Function.
4) Pin verification decisions (verified/rejected) happen server-side only.

---

## Secrets placement
### Mobile (.env)
Allowed:
- EXPO_PUBLIC_SUPABASE_URL
- EXPO_PUBLIC_SUPABASE_ANON_KEY

Forbidden in mobile:
- SUPABASE_SERVICE_ROLE_KEY
- OPENAI_API_KEY

### Edge Functions (secrets)
Store as function secrets:
- SUPABASE_SERVICE_ROLE_KEY
- OPENAI_API_KEY

---

## RLS policy intent (high level)

### profiles
- select: any authenticated user
- insert: only self (id = auth.uid())
- update: only self

### ratings_global
- select: any authenticated user
- insert/update/delete: deny to client (server/service role only)

### skills, pins
- select: any authenticated user
- insert/update/delete: deny to client (server only)

### videos
- select: authenticated users can see:
  - status='active' videos
  - and their own videos regardless of status
- insert: only self
- update/delete: only self

### pin_claims
- select: only self (user sees own claims)
- insert: only self (creates claim/pending)
- update: deny to client (server sets verified/rejected + ai_score + decided_at)

### video_likes, video_saves
- select: authenticated users
- insert: only self
- delete: only self

### reports
- insert: authenticated users (reporter_id must match auth.uid())
- select: only reporter (MVP)
- (Admin review later)

---

## Required server-side enforcement (Edge Functions)
Functions MUST enforce:
- verifyPinClaim:
  - evidence_video.user_id == auth.uid()
  - pin exists and active
  - rate limiting (basic)
  - write verified/rejected only from server
  - recompute Elo_v1 deterministically to prevent double-counting

- getSignedVideoUrl:
  - only sign URLs for active videos or owner’s videos

- coachChat:
  - OpenAI key never exposed
  - include injury disclaimer and safe guidance rules

---

## Anti-abuse MVP (minimum)
- Upload cap: <= 30s + file size limit (e.g. 100MB)
- Verify attempts rate limit (e.g. 20/day)
- Reports: allow user to report any video/user
- Future: device fingerprinting / email verification / trust score

