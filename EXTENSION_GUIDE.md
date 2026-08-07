# Extension Developer Guide — HunterToon Editor

> **بالعربية:** هذا الكتيب هو المرجع الكامل لصنع إضافات محرّر HunterToon.
> كل إضافة = مجلد صغير يحتوي `manifest.json` + `init.lua` (لوا) + أيقونة
> اختيارية، يُضغط ZIP ويُرفع إلى متجر الإضافات — ثم يثبّتها أي مستخدم من
> داخل التطبيق **دون أي تحديث للتطبيق نفسه**. التطبيق يحمّل لوا في صندوق
> معزول بلا وصول للقرص أو الشبكة؛ كل ما تستطيع الإضافة فعله هو: عرض لوحة
> صغيرة داخل المحرر، معالجة ضغطات الأزرار، وتحديث محتوى لوحتها. اقرأ
> القسم 1 (الفهرس) أولاً لتعرف كل ما تحتاجه، ثم القسم 2 لفهم كيف تعمل
> الأشياء من الداخل.

---

## 1. Index — Everything you need to know

> **بالعربية:** هذا الفهرس هو "خريطة المعرفة" الكاملة: كل ماذا/لماذا مطلوب
> لصنع إضافة تعمل. راجعه قبل البدء وبعد الانتهاء.

| # | Topic | Why it matters | Where |
|---|---|---|---|
| 1 | How extensions work (architecture) | Understand the sandbox, the contract, and the limits before writing code | §2 |
| 2 | Extension anatomy (3 files) | Know exactly which files you must produce | §3 |
| 3 | `manifest.json` reference | Every field, required or optional, and its validation rules | §4 |
| 4 | The Lua contract (module functions) | The 4 functions that make your extension live | §5 |
| 5 | Panel UI items (`ui_state`) | The 7 widget kinds the panel can render | §6 |
| 6 | API surface & sandbox limits | What your Lua can call, and what it can never do | §7 |
| 7 | Lifecycle & state | When your functions run, when the panel refreshes | §8 |
| 8 | Versioning & `minApi` | Semver rules and compatibility with future app versions | §9 |
| 9 | Packaging (ZIP + sha256) | The exact archive layout the store requires | §10 |
| 10 | Publishing to the store | How an extension reaches every user | §11 |
| 11 | Local testing | Try your extension without GitHub | §12 |
| 12 | Best practices & limitations | Rules that keep your extension fast, safe and accepted | §13 |
| 13 | FAQ | Common pitfalls and answers | §14 |
| A | Full working sample (`progress`) | Copy-paste starting point | Appendix A |
| B | Ship checklist | One-page checklist before you publish | Appendix B |

---

## 2. How extensions work

An extension is a **small Lua script** that drives a **floating panel**
inside the editor. The app itself is written in Dart/Flutter; your extension
never touches pixels, files or the network. Instead:

```
┌────────────────────────────────────────────────────────────┐
│  Dart host (the app)                                        │
│                                                             │
│  ┌──────────────┐   invokes   ┌─────────────────────────┐   │
│  │ Extension    │ ───────────▶│ Lua sandbox (isolate)   │   │
│  │ session      │  on_open /  │  - your init.lua        │   │
│  │ (per plugin) │  on_close / │  - api.log, api.emit    │   │
│  │              │  handle_    │  - no files, no network │   │
│  │              │  action /   │  - watchdog (timeouts)  │   │
│  │              │  ui_state   ◀─────────────────────────│   │
│  │              │             │  returns { items = {} } │   │
│  └──────────────┘             └─────────────────────────┘   │
│       │                                                     │
│       ▼  renders your items as widgets (label, button, …)   │
└────────────────────────────────────────────────────────────┘
```

Key facts:

- **The Lua runtime is bundled inside the APK.** The store only ships
  `.lua` / `.json` / `.png` text and data — never compiled code.
- **Every call is sandboxed.** A watchdog kills scripts that run too long.
- **The panel is rendered by Dart.** Lua only *describes* the UI by
  returning a table of items.
- **An extension is a single file of logic**: `init.lua`. The contract is
  deliberately tiny so extensions remain portable and easy to audit.

> **بالعربية:** الإضافة لا ترسم ولا تقرأ ملفات ولا تتصل بالشبكة — التطبيق
> هو من يرسم ويفعل، ولوا فقط "تصف" الواجهة وتعالج الأزرار. هذا التصميم
> هو ما يجعل إضافات الطرف الثالث آمنة ومتوافقة مع سياسات Google Play.

---

## 3. Extension anatomy

Every extension is one folder, three files maximum:

```
packages/<slug>/
├── manifest.json     ← required — identity, version, panel geometry
├── init.lua          ← required — the whole logic of your extension
└── icon.png          ← optional — 32×32 PNG shown in menus and the store
```

