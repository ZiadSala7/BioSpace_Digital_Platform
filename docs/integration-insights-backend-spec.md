# Integration insights API — Cosmic Imprint & Color Emotional Analysis

This document defines REST endpoints the **Flutter app** will call for two insight products. Base URL matches the existing API: `https://bio-space.anmka.com/api` (prefix `/api`).

All routes below assume **Bearer authentication** unless noted.

---

## 1. Cosmic Imprint

**Purpose:** Persist user inputs (birth / place / optional chart parameters) and return a structured **interpretive report** (text + optional sections). Exact astrology logic stays on the server.

### 1.1 Get current imprint profile + latest report

**`GET /insights/cosmic-imprint`**

**Response 200** (envelope aligned with your API, e.g. `success` + `data`):

```json
{
  "success": true,
  "data": {
    "inputs": {
      "birth_date": "1990-05-21",
      "birth_time": "14:30",
      "birth_time_unknown": false,
      "birth_place": "Cairo, Egypt",
      "latitude": 30.0444,
      "longitude": 31.2357,
      "timezone": "Africa/Cairo"
    },
    "report": "Plain-language full report (optional if you only use sections).",
    "sections": [
      { "title": "Core imprint", "body": "…", "key": "core" },
      { "title": "Growth edges", "body": "…", "key": "growth" }
    ],
    "metadata": {
      "model_version": "cosmic-v1",
      "computed_at": "2026-04-05T12:00:00.000Z"
    }
  }
}
```

- If the user has **no saved analysis**, return `success: true` with `data: { "inputs": null, "report": null, "sections": [] }` or **404** with a clear `message` — the app handles both.

### 1.2 Submit / refresh analysis

**`POST /insights/cosmic-imprint`**

**Body** (all fields optional except what your product requires; app sends ISO date and optional time/place):

```json
{
  "birth_date": "1990-05-21",
  "birth_time": "14:30",
  "birth_time_unknown": false,
  "birth_place": "Cairo, Egypt",
  "latitude": 30.0444,
  "longitude": 31.2357,
  "timezone": "Africa/Cairo",
  "locale": "ar"
}
```

- **`locale`**: `"ar"` | `"en"` — prefer report language to match app locale.
- Validate ranges; reject impossible dates with **400** and `message`.

**Response 200:** same shape as §1.1 `data` (updated `inputs` + new `report` / `sections`).

**Errors:** 400 validation, 401, 429 rate limit (recommended for heavy compute).

### 1.3 Optional extensions (not required for v1)

- `GET /insights/cosmic-imprint/history` — paginated past reports.
- `DELETE /insights/cosmic-imprint` — user resets stored imprint.

---

## 2. Color Emotional Analysis

**Purpose:** User selects **colors** (and optionally a **mood scale**). Server returns an **emotional / energetic interpretation** tied to those choices.

### 2.1 Get last result + inputs

**`GET /insights/color-emotional`**

**Response 200:**

```json
{
  "success": true,
  "data": {
    "inputs": {
      "selected_colors": ["#7C3AED", "#F59E0B", "#10B981"],
      "mood_scale": 3,
      "notes": null
    },
    "report": "Optional single string summary.",
    "sections": [
      { "title": "Emotional tone", "body": "…", "key": "tone" },
      { "title": "Suggested focus", "body": "…", "key": "focus" }
    ],
    "metadata": {
      "model_version": "color-v1",
      "computed_at": "2026-04-05T12:00:00.000Z"
    }
  }
}
```

Empty state: same pattern as Cosmic (empty `sections` or 404).

### 2.2 Submit analysis

**`POST /insights/color-emotional`**

**Body:**

```json
{
  "selected_colors": ["#7C3AED", "#F59E0B", "#10B981"],
  "mood_scale": 3,
  "notes": "Optional short user note",
  "locale": "ar"
}
```

**Rules (suggested):**

- `selected_colors`: array of **3–7** CSS hex strings (`#RRGGBB`), uppercase or lowercase accepted.
- `mood_scale`: optional integer **1–5** (1 = low / heavy, 5 = high / light — define in your copy).
- `locale`: `"ar"` | `"en"`.

**Response 200:** same as §2.1 `data`.

**Errors:** 400 if too few/many colors or invalid hex.

---

## 3. Shared conventions

1. **Envelope:** Use the same `{ success, message?, data }` pattern as the rest of your API.
2. **Idempotency:** Optional `Idempotency-Key` header on `POST` if you cache by user + payload hash.
3. **Privacy:** Reports may be sensitive — enforce **user-scoped** rows, HTTPS only, and align with your privacy policy.
4. **Localization:** Honor `locale` in `POST` body for generated text; fall back to `Accept-Language` if omitted.
5. **Mobile client paths wired today:**
   - `GET` / `POST` `…/api/insights/cosmic-imprint`
   - `GET` / `POST` `…/api/insights/color-emotional`

If you change paths or field names, notify the app team so `ApiEndpoints` and parsers stay in sync.

---

## 4. Backend checklist

- [ ] `GET` + `POST` `/insights/cosmic-imprint` (auth required)
- [ ] `GET` + `POST` `/insights/color-emotional` (auth required)
- [ ] Validation + error messages for both `POST` bodies
- [ ] Persist per-user latest (and optionally history)
- [ ] Rate limiting / async job if compute is heavy (return `202` + `job_id` only if you extend the contract — not used in v1 client)
- [ ] Document final JSON schema for `sections[].title|body|key`

---

*Document version: 1.0 — Integration insights (Cosmic Imprint + Color Emotional Analysis).*
