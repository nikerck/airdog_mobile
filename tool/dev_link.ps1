# 真机一键联调：插上手机后跑这个脚本。
#
#   pwsh ./tool/dev_link.ps1
#   pwsh ./tool/dev_link.ps1 -Serial R58M12345678
#
# 做的事：确认设备 → adb reverse 8080 → 装 APK → 启动 App。
# 之后在登录页点「USB 真机 127.0.0.1:8080」，用 zyy / 123456 登录。

param(
    [string]$Serial = '',
    [string]$Apk = 'build\app\outputs\flutter-apk\app-debug.apk',
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'

function Resolve-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($base in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, 'D:\Android\Sdk')) {
        if ($base) {
            $candidate = Join-Path $base 'platform-tools\adb.exe'
            if (Test-Path $candidate) { return $candidate }
        }
    }
    throw '找不到 adb。请把 platform-tools 加进 PATH，或设置 ANDROID_HOME。'
}

$adb = Resolve-Adb
Write-Host "adb: $adb" -ForegroundColor DarkGray

# 1. 找设备
$lines = & $adb devices -l | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice\b' }
$devices = @()
foreach ($line in $lines) {
    $parts = $line -split '\s+'
    $devices += [pscustomobject]@{
        Serial = $parts[0]
        IsEmulator = $parts[0] -like 'emulator-*'
    }
}

if ($Serial) {
    $target = $devices | Where-Object { $_.Serial -eq $Serial }
    if (-not $target) { throw "设备 $Serial 不在线。先跑 adb devices 看看。" }
} else {
    $target = $devices | Where-Object { -not $_.IsEmulator } | Select-Object -First 1
    if (-not $target) {
        Write-Host ''
        Write-Host '没发现真机。检查清单：' -ForegroundColor Yellow
        Write-Host '  1. 手机「设置 → 关于手机」连点版本号 7 次，打开开发者选项'
        Write-Host '  2. 开发者选项里打开「USB 调试」'
        Write-Host '  3. 插上数据线（不是只能充电的线），手机弹窗选「允许」'
        Write-Host '  4. 下拉通知栏，USB 用途选「传输文件 / MTP」'
        Write-Host '  5. 换一个 USB 接口再试（别走扩展坞）'
        Write-Host ''
        Write-Host '当前连着的：' -ForegroundColor DarkGray
        & $adb devices -l
        exit 1
    }
}

$serial = $target.Serial
$model = (& $adb -s $serial shell getprop ro.product.model) -join ''
$version = (& $adb -s $serial shell getprop ro.build.version.release) -join ''
Write-Host "设备: $model (Android $version, $serial)" -ForegroundColor Green

# 2. 端口转发：手机的 127.0.0.1:8080 → 电脑的 localhost:8080
& $adb -s $serial reverse "tcp:$Port" "tcp:$Port" | Out-Null
$list = & $adb -s $serial reverse --list
if ($list -match "tcp:$Port") {
    Write-Host "端口转发: 手机 127.0.0.1:$Port → 电脑 localhost:$Port ✓" -ForegroundColor Green
} else {
    throw '端口转发没建立成功。'
}

# 3. 装包
if (-not (Test-Path $Apk)) { throw "找不到 APK：$Apk，先跑 flutter build apk --debug" }
& $adb -s $serial install -r $Apk | Select-Object -Last 1
if ($LASTEXITCODE -ne 0) { throw '安装失败。' }

# 4. 启动
& $adb -s $serial shell am force-stop com.kkui.airdog_mobile
& $adb -s $serial shell am start -n com.kkui.airdog_mobile/.MainActivity | Out-Null
Write-Host ''
Write-Host '装好了，App 已启动。' -ForegroundColor Green
Write-Host "登录页点「USB 真机 127.0.0.1:$Port」，账号 zyy / 123456"
Write-Host '拔线或重启 adb 后需要重新执行本脚本（adb reverse 会失效）。'
