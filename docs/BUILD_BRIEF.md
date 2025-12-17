# Calisthena MVP v1 — Build Brief (Frozen)

## Goal
Ship a working MVP that proves the loop:
Onboard → Upload → Feed → Pin verification (AI stub) → Rank update → Profile/Leaderboard → Coach → Repeat

## MVP Skills (expand later)
- planche
- front_lever
- handstand

## MVP Pin Trees (expand later)
Planche: tuck → adv_tuck → straddle → full
Front Lever: tuck → adv_tuck → straddle → full
Handstand: wall_hs → freestanding_hs → hspu

Pin states:
- locked
- pending
- verified (gold)
- rejected

## Upload + Verification Flow (MVP)
- User uploads a video (≤30s) and selects exactly ONE target pin (e.g., planche_adv_tuck).
- Backend runs AI verification (stub v1) and returns:
  - verified (unlock pin), OR rejected (with reason tags), OR pending (optional).
- If verified:
  - pin becomes verified (gold)
  - user rank increases immediately

## Ranking (MVP: stable and shippable)
We display “Elo” in UI, but MVP computation is pin-based.

rank_elo_v1 = 1200 + sum(pin_points for verified pins)

Pin points (v1):
- tuck / wall_hs: +20
- adv_tuck / freestanding_hs: +40
- straddle: +80
- full / hspu: +140

## Feed (MVP)
- Vertical video feed of uploaded videos
- Report button (minimal moderation)
- Likes + Saves included
- Comments excluded (Phase 2)

## Coach (MVP)
- Chat UI
- Personality modes: motivator / instructor / strict / custom
- Uses user context (skills focus, pins earned)
- Injury-safe behavior: disclaimer + conservative advice

## Explicitly Out of Scope (Phase 2+)
- Battles/duels system (mutual agreement challenges)
- Community judging/voting on pins
- Combo verification that unlocks multiple pins at once
- Comments / DMs
- Live workout mode
- Pose/form detection (real vision) — replace stub later

## Success Criteria (MVP)
- User can sign up + onboard
- User can upload ≤30s video and see it in feed
- User can submit pin verification and get verified/rejected response
- Verified pin updates rank and appears on profile
- Leaderboard shows rank ordering correctly
- Coach replies with the selected personality