The folder is zipped with the three files **at the archive root** and
uploaded as `<slug>-<version>.zip`.

> **بالعربية:** مجلد واحد بثلاثة ملفات فقط؛ أي ملف إضافي لا يُقرأ ولن
> يضره شيء، لكن لا تعتمد عليه أبداً — القاعدة الذهبية: كل المنطق في
> `init.lua` واحد.

---

## 4. `manifest.json` reference

```json
{
  "slug": "progress",
  "name": "Progress Tracker",
  "version": "1.0.0",
  "icon": "icon.png",
  "minApi": 1,
  "description": "Tracks your pages-per-chapter progress inside the editor.",
  "author": "HunterToon",
  "homepage": "https://github.com/lamineheskoura/editoon-extensions",
  "panel": { "movable": true, "closable": true, "width": 280, "height": 300, "x": 0.82, "y": 0.15 }
}
```

### Field reference

| Field | Required | Type | Validation & notes |
|---|---|---|---|
| `slug` | ✅ yes | `string` | `^[a-z][a-z0-9-]*$` — lowercase latin, digits, dashes. **Must equal the folder name**, else rejected. |
| `name` | ✅ yes | `string` | Display name (Arabic allowed). Shown in menus, store, panels. |
| `version` | ✅ yes | `string` | Semver-ish (e.g. `1.0.0`). Numbers accepted for compatibility. Must match the ZIP name. |
| `minApi` | ✅ yes | `integer` | Extension-API version your extension needs. `1` today. Requests for a future value are rejected with "update the app" — bump it only when you actually use newer features. |
| `panel` | ✅ yes | `object` | Default panel geometry: `movable`, `closable`, `width`, `height`, `x`/`y` as fractions of the editor area (0–1). |
| `icon` | no | `string` | Path inside the package to a 32×32 PNG. |
| `description` | no | `string` | Shown in the store listing. |
| `author` | no | `string` | Your name/alias. |
| `homepage` | no | `string` | Link to your repo/contact. |

Unknown fields are ignored — extra metadata is safe to keep, and new
fields can be added in the future without breaking older app versions.

> **بالعربية:** `slug` هو "جواز سفر" الإضافة — يجب أن يطابق اسم المجلد
> بالضبط. `minApi` يضمن ألا تطلب الإضافة ميزات من نسخة تطبيق أقدم منها.
> بقية الحقول إعلانية وتظهر في المتجر.

---

## 5. The Lua contract

Your `init.lua` must return a table `M` with (some of) these functions:

```lua
local state = { done = 0 }

local M = {}

function M.on_open(ctx)
  -- Called once when the user opens your panel (from the "+" menu).
end

function M.on_close(ctx)
  -- Called when the panel/session closes.
end

function M.handle_action(ctx, action, args)
  -- Called on every button press / row tap / toggle / edit submit.
  -- action: string from the widget's `action` field (or 'prev'/'next'
  --         for nav_row). args: table of extras (e.g. edit text).
end

function M.ui_state(ctx)
  -- Returns the panel content table: { items = { ... } }.
  -- Called when the panel opens and automatically after every action.
  return { items = {} }
end

return M
```

### The `ctx` table

Every function receives a context table with the extension identity:

```lua
ctx = { slug = "progress" }
```

### Return values

| Function | Returns | Notes |
|---|---|---|
| `on_open` / `on_close` | nothing | Side effects via `api.*` only. |
| `handle_action` | nothing | The host refreshes the panel automatically afterwards. |
| `ui_state` | `{ items = { ... } }` | Any other shape is treated as an empty panel (no crash). |

> **بالعربية:** أربع دوال فقط. اللوحة تُحدَّث تلقائياً بعد كل ضغطة زر —
> لا تحتاج لإعادة رسم يدوية. `ctx` يحمل slug الإضافة (قد تتسع لاحقاً
> لسياق المحرر).

---

## 6. Panel UI items (`ui_state`)

Lua describes the panel with a list of typed items. Dart renders them
following the app theme — Lua never draws a single pixel.

| kind | Fields | Renders as |
|---|---|---|
| `label` | `text` | Static text line |
| `button` | `text`, `primary?`, `action?` | Tappable button; `primary` highlights it |
| `counter` | `label?`, `count` | Number with optional label |
| `list` | `label?`, `items:[{text, strikethrough?, selected?, id?, action?}]` | Rows with optional strike-through / selection / tap action |
| `toggle` | `label`, `value`, `action?` | Switch that sends `action` on tap |
| `edit` | `label?`, `text?`, `hint?`, `action?` | Text field; submitted value arrives in `args` |
| `nav_row` | (none) | Previous/next buttons sending actions `prev` / `next` |

