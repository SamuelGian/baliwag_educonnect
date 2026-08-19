# API Integration Documentation — Weather Advisory (Week 5)

## API Name
**Open-Meteo** — a free, keyless weather and geocoding API.
https://open-meteo.com/en/docs

No API key or registration is required, so the feature works immediately for anyone who clones the project (unlike the OCR.space integration already in this app, which needs a personal key in `lib/config/secrets.dart`).

## API Endpoint(s) Used

1. **Forecast endpoint** — current conditions + today's min/max for a given coordinate:
   ```
   GET https://api.open-meteo.com/v1/forecast
       ?latitude=14.9563&longitude=120.8967
       &current=temperature_2m,relative_humidity_2m,weather_code,is_day
       &daily=temperature_2m_max,temperature_2m_min
       &timezone=Asia/Manila
       &forecast_days=1
   ```

2. **Geocoding endpoint** — looks up latitude/longitude for a city/municipality name the student types in:
   ```
   GET https://geocoding-api.open-meteo.com/v1/search
       ?name=Malolos&count=6&language=en&format=json
   ```

Both are plain HTTP GET requests returning JSON, called with the `http` package already used elsewhere in the project (see `lib/services/ocr_service.dart` for the existing pattern this follows).

## Sample JSON Response

**Forecast endpoint:**
```json
{
  "latitude": 14.96,
  "longitude": 120.9,
  "current": {
    "time": "2026-08-11T14:00",
    "temperature_2m": 31.4,
    "relative_humidity_2m": 74,
    "weather_code": 80,
    "is_day": 1
  },
  "daily": {
    "time": ["2026-08-11"],
    "temperature_2m_max": [32.1],
    "temperature_2m_min": [24.6]
  }
}
```

**Geocoding endpoint** (trimmed):
```json
{
  "results": [
    {
      "name": "Malolos",
      "admin1": "Central Luzon",
      "country": "Philippines",
      "latitude": 14.84,
      "longitude": 120.81
    }
  ]
}
```

## Explanation of Integration — Why This API Fits EduConnect

Baliwag EduConnect's scholarship workflow is not purely digital: applicants still need to travel to get a **Barangay Certificate of Residency**, submit requirements at the **City Scholarship Office**, or attend **scholar orientation at the Baliwag Bayan Hall** (see the seeded announcements in `lib/data/app_state.dart`). A sudden downpour on a submission day is a real, recurring obstacle for these trips.

The **Weather Advisory** card on the Student Dashboard shows live conditions for Baliwag (default) or any other city/municipality the student is about to visit, and gives a plain-language recommendation:

- Rain-risk conditions → reminder to bring an umbrella and keep documents in a sealed folder.
- Clear conditions → no advisory shown, since there's nothing to warn about.

This directly supports the app's core purpose (getting physical requirements submitted successfully) rather than being a generic, bolted-on widget.

### Where it lives in the code
| File | Role |
|---|---|
| `lib/models/weather.dart` | `WeatherSnapshot`, `GeoLocation` models + WMO weather-code → label/icon mapping |
| `lib/services/weather_service.dart` | `WeatherService` — HTTP GET calls to both endpoints, JSON parsing, error handling |
| `lib/widgets/weather_card.dart` | Stateful UI: frosted-glass card, loading/error/loaded states, location search, manual refresh |
| `lib/screens/student_dashboard_screen.dart` | Mounts `WeatherCard` on the Student Dashboard, beside the OCR panel |

### Requirements checklist
- [x] Integrates a public API (Open-Meteo)
- [x] HTTP GET requests (`http.get`, via `WeatherService._get`)
- [x] Retrieves and processes JSON data (`jsonDecode`, typed parsing into `WeatherSnapshot`/`GeoLocation`)
- [x] Displays API data in the UI (`WeatherCard` on the Student Dashboard)
- [x] Handles errors: no internet / timeout, non-200 response, unreadable JSON, empty search results — all surfaced as a friendly message with a **Retry** button (`WeatherException`, `_LoadState.error`)

### Bonus features implemented
- **Multiple endpoints**: forecast API + geocoding API, used together (a geocoding result feeds straight into the forecast call).
- **Search/filter**: the "Enter a city name" field lets a student look up weather anywhere before traveling there.
- **Dynamic refresh without reloading the page**: the refresh icon re-fetches the forecast in place; Flutter's widget tree updates via `setState` with no page navigation or reload.

## Screenshots
_Insert screenshots here before zipping the submission (see instructions below):_
1. **API request working** — browser DevTools → Network tab showing a `200 OK` GET request to `api.open-meteo.com/v1/forecast`.
2. **Data displayed in the project** — the Weather Advisory card on the Student Dashboard showing live temperature, condition, and min/max.
3. **Search in action** — typing a city name and seeing that city's weather load.
4. **Error state** — e.g. with Wi-Fi disabled, showing the error message and Retry button.

## Updated Project Database
Not applicable — this feature is stateless (no data is persisted; each screen load re-fetches live weather).

## Reflection

Integrating the Open-Meteo weather API turned an idea that could have felt bolted-on into something tied to how the scholarship process actually works: students still have to physically travel to the Barangay Hall or the City Scholarship Office to submit requirements, so a live weather check with a rain advisory directly supports that trip instead of just decorating the dashboard. The biggest non-coding challenge was environmental — midway through testing, the development machine's C: drive dropped to under 0.1 GB free and silently crashed the Flutter web server, which took a disk cleanup before I could verify anything worked. On the API side, Open-Meteo returns numeric WMO weather codes instead of ready-made text like "Partly Cloudy," so I had to write a mapping from code to label and icon myself rather than just reading a `description` field. The UI also went through a few iterations — a full dashboard panel, then a floating corner popover, then back to an embedded dashboard card with a frosted-glass look — which meant reworking the widget's state and layout placement more than once. Overall, chaining two endpoints (geocoding → forecast) and handling every failure path (offline, bad response, no matching city) with a visible retry option made the feature feel like a real, resilient part of the app rather than a demo that only works on the happy path.
