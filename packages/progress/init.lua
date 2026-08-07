-- ============================================================
-- مؤشر التقدم (progress) — إضافة تجريبية خارجية لمتجر HunterToon
-- ============================================================
-- عقد الإضافة (راجع store/README.md):
--   * init.lua يُرجع جدولاً يُسجَّل على `_G.progress` تلقائياً.
--   * on_open(ctx) / on_close(ctx): دورة حياة الجلسة.
--   * handle_action(ctx, action, args): كل ضغطة زر/صف في اللوحة.
--   * ui_state(ctx): يُرجع { items = {...} } — اللوحة ترسمه من Dart.
-- كل شيء في ملف واحد: أي إضافة خارجية لا تحتاج سوى manifest.json +
-- init.lua (+ icon.png اختيارية) داخل مجلد، يُضغَّط ZIP ويُرفع للمتجر.

local state = { done = 0, log = {} }

local M = {}

function M.on_open(ctx)
  api.log('info', 'progress: opened')
end

function M.on_close(ctx)
  api.log('info', 'progress: closed')
end

function M.handle_action(ctx, action, args)
  if action == 'inc' then
    state.done = state.done + 1
    table.insert(state.log, 1, { text = 'أنجزت صفحة (+1)', id = #state.log + 1 })
  elseif action == 'dec' then
    if state.done > 0 then
      state.done = state.done - 1
      table.insert(state.log, 1, { text = 'تراجعت صفحة (-1)', id = #state.log + 1 })
    end
  elseif action == 'reset' then
    state.done = 0
    state.log = {}
    api.emit('progress.reset', { done = 0 })
  end
end

function M.ui_state(ctx)
  local items = {
    { kind = 'label', text = 'تتبع إنجازك في الفصل الحالي' },
    { kind = 'counter', label = 'صفحات منجزة', count = state.done },
    { kind = 'button', text = '+1 صفحة', action = 'inc', primary = true },
    { kind = 'button', text = '-1 صفحة', action = 'dec' },
    { kind = 'button', text = 'تصفير', action = 'reset' },
  }
  if #state.log > 0 then
    local rows = {}
    for i, e in ipairs(state.log) do
      rows[i] = { text = e.text, id = tostring(e.id) }
    end
    table.insert(items, { kind = 'list', label = 'سجل الإجراءات', items = rows })
  end
  return { items = items }
end

return M
