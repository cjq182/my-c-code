#Requires -Version 5.1
<#
    一键把当前文件夹的改动提交并推送到 GitHub
    用法：
        .\push.ps1                      # 自动生成提交说明
        .\push.ps1 "add 9y17 exercise"  # 自定义提交说明
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Message
)

$ErrorActionPreference = 'Stop'

# 始终以脚本所在目录作为仓库根目录，避免在别的路径下误操作
Set-Location -LiteralPath $PSScriptRoot

function Write-Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "OK  $text" -ForegroundColor Green }
function Write-Bad($text)  { Write-Host "!!  $text" -ForegroundColor Red }

# ---------- 1. 确认这是 git 仓库 ----------
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git'))) {
    Write-Bad "当前目录不是 Git 仓库：$PSScriptRoot"
    exit 1
}

# ---------- 2. 检查能否连上 GitHub ----------
Write-Step '检查 github.com:443 连通性'
$reachable = $false
try {
    $client = New-Object System.Net.Sockets.TcpClient
    $async  = $client.BeginConnect('github.com', 443, $null, $null)
    if ($async.AsyncWaitHandle.WaitOne(5000, $false) -and $client.Connected) { $reachable = $true }
    $client.Close()
} catch { $reachable = $false }

if (-not $reachable) {
    Write-Bad '连不上 github.com:443 —— 请先打开代理 / VPN，再重新运行本脚本。'
    exit 1
}
Write-Ok 'GitHub 可达'

# ---------- 3. 暂存改动 ----------
Write-Step '扫描改动 (git add -A)'
git add -A | Out-Null

$staged = @(git diff --cached --name-only)
if ($staged.Count -eq 0) {
    Write-Ok '没有需要提交的改动，工作区已经是干净的。'
    git status -sb
    exit 0
}

Write-Host '本次将提交以下文件：' -ForegroundColor Yellow
git status --short

# ---------- 4. 提交 ----------
if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = 'update C code {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm')
}
Write-Step "提交：$Message"
git commit -m $Message | Out-Null

# ---------- 5. 推送 ----------
Write-Step '推送到 origin'
# git 把进度信息写到 stderr；在 ErrorActionPreference='Stop' 下再配合 2>&1，
# PowerShell 会把它当成致命错误而中断脚本。这里临时放行，只按退出码判断成败。
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
git push
$pushCode = $LASTEXITCODE
$ErrorActionPreference = $prevEap

if ($pushCode -ne 0) {
    Write-Bad '推送失败。若提示认证问题，请检查 Windows 凭据管理器里的 git:https://github.com。'
    exit 1
}

Write-Ok '上传完成'
$url = (git remote get-url origin) -replace '\.git$', ''
Write-Host "仓库地址：$url" -ForegroundColor Green
git log --oneline -1
