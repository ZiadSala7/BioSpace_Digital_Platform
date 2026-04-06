# Course transformation (before/after + indicators) — backend specification

This document describes the REST API and persistence model the **Flutter app** uses for the **per-course transformation** screen (نظام التحول): free-text “before/after”, three **0…1** sliders (commitment, consistency, results), and a **0…100** score.

The mobile app **always** mirrors data in **local storage** for offline use, but **reads and writes the server first** when the endpoints below exist. Share this with the backend team. Base URL: `https://bio-space.anmka.com/api` (see `ApiEndpoints.baseUrl`).

**App reference:** `lib/services/course_transformation_service.dart`, `lib/screens/secondary/course_transformation_screen.dart`.

---

## 1. Product rules

1. **Scope**: One transformation record per **authenticated user** per **course** (`course_id`). It is **not** a global/course-wide document.
2. **Auth**: All endpoints require `Authorization: Bearer <token>`.
3. **Enrollment**: Recommended: only users **enrolled** in the course can `GET`/`PUT`/`POST` their transformation for that course.
4. **Score**: The app sends `score` as the average of the three sliders × 100. The server may **recompute and overwrite** `score` from `commitment`, `consistency`, and `results` for consistency.
5. **Timestamps**: Prefer server-side `updated_at` (and `created_at`). The client may send `updated_at`; the server may ignore it or use it only for conflict detection.

---

## 2. Data model (suggested)

### Table: `course_user_transformations` (name flexible)

| Column | Type | Notes |
|--------|------|--------|
| `id` | UUID | Primary key |
| `user_id` | UUID | From JWT |
| `course_id` | UUID | FK → courses |
| `before` | text | Long text OK |
| `after` | text | Long text OK |
| `commitment` | float | **0.0 … 1.0** |
| `consistency` | float | **0.0 … 1.0** |
| `results` | float | **0.0 … 1.0** |
| `score` | float | **0 … 100** (derived or stored) |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

**Unique constraint:** `(user_id, course_id)`.

---

## 3. JSON fields (canonical)

| Field | Type | Required on write | Notes |
|--------|------|-------------------|--------|
| `before` | string | no | Default `""` |
| `after` | string | no | Default `""` |
| `commitment` | number | no | 0…1; coerce/clamp |
| `consistency` | number | no | 0…1 |
| `results` | number | no | 0…1 |
| `score` | number | no | 0…100; optional recompute |
| `updated_at` | string (ISO-8601) | no | Client hint; server may ignore |

**Aliases the app accepts on read** (optional backend convenience):

| Canonical | Aliases |
|-----------|---------|
| `score` | `transformation_score` |

---

## 4. REST endpoints

All paths are under **`/api`**.

### 4.1 Get my transformation for a course

**`GET /courses/:courseId/transformation`**

- **Auth**: required  
- **Behavior**: Return the row for `(current_user, courseId)`. If none exists, respond with **`200`** and empty payload (see below) or **`404`** — the app treats failures as “use local cache only”, so prefer **`200` + empty `data`** for a smooth first-time experience.

**Response envelope** (match existing API style):

**Option A — fields directly under `data`:**

```json
{
  "success": true,
  "data": {
    "before": "…",
    "after": "…",
    "commitment": 0.5,
    "consistency": 0.5,
    "results": 0.5,
    "score": 50,
    "updated_at": "2026-04-05T12:00:00.000Z"
  }
}
```

**Option B — nested under `transformation` (also supported by the app):**

```json
{
  "success": true,
  "data": {
    "transformation": {
      "before": "…",
      "after": "…",
      "commitment": 0.5,
      "consistency": 0.5,
      "results": 0.5,
      "score": 50,
      "updated_at": "2026-04-05T12:00:00.000Z"
    }
  }
}
```

**No record yet:**

```json
{
  "success": true,
  "data": {}
}
```

or

```json
{
  "success": true,
  "data": null
}
```

If `success` is **`false`**, the app does not apply the body and falls back to device cache.

---

### 4.2 Upsert (full replace)

**`PUT /courses/:courseId/transformation`**

- **Auth**: required  
- **Body**: JSON object with the fields in §3 (all optional; missing fields can be treated as empty/zero or left unchanged — document your choice; the app always sends a full snapshot on save).

**Example body:**

```json
{
  "before": "كانت حياتي مليئة بالضغوط",
  "after": "أصبحت أكثر هدوءاً",
  "commitment": 0.72,
  "consistency": 0.65,
  "results": 0.8,
  "score": 72.33333333333333,
  "updated_at": "2026-04-05T12:00:00.000Z"
}
```

**Response:** `200` with same envelope as GET (`data` = saved record).  
**Errors:** `400`, `401`, `403`, `404` (course).

---

### 4.3 Create / upsert (alternate)

**`POST /courses/:courseId/transformation`**

- Same body and semantics as **PUT** (idempotent upsert by `(user_id, course_id)`).  
- The app tries **PUT first**; if that fails (e.g. route not implemented), it retries **POST**.

---

## 5. Progress / dashboard aggregation (optional)

The **progress** screen can show transformation summary if the **user progress** (or similar) payload includes a `transformation` object with the same fields (`before`, `after`, `commitment`, `consistency`, `results`, `score` or `transformation_score`). This is **optional** and independent of the course transformation endpoints above.

---

## 6. Security checklist

- [ ] Bind records to **JWT user id**; never allow setting another user’s `user_id` via body.
- [ ] Enforce **course enrollment** (or your product rules).
- [ ] Validate numeric ranges (0…1 sliders, 0…100 score).
- [ ] Optional: max length on `before` / `after` (e.g. 10 000 chars).

---

## 7. Migration / local cache

The app keeps a **SharedPreferences** copy (`course_transformation_v1:<courseId>`) for offline use. After a successful **GET**, it **overwrites** that cache with the server payload. If the API is not deployed yet, users only see **device-local** data; once **GET** succeeds, server data becomes the source of truth for that session’s load path.
