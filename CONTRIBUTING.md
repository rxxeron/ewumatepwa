# EWUmate PWA — Contributing Guidelines

Thank you for contributing to **EWUmate Progressive Web App (PWA)**! This platform delivers the EWUmate experience across browsers and iOS Safari devices without requiring native store installations.

---

## 🛠️ Prerequisites & Setup

1. **Flutter SDK:** Flutter 3.27+ with Web support enabled (`flutter config --enable-web`)
2. **Chrome / Edge / Safari** for local browser debugging
3. **Environment Setup:**
   ```bash
   cp .env.example .env
   ```

---

## 🚀 Running Locally

```bash
# Run in Chrome with CanvasKit rendering
flutter run -d chrome

# Build for production
flutter build web --release --base-href "/"
```

---

## 📐 Web-Specific Guidelines

1. **Web Compatibility:**
   - Avoid `dart:io` operations. Use web-compatible alternatives or conditional imports.
   - For file downloads, use browser Blob Object URLs.
2. **IndexedDB / Hive:**
   - Local state is stored in IndexedDB via Hive. Ensure box names and adapters maintain backward compatibility.
3. **CanvasKit Rendering:**
   - The UI is tuned for CanvasKit hardware rendering. Avoid CSS overrides that break canvas layout.

---

## 🧪 Testing Checklist
- [ ] Ran `flutter format .`
- [ ] Ran `flutter analyze`
- [ ] Verified responsive layout across desktop and mobile viewport sizes in DevTools
