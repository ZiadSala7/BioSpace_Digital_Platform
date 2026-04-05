# Course API — requested fields (backend)

This document describes new fields the mobile app needs on the **course** resource. Please expose them on course list and course detail responses (and on create/update payloads if courses are edited via API).

---

## Fields

| Field (JSON key)   | Type     | Description |
|--------------------|----------|-------------|
| `start_date`       | DateTime | Scheduled start of the course (or enrollment window start—define per product). |
| `end_date`         | DateTime | Scheduled end of the course (or enrollment window end). |
| `available_seats`  | integer  | Number of seats still open for booking. |
| `booked_seats`     | integer  | Number of seats already booked. |
| `status`           | string   | Enrollment or course availability state. Allowed values: **`open`**, **`closed`**. |

**Dart / client naming (for reference):** `startDate`, `endDate`, `availableSeats`, `bookedSeats`, `status`.

---

## `status` values

| Value    | Meaning (suggested) |
|----------|----------------------|
| `open`   | Course accepts new enrollments (or is within its active window). |
| `closed` | Course does not accept new enrollments (full, ended, or manually closed). |

Use **lowercase** exactly as above so clients can compare without case normalization.

---

## DateTime format

Use **ISO 8601** strings in JSON, with timezone (UTC or explicit offset), for example:

`2026-04-10T09:00:00.000Z`

---

## Example: course JSON fragment

```json
{
  "id": "…",
  "title": "…",
  "start_date": "2026-04-10T09:00:00.000Z",
  "end_date": "2026-06-15T18:00:00.000Z",
  "available_seats": 12,
  "booked_seats": 8,
  "status": "open"
}
```

---

## Suggested consistency rules (optional)

- `available_seats` and `booked_seats` are non-negative integers.
- When `status` is `closed`, `available_seats` may be `0` but the API may still return the last known counts for display.
- If the backend prefers camelCase JSON instead of snake_case, the same semantics apply; the app can map keys accordingly—**please confirm the chosen JSON naming** with the mobile team.

---

## Endpoints to update

At minimum, include these fields wherever a full course object is returned, for example:

- `GET /courses` (and paginated variants)
- `GET /courses/:id`
- Category course listings (e.g. `GET /categories/:id/courses`) if those return course objects

If you use separate “live course” or admin payloads, align field names and types there as well when the same entity is represented.
