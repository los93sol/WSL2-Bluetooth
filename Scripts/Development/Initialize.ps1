# NOTE: If you are unable to run the script you need to run Set-ExecutionPolicy RemoteSigned

# Required because wsl command outputs wierd
$originalEncoding = [System.Console]::OutputEncoding
[System.Console]::OutputEncoding = [System.Text.Encoding]::Unicode

function Get-WSLDistribution {
    param (
        [string]$Name
    )

    $wslListOutput = wsl --list --verbose | Out-String
    $lines = $wslListOutput -split '\r?\n' | Where-Object { $_ -match '\S' }  # Split by lines and filter out empty lines

    # Skip the header line
    $lines = $lines[1..($lines.Length - 1)]

    foreach ($line in $lines) {
        if ($line -match '^(?<Default>\*?)\s*(?<DistroName>.*?)\s+(?<State>.*?)\s+(?<Version>\d+)\s*$') {
            $distroDetails = @{
                Name      = $Matches['DistroName']
                State     = $Matches['State']
                Version   = [int]$Matches['Version']
                IsDefault = ($Matches['Default'] -eq '*')
            }
            
            if ($distroDetails.Name -eq $Name) {
                return [PSCustomObject]$distroDetails
            }
        }
    }

    return $null
}

$rebootPendingFile = Join-Path $PSScriptRoot ".reboot_pending"
$rebootPending = Test-Path $rebootPendingFile

$baseDistroName = "Ubuntu"

Write-Host "Ensuring $baseDistroName is installed in WSL"
$baseDistro = Get-WSLDistribution -Name $baseDistroName
$baseDistroInstalled = $baseDistro -ne $null

if (!$rebootPending -And !$baseDistroInstalled) {
    Write-Host "$baseDistroName is not installed, installing it now"
    wsl --install --distribution $baseDistroName *> $null

    New-Item -Path $rebootPendingFile -ItemType File -Force > $null
    Write-Host "$baseDistroName has been installed, restart your computer and complete setup then run this script again" -ForegroundColor Yellow
    exit
}
elseif ($rebootPending -And !$baseDistroInstalled) {
    Write-Host "You must reboot your machine before running this script" -ForegroundColor Yellow
    exit
}
elseif ($rebootPending) {
    Remove-Item $rebootPendingFile
}

$requiredVersion = '2'

Write-Host "Ensuring $baseDistroName is version $requiredVersion"
if ($baseDistro.Version -ne $requiredVersion) {
    Write-Host "$baseDistroName must be version $requiredVersion, attempting to set it now."
    wsl --set-version $baseDistroName $requiredVersion > $null

    if (-not $?) {
        Write-Host "Unable to set the version of $baseDistro to $requiredVersion"
        exit
    }
}

Write-Host "Ensuring $baseDistroName is the default distribution"
if (!$baseDistro.IsDefault) {
    Write-Host "Setting $baseDistroName to the default distribution"
    wsl --set-default $baseDistroName > $null
}

Write-Host "Updating WSL"
wsl --update > $null

Write-Host "Checking if bluetooth is already enabled in the kernel"
$bluetoothEnabled = (wsl --distribution $baseDistroName -- bash -c "zcat /proc/config.gz | grep CONFIG_BT=y") -ne $null

