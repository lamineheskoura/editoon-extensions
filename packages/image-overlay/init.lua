-- image-overlay/init.lua
-- إضافة «صورة فوق صورة» — العقل اللوائي (§4 من image-overlay-extension.md).
--
-- يملك **القرارات**: أي overlay محدد، ما الذي تُعرضه اللوحة، هل الدمج
-- متاح (يمنعه إيماءة تحويل جارية أو معالجة مضيفة)، وأسهم إعادة الترتيب.
-- لا يملك بيانات الصفحة ولا يكتبها مباشرة — كل تأثير عبر `api.overlay.*`
-- و `api.io.*` و `api.ui.*`.
--
-- العقد المُلزم (master doc §4.3):
--   meta, on_startup, on_open, on_close, on_event, handle_action, ui_state
--
-- **قراءات المضيف** تأتي عبر `_ext_ctx` (يحقنها الـ VM عند كل استدعاء):
--   ctx.overlays       = [{id, x, y, w, h, rotation, opacity, blend}]
--   ctx.selected_id    = معرّف overlay المحدد (أو nil)
--   ctx.gesture_active = هل إيماءة تحويل جارية (يمنع الدمج — §8.12)
--   ctx.processing     = هل معالجة مضيفة جارية (يمنع الدمج)
--   ctx.canvas_w/h     = أبعاد الصفحة (بكسل)

local M = {}

M.meta = {
  name    = 'صورة فوق صورة',
  slug    = 'image-overlay',
  version = 1,
}

-- قائمة أنماط المزج المعروفة للمضيف (تتطابق مع أسماء الجسر).
M.blends = {
  'srcOver', 'multiply', 'screen', 'overlay', 'darken', 'lighten',
  'colorBurn', 'colorDodge', 'hardLight', 'softLight',
  'difference', 'exclusion', 'color', 'luminosity',
}

-- دمج وسيطة ctx الرسمية مع `_G._ext_ctx` (يحقنه المضيف عند كل استدعاء) —
-- قراءات المضيف (overlays/selected_id/أعلام الحظر) تأتي عبر الـ global.
local function read_ctx(arg)
  local merged = {}
  local ext = _ext_ctx or {}
  for k, v in pairs(ext) do merged[k] = v end
  for k, v in pairs(arg or {}) do merged[k] = v end
  return merged
end

function M.on_startup(_ctx)
  api.log('info', 'image-overlay: on_startup')
  return true
end

function M.on_open(ctx)
  api.log('info', 'image-overlay: on_open (slug=' .. tostring(ctx.slug) .. ')')
  return true
end

function M.on_close(_ctx)
  api.log('info', 'image-overlay: on_close')
  return true
end

function M.on_event(ctx, event, payload)
  payload = payload or {}
  api.log('debug', 'image-overlay: on_event ' .. tostring(event))
  if event == 'overlay.added' then
    -- اختيار الصورة المضافة للتو (قرار لوا — تظهر مقابضها فوراً).
    -- تحديث اللوحة يتم عبر المضيف (`hooks.refreshUi` بعد الإضافة).
    local id = payload.id
    if id then
      api.overlay.select(id)
    end
  end
  return true
end

-- === Actions (من اللوحة عبر handle_action) ==================================

