# packages.psd1 — Canonical software catalog for the Win dotfiles repo
#
# This is the single source of truth for all package lists. Scripts that install
# or remove software load this file via Import-PowerShellDataFile.
#
# Reconciled from: setup.ps1, Scripts/Install-Packages.ps1, Scripts/shell-setup.ps1,
# Scripts/debloat-windows.ps1, and Scripts/auto/autounattend.xml.
# setup.ps1 retains its own inline lists for historical reasons; this file is canonical.

@{
  # ---------------------------------------------------------------------------
  # Core developer tools — installed first as prerequisites for everything else
  # ---------------------------------------------------------------------------
  WingetCore = @(
    'Git.Git'
    'Microsoft.PowerShell'
    'Microsoft.WindowsTerminal'
  )

  # ---------------------------------------------------------------------------
  # Runtimes — VC++, .NET, DirectX, Java, OpenAL
  # ---------------------------------------------------------------------------
  WingetRuntimes = @(
    'Microsoft.VCRedist.2015+.x64'
    'Microsoft.VCRedist.2013.x64'
    'Microsoft.DotNet.DesktopRuntime.10'
    'Microsoft.DotNet.DesktopRuntime.9'
    'Microsoft.DotNet.DesktopRuntime.8'
    'Microsoft.DotNet.DesktopRuntime.7'
    'Microsoft.DotNet.DesktopRuntime.6'
    'Microsoft.DotNet.Framework.DeveloperPack_4'
    'Microsoft.DirectX'
    'KhronosGroup.VulkanRT'
    'KhronosGroup.VulkanSDK'
    'Microsoft.XNARedist'
    'Microsoft.EdgeWebView2Runtime'
    'Oracle.JavaRuntimeEnvironment'
    'EclipseAdoptium.Temurin.25.JRE'
    'OpenAL.OpenAL'
  )

  # ---------------------------------------------------------------------------
  # Build toolchains — compilers, linters, formatters, language tooling
  # ---------------------------------------------------------------------------
  WingetToolchains = @(
    'MartinStorsjo.LLVM-MinGW.UCRT'
    'Rustlang.Rustup'
    'astral-sh.uv'
    'Oven-sh.Bun'
    'BiomeJS.Biome'
    'koalaman.shellcheck'
    'ast-grep.ast-grep'
    'SQLite.SQLite'
  )

  # ---------------------------------------------------------------------------
  # Development tools — IDEs, editors, version control, dev environment managers
  # ---------------------------------------------------------------------------
  WingetDevTools = @(
    'GitHub.cli'
    'Notepad++.Notepad++'
    'VSCodium.VSCodium'
    'CodeSector.TeraCopy'
    'MathiasCodes.Winstow'
    'OpenJS.NodeJS'
    'Python.Python.3.13'
    'PuTTY.PuTTY'
    'Eugeny.Terminus'
    'jdx.mise'
    'topgrade-rs.topgrade'
  )

  # ---------------------------------------------------------------------------
  # CLI tools — shell utilities, file finders, diff tools, prompts
  # ---------------------------------------------------------------------------
  WingetCliTools = @(
    'eza-community.eza'
    'BurntSushi.ripgrep.MSVC'
    'sharkdp.fd'
    'sharkdp.bat'
    'dandavison.delta'
    'JanDeDobbeleer.OhMyPosh'
  )

  # ---------------------------------------------------------------------------
  # Applications — media, productivity, gaming, system utilities, security
  # ---------------------------------------------------------------------------
  WingetApplications = @(
    # Media / video / audio
    'VideoLAN.VLC'
    'mpv.net'
    'OBSProject.OBSStudio'
    'Meltytech.Shotcut'
    'KDE.Kdenlive'
    'Audacity.Audacity'
    'HandBrake.HandBrake'
    'GiantPinkRobots.Varia'
    'CodecGuide.K-LiteCodecPack.Basic'
    # Image / graphics
    'GIMP.GIMP'
    'tannerhelland.PhotoDemon'
    'Greenshot.Greenshot'
    'XnSoft.XnConvert'
    'SaeraSoft.CaesiumImageCompressor'
    # Compression / files
    '7zip.7zip'
    'Meta.Zstandard'
    'IridiumIO.CompactGUI'
    'Nikkho.FileOptimizer'
    'Rclone.Rclone'
    'TimVisee.ffsend'
    'aria2.aria2'
    # Browsers / launchers
    'Ablaze.Floorp'
    'Mozilla.Firefox'
    # Gaming
    'Valve.Steam'
    'EpicGames.EpicGamesLauncher'
    'PrismLauncher.PrismLauncher'
    'smartfrigde.Legcord'
    # Productivity / utilities
    'Microsoft.PowerToys'
    'voidtools.Everything'
    'DevToys-app.DevToys'
    'AutoHotkey.AutoHotkey'
    'TheDocumentFoundation.LibreOffice'
    'Rainmeter.Rainmeter'
    'Microsoft.Sysinternals.Autoruns'
    'Sysinternals.Autologon'
    # Package managers / install helpers
    'MartiCliment.UniGetUI'
    'Chocolatey.Chocolatey'
    'Chocolatey.ChocolateyGUI'
    # System / drivers / hardware
    'Guru3D.Afterburner.Beta'
    'SteelSeries.SteelSeriesEngine'
    'ViGEm.ViGEmBus'
    'ToastyX.CustomResolutionUtility'
    'TechPowerUp.NVCleanstall'
    'Wagnardsoft.DisplayDriverUninstaller'
    'lostindark.DriverStoreExplorer'
    'Recol.DLSSUpdater'
    'GlennDelahoy.SnappyDriverInstallerOrigin'
    'CPUID.CPU-Z'
    'TechPowerUp.GPU-Z'
    # Disk / storage / cleanup
    'WinDirStat.WinDirStat'
    'BleachBit.BleachBit'
    'qarmin.czkawka.gui'
    'SingularLabs.CCEnhancer'
    # Uninstallers / maintenance
    'RevoUninstaller.RevoUninstaller'
    'Klocman.BulkCrapUninstaller'
    'Universal-Debloater-Alliance.uad-ng'
    # Security
    'ClamWin.ClamWin'
    # Dev utilities
    'WindowsPostInstallWizard.UniversalSilentSwitchFinder'
    'EditorConfig-Checker.EditorConfig-Checker'
    'Nlitesoft.NTLite'
    'CodingWondersSoftware.DISMTools.Stable'
  )

  # ---------------------------------------------------------------------------
  # Scoop
  # ---------------------------------------------------------------------------
  ScoopBuckets = @(
    'extras'
    'nerd-fonts'
    'java'
    'nirsoft'
  )

  ScoopPackages = @()

  # ---------------------------------------------------------------------------
  # Chocolatey
  # ---------------------------------------------------------------------------
  ChocoPackages = @()

  # ---------------------------------------------------------------------------
  # PowerShell modules
  # ---------------------------------------------------------------------------
  PsModules = @(
    'PSIni'
    'Pester'
    'PowerShell-Beautifier'
  )

  # ---------------------------------------------------------------------------
  # Windows optional features (DISM)
  # ---------------------------------------------------------------------------
  WindowsFeatures = @(
    'Microsoft-Windows-Subsystem-Linux'
    'VirtualMachinePlatform'
    'LegacyComponents'
    'DirectPlay'
  )

  # ---------------------------------------------------------------------------
  # Appx packages to remove during debloat
  # Union of debloat-windows.ps1 and setup.ps1 lists; wildcards kept where broader.
  # ---------------------------------------------------------------------------
  AppxToRemove = @(
    '*Clipchamp*'
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.BingSearch'
    'Microsoft.Copilot'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MicrosoftStickyNotes'
    'Microsoft.MSPaint'
    'Microsoft.Office.OneNote'
    'Microsoft.OutlookForWindows'
    'Microsoft.People'
    'Microsoft.SkypeApp'
    'Microsoft.Todos'
    '*WindowsPhone*'
    'Microsoft.ZuneMusic'
    'MicrosoftCorporationII.MicrosoftFamily'
    'MicrosoftCorporationII.QuickAssist'
    'MicrosoftTeams*'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.XboxGameCallableUI'
    'Microsoft.WindowsAlarms'
    'Microsoft.WindowsCamera'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.Windows.DevHome'
    'Microsoft.Edge.GameAssist'
    'Microsoft.549981C3F5F10'
    '*3DViewer*'
    '*WebExperience*'
    '*CandyCrush*'
    '*BubbleWitch*'
    'king.com*'
    '*MarchofEmpires*'
    'Microsoft.MixedReality.Portal'
    '*HolographicFirstRun*'
    'microsoft.windowscommunicationsapps'
  )
}
