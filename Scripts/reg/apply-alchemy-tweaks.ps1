#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Applies the alchemy/ tiered registry tweak collection (GPU scheduling,
    DWM, DirectX, kernel/DPC, MMCSS, NVMe, NVIDIA, power).
.DESCRIPTION
    Ports alchemy/Officially-Verified-main and Verified-Tweaks-main (applied
    always) plus Experimental-Tweaks-main (opt-in via -IncludeExperimental).

    Deliberately skipped (kept from upstream research, not re-derived here):
    machine-specific Video/Class-GUID priority keys ("Base and OverTarget
    Priorities" - no corroboration these affect WDDM scheduling); "Max
    Pending Interrupts" and "Apply Kernel Tweaks.bat" (invented env-var /
    WDK driver-function names nothing reads); "General GPU Tweaks #1"
    (unconfirmed keys, or a default given as a no-op); "Priority Control
    Tweaks" values folded into the Experimental region below instead of a
    separate skip; MMCSS's AlwaysOn/LazyMode (alchemy's own driver
    reverse-engineering note says these two names are never read -
    SystemResponsiveness is the value that actually matters and is applied
    instead); DWM's OverlayQualifyCount/OverlayDisqualifyCount/
    DisableAdvancedDirectFlip (user-reported black-screen blinking in
    fullscreen games - these are the MPO promotion/demotion hysteresis
    counters; at 0 there is no debounce, so DWM re-qualifies the overlay
    plane every frame and each transition is a black flash); "Disable Storage
    D3 In Modern Standby" (no single confirmed registry path even in
    alchemy's own note - it's set per storage device/driver, not one global
    key); "Disable VBS-HVCI" (real security reduction, alchemy itself hedges
    on it) and "Priority Separation" (alchemy's own note says Game Mode
    silently nullifies the foreground boost on 23H2).

    NtfsDisableLastAccessUpdate/NtfsDisable8dot3NameCreation ("File System
    Tweaks") are applied unconditionally in Set-KernelTweak even though
    alchemy only ever documented them as prose (no shipped .reg) -- both are
    low-risk NTFS behavior tunables. The Experimental region also applies
    GlobalDisableThirdPartyEnhancements ("Disable Third-Party Audio
    Enhancements"), another prose-only recommendation with a concrete,
    low-risk value. Set-DirectXTweak additionally applies "General DirectX
    Tweaks (5)" to the native HKLM\...\Direct3D hive (distinct from the HKCU
    block already there).

    A handful of values ported from the separate Batlez-Tweaks.bat collection
    (vendored elsewhere in this repo) close gaps the alchemy-sourced tweaks
    above left open: NoLazyMode/LazyModeTimeout and the MMCSS
    Tasks\{Audio,Games,"Pro Audio",DisplayPostProcessing} scheduler profiles
    (Set-MmcssTweak -- real, documented categories, unlike the AlwaysOn/
    LazyMode no-ops already skipped above), PowerThrottlingOff
    (Set-PowerTweak), DisablePagingExecutive (Set-KernelTweak), and the Game
    Bar/Game DVR disable bundle (Set-GameBarTweak). Batlez-Tweaks.bat also
    contains a large amount of legacy/no-op cargo-cult content (dead TCP
    Chimney/WZC keys, AFD buffer tuning superseded by modern auto-tuning) and
    some actively counterproductive values (disabling WPF hardware
    acceleration and Media Foundation hardware video transforms system-wide)
    that were deliberately not ported.

    Flagged, not removed: the DWM (SuperWetEnabled/UseHWDrawListEntriesOnWARP)
    and DirectX DXGKrnl blocks below ARE genuinely read by dwm.exe/dxgkrnl.sys
    per community reverse-engineering (not placebo) - but the exact same
    value sets, plus the taskkill+restart of dwm.exe, are also documented as
    Trojan.KillProc2.38961's payload by Dr.Web. Very likely coincidental
    reuse of a popular tweak list by malware authors, not evidence the
    values themselves are malicious, but it's a real chance of an AV/EDR
    false positive on this file. Remove those two blocks yourself if that
    risk isn't acceptable.
.PARAMETER IncludeExperimental
    Also apply the Experimental tier (unverified, apply at own risk per
    upstream README).
.PARAMETER NoRestorePoint
    Skip creating a restore point before applying changes.
.EXAMPLE
    .\apply-alchemy-tweaks.ps1
    Applies the Officially-Verified and Verified tiers.
.EXAMPLE
    .\apply-alchemy-tweaks.ps1 -IncludeExperimental
    Also applies the opt-in Experimental tier.
.NOTES
    No -Restore switch: most of this is one-way registry pushes with no
    single well-defined "default" (90+ Resource Set policy keys, Power
    Profile event priority deletions, etc.) -- restoring everything means
    re-running per-tweak revert files from alchemy/, or a registry backup
    taken before this script. Roll back via the restore point created below.
#>
param(
    [switch]$IncludeExperimental,
    [switch]$NoRestorePoint
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot/../Common.ps1"

function Set-RegistryValueTable {
    <#
    .SYNOPSIS
        Applies a table of Name = Data registry values under one path.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Values,
        [string]$Type = 'REG_DWORD'
    )
    foreach ($kv in $Values.GetEnumerator()) {
        Set-RegistryValue -Path $Path -Name $kv.Key -Type $Type -Data $kv.Value
    }
}

#region Officially-Verified: GPU Preemption / Resource Sets / Serialize Timer / Long Paths
function Set-OfficiallyVerifiedTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "Applying Officially-Verified tweaks..." -ForegroundColor Cyan

    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler" `
        -Name "EnablePreemption" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" `
        -Name "SerializeTimerExpiration" -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" `
        -Name "LongPathsEnabled" -Type REG_DWORD -Data "1"

    $policySets = @(
        'ApplicationService', 'ApplicationServiceElastic', 'ApplicationServiceHighPriElastic',
        'ApplicationServiceHighPriority', 'ApplicationServiceRemote', 'AppToAppTarget', 'BackgroundAudioPlayer',
        'BackgroundCachedFileUpdater', 'BackgroundTaskCompletion', 'BackgroundTaskDebug', 'BackgroundTransfer',
        'BackgroundTransferNetworkState', 'Balloon', 'CalendarProviderAsChild', 'CallingEvent',
        'CallingEventHighPriority', 'ChatMessageNotification', 'ComponentTarget', 'ContinuousBackgroundExecution',
        'CortanaSpeechBackground', 'CreateProcess', 'DefaultModernBackgroundTask', 'DefaultPPLE', 'DefaultPPLE2',
        'EmCreateProcess', 'EmCreateProcessNormalPriority', 'EmptyHost', 'EmptyHostHighPriority', 'EmptyHostPPLE',
        'FileProviderTarget', 'ForegroundAgent', 'ForegroundCachedFileUpdater', 'ForegroundTaskCompletion', 'Frozen',
        'GenericExtendedExecution', 'GeofenceTask', 'HighPriorityBackgroundAgent', 'HighPriorityBackgroundDemoted',
        'HighPriorityBackgroundTransfer', 'IoTStartupTask', 'JumboForegroundAgent', 'LmaBackgroundTaskCompletion',
        'LmaDefaultModernBackgroundTask', 'LmaPrelaunchForeground', 'LmaUiDebugModeForeground', 'LmaUiFrozen',
        'LmaUiFrozenDNCS', 'LmaUiFrozenDNK', 'LmaUiFrozenHighPriority', 'LmaUiModernForeground',
        'LmaUiModernForegroundLarge', 'LmaUiPaused', 'LmaUiPausedDNK', 'LmaUiPausedHighPriority', 'LmaUiPausing',
        'LongRunningBluetooth', 'LongRunningControlChannel', 'LongRunningSensor', 'MediaProcessing',
        'OemBackgroundAgent', 'OemTask', 'PendingDefaultPPLE', 'PiP', 'PreinstallTask', 'PrelaunchForeground',
        'PushTriggerTask', 'ResourceIntensive', 'ShareDataPackageHost', 'ShortRunningBluetooth',
        'TaskCompletionHighPriority', 'UiComposer', 'UiDebugModeForeground', 'UiForegroundDNK', 'UiFrozen',
        'UiFrozenDNCS', 'UiFrozenDNK', 'UiFrozenHighPriority', 'UiLockScreen', 'UiModernForeground',
        'UiModernForegroundExtended', 'UiModernForegroundLarge', 'UiOverlay', 'UiPaused', 'UiPausedDNK',
        'UiPausedHighPriority', 'UiPausing', 'UiPausingLowPriority', 'UiShellCustom1', 'UiShellCustom2',
        'UiShellCustom3', 'UiShellCustom4', 'VideoTranscoding', 'VoipActiveCallBackground',
        'VoipActiveCallBackgroundPriority', 'VoipActiveCallForeground', 'VoipForegroundWorker',
        'VoipSuspendedBackground', 'VoipWorker', 'Vpn', 'WebAuthSignIn'
    )
    foreach ($policy in $policySets) {
        Set-RegistryValueTable -Path "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\PolicySets\$policy" -Type REG_SZ -Values @{
            CPU               = "UnmanagedAboveNormal"
            ExternalResources = "ResourceIntensive"
            Flags             = "Foreground"
            Importance        = "Critical"
            IO                = "NoCap"
            Memory            = "NoCap"
        }
    }
}
#endregion

