# 小窝 API 冒烟测试（Windows / PowerShell 7）
#
# 用法：
#   pwsh ./smoke.ps1 -Base http://127.0.0.1:8080 -User zyy -Pass 123456 -Image .\test.jpg
#
# 后端按《接口约定 v1.0》实现后，这个脚本应该全绿。

param(
    [string]$Base = 'http://127.0.0.1:8080',
    [string]$User = 'zyy',
    [string]$Pass = '123456',
    [string]$Image = '',
    [string]$MomoUser = '',
    [string]$MomoPass = ''
)

$ErrorActionPreference = 'Stop'
$script:passed = 0
$script:failed = 0

function Ok($msg) { $script:passed++; Write-Host "  [ok]   $msg" -ForegroundColor Green }
function Bad($msg) { $script:failed++; Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Skip($msg) { Write-Host "  [skip] $msg" -ForegroundColor DarkGray }

# 返回 @{ Status = 200; Body = '...' }，不抛异常
function Call($method, $path, $body = $null, $token = $null) {
    $headers = @{}
    if ($token) { $headers['Authorization'] = "Bearer $token" }
    $params = @{
        Uri         = "$Base$path"
        Method      = $method
        Headers     = $headers
        ContentType = 'application/json; charset=utf-8'
        UseBasicParsing = $true
    }
    if ($null -ne $body) {
        $params['Body'] = [System.Text.Encoding]::UTF8.GetBytes([string]$body)
    }
    try {
        $resp = Invoke-WebRequest @params
        return @{ Status = [int]$resp.StatusCode; Body = $resp.Content }
    } catch {
        $r = $_.Exception.Response
        if (-not $r) { throw }
        $stream = $r.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        return @{ Status = [int]$r.StatusCode; Body = $reader.ReadToEnd() }
    }
}

function Expect-Code($desc, $expect, $body) {
    if ($body -match "`"code`"\s*:\s*$expect") { Ok $desc }
    else { Bad "$desc（期望 code=$expect，实际：$($body.Substring(0, [Math]::Min(180, $body.Length)))）" }
}

function Expect-Status($desc, $expect, $got) {
    if ($got -eq $expect) { Ok $desc } else { Bad "$desc（期望 HTTP $expect，实际 $got）" }
}

Write-Host '== 1. 认证 ==' -ForegroundColor Cyan
$r = Call POST '/api/auth/login' (@{ username = $User; password = $Pass } | ConvertTo-Json)
Expect-Status '登录成功返回 200' 200 $r.Status
Expect-Code '登录返回 code=0' 0 $r.Body
$login = $r.Body | ConvertFrom-Json
$token = $login.data.token
if ($token) { Ok '拿到 token' } else { Bad '没有 token' }

$r = Call POST '/api/auth/login' (@{ username = $User; password = 'wrong-pass' } | ConvertTo-Json)
Expect-Status '错误密码返回 401' 401 $r.Status
Expect-Code '错误密码 code=1001' 1001 $r.Body

$r = Call GET '/api/todos?spaceId=sp_shared'
Expect-Status '无 token 返回 401' 401 $r.Status
Expect-Code '无 token code=1003' 1003 $r.Body

Write-Host '== 2. 空间 ==' -ForegroundColor Cyan
$r = Call GET '/api/spaces' $null $token
if ($r.Body -match 'sp_personal') { Ok '有 sp_personal' } else { Bad '缺少 sp_personal' }
if ($r.Body -match 'sp_shared') { Ok '有 sp_shared' } else { Bad '缺少 sp_shared' }
if ($r.Body -match 'u_momo') { Ok '有 u_momo' } else { Bad '缺少 u_momo' }

Write-Host '== 3. 文件 ==' -ForegroundColor Cyan
$fileId = $null
if ($PSVersionTable.PSVersion.Major -lt 6) {
    Skip 'Windows PowerShell 5.1 不支持 -Form，跳过上传测试（换 PowerShell 7 可测）'
} elseif ($Image -and (Test-Path $Image)) {
    $form = @{ file = Get-Item $Image }
    $resp = Invoke-WebRequest -Uri "$Base/api/files" -Method Post `
        -Headers @{ Authorization = "Bearer $token" } -Form $form -SkipHttpErrorCheck
    Expect-Status '上传图片返回 200' 200 ([int]$resp.StatusCode)
    $fileId = ($resp.Content | ConvertFrom-Json).data.id
    if ($fileId) { Ok "拿到 fileId：$fileId" } else { Bad '没有 fileId' }

    $resp2 = Invoke-WebRequest -Uri "$Base/api/files" -Method Post `
        -Headers @{ Authorization = "Bearer $token" } -Form $form -SkipHttpErrorCheck
    $id2 = ($resp2.Content | ConvertFrom-Json).data.id
    if ($fileId -eq $id2) { Ok '重复上传命中同一 id（按 sha256 去重）' }
    else { Bad "重复上传产生了新 id：$id2" }
} else {
    Skip '未提供 -Image，跳过上传测试'
}

Write-Host '== 4. 待办 ==' -ForegroundColor Cyan
$images = @()
if ($fileId) { $images = @($fileId) }   # 别用 if 表达式直接赋值：空数组会被折叠成 $null
$todoBody = @{
    spaceId = 'sp_shared'
    title   = 'smoke 待办'
    content = '正文测试'
    images  = $images
    dueAt   = $null
} | ConvertTo-Json -Depth 5
$r = Call POST '/api/todos' $todoBody $token
Expect-Code '创建待办 code=0' 0 $r.Body
$created = ($r.Body | ConvertFrom-Json).data.item
$todoId = $created.id
$rev = $created.rev
if ($todoId) { Ok "拿到待办 id：$todoId" } else { Bad '没有待办 id' }

if (-not $todoId) {
    Bad '创建失败，跳过后续待办检查'
} else {
$r = Call PATCH "/api/todos/$todoId" (@{ title = 'smoke 改过'; rev = $rev } | ConvertTo-Json) $token
Expect-Code '用正确 rev 修改 code=0' 0 $r.Body

$r = Call PATCH "/api/todos/$todoId" (@{ title = '再改'; rev = $rev } | ConvertTo-Json) $token
Expect-Status '旧 rev 修改返回 409' 409 $r.Status
Expect-Code '旧 rev code=2003' 2003 $r.Body

if ($MomoUser -and $MomoPass) {
    $momo = Call POST '/api/auth/login' (@{ username = $MomoUser; password = $MomoPass } | ConvertTo-Json)
    $mToken = ($momo.Body | ConvertFrom-Json).data.token
    $r = Call PATCH "/api/todos/$todoId" (@{ title = 'Momo 想改'; rev = 99 } | ConvertTo-Json) $mToken
    Expect-Status '非创建人改内容返回 403' 403 $r.Status
    Expect-Code '非创建人 code=2002' 2002 $r.Body
} else {
    Skip '未提供 -MomoUser/-MomoPass，跳过非创建人权限测试'
}

$r = Call DELETE "/api/todos/$todoId" $null $token
Expect-Code '删除待办 code=0' 0 $r.Body

$r = Call GET '/api/todos?spaceId=sp_shared' $null $token
if ($r.Body -match [regex]::Escape($todoId)) { Bad '删除后列表仍包含该待办' }
else { Ok '删除后列表不含该待办' }
}

Write-Host '== 5. 生理期 ==' -ForegroundColor Cyan
$now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$r = Call POST '/api/period/logs' (@{ spaceId = 'sp_shared'; startedOn = $now; flow = 2 } | ConvertTo-Json) $token
Expect-Status '写入共享空间返回 403' 403 $r.Status
Expect-Code '写入共享空间 code=3003' 3003 $r.Body

Write-Host '== 6. 同步 ==' -ForegroundColor Cyan
$r = Call GET '/api/sync/changes?since=0' $null $token
Expect-Code '同步接口 code=0' 0 $r.Body
if ($r.Body -match 'serverTime') { Ok '返回 serverTime' } else { Bad '缺少 serverTime' }
if (-not $todoId) { Skip '没有 todoId，跳过墓碑检查' }
elseif ($r.Body -match [regex]::Escape($todoId)) { Ok '同步含已删除待办的墓碑行' }
else { Bad '同步缺少墓碑行' }

Write-Host ''
Write-Host "通过 $script:passed 项，失败 $script:failed 项" -ForegroundColor Cyan
if ($script:failed -gt 0) { exit 1 }
