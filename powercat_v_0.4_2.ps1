# powercat - a netcat for powershell (almost more than a POC)
# started by MBD 20140803

###########
# Credits #
###########
# idea based on comments by strandjs & Joff Thyer
# socket stream proof of concept from http://pastebin.ca/1715493
# additional socket tweaks thanks to MSDN:
# http://msdn.microsoft.com/en-us/library/system.net.sockets.tcpclient(v=vs.110).aspx

#############
# Thank you #
#############
# 1) my wife for putting up with my compulsive coding
# 2) Black Hills Info Sec for being a rocking place to work
# Check us out at: http://blackhillsinfosec.com/
# 3) the testers: Jim, Adam, Andy, and John
# 4) *YOU*, the user of this tool!  
# Without you, this would be only a bunch of bytes!

###################
### TROPHY CASE ###
# TCB: stuff done #
###################
# - got stream going
# - chat recieve mode
# - invoke cmd, redirect stdin, kill process, and reclaim stdout
# - stream stdout of cmd to remote client.  :-D (this took longer than i'd care to admit)
# - test to ensure socket opened.  If not, warn why.
# - added CLI args (L, h, etc) <-- will be an ongoing thing though!
# - can send to remote netcat with client mode

##################
# Current sprint #
##################
# -- Find bugs!!

###########
# On deck #
###########
# -- listener options (both l & L)

###############
# Bug squash! #
###############
# -- some commands don't appear to work.  Netstat for instance

#########
# TODOs #
#########
# Minimum req set for 1.0 release (this recreates "full" netcat functionality)
# - working command redirection (Done -- not ideal, but works)
# - working "chat" mode recieve aka listen (DONE!)
# - working "chat" mode send aka client (done)
# - working shell redircts <, >, |
# - ability to setup a relay (invoke powercat 2x: one listen & one client)
# - add a license (BSD?)

###################
# the idea hopper #
###################
# mas importante:
# -- create a client mode
# -- verify can send files via > or <
# -- listener option (both l & L)
# -- check for valid combinations of command line args (ie: -L requires -p)
# -- is start-sleep needed? test and find out! (at present, yes. WEAK!)
# -- create v & vv options
# -- cleanup code (spelling fixes in comments, consistant cases, use of ;, etc.)
# -- revamp connection code... make both client and listen similar

# very nice to have
# -- make function calls for reading/writing to stream... clean up the main section
# -- add logic to check if you have perms to open low order ports
# -- setup password or certificate authentication options
# -- put STDOUT into stream without the use of sleep functions (async mode)
# -- change process invocation method.  keep same cmd running for duration of connection
# -- implement listen hard mode (restart powercat when a PUNT! gets sent)

# pie in sky
# -- other protocols (udp, icmp, routing protocols?, etc)
# -- auto relay mode?
# -- relay c2 helper
# -- make an ultra thin version (aka minimized) to make script small
# -- create a evader mode where it makes itself to dodge AV etc. (will this ever be needed?)
# -- setup different transport options (ie ssl etc)
# -- protocol enveloper/wrapper (dns, ssl, smtp)
# -- data encoder/crypter xor, 3des, etc
# -- wizard/walkthru mode (walk a noob through setting up powercat listener or client)

############
# Warning! #
############
# This code is provided as is. It's free and always will be.
# There will never be a warranty or guarantee.  If it works, nifty. If not, tough.
# If you're not happy with this code, fix it.  I'd *love* bug fixes.
# In the event that you cannot fix my bugs, please at least tell me about them! 
# Since I stand behind my software, including free software,
# I'll always give a full refund if you're not completely satisfied.  ;-)
# 
# Have a nice day! :-) 
# - Mick Douglas

### end of comments ###
### begin teh codez ###

param (
    [string]$c = "",
    [string]$e = "",
    [switch]$h = $false,
    [switch]$l = $false,
    [string]$p = "",
    [switch]$version = $false
)

[string]$ver = "0.4_2";

# MBD this also needs to trigger if 
# - no command args are given
# - invalid commands arg mix is given
if ($h -eq $true){
    Write-Host ""
    write-Host "powercat: a netcat implementation in MS PowerShell"
    write-Host ""
    Write-Host "powercat operates in two modes:"
    Write-Host "   1) Listener mode -- awaits a connection from another client"
    Write-Host "   2) Client mode -- connects to another listener/server"
    Write-Host ""
    Write-Host "   Usage:"
    Write-Host "      (Listen mode) powercat.ps1 -L -p {port} -e cmd.exe"
    Write-Host "      (Client mode) powercat.ps1 -c {IP} -p {port}"
    Write-Host ""
    Write-Host "   -c {computer dns name or IP} : computer to connect to (connect mode)"
    Write-Host "   -e {executable} : Command to run once a connection is made (listen mode)"
    Write-Host "   -h : this help screen"
    Write-Host "   -l : listen mode (allow remote systems to connect to this machine)"
    Write-Host "   -p {port} : the port to listen & connect on"
    Write-Host "   -version : print the current version of powercat and exit"
    Write-Host ""
    exit;
}

