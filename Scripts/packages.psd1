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
    WingetCore         = @(
        'Git.Git'
        'Microsoft.PowerShell'
        'Microsoft.WindowsTerminal'
    )

    # ---------------------------------------------------------------------------
    # Runtimes — VC++, .NET, DirectX, Java, OpenAL
    # ---------------------------------------------------------------------------
    WingetRuntimes     = @(
        'abbodi1406.vcredist'
        'Microsoft.DotNet.DesktopRuntime.10'
        'Microsoft.DotNet.DesktopRuntime.9'
        'Microsoft.DotNet.DesktopRuntime.8'
        'Microsoft.DotNet.DesktopRuntime.7'
        'Microsoft.DotNet.DesktopRuntime.6'
        'Microsoft.DotNet.Framework.DeveloperPack_4'
        'Microsoft.DirectX'
        'KhronosGroup.VulkanRT'
        'Microsoft.XNARedist'
        'Microsoft.EdgeWebView2Runtime'
        'Oracle.JavaRuntimeEnvironment'
        'EclipseAdoptium.Temurin.25.JRE'
    )

    # ---------------------------------------------------------------------------
    # Build toolchains — compilers, linters, formatters, language tooling
    # ---------------------------------------------------------------------------
    WingetToolchains   = @(
        'MartinStorsjo.LLVM-MinGW.UCRT'
        'Rustlang.Rustup'
        'RubyInstallerTeam.Ruby.4.0'
        'Microsoft.VisualStudio.BuildTools'
        'astral-sh.uv'
        'Oven-sh.Bun'
        'BiomeJS.Biome'
        'ast-grep.ast-grep'
        'SQLite.SQLite'
    )

    # ---------------------------------------------------------------------------
    # Development tools — IDEs, editors, version control, dev environment managers
    # ---------------------------------------------------------------------------
    WingetDevTools     = @(
        'GitHub.cli'
        'Notepad++.Notepad++'
        'VSCodium.VSCodium'
        'CodeSector.TeraCopy'
        'MathiasCodes.Winstow'
        'OpenJS.NodeJS'
        'Python.Python.3.14'
        'Python.Launcher'
        'PuTTY.PuTTY'
        'jdx.mise'
        'topgrade-rs.topgrade'
        'sinelaw.fresh-editor'
        'Anthropic.ClaudeCode'
        'Anthropic.Claude'
    )

    # ---------------------------------------------------------------------------
    # CLI tools — shell utilities, file finders, diff tools, prompts
    # ---------------------------------------------------------------------------
    WingetCliTools     = @(
        'eza-community.eza'
        'BurntSushi.ripgrep.MSVC'
        'sharkdp.fd'
        'sharkdp.bat'
        'JanDeDobbeleer.OhMyPosh'
        'Starship.Starship'
        'ajeetdsouza.zoxide'
        'DEVCOM.JetBrainsMonoNerdFont'
        'marlocarlo.psmux'
    )

    # ---------------------------------------------------------------------------
    # Applications — media, productivity, gaming, system utilities, security
    # ---------------------------------------------------------------------------
    # Reconciled 2026-06-17 to match currently-installed software (winget export).
    WingetApplications = @(
        # Media / video / audio
        'VideoLAN.VLC'
        'mpv.net'
        'OBSProject.OBSStudio'
        #'Meltytech.Shotcut'
        'KDE.Kdenlive'
        'Audacity.Audacity'
        'HandBrake.HandBrake'
        'Gyan.FFmpeg.Shared'
        # Image / graphics
        'GIMP.GIMP'
        'KDE.Krita'
        'tannerhelland.PhotoDemon'
        'Greenshot.Greenshot'
        'XnSoft.XnConvert'
        'SaeraSoft.CaesiumImageCompressor'
        # Compression / files
        '7zip.7zip'
        'Nikkho.FileOptimizer'
        'aria2.aria2'
        # Browsers / launchers
        'Ablaze.Floorp'
        'ImputNet.Helium'
        # Gaming
        'Valve.Steam'
        'EpicGames.EpicGamesLauncher'
        'PrismLauncher.PrismLauncher'
        'smartfrigde.Legcord'
        # Productivity / utilities
        #'Microsoft.PowerToys'
        'voidtools.Everything'
        'AutoHotkey.AutoHotkey'
        'ONLYOFFICE.DesktopEditors'
        'gerardog.gsudo'
        'Microsoft.Sysinternals.Autoruns'
        'Microsoft.Sysinternals.Autologon'
        # Package managers / install helpers
        'Devolutions.UniGetUI'
        # System / drivers / hardware
        'Guru3D.Afterburner.Beta'
        'SteelSeries.GG'
        'ViGEm.ViGEmBus'
        'Nefarius.HidHide'
        'TechPowerUp.NVCleanstall'
        'GlennDelahoy.SnappyDriverInstallerOrigin'
        'Orbmu2k.nvidiaProfileInspector'
        'xHybred.NVPIRevamped'
        #'Nvidia.PhysX'
        'REALiX.HWiNFO'
        'Intel.IntelExtremeTuningUtility'
        'Ventoy.Ventoy'
        # Disk / storage / cleanup
        'BleachBit.BleachBit'
        # Uninstallers / maintenance
        'RevoUninstaller.RevoUninstaller'
    )

    # ---------------------------------------------------------------------------
    # Scoop
    # ---------------------------------------------------------------------------
    ScoopBuckets       = @(
        'extras'
        'yaw'
    )

    ScoopPackages      = @(
        'jq'
        'scoop-search'
        'yaw'
        'yq'
    )

    # ---------------------------------------------------------------------------
    # Chocolatey
    # ---------------------------------------------------------------------------
    ChocoPackages      = @()

    # ---------------------------------------------------------------------------
    # PowerShell modules
    # ---------------------------------------------------------------------------
    PsModules          = @(
        'Pester'
        'PSIni'
        'PSScriptAnalyzer'
        'PSWindowsUpdate'
        'Terminal-Icons'
    )

    # ---------------------------------------------------------------------------
    # Windows optional features (DISM)
    # ---------------------------------------------------------------------------
    WindowsFeatures    = @(
        'Microsoft-Windows-Subsystem-Linux'
        'VirtualMachinePlatform'
        'LegacyComponents'
        'DirectPlay'
    )

    # ---------------------------------------------------------------------------
    # Appx packages to remove during debloat
    # Union of debloat-windows.ps1 and setup.ps1 lists; wildcards kept where broader.
    # ---------------------------------------------------------------------------
    AppxToRemove       = @(
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
        #'Microsoft.XboxIdentityProvider'
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
