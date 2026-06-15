# RufusPS

**RufusPS** is a PowerShell-based Windows bootable USB creator.
It prepares a USB drive, formats it as FAT32, mounts a Windows ISO, copies the installer files, and automatically splits `install.wim` when required for FAT32 compatibility.

---

## Features

- Safely lists available USB disks before wiping
- Requires manual disk selection
- Requires explicit `ERASE` confirmation before destructive actions
- Creates a GPT/FAT32 USB installer for UEFI systems
- Mounts Windows ISO automatically
- Copies Windows setup files using `robocopy`
- Splits large `install.wim` files into `.swm` files using DISM
- Supports ISOs containing either:
  - `sources/install.wim`
  - `sources/install.esd`
- Dismounts ISO after completion
- Attempts to eject USB after completion

---

## Warning

This script will erase the selected USB disk. Use it carefully.

Before running RufusPS:

- Remove USB drives you do not want to wipe
- Double-check the disk number
- Make sure the ISO path is correct
- Run PowerShell as Administrator

The author is not responsible for data loss caused by selecting the wrong disk.

---

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or newer
- Administrator privileges
- A Windows ISO file
- A USB drive, preferably 8 GB or larger
- UEFI-capable target system

---

## Usage

Clone the repository:

```powershell
git clone https://github.com/YOUR_USERNAME/RufusPS.git
cd RufusPS
```

Edit the ISO path inside `RufusPS.ps1`:

```powershell
$isoImage = "C:\Path\To\windows10.iso"
```

Run PowerShell as Administrator.

Then execute:

```powershell
.\RufusPS.ps1
```

The script will show detected USB disks:

```text
Number FriendlyName        SerialNumber Size PartitionStyle
------ ------------        ------------ ---- --------------
1      SanDisk USB Drive   XXXXXXXX     16GB MBR
```

Enter the correct USB disk number.

To confirm wiping the disk, type:

```text
ERASE
```

RufusPS will then create the bootable USB installer.

---

## Why FAT32?

FAT32 is used because it is widely supported by UEFI firmware. However, FAT32 has a single-file size limit of 4 GB. Many Windows ISO files include an `install.wim` file larger than 4 GB.
RufusPS handles this by splitting `install.wim` into smaller `.swm` files:

```text
install.swm
install2.swm
install3.swm
```

Windows Setup supports this split-image format.

---

## GPT vs MBR

RufusPS uses GPT partitioning by default. This is suitable for modern UEFI-based systems.
If you need Legacy BIOS boot support, GPT/FAT32 may not be enough. In that case, you may need to modify the script to use MBR instead.

---

## Script Overview

RufusPS performs the following actions:

1. Checks that the ISO exists
2. Lists detected USB disks
3. Asks the user to select the target USB disk
4. Requires confirmation before wiping
5. Clears the selected USB disk
6. Initializes it as GPT
7. Creates a FAT32 partition
8. Mounts the Windows ISO
9. Copies ISO contents to the USB drive
10. Excludes `install.wim` and `install.esd` during the first copy
11. Splits `install.wim` if found
12. Copies `install.esd` if found and under 4 GB
13. Dismounts the ISO
14. Attempts to eject the USB drive

---

## Safety Notes

RufusPS avoids wiping every USB disk automatically. Unlike unsafe one-liners such as:

```powershell
Get-Disk | Where BusType -eq 'USB' | Clear-Disk
```

RufusPS forces the user to select one USB disk and confirm the operation.

Still, the script is destructive. If you choose the wrong disk, the data will be erased.

---

## Troubleshooting

### PowerShell blocks the script

Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run:

```powershell
.\RufusPS.ps1
```

This only changes the execution policy for the current PowerShell session.

---

### Robocopy failed

Robocopy exit codes below `8` usually mean success or partial success.

RufusPS treats exit codes `8` and above as failure.

Check that:

- The ISO is mounted correctly
- The USB drive is writable
- The USB drive has enough space

---

### DISM failed while splitting install.wim

Make sure you are running PowerShell as Administrator.

Also verify that the Windows ISO is not corrupted.

---

### USB does not boot

Check the following:

- Target machine supports UEFI boot
- Secure Boot settings are compatible with the ISO
- USB boot is enabled in firmware settings
- The USB drive is selected from the boot menu
- The ISO is a valid Windows installation ISO

---

## Disclaimer

RufusPS is provided as-is.

You are responsible for verifying the selected disk before continuing.

Always back up important data before using disk formatting or disk wiping tools.

---

## Author
Harith Dilshan (h4rithd.com)
