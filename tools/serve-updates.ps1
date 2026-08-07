<#
.SYNOPSIS
  خادم صغير يخدم مجلد dist على الشبكة المنزلية، ليسحب الهاتف التحديث من الحاسوب مباشرة.

.DESCRIPTION
  شغّله بعد publish-update.ps1، ثم ضع العنوان الذي يطبعه في
  «الإعدادات ← التحديثات ← عنوان مصدر التحديث» داخل التطبيق.

  يعمل داخل الشبكة المحلية فقط ولا يحتاج إنترنت. أوقفه بـ Ctrl+C.
  قد يطلب ويندوز السماح له في جدار الحماية عند أول تشغيل.

.EXAMPLE
  .\tools\serve-updates.ps1 -Port 8080
#>
param(
    [int]$Port = 8080,
    [string]$Folder
)

$ErrorActionPreference = 'Stop'
if (-not $Folder) { $Folder = Join-Path (Split-Path -Parent $PSScriptRoot) 'dist' }
if (-not (Test-Path $Folder)) { throw "المجلد غير موجود: $Folder — شغّل publish-update.ps1 أولاً" }

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notmatch '^169\.' } |
    Select-Object -First 1).IPAddress

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Port/")
try { $listener.Start() }
catch {
    throw "تعذّر فتح المنفذ $Port. شغّل PowerShell كمسؤول، أو جرّب منفذاً آخر."
}

Write-Host ''
Write-Host 'الخادم يعمل. ضع هذا العنوان في التطبيق:' -ForegroundColor Green
Write-Host "  http://$ip`:$Port/version.json" -ForegroundColor Yellow
Write-Host ''
Write-Host "يخدم: $Folder"
Write-Host 'أوقفه بـ Ctrl+C'

$types = @{
    '.json' = 'application/json; charset=utf-8'
    '.apk'  = 'application/vnd.android.package-archive'
    '.ruba' = 'application/json; charset=utf-8'
}

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $name = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
        # نمنع الخروج من المجلد المخدوم.
        $full = Join-Path $Folder $name
        $resolved = try { (Resolve-Path $full -ErrorAction Stop).Path } catch { $null }

        if (-not $resolved -or -not $resolved.StartsWith((Resolve-Path $Folder).Path)) {
            $ctx.Response.StatusCode = 404
            $ctx.Response.Close()
            Write-Host "404  $name" -ForegroundColor DarkGray
            continue
        }

        $ext = [System.IO.Path]::GetExtension($resolved).ToLower()
        $ctx.Response.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' }
        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $ctx.Response.Close()
        Write-Host "200  $name  ($([math]::Round($bytes.Length/1KB)) ك.ب)"
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