```lua
function M.ui_state(ctx)
  return { items = {
    { kind = 'label',   text = 'Chapter progress' },
    { kind = 'counter', label = 'Pages done', count = state.done },
    { kind = 'button',  text = '+1 page', action = 'inc', primary = true },
    { kind = 'list',    label = 'History',
      items = { { text = 'Done a page', id = '1' } } },
  } }
end
```

Unknown `kind` values are logged and **skipped** — an old app never
crashes on a newer extension, and vice-versa.

> **بالعربية:** 7 أنواع عناصر جاهزة. أي `kind` غير معروف يُتجاهل بهدوء
> (توافق أمامي وخلفي). اللوحة تُرسم حسب ثيم التطبيق — لا ألوان/أحجام من
> لوا.

---

## 7. API surface & sandbox limits

### Available to third-party extensions

| API | Signature | Purpose |
|---|---|---|
| `api.log` | `api.log(level, message)` | `level` ∈ `debug`/`info`/`warn`/`error`. Logs appear in the extension log. |
| `api.emit` | `api.emit(name, payload)` | Fires a named event to the host (future host hooks / other features). |

### What Lua can never do

- ❌ No file access (read or write) — the sandbox has no I/O.
- ❌ No network access — no sockets, no HTTP.
- ❌ No access to the editor model directly — no pixels, pages or boxes
  unless the app exposes an `api.*` bridge for it.
- ❌ No foreign native code / OS calls.
- ❌ No infinite work — a watchdog enforces a timeout per invocation.

> **بالعربية:** سطران فقط متاحان: `api.log` للتسجيل و`api.emit` لإطلاق
> أحداث للمضيف. لا ملفات، لا شبكة، لا وصول لنموذج المحرر، وحارس زمني
> يقتل أي سكربت معلّق. هذه الحدود نفسها هي ما يجعل المتجر مقبولاً في
> Google Play.

---

## 8. Lifecycle & state

```
user taps "+" → session opens → on_open(ctx)
                                   │
        every action: handle_action(ctx, action, args)
                                   │
        panel refresh: ui_state(ctx) → { items } → rendered
                                   │
user closes panel → on_close(ctx) → session ends
```

- **State lives in Lua.** `local state = { ... }` in your file persists
  for the session; it resets when the app restarts. There is no host-side
  persistence API for third-party extensions yet.
- **Automatic refresh:** the panel re-renders from `ui_state` after every
  `handle_action` — you never trigger updates manually.
- **Re-entrancy:** keep `handle_action` pure-and-quick; the watchdog
  measures each call separately.

> **بالعربية:** الحالة تعيش داخل سكربتك (متغيرات محلية) وتدوم للجلسة
> الحالية فقط؛ لا يوجد تخزين دائم للإضافات الخارجية بعد. التحديث تلقائي
> بعد كل فعل.

---

## 9. Versioning & `minApi`

- `version` is semver-ish: `major.minor.patch`. Bump **patch** for fixes,
  **minor** for new UI/features, **major** for breaking contract changes.
- The store keeps each published version as `<slug>-<version>.zip` and the
  catalog points to the latest. Users can update in the store screen.
- `minApi` guards compatibility: set it to the minimum extension-API the
  app must have. Today the API is `1`; if a future app adds features and
  bumps the API, extensions requesting a higher `minApi` are refused on
  old app versions with a clear message.

> **بالعربية:** نسّق إصداراتك semver؛ ارفع `minApi` فقط عند الحاجة فعلية
> لميزات أحدث. المستخدمون يحدّثون من شاشة المتجر.

---

## 10. Packaging

The store requires exactly:

```
<slug>-<version>.zip
├── manifest.json
├── init.lua
└── icon.png (optional)
```

Use the build script from the repo root:

```powershell
.\tools\build_extension.ps1 -Slug progress -Version 1.0.0
```

It produces `packages/<slug>/<slug>-<version>.zip` and prints the catalog
entry (with the correct `sha256` **and** `sizeBytes`, which the store shows
to users as the download size). The catalog itself is auto-generated:

```powershell
.\tools\rebuild_catalog.ps1     # regenerates catalog.json from folders
.\tools\validate_store.ps1      # validates everything (folder, zip, hashes)
```

Never hand-edit `catalog.json` — it is a build output. `validate-store.yml`
(CI) enforces this on every push.

> **بالعربية:** الأرشيف = الملفات الثلاثة على الجذر، باسم
> `<slug>-<version>.zip`. السكربت يبني الأرشيف ويحسب بصمة sha256
> (التحقق منها إلزامي في التطبيق عند التثبيت). `catalog.json` مخرَج
> آلي — لا تعدّله باليد.

---

