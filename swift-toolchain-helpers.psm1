<#
.SYNOPSIS
    Joins multiple path parts into a single path using PowerShell's Join-Path cmdlet.
    This helper method works with both PowerShell Core and Windows PowerShell.

.DESCRIPTION
    This function provides a compatible way to join multiple path parts into a single path.
    It takes variable number of path parts and combines them sequentially using Join-Path.

.PARAMETER Parts
    An array of string path parts to be joined together. The first element is used as the base path,
    and subsequent elements are joined as child paths.

.EXAMPLE
    Join-PathCompat "C:\Users" "Username" "Documents" "file.txt"
    Returns: C:\Users\Username\Documents\file.txt

.EXAMPLE
    Join-PathCompat $Env:TEMP "MyApp" "logs"
    Returns: The temp directory path joined with MyApp\logs

.OUTPUTS
    [string] The combined path string.
#>
Function Join-PathCompat {
    param(
        [Parameter(Mandatory, ValueFromRemainingArguments)]
        [string[]]$Parts
    )

    $result = $Parts[0]
    foreach ($part in $Parts[1..($Parts.Length - 1)]) {
        $result = Join-Path -Path $result -ChildPath $part
    }
    return $result
}

<#
.SYNOPSIS
    Gets the Visual Studio compatible host architecture identifier.

.DESCRIPTION
    Converts the processor architecture from the PROCESSOR_ARCHITECTURE environment variable
    to the format expected by Visual Studio build tools (amd64 or arm64).

.EXAMPLE
    Get-Vs-HostArch
    Returns: "amd64" on x64 systems or "arm64" on ARM64 systems

.OUTPUTS
    [string] The Visual Studio compatible architecture string ("amd64" or "arm64").

.NOTES
    Throws an exception if the processor architecture is not recognized.
