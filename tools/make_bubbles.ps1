# generates transparent manga speech-bubble PNGs for the bubbles-arabic pack
# usage: .\tools\make_bubbles.ps1
# outputs: packages/bubbles-arabic/images/*.png + icon.png (512x512, transparent bg)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outDir = Join-Path $PSScriptRoot '..\packages\bubbles-arabic'
$imgDir = Join-Path $outDir 'images'
New-Item -ItemType Directory -Path $imgDir -Force | Out-Null

function New-BubbleCanvas([int]$W, [int]$H) {
  $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)
  return @($bmp, $g)
}

function Close-BubbleCanvas($ctx, [string]$OutPath) {
  $ctx[1].Dispose()
  $ctx[0].Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $ctx[0].Dispose()
}

# speech bubble: rounded rect with an integrated tail (single GraphicsPath).
function New-RectBubble {
  param([string]$OutPath, [int]$W, [int]$H, [float]$X, [float]$Y, [float]$BW, [float]$BH,
        [float]$Radius, [float]$TailX, [float]$TailY, [int]$TailW, [string]$Side = 'bottom',
        [int]$Stroke = 6)
  $ctx = New-BubbleCanvas $W $H
  $bmp = $ctx[0]; $g = $ctx[1]
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $R = [Math]::Min($Radius, [Math]::Min($BW / 2, $BH / 2))
  $path.AddLine($X + $R, $Y, $X + $BW - $R, $Y)
  $path.AddArc($X + $BW - 2 * $R, $Y, 2 * $R, 2 * $R, 270, 90)
  $path.AddLine($X + $BW, $Y + $R, $X + $BW, $Y + $BH - $R)
  $path.AddArc($X + $BW - 2 * $R, $Y + $BH - 2 * $R, 2 * $R, 2 * $R, 0, 90)
  if ($Side -eq 'bottom') {
    $mouthR = [Math]::Min($TailX + $TailW / 2, $X + $BW - $R)
    $mouthL = [Math]::Max($TailX - $TailW / 2, $X + $R)
    $path.AddLine($X + $BW - $R, $Y + $BH, $mouthR, $Y + $BH)
    $path.AddLine($mouthR, $Y + $BH, $TailX, $TailY)
    $path.AddLine($TailX, $TailY, $mouthL, $Y + $BH)
    $path.AddLine($mouthL, $Y + $BH, $X + $R, $Y + $BH)
  } else {
    $mouthR = [Math]::Min($TailX + $TailW / 2, $X + $BW - $R)
    $mouthL = [Math]::Max($TailX - $TailW / 2, $X + $R)
    $path.AddLine($X + $BW - $R, $Y, $mouthR, $Y)
    $path.AddLine($mouthR, $Y, $TailX, $TailY)
    $path.AddLine($TailX, $TailY, $mouthL, $Y)
    $path.AddLine($mouthL, $Y, $X + $R, $Y)
  }
  $path.AddArc($X, $Y + $BH - 2 * $R, 2 * $R, 2 * $R, 90, 90)
  $path.CloseFigure()

  $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 20, 20, 25)), $Stroke
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.FillPath($fill, $path)
  $g.DrawPath($pen, $path)
  $fill.Dispose(); $pen.Dispose(); $path.Dispose()
  Close-BubbleCanvas $ctx $OutPath
}

# thought bubble: big circle + trailing smaller circles
function New-ThoughtBubble {
  param([string]$OutPath, [int]$W, [int]$H, [int]$Stroke = 6)
  $ctx = New-BubbleCanvas $W $H
  $bmp = $ctx[0]; $g = $ctx[1]
  $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 20, 20, 25)), $Stroke
  foreach ($c in @(@(305, 205, 150), @(185, 380, 34), @(135, 430, 24), @(100, 465, 15))) {
    $e = New-Object System.Drawing.Rectangle ($c[0] - $c[2]), ($c[1] - $c[2]), (2 * $c[2]), (2 * $c[2])
    $g.FillEllipse($fill, $e)
    $g.DrawEllipse($pen, $e)
  }
  $fill.Dispose(); $pen.Dispose()
  Close-BubbleCanvas $ctx $OutPath
}

# shout bubble: jagged polygon + tail on the left
function New-ShoutBubble {
  param([string]$OutPath, [int]$W, [int]$H, [int]$Stroke = 6)
  $ctx = New-BubbleCanvas $W $H
  $bmp = $ctx[0]; $g = $ctx[1]
  $pts = @(
    @(30, 70), @(80, 40), @(120, 75), @(165, 45), @(210, 80), @(255, 50),
    @(300, 82), @(345, 52), @(390, 78), @(440, 50), @(475, 80), @(482, 100),
    @(475, 320), @(335, 320), @(290, 420), @(245, 320), @(60, 320), @(30, 70)
  )
  $poly = New-Object System.Drawing.Drawing2D.GraphicsPath
  $poly.AddPolygon([System.Drawing.Point[]]($pts | ForEach-Object { New-Object System.Drawing.Point $_[0], $_[1] }))
  $poly.CloseFigure()
  $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 20, 20, 25)), $Stroke
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.FillPath($fill, $poly)
  $g.DrawPath($pen, $poly)
  $fill.Dispose(); $pen.Dispose(); $poly.Dispose()
  Close-BubbleCanvas $ctx $OutPath
}

New-RectBubble -OutPath (Join-Path $imgDir 'bubble_round.png') -W 512 -H 512 -X 76 -Y 56 -BW 360 -BH 300 -Radius 90 -TailX 256 -TailY 452 -TailW 90
New-RectBubble -OutPath (Join-Path $imgDir 'bubble_rect.png') -W 512 -H 512 -X 46 -Y 66 -BW 420 -BH 300 -Radius 24 -TailX 396 -TailY 470 -TailW 110
New-RectBubble -OutPath (Join-Path $imgDir 'bubble_oval.png') -W 512 -H 512 -X 66 -Y 76 -BW 380 -BH 250 -Radius 125 -TailX 256 -TailY 452 -TailW 70
New-RectBubble -OutPath (Join-Path $imgDir 'bubble_tail_top.png') -W 512 -H 512 -X 56 -Y 110 -BW 400 -BH 320 -Radius 55 -TailX 256 -TailY 62 -TailW 70 -Side top
New-ThoughtBubble -OutPath (Join-Path $imgDir 'bubble_thought.png') -W 512 -H 512
New-ShoutBubble -OutPath (Join-Path $imgDir 'bubble_shout.png') -W 512 -H 512

# pack icon: small bubble glyph
New-RectBubble -OutPath (Join-Path $outDir 'icon.png') -W 32 -H 32 -X 4 -Y 4 -BW 24 -BH 18 -Radius 8 -TailX 17 -TailY 27 -TailW 8 -Stroke 2

Write-Host "generated $((Get-ChildItem $imgDir).Count) bubbles + icon at $outDir"