#region Verified: DirectX (folded in from the former Scripts/reg/DirectX.reg)
function Set-DirectXTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "Applying DirectX tweaks..." -ForegroundColor Cyan

    $direct3dCommon = @{
        DisableVidMemVBs = "0"
        'MMX Fast Path'  = "1"
        FlipNoVsync      = "1"
    }
    foreach ($base in 'HKCU\SOFTWARE\Microsoft\Direct3D', 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Direct3D') {
        Set-RegistryValueTable -Path $base -Values $direct3dCommon
    }
    Set-RegistryValueTable -Path "HKCU\SOFTWARE\Microsoft\Direct3D" -Values @{
        UseNonLocalVidMem       = "1"
        FullDebug               = "0"
        DisableDM               = "1"
        EnableMultimonDebugging = "0"
        LoadDebugRuntime        = "0"
        FewVertices             = "1"
        DisableMMX              = "0"
        UseMMXForRGB            = "1"
        UseVSync                = "0"
    }

    Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Direct3D\ReferenceDevice" -Name "AllowAsync" -Type REG_DWORD -Data "1"
    foreach ($base in 'HKLM\SOFTWARE\Microsoft\Direct3D\Drivers', 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Direct3D\Drivers') {
        Set-RegistryValue -Path $base -Name "SoftwareOnly" -Type REG_DWORD -Data "0"
    }

    # "General DirectX Tweaks (5)" -- native HKLM hive, distinct from the HKCU
    # block above (Direct3D reads machine-wide defaults from here and per-user
    # overrides from HKCU; neither block supersedes the other).
    Set-RegistryValueTable -Path "HKLM\SOFTWARE\Microsoft\Direct3D" -Values @{
        UseNonLocalVidMem       = "1"
        FullDebug               = "0"
        DisableDM               = "1"
        EnableMultimonDebugging = "0"
        LoadDebugRuntime        = "0"
        FewVertices             = "1"
        DisableMMX              = "0"
        UseMMXForRGB            = "1"
        DisableVidMemVBs        = "0"
    }
    foreach ($base in 'HKLM\SOFTWARE\Microsoft\DirectDraw', 'HKLM\SOFTWARE\WOW6432Node\Microsoft\DirectDraw') {
        Set-RegistryValueTable -Path $base -Values @{ EmulationOnly = "0"; UseNonLocalVidMem = "1" }
    }

    $d3dFlags = @{
        D3D11_ALLOW_TILING                                = "1"
        D3D11_DEFERRED_CONTEXTS                            = "1"
        D3D11_ENABLE_DYNAMIC_CODEGEN                       = "1"
        D3D11_MULTITHREADED                                = "1"
        D3D12_ALLOW_TILING                                 = "1"
        D3D12_CONSERVATIVE_RASTERIZATION_MODE_ON           = "1"
        D3D12_CPU_PAGE_TABLE_ENABLED                       = "1"
        D3D12_DEFERRED_CONTEXTS                            = "1"
        D3D12_ENABLE_RUNTIME_DRIVER_OPTIMIZATIONS          = "1"
        D3D12_ENABLE_UNSAFE_COMMAND_BUFFER_REUSE           = "1"
        D3D12_HEAP_SERIALIZATION_ENABLED                   = "1"
        D3D12_MAP_HEAP_ALLOCATIONS                         = "1"
        D3D12_MULTITHREADED                                = "1"
        D3D12_RESIDENCY_MANAGEMENT_ENABLED                 = "1"
        D3D12_RESOURCE_ALIGNMENT                           = "1"
        DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE               = "1"
        DXGI_PRESENT_ALLOW_TEARING                         = "1"
        DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING                 = "1"
        DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT = "1"
        DXGI_SWAP_EFFECT_FLIP_DISCARD                      = "1"
        DXGI_USE_OPTIMIZED_SWAP_CHAIN                      = "1"
        DXMaxFrameLatency                                  = "1"
        DXSpinWaitTimeout                                  = "0xfffffff"
    }
    foreach ($base in 'HKLM\SOFTWARE\Microsoft\DirectX', 'HKLM\SOFTWARE\WOW6432Node\Microsoft\DirectX') {
        Set-RegistryValueTable -Path $base -Values $d3dFlags
    }

    # See the module-level .DESCRIPTION note on the AV/EDR false-positive risk
    # of this block (Trojan.KillProc2.38961 payload reuses the same keys).
    # 13 values, matching alchemy's "General DirectX Tweaks (2)" exactly --
    # MonitorLatencyTolerance/MonitorRefreshLatencyTolerance belong to a
    # different key (GraphicsDrivers\Power) and are applied there instead,
    # under Set-ExperimentalTweak's Latency Tolerance block.
    foreach ($name in 'CreateGdiPrimaryOnSlaveGPU', 'DriverSupportsCddDwmInterop', 'DxgkCddSyncDxAccess',
        'DxgkCddSyncGPUAccess', 'DxgkCddWaitForVerticalBlankEvent', 'DxgkCreateSwapChain',
        'DxgkFreeGpuVirtualAddress', 'DxgkOpenSwapChain', 'DxgkShareSwapChainObject',
        'DxgkWaitForVerticalBlankEvent', 'DxgkWaitForVerticalBlankEvent2', 'SwapChainBackBuffer',
        'TdrResetFromTimeoutAsync') {
        Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Services\DXGKrnl" -Name $name -Type REG_DWORD -Data "1"
    }

    # Skipped: fabricated DX_*/__GL_* Session Manager\Environment vars from an
    # earlier version of this file -- same "invented name nothing reads"
    # problem as the skipped "Max Pending Interrupts" tweak.

    Set-RegistryValue -Path "HKCU\Software\Microsoft\DirectX\GraphicsSettings" -Name "SwapEffectUpgradeCache" `
        -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKCU\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" `
        -Type REG_SZ -Data "SwapEffectUpgradeEnable=1;;VRROptimizeEnable=0;AutoHDREnable=0;"
}
#endregion

