-- typesetting/fit.lua
-- مُساعد قرار ملاءمة الخط (§6 من typesetting-extension.md).
--
-- يُحمَّل من المضيف عبر `loadExtensionFile(slug='typesetting_fit')` ويُوضع
-- على `_G.typesetting_fit` ليقرأه `init.lua` عبر `rawget(_G, 'typesetting_fit')`.
--
-- **ملاحظة**: القرار الفعلي للملاءمة يُنفّذه المضيف عبر `api.font.fit` باستعمال
-- `TextPainter` (binary search على أكبر `fontSize` يلائم الصندوق). هذا الملف
-- يقدّم فقط **ملاءمة تقديرية** للوا — مفيدة عند الاختبارات المعزولة لـ init.

local F = {}

-- fit = (text, width_pts, height_pts, padding_pts) -> {fontSize, too_small}.
-- جسم التنفيذ: تناسب الخط صندوق صغير جداً => علامة «الصندوق صغير جداً».
function F.fit(text, width_pts, height_pts, padding)
  padding = padding or 6.0
  local usable_w = (width_pts or 0) - 2 * padding
  local usable_h = (height_pts or 0) - 2 * padding
  if usable_w <= 0 or usable_h <= 0 then
    return { fontSize = 8.0, too_small = true }
  end
  -- تقدير سريع: حجم الخط يساوي نصف ارتفاع الصندوق القابل للاستعمال،
  -- مشدوداً بين 8 و 96. هذا تقدير تقريبي بديل لما يفعله TextPainter (المضيف).
  local fs = math.max(8.0, math.min(usable_h * 0.9, 96.0))
  -- كذلك لا يتجاوز العرض التقريبي: حجم الخط ≈ usable_w / (#chars * 0.6).
  local nchars = string.len(text or '')
  if nchars > 0 then
    local max_by_width = usable_w / (nchars * 0.6)
    fs = math.min(fs, max_by_width)
  end
  fs = math.max(fs, 8.0)
  local too_small = fs < 10.0 and (nchars > 0)
  return { fontSize = fs, too_small = too_small }
end

return F
