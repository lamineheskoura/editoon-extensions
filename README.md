# HunterToon Extensions

**The official extension store for the HunterToon Editor app.** The app
fetches `catalog.json` from this repository (URL via Remote Config, key
`extensions_catalog_url`) and lets users install, update, and remove
Lua-powered extensions from inside the app — **without any app update**.

> **بالعربية:** هذا هو مستودع متجر الإضافات الرسمي لمحرّر HunterToon.
> التطبيق يقرأ `catalog.json` من هذا المستودع، والمستخدم يثبّت/يحدّث/يحذف
> الإضافات من داخل التطبيق بلا أي تحديث للتطبيق. لصنع إضافة جديدة اقرأ
> [دليل صنع الإضافات](EXTENSION_GUIDE.md) — كامل بالإنكليزية مع ملخصات
> عربية لكل قسم.

---

## 📚 Documentation

| Doc | What it covers | بالعربية |
|---|---|---|
| **[EXTENSION_GUIDE.md](EXTENSION_GUIDE.md)** | The full developer handbook: index, contract, UI items, API, packaging, publishing, FAQ + sample | المرجع الكامل لصنع إضافتك الأولى |
| **[catalog.json](catalog.json)** | The machine-readable store index (auto-generated — do not hand-edit) | فهرس المتجر (مخرَج آلي) |
| **[tools/build_extension.ps1](tools/build_extension.ps1)** | Builds `<slug>-<version>.zip` + prints the catalog entry | يبني الأرشيف ويحسب البصمة |
| **[tools/rebuild_catalog.ps1](tools/rebuild_catalog.ps1)** | Regenerates `catalog.json` deterministically from `packages/` | يعيد توليد الفهرس |
| **[tools/validate_store.ps1](tools/validate_store.ps1)** | Full validation (folders, zips, hashes, internal consistency) | يفحص المتجر كاملاً |
| **[tools/gen_icon.dart](tools/gen_icon.dart)** | Optional 32×32 icon generator (pure Dart) | مولّد أيقونات اختياري |

---

## 📁 Repository structure

```
lamineheskoura/editoon-extensions
├── catalog.json                    ← store index (auto-generated)
├── README.md
├── EXTENSION_GUIDE.md              ← developer handbook (EN + AR summaries)
├── .github/workflows/validate-store.yml  ← CI validation on every push/PR
├── tools/
│   ├── gen_icon.dart
│   ├── build_extension.ps1
│   ├── rebuild_catalog.ps1
│   └── validate_store.ps1
└── packages/
    ├── progress/                   ← sample extension «progress»
    │   ├── manifest.json
    │   ├── init.lua
    │   ├── icon.png
    │   └── progress-1.0.0.zip
    └── <slug>/                     ← your extension goes here
```

**Golden rule:** `catalog.json` is a *build output* — never edit it by
hand. One folder per extension in `packages/<slug>/`; changing an
extension never touches anything else.

---

## 🚀 Quick start (3 minutes)

```powershell
# 1. create your folder (copy the progress sample)
Copy-Item packages/progress packages/my-extension -Recurse

# 2. edit manifest.json (slug must equal the folder name) + write init.lua

# 3. build the zip + regenerate + validate
.\tools\build_extension.ps1 -Slug my-extension -Version 1.0.0
.\tools\rebuild_catalog.ps1
.\tools\validate_store.ps1

# 4. open a PR — CI validates everything again automatically
```

Full details: **[EXTENSION_GUIDE.md](EXTENSION_GUIDE.md)**.

---

## 🔒 Security & store rules

- Every archive is **sha256-verified** on download (tampering rejected).
- **Path traversal** (`..`) is blocked at install time.
- `minApi` guards compatibility — future API requests are refused on old
  app versions.
- Lua runs in a **sandboxed isolate with a watchdog**: no files, no
  network, no WebView — only `api.log` / `api.emit`.
- The catalog is **curated**: only this repo's `main` branch content is
  served; users install explicitly, one by one.

## ✅ Google Play compliance (why this design is acceptable)

Play's policy states that *interpreted languages (JavaScript, Python,
Lua, etc.) loaded at run time must not allow potential violations of
Google Play policies*. Our design complies with every explicit condition:

| Policy condition | Status |
|---|---|
| No downloadable executable code (dex/so/jar) from outside Play | ✅ Lua only, runs in the bundled interpreter |
| Only indirect access to Android APIs | ✅ Isolated sandbox, no file/network/WebView |
| Integrity checks before loading | ✅ Mandatory sha256 + HTTPS-only downloads |
| Downloadable code stored in app-private storage | ✅ `<docs>/extensions/<slug>/` |
| No self-update of the app, no APK downloads | ✅ Not possible by design |
| User consent | ✅ Explicit install per extension, one-tap removal |

---

## 🤝 Contributing

1. Fork, create `packages/<slug>/` (see the guide), build + validate.
2. Open a PR — the `validate-store` workflow runs automatically and must
   pass (structure, hashes, deterministic catalog).
3. After merge the extension is live in the store within minutes.

> **بالعربية:** المساهمة: افرع المستودع، أضف مجلد إضافتك، ابنِ وتحقق
> محلياً، ثم افتح PR — CI يتحقق تلقائياً ويرفض أي خلل. بعد الدمج تصبح
> الإضافة متاحة لكل المستخدمين فوراً.
