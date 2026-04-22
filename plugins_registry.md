# TasteSpot Plugins Registry

This document serves as a running registry of external Flutter packages (plugins) we've added to the project. It explicitly breaks down what each plugin does and exactly why we needed it, so you can easily reference them later!

---

## 1. `url_launcher`
* **Purpose**: Deep Linking & Opening External Native Apps
* **What it does**: It acts as a messenger to iOS and Android. When you trigger it with an external link (like a website URL, an email `mailto:`, or a map link), it forces the operating system to jump out of your Flutter app and natively open that link in the appropriate pre-installed app (Safari, Chrome, Google Maps, Apple Maps, etc.).
* **Where we use it**:
    * **Restaurant Tagging**: We use it on the `PostDetailScreen`. When a user taps the "📍 Sakura Sushi Bar" pill, we generate a Google Maps search URL and feed it to `url_launcher` to instantly blast the user over to the Google Maps app to see directions.
