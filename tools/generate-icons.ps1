<#
.SYNOPSIS
  يولّد أيقونة «ربى» بكل الأحجام التي يحتاجها أندرويد.

.DESCRIPTION
  الأيقونة مرسومة برمجياً لا مستوردة كصورة، فتبقى حادة في كل كثافة شاشة،
  ويمكن تعديل ألوانها أو أبعادها من هنا وإعادة التوليد بأمر واحد.

  التصميم: زجاجة رضاعة بيضاء صمّاء على خلفية تركوازية (#0088B0) بلون التطبيق،
  مع علامتَي تدريج. الشكل الصمّاء مقصود — التفاصيل الرفيعة تختفي عند 48 بكسل.

  ينتج:
    mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png        الأيقونة القديمة (مربع مستدير)
    mipmap-{...}/ic_launcher_round.png                 الأيقونة الدائرية
    playstore-icon.png                                 512×512 للعرض والتوثيق

  أما أيقونة أندرويد 8+ التكيّفية فمرسومة كـ vector في res/drawable
  ولا يولّدها هذا السكربت.

.EXAMPLE
  .\tools\generate-icons.ps1
#>
param(
    [string]$Background = '#0088B0',
    [string]$Foreground = '#FFFFFF',
    [string]$Tick = '#0088B0'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$resDir = Join-Path $root 'android\app\src\main\res'

# كل الإحداثيات في شبكة 108×108 — نفس شبكة أيقونات أندرويد التكيّفية،
# فيبقى الشكلان متطابقين بين الأيقونة القديمة والحديثة.
$GRID = 108.0

function ConvertTo-Color([string]$hex) {
    [System.Drawing.ColorTranslator]::FromHtml($hex)
}

function Add-RoundedRect {
    param(
        [System.Drawing.Drawing2D.GraphicsPath]$Path,
        [double]$X, [double]$Y, [double]$W, [double]$H, [double]$R, [double]$S
    )
    $x = $X * $S; $y = $Y * $S; $w = $W * $S; $h = $H * $S; $d = [Math]::Min($R * $S * 2, [Math]::Min($w, $h))
    $Path.AddArc([float]$x, [float]$y, [float]$d, [float]$d, 180, 90)
    $Path.AddArc([float]($x + $w - $d), [float]$y, [float]$d, [float]$d, 270, 90)
    $Path.AddArc([float]($x + $w - $d), [float]($y + $h - $d), [float]$d, [float]$d, 0, 90)
    $Path.AddArc([float]$x, [float]($y + $h - $d), [float]$d, [float]$d, 90, 90)
    $Path.CloseFigure()
}

function New-Icon {
    param([int]$Size, [ValidateSet('square', 'circle')][string]$Shape)

    $s = $Size / $GRID
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # ── الخلفية ────────────────────────────────────────────────────────────
    $bgPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    if ($Shape -eq 'circle') {
        $bgPath.AddEllipse(0, 0, $Size, $Size)
    }
    else {
        # نصف قطر 22% يقارب شكل أيقونات أندرويد الحديثة
        Add-RoundedRect -Path $bgPath -X 0 -Y 0 -W $GRID -H $GRID -R 24 -S $s
    }
    $bgBrush = New-Object System.Drawing.SolidBrush((ConvertTo-Color $Background))
    $g.FillPath($bgBrush, $bgPath)

    # ── الزجاجة ────────────────────────────────────────────────────────────
    # ثلاثة مستطيلات مستديرة متداخلة: الحلمة، الطوق، الجسم.
    # وضع التعبئة Winding يدمجها في شكل واحد صمّاء.
    $bottle = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bottle.FillMode = [System.Drawing.Drawing2D.FillMode]::Winding
    Add-RoundedRect -Path $bottle -X 49 -Y 14 -W 10 -H 20 -R 5 -S $s   # الحلمة
    Add-RoundedRect -Path $bottle -X 42 -Y 30 -W 24 -H 12 -R 4 -S $s   # الطوق
    Add-RoundedRect -Path $bottle -X 37 -Y 40 -W 34 -H 50 -R 9 -S $s   # الجسم
    $fgBrush = New-Object System.Drawing.SolidBrush((ConvertTo-Color $Foreground))
    $g.FillPath($fgBrush, $bottle)

    # ── علامات التدريج ─────────────────────────────────────────────────────
    $ticks = New-Object System.Drawing.Drawing2D.GraphicsPath
    Add-RoundedRect -Path $ticks -X 56 -Y 52 -W 11 -H 3.2 -R 1.6 -S $s
    Add-RoundedRect -Path $ticks -X 56 -Y 62 -W 11 -H 3.2 -R 1.6 -S $s
    Add-RoundedRect -Path $ticks -X 56 -Y 72 -W 11 -H 3.2 -R 1.6 -S $s
    $tickBrush = New-Object System.Drawing.SolidBrush((ConvertTo-Color $Tick))
    $g.FillPath($tickBrush, $ticks)

    $bgBrush.Dispose(); $fgBrush.Dispose(); $tickBrush.Dispose()
    $bgPath.Dispose(); $bottle.Dispose(); $ticks.Dispose()
    $g.Dispose()
    return $bmp
}

$densities = @{
    'mipmap-mdpi'    = 48
    'mipmap-hdpi'    = 72
    'mipmap-xhdpi'   = 96
    'mipmap-xxhdpi'  = 144
    'mipmap-xxxhdpi' = 192
}

foreach ($d in $densities.GetEnumerator() | Sort-Object Value) {
    $dir = Join-Path $resDir $d.Key
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }

    $sq = New-Icon -Size $d.Value -Shape 'square'
    $sq.Save((Join-Path $dir 'ic_launcher.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $sq.Dispose()

    $ci = New-Icon -Size $d.Value -Shape 'circle'
    $ci.Save((Join-Path $dir 'ic_launcher_round.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $ci.Dispose()

    Write-Host ("  {0,-16} {1}×{1}" -f $d.Key, $d.Value)
}

$store = New-Icon -Size 512 -Shape 'square'
$store.Save((Join-Path $root 'playstore-icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$store.Dispose()

# ── أيقونة أندرويد 8+ التكيّفية ────────────────────────────────────────────
# طبقتان منفصلتان يقصّهما النظام بالشكل الذي يختاره المستخدم (دائرة، مربع، قطرة…).
# المنطقة المضمونة الظهور هي 72×72 وسط شبكة 108×108، فنُصغّر الزجاجة لتقع كلها داخلها.

function Get-RoundedRectPath {
    param([double]$X, [double]$Y, [double]$W, [double]$H, [double]$R)
    $r = [Math]::Min($R, [Math]::Min($W, $H) / 2)
    $n = { param($v) [Math]::Round($v, 2) }
    "M{0},{1} H{2} A{3},{3} 0 0 1 {4},{5} V{6} A{3},{3} 0 0 1 {2},{7} H{0} A{3},{3} 0 0 1 {8},{6} V{5} A{3},{3} 0 0 1 {0},{1} Z" -f `
        (& $n ($X + $r)), (& $n $Y), (& $n ($X + $W - $r)), (& $n $r), (& $n ($X + $W)),
        (& $n ($Y + $r)), (& $n ($Y + $H - $r)), (& $n ($Y + $H)), (& $n $X)
}

# نفس أشكال الأيقونة القديمة، مُصغّرة ومركّزة داخل المنطقة المضمونة.
$k = 60.0 / 76.0                      # ارتفاع الزجاجة الأصلي 76 وحدة ← 60
function Move-X([double]$x) { 54 + ($x - 54) * $k }
function Move-Y([double]$y) { 24 + ($y - 14) * $k }
function Scale([double]$v) { $v * $k }

$shapes = @(
    @{ X = 49; Y = 14; W = 10; H = 20; R = 5 }      # الحلمة
    @{ X = 42; Y = 30; W = 24; H = 12; R = 4 }      # الطوق
    @{ X = 37; Y = 40; W = 34; H = 50; R = 9 }      # الجسم
)
$tickShapes = @(
    @{ X = 56; Y = 52; W = 11; H = 3.2; R = 1.6 }
    @{ X = 56; Y = 62; W = 11; H = 3.2; R = 1.6 }
    @{ X = 56; Y = 72; W = 11; H = 3.2; R = 1.6 }
)

$bottlePaths = ($shapes | ForEach-Object {
        $d = Get-RoundedRectPath -X (Move-X $_.X) -Y (Move-Y $_.Y) -W (Scale $_.W) -H (Scale $_.H) -R (Scale $_.R)
        "    <path android:fillColor=`"$Foreground`" android:pathData=`"$d`" />"
    }) -join "`n"

$tickPaths = ($tickShapes | ForEach-Object {
        $d = Get-RoundedRectPath -X (Move-X $_.X) -Y (Move-Y $_.Y) -W (Scale $_.W) -H (Scale $_.H) -R (Scale $_.R)
        "    <path android:fillColor=`"$Tick`" android:pathData=`"$d`" />"
    }) -join "`n"

$drawableDir = Join-Path $resDir 'drawable'
$anyDpiDir = Join-Path $resDir 'mipmap-anydpi-v26'
foreach ($d in @($drawableDir, $anyDpiDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }
}

@"
<?xml version="1.0" encoding="utf-8"?>
<!-- مولَّد بواسطة tools/generate-icons.ps1 — لا تحرّره يدوياً -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="$Background" android:pathData="M0,0 H108 V108 H0 Z" />
</vector>
"@ | Out-File (Join-Path $drawableDir 'ic_launcher_background.xml') -Encoding utf8

@"
<?xml version="1.0" encoding="utf-8"?>
<!-- مولَّد بواسطة tools/generate-icons.ps1 — لا تحرّره يدوياً -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
$bottlePaths
$tickPaths
</vector>
"@ | Out-File (Join-Path $drawableDir 'ic_launcher_foreground.xml') -Encoding utf8

$adaptive = @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"@
$adaptive | Out-File (Join-Path $anyDpiDir 'ic_launcher.xml') -Encoding utf8
$adaptive | Out-File (Join-Path $anyDpiDir 'ic_launcher_round.xml') -Encoding utf8

Write-Host '  mipmap-anydpi-v26  أيقونة تكيّفية (vector)'
Write-Host ''
Write-Host 'تم توليد الأيقونات.' -ForegroundColor Green
