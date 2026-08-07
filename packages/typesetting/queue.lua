-- typesetting/queue.lua
-- عقل صفّ توزيع الأسطر (§4 من typesetting-extension.md).
--
-- يُحمَّل من المضيف عبر `loadExtensionFile(slug='typesetting_queue')`، ويُوضع
-- على `_G.typesetting_queue` ليقرأه `init.lua` عبر `rawget(_G, 'typesetting_queue')`.
--
-- **cache فقط (P5)**: مصدر الحقيقة للحالة "مستخدم" هو المسح الكامل لعناصر
-- الصفحات في المضيف (`TypesettingUsedStateAnalyzer`). هذا التنفيذ يدير
-- cache محلي لاتخاذ قرارات سريعة. التزامن مع المسح يجري في `on_open` عبر
-- `used_state.ready` (كل سطر `used` يُضبط منه).

local Q = { lines = {}, boxes = {}, used = {} }

-- إعادة تعطيل الصفّ بسيناريو جديد (قائمة {id, seq, text}).
function Q.reset(lines)
  Q.lines = lines or {}
  Q.boxes = {}
  -- `used` تُبنى لاحقاً من `used_state.ready`؛ نُصفّر الآن فقط.
  Q.used = {}
  for _, line in ipairs(Q.lines) do
    line.used = line.used or false
  end
end

-- أعطِ سطراً بـ seq الأدنى غير مستعمل، أو `nil` إذا استُ عملوا كلهم.
-- هذا يلتزم بترتيب `seq` (ترتيب الإنشاء في المضيف = ترتيب التوزيع).
-- **ملاحظة**: نحافظ على تثبيت `used` على كائن السطر نفسه (مرجع مشترك مع
-- القائمة في `init.lua`).
function Q.pop_next_unused()
  local best = nil
  for _, line in ipairs(Q.lines) do
    if not (line.used or false) then
      if not best or (line.seq or 0) < (best.seq or 0) then
        best = line
      end
    end
  end
  return best
end

-- نفس pop_next_unused لكن دون تعليم used — للمعاينة.
function Q.peek_next_unused()
  local best = nil
  for _, line in ipairs(Q.lines) do
    if not (line.used or false) then
      if not best or (line.seq or 0) < (best.seq or 0) then
        best = line
      end
    end
  end
  return best
end

-- عدّ الأسطر غير المستعملة.
function Q.remaining_count()
  local n = 0
  for _, line in ipairs(Q.lines) do
    if not (line.used or false) then n = n + 1 end
  end
  return n
end

-- علّم سطراً بأنه مستعمل في صندوق بعد توزيع الفعل `api.commands.distribute`.
function Q.mark_used(line, boxId)
  if not line then return end
  line.used = true
  Q.used[boxId] = line.id
end

-- إسناد يدوي لسطر محدّد على صندوق:
-- يُحرّر السطر القديم للصندوق إن كان به سطر، ثم يضع السطر الجديد.
function Q.assign(lineId, boxId)
  -- ابحث عن السطر.
  local line = nil
  for _, l in ipairs(Q.lines) do
    if l.id == lineId then line = l; break end
  end
  if not line then return false end
  -- ابحث عن صندوق آخر يحمل نفس السطر وحرّره.
  for bid, lid in pairs(Q.used) do
    if lid == lineId and bid ~= boxId then
      Q.used[bid] = nil
      -- لاحظ: السطر القديم للصندوق المُسند إليه الآن سيُحرّر أدناه.
    end
  end
  -- إن كان الصندوق يحمل سطراً مختلفاً، حرّره.
  local old = Q.used[boxId]
  if old and old ~= lineId then
    for _, l in ipairs(Q.lines) do
      if l.id == old then l.used = false; break end
    end
  end
  line.used = true
  Q.used[boxId] = lineId
  return true
end

-- تحرير إسناد: يُحرّر سطراً من صندوق.
function Q.unassign(lineId, boxId)
  if Q.used[boxId] == lineId then
    Q.used[boxId] = nil
    for _, l in ipairs(Q.lines) do
      if l.id == lineId then l.used = false; break end
    end
    return true
  end
  -- الحالة المستنتجة من المسح تتفوّق: إن لم يكن الـ cache متزامناً، فلا مضرّ.
  return false
end

function Q.on_box_created(boxId, seq)
  if not boxId then return end
  Q.boxes[boxId] = { seq = seq or 0 }
end

function Q.on_box_deleted(boxId, wasFilled)
  if not boxId then return end
  local lid = Q.used[boxId]
  if lid then
    for _, l in ipairs(Q.lines) do
      if l.id == lid then l.used = false; break end
    end
    Q.used[boxId] = nil
  end
  Q.boxes[boxId] = nil
  if wasFilled then
    api.log('debug', 'typesetting: box deleted — line freed: ' .. tostring(lid))
  end
end

return Q
