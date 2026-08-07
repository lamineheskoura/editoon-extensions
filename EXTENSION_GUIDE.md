# دليل مطوّر الإضافات — محرر HunterToon

الإضافة عبارة عن مجلد صغير فيه `manifest.json` + `init.lua` (سكربت Lua) وأيقونة
اختيارية، يُضغط كملف `ZIP` ويُرفع إلى المتجر، ثم يثبّته أي مستخدم من داخل التطبيق
**بدون أي تحديث للتطبيق**. تعمل الإضافة في صندوق معزول آمن، لكنها تستطيع قيادة كل
أدوات المحرّر (رسم، قصّ، نص، طبقات، تراجع، حفظ) عبر واجهة `api.*` موحّدة.

---

## 1. الفهرس

| # | الموضوع | أين |
|---|---|---|
| 1 | كيف تعمل الإضافات | §2 |
| 2 | تشريح الإضافة | §3 |
| 3 | مرجع `manifest.json` | §4 |
| 4 | القدرات `capabilities` | §5 |
| 5 | عقد Lua | §6 |
| 6 | السياق `ctx` | §7 |
| 7 | واجهة `api.*` | §8 |
| 8 | لوحة `ui_state` | §9 |
| 9 | دورة الحياة | §10 |
| 10 | التراجع والتجميع | §11 |
| 11 | الإصدارات و `minApi` | §12 |
| 12 | التغليف والنشر | §13 |
| 13 | التجريب محلياً | §14 |
| 14 | أفضل الممارسات | §15 |
| 15 | أسئلة شائعة | §16 |
| أ | نماذج عملية | الملحق أ |

---

## 2. كيف تعمل الإضافات

الإضافة سكربت Lua يوجّه أداة داخل المحرّر. يحمّل التطبيق `init.lua` في صندوق Lua
معزول، ثم يستدعي دوالك ويمرّر الآثار عبر `api.*`:

```
Dart (المضيف)
   │  يقرأ manifest.json
   │  يحمّل init.lua في صندوق Lua معزول
   ▼
   ui_state(ctx)                 ← وصف اللوحة
   handle_action(ctx, action, args)   ← ضغطات الأزرار
   api.tool.* / api.layers.*     ← كلها أوامر قابلة للتراجع
   api.history.*                 ← تراجع / إعادة / تجميع
   on_close(ctx)                 ← الإغلاق
```

حقائق أساسية:

- **مضيف Lua مدمج** في التطبيق — المتجر يوزّع نصوصاً وبيانات فقط.
- **عزل تام** — حارس زمني يوقف أي سكربت مطوّل.
- **اللوحة تُرسم من Dart** — Lua تصف فقط.
- **القراءة من المستند** تأتي جاهزة في `ctx` (لقطة) — ليست استدعاءً.

---

## 3. تشريح الإضافة

```
packages/<slug>/
├── manifest.json      ← مطلوب — الهوية والنسخة والقدرات
├── init.lua           ← مطلوب — كل منطق الإضافة
└── icon.png           ← اختياري — 32×32
```

يُضغط المجلد بحواف الملفات على الجذر ويُرفع باسم `<slug>-<version>.zip`.

---

## 4. مرجع `manifest.json`

```json
{
  "slug": "typesetting",
  "name": "ترجمة وتوزيع",
  "version": "1.0.0",
  "icon": "icon.png",
  "minApi": 1,
  "description": "توزيع النص على الصناديق تلقائياً",
  "author": "HunterToon",
  "homepage": "https://github.com/lamineheskoura/editoon-extensions",
  "capabilities": ["doc:read", "tools:brush", "layers:read", "history:write"],
  "panel": { "movable": true, "closable": true, "width": 280, "height": 200, "x": 0.82, "y": 0.15 }
}
```

| الحقل | مطلوب؟ | النوع | القاعدة |
|---|---|---|---|
| `slug` | نعم | نص | صغيرة/أرقام/شرطات، يطابق اسم المجلد. |
| `name` | نعم | نص | الاسم المعروض (العربية مسموح). |
| `version` | نعم | نص | semver ويطابق اسم الـ ZIP. |
| `minApi` | نعم | عدد | `2` للملف الحالي؛ أكبر = رفض. |
| `panel` | نعم | كائن | مقاسات اللوحة الافتراضية. |
| `capabilities` | نعم | قائمة | الإعلان عن القدرات (§5). |
| `icon` | لا | نص | مسار الأيقونة. |
| `description` | لا | نص | يظهر في المتجر. |
| `author`/`homepage` | لا | نص | معلومات عامة. |

الحقول غير المعروفة تُتجاهل — لا كسر مستقبلي.

---

## 5. القدرات `capabilities` — بوابة الأمان

