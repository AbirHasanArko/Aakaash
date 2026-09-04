# Aakaash Release Notes

## Version 1.1.0 - The Smart Weather & Agriculture Update

We've been hard at work making Aakaash not just a weather app, but a smart companion tailored specifically for Bangladesh. This update introduces powerful AI capabilities and critical tools for our farming communities.

### 🌟 All Features

*   **Intelligent Natural Calamity Radar**
    *   **Earthquake Sentinel:** Real-time M3.5+ earthquake monitoring with sound-on push notifications.
    *   **Flood Fusion:** District-level flood risk alerts combining rainfall forecasts with river discharge data.
    *   **Multi-Hazard Map:** Live tracking of cyclones (GDACS) and active fires (NASA FIRMS) across Bangladesh.
*   **AI Weather Insights (Premium)**
    *   **Gemini-Powered Briefings:** Instead of just raw numbers, Aakaash now uses Google Gemini 3.6 Flash to read your local forecast and explain it in natural, conversational language.
    *   **Smart Suggestions:** The app now dynamically generates context-aware action chips. If it's going to rain, it'll tell you to carry an umbrella. If a heatwave is coming, it'll remind you to stay hydrated.
*   **Farmer's Corner (কৃষকের কোণ)**
    *   **Agricultural Suitability Gauge:** A dedicated dashboard scoring today's weather (0-100) for general farming tasks.
    *   **Smart Advisories:** 7 specialized, color-coded cards giving tailored advice for pesticide spraying, seed sowing, irrigation, harvest readiness, extreme weather (heatwaves/cold waves), pest & disease risk, and fertilizer application.
    *   **Seasonal Knowledge:** Tracks the current Bengali calendar season (e.g., Grisma, Barsha) and displays relevant crop tasks.
*   **Beautiful District-Aware Forecasting**
    *   **Home Screen Widget:** Pin your selected city and real-time weather to your Android launcher with a stunning glassmorphism widget.
    *   **Comprehensive Data:** 5-day forecast strips, 24-hour hourly graphs, and a 6-tile highlights grid (humidity, wind, UV, pressure, visibility, dew point).
    *   **Glassmorphism UI:** Stunning glass cards sitting on top of adaptive gradient backgrounds that shift with the current weather code and time of day.
    *   **Automated Background Sync:** Configurable daily morning weather summaries and background calamity sweeps.

### 🛠️ Improvements & Fixes

*   **Accurate AI Localities:** Fixed an issue where Gemini would sometimes use deep local OpenWeather geonodes (like "Samair") instead of the primary city name (like "Dhaka"). The AI now always refers to the correct, user-friendly city name.
*   **Forecast Optimization:** Transitioned from a 10-day forecast to a highly accurate 5-day forecast strip, ensuring better data reliability.
*   **Brand Unification:** All user-facing subscription and UI references have been officially updated from "AppsPro" to "BDApps" for a cleaner, unified brand experience.
*   **Updated Subscription Pricing:** The premium subscription rate is now officially listed as **BDT 2.00/day** (applicable for Robi and Cirkle users).

### 🧱 Tech Stack

*   **UI Framework:** Flutter 3.13+ / Dart 3.1+
*   **State Management:** Provider
*   **AI Insights:** Google Gemini Flash (`google_generative_ai`)
*   **Weather Data:** OpenWeather (`/onecall` + `/forecast`)
*   **Calamity Radar:** USGS Earthquakes, GDACS, NASA FIRMS, Open-Meteo Flood/GloFAS
*   **Background Tasks:** Workmanager (Native Android JobScheduler)
*   **Notifications:** Flutter Local Notifications
*   **Location:** Geolocator + Geocoding
*   **Subscriptions:** BDApps via AppsPro SDK

---
*Stay safe and weather-aware!*