function M.handle_action(ctx, action, payload)
  ctx = read_ctx(ctx)
  payload = payload or {}
  local arg = payload.arg

  if action == 'add_overlay' then
    -- المضيف يفتح SAF picker، ينسخ الصورة داخل المشروع، يضيف overlay،
    -- ثم يُسلّم `overlay.added` لاختيارها تلقائياً.
    api.io.pick_image()
    return { ok = true }
  elseif action == 'select_overlay' then
    local id = arg
    if not id then return { ok = false, reason = 'missing_id' } end
    api.overlay.select(id)
    -- المضيف يعيد رسم اللوحة عبر hooks.refreshUi بعد عودة لوا.
    return { ok = true }
  elseif action == 'reorder_up' or action == 'reorder_down' then
    local id = arg
    if not id then return { ok = false, reason = 'missing_id' } end
    local dir = action == 'reorder_up' and 1 or -1
    api.overlay.reorder(id, dir)
    return { ok = true }
  elseif action == 'delete_overlay' then
    local id = arg
    if not id then return { ok = false, reason = 'missing_id' } end
    api.overlay.delete(id)
    -- المضيف يُسلّم `overlay.deleted` بعد الحذف (on_event يحدّث اللوحة).
    return { ok = true }
  elseif action == 'set_opacity' then
    local id = ctx.selected_id
    if not id then return { ok = false, reason = 'no_selection' } end
    api.overlay.set_opacity(id, tonumber(arg) or 1.0)
    return { ok = true }
  elseif action == 'set_blend' then
    local id = ctx.selected_id
    if not id then return { ok = false, reason = 'no_selection' } end
    api.overlay.set_blend(id, tostring(arg) or 'srcOver')
    return { ok = true }
  elseif action == 'flatten_all' then
    if ctx.gesture_active or ctx.processing then
      api.log('warn', 'image-overlay: flatten blocked (gesture/processing)')
      return { ok = false, reason = 'busy' }
    end
    api.overlay.flatten_all()
    return { ok = true }
  end
  return { ok = false }
end

-- === ui_state القادم للوحة (Dart يرسم بلوحة PanelWidgetRegistry) =============

function M.ui_state(ctx)
  ctx = read_ctx(ctx)
  local overlays = ctx.overlays or {}
  local selected = ctx.selected_id
  local gesture = ctx.gesture_active or false
  local processing = ctx.processing or false
  local can_flatten = #overlays > 0 and not gesture and not processing

  -- الصفوف: نقرة الصف = اختيار؛ أزرار ⤴ ⤵ 🗑 على اليمين.
  local rows = {}
  for i, o in ipairs(overlays) do
    local first = (i == 1)
    local last = (i == #overlays)
    rows[i] = {
      id = o.id,
      text = 'صورة ' .. i,
      selected = (o.id == selected),
      action = 'select_overlay',
      sub_actions = {
        { action = 'reorder_up',   icon = 'up',     enabled = not last },
        { action = 'reorder_down', icon = 'down',   enabled = not first },
        { action = 'delete_overlay', icon = 'delete', enabled = true },
      },
    }
  end

  local items = {
    { kind = 'button', text = '📁 إضافة صورة', primary = true, action = 'add_overlay' },
    { kind = 'counter', label = 'عدد الطبقات', count = #overlays },
  }
  if #overlays > 0 then
    items[#items + 1] = { kind = 'label', text = 'الطبقات فوق الصفحة (اضغط للاختيار):' }
    items[#items + 1] = { kind = 'list', id = 'overlays', items = rows }
  else
    items[#items + 1] = { kind = 'label', text = 'لا صور بعد — أضف صورة فوق الصفحة.' }
  end

  -- خصائص الـ overlay المحدد فقط (قرار لوا: بدون اختيار تُخفى الخصائص).
  local sel = nil
  if selected then
    for _, o in ipairs(overlays) do
      if o.id == selected then sel = o; break end
    end
  end
  if sel then
    items[#items + 1] = { kind = 'label', text = '── خصائص الصورة المحددة ──' }
    items[#items + 1] = {
      kind = 'slider', label = 'الشفافية', value = sel.opacity or 1.0,
      min = 0, max = 1, step = 0.05, action = 'set_opacity',
    }
    items[#items + 1] = {
      kind = 'select', label = 'المزج', value = sel.blend or 'srcOver',
      options = M.blends, action = 'set_blend',
    }
  end

  items[#items + 1] = {
    kind = 'button', text = '🧩 دمج مع الصفحة (قابل للتراجع)',
    primary = true, action = 'flatten_all', enabled = can_flatten,
  }
  if can_flatten then
    items[#items + 1] = { kind = 'label', text = 'يمكن التراجع عن الدمج (Undo)' }
  end

  return {
    title = M.meta.name,
    visible = true,
    items = items,
  }
end

return M