#>
Function Get-VsHostArch {
    switch ($Env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { return 'amd64' }
        'ARM64' { return 'arm64' }
        default { throw "Unknown host architecture: `"${Env:PROCESSOR_ARCHITECTURE}`"" }
    }
}

<#
.SYNOPSIS
    Gets the CMake architecture identifier.

.DESCRIPTION
    Converts the processor architecture from the PROCESSOR_ARCHITECTURE environment variable
    to the format expected by CMake (x86_64 or arm64).

.EXAMPLE
    Get-CMakeHostArch
    Returns: "x86_64" on x64 systems or "arm64" on ARM64 systems

.OUTPUTS
    [string] The CMake compatible architecture string ("x86_64" or "arm64").

.NOTES
    Throws an exception if the processor architecture is not recognized.
#>
Function Get-CMakeHostArch {
    switch ($Env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { return 'x86_64' }
        'ARM64' { return 'arm64' }
        default { throw "Unknown host architecture: `"${Env:PROCESSOR_ARCHITECTURE}`"" }
    }
}

<#
.SYNOPSIS
    Initializes the CMake environment for Swift development. The Swift toolchain only works with a
    specific version of CMake.

.DESCRIPTION
    Downloads and sets up the required CMake version for Swift development if not already installed.
    Configures environment variables (PATH and CMAKE_ROOT) to point to the CMake installation.
    The CMake version is downloaded to the user's local application data directory.

.PARAMETER CMakeVersion
    The CMake major.minor version to install (default: "3.29").

.PARAMETER CMakePatchNumber
    The CMake patch version number to install (default: "9").

.EXAMPLE
    Initialize-CMakeSwiftEnv
    Downloads and sets up CMake 3.29.9 for the current architecture.

.EXAMPLE
    Initialize-CMakeSwiftEnv -CMakeVersion "3.30" -CMakePatchNumber "0"
    Downloads and sets up CMake 3.30.0 for the current architecture.

.NOTES
    - Downloads CMake from the official GitHub releases
    - Installation path: $Env:LOCALAPPDATA\Programs\cmake-{version}-windows-{arch}
    - Adds CMake bin directory to PATH
    - Sets CMAKE_ROOT environment variable
#>
Function Initialize-CMakeSwiftEnv {
    param (
        [string] $CMakeVersion = "3.29",
        [string] $CMakePatchNumber = "9"
    )

    $LLVMArch = Get-CMakeHostArch
    $SwiftCMakeDir = "cmake-${CMakeVersion}.${CMakePatchNumber}-windows-${LLVMArch}"
    $SwiftCMakeInstallPath = Join-PathCompat "${Env:LOCALAPPDATA}" "Programs" "${SwiftCMakeDir}"
    if (-Not (Test-Path -Path $SwiftCMakeInstallPath)) {
        $URI = "https://cmake.org/files/v${CMakeVersion}/cmake-${CMakeVersion}.${CMakePatchNumber}-windows-${LLVMArch}.zip"
        $ZipFile = Join-PathCompat "${Env:TEMP}" "cmake-${CMakeVersion}.${CMakePatchNumber}-windows-${LLVMArch}.zip"
        Invoke-WebRequest -Uri $URI -OutFile $ZipFile -UseBasicParsing
        Expand-Archive -Path $ZipFile -DestinationPath "${Env:LOCALAPPDATA}\Programs" -Force
        Remove-Item -Path $ZipFile -Force
    }
    $SwiftCMakeBinPath = Join-PathCompat "${SwiftCMakeInstallPath}" "bin"
    $SwiftCMakeModulePath = Join-PathCompat "${SwiftCMakeInstallPath}" "share" "cmake-${CMakeVersion}"
    $Env:PATH = "$SwiftCMakeBinPath;$Env:PATH"
    $Env:CMAKE_ROOT = $SwiftCMakeModulePath
}

<#
.SYNOPSIS
    Initializes the S: drive for Swift toolchain development.

.DESCRIPTION
    Creates a substituted drive S: that points to the user's toolchain source directory.
    This provides a shorter, more convenient path for accessing Swift toolchain files.
    If the S: drive doesn't exist, it creates it using the subst command.
    After setup, changes the current location to the S: drive.

.PARAMETER ToolchainSrcPath
    The path to the toolchain source directory.

.EXAMPLE
    Initialize-SDevDrive $Env:USERPROFILE\src\toolchain
    Creates S: drive pointing to $Env:USERPROFILE\src\toolchain and navigates to it.

.NOTES
    - Uses subst command to create the drive mapping
    - Changes current location to S: drive after setup
#>
Function Initialize-SDevDrive {
    param(
        [Parameter(Mandatory = $True)]
        [string] $ToolchainSrcPath
    )
    # Ensure the S: drive is set up for toolchain access.
    if (-Not (Test-Path -Path "S:\")) {
        subst S: "$ToolchainSrcPath"
    }
    S:
}

<#
.SYNOPSIS
    Initializes the Visual Studio development environment with specified parameters.

.DESCRIPTION
    Sets up the Visual Studio development environment by locating the latest VS installation,
    importing the DevShell module, and configuring the development command prompt with
    specified Windows SDK version, toolset version, and target architecture.
    Also fixes potential issues with the INCLUDE environment variable when using specific SDK versions.

.PARAMETER WinSdkVersion
    The Windows SDK version to use (e.g., "10.0.22621.0"). If empty, uses the default SDK.

.PARAMETER ToolsetVersion
    The Visual C++ toolset version to use (e.g., "14.29"). If empty, uses the default toolset.

.PARAMETER HostArch
    The host architecture for the build tools. If empty, automatically sets it to the current architecture.

.PARAMETER TargetArch
    The target architecture for compilation. If empty, automatically sets it to the current architecture.

.EXAMPLE
    Initialize-VsDevEnv
    Sets up VS environment with default settings for current architecture.

.EXAMPLE
    Initialize-VsDevEnv -WinSdkVersion "10.0.22621.0" -TargetArch "arm64"
    Sets up VS environment with specific Windows SDK version targeting ARM64.

.EXAMPLE
    Initialize-VsDevEnv -ToolsetVersion "14.29" -HostArch "amd64" -TargetArch "amd64"
    Sets up VS environment with specific toolset version for x64 development.

.NOTES
    - Requires Visual Studio to be installed
    - Uses vswhere.exe to locate VS installation
    - Automatically fixes INCLUDE path issues when using specific Windows SDK versions
    - Throws exceptions if VS installation is not found
#>
Function Initialize-VsDevEnv {
    [CmdletBinding()]
    param (
        [string] $WinSdkVersion,
        [string] $ToolsetVersion,
        [string] $HostArch,
        [string] $TargetArch
    )

    $InstallerLocation = Join-PathCompat "${Env:ProgramFiles(x86)}" 'Microsoft Visual Studio' 'Installer'
    $VSWhere = Join-PathCompat "${InstallerLocation}" 'vswhere.exe'
    if (-Not (Test-Path -Path $VSWhere)) {
        throw "No VS Installation found: `"$VSWhere`" does not exist."
    }

    $VSLocation = (& "$VSWhere" -latest -products * -format json | ConvertFrom-Json).installationPath
    if (-Not (Test-Path -Path $VSLocation)) {
        throw "No VS Installation found: `"$VSLocation`" does not exist."
    }
    Import-Module "$VSLocation\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"

    $DevCmdArgs = "-no_logo"
    if ($WinSdkVersion -ne "") {
        $DevCmdArgs += " -winsdk=${WinSdkVersion}"
    }
    if ($ToolsetVersion -ne "") {
        $DevCmdArgs += " -vcvars_ver=${ToolsetVersion}"
    }
    if ($HostArch -eq "") {
        $HostArch = Get-VsHostArch
    }
    $DevCmdArgs += " -host_arch=${HostArch}"
    if ($TargetArch -eq "") {
        $TargetArch = Get-VsHostArch
    }
    Enter-VsDevShell -VsInstallPath "$VSLocation" -Arch $TargetArch -DevCmdArguments $DevCmdArgs

    # Fix buggy INCLUDE environment variable when using $WinSdkVersion.
    if ($WinSdkVersion -ne "") {
        $Win10SdkRoot = Get-ItemPropertyValue `
            -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Kits\Installed Roots" `
            -Name "KitsRoot10"
        $Win10SdkInclude = Join-PathCompat $Win10SdkRoot "Include"

        $IncludePaths = $Env:INCLUDE -split ';'
        $NewIncludePaths = @()
        foreach ($IncludePath in $IncludePaths) {
            $IncludePath = $IncludePath -replace '\\', '\'
            if (-not ($IncludePath.StartsWith($Win10SdkInclude))) {
                # If the include path does not start with the Win10 SDK include path, keep it.
                $NewIncludePaths += $IncludePath
                continue
            }

            $Remainder = $IncludePath.Substring($Win10SdkInclude.Length).TrimStart('\')
            $Components = $Remainder -split '\\'
            $NextComponent = $Components[0]
            if ($NextComponent -eq $WinSdkVersion) {
                # If the next component is the WinSdkVersion, keep it.
                $NewIncludePaths += $IncludePath
                continue
            }

            $Rest = ($Components | Select-Object -Skip 1) -join '\'
            $NewIncludePath = $Win10SdkInclude + '\' + $WinSdkVersion + '\' + $Rest
            $NewIncludePath = $NewIncludePath -replace '\\', '\'
            $NewIncludePaths += $NewIncludePath
        }
        $Env:INCLUDE = $NewIncludePaths -join ';'
    }
}

<#
.SYNOPSIS
    Initializes the basic Swift build environment.

.DESCRIPTION
    Sets up the fundamental environment needed for Swift development by initializing
    both the CMake environment and the S: development drive. This is a convenience
    function that combines the basic setup steps needed before building the Swift toolchain.

.PARAMETER ToolchainSrcPath
    The path to the toolchain source directory.

.EXAMPLE
    Initialize-SwiftBuildEnv -ToolchainSrcPath $Env:USERPROFILE\src\toolchain
    Sets up CMake and S: drive for Swift development.

.NOTES
    This function calls:
    - Initialize-CMakeSwiftEnv: Sets up CMake with Swift-compatible version
    - Initialize-SDevDrive: Creates and navigates to the S: development drive
#>
Function Initialize-SwiftBuildEnv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string] $ToolchainSrcPath
    )

    # Find swift.exe.
    $SwiftPath = Get-Command swift.exe -ErrorAction SilentlyContinue
    if ($SwiftPath) {
        # Remove the Swift installation from PATH.
        $SwiftBinPath = Split-Path $SwiftPath.Source -Parent
        $SwiftRuntimePath = $SwiftBinPath -replace '\\Toolchains\\0.0.0\+Asserts\\usr\\bin', '\Runtimes\0.0.0\usr\bin'
        $Env:PATH = ($Env:PATH.Split(';') | Where-Object { $_ -ne "$SwiftBinPath\" }) -join ';'
        $Env:PATH = ($Env:PATH.Split(';') | Where-Object { $_ -ne "$SwiftRuntimePath\" }) -join ';'
        Remove-Item Env:SDKROOT -ErrorAction SilentlyContinue
    }

    Initialize-CMakeSwiftEnv
    Initialize-SDevDrive -ToolchainSrcPath $ToolchainSrcPath
}
 
<#
.SYNOPSIS
    Initializes the environment for reproducing Swift issues or testing.

.DESCRIPTION
    Sets up a complete Swift reproduction environment including the build environment,
    Visual Studio development tools, and PATH configuration to use a local Swift toolchain.
    This environment is configured to use a development version (0.0.0) of Swift toolchain
    installed in the S:\Program Files\Swift directory structure.

.PARAMETER ToolchainSrcPath
    The path to the toolchain source directory.

.PARAMETER TargetArch
    The target architecture for compilation (default: "amd64"). Supported values are typically
    "amd64" for x64 and "arm64" for ARM64.

.EXAMPLE
    Initialize-SwiftReproEnv -ToolchainSrcPath $Env:USERPROFILE\src\toolchain
    Sets up Swift reproduction environment for x64 architecture.

.EXAMPLE
    Initialize-SwiftReproEnv -TargetArch "arm64"
    Sets up Swift reproduction environment for ARM64 architecture.

.NOTES
    This function:
    - Configures PATH to include Swift toolchain binaries and runtime
    - Sets SDKROOT to the Windows SDK in the Swift toolchain
    - Uses toolchain version "0.0.0" (development version)
    - Expects toolchain at S:\Program Files\Swift
#>
Function Initialize-SwiftReproEnv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string] $ToolchainSrcPath,
        [string] $TargetArch = "amd64"
    )
    # Initialize the Swift build environment.
    Initialize-SwiftBuildEnv -ToolchainSrcPath $ToolchainSrcPath

    # Set up the Visual Studio development environment.
    Initialize-VsDevEnv -TargetArch $TargetArch

    $ToolchainPath = "S:\Program Files\Swift"
    $ToolchainVersion = "0.0.0"
    $SwiftBinPath = "${ToolchainPath}\Toolchains\${ToolchainVersion}+Asserts\usr\bin"
    $InstallRuntimePath = "${ToolchainPath}\Runtimes\${ToolchainVersion}\usr\bin"
    $Env:PATH = "$SwiftBinPath;$InstallRuntimePath;$Env:PATH"
    $Env:SDKROOT = "${ToolchainPath}\Platforms\Windows.platform\Developer\SDKs\Windows.sdk"
}


<#
.SYNOPSIS
    Initializes the environment for Swift bootstrap development using a specific Swift release.

.DESCRIPTION
    Sets up a complete Swift development environment using a pre-built Swift toolchain from
    an official release. This is typically used for bootstrap scenarios where you need to
    build Swift using an existing Swift compiler. The function configures the environment
    to use a specific Swift release version installed in the build toolchains directory.

.PARAMETER ToolchainSrcPath
    The path to the toolchain source directory.

.PARAMETER TargetArch
    The target architecture for compilation (default: "amd64"). Supported values are typically
    "amd64" for x64 and "arm64" for ARM64.

.PARAMETER ToolchainVersion
    The Swift toolchain version to use (default: "6.1.2"). This should match an installed
    Swift release toolchain in the S:\b\toolchains directory.

.EXAMPLE
    Initialize-SwiftBootstrapEnv -ToolchainSrcPath $Env:USERPROFILE\src\toolchain
    Sets up Swift bootstrap environment using Swift 6.1.2 for x64 architecture.

.EXAMPLE
    Initialize-SwiftBootstrapEnv -ToolchainSrcPath $Env:USERPROFILE\src\toolchain -TargetArch "arm64" -ToolchainVersion "0.0.0"
    Sets up Swift bootstrap environment using Swift 0.0.0 for ARM64 architecture.

.NOTES
    This function:
    - Configures PATH to include Swift toolchain binaries and runtime
    - Sets SDKROOT to the Windows SDK in the Swift toolchain
    - Expects toolchain at S:\b\toolchains\swift-{version}-RELEASE-windows10\LocalApp\Programs\Swift
#>
Function Initialize-SwiftBootstrapEnv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string] $ToolchainSrcPath,
        [string] $TargetArch = "amd64",
        [string] $ToolchainVersion = "6.1.2"
    )
    # Initialize the Swift build environment.
    Initialize-SwiftBuildEnv -ToolchainSrcPath $ToolchainSrcPath

    # Set up the Visual Studio development environment.
    Initialize-VsDevEnv -TargetArch $TargetArch

    $ToolchainPath = "S:\b\toolchains\swift-${ToolchainVersion}-RELEASE-windows10\LocalApp\Programs\Swift"
    $SwiftBinPath = "${ToolchainPath}\Toolchains\${ToolchainVersion}+Asserts\usr\bin"
    $InstallRuntimePath = "${ToolchainPath}\Runtimes\${ToolchainVersion}\usr\bin"
    $Env:PATH = "$SwiftBinPath;$InstallRuntimePath;$Env:PATH"
    $Env:SDKROOT = "${ToolchainPath}\Platforms\${ToolchainVersion}\Windows.platform\Developer\SDKs\Windows.sdk"
}

Export-ModuleMember -Function @(
    'Initialize-VsDevEnv',
    'Initialize-SwiftBuildEnv',
    'Initialize-SwiftReproEnv',
    'Initialize-SwiftBootstrapEnv'
)