#region Verified: DWM
function Set-DwmTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "Applying DWM tweaks..." -ForegroundColor Cyan

    Set-RegistryValueTable -Path "HKLM\SOFTWARE\Microsoft\Windows\DWM" -Values @{
        FrameLatency                       = "2"
        ForceDirectDrawSync                = "0"
        MaxQueuedPresentBuffers            = "1"
        SuperWetEnabled                    = "1"
        SDRBoostPercentOverride            = "1"
        ResampleInLinearSpace              = "1"
        OneCoreNoDWMRawGameController      = "0"
        MPCInputRouterWaitForDebugger      = "0"
        InteractionOutputPredictionDisabled = "1"
        InkGPUAccelOverrideVendorWhitelist = "1"
        EnableRenderPathTestMode           = "0"
        FlattenVirtualSurfaceEffectInput   = "1"
        EnableCpuClipping                  = "1"
        DisallowNonDrawListRendering       = "1"
        DisableProjectedShadowsRendering   = "1"
        DisableProjectedShadows            = "1"
        DisableLockingMemory               = "1"
        DisableHologramCompositor          = "1"
        DisableDeviceBitmaps               = "1"
        DebugFailFast                      = "0"
        DDisplayTestMode                   = "0"
        UseHWDrawListEntriesOnWARP         = "1"
        ResampleModeOverride               = "1"
        RenderThreadWatchdogTimeoutMilliseconds = "0"
        ParallelModePolicy                 = "1"
        EnableResizeOptimization           = "1"
        EnableMegaRects                    = "1"
        EnableFrontBufferRenderChecks      = "0"
        EnableEffectCaching                = "1"
        EnableDesktopOverlays              = "0"
        EnablePrimitiveReordering          = "0"
        MaxD3DFeatureLevel                 = "0"
        ResizeTimeoutModern                = "0"
        ResizeTimeoutGdi                   = "0"
        HighColor                          = "0"
        DisableDrawListCaching             = "1"
        AnimationsShiftKey                 = "0"
        AnimationAttributionEnabled        = "0"
        EnableCommonSuperSets              = "1"
    }

    if ($PSCmdlet.ShouldProcess('dwm.exe', 'Restart to apply DWM registry changes')) {
        Stop-Process -Name dwm -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
        Start-Process -FilePath "$env:windir\system32\dwm.exe"
    }
}
#endregion

