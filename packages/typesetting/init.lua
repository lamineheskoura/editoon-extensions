-- typesetting/init.lua
-- إضافة توزيع الترجمة — العقل اللوائي (§4 من typesetting-extension.md).
--
-- يملك **القرارات**: الحالة، الترتيب، التوزيع، التخطّي، الإسناد اليدوي.
-- لا يملك بيانات الصفحة ولا يكتبها مباشرة — كل تأثير عبر `api.commands.*`.
--
-- العقد المُلزم (master doc §4.3):
--   meta, on_startup, on_open, on_close, on_event, handle_action, ui_state
--
-- **ملاحظة تحميلية:** لا `package` lib في الـ VM (sandbox)؛ لذلك queue و fit
-- مُضمَّنان هنا كـ modules محلية بدلاً من `require`. كلاهما يحافظ على عقد
-- typesetting-extension.md §4 (queue.lua و fit.lua). الـ host يختبرهما مباشرة
-- أيضاً عبر تحميلها على `_G.typesetting_queue`/`_G.typesetting_fit` لاختبارات
-- قائمة بذاتها (انظر `test/engine/extensions/typesetting_queue_test.dart`).

local M = {}

-- === queue (cache للسطر "مستخدم" — P5) =====================================

local queue = { lines = {}, boxes = {}, used = {} }

function queue.reset(lines)
  queue.lines = lines or {}
  queue.boxes = {}
  queue.used = {}
  for _, line in ipairs(queue.lines) do
    line.used = line.used or false
  end
end

function queue.pop_next_unused()
  local best = nil
  for _, line in ipairs(queue.lines) do
    if not (line.used or false) then
      if not best or (line.seq or 0) < (best.seq or 0) then
        best = line
      end
    end
  end
  return best
end

function queue.peek_next_unused()
  local best = nil
  for _, line in ipairs(queue.lines) do
    if not (line.used or false) then
      if not best or (line.seq or 0) < (best.seq or 0) then
        best = line
      end
    end
  end
  return best
end

function queue.remaining_count()
  local n = 0
  for _, line in ipairs(queue.lines) do
    if not (line.used or false) then n = n + 1 end
  end
  return n
end

function queue.mark_used(line, boxId)
  if not line then return end
  line.used = true
  queue.used[boxId] = line.id
end

-- إسناد يدوي: يحرّر السطر القديم للصندوق ويضع الجديد.
function queue.assign(lineId, boxId)
  local line = nil
  for _, l in ipairs(queue.lines) do
    if l.id == lineId then line = l; break end
  end
  if not line then return false end
  -- إذا كان هذا السطر على صندوق آخر، حرّر ذاك الصندوق.
  for bid, lid in pairs(queue.used) do
    if lid == lineId and bid ~= boxId then
      queue.used[bid] = nil
    end
  end
  -- إذا كان الـ boxId الحالي يحمل سطراً مختلفاً، حرّره.
  local old = queue.used[boxId]
  if old and old ~= lineId then
    for _, l in ipairs(queue.lines) do
      if l.id == old then l.used = false; break end
    end
  end
  line.used = true
  queue.used[boxId] = lineId
  return true
end

-- تحرير إسناد.
function queue.unassign(lineId, boxId)
  if queue.used[boxId] == lineId then
    queue.used[boxId] = nil
    for _, l in ipairs(queue.lines) do
      if l.id == lineId then l.used = false; break end
    end
    return true
  end
  return false
end

function queue.on_box_created(boxId, seq)
  if not boxId then return end
  queue.boxes[boxId] = { seq = seq or 0 }
end

function queue.on_box_deleted(boxId, wasFilled)
  if not boxId then return end
  local lid = queue.used[boxId]
  if lid then
    for _, l in ipairs(queue.lines) do
      if l.id == lid then l.used = false; break end
    end
    queue.used[boxId] = nil
  end
  queue.boxes[boxId] = nil
  if wasFilled then
    api.log('debug', 'typesetting: box deleted — line freed: ' .. tostring(lid))
  end
end

-- === fit (تقدير لوا للملاءمة؛ القرار الحقيقي في المضيف عبر TextPainter) ====

local fit = {}

function fit.fit(text, width_pts, height_pts, padding)
  padding = padding or 6.0
  local usable_w = (width_pts or 0) - 2 * padding
  local usable_h = (height_pts or 0) - 2 * padding
  if usable_w <= 0 or usable_h <= 0 then
    return { fontSize = 8.0, too_small = true }
  end
  local fs = math.max(8.0, math.min(usable_h * 0.9, 96.0))
  local nchars = string.len(text or '')
  if nchars > 0 then
    local max_by_width = usable_w / (nchars * 0.6)
    fs = math.min(fs, max_by_width)
  end
  fs = math.max(fs, 8.0)
  local too_small = fs < 10.0 and (nchars > 0)
  return { fontSize = fs, too_small = too_small }
