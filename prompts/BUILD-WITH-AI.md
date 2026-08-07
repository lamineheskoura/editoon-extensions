# كيف تبني إضافة عبر مساعد ذكي (AI)

هذه الصفحة تعطي برومبتاً جاهزاً. انسخه والصقه في ChatGPT أو Gemini أو Claude
ليكتب لك إضافة كاملة لبرنامج HunterToon. لا يحتاج المساعد إلى أي ملف آخر.

خطوات الاستخدام:

1. انسخ «البرومبت النهائي» من القسم 4 بالكامل.
2. في موضع «<وصف الأداة>» اكتب طلبك بجملة أو جملتين.
3. احفظ رد المساعد في مجلد باسم أداتك، اضغطه إلى ZIP، وثبّته من داخل التطبيق.

---

## 1. ما تفعله الإضافة

- **البرنامج:** محرر HunterToon (برنامج رسم رقمي).
- **المضيف:** لغة Lua تُشغَّل من داخل التطبيق عبر واجهة `api.*`.
- **الملفات:** `manifest.json` + `init.lua` فقط.
- **النشر:** تحفظ الملفين في مجلد باسم `slug`، تضغطه ZIP، ويثبّته أي مستخدم من
  داخل التطبيق دون أي تحديث للبرنامج.

---

## 2. معلومات يحتاجها المساعد

### ملف `manifest.json`

```json
{
  "slug": "my-tool",
  "name": "أداتي",
  "version": "1.0.0",
  "minApi": 2,
  "capabilities": ["doc:read", "tools:brush"],
  "panel": { "width": 280, "height": 200, "x": 0.8, "y": 0.2 }
}
```

- `slug`: أحرف إنجليزية صغيرة وشرطات، ويجب أن يطابق اسم المجلد.
- `capabilities`: إعلان الإمكانات. كل ميزة تستخدمها تُصرَّح هنا، وأي قدرة غير
  معروفة تجعل الأداة تُرفض قبل الفتح.
- `minApi`: القيمة 2 للنسخة الحالية.

### ملف `init.lua`

```lua
local M = {}
function M.ui_state(ctx)
  return { title = 'أداتي', items = {
    { kind = 'label', text = 'مرحبا' },
    { kind = 'button', label = 'ابدأ', action = 'start' },
  } }
end
function M.handle_action(ctx, action, args)
  if action == 'start' then
    api.history.group('start')
    api.tool.stroke({
      target = 'brush',
      points = { { x = 0, y = 0 }, { x = 40, y = 40 } },
      color = '#303080', size = 3, opacity = 1.0,
    })
    api.history.end_group()
  end
  return true
end
return M
```

### ملخص `api.*`

| الاستدعاء | ماذا يفعل |
|---|---|
| `api.tool.stroke({target, points, color, size, opacity})` | رسم ضربة أو مسح |
| `api.tool.crop({rect = {x,y,w,h}})` | قصّ جزء |
| `api.tool.textAdd({rect, text, fontSize, color})` | إضافة نص |
| `api.tool.pick({x, y})` | أخذ لون نقطة |
| `api.layers.add / remove / reorder / set_opacity / set_locked / set_visible` | تغيير الطبقات |
| `api.history.group(name)` ... `api.history.end_group()` | جعل سلسلة خطوة واحدة |
| `api.history.undo() / redo() / count()` | سجل التراجع |
| `api.io.write_text({name, content})` / `read_text` | نص (يحتاج `export:write`) |
| `api.ui.toast({message})` / `api.ui.refresh()` | رسالة وتحديث |

### عناصر اللوحة في `ui_state.items`

- `label` (نص) — `button` (زر ،له إجراء) — `toggle` (مفتاح مع `value`)
- `counter` — `list` — `edit` (حقل نص) — `nav_row`
- `slider` (منزلق مع `value` و`min` و`max`) — `select` (قائمة مع `options`)

أي عنصر غير معروف يُتجاهل بأمان.

---

## 3. قواعد إلزامية

