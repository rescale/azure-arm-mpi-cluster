Param(
  [int]$vmIndex=0
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Visual Studio 2013 x64 and x86 redists
$VS2013_x64 = Join-Path $ScriptDir "vcredist_x64.exe"
Start-Process -File "$VS2013_x64" -Arg '/i /q /norestart' -Wait -Verb RunAs

$VS2013_x86 = Join-Path $ScriptDir "vcredist_x86.exe"
Start-Process -File "$VS2013_x86" -Arg '/i /q /norestart' -Wait -Verb RunAs

# Install MSMPI
$MPIInstaller = Join-Path $ScriptDir "MSMpiSetup.exe"
Start-Process $MPIInstaller -Arg "-unattend" -Wait
Start-Service MsMpiLaunchSvc
Set-Service MsMpiLaunchSvc -StartupType Automatic

$env:MSMPI_BIN = [Environment]::GetEnvironmentVariable("MSMPI_BIN", "Machine")
[Environment]::SetEnvironmentVariable("PATH", $env:PATH + $env:MSMPI_BIN + ";", "Machine")

netsh advfirewall firewall add rule name="ephemeral-tcp" dir=in action=allow localport=49152-65535 protocol=tcp
netsh advfirewall firewall add rule name="ephemeral-udp" dir=in action=allow localport=49152-65535 protocol=udp

# Setup SMB
if ($vmIndex -eq 0) {
    New-Item "D:\shared" -type directory
    New-SmbShare -Name shared -Path D:\shared -FullAccess Everyone
}
cmd /c mklink /D C:\shared \\N0\shared

# SSH setup
$OpenSSHArchive = Join-Path $ScriptDir "OpenSSH-Win64.zip"

$Destination = "C:\"
$OpenSSHDir = Join-Path $Destination "OpenSSH-Win64"

Add-Type -assembly "system.io.compression.filesystem"

[io.compression.zipfile]::ExtractToDirectory($OpenSSHArchive, $Destination)

New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH

Start-Process "ssh-keygen.exe" -ArgumentList "-A" -WorkingDirectory $OpenSSHDir -Wait

Start-Process "sshd.exe" -ArgumentList "install" -WorkingDirectory $OpenSSHDir -Wait

$sshd_config = Join-Path $OpenSSHDir "sshd_config"
$sftp_server = Join-Path $OpenSSHDir "sftp-server.exe"

(Get-Content $sshd_config) | Select-String -Pattern '^Subsystem\s+.+$' -NotMatch | Set-Content $sshd_config
Add-Content $sshd_config "`nSubsystem sftp $sftp_server`n"

Start-Service sshd
Set-Service sshd -StartupType Automatic
