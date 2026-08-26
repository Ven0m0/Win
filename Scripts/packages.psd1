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
    # Runtimes
    # ---------------------------------------------------------------------------
    WingetRuntimes     = @(
        'abbodi1406.vcredist'
        'Microsoft.DotNet.DesktopRuntime.10'
        'Microsoft.DotNet.DesktopRuntime.9'
        'Microsoft.DotNet.DesktopRuntime.8'
        'Microsoft.DotNet.DesktopRuntime.7'
        'Microsoft.DotNet.Framework.DeveloperPack_4'
        'Microsoft.DirectX'
        'KhronosGroup.VulkanRT'
        'Microsoft.XNARedist'
        'Microsoft.EdgeWebView2Runtime'
        'Microsoft.AppInstaller'
        'Microsoft.VCLibs.Desktop.14'
        'Microsoft.WindowsAppRuntime.2'
        'Microsoft.GameInput'
    )

    # ---------------------------------------------------------------------------
    # Build toolchains — compilers, linters, formatters, language tooling
    # ---------------------------------------------------------------------------
    WingetToolchains   = @(
        'MartinStorsjo.LLVM-MinGW.UCRT'
        'Rustlang.Rustup'
        'Mozilla.sccache'
        'RubyInstallerTeam.Ruby.4.0'
        'Microsoft.VisualStudio.BuildTools'
        'astral-sh.uv'
        'Oven-sh.Bun'
        'DenoLand.Deno'
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
        'OpenJS.NodeJS'
        'Python.Python.3.14'
        'jdx.mise'
        'topgrade-rs.topgrade'
        'sinelaw.fresh-editor'
        'Anthropic.ClaudeCode'
        'Anthropic.Claude'
        'SST.OpenCodeDesktop'
        'Microsoft.Coreutils'
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
        'gerardog.gsudo'
        'yt-dlp.yt-dlp'
    )

    # ---------------------------------------------------------------------------
    # Applications — media, productivity, gaming, system utilities, security
    # ---------------------------------------------------------------------------
    # Reconciled 2026-06-17 to match currently-installed software (winget export).
    WingetApplications = @(
        # Media / video / audio
        'VideoLAN.VLC'
        'OBSProject.OBSStudio'
        #'Meltytech.Shotcut'
        'KDE.Kdenlive'
        'HandBrake.HandBrake'
        'Gyan.FFmpeg'
        'CodeF0x.ffzap'
        # Image / graphics
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
        # 'Ablaze.Floorp'
        'ImputNet.Helium'
        # Gaming
        'Valve.Steam'
        'EpicGames.EpicGamesLauncher'
        'PrismLauncher.PrismLauncher'
        'smartfrigde.Legcord'
        # Productivity / utilities
        #'Microsoft.PowerToys'
        'AutoHotkey.AutoHotkey'
        #'ONLYOFFICE.DesktopEditors'
        'TheDocumentFoundation.LibreOffice'
        'Microsoft.Sysinternals.Autoruns'
        'Microsoft.Sysinternals.Autologon'
        'Obsidian.Obsidian'
        'memstechtips.Winhance'
        'Nextcloud.NextcloudDesktop'
        'Microsoft.WSL'
        'Bitwarden.Bitwarden'
        'Bitwarden.CLI'
        # Package managers / install helpers
        'Devolutions.UniGetUI'
        # System / drivers / hardware
        'Guru3D.Afterburner.Beta'
        'SteelSeries.GG'
        'ViGEm.ViGEmBus'
        'Nefarius.HidHide'
        'TechPowerUp.NVCleanstall'
        'GlennDelahoy.SnappyDriverInstallerOrigin'
        'xHybred.NVPIRevamped'
        'Wagnardsoft.DisplayDriverUninstaller'
        #'Nvidia.PhysX'
        'REALiX.HWiNFO'
        # 'Intel.IntelExtremeTuningUtility'
        'Ventoy.Ventoy'
        # 'Rufus.Rufus'
        # 'WinFsp.WinFsp'
        # 'ClockworkMod.UniversalADBDriver'
        # 'Google.PlatformTools'
        # Disk / storage / cleanup
        'BleachBit.BleachBit'
        'maharmstone.btrfs'
        'AntibodySoftware.WizTree'
        'lostindark.DriverStoreExplorer'
        'Nlitesoft.NTLite'
        # Uninstallers / maintenance
        'RevoUninstaller.RevoUninstaller'
        # Gaming (added)
        'Guru3D.RTSS'
        'PlayStation.PSRemotePlay'
        'Playnite.Playnite'
        'StreetPea.chiaki-ng'
        'GameSir.GameSirConnect'
        'Oracle.VirtualBox'
        'CakeWallet.CakeWallet'
        # Dev / CLI (added)
        'ShareX.ShareX'
        'afkarxyz.SpotiFLAC'
        'yt-dlp.FFmpeg'
        'Gyan.FFmpeg'
        'beeradmoore.dlss-swapper'
        'Recol.DLSSUpdater'
        # Windows tooling (added)
        'Microsoft.WindowsADK'
        'Microsoft.WindowsADK.WinPEAddon'
        'Microsoft.OSCDIMG'
    )

    # ---------------------------------------------------------------------------
    # Manual installs — no winget package; installed via dedicated script
    # ---------------------------------------------------------------------------
    ManualInstalls     = @(
        #@{ Name = 'DLSSync'; Script = 'third-party\dlssync\install-dlssync.ps1' }
        @{ Name = 'Ds4Windows'; Script = 'third-party\ds4windows\install-ds4windows.ps1' }
    )

    # ---------------------------------------------------------------------------
    # Scoop
    # ---------------------------------------------------------------------------
    ScoopBuckets       = @(
        'extras'
        'java'
        @{ Name = 'ven0m0'; Url = 'https://github.com/Ven0m0/scoop-bucket' }
    )

    # graalvm-oracle-jdk is Oracle GraalVM (GraalVM Free Terms and Conditions license,
    # includes native-image and the enterprise Truffle/SVM modules) - NOT graalvm-jdk,
    # graalvm25-jdk, or graalvm-jdk-dev, which are all GraalVM Community Edition (GPL-2.0)
    # despite similar names. Sets JAVA_HOME/GRAALVM_HOME itself via the manifest's env_set.
    ScoopPackages      = @(
        'azaharplus'
        'eden'
        'fclones'
        'graalvm-oracle-jdk'
        'jq'
        'scoop-search'
        'yq'
        'snappy-driver-installer-origin'
        'lessmsi'
        'innounp'
        'dark'
    )

    # ---------------------------------------------------------------------------
    # Chocolatey
    # ---------------------------------------------------------------------------
    # winbtrfs removed 2026-07-10: same upstream project (maharmstone/btrfs) is
    # tracked via winget as 'maharmstone.btrfs' in WingetApplications, sourced
    # directly from the author rather than a community re-package.
    ChocoPackages      = @(
        'dolphin'
    )

    # ---------------------------------------------------------------------------
    # Bun global packages
    # ---------------------------------------------------------------------------
    BunPackages        = @(
        '@biomejs/biome'
        '@colbymchenry/codegraph'
        '@kilocode/cli'
        '@vtsls/language-server'
        '@zed-industries/vscode-langservers-extracted'
        'typescript-language-server'
        'yaml-language-server'
        '@googleworkspace/cli'
    )

    # ---------------------------------------------------------------------------
    # npm global packages
    # ---------------------------------------------------------------------------
    NpmPackages        = @(
        'oh-my-claude-sisyphus'
        'context-mode'
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
        'cargo-edit'
        'agnix-cli'
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
        'Microsoft.WinGet.Client'
        'Microsoft.WinGet.CommandNotFound'
    )

    # ---------------------------------------------------------------------------
    # Windows optional features (DISM)
    # ---------------------------------------------------------------------------
    WindowsFeatures    = @(
        'Microsoft-Windows-Subsystem-Linux'
        'VirtualMachinePlatform'
        'LegacyComponents'
        'DirectPlay'
        'MediaPlayback'
        'Microsoft-Hyper-V-All'
        'NetFx3'
        'NetFx4-AdvSrvs'
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