# MBD XXX need to determine proper order and checks for valid cli options

if ($version -eq $true){
    Write-Host "You're using powercat version $ver"
    exit;
}

if ($p -eq ""){
    write-host "You must specify a port with -p like so:"
    write-host "-p {port number}"
    exit;
}

if ($l -eq $true){
    try{
        $enc = New-Object System.Text.AsciiEncoding
        $sock = New-Object System.net.Sockets.TcpListener $p
        $sock.Start()
        $client = $sock.AcceptTcpClient()
        #$client = $sock.AcceptTcpClientAsync()
        $stream = $client.GetStream()
        $buffer = New-Object System.Byte[] $client.ReceiveBufferSize
    } catch {
        Write-Host ""
        Write-Host "Connection failed. :-(";
        Write-Host "This can happen for several reasons:";
        Write-Host "   1) Is port $p already in use?";
        Write-Host "   2) Are you trying to open a low order port as a non-admin?";
        Write-Host ""
        exit;
    }

    while($bytes = $stream.Read($buffer, 0, $buffer.length)){
        # MBD uncomment this to have echo back to the connector
        #$stream.write($buffer, 0, $bytes)
        if($e -eq "cmd.exe"){

            $command = $enc.GetString($buffer, 0, $bytes)
            $command = $command.Substring(0,$command.Length-1)

            $psi = New-Object System.Diagnostics.ProcessStartInfo;
            $psi.FileName = "cmd.exe";
            $psi.Arguments = "/c $command"
            $psi.UseShellExecute = $false;
            $psi.RedirectStandardInput = $true;
            $psi.RedirectStandardOutput = $true;
            $psi.RedirectStandardError = $true;
            $proc = [System.Diagnostics.Process]::Start($psi);

            while(!($proc.HasExited)){
                start-sleep -s 1
                # MBD you can uncomment this if you want to see progress or lack thereof
                #write-host Waiting for process to finish
            }

            if ($proc.StandardError){
                # send STDERR to remote client
                $error = $proc.StandardError.ReadToEnd()
                $error = $enc.GetBytes($error)
                $stream.write($error, 0, $error.length)
                # MDB uncomment this to send cmd error to LOCAL system
                #write-host $proc.StandardError.ReadToEnd()
            }

            if ($proc.StandardOutput){
                # Send STDOUT to remote client
                $output = $proc.StandardOutput.ReadToEnd()
                $output = $enc.GetBytes($output)
                $stream.write($output, 0, $output.length)
                # MDB uncomment this to send cmd output to LOCAL system
                #write-host $proc.StandardOutput.ReadToEnd()
            }
            
        } else {
            # chat mode
            write-host -n $enc.GetString($buffer, 0, $bytes)
        }
        # the string ESC kills chat mode.  IDK if that's what we want.
        if($bytes -gt 3){
            if($enc.GetString($buffer, 0, 3) -eq "ESC"){
                break
            }
        }
    }
    $client.Close()
    $sock.Stop()
    
} else {
    $enc = New-Object System.Text.AsciiEncoding
    $sock = New-Object System.net.Sockets.TcpClient
    $sock.connect($c, $p)
    if ($sock.Connected){
        $stream = $sock.GetStream()
    } else {
        write-host unable to connect - something failed
        exit;
    }
    # MBD this needs fixed.  While($sock.Connected) is that right?
    While ($true){
        # need to pull IP and port from cli.  :-(
        # normally this ain't no thing, but a chicken wing...
        # but if I'm to replicate netcat you don't use -X switches.  Just IP port.
        # first world coding problems.  Will likely force use of da switches.
        
        #$buffer = New-Object System.Byte[] $client.ReceiveBufferSize
        $buffer = Read-Host
        $buffer = $buffer + "`r`n"
        $buffer = $enc.GetBytes($buffer)
        $stream.write($buffer, 0, $buffer.length)

    }
    # MBD should this be closing the remote listen connector?  IDK
    $sock.Close();
}