-- scripted-brush/init.lua — فرشاة مبرمجة.
--
-- ترسم «مشطاً» من n ضربات معتمدة على نقطة البداية، كلها داخل group واحد
-- → Undo واحد يمحو النمط كاملاً. تقود أداة الفرشاة من لوا بلا لمسة
-- لاستخدام المتجر، وتدعم أتمتة run والمعالجات القياسية.

local M = {}

M.name = 'scripted-brush'
M.author = 'HunterToon'

function M.on_startup(_ctx) return true end
function M.on_open(_ctx) return true end
function M.on_close(_ctx) return true end
function M.on_event(_ctx, event, payload) return true end

function M.ui_state(ctx)
  return {
    title = 'فرشاة مبرمجة',
    visible = true,
    items = {
      { kind = 'label', text = 'نمط مشط' },
      { kind = 'button', label = 'ارسم المشط', action = 'paint_comb' },
    },
  }
end

function M.handle_action(ctx, action, args)
  if action == 'paint_comb' then
    M.paint_comb(7)
  end
  return true
end

-- نمط مشط: n ضربات متوازيات بزاوية 45°، كلها داخل group واحدة.
function M.paint_comb(n)
  api.history.group('مشط مبرمج')
  local count = n or 6
  for i = 1, count do
    local x = (i - 1) * 12
    api.tool.stroke({
      target = 'brush',
      points = { { x = x, y = 0 }, { x = x + 8, y = 30 } },
      color = '#303080',
      size = 3,
      opacity = 1.0,
    })
  end
  api.history.end_group()
  return true
end

-- دورة تراجع/إعادة (تتحقق من التراجع المجمّع).
function M.toggle_undo()
  api.history.undo()
  api.history.redo()
  return true
end

return M