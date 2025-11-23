# 🌫️ Aeris - AI-Powered Air Quality Monitor

> ⚠️ **Built in 24 hours using the new [Google Antigravity](https://antigravity.google.com) IDE.**

**Aeris** is a modern, physics-based Air Quality monitoring app built with **Flutter**. It combines real-time data with fluid, organic animations to visualize the invisible air around us.

## ⚡ Key Features

### 🎨 Visual Engineering
* **Fluid Backgrounds:** `AnimatedContainer` morphs gradients smoothly (Green → Purple) based on pollution levels.
* **Glassmorphism:** Custom frosted glass UI with `BackdropFilter` and dynamic opacity.
* **Liquid Physics:** Custom `LiquidPullToRefresh` animation that melts the UI on reload.
* **3D Matrix Tilt:** The central dashboard responds to touch pressure using `Matrix4` physics (Direct Control).

### 🛠️ Technical Architecture
* **Dual-Mode Intelligence:** Auto-GPS detection + Hybrid Search (City & Station ID).
* **Smart State Management:** Prevents "Data Reset" bugs by tracking context using `setState` logic.
* **Production Optimization:** Split ABI Builds (Arm64-v8a) reduced app size from **454MB to 7MB**.

## 📸 Tech Stack
* **Framework:** Flutter (Dart)
* **IDE:** Google Antigravity (Gemini 3 Pro Agent)
* **API:** WAQI (World Air Quality Index)
* **Packages:** `geolocator`, `liquid_pull_to_refresh`, `font_awesome_flutter`

## 🚀 How to Run
1. Clone the repo:
   ```bash
   git clone https://github.com/Water9977/Aeris.git
   
2. Install dependencies:
   ```bash
   flutter pub get

3. Run the app:
   ```bash
   flutter run --release