1. ملف واحد `init.lua` بلا تبعيات: لا شبكة، ولا ملفات إلا عبر `api.io`.
2. كل تغيير في المستند يكون عبر `api.*` ويخضع للتراجع.
3. أي سلسلة من عدة خطوات تُغلَّف داخل `group` / `end_group` لتصبح خطوة تراجع
   واحدة.
4. `ui_state` تصف اللوحة فقط، ولا تنفّذ أي أثر داخل المستند.
5. لا حلقة بلا نهاية (يوجد حارس زمني).
6. لا تذكر في `capabilities` إلا ما تستخدمه فعلاً.
7. كل دالة تُرجع `true`.
8. التعليقات في `init.lua` عربية وقصيرة.

---

## 4. البرومبت النهائي — انسخه من هنا

```text
أنت مطور إضافات لبرنامج تحرير رسومي يستضيف سكربتات لوا داخل صندوق معزول عبر
واجهة api.*. اكتب أداة كاملة باسم <اسم الأداة>.

وصف الأداة: <اكتب وصف الأداة هنا بجملة أو جملتين>.

سلّم ملفين منفصلين فقط:

1) manifest.json يحتوي:
   - slug: أحرف إنجليزية صغيرة وشرطات (يطابق اسم المجلد الوارد فيها)
   - name: الاسم الظاهر للمستخدم
   - version: "1.0.0"
   - minApi: 2
   - capabilities: أضف منها فقط ما تستخدمه الأداة فعلاً:
     doc:read, page:write, layers:read, layers:write, tools:brush, tools:heal,
     tools:clone, tools:crop, tools:text, tools:overlay, history:write,
     clipboard:write, export:write
   - panel: { "width": 280, "height": 200, "x": 0.8, "y": 0.2 }

2) init.lua يتضمن جدولاً M يحوي:
   - M.ui_state(ctx) يعيد { title, items } حيث كل عنصر من:
     { kind='label', text }
     { kind='button', label, action }
     { kind='toggle', label, value, action }
     { kind='counter', label, count }
     { kind='list', label, items }
     { kind='edit', label, text, action }
     { kind='nav_row' }
     { kind='slider', label, value, min, max, step, action }
     { kind='select', label, value, options, action }
   - M.handle_action(ctx, action, args) ينفذ الإجراء عبر:
     * api.tool.stroke({ target='brush', points={{x,y},...}, color, size,
       opacity }) — بحد 1000 نقطة
     * api.tool.crop({ rect = {x,y,w,h} })
     * api.tool.textAdd({ rect, text, fontSize, color })
     * api.layers.add / remove / reorder / set_opacity / set_locked / set_visible
     * api.history.group('caption') ثم الأوامر ثم api.history.end_group()
     * api.io.write_text({name, content}) عند الحاجة
     * api.ui.toast({message}) عند الإنهاء
   - دوال اختيارية: M.on_startup(ctx)، M.on_open(ctx)، M.on_close(ctx)،
     M.on_event(ctx, event, payload) — كلها ترجع true.

قواعد صارمة:
- لا تستعمل قدرة خارج القائمة أعلاه.
- لا وصول للشبكة ولا لملفات خارجية؛ القراءة والكتابة عبر api.io فقط.
- كل سلسلة خطوات تُغلَّف داخل group/end_group.
- التعليقات في لوا عربية قصيرة فقط.
- لا تضع أي نص عربي به أخطاء إملائية واضحة.
- في نهاية الرد اشرح بجملتين ما كتبته.
```

---

## 5. بعد أن يجيب المساعد

1. انسخ الرد إلى مجلد اسمه هو `slug`. فيه ملفان: `manifest.json`, `init.lua`.
2. اضغط المجلد إلى ملف ZIP وسمّه `<slug>-1.0.0.zip`.
3. افتح التطبيق ثم «متجر الإضافات» ثم «تثبيت من ملف»، واختره.
4. عند النجاح انشر في المتجر عبر `build_extension.ps1`.

> إن أخطأ المساعد أو لم يفهم، أعد الصياغة أو وضّح له القواعد في القسم 3.