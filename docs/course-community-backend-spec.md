# Course wave community (chat) — backend specification

This document describes the REST API and database model the **Flutter mobile app** expects for **per-course, per-wave community discussion** (مجتمع الموجة). The app previously stored messages only on-device; it now calls these endpoints and falls back to local storage if the server is unavailable.

Share this with the backend team. Paths are relative to the existing REST base: `https://bio-space.anmka.com/api` (see `ApiEndpoints.baseUrl` in the app).

---

## 1. Product rules (summary)

1. **Scope**: Messages belong to a **course** and, when the product uses cohorts/waves, optionally to a **`wave_id`**. The app sends `wave_id` when the course payload includes it (`wave_id`, `waveId`, `course_wave_id`, etc.).
2. **Access**: Only **authenticated** users should read or post. Recommended: only users **enrolled** in that course (and wave, if applicable) can access the thread.
3. **Author identity**: The server **must** determine the author from the **JWT** (user id, display name, and whether they are an **instructor** for that course). **Do not trust** client-supplied `sender_role` or impersonation fields for authorization.
4. **Ordering**: Return messages in **chronological order** (oldest first), consistent with the app’s `ListView` + scroll-to-bottom behavior.
5. **Mobile app behavior**: `GET` responses are cached locally for offline display. `POST` failures show a snackbar; the message may still be appended **locally only** until the server exists.

---

## 2. Data model (suggested)

### 2.1 `course_community_messages` (table / collection)

| Field | Type | Notes |
|--------|------|--------|
| `id` | UUID | Primary key |
| `course_id` | UUID | FK → courses |
| `wave_id` | UUID, nullable | When null, thread is “whole course”; when set, thread is **only that wave** |
| `user_id` | UUID | Author (from auth) |
| `body` or `text` | text | Message content; app sends `text`, accepts `text` or `body` in responses |
| `created_at` | timestamp | ISO-8601 UTC recommended |
| `updated_at` | timestamp | Optional |
| `deleted_at` | timestamp, nullable | Soft delete (optional) |

**Indexes (suggested)**

- `(course_id, wave_id, created_at)` for listing.
- Optional unique constraints are **not** required unless you add idempotency keys later.

**Derived / join fields for API responses**

- `sender_name` (string): display name from user profile.
- `sender_role` (string): `"student"` \| `"instructor"` (or `"admin"`) based on your rules.
- The app uses `user_id` on each message to align bubbles on the **right** for the **current user**.

---

## 3. REST endpoints

### 3.1 List messages

**`GET /courses/:courseId/community/messages`**

| Aspect | Detail |
|--------|--------|
| **Auth** | Required (`Authorization: Bearer …`) |
| **Query** | `wave_id` (optional): UUID string; must match scoping rules in §1 |

**Response** (200), same JSON envelope as the rest of your API:

**Option A — `data` is the array** (preferred by the app parser):

```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "text": "Hello",
      "user_id": "uuid",
      "sender_name": "Sara",
      "sender_role": "student",
      "created_at": "2026-04-05T12:00:00.000Z"
    }
  ]
}
```

**Option B — `data.messages`** (also supported):

```json
{
  "success": true,
  "data": {
    "messages": [
      {
        "id": "uuid",
        "text": "Hello",
        "user_id": "uuid",
        "sender_name": "Sara",
        "sender_role": "instructor",
        "created_at": "2026-04-05T12:00:00.000Z"
      }
    ]
  }
}
```

**Field aliases** the app accepts on each message:

| Canonical | Aliases |
|-----------|---------|
| `sender_name` | `senderName` |
| `sender_role` | `senderRole` |
| `text` | `body` |
| `user_id` | `userId` |
| `created_at` | `createdAt` |
| Nested `user.name` | used if `sender_name` is missing |

**Errors**: `401` unauthorized, `403` forbidden (not enrolled), `404` course not found.

---

### 3.2 Post message

**`POST /courses/:courseId/community/messages`**

| Aspect | Detail |
|--------|--------|
| **Auth** | Required |
| **Query** | Optional: same `wave_id` as GET (app may send it only in the JSON body; either is fine if consistent) |

**Body** (JSON):

```json
{
  "text": "Message text",
  "wave_id": "optional-uuid"
}
```

- **`text`** (required): non-empty string after trim; max length at your discretion (e.g. 2000–10000 chars).
- **`wave_id`** (optional): must match GET scoping; server should validate enrollment for that wave when applicable.

**Server responsibilities**

- Set `user_id`, `sender_name`, `sender_role` from the authenticated user and course/instructor relationships.
- Reject empty or whitespace-only `text` with **400**.

**Response** (200/201), envelope:

**Option A — return the created message in `data`:**

```json
{
  "success": true,
  "message": "Created",
  "data": {
    "id": "uuid",
    "text": "Message text",
    "user_id": "uuid",
    "sender_name": "Sara",
    "sender_role": "student",
    "created_at": "2026-04-05T12:01:00.000Z"
  }
}
```

**Option B — success without body**: The app will **`GET` again** after `POST`, so returning only `{ "success": true }` is acceptable as long as `GET` immediately returns the new row.

**Errors**: `400` validation, `401`, `403`, `404`, `413` payload too large.

---

## 4. Consistency with existing course payloads

The app already derives:

- **`wave_id`** for the query/body via `CourseWaveInfo.waveIdFromCourse(course)` (`wave_id`, `waveId`, `course_wave_id`, `courseWaveId`).
- **Local cache key** via `CourseWaveInfo.communityThreadId(course)` when `wave_id` is missing (composite of course id + `start_date`, etc.).  
  The **server** should still prefer a real **`wave_id`** whenever the course has waves.

---

## 5. Security checklist

- [ ] Require auth on both endpoints.
- [ ] Enforce enrollment (and wave membership if you use `wave_id`).
- [ ] Never allow clients to set **`sender_role`** or **`user_id`** for other users.
- [ ] Sanitize or rate-limit `POST` to reduce spam.
- [ ] Optional: moderate/delete APIs for instructors/admins (not required for v1 in the app).

---

## 6. Flutter implementation reference (for alignment)

| Item | Location |
|------|-----------|
| Base paths | `lib/core/api/api_endpoints.dart` → `courseCommunityMessages` |
| HTTP calls | `lib/services/course_community_service.dart` |
| UI | `lib/screens/secondary/course_community_screen.dart` |

---

## 7. Migration note

Users who already have messages in **SharedPreferences** (`course_community_v2:*`) will keep seeing them **only while `GET` fails** (e.g. before the backend is deployed). After `GET` succeeds, the local cache is **replaced** by the server list for that thread key. If you need a one-time import of old device data, that would be a separate product decision (not implemented in the app).
