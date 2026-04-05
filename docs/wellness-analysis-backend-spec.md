# Cosmic Imprint & Color Emotional Analysis — backend API specification

This document defines REST endpoints the **Flutter app** calls for two integrated wellness features:

1. **Cosmic Imprint** — birth-based profile / archetype / “imprint” narrative (your domain logic on the server).  
2. **Color Emotional Analysis** — user-selected colors → emotional spectrum and interpretation.

Base URL (existing convention): `https://bio-space.anmka.com/api`  
All routes below are **relative to `/api`**.

---

## Shared conventions

- **Authentication**: Bearer token required on all routes unless you explicitly ship a public demo (not assumed here).
- **Envelope** (match your existing API):

```json
{
  "success": true,
  "message": "optional",
  "data": { }
}
```

- **Errors**: `success: false`, HTTP 4xx/5xx, `message` human-readable; optional `errors` object for field validation.
- **Localization**: Where both Arabic and English copy exist, use either:
  - paired fields (`summary_ar` / `summary_en`), or  
  - a single `summary` plus `locale` echo, or  
  - `i18n: { "ar": "...", "en": "..." }` — the app can adapt once you document the chosen shape.

---

## 1. Cosmic Imprint

### 1.1 Purpose

Store inputs (birth data, optional place/time) and return a **structured Cosmic Imprint** result for the authenticated user. The app uses this for display and optional re-fetch of the **latest** saved imprint.

### 1.2 Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/wellness/cosmic-imprint` | Latest Cosmic Imprint for the current user. `404` or `success: false` if none. |
| `POST` | `/wellness/cosmic-imprint` | Compute (or queue) imprint from body; persist; return full result. |

You may alternatively use `/analysis/cosmic-imprint` — **must match** what you deploy; the mobile `ApiEndpoints` will be updated to the final path.

### 1.3 `POST` request body (suggested)

All fields optional except what **you** require for your engine (document minimum in your implementation):

```json
{
  "birth_date": "1990-05-20",
  "birth_time": "14:30",
  "birth_timezone": "Africa/Cairo",
  "birth_place_label": "Cairo, Egypt",
  "birth_latitude": 30.0444,
  "birth_longitude": 31.2357,
  "locale": "ar"
}
```

- `birth_date`: ISO date (`YYYY-MM-DD`).  
- `birth_time`: `HH:mm` 24h in the given timezone, or omit if unknown.  
- `locale`: hint for default narrative language (`ar` | `en`).

### 1.4 `POST` / `GET` response `data` (suggested)

Flexible object; the app renders text + maps + lists if present:

```json
{
  "id": "uuid",
  "user_id": "uuid",
  "computed_at": "2026-04-05T12:00:00.000Z",
  "imprint_key": "stellar_seeker",
  "imprint_label_ar": "البصمة الكونية: الباحث",
  "imprint_label_en": "Cosmic Imprint: Seeker",
  "summary_ar": "ملخص قصير…",
  "summary_en": "Short summary…",
  "archetype_key": "seeker",
  "elements": {
    "fire": 0.25,
    "earth": 0.2,
    "air": 0.3,
    "water": 0.25
  },
  "traits": ["intuition", "adaptability", "patience"],
  "scores": {
    "integration": 0.78,
    "expression": 0.62
  },
  "narrative_blocks": [
    {
      "title_ar": "الطاقة الأساسية",
      "title_en": "Core energy",
      "body_ar": "…",
      "body_en": "…"
    }
  ],
  "integration_analysis_ar": "نص تحليل تكاملي اختياري…",
  "integration_analysis_en": "Optional integration narrative…"
}
```

**Integration analysis**: If you expose a dedicated long-form field for “integration” with other app modules (e.g. courses, transformation), use `integration_analysis_*` or a nested `integration: { ... }` and tell the app team the final keys.

---

## 2. Color Emotional Analysis

### 2.1 Purpose

User picks a small ordered set of colors in the app; the server returns **emotional mapping**, scores, and interpretive text.

### 2.2 Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/wellness/color-emotional` | Latest color emotional analysis for the current user. |
| `POST` | `/wellness/color-emotional` | Run analysis for submitted colors; persist; return result. |

Alternative path: `/analysis/color-emotional` (same note as above).

### 2.3 `POST` request body (suggested)

```json
{
  "colors": ["#E53935", "#1E88E5", "#FDD835"],
  "context": "daily_check_in",
  "notes": "optional free text from user",
  "locale": "ar"
}
```

- `colors`: **3–7** hex strings (`#RRGGBB`), order preserved (first = strongest / primary — define in your model).  
- `context`: optional enum string for analytics (`daily_check_in`, `pre_session`, etc.).

### 2.4 `POST` / `GET` response `data` (suggested)

```json
{
  "id": "uuid",
  "user_id": "uuid",
  "computed_at": "2026-04-05T12:00:00.000Z",
  "input_colors": ["#E53935", "#1E88E5", "#FDD835"],
  "dominant_emotions": [
    {
      "key": "calm",
      "score": 0.82,
      "label_ar": "هدوء",
      "label_en": "Calm"
    },
    {
      "key": "hope",
      "score": 0.71,
      "label_ar": "أمل",
      "label_en": "Hope"
    }
  ],
  "emotion_spectrum": {
    "calm": 0.82,
    "energy": 0.45,
    "stress": 0.22
  },
  "interpretation_ar": "شرح المشاعر المرتبطة باختيار الألوان…",
  "interpretation_en": "Interpretation tied to color choice…",
  "integration_notes_ar": "ربط اختياري بمسار التعلم أو التحول",
  "integration_notes_en": "Optional link to learning / transformation journey",
  "suggestions": [
    { "title_ar": "تأمل", "title_en": "Reflection", "body_ar": "…", "body_en": "…" }
  ]
}
```

---

## 3. Privacy & compliance

- Classify birth data and emotional assessments as **sensitive**; apply retention policy and export/delete aligned with your privacy policy.  
- Log only non-identifying metrics if possible.

---

## 4. Mobile client reference

- Service: `WellnessAnalysisService` (`lib/services/wellness_analysis_service.dart`).  
- UI: `WellnessAnalysisScreen` — tabs **Cosmic Imprint** and **Color Emotional**.  
- Endpoints constant (adjust if paths differ):

  - `GET`/`POST` `.../api/wellness/cosmic-imprint`  
  - `GET`/`POST` `.../api/wellness/color-emotional`

---

## 5. Backend checklist

- [ ] `GET`/`POST` Cosmic Imprint (auth, persist, validation).  
- [ ] `GET`/`POST` Color Emotional (validate hex list length, order).  
- [ ] Stable `data` schema or version field (`schema_version: 1`) if you expect breaking changes.  
- [ ] Document required vs optional POST fields and exact error codes.  
- [ ] Confirm JSON field names with the app team if you deviate from this spec.

---

*Document version: 1.0 — Cosmic Imprint & Color Emotional Analysis for BioSpace / Anmka mobile.*
