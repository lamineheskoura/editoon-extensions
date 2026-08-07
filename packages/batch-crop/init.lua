-- batch-crop/init.lua — قص بالجملة.
--
-- يقصّ صفحة عبر أربعة أرباع (أتمتة api.tool.crop). كل عملية قص تسجل
-- أمر قص قابل للتراجع في محرك القص على جانب المضيف — التراجع/الإعادة
-- يمران عبر api.history.*.

local M = {}

M.name = 'batch-crop'
function M.on_startup(_ctx) return true end
function M.on_open(_ctx) return true end
function M.on_close(_ctx) return true end
function M.on_event(_ctx, event, payload) return true end

function M.ui_state(ctx)
  return {
    title = 'قص بالجملة',
    visible = true,
    items = {
      { kind = 'label', text = '4 أرباع تلقائية' },
      { kind = 'button', label = 'قص الأرباع', action = 'crop_quads' },
    },
  }
end

function M.handle_action(ctx, action, args)
  if action == 'crop_quads' then M.crop_quads() end
  return true
end

-- يقصّ أربعة أرباع (افتراضياً هامش 4و×4).
function M.crop_quads()
  api.tool.crop({ rect = { x = 0, y = 0, w = 4, h = 4 } })
  api.tool.crop({ rect = { x = 0, y = 4, w = 4, h = 4 } })
  api.tool.crop({ rect = { x = 4, y = 0, w = 4, h = 4 } })
  api.tool.crop({ rect = { x = 4, y = 4, w = 4, h = 4 } })
  return true
end

-- أتمتة: عدد معين من القصات المستقلة.
function M.run(count)
  local n = count or 2
  for i = 1, n do
    api.tool.crop({ rect = { x = i, y = i, w = 2, h = 2 } })
  end
  return true
end

-- يرجع لآخر قص (تراجع واحد).
function M.undo_last()
  api.history.undo()
  return true
end

return M