| القدرة | تمنح |
|---|---|
| `doc:read` | قراءة `ctx`. |
| `page:write` | كتابة الصفحة. |
| `layers:read` | قراءة الطبقات. |
| `layers:write` | تعديل الطبقات (إضافة/حذف/ترتيب/شفافية/قفل) — بتراجع. |
| `tools:brush` | فرشاة/ماسح/فرشاة بيضاء. |
| `tools:heal` | إصلاح. |
| `tools:clone` | ختم. |
| `tools:crop` | القصّ. |
| `tools:text` | نصّ. |
| `tools:overlay` | صورة فوق صورة. |
| `history:write` | تراجع / إعادة / تجميع. |
| `clipboard:write` | الحافظة. |
| `export:write` | حفظ الملفات `api.io.*`. |

> أي إجراء بلا قدرة → `false` + تسجيل `api denied` بلا أثر.
> أي قدرة غير معروفة في `capabilities` → الإضافة تُرفض قبل الفتح.

---

## 6. عقد Lua

يجب أن يرجع `init.lua` جدول `M`:

```lua
local M = {}

function M.on_startup(ctx)                -- تهيئة مرة
end
function M.on_open(ctx)                   -- فتح
end
function M.on_close(ctx)                  -- إغلاق
end
function M.on_event(ctx, event, payload)  -- أحداث متأخرة
end
function M.handle_action(ctx, action, args) -- إجراءات الزر
end
function M.ui_state(ctx)
  return { title = 'أداتي', visible = true, items = {} }
end
function M.run(ctx)                       -- أتمتة (اختياري)
  return true
end

return M
```

| الدالة | الإرجاع | ملاحظة |
|---|---|---|
| `on_startup`/`on_open`/`on_close` | — | لحظات الحياة، أثرها عبر `api.*`. |
| `on_event` | — | أحداث خارجية متأخرة. |
| `handle_action` | — | يتحدّثـ اللوحة تلقائياً. |
| `ui_state` | `{items}` | أي شكل آخر = لوحة فارغة. |
| `run` | boolean | نقطة أتمتة برمجية. |

---

## 7. السياق `ctx`

كل دالة تستلم `ctx` — لقطة جاهزة من المستند:

```lua
ctx = {
  slug        = "my-tool",
  page        = { id, w, h },
  tool        = "brush",
  sel         = "elt-12",
  layers      = { { id, name, type, visible, opacity, blend, locked } },
  overlays    = { { id, x, y, w, h, rotation, opacity, blend } },
  can_undo    = true,
  can_redo    = false,
  undo_count  = 5,
  redo_count  = 0,
  processing  = false,
  gesture_active = false,
  canvas_w    = 1024, canvas_h = 1536,
}
```

- يُبنى لكل استدعاء — لقطة اللحظة.
- استغلال `can_undo` / `undo_count` في القرارات البرمجية.

---

## 8. واجهة `api.*`

### 8.1 `api.tool.*` (أدوات الرسم/النص/القصّ)

| الدالة | الأداة | القدرة |
|---|---|---|
| `stroke({points, target='brush'/'eraser'/'white', color, size, opacity})` | فرشاة | `tools:brush` |
| `heal({points, radius, mode})` | إصلاح | `tools:heal` |
| `clone({points, source={x,y}, size, opacity})` | ختم | `tools:clone` |
| `crop({rect={x,y,w,h}})` | قصّ | `tools:crop` |
| `textAdd({rect, text, fontSize, color, align})` | نصّ | `tools:text` |
| `textEdit({id, ...})` | تعديل | `tools:text` |
| `overlay({op='add', ...})` | صورة فوق صورة | `tools:overlay` |
| `pick({x,y})` | قطّارة | `doc:read` |
| `viewport({scale=2})` | تحريك | — |

قيود: `points` ≤ 1000 نقطة للضربة.

### 8.2 `api.layers.*`

- `add({type, name?})` / `remove({id})` / `reorder({id, to_index})`
- `set_visible({id, visible})` / `set_opacity({id, opacity})`
- `set_locked({id, locked})` / `set_blend({id, blend})`

كلها تغييرات متراجعة.

### 8.3 `api.history.*`

- `undo()` / `redo()` / `count()`
- `group(label)` + `end_group()` — يُنشئان **خطوة مركّبة واحدة**.

> مثال: 9 ضربات فرشاة داخل `group` تُتراجع بواحد.

### 8.4 `api.io.*` (تتطلب `export:write`)

- `read_text({name?})` / `write_text({name, content})` / `save_bytes({name, content})`.

### 8.5 `api.clipboard.*` (تتطلب `clipboard:write`)

- `read()` / `write({text})`.

### 8.6 `api.ui.*` (لا قدرة)

- `refresh()` / `toast({message})` / `hide()`.

### 8.7 اتصالات عامة

- `log(level, message)` / `emit(name, payload)`.

---

## 9. عناصر اللوحة `ui_state.items`

| kind | الحقول | يرسم |
|---|---|---|
| `label` | `text` | سطر |
| `button` | `text`, `primary?`, `action?` | زر |
| `counter` | `label?`, `count` | عدد |
| `list` | `label?`, `items` | صفوف |
| `toggle` | `label`, `value`, `action?` | مفتاح |
| `edit` | `label?`, `text?`, `hint?`, `action?` | حقل |
| `nav_row` | — | prev/next |
| `slider` | `label?`, `value`, `min?`, `max?`, `step?`, `action?` | منزلق |
| `select` | `label?`, `value`, `options`, `action?` | قائمة |

مجهول `kind` يُتجاهل بأمان دون كسر اللوحة.

---

## 10. دورة الحياة

```
فتح → on_startup → on_open(ctx)
          │
 كل فعل → handle_action(ctx, action, args)
          │
 لوحة   → ui_state(ctx) → render
          │
 إغلاق  → on_close(ctx)
```

الحالة تعيش في Lua وتبقى للجلسة؛ لا تخزين دائم يكتمل إلا بالمستخدم عبر `api.io`.
اللوحة تتحدث تلقائياً بعد كل فعل.

---

## 11. التراجع والتجميع

- كل عملية تتحوّل إلى `EditorCommand` وتُسجَّل في السجل.
- `group/end_group` تجمع الأوامر في خطوة مركّبة واحدة قابلة للإلغاء.
- القراءات: `ctx.undo_count` / `api.history.count()`.
- `group` يجمع كل الأوامر بعده حتى `end_group` في خطوة واحدة.

---

## 12. الإصدارات و `minApi`

- `version` semver؛ لـ إصلاح (patch)، ميزات (minor)، كسر (major).
- `kCurrentApiVersion = 2` حالياً. `minApi ≤ 2` مقبول؛ ما فوقه رفض صريح.

---

## 13. التغليف والنشر

```
<slug>-<version>.zip
├── manifest.json
├── init.lua
└── icon.png (اختياري)
```

من داخل مستودع المتجر:

```powershell
.\tools\build_extension.ps1 -Slug my-extension -Version 1.0.0
.\tools\rebuild_catalog.ps1
.\tools\validate_store.ps1
```

ثم افتح PR — CI يفحص الجميع. `catalog.json` مولَّد آلياً — لا تعدّله يدوياً.

---

## 14. التجريب محلياً

اضغط المجلد إلى `ZIP` ثم افتح التطبيق: **متجر الإضافات** ← **تثبيت من ملف**.
نفس مسار التثبيت يعمل (sha256، مسار، manifest) — ما تختبره = ما يصل المستخدم.

---

## 15. أفضل الممارسات

- ملف واحد `init.lua` لكل منطق.
- أعلن القدرة الأدنى.
- دوال قصيرة (الحارس الزمني).
- `ui_state` حتمي.
- أفعال ثابتة (واجهتك).
- لا أسرار في السكريب.
- لا تحاول كسر الصندوق.

---

## 16. أسئلة شائعة

**هل تقصّ وترسم وتضيف نصاً وتلغي؟**
نعم — المنصّة المفتوحة تمنح كل الأدوات عبر `api.*` مع تراجع كامل.

**هل أحفظ بين الجلسات؟**
عبر `api.io` و`export:write` (نافذة حفظ). حالة Lua عابرة للجلسة.

**هل manifest تالف يكسر التطبيق؟**
لا — الفحص قبل الفتح يرفضه بأمان ويعرض رسالة واضحة.

**نسخة أقدم؟**
`minApi` حماية.

**هل المتجر آمن؟**
`sha256` لكل تنزيل + فحص مسارات + CI.

---

## الملحق أ — نماذج عملية (نسخ-لصق)

| الحزمة | ماذا تفعل | النمط |
|---|---|---|
| `progress` | «مؤشر التقدم»: عدّاد بسيط لتتبع صفحات الفصل | أتمتة + IO خفيف |
| `image-overlay` | «صورة فوق صورة»: وضع صورة فوق الصفحة مع دمج وتراجع | طبقات + تراجع |
| `typesetting` | «ترجمة وتوزيع»: توزيع النص على الصناديق تلقائياً مع ضبط الخط | معالجة صفحات |

- `progress/init.lua` — عدّاد صفحات على الـ layers الحالية.
- `image-overlay/init.lua` — تحريك/تكبير/تدوير + دمج قابل للتراجع.
- `typesetting/init.lua` — `queue.lua` + `fit.lua` لتوزيع النص بين الصناديق.

> انسخ أيّاً منها وعدّله ليبني أداتك.