# Gaze — iOS Social Fashion App

> Share outfits, earn fires, and compete in weekly style challenges.

Gaze is an iOS-only social platform built for fashion-conscious communities. Users post styled outfits, follow friends and creators, react with "fires" (the app's like mechanic), leave comments, save looks, and compete in weekly challenges voted on by the community.

---

## Features

### Core Social
- **Outfit posts** — share photos tagged with style category (streetwear, quiet luxury, vintage, athleisure, and more) and price level ($ → $$$$), with an optional product link
- **Friends feed** — posts from mutual connections only (symmetric follow)
- **Following feed** — posts from everyone you follow (asymmetric)
- **Explore** — trending and discovery feed open to all public posts
- **Fire / save / comment** — engagement actions synced against the Supabase backend in real time

### Social Graph
- **Follow / unfollow** with live count sync across views
- **Friend requests** — send, accept, or decline; accepted requests create a mutual follow
- **Remove friend** — tears down both follow directions with rollback on partial failure
- **Blocking** — hides a blocked user's content across feeds, explore, search, and notifications; fully reversible from Settings

### Profiles
- Avatar upload, display name, bio, city, university
- Style score and challenge wins badge
- Outfit count, follower/following counts sourced from the database (not local arrays)
- Editable profile with save confirmation and rollback on failure

### Weekly Challenges
- Community-voted weekly theme
- Submit an outfit, receive daily finalist placements, vote in finals
- Winners tracked with `challenge_wins` on the profile

### Notifications
- Real-time bell with unread badge
- Types: fires, comments, friend requests, challenge events
- Accept/decline friend requests directly from the notification sheet

### Safety & Settings
- Block/unblock users (block removes mutual follows instantly)
- Notification preferences (links to iOS system settings)
- Terms of Service and Privacy Policy sheets

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI framework | SwiftUI (iOS-only) |
| Architecture | MVVM + Service layer |
| Backend | Supabase (PostgreSQL 17, Auth, Storage) |
| Auth | Supabase Auth → custom username setup flow |
| Image storage | Supabase Storage (`outfit-photos`, `avatars` buckets) |
| Image caching | `URLCache` (64 MB RAM / 512 MB disk) |
| State management | `@StateObject`, `@EnvironmentObject`, `@Published` |
| Config | `SupabaseConfig.plist` (URL + anon key, gitignored) |
| Analytics/crash | Firebase (FirebaseCore) |

---

## Project Structure

```
.
├── Gaze/                          # Xcode project root
│   ├── Gaze.xcodeproj/
│   └── Gaze/                      # Swift source root
│       ├── GazeApp.swift
│       ├── ContentView.swift
│       ├── Components/            # Shared UI components (GazeTabBar, SharedComponents)
│       ├── Design/                # Theme, colors, haptics, animations (GazeTheme)
│       ├── Features/              # One folder per feature module
│       │   ├── Auth/              # Sign-in, sign-up, username setup
│       │   ├── Feed/              # Friends + Following feeds
│       │   ├── Explore/           # Discovery / trending
│       │   ├── Post/              # Create outfit post
│       │   ├── Profile/           # Own profile, edit profile, settings
│       │   ├── Comments/          # Comment thread sheet
│       │   ├── Detail/            # Outfit detail view
│       │   ├── Friends/           # Friends list, friend requests, user search
│       │   ├── Notifications/     # Notification center
│       │   ├── Ranking/           # Leaderboard / style ranking
│       │   ├── Diary/             # Weekly diary flow
│       │   └── Onboarding/        # First-run onboarding
│       ├── Models/                # GazeUser, Outfit, StyleCategory, DBModels, etc.
│       ├── Services/              # SupabaseService, SupabaseManager, StorageService,
│       │   │                      #   ChallengeService, AISearchService, AppLogger
│       │   └── MockDataService.swift
│       └── ViewModels/            # AppViewModel, FeedViewModel, PostViewModel,
│                                  #   ProfileViewModel, ExploreViewModel,
│                                  #   ChallengeViewModel, RankingViewModel
├── supabase/                      # Supabase migration files
│   └── migrations/
├── docs/                          # Engineering documentation and audit logs
├── supabase_schema_live_visualized.sql   # Authoritative live schema snapshot
└── supabase_schema_client.sql            # Historical reference only (outdated)
```

---

## Database Schema

17 tables live in Supabase (PostgreSQL 17):

| Domain | Tables |
|---|---|
| Users | `profiles` |
| Content | `outfits`, `fires`, `comments`, `comment_likes`, `saved_outfits` |
| Social graph | `follows`, `friend_requests`, `blocked_users` |
| Messaging | `notifications` |
| Challenges | `weekly_challenges`, `challenge_submissions`, `challenge_submission_likes`, `challenge_submission_comments`, `challenge_submission_votes`, `challenge_finals_votes`, `challenge_daily_finalists`, `challenge_winners` |

Row-Level Security (RLS) is enabled on all tables. Triggers maintain denormalised counts (`fire_count`, `comment_count`, `outfit_count`, `follower_count`, `following_count`).

---

## Getting Started

### Requirements
- Xcode 16+
- iOS 17+ deployment target
- A Supabase project with the schema from `supabase_schema_live_visualized.sql` applied

### Setup

1. Clone the repo and open `Gaze/Gaze.xcodeproj` in Xcode.

2. Create `Gaze/Gaze/SupabaseConfig.plist` (gitignored) with your Supabase credentials:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>https://your-project.supabase.co</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>your-anon-key</string>
</dict>
</plist>
```

3. Replace `Gaze/Gaze/GoogleService-Info.plist` with your own Firebase config, or remove FirebaseCore from the project if analytics are not needed.

4. Run on a physical device or simulator (iOS 17+).

### Supabase Migrations

```bash
supabase db push
```

Migration files are in `supabase/migrations/`. Apply them in chronological order if pushing manually.

---

## Architecture Notes

- **MVVM** — each feature screen has a dedicated `*ViewModel` that owns network calls and state; views are kept thin
- **Service layer** — `SupabaseService` contains all direct Supabase queries; ViewModels call services, never the Supabase client directly
- **Notification bus** — cross-ViewModel state sync uses `NotificationCenter` with named Gaze events (`gazeFollowStateChanged`, `gazeNewPost`, `gazeUserBlocked`, etc.)
- **Optimistic UI** — follow toggles, fires, and friend actions update local state immediately and roll back on server failure
- **Image uploads** — handled by `StorageService`; path format is `{userId}/{uuid}.jpg` for access-scoped RLS policies

---

## Known Limitations / Post-Launch Work

| Area | Status |
|---|---|
| Pagination / infinite scroll | Not implemented (fixed query limits) |
| Comment deletion UI | Service method ready; no UI yet |
| `get_rankings` RPC | `SECURITY INVOKER` — relies on table RLS being correct |
| `outfits` RLS `outfits_read` policy | Exposes non-`everyone` rows — needs narrowing before scaled launch |
| `notifications` INSERT policy | Permissive `WITH CHECK (true)` — should be restricted to trigger/service-role only |
| Duplicate indexes | `follows`, `fires` have redundant btree indexes (cosmetic, non-blocking) |
| Fire/outfit count triggers | Duplicate triggers cause multi-increment per action — consolidation migration pending |

See `docs/SUPABASE_LAUNCH_REVIEW.md` and `docs/FINAL_QA_GATE.md` for the full pre-launch audit.

---

## Documentation

| File | Contents |
|---|---|
| `docs/00_PROJECT_OVERVIEW.md` | Product summary and engineering objective |
| `docs/01_CLIENT_REQUIREMENTS.md` | Client-requested focus areas |
| `docs/03_TECH_AUDIT.md` | Full P0–P2 bug audit with fixes |
| `docs/05_WORKLOG.md` | Day-by-day engineering log |
| `docs/08_CONFIRMED_BACKEND_REALITY.md` | Authoritative schema source of truth |
| `docs/SUPABASE_LAUNCH_REVIEW.md` | RLS, trigger, and index audit |
| `docs/FINAL_QA_GATE.md` | Manual QA checklist for launch sign-off |
| `docs/LAUNCH_POLISH_CHECKLIST.md` | Full regression and polish checklist |

---

## License

Private / proprietary. All rights reserved.