if (!$bluetoothEnabled) {
    Write-Host "Bluetooth support is not enabled in the WSL kernel"
 
    $backupPath = Join-Path $PSScriptRoot "$baseDistroName.tar"
    Write-Host "Backing up $baseDistroName to $backupPath" 
    wsl --export $baseDistroName $backupPath > $null

    $newDistroName = "$baseDistroName-bluetooth"
    $newDistroPath = Join-Path $PSScriptRoot "$newDistroName-install"

    $newDistro = Get-WSLDistribution -Name $newDistroName
    $newDistroInstalled = $newDistro -ne $null

    if ($newDistroInstalled) {
        Write-Host "$newDistroName distribution already exists, unregistering it"
        wsl --unregister $newDistroName > $null
    }

    if (Test-Path $newDistroPath) {
        Write-Host "$newDistroPath already exists, deleting it"
        Remove-Item -Recurse $newDistroPath
    }

    Write-Host "Creating $newDistroPath directory"
    New-Item -ItemType Directory -Path $newDistroPath > $null
    
    Write-Host "Importing $newDistroName with $baseDistroName as base"
    wsl --import $newDistroName $newDistroPath $backupPath > $null

    [System.Console]::OutputEncoding = [System.Text.Encoding]::ASCII
    $wslUserPath = "/mnt/$($env:USERPROFILE[0].ToString().ToLower())$( $env:USERPROFILE.Substring(2).Replace('\', '/') )"
    wsl --distribution $newDistroName --user root -- bash Scripts/Development/BuildKernel.sh $wslUserPath 2>$null
    [System.Console]::OutputEncoding = [System.Text.Encoding]::Unicode

    $wslUserPath = $env:USERPROFILE.Replace('\', '\\')
    $wslConfigContent = @"
[wsl2]
kernel=$wslUserPath\\bluetooth-bzImage
"@

    $wslUserPath = $env:USERPROFILE
    Write-Host "Updating $wslUserPath\.wslconfig"
    $wslConfigContent | Out-File -FilePath "$wslUserPath\.wslconfig"

    Write-Host "Cleaning up $newDistroName"
    wsl --unregister $newDistroName
    Remove-Item -Recurse $newDistroPath
    Remove-Item $backupPath

    wsl --shutdown
}

Write-Host "Ensuring that the app user has been configured on $baseDistroName"
if ((wsl --distribution $baseDistroName -- getent passwd 1654) -eq $null) {
    Write-Host "Adding the app user to $baseDistroName"
    wsl --distribution $baseDistroName --user root -- useradd -u 1654 -M -N app    
}

if ((wsl --distribution $baseDistroName -- getent group bluetooth) -eq $null) {
    Write-Host "Adding the bluetooth group to $baseDistroName"
    wsl --distribution $baseDistroName --user root -- groupadd bluetooth
}

wsl --distribution $baseDistroName --user root -- usermod -aG bluetooth app

Write-Host "Ensuring dbus is running on $baseDistroName"
[System.Console]::OutputEncoding = [System.Text.Encoding]::ASCII
if ((wsl --distribution $baseDistroName --user root -- systemctl is-active dbus) -ne "active") {
    Write-Host "Starting dbus on $baseDistroName"
    wsl --distribution $baseDistroName --user root -- systemctl start dbus
}

Write-Host "Ensuring bluez is installed on $baseDistroName"
if ((wsl --distribution $baseDistroName -- dpkg -l | Select-String "bluez") -eq $null) {
    Write-Host "Installing bluez on $baseDistroName"
    wsl --distribution $baseDistroName --user root -- bash -c "apt update && apt install -y bluez" 2>$null
    wsl --distribution $baseDistroName --user root -- bash -c "sed -i 's/BLUETOOTH_ENABLED=0/BLUETOOTH_ENABLED=1/' /etc/init.d/bluetooth"
}

Write-Host "Ensuring bluetooth is running on $baseDistroName"
if ((wsl --distribution $baseDistroName --user root -- systemctl is-active bluetooth) -ne "active") {
    Write-Host "Starting bluetooth on $baseDistroName"
    wsl --distribution $baseDistroName --user root -- systemctl start bluetooth    
}

Write-Host "Ensuring that usbip is installed on $baseDistroName"
if ((wsl --distribution $baseDistroName -- dpkg -l | Select-String "linux-tools-virtual") -eq $null) {
    Write-Host "Installing usbip on $baseDistroName"
    wsl --distribution $baseDistroName --user root -- bash -c "apt update && apt install -y linux-tools-virtual hwdata && update-alternatives --install /usr/local/bin/usbip usbip `ls /usr/lib/linux-tools/*/usbip | tail -n1` 20" 2>$null
}
[System.Console]::OutputEncoding = [System.Text.Encoding]::Unicode

Write-Host "Ensuring usbipd-win is installed"
Get-Command usbipd *> $null
if (-not $?) {
    Write-Host "Installing usbipd-win now"
    winget install --silent --exact dorssel.usbipd-win > $null
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "usbipd-win has been installed"
}

Write-Host "Ensuring Docker Desktop is installed"
Get-Command docker *> $null
if (-not $?) {
    Write-Host "Installing Docker Desktop"
    $url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    $outputPath = Join-Path $PSScriptRoot "Docker Desktop Installer.exe"
    Invoke-WebRequest -Uri $url -OutFile $outputPath
    Start-Process -Wait -NoNewWindow -FilePath $outputPath -ArgumentList "install --backend=wsl-2 --quiet --accept-license " -ErrorAction Stop;
    Remove-Item $outputPath
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "Docker Desktop has been installed, you may need to reboot your machine before using it." -ForegroundColor Yellow
}

Write-Host "Remember to run:" -ForegroundColor Green
Write-Host "    ""usbipd wsl list"" to view all your USB devices" -ForegroundColor Green
Write-Host "    ""usbipd wsl attach --busid 9-1 --distribution $baseDistroName"" to attach a device" -ForegroundColor Green

# Restore console encoding
[System.Console]::OutputEncoding = $originalEncoding