end

-- === الحالة المحلية =========================================================

M.script = { lines = {}, chapter = nil, updatedAt = nil }
M.cursor = 1
M.auto_mode = false
M.font_fit = true
M.input_text = ''

-- === Lifecycle ===============================================================

function M.on_startup(_ctx)
  api.log('info', 'typesetting: on_startup')
  return true
end

function M.on_open(ctx)
  api.log('info', 'typesetting: on_open (slug=' .. tostring(ctx.slug) .. ')')
  -- اطلب السيناريو والحالة المستنتجة من المضيف — يصل عبر on_event.
  api.script.load()
  return true
end

function M.on_close(_ctx)
  api.log('info', 'typesetting: on_close')
  return true
end

function M.on_event(ctx, event, payload)
  if event == 'script.loaded' or event == 'script.replaced' then
    M.script = payload or {}
    M.cursor = 1
    queue.reset(payload and payload.lines or {})
    api.log('debug', 'typesetting: script loaded (' ..
        tostring(#(M.script.lines or {})) .. ' lines)')
  elseif event == 'used_state.ready' then
    payload = payload or {}
    for _, line in ipairs(M.script.lines or {}) do
      line.used = (payload.used or {})[line.id] ~= nil
    end
    api.log('debug', 'typesetting: used_state seeded')
  elseif event == 'box.created' then
    queue.on_box_created(payload and payload.elementId, payload and payload.seq)
    if M.auto_mode then
      return M.distribute_next(payload and payload.elementId)
    end
  elseif event == 'box.deleted' then
    queue.on_box_deleted(payload and payload.elementId, payload and payload.wasFilled)
  elseif event == 'clipboard.text' then
    local text = payload and payload.text or ''
    if string.len(text) > 0 then
      M.input_text = text
      M.replace_all(text)
      api.ui.update('typesetting', M.ui_state({}))
    end
    api.log('debug', 'typesetting: clipboard text received (' .. string.len(text) .. ' chars)')
  elseif event == 'io.text_file' then
    local text = payload and payload.text or ''
    if string.len(text) > 0 then
      M.input_text = text
      M.replace_all(text)
      api.ui.update('typesetting', M.ui_state({}))
    end
    api.log('debug', 'typesetting: file text received (' .. string.len(text) .. ' chars)')
  elseif event == 'distribution.done' then
    api.log('debug', 'typesetting: distribution done')
  elseif event == 'page.changed' then
    api.log('debug', 'typesetting: page ' .. tostring(payload and payload.page))
  end
  return true
end

-- === Actions (من اللوحة عبر handle_action) ==================================

function M.handle_action(ctx, action, payload)
  payload = payload or {}
  if action == 'distribute_next' then
    return M.distribute_next(payload.boxId)
  elseif action == 'assign' then
    return M.assign_line(payload.lineId, payload.boxId)
  elseif action == 'unassign' then
    return M.unassign_line(payload.lineId, payload.boxId)
  elseif action == 'replace_all' then
    return M.replace_all(payload.text or M.input_text or '')
  elseif action == 'next' then
    return M.step(1)
  elseif action == 'prev' then
    return M.step(-1)
  elseif action == 'toggle_auto' then
    M.auto_mode = not M.auto_mode
    api.ui.update('typesetting', M.ui_state(ctx))
    return { auto_mode = M.auto_mode }
  elseif action == 'toggle_font_fit' then
    M.font_fit = not M.font_fit
    api.ui.update('typesetting', M.ui_state(ctx))
    return { font_fit = M.font_fit }
  elseif action == 'paste_clipboard' then
    api.clipboard.get_text()
    return { ok = true }
  elseif action == 'import_file' then
    api.io.read_text_file()
    return { ok = true }
  elseif action == 'write_template_file' then
    api.io.write_text_file('script_template.txt', M.template_text())
    return { ok = true }
  elseif action == 'set_input_text' then
    M.input_text = payload.arg or ''
    return { ok = true }
  elseif action == 'load_input_text' then
    if M.input_text and string.len(M.input_text) > 0 then
      M.replace_all(M.input_text)
      api.ui.update('typesetting', M.ui_state(ctx))
    end
    return { ok = true }
  elseif action == 'open_script_editor' then
    -- يطلب المضيف فتح محرر ملء الشاشة لنص الفصل (يكتب/يلصق/يحرر).
    -- المضيف يفتح الـ widget ويُدخل النص عبر `replace_all` عند الحفظ.
    return { ok = true, open_script_editor = true }
  elseif action == 'list_line' then
    -- اختيار سطر من القائمة → تحريك المؤشر إليه.
    local lineId = payload.arg
    if lineId then
      for i, line in ipairs(M.script.lines or {}) do
        if line.id == lineId then
          M.cursor = i
          api.ui.update('typesetting', M.ui_state(ctx))
          return { ok = true, cursor = i }
        end
      end
    end
    return { ok = false }
  end
  return { ok = false }
end

-- === العمليات الذرّية ========================================================

function M.distribute_next(boxId)
  if not boxId then
    api.log('warn', 'typesetting: distribute_next called without a box')
    return { ok = false, reason = 'no_box' }
  end
  local line = queue.pop_next_unused()
  if not line then
    api.log('info', 'typesetting: queue empty — nothing to distribute')
    return { ok = false, reason = 'empty' }
  end
  api.commands.distribute({ lineId = line.id }, boxId, { font_fit = M.font_fit })
  queue.mark_used(line, boxId)
  line.used = true
  api.emit('distribution.done', { lineId = line.id, boxId = boxId })
  api.ui.update('typesetting', M.ui_state({}))
  return { ok = true, lineId = line.id, boxId = boxId }
end

function M.assign_line(lineId, boxId)
  if not lineId or not boxId then
    return { ok = false, reason = 'missing_args' }
  end
  api.commands.assign({ lineId = lineId }, boxId, { font_fit = M.font_fit })
  queue.assign(lineId, boxId)
  api.emit('distribution.done', { lineId = lineId, boxId = boxId, manual = true })
  return { ok = true }
end

function M.unassign_line(lineId, boxId)
  if not lineId or not boxId then
    return { ok = false, reason = 'missing_args' }
  end
  api.commands.unassign({ lineId = lineId }, boxId, {})
  queue.unassign(lineId, boxId)
  api.emit('distribution.undone', { lineId = lineId, boxId = boxId })
  return { ok = true }
end

function M.replace_all(text)
  api.script.replace(text or '')
  return { ok = true }
end

function M.step(direction)
  local n = #(M.script.lines or {})
  if n == 0 then return { ok = false, reason = 'no_script' } end
  -- تنقّل مباشر سطراً بسطر (دون قفز فوق المستعمل): يبقى زرّا السابق/
  -- التالي متوقعين ويعبران كل الأسطر — المستعمل منها يظهر مشطوباً.
  local idx = M.cursor + direction
  if idx < 1 then idx = 1 end
  if idx > n then idx = n end
  M.cursor = idx
  api.ui.update('typesetting', M.ui_state({}))
  local line = M.script.lines[idx]
  return { ok = true, cursor = idx, lineId = line and line.id }
end

function M.template_text()
  local parts = { 'سطر 1 — ألصق نص الفصل هنا سطراً سطراً.',
                  'سطر 2 …',
                  'سطر 3 …' }
  return table.concat(parts, '\n')
end

-- === ui_state القادم للوحة (Dart يرسم بلوحة PanelWidgetRegistry) ===============

function M.ui_state(ctx)
  local lines_rendered = {}
  for i, line in ipairs(M.script.lines or {}) do
    lines_rendered[i] = {
      id = line.id,
      text = line.text,
      strikethrough = line.used or false,
      selected = (i == M.cursor),
      action = 'list_line',
    }
  end
  local next_line = queue.peek_next_unused()
  local remaining = queue.remaining_count()
  local total = #(M.script.lines or {})
  local status_text
  if total == 0 then
    status_text = 'لا يوجد نص — ألصق أو استورد نص الفصل أدناه'
  else
    status_text = 'التالي: ' .. (next_line and next_line.text or '— انتهى التوزيع')
  end
  return {
    title = 'ترجمة وتوزيع',
    items = {
      { kind = 'counter', label = 'متبقٍ', count = remaining },
      { kind = 'label', text = status_text },
      { kind = 'button', text = 'وزّع التالي ←', primary = true, action = 'distribute_next' },
      { kind = 'nav_row' },
      { kind = 'list', id = 'lines', items = lines_rendered },
      { kind = 'toggle', label = 'الوضع الأوتوماتيكي', value = M.auto_mode, action = 'toggle_auto' },
      { kind = 'toggle', label = 'حجم خط تلقائي', value = M.font_fit, action = 'toggle_font_fit' },
      { kind = 'label', text = '── إدخال النص ──' },
      { kind = 'button', text = 'فتح محرر نص الفصل', primary = true, action = 'open_script_editor' },
      { kind = 'button', text = 'استيراد من ملف', action = 'import_file' },
      { kind = 'button', text = 'إنشاء ملف قالب', action = 'write_template_file' },
    },
  }
end

return M