#region Verified: Kernel / single-key tweaks
function Set-KernelTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "Applying kernel and single-key tweaks..." -ForegroundColor Cyan

    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "EventProcessorEnabled" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "MaximumTunnelEntries" -Type REG_DWORD -Data "0"
    Set-RegistryValueTable -Path "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" -Values @{
        NtfsDisableLastAccessUpdate  = "1"
        NtfsDisable8dot3NameCreation = "1"
    }
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" `
        -Name "DisablePagingExecutive" -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
        -Name "NetworkThrottlingIndex" -Type REG_DWORD -Data "10"
    if ($PSCmdlet.ShouldProcess('disabledynamictick', 'bcdedit /set')) {
        $null = bcdedit /set disabledynamictick yes
    }
    # Skipped: "Max Pending Interrupts.reg" invented ~50 env-var names under
    # Session Manager\Environment that nothing in the kernel or drivers reads.

    Set-RegistryValueTable -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Values @{
        InterruptSteeringDisabled = "1"
        DistributeTimers          = "1"
        DpcWatchdogProfileOffset  = "0"
        DpcTimeout                = "0"
        IdealDpcRate              = "1"
        MaximumDpcQueueDepth      = "1"
        MinimumDpcRate            = "1"
        DpcWatchdogPeriod         = "0"
        SplitLargeCaches          = "1"
    }
    # Skipped: alchemy's "Thread DPC" tweak set ThreadDpcEnable=0 (ordinary,
    # non-preemptible DPCs -- pre-Vista behavior). Microsoft's own driver docs
    # recommend the opposite: threaded DPCs (the value=1 default) can be
    # preempted by another DPC, while ordinary DPCs block every thread on the
    # CPU for their full duration. The "disable it for lower gaming latency"
    # claim traces to enthusiast forums, not Microsoft guidance, so this is
    # left at the system default (1) instead of being forced to 0.
    # Skipped: "Apply Kernel Tweaks.bat" also set MaxDynamicTickDuration,
    # MaximumSharedReadyQueueSize, BufferSize, IoQueueWorkItem(ToNode/Ex),
    # IoQueueThreadIrp, ExTryQueueWorkItem, ExQueueWorkItem, IoEnqueueIrp,
    # XMMIZeroingEnable, UseNormalStack, UseNewEaBuffering,
    # StackSubSystemStackSize under this same key -- the IoQueueWorkItem-style
    # names are real WDK kernel-mode *driver API function names*, not
    # registry-read tunables; writing a DWORD with a function's name does
    # nothing. The rest are undocumented values with community-reported BSODs.
}
#endregion

