# Manage Windows Apps in Intune with WinGet

This repository provides a PowerShell script for installing and uninstalling Windows applications through Microsoft Intune using WinGet.

The `WinGet.ps1` script supports the following parameters:

* `PackageId`: the WinGet package identifier;
* `Version`: the specific version to install (optional);
* `Action`: the action to perform, such as `Uninstall`.

## Install the latest version

Replace `<PACKAGE_ID>` with the WinGet identifier of the application:

```powershell
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\WinGet.ps1" -PackageId "<PACKAGE_ID>"
```

Example:

```powershell
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\WinGet.ps1" -PackageId "7zip.7zip"
```

## Install a specific version

To display the available versions of an application, run:

```powershell
winget show --id "<PACKAGE_ID>" --versions
```

Then specify the package identifier and the version you want to install:

```powershell
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\WinGet.ps1" -PackageId "<PACKAGE_ID>" -Version "<VERSION>"
```

Example:

```powershell
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\WinGet.ps1" -PackageId "7zip.7zip" -Version "25.01"
```

## Uninstall the application

Replace `<PACKAGE_ID>` with the WinGet identifier of the application to uninstall:

```powershell
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\WinGet.ps1" -PackageId "<PACKAGE_ID>" -Action Uninstall
```

Example:

```powershell
%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\WinGet.ps1" -PackageId "7zip.7zip" -Action Uninstall
```

## Microsoft Intune configuration

Use the appropriate command as the install or uninstall command when configuring the Win32 application in Microsoft Intune.

The `%SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe` path allows the 32-bit Microsoft Intune Management Extension process to launch the 64-bit version of Windows PowerShell.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
