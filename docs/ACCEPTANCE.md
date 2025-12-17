# Calisthena MVP v1 — Acceptance Checklist (Definition of Done)

## 1) Repo + setup
- [ ] Repo has docs/BUILD_BRIEF.md, docs/DB_SCHEMA.sql, docs/EDGE_FUNCTIONS.md, docs/SECURITY_RLS.md, docs/ACCEPTANCE.md
- [ ] No secrets committed (no .env with real keys)
- [ ] App runs on iOS simulator from a clean install

## 2) Auth + onboarding
- [ ] User can sign up and log in (Supabase Auth)
- [ ] Session persists after app restart
- [ ] Onboarding captured: skill_focus (1–3), level, goals, coach personality
- [ ] User can edit coach personality in Settings

## 3) Upload + feed
- [ ] User can upload a video <= 30 seconds
- [ ] App blocks videos > 30 seconds with a clear message
- [ ] Upload shows progress and success state
- [ ] Uploaded video appears in feed within 10 seconds
- [ ] Feed plays videos reliably (no blank player, no crashing)
- [ ] Report action exists on a video

## 4) Private video access
- [ ] Videos bucket is private in Supabase
- [ ] Playback works via signed URLs from getSignedVideoUrl (not public URLs)
- [ ] User cannot access another user's hidden/removed video

## 5) Pins (skill tree)
- [ ] Pins screen displays 3 skill trees (planche, front_lever, handstand)
- [ ] Pins show correct states:
  - locked (default)
  - pending (after claim)
  - verified (after success)
  - rejected (after failure)

## 6) Pin verification flow
- [ ] User selects exactly ONE target pin and submits evidence video
- [ ] verifyPinClaim returns: verified OR rejected, with ai_score + reason tags
- [ ] If verified:
  - pin changes to verified (gold)
  - pin cannot be re-claimed again (unique constraint holds)
- [ ] If rejected:
  - user can re-attempt (new evidence video) OR gets a clear message why
  - rejected claim is visible to user

## 7) Ranking (Elo_v1 pin-based)
- [ ] Profile shows “Elo” number
- [ ] Elo formula is consistent:
  elo = 1200 + sum(points for VERIFIED pins)
- [ ] After a verified pin, Elo increases immediately and matches expected points
- [ ] Leaderboard orders users correctly by Elo descending

## 8) Likes + saves
- [ ] User can like/unlike a video
- [ ] User can save/unsave a video
- [ ] Likes and saves persist after restart

## 9) AI Coach
- [ ] Coach chat responds within reasonable time (dev environment)
- [ ] Personality modes change tone (motivator/instructor/strict/custom)
- [ ] Injury messages trigger a safety disclaimer and conservative advice
- [ ] Coach uses user context (mentions skill focus or current level/pins)

## 10) Security checks (basic)
- [ ] Client cannot modify ratings_global.elo via direct Supabase calls
- [ ] Client cannot set pin_claims.status to verified directly
- [ ] Service role key and OpenAI key are not present in client bundle
- [ ] RLS is enabled on all public tables