#region Verified: MMCSS
function Set-MmcssTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "Applying MMCSS tweaks (SystemResponsiveness, task profiles, service enabled)..." -ForegroundColor Cyan

    Set-RegistryValueTable -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Values @{
        SystemResponsiveness = "10"
        NoLazyMode           = "1"
        LazyModeTimeout      = "10000"
    }
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Services\MMCSS" -Name "Start" -Type REG_DWORD -Data "2"
    # Skipped: AlwaysOn/LazyMode -- alchemy's own NOTE.txt (driver reverse
    # engineering) says these two value names are never read by the MMCSS
    # driver. NoLazyMode/LazyModeTimeout are among the values that same note
    # confirms the driver actually reads (ported from Batlez-Tweaks.bat).

    # MMCSS task scheduler profiles (ported from Batlez-Tweaks.bat) -- real,
    # documented categories, distinct from the AlwaysOn/LazyMode no-ops above.
    $mmcssTasks = @{
        Audio                 = @{ Priority = '6'; Category = 'High' }
        DisplayPostProcessing = @{ Priority = '8'; Category = 'High' }
        Games                 = @{ Priority = '6'; Category = 'High'; Latency = 'True' }
        'Pro Audio'           = @{ Priority = '1'; Category = 'High' }
    }
    foreach ($task in $mmcssTasks.Keys) {
        $path = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\$task"
        Set-RegistryValue -Path $path -Name 'GPU Priority' -Type REG_DWORD -Data '8'
        Set-RegistryValue -Path $path -Name 'Priority' -Type REG_DWORD -Data $mmcssTasks[$task].Priority
        Set-RegistryValue -Path $path -Name 'Scheduling Category' -Type REG_SZ -Data $mmcssTasks[$task].Category
        if ($mmcssTasks[$task].Latency) {
            Set-RegistryValue -Path $path -Name 'Latency Sensitive' -Type REG_SZ -Data $mmcssTasks[$task].Latency
        }
    }
}
#endregion

