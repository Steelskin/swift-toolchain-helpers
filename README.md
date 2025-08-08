# `swift-toolchain-helpers`

This repository contains a small PowerShell module aimed at simplifying common tasks for a Swift
toolchain build on Windows.

## Installation

Add the following code to your [PowerShell Profile](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.5):

```pwsh
Import-Module -Name "Path\to\swift-toolchain-helpers\swift-toolchain-helpers.psm1"
```

For Windows PowerShell, the default path is:
```
${Env:USERPROFILE}\Documents\WindowsPowerShell\profile.ps1
```

For PowerShell Core, the default path is:
```
${Env:USERPROFILE}\Documents\PowerShell\profile.ps1
```

## Exported cmdlets

* **`Initialize-VsDevEnv`**\
  Initializes a Visual Studio Development Environment for the selected target, with the selected
  Windows SDK and Build Tools version.
* **`Initialize-SwiftBuildEnv`**\
  Sets up the environment to do the following:
  * Removes the system installation of Swift from the environment, if any.
  * Installs the appropriate CMake version under `$Env:LOCALAPPDATA\Programs`, if it is not already
    there and sets the `PATH` variable accordingly.
  * Mounts the provided `-ToolchainSrcPath` to `S:`, if it is not already mounted.
* **`Initialize-SwiftReproEnv`**\
  Does the same as `Initialize-SwiftBuildEnv`, and then sets up a Swift toolchain environment to
  the bootstrap toolchain version used for the Swift toolchain build (6.1.2 by default). This is
  useful when debugging issues during the compiler build.
* **`Initialize-SwiftBootstrapEnv`**\
  Does the same as `Initialize-SwiftBuildEnv`, and then sets up a Swift toolchain environment to
  the built toolchain. This is useful when debugging issues during the SDK/Runtimes builds.

## Misc - Helper PowerShell profile

This is my PowerShell profile file:
```pwsh
if ([System.Console]::IsOutputRedirected -or !!([Environment]::GetCommandLineArgs() | Where-Object { $_ -ilike '-noni*'})) {
    # If the output is redirected or the session is non-interactive, do not run the profile.
    return
}

# Import Swift toolchain helpers.
Import-Module -Name "${Env:USERPROFILE}\src\swift-toolchain-helpers\swift-toolchain-helpers.psm1"

# Nice Git integration in PowerShell.
Import-Module posh-git

# Make PowerShell more user-friendly.
if (-not (Get-Module -Name PSReadLine)) {
    Import-Module PSReadLine
}
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineKeyHandler -Key RightArrow -Function ForwardChar
Set-PSReadLineKeyHandler -Key "Ctrl+;" -Function AcceptNextSuggestionWord
Set-PSReadLineKeyHandler -Key "Ctrl+`'" -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadlineOption -BellStyle None
```

You may need to install the following so it works as expected:
```pwsh
# Git integration module.
Install-Module posh-git

# Necessary for Windows PowerShell to get the latest version.
Install-Module PSReadLine -Scope CurrentUser -Force
```
