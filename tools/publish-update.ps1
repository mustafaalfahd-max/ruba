<#
.SYNOPSIS
  ينشر إصداراً جديداً من «ربى» على GitHub، فيصل التحديث إلى الهاتف تلقائياً.

.DESCRIPTION
  الخطوات التي ينفّذها:
    1. يبني APK لمعمارية arm64 (نحو 21 م.ب بدل 55).
    2. ينشئ GitHub Release بوسم v<الإصدار> ويرفع الـ APK كأصل فيه.
    3. يكتب updates/version.json ويدفعه إلى الفرع الرئيسي.

  التطبيق يقرأ version.json من الفرع الرئيسي مباشرةً، فالعنوان في الهاتف ثابت
  ولا يتغيّر مع كل نشر:
    https://raw.githubusercontent.com/<المستخدم>/<المستودع>/main/updates/version.json

  ترتيب الخطوات مقصود: يُرفع الـ APK قبل نشر البيان، حتى لا يرى التطبيق إصداراً
  رابطه لا يعمل بعد.

  قبل التشغيل: ارفع رقم الإصدار في pubspec.yaml — الرقم بعد + هو ما يقارنه التطبيق.

.EXAMPLE
  .\tools\publish-update.ps1 -Changelog "إصلاح تنبيه الجرعات","تسريع فتح السجل"
#>
param(
    # أسطر «ما الجديد» التي تظهر داخل التطبيق.
    [string[]]$Changelog = @(),

    # اجعله true لو أردت إبراز التحديث كإلزامي.
    [switch]$Mandatory,

    # تخطَّ البناء واستعمل آخر APK موجود.
    [switch]$SkipBuild,

    # جهّز كل شيء محلياً واعرض ما سيحدث بلا رفع.
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if ($root -match '[^\x00-\x7F]') {
    throw "مسار المشروع يحوي حروفاً غير إنجليزية:`n  $root`n" +
          'أدوات Flutter الأصلية (gen_snapshot و impellerc) تفشل معه. انقل المشروع إلى مسار إنجليزي كامل.'
}

foreach ($cmd in @('flutter', 'git', 'gh')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "الأمر '$cmd' غير موجود في PATH" }
}

Push-Location $root
try {
    # ── رقم الإصدار من pubspec.yaml ────────────────────────────────────────
    $pubspec = Get-Content 'pubspec.yaml' -Raw -Encoding UTF8
    if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$') {
        throw 'تعذّرت قراءة رقم الإصدار من pubspec.yaml (المتوقع مثل: version: 1.1.0+2)'
    }
    $versionName = $Matches[1]
    $versionCode = [int]$Matches[2]
    $tag = "v$versionName"

    # ── معلومات المستودع ───────────────────────────────────────────────────
    $slug = (& gh repo view --json nameWithOwner --jq .nameWithOwner)
    if ($LASTEXITCODE -ne 0 -or -not $slug) { throw 'تعذّرت قراءة معلومات المستودع — تأكد أن المجلد مرتبط بمستودع GitHub' }
    $branch = (& git rev-parse --abbrev-ref HEAD).Trim()

    if ((& gh release view $tag --json tagName 2>$null) -and -not $DryRun) {
        Write-Host "تنبيه: الوسم $tag موجود مسبقاً — سيُستبدل ملف APK داخله." -ForegroundColor Yellow
    }

    # ── البناء ─────────────────────────────────────────────────────────────
    $apkBuilt = 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
    if (-not $SkipBuild) {
        Write-Host "بناء الإصدار $versionName ($versionCode)…" -ForegroundColor Cyan
        & flutter build apk --release --split-per-abi --target-platform android-arm64
        if ($LASTEXITCODE -ne 0) { throw 'فشل بناء APK' }
    }
    if (-not (Test-Path $apkBuilt)) { throw "لم يُعثر على $apkBuilt" }

    $outDir = Join-Path $root 'dist'
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory $outDir | Out-Null }
    $apkName = "ruba-$versionName.apk"
    $apkOut = Join-Path $outDir $apkName
    Copy-Item $apkBuilt $apkOut -Force

    $hash = (Get-FileHash $apkOut -Algorithm SHA256).Hash.ToLower()
    $sizeMb = [math]::Round((Get-Item $apkOut).Length / 1MB, 1)

    # ── بيان الإصدار ───────────────────────────────────────────────────────
    $manifest = [ordered]@{
        versionCode = $versionCode
        versionName = $versionName
        apkUrl      = "https://github.com/$slug/releases/download/$tag/$apkName"
        sha256      = $hash
        changelog   = @($Changelog)
        mandatory   = [bool]$Mandatory
    }
    $updatesDir = Join-Path $root 'updates'
    if (-not (Test-Path $updatesDir)) { New-Item -ItemType Directory $updatesDir | Out-Null }
    $jsonPath = Join-Path $updatesDir 'version.json'
    $manifest | ConvertTo-Json -Depth 4 | Out-File $jsonPath -Encoding utf8

    $manifestUrl = "https://raw.githubusercontent.com/$slug/$branch/updates/version.json"

    if ($DryRun) {
        Write-Host ''
        Write-Host 'تجربة بلا رفع. ما كان سيُنشر:' -ForegroundColor Yellow
        Write-Host "  الوسم       : $tag"
        Write-Host "  الملف       : $apkName ($sizeMb م.ب)"
        Write-Host "  البصمة      : $hash"
        Write-Host "  عنوان البيان: $manifestUrl"
        return
    }

    # ── الرفع: الأصل أولاً ثم البيان ───────────────────────────────────────
    $notes = if ($Changelog.Count) { ($Changelog | ForEach-Object { "- $_" }) -join "`n" } else { "الإصدار $versionName" }

    if (& gh release view $tag --json tagName 2>$null) {
        Write-Host "رفع APK إلى الإصدار الموجود $tag…" -ForegroundColor Cyan
        & gh release upload $tag $apkOut --clobber
    }
    else {
        Write-Host "إنشاء الإصدار $tag ورفع APK…" -ForegroundColor Cyan
        & gh release create $tag $apkOut --title "ربى $versionName" --notes $notes
    }
    if ($LASTEXITCODE -ne 0) { throw 'فشل رفع الإصدار إلى GitHub' }

    Write-Host 'نشر بيان الإصدار…' -ForegroundColor Cyan
    & git add 'updates/version.json'
    & git commit -m "نشر الإصدار $versionName ($versionCode)" | Out-Null
    & git push origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'فشل دفع version.json — ادفعه يدوياً' }

    Write-Host ''
    Write-Host "تم نشر الإصدار $versionName" -ForegroundColor Green
    Write-Host "  $apkName ($sizeMb م.ب)"
    Write-Host "  https://github.com/$slug/releases/tag/$tag"
    Write-Host ''
    Write-Host 'العنوان المضبوط داخل التطبيق (لا يتغيّر مع الإصدارات):' -ForegroundColor Yellow
    Write-Host "  $manifestUrl"
    Write-Host ''
    Write-Host 'قد يتأخر ظهور التحديث دقيقة أو دقيقتين بسبب تخزين raw.githubusercontent المؤقت.'
}
finally {
    Pop-Location
}