#region Verified: NVMe
function Set-NvmeTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "Applying NVMe tweaks..." -ForegroundColor Cyan

    $nvmeValues = @{
        QueueDepth                = "64"
        NvmeMaxReadSplit           = "4"
        NvmeMaxWriteSplit          = "4"
        ForceFlush                 = "1"
        ImmediateData              = "1"
        MaxSegmentsPerCommand      = "256"
        MaxOutstandingCmds         = "256"
        ForceEagerWrites           = "1"
        MaxQueuedCommands          = "256"
        MaxOutstandingIORequests   = "256"
        NumberOfRequests           = "1500"
        IoSubmissionQueueCount     = "3"
        IoQueueDepth               = "64"
        HostMemoryBufferBytes      = "1500"
        ArbitrationBurst           = "256"
    }
    foreach ($base in "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters",
        "HKLM\SYSTEM\CurrentControlSet\Control\StorNVMe\Parameters\Device") {
        Set-RegistryValueTable -Path $base -Values $nvmeValues
    }
}
#endregion

#region Verified: NVIDIA
function Set-NvidiaTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "Applying NVIDIA tweaks..." -ForegroundColor Cyan

    foreach ($base in "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
        "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power",
        "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm",
        "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\NVAPI",
        "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak") {
        Set-RegistryValue -Path $base -Name "RmGpsPsEnablePerCpuCoreDpc" -Type REG_DWORD -Data "1"
    }
    Set-RegistryValue -Path "HKLM\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" `
        -Name "OptInOrOutPreference" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup" `
        -Name "SendTelemetryData" -Type REG_DWORD -Data "0"

    # Disable Dynamic Pstate + zero the HDCP key, applied to every detected NVIDIA
    # GPU via Common.ps1's Get-NvidiaGpuRegistryPath (no hardcoded PCI/Class GUIDs).
    $null = Set-NvidiaGpuRegistryValue -Name "DisableDynamicPstate" -Type REG_DWORD -Data "1"
    $null = Set-NvidiaGpuRegistryValue -Name "RMHdcpKeyglobZero" -Type REG_DWORD -Data "1"
}
#endregion