## 11. Publishing to the store

1. Create your package folder under `packages/<slug>/` (manifest + init.lua + icon).
2. Build the ZIP and regenerate the catalog (see §10).
3. Run `.\tools\validate_store.ps1` — it must pass (CI does the same).
4. Open a pull request against `lamineheskoura/editoon-extensions`.
5. After merge, the extension appears in every user's **Extension Store**
   within minutes — no app update needed.

> **بالعربية:** القنوات: مجلد → ZIP → توليد الكتالوج → تحقق → PR على
> مستودع المتجر. بعد الدمج تظهر الإضافة لكل المستخدمين فوراً.

---

## 12. Local testing (no GitHub)

Zip your package folder (three files at the root) and tap
**"Install from file"** in the app's Extension Store. The same install
pipeline runs (sha256, path safety, manifest validation) — what you test
locally is exactly what users get.

> **بالعربية:** للتجربة محلياً: اضغط المجلد ZIP وثبّته من «تثبيت من
> ملف» في المتجر — نفس مسار التثبيت تماماً.

---

## 13. Best practices & limitations

- **One-file rule:** put all logic in `init.lua`. The host only reads
  files from your installed folder; a self-contained package always works.
- **Keep it fast:** every call has a watchdog timeout; heavy work per tap
  will be killed.
- **No assumptions about screen size:** `panel` geometry in the manifest is
  the *default*; users can move/resize closable panels.
- **Be deterministic:** `ui_state` must be computable from your state —
  never block on anything (you can't anyway: no I/O exists).
- **Name actions clearly:** use stable string actions (`'inc'`, `'reset'`),
  they are your public API — changing them breaks existing panel layouts.
- **Arabic is welcome** in `name`, `description` and all UI strings.
- **Never ship secrets:** scripts are readable by users — never embed
  tokens, keys, or private URLs.
- **Never try to bypass the sandbox:** the watchdog and validator are
  enforced by the app; extensions that probe the host are rejected at
  review/validation time.

> **بالعربية:** القواعد الذهبية: ملف واحد، سرعة، حتمية، أسماء أفعال
> ثابتة (واجهتك العامة)، لا أسرار في السكربت (المستخدم يقرأه)، والعربية
> مرحّب بها في كل النصوص.

---

## 14. FAQ

**Q: Can an extension edit the manga pages?**
A: Not yet. Third-party extensions get `api.log` and `api.emit` only. A
future `api.*` bridge (e.g. page info or text insertion) can be added by
the app — publish what you need as a feature request.

**Q: Can my extension save data between sessions?**
A: Not yet — state lives for the current session only. A persistence
bridge may come later.

**Q: Will a malformed manifest crash the app?**
A: No. Install-time validation rejects it with a clear message.

**Q: What if a user has an older app version?**
A: `minApi` protects you — the store refuses your extension there.

**Q: Is my extension safe from malicious store tampering?**
A: Yes — the catalog is curated in the `lamineheskoura/editoon-extensions` repo, every
archive is sha256-verified on download, and path-traversal is blocked.

**Q: Can I ship a ZIP bigger than a few KB?**
A: Archives are plain ZIP; keep them small (a normal extension is ~2 KB).
If you need many versions, attach archives to GitHub Releases instead of
committing them (README explains the growth model).

> **بالعربية:** خلاصة الأسئلة الشائعة: لا تعديل للصفحات بعد (ميزة مستقبلية
> عبر جسور api جديدة)، لا تخزين دائم بعد، التطبيق لا ينهار على manifest
> خاطئ، وsha256 يحمي من العبث.

---

## Appendix A — Full working sample (`packages/progress`)

The `progress` extension ships in this repo as the reference sample —
read `packages/progress/init.lua` and `packages/progress/manifest.json`
as your starting point. It demonstrates: state, counters, buttons,
history list, `api.log`, and `api.emit` — all in one file.

## Appendix B — Ship checklist

- [ ] Folder name == `slug` (`^[a-z][a-z0-9-]*$`)
- [ ] `manifest.json`: `slug`, `name`, `version`, `minApi`, `panel` present
- [ ] `init.lua` returns `M` and defines at least `ui_state` (+ `handle_action`)
- [ ] `icon.png` is 32×32 (optional)
- [ ] ZIP named `<slug>-<version>.zip` with files at root
- [ ] `.\\tools\\build_extension.ps1 -Slug <slug> -Version <version>` OK
- [ ] `.\\tools\\rebuild_catalog.ps1` regenerated `catalog.json`
- [ ] `.\\tools\\validate_store.ps1` passes (CI will run it anyway)
- [ ] No secrets, no absolute paths, no localhost URLs in the package
- [ ] `ui_state` never blocks; every action is bounded and quick
