-- watermark/init.lua — علامة مائية.
--
-- 1) stamp: نص العلامة عبر api.tool.textAdd داخل group (تراجع واحد).
-- 2) style: يقرأ اللوحة من ctx.layers (doc:read) ليجد طبقة النص، ثم
--    يطبق شفافية وقفل عبر api.layers.* داخل group.
-- 3) save: حفظ وصف العلامة عبر api.io.write_text (export:write).
--
-- دورة حقيقية: إضافة تُنشأ خارج التطبيق، تتحكم بأدوات النص والطبقات
-- وتُحفظ — بلا أي تعديل على رمز المحرر.

local M = {}

M.name = 'watermark'
function M.on_startup(_ctx) return true end
function M.on_open(_ctx) return true end
function M.on_close(_ctx) return true end
function M.on_event(_ctx, event, payload) return true end

function M.ui_state(ctx)
  return {
    title = 'علامة مائية',
    visible = true,
    items = {
      { kind = 'label', text = 'ضع علامة المحرر' },
      { kind = 'button', label = 'ختم + نمط', action = 'stamp_style' },
    },
  }
end

function M.handle_action(ctx, action, args)
  if action == 'stamp_style' then
    M.stamp(ctx, '© HunterToon')
    return M.style_it(ctx, 0.35, true)
  end
  return true
end

-- يضيف النص كطبقة علامة في «تراجع واحد».
function M.stamp(ctx, text)
  api.history.group('watermark.stamp')
  api.tool.textAdd({
    rect = { x = 60, y = 220, width = 180, height = 40 },
    text = text,
    color = '#ffffff',
    fontSize = 18,
    align = 'center',
  })
  api.history.end_group()
  return true
end

-- يقرأ ctx.layers ليجد طبقة النص ثم يطبق القفل والشفافية في «تراجع واحد».
function M.style_it(ctx, opacity, lock)
  local layerId = nil
  for _, l in ipairs(ctx.layers or {}) do
    if l.type == 'text' then layerId = l.id end
  end
  if layerId == nil then return false end

  api.history.group('watermark.style')
  api.layers.set_opacity({ id = layerId, opacity = opacity })
  api.layers.set_locked({ id = layerId, locked = lock })
  api.history.end_group()
  return true
end

-- يحفظ وصف العلامة (وثيقة نصية عبر api.io.write_text).
function M.save(ctx, text)
  api.io.write_text({ name = 'watermark.txt', content = text or 'watermark' })
  return true
end

-- دورة تراجع/إعادة كاملة.
function M.toggle_undo()
  api.history.undo()
  api.history.redo()
  return true
end

return M