#region Verified: Power
function Set-PowerTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "Applying power tweaks..." -ForegroundColor Cyan

    $eventGuids = @(
        '{0AABB002-A307-447e-9B81-1D819DF6C6D0}', '{0c3d5326-944b-4aab-8ad8-fe422a0e50e0}',
        '{0DA965DC-8FCF-4c0b-8EFE-8DD5E7BC959A}', '{4569E601-272E-4869-BCAB-1C6C03D7966F}',
        '{8BC6262C-C026-411d-AE3B-7E2F70811A13}', '{a4a61b5f-f42c-4d23-b3ab-5c27df9f0f18}',
        '{c04a802d-2205-4910-ae98-3b51e3bb72f2}', '{D4140C81-EBBA-4e60-8561-6918290359CD}',
        '{EE1E4F72-E368-46b1-B3C6-5048B11C2DBD}'
    )
    foreach ($guid in $eventGuids) {
        Remove-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power\Profile\Events\{54533251-82be-4824-96c1-47b60b740d00}\$guid" `
            -Name "Pri"
    }
    Set-RegistryValue -Path ("HKLM\SYSTEM\CurrentControlSet\Control\Power\Profile\Events\" +
        "{54533251-82be-4824-96c1-47b60b740d00}\{0DA965DC-8FCF-4c0b-8EFE-8DD5E7BC959A}\{7E01ADEF-81E6-4e1b-8075-56F373584694}") `
        -Name "TimeLimitInSeconds" -Type REG_DWORD -Data "1"

    Set-RegistryValueTable -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" -Values @{
        DisableTaggedEnergyLogging   = "1"
        TelemetryMaxApplication      = "0"
        TelemetryMaxTagPerApplication = "0"
    }
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Throttle" `
        -Name "PerfEnablePackageIdle" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "PlatformAoAcOverride" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" `
        -Name "PowerThrottlingOff" -Type REG_DWORD -Data "1"
    Set-RegistryValueTable -Path "HKLM\SYSTEM\CurrentControlSet\Control\Processor" -Values @{
        CPPCEnable        = "0"
        AllowPepPerfStates = "0"
    }
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System" `
        -Name "CountOperations" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\fssProv" -Name "EncryptProtocol" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Services\pci\Parameters" -Name "ASPMOptOut" -Type REG_DWORD -Data "1"
    Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule" -Name "DisableRpcOver" -Type REG_DWORD -Data "1"
}
#endregion

#region Verified: Game Bar / Game DVR (ported from Batlez-Tweaks.bat)
function Set-GameBarTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Write-Host "Applying Game Bar / Game DVR tweaks..." -ForegroundColor Cyan

    Set-RegistryValueTable -Path "HKCU\SOFTWARE\Microsoft\GameBar" -Values @{
        AllowAutoGameMode         = "0"
        AutoGameModeEnabled       = "0"
        GameDVR_Enabled           = "0"
        UseNexusForGameBarEnabled = "0"
        GameDVR_FSEBehavior       = "2"
    }
}
#endregion

