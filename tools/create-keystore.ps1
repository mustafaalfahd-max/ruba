<#
.SYNOPSIS
  ينشئ مفتاح توقيع «ربى» ويربطه بالمشروع.

.DESCRIPTION
  يسألك عن كلمتَي المرور بإدخال مخفي، ينشئ ملف .jks، ثم يكتب
  android/key.properties المستبعَد من git.

  شغّله مرة واحدة فقط. بعدها كل `flutter build apk --release` يوقّع بمفتاحك.

  ⚠ احتفظ بنسخة من ملف .jks وكلمتَي مروره خارج هذا الحاسوب.
    ضياعه يعني استحالة إصدار أي تحديث لهذا التطبيق إلى الأبد،
    ولن يكون أمام من ثبّته إلا حذفه وفقدان بياناته.

.EXAMPLE
  .\tools\create-keystore.ps1
  .\tools\create-keystore.ps1 -KeystorePath "D:\keys\ruba-release.jks"
#>
param(
    [string]$KeystorePath = "$env:USERPROFILE\keys\ruba-release.jks",
    [string]$Alias = 'ruba',
    [int]$ValidityDays = 10000
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# keytool يأتي مع جافا. نفضّل جافا المضبوطة للمشروع على أي جافا أخرى في PATH.
$gradleProps = Join-Path $root 'android\gradle.properties'
$javaHome = $null
if (Test-Path $gradleProps) {
    $line = Select-String -Path $gradleProps -Pattern '^\s*org\.gradle\.java\.home\s*=\s*(.+)$' |
        Select-Object -First 1
    if ($line) { $javaHome = $line.Matches[0].Groups[1].Value.Trim() -replace '\\:', ':' -replace '\\\\', '\' }
}
$keytool = if ($javaHome -and (Test-Path (Join-Path $javaHome 'bin\keytool.exe'))) {
    Join-Path $javaHome 'bin\keytool.exe'
}
else {
    (Get-Command keytool -ErrorAction SilentlyContinue).Source
}
if (-not $keytool) { throw 'لم يُعثر على keytool — ثبّت JDK أو اضبط org.gradle.java.home' }

if (Test-Path $KeystorePath) {
    throw "الملف موجود مسبقاً: $KeystorePath`nلا تُنشئ مفتاحاً جديداً فوق القديم — ستفقد القدرة على تحديث النسخ الموقّعة به."
}

Write-Host ''
Write-Host 'إنشاء مفتاح توقيع «ربى»' -ForegroundColor Cyan
Write-Host "  الملف   : $KeystorePath"
Write-Host "  الاسم   : $Alias"
Write-Host "  الصلاحية: $ValidityDays يوماً (نحو $([math]::Round($ValidityDays/365)) سنة)"
Write-Host ''
Write-Host 'اختر كلمة مرور قوية واحفظها في مدير كلمات المرور — لا في ملف نصي.' -ForegroundColor Yellow
Write-Host ''

$p1 = Read-Host 'كلمة المرور' -AsSecureString
$p2 = Read-Host 'أعد كتابتها' -AsSecureString

$plain1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
$plain2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))

try {
    if ($plain1 -ne $plain2) { throw 'كلمتا المرور غير متطابقتين' }
    if ($plain1.Length -lt 8) { throw 'كلمة المرور قصيرة — 8 محارف على الأقل (keytool يرفض ما دونها)' }

    $dir = Split-Path -Parent $KeystorePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }

    $dname = 'CN=Ruba, OU=Ruba, O=Ruba, L=Baghdad, C=IQ'
    & $keytool -genkeypair -v `
        -keystore $KeystorePath `
        -alias $Alias `
        -keyalg RSA -keysize 2048 `
        -validity $ValidityDays `
        -dname $dname `
        -storepass $plain1 -keypass $plain1
    if ($LASTEXITCODE -ne 0) { throw 'فشل إنشاء المفتاح' }

    # كلمة المرور نفسها للملف وللمفتاح — يبسّط الإدارة ولا يقلّل الحماية،
    # فمن يملك الملف وكلمة مروره يملك المفتاح على أي حال.
    $propsPath = Join-Path $root 'android\key.properties'
    $storeForGradle = $KeystorePath -replace '\\', '/'
    @"
storeFile=$storeForGradle
storePassword=$plain1
keyAlias=$Alias
keyPassword=$plain1
"@ | Out-File $propsPath -Encoding utf8 -NoNewline

    Write-Host ''
    Write-Host 'تم.' -ForegroundColor Green
    Write-Host "  المفتاح   : $KeystorePath"
    Write-Host "  الربط     : android/key.properties (مستبعَد من git)"
    Write-Host ''
    Write-Host 'الخطوة التالية — انسخ ملف .jks إلى مكان آمن خارج هذا الحاسوب:' -ForegroundColor Yellow
    Write-Host "  $KeystorePath"
    Write-Host ''
    Write-Host 'ثم ابنِ وانشر:'
    Write-Host '  flutter build apk --release --split-per-abi --target-platform android-arm64'
    Write-Host '  .\tools\publish-update.ps1 -Changelog "الإصدار الأول"'
}
finally {
    # نمسح كلمة المرور من الذاكرة بعد الانتهاء.
    $plain1 = $null; $plain2 = $null
    [GC]::Collect()
}
