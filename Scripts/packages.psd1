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
        'Microsoft.DotNet.Native.Runtime'
        'Microsoft.DotNet.Framework.DeveloperPack_4'
        'Microsoft.DotNet.Framework.DeveloperPack.4.6'
        'Microsoft.DirectX'
        'KhronosGroup.VulkanRT'
        'Microsoft.XNARedist'
        'Microsoft.EdgeWebView2Runtime'
        'Oracle.JavaRuntimeEnvironment'
        'Microsoft.AppInstaller'
        'Microsoft.UI.Xaml.2.8'
        'Microsoft.VCLibs.14'
        'Microsoft.VCLibs.Desktop.14'
        'Microsoft.WindowsAppRuntime.1.8'
        'Microsoft.WindowsAppRuntime.2.1'
        'Microsoft.GameInput'
        'Microsoft.VSTOR'
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
        'SQLite.SQLite'
        'Mozilla.sccache'
        'tamasfe.taplo'
        'DenoLand.Deno'
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
        'ajeetdsouza.zoxide'
        'DEVCOM.JetBrainsMonoNerdFont'
        'marlocarlo.psmux'
        'bootandy.dust'
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
        'HandBrake.HandBrake'
        'Gyan.FFmpeg.Shared'
        'CodeF0x.ffzap'
        # Image / graphics
        'GIMP.GIMP'
        'KDE.Krita'
        'tannerhelland.PhotoDemon'
        'Greenshot.Greenshot'
        'XnSoft.XnConvert'
        'SaeraSoft.CaesiumImageCompressor'
        'OliverBetz.ExifTool'
        'TimoKokkonen.Jpegoptim'
        'Google.Libwebp'
        # Compression / files
        '7zip.7zip'
        'aria2.aria2'
        'LIGHTNINGUK.ImgBurn'
        'qarmin.czkawka.cli'
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
        'Microsoft.Sysinternals.Autoruns'
        'Microsoft.Sysinternals.Autologon'
        'Obsidian.Obsidian'
        'memstechtips.Winhance'
        'Nextcloud.NextcloudDesktop'
        'Microsoft.WSL'
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
        'Rufus.Rufus'
        'WinFsp.WinFsp'
        'ClockworkMod.UniversalADBDriver'
        'Google.PlatformTools'
        # Disk / storage / cleanup
        'BleachBit.BleachBit'
        'maharmstone.btrfs'
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
    # winbtrfs removed 2026-07-10: same upstream project (maharmstone/btrfs) is
    # tracked via winget as 'maharmstone.btrfs' in WingetApplications, sourced
    # directly from the author rather than a community re-package.
    ChocoPackages      = @()

    # ---------------------------------------------------------------------------
    # Bun global packages
    # ---------------------------------------------------------------------------
    BunPackages        = @(
        '@ast-grep/cli'
        '@biomejs/biome'
        '@colbymchenry/codegraph'
        '@kilocode/cli'
        '@vtsls/language-server'
        '@zed-industries/vscode-langservers-extracted'
        'typescript-language-server'
        'yaml-language-server'
    )

    # ---------------------------------------------------------------------------
    # npm global packages
    # ---------------------------------------------------------------------------
    NpmPackages        = @(
        'oh-my-claude-sisyphus'
    )

    # ---------------------------------------------------------------------------
    # Cargo packages (cargo-binstall)
    # ---------------------------------------------------------------------------
    # Plain strings install from crates.io (`cargo install <name>`). A hashtable
    # entry with a Git key installs from that repository instead
    # (`cargo install --git <url>`) - used for packages not published to crates.io.
    CargoPackages      = @(
        'cargo-binstall'
        'cargo-cache'
        'cargo-update'
        @{ Name = 'rtk'; Git = 'https://github.com/rtk-ai/rtk' }
    )

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