#region Experimental (opt-in, apply at own risk per upstream README)
function Set-ExperimentalTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "  [*] Experimental kernel tweaks..." -ForegroundColor Gray
    Set-RegistryValueTable -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Values @{
        PriorityControl            = "50"
        DisableOverlappedExecution = "0"
        TimeIncrement              = "15"
        QuantumLength               = "20"
    }
    # Skipped: "General GPU Tweaks #1.reg" set 13 GraphicsDrivers values to 0.
    # Most have no corroboration as real keys; the one confirmed-real key,
    # DisableOverlays, needs =1 to disable MPO overlays -- writing 0 matches
    # Windows' own default, i.e. a no-op even in the best case.

    Write-Host "  [*] Priority Control Tweaks..." -ForegroundColor Gray
    Set-RegistryValueTable -Path "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" -Values @{
        ForegroundBoost                   = "1"
        ThreadBoostType                   = "2"
        ThreadSchedulingModel             = "1"
        AdjustDpcThreshold                = "800"
        DeepIoCoalescingEnabled           = "1"
        IdealDpcRate                      = "800"
        SchedulerAssistThreadFlagOverride = "1"
    }

    Write-Host "  [*] DPC-ISR latency tolerance..." -ForegroundColor Gray
    foreach ($name in 'ExitLatency', 'ExitLatencyCheckEnabled', 'Latency', 'LatencyToleranceDefault',
        'LatencyToleranceFSVP', 'LatencyTolerancePerfOverride', 'LatencyToleranceScreenOffIR',
        'RtlCapabilityCheckLatency') {
        Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name $name -Type REG_DWORD -Data "1"
    }
    foreach ($name in 'DefaultD3TransitionLatencyActivelyUsed', 'DefaultD3TransitionLatencyIdleLongTime',
        'DefaultD3TransitionLatencyIdleMonitorOff', 'DefaultD3TransitionLatencyIdleNoContext',
        'DefaultD3TransitionLatencyIdleShortTime', 'DefaultD3TransitionLatencyIdleVeryLongTime',
        'DefaultLatencyToleranceIdle0', 'DefaultLatencyToleranceIdle0MonitorOff', 'DefaultLatencyToleranceIdle1',
        'DefaultLatencyToleranceIdle1MonitorOff', 'DefaultLatencyToleranceMemory', 'DefaultLatencyToleranceNoContext',
        'DefaultLatencyToleranceNoContextMonitorOff', 'DefaultLatencyToleranceOther',
        'DefaultLatencyToleranceTimerPeriod', 'DefaultMemoryRefreshLatencyToleranceActivelyUsed',
        'DefaultMemoryRefreshLatencyToleranceMonitorOff', 'DefaultMemoryRefreshLatencyToleranceNoContext', 'Latency',
        'MaxIAverageGraphicsLatencyInOneBucket', 'MiracastPerfTrackGraphicsLatency', 'MonitorLatencyTolerance',
        'MonitorRefreshLatencyTolerance', 'TransitionLatency') {
        Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" -Name $name -Type REG_DWORD -Data "1"
    }

    Write-Host "  [*] Resource management..." -ForegroundColor Gray
    foreach ($policy in 'HardCap0', 'Paused', 'SoftCapFull', 'SoftCapLow') {
        Set-RegistryValueTable -Path "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\$policy" -Values @{
            CapPercentage  = "0"
            SchedulingType = "0"
        }
    }
    foreach ($policy in 'SoftCapFullAboveNormal', 'SoftCapLowBackgroundBegin', 'UnmanagedAboveNormal') {
        Set-RegistryValueTable -Path "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\$policy" -Values @{
            CapPercentage  = "0"
            PriorityClass  = "32"
            SchedulingType = "0"
        }
    }
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Processor" -Name "Capabilities" -Type REG_DWORD -Data "0x7e666"
    Set-RegistryValue -Path "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\IO\NoCap" -Name "IOBandwidth" -Type REG_DWORD -Data "0"
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System" `
        -Name "IoEnableSessionZeroAccessCheck" -Type REG_DWORD -Data "1"
    foreach ($flag in 'BackgroundDefault', 'Frozen', 'FrozenDNCS', 'FrozenDNK', 'FrozenPPLE', 'Paused', 'PausedDNK',
        'Pausing', 'PrelaunchForeground', 'ThrottleGPUInterference') {
        Set-RegistryValue -Path "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Flags\$flag" `
            -Name "IsLowPriority" -Type REG_DWORD -Data "0"
    }
    # Skipped: "Base and OverTarget Priorities.reg" set BasePriority=200 /
    # OverTargetPriority=80 on ~90 device Class GUIDs. No corroboration that
    # these values affect GPU/device scheduling on modern WDDM.

    Write-Host "  [*] Disable third-party audio enhancements..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Audio" `
        -Name "GlobalDisableThirdPartyEnhancements" -Type REG_DWORD -Data "1"
    # Disables ALL third-party audio effect packs system-wide (vendor
    # spatial/EQ/mic-noise-suppression APOs); Microsoft inbox effects are
    # unaffected. Skip this function if you rely on vendor audio effects.

    # Skipped: "Disable Storage D3 In Modern Standby" -- StorageD3InModernStandby
    # has no single confirmed registry path even in alchemy's own note (it's
    # set per storage device/driver, not under one global key like the audio
    # value above); not implementing it here would mean guessing a path.
    # Skipped: "Disable VBS-HVCI" (real security reduction, alchemy explicitly
    # hedges on it) and "Priority Separation" (alchemy's own note says Game
    # Mode silently nullifies the foreground boost on 23H2).
}
#endregion

Request-AdminElevation

if (-not $NoRestorePoint) {
    New-RestorePoint -Description "Before apply-alchemy-tweaks"
}

Set-OfficiallyVerifiedTweak
Set-DirectXTweak
Set-DwmTweak
Set-KernelTweak
Set-MmcssTweak
Set-NvmeTweak
Set-NvidiaTweak
Set-PowerTweak
Set-GameBarTweak

if ($IncludeExperimental) {
    Write-Host ""
    Write-Host "Applying Experimental tweaks (unverified, apply at own risk)..." -ForegroundColor Yellow
    Set-ExperimentalTweak
}

Write-Host ""
Write-Host "Alchemy tweaks applied." -ForegroundColor Green
Write-Host "Note: disabledynamictick and several kernel/DWM values only take effect after a reboot." -ForegroundColor Yellow
