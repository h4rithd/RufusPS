#requires -RunAsAdministrator

<#
.SYNOPSIS
    RufusPS - Create a bootable Windows USB installer from a Windows ISO.

.AUTHOR
    h4rithd

.DESCRIPTION
    RufusPS prepares a USB drive for Windows installation by:
    - Selecting a target USB disk safely
    - Wiping and reinitializing the selected USB disk
    - Formatting it as FAT32 for UEFI boot
    - Mounting a Windows ISO
    - Copying ISO contents to USB
    - Splitting install.wim into .swm files when needed

.WARNING
    This script will erase the selected USB disk.
    Double-check the disk number before confirming.
#>

$isoImage = "C:\Path\To\windows10.iso"

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "RufusPS by h4rithd" -ForegroundColor Cyan
Write-Host "Windows Bootable USB Creator" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $isoImage)) {
    throw "ISO file not found: $isoImage"
}

$usbDisks = Get-Disk | Where-Object BusType -eq "USB"

if (-not $usbDisks) {
    throw "No USB disks found."
}

Write-Host "Detected USB disks:" -ForegroundColor Yellow
$usbDisks | Format-Table Number, FriendlyName, SerialNumber, Size, PartitionStyle -AutoSize

$diskNumber = Read-Host "Enter the USB disk number to wipe"

if ($diskNumber -notmatch '^\d+$') {
    throw "Invalid disk number."
}

$targetDisk = Get-Disk -Number $diskNumber -ErrorAction Stop

if ($targetDisk.BusType -ne "USB") {
    throw "Disk $diskNumber is not a USB disk. Aborting."
}

Write-Warning "This will ERASE all data on USB disk $diskNumber: $($targetDisk.FriendlyName)"
$confirm = Read-Host "Type ERASE to continue"

if ($confirm -ne "ERASE") {
    throw "Operation cancelled."
}

$mountedIso = $null
$usbVolume = $null

try {
    Write-Host "Preparing USB disk..." -ForegroundColor Yellow

    $formattedVolume = $targetDisk |
        Clear-Disk -RemoveData -RemoveOEM -Confirm:$false -PassThru |
        Initialize-Disk -PartitionStyle GPT -PassThru |
        New-Partition -UseMaximumSize -AssignDriveLetter |
        Format-Volume -FileSystem FAT32 -NewFileSystemLabel "RufusPS" -Confirm:$false

    $usbVolume = $formattedVolume
    $usbRoot = "$($usbVolume.DriveLetter):\"

    if (-not (Test-Path $usbRoot)) {
        throw "USB volume was not mounted correctly."
    }

    Write-Host "Mounting ISO..." -ForegroundColor Yellow

    $mountedIso = Mount-DiskImage -ImagePath $isoImage -StorageType ISO -PassThru
    $isoVolume = $mountedIso | Get-Volume
    $isoRoot = "$($isoVolume.DriveLetter):\"

    if (-not (Test-Path $isoRoot)) {
        throw "ISO volume was not mounted correctly."
    }

    $installWim = Join-Path $isoRoot "sources\install.wim"
    $installEsd = Join-Path $isoRoot "sources\install.esd"
    $usbSources = Join-Path $usbRoot "sources"

    Write-Host "Copying ISO files to USB..." -ForegroundColor Yellow

    robocopy $isoRoot $usbRoot /S /R:0 /W:0 /Z /XF install.wim install.esd /NP

    $robocopyExit = $LASTEXITCODE

    if ($robocopyExit -ge 8) {
        throw "Robocopy failed with exit code $robocopyExit"
    }

    if (-not (Test-Path $usbSources)) {
        New-Item -Path $usbSources -ItemType Directory | Out-Null
    }

    if (Test-Path $installWim) {
        Write-Host "Splitting install.wim for FAT32 compatibility..." -ForegroundColor Yellow

        dism /Split-Image `
            /ImageFile:$installWim `
            /SWMFile:"$usbSources\install.swm" `
            /FileSize:3800

        if ($LASTEXITCODE -ne 0) {
            throw "DISM failed while splitting install.wim"
        }
    }
    elseif (Test-Path $installEsd) {
        Write-Host "Copying install.esd..." -ForegroundColor Yellow

        $esdSize = (Get-Item $installEsd).Length

        if ($esdSize -gt 4GB) {
            throw "install.esd is larger than 4GB. FAT32 cannot store files larger than 4GB."
        }

        Copy-Item $installEsd -Destination "$usbSources\install.esd" -Force
    }
    else {
        throw "Neither install.wim nor install.esd found in ISO sources directory."
    }

    Write-Host ""
    Write-Host "RufusPS completed successfully." -ForegroundColor Green
    Write-Host "Bootable Windows USB created at $usbRoot" -ForegroundColor Green
}
finally {
    if ($mountedIso) {
        Write-Host "Dismounting ISO..." -ForegroundColor Yellow
        Dismount-DiskImage -ImagePath $isoImage -ErrorAction SilentlyContinue
    }

    if ($usbVolume -and $usbVolume.DriveLetter) {
        try {
            Write-Host "Ejecting USB..." -ForegroundColor Yellow

            (New-Object -ComObject Shell.Application).
                NameSpace(17).
                ParseName("$($usbVolume.DriveLetter):").
                InvokeVerb("Eject")
        }
        catch {
            Write-Warning "Could not eject USB automatically. Eject it manually."
        }
    }
}
