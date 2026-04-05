# Course waitlist & next-wave enrollment priority — backend specification

This document describes the API and data model the **mobile app (Flutter)** expects so learners can join a **waitlist** when the current **wave** is **full** or **closed**, and receive **enrollment priority** (أولوية) when the **next wave** opens.

Share this with the backend team; paths are relative to the existing REST base: `https://bio-space.anmka.com/api`.

---

## 1. Product rules (summary)

1. **Trigger**: If the user cannot enroll in the **current wave** (capacity full, `status` not `open`, or wave explicitly closed), the app offers **Join waitlist**.
2. **Scope**: Waitlist entries are tied to **`course_id`** and, when the product uses multiple cohorts, **`wave_id`** (current closed wave or the wave the user tried to join).
3. **Next wave**: When a **new wave** is created and enrollment opens, users on the waitlist for that course (and matching wave lineage, if applicable) should be processed **in priority order** (see §4).
4. **Fairness**: Priority is **FIFO by default** (`joined_at` ascending). The app displays a **rank** (1 = highest priority) returned by the API.
5. **Auth**: Join, leave, and “my status” require an authenticated user.

---

## 2. Data model (suggested)

### 2.1 `course_waitlist_entries` (table / collection)

| Field | Type | Notes |
|--------|------|--------|
| `id` | UUID | Primary key |
| `user_id` | UUID | |
| `course_id` | UUID | |
| `wave_id` | UUID, nullable | Target closed wave; if null, “next open wave for this course” |
| `status` | enum | `active`, `invited`, `converted`, `cancelled`, `expired` |
| `priority_rank` | int | 1 = first to be offered next wave seat (computed or stored) |
| `joined_at` | timestamp | Used for ordering |
| `updated_at` | timestamp | |

Unique constraint suggestion: `(user_id, course_id, wave_id)` while `status = active` to avoid duplicates.

### 2.2 Course / wave API payloads (read)

Include user-specific flags on **course detail** and optionally on **course list** when `Authorization` is present:

| Field | Type | Description |
|--------|------|-------------|
| `user_on_waitlist` | boolean | User has an `active` waitlist row for this course/wave |
| `on_waitlist` | boolean | Alias (optional); app accepts either |
| `waitlist_position` | int, optional | 1-based rank among active waiters for next wave |
| `waitlist_rank` | int, optional | Alias for `waitlist_position` |
| `enrollment_priority_rank` | int, optional | Same meaning; alias |
| `waitlist` | object, optional | Nested: `{ "active": true, "position": 3, "wave_id": "..." }` |
| `waitlist_disabled` | boolean, optional | If `true`, app **does not** offer waitlist (admin kill-switch) |
| `waitlist_closed` | boolean, optional | If `true`, waitlist signups closed |

If `waitlist_disabled` / `waitlist_closed` are omitted, the app assumes waitlist is **allowed** whenever enrollment is **not** allowed.

---

## 3. REST endpoints

### 3.1 Join waitlist

**`POST /courses/:courseId/waitlist`**

- **Auth**: Required  
- **Body** (JSON, optional):

```json
{
  "wave_id": "uuid-of-current-or-target-wave"
}
```

- **Behavior**:
  - Validate course exists; current wave is not enrollable OR waitlist is explicitly allowed for full courses.
  - Create `active` entry (or idempotent success if already active).
  - Recompute `priority_rank` / position for the queue.
- **Response** (200), same envelope as rest of API:

```json
{
  "success": true,
  "message": "Joined waitlist",
  "data": {
    "user_on_waitlist": true,
    "on_waitlist": true,
    "waitlist_position": 5,
    "wave_id": "uuid",
    "course_id": "uuid"
  }
}
```

- **Errors**: 400 (validation), 401, 404 (course), 409 (duplicate if not idempotent), 410 (waitlist closed).

---

### 3.2 Leave waitlist

**`DELETE /courses/:courseId/waitlist`**

- **Auth**: Required  
- **Query** (optional): `?wave_id=<uuid>`  
- **Behavior**: Mark user’s active entry `cancelled` (or delete). Optionally shift ranks of others.
- **Response**:

```json
{
  "success": true,
  "data": {
    "user_on_waitlist": false,
    "on_waitlist": false,
    "waitlist_position": null
  }
}
```

---

### 3.3 Get my waitlist status (optional but useful)

**`GET /courses/:courseId/waitlist/me`**

- **Auth**: Required  
- **Query** (optional): `wave_id`  
- **Response**: Same shape as `data` in §3.1, or 404 if not on waitlist.

The app can work **without** this route if the same fields are always returned on **`GET /courses/:courseId`** (detail).

---

## 4. Next wave — priority & enrollment

When **wave N+1** opens:

1. **Notify** users with `status = active` (push/email/in-app — product decision).
2. **Offer enrollment** in **`priority_rank`** order (or `joined_at` FIFO):
   - Option A: Auto-enroll when payment not required (free course).
   - Option B: Send **time-limited checkout link** or in-app “claim seat” for paid courses.
3. On successful enrollment: set waitlist row to `converted` and link `enrollment_id`.
4. If user does not enroll before deadline: `expired` or back to queue (product decision).

The app only needs the API to expose **rank** and **flags**; orchestration stays on the server.

---

## 5. Consistency with existing course fields

Existing wave fields used by the app today:

- `status` / `enrollment_status`: e.g. `open`, `closed`, `full`
- `available_seats`, `booked_seats`, `start_date`, `end_date`, `wave_id`

Waitlist logic on the server should align with the same definition of “cannot enroll” the app uses (`status != open` or no available seats).

---

## 6. Mobile app implementation notes (for backend testing)

- Endpoints wired in the client (subject to your final routing):
  - `POST   /api/courses/:id/waitlist`
  - `DELETE /api/courses/:id/waitlist` (optional `?wave_id=`)
- The client merges `data` from join/leave into the local course map and parses:
  - `user_on_waitlist`, `on_waitlist`, `waitlist_position`, nested `waitlist`

If your paths or names differ, tell the app team once so `ApiEndpoints` and parsers stay aligned.

---

## 7. Checklist for backend delivery

- [ ] `POST /courses/:id/waitlist` with optional `wave_id`
- [ ] `DELETE /courses/:id/waitlist` (+ optional `wave_id`)
- [ ] Course detail (and optionally list) returns waitlist flags + position for logged-in users
- [ ] Unique / idempotent behavior for duplicate join
- [ ] Admin flags `waitlist_disabled` / `waitlist_closed` if needed
- [ ] Job or workflow when new wave opens: priority enrollment + notifications
- [ ] Document actual JSON envelope (`success` / `data` / `message`) to match existing API conventions

---

*Document version: 1.0 — for coordination with Anmka / BioSpace mobile client.*
