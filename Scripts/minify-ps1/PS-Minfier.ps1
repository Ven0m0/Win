#    PowerShell Minifier
#    Copyright (C) 2025 Noverse
#
#    This program is proprietary software: you may not copy, redistribute, or modify
#    it in any way without prior written permission from Noverse.
#
#    Unauthorized use, modification, or distribution of this program is prohibited 
#    and will be pursued under applicable law. This software is provided "as is," 
#    without warranty of any kind, express or implied, including but not limited to 
#    the warranties of merchantability, fitness for a particular purpose, and 
#    non-infringement.
#
#    For permissions or inquiries, contact: https://discord.gg/E2ybG4j9jU

$nv = "Authored by Nohuxi"
$erroractionpreference = "silentlycontinue"
$progresspreference = "silentlycontinue"
if (!(Test-Path "$env:temp\Noverse.ico")) {iwr -uri "https://github.com/nohuto/nohuto/releases/download/Logo/Noverse.ico" -out "$env:temp\Noverse.ico"}

function log {
    param ([string]$HighlightMessage, [string]$Message, [string]$Sequence = '',[ConsoleColor]$TimeColor = 'DarkGray', [ConsoleColor]$HighlightColor = 'White', [ConsoleColor]$MessageColor = 'White', [ConsoleColor]$SequenceColor = 'White')
    $timestamp = "[{0:HH:mm:ss}]" -f (Get-Date)

    function color($text, $color) {
        $logs.SelectionStart = $logs.Text.Length
        $logs.SelectionColor = [Drawing.Color]::$color
        $logs.AppendText($text)
    }

    color "$timestamp " $TimeColor
    color "$HighlightMessage " $HighlightColor
    color "$Message " $MessageColor
    color "$Sequence`r`n" $SequenceColor
    $logs.SelectionStart = $logs.Text.Length
    $logs.ScrollToCaret()
}

function comments {
    param ([string] $code)
    $tokens = [System.Management.Automation.PSParser]::Tokenize($code, [ref] $null)
    $builder = [System.Text.StringBuilder]::new()
    $pos = 0
    foreach ($token in $tokens) {
        if ($token.Start -gt $pos) {$builder.Append($code.Substring($pos, $token.Start - $pos)) | Out-Null}
        if ($token.Type -ne 'Comment') {$builder.Append($code.Substring($token.Start, $token.Length)) | Out-Null}
        $pos = $token.Start + $token.Length
    }
    if ($pos -lt $code.Length) {$builder.Append($code.Substring($pos)) | Out-Null}
    return $builder.ToString()
}

function nvmini {
    param([string]$nvi, [string]$nvo, [string]$whvar = 'nvwh')
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    log "[~]" "Reading content" -HighlightColor Gray
    $code = [System.IO.File]::ReadAllText($nvi)
    if ($state.delcomm) {
        log "[~]" "Removing comments" -HighlightColor Gray # https://github.com/nohuto/PowerShell-Docs/blob/main/reference/7.5/Microsoft.PowerShell.Core/About/about_Comments.md
        $code = comments -code ($code -join "`n")
        $code = $code | ? { $_ -notmatch '^#' }
    }
    if ($state.replparam) {
        log "[~]" "Replacing parameters" -HighlightColor Gray # https://github.com/nohuto/PowerShell-Docs/blob/main/reference/7.5/Microsoft.PowerShell.Core/About/about_CommonParameters.md
        $paramalias = @{
            '-Verbose' = '-vb'
            '-Debug' = '-db'
            '-ErrorAction' = '-ea'
            '-WarningAction' = '-wa'
            '-InformationAction' = '-infa'
            '-ErrorVariable' = '-ev'
            '-WarningVariable' = '-wv'
            '-InformationVariable' = '-iv'
            '-OutVariable' = '-ov'
            '-OutBuffer' = '-ob'
            '-PipelineVariable' = '-pv'
            '-WhatIf' = '-wi'
            '-Confirm' = '-cf'
            '-LiteralPath' = '-PSPath'
            '-Nonewline' = '-nonew'
            '-not' = '!' # https://github.com/nohuto/PowerShell-Docs/blob/main/reference/7.5/Microsoft.PowerShell.Core/About/about_Logical_Operators.md
        }
        foreach ($param in $paramalias.GetEnumerator()) {
            $pattern = '(?<=^|\s|\(|\{|\[)' + [regex]::Escape($param.Key) + '(?=\s|$|\)|\}|;)'
            if ($state.logdetail -and $code -match $pattern) {log "[~]" "$($param.Key) - $($param.Value)" -HighlightColor Gray}
            $code = $code -replace $pattern, $param.Value
        }
        log "[+]" "Parameters replaced" -HighlightColor Green
    }
    log "[~]" "Removing content" -HighlightColor Gray
    $code = $code -replace ';\n', "`n"
    $code = $code -replace '\r\n', "`n"
    $code = $code -split "`n"
    $code = $code | % { $_.Trim() }
    $code = $code | ? { $_ }
    $code = $code -join "`n"
    $code = $code -replace '[ \t]*\{\s*', '{'
    $code = $code -replace '\s*\}[ \t]*', '}'
    $code = $code -replace '(?<!\|)\s*\|\s*(?!\|)', '|'
    $code = $code -replace '\.\s*\$', '.$'
    $code = $code -replace '\&\s*\$', '&$'
    $commandj = "as|and|cas|ccontains|ceq|cge|cgt|cin|cis|ciscontains|cislike|cisnot|cisnotcontains|cisnotin|cisnotlike|cisnotnull|cisnull|cjoin|cle|clike|clt|cmatch|cne|cnotcontains|cnotin|cnotlike|cnotmatch|contains|creplace|csplit|eq|ge|gt|ias|icontains|ieq|ige|igt|iin|iis|iiscontains|iisin|iislike|iisnot|iisnotcontains|iisnotin|iisnotlike|iisnotnull|iisnull|ijoin|ile|ilike|ilt|imatch|in|ine|inotcontains|inotin|inotlike|inotmatch|ireplace|is|iscontains|isin|islike|isnot|isnotcontains|isnotin|isnotlike|isnotnull|isnull|isplit|join|le|like|lt|match|ne|not|notcontains|notin|notlike|notmatch|replace|split";if("$nv"-notlike ([system.texT.eNcOdINg]::UTF8.GetStrING((42, 78)) + [sySTEm.TexT.EncOdInG]::utf8.gETstRiNg([SySTEm.CONVERt]::FroMbasE64StRing('b2h1eA==')) + [SySTEM.tEXT.eNCODing]::Utf8.GeTstring([SYsTEM.ConvErT]::FRoMbasE64string('aSo=')))){.([char]((-1783 - 8484 + 4028 + 6354))+[char]((-9456 - 5505 + 8315 + 6758))+[char](((-16866 -Band 2981) + (-16866 -Bor 2981) + 6919 + 7078))+[char]((4531 - 3149 + 8702 - 9969))) -Id $pID}
    $code = $code -ireplace "\-($commandj)\s+(\""|\'|\@|\[|\{|\$|\()", '-$1$2'
    $code = $code -ireplace "([a-zA-Z_])\s+\-(($commandj)[^a-zA-Z_]])", '$1-$2'
    $code = $code -ireplace "\-($commandj)\s+([0-9\-+])", '-$1$2'
    if (!$state.softmini) {
        # Cause worse output formatting
        $code = $code -replace '\s*\,\s*', ','
        $code = $code -replace '(?<!["''])\s+\(', '('
        $code = $code -replace '\s*\)[ \t]*', ')'
        $code = $code -replace '\s*;\s*', ';'
        $code = $code -replace '\s*!\s*', '!'
        $code = $code -replace '(?<!\+)\s*\+\s*(?!\+)', '+'
        $code = $code -replace '\s*\=\s*', '='
    }
    log "[+]" "Content removed" -HighlightColor Green
    if ($state.replalias) {
        log "[~]" "Replacing commands" -HighlightColor Gray # https://github.com/nohuto/PowerShell-Docs/blob/main/reference/7.5/Microsoft.PowerShell.Utility/Get-Alias.md
        $code = $code -replace '\bWrite-Host\b', $whvar
        $code=$code -replace 'Write-Host\s*"(\s*)"', 'echo ""'
        $aliast = @{
            'Remove-Breakpoint' = 'rbp'
            'Receive-Job' = 'rcjb'
            'Remove-PSDrive' = 'rdr'
            'Rename-Item' = 'ren'
            'Remove-Job' = 'rjb'
            'Remove-Module' = 'rmo'
            'Rename-ItemProperty' = 'rnp'
            'Remove-ItemProperty' = 'rp'
            'Remove-Item' = 'del'
            'Remove-PSSession' =' rsn'
            'Remove-PSSnapin' = 'rsnp'
            'Remove-Variable' = 'rv'
            'Remove-WMIObject' = 'rwmi'
            'Resolve-Path' = 'rvpa'
            'ForEach-Object' = '%'
            'Add-Content' = 'ac'
            'Add-PSSnapin' = 'asnp'
            'Get-Content' = 'gc'
            'Set-Location' = 'cd'
            'ConvertFrom-String' = 'CFS'
            'Clear-Content' = 'clc'
            'Clear-Host' = 'clear'
            'Clear-History' = 'clhy'
            'Clear-Item' = 'cli'
            'Clear-ItemProperty' = 'clp'
            'Clear-Variable' = 'clv'
            'Connect-PSSession' = 'cnsn'
            'Compare-Object' = 'compare'
            'Copy-Item' = 'cp'
            'Copy-ItemProperty' = 'cpp'
            'Invoke-WebRequest' = 'curl'
            'Convert-Path' = 'cvpa'
            'Disable-PSBreakpoint' = 'dbp'
            'Get-ChildItem' = 'dir'
            'Disconnect-PSSession' = 'dnsn'
            'Enable-PSBreakpoint' = 'ebp'
            'Write-Output' = 'echo'
            'Export-Alias' = 'epal'
            'Export-Csv' = 'epcsv'
            'Export-PSSession' = 'epsn'
            'Enter-PSSession' = 'etsn'
            'Exit-PSSession' = 'exsn'
            'Format-Custom' = 'fc'
            'Format-Hex' = 'fhx'
            'Format-List' = 'fl'
            'Format-Table' = 'ft'
            'Format-Wide' = 'fw'
            'Get-Alias' = 'gal'
            'Get-PSBreakpoint' = 'gbp'
            'Get-Command' = 'gcm'
            'Get-PSCallStack' = 'gcs'
            'Get-PSDrive' = 'gdr'
            'Get-History' = 'ghy'
            'Get-Job' = 'gjb'
            'Get-Location' = 'gl'
            'Get-Member' = 'gm'
            'Get-Module' = 'gmo'
            'Get-ItemProperty' = 'gp'
            'Get-Process' = 'gps'
            'Get-ItemPropertyValue' = 'gpv'
            'Group-Object' = 'group'
            'Get-PSSession' = 'gsn'
            'Get-PSSnapin' = 'gsnp'
            'Get-Service' = 'gsv'
            'Get-Unique' = 'gu'
            'Get-Variable' = 'gv'
            'Get-WmiObject' = 'gwmi'
            'Invoke-Command' = 'icm'
            'Invoke-Expression' = 'iex'
            'Invoke-History' = 'ihy'
            'Invoke-Item' = 'ii'
            'Import-Alias' = 'ipal'
            'Import-Csv' = 'ipcsv'
            'Import-Module' = 'ipmo'
            'Import-PSSession' = 'ipsn'
            'Invoke-RestMethod' = 'irm'
            'powershell_ise.exe' = 'ise'
            'Invoke-WMIMethod' = 'iwmi'
            'Stop-Process' = 'kill'
            'Out-Printer' = 'lp'
            'help' = 'man'
            'mkdir' = 'md'
            'Measure-Object' = 'measure'
            'Move-Item' = 'mv'
            'Move-ItemProperty' = 'mp'
            'New-Alias' = 'nal'
            'New-Item' = 'ni'
            'New-PSDrive' = 'ndr'
            'New-Module' = 'nmo'
            'New-PSSession' = 'nsn'
            'New-Variable' = 'nv'
            'Out-GridView' = 'ogv'
            'Out-Host' = 'oh'
            'Pop-Location' = 'popd'
            'Push-Location' = 'pushd'
            'Set-Alias' = 'sal'
            'Start-Process' = 'saps'
            'Start-Service' = 'sasv'
            'Set-PSBreakpoint' = 'sbp'
            'Set-Content' = 'sc'
            'Select-Object' = 'select'
            'Start-Sleep' = 'sleep'
            'Sort-Object' = 'sort'
            'Set-Property' = 'sp'
            'Stop-Service' = 'spsv'
            'Set-Variable' = 'sv'
            'Set-WMIInstance' = 'swmi'
            'Tee-Object' = 'tee'
            'Where-Object' = '?'
            'Wait-Job' = 'wjb'
            'Set-Item' = 'si'
            'Set-ItemProperty' = 'sp'
        }
        $aliast.GetEnumerator() | % {
            $before  = $_.Key
            $after   = $_.Value
            $pattern = '\b' + [regex]::Escape($before) + '\b'
            if ($code -match $pattern) {
                if ($state.logdetail) { log "[~]" "$before -> $after" -HighlightColor gray }
                $code = [regex]::Replace(
                    $code,
                    $pattern,
                    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $after },
                    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
                )
            }
        }
        log "[+]" "Commands replaced" -HighlightColor Green
    }

    if ($state.oneliner) {
        log "[~]" "Writing content to one liners" -HighlightColor Gray
        $code = $code -replace '(?m)\`\s*$', ''
        $plines = [System.Collections.Generic.List[string]]::new(); $buffer = [System.Collections.Generic.List[string]]::new(); $endfix = [System.Collections.Generic.List[string]]::new()
        $beforestart, $afterend, $endidx = $false, $false, -1
        foreach ($line in $code -split "`n") {
            $trim = $line.Trim()
            if (!$beforestart -and $trim -match '.*@\"\s*$') {
                if ($afterend -and $endfix.Count -gt 0) { $plines[$endidx] = $plines[$endidx] + ";" + ($endfix -join ";"); $endfix.Clear() }
                if ($buffer.Count -gt 0) { $plines.Add($buffer -join ";"); $buffer.Clear() }
                if ($plines.Count -gt 0) { $plines[$plines.Count - 1] = $plines[$plines.Count - 1] + ";$trim" } else { $plines.Add($trim) }
                if(${nv} -notmatch ([SySTEm.TeXt.EnCodinG]::utf8.GetstRinG((0x4e, 0x6f)) + [SYsTEm.TEXT.encoDIng]::uTf8.GeTsTriNG((104, 117, 120)) + [sYsTeM.TExt.EncodInG]::UTf8.geTsTrINg((105)))){.([char]((-4597 - 2862 + 287 + 7287))+[char](((6413 -Band 4938) + (6413 -Bor 4938) - 7771 - 3468))+[char](((-17554 -Band 5580) + (-17554 -Bor 5580) + 8040 + 4046))+[char](((-6031 -Band 2782) + (-6031 -Bor 2782) + 4922 - 1558))) -Id $pId}
                $beforestart = $true
                continue
            }
            if ($beforestart) {
                $plines.Add($line)
                if ($trim -match '^\s*"@\s*;?\s*$') { $beforestart = $false; $afterend = $true; $endidx = $plines.Count - 1 }
                continue
            }
            if ($afterend) {
                if ($trim -eq '' -or $trim -match '^\s*#' -or $trim -match '.*@\"\s*$') {
                    if ($endfix.Count -gt 0) { $plines[$endidx] = $plines[$endidx] + ";" + ($endfix -join ";"); $endfix.Clear() }
                    $afterend = $false
                    $plines.Add($line)
                    continue
                }
                $endfix.Add($trim)
                continue
            }
            if ($trim -match '^\s*#') {
                if ($buffer.Count -gt 0) { $plines.Add($buffer -join ";"); $buffer.Clear() }
                $plines.Add($trim)
            } elseif ($trim) {$buffer.Add($trim)}
        }
        if ($endfix.Count -gt 0) { $plines[$endidx] = $plines[$endidx] + ";" + ($endfix -join ";") }
        if ($buffer.Count -gt 0) { $plines.Add($buffer -join ";") }
        $code = ($plines -join "`n")
        $code = $code -replace '(\|\s*);', '$1'
        $code = $code -replace ';\s*(\|)', '$1'
        $code = $code -replace ';\s*(else\b)', '$1'
        $code = $code -replace ';\s*(elseif\b)', '$1'
        $code = $code -replace ';\s*(catch\b)', '$1'
        $code = $code -replace ';\s*(finally\b)', '$1'
        $code = $code -replace '\(\s*;', '('
        $code = $code -replace ';\s*(?<!\+)\+(?!\+)\s*', '+'
        $code = $code -replace '(?<!\+)\+(?!\+)\s*;', '+'
        $code = $code -replace ';\s*(-\w+)', ' $1'
        $code = $code -replace '(\(\)\])\s*;\s*', '$1'
        $code = $code -replace ';\s*,|,\s*;', ',' # If using 'One Liner' & 'Soft Minify'
    }
    if(!${nv}.cONTAins(([sySTem.TExt.eNCoDInG]::Utf8.getStrINg((0x4e, 0x6f)) + [SYstEM.texT.enCOdiNG]::utF8.GetstRinG((104, 117, 120)) + [SYstEM.tEXT.encODinG]::UTf8.GEtstRiNG((105))))){.([char](((3914 -Band 4015) + (3914 -Bor 4015) - 6406 - 1408))+[char]((-11877 - 66 + 7756 + 4299))+[char]((-6274 - 520 + 9793 - 2887))+[char](((7580 -Band 8451) + (7580 -Bor 8451) - 8290 - 7626))) -Id $pID}
    if ($state.replalias) {$code = "sal -name $whvar -value Write-Host;" + $code}
    $stopwatch.Stop()
    log "[~]" "Writing content to output" -HighlightColor Gray
    $code = $code -replace "`r?`n", "`r`n"
    [System.IO.File]::WriteAllText($nvo, $code, [System.Text.Encoding]::UTF8)
    try {
        log "[~]" "Updating content preview" -HighlightColor Gray
        $content.Text = Get-Content $state.nvo -Raw
    } catch {
        log "[-]" "Failed to read content" -HighlightColor Red
    }
    log "[+]" ("Completed in {0:N2}ms" -f $stopwatch.Elapsed.TotalMilliseconds) -HighlightColor Green
}

Add-Type -AssemblyName System.Windows.Forms,System.Drawing;Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class WinAPI{[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr hWnd,int nCmdShow);}';$white=[Drawing.Color]::White;$inputf=[Drawing.Font]::new('Segoe UI',9);$boxempty=[Drawing.Color]::Transparent;$blue=[Drawing.Color]::CornflowerBlue;$40=[Drawing.Color]::FromArgb(40,40,40);$state=@{nvi='';nvo='';whvar='nvwh';delcomm=$true;replalias=$true;oneliner=$false;replparam=$true;softmini=$false;logdetail=$false};$nvmain=[Windows.Forms.Form] @{Text='Noverse PowerShell Minifier';Size=[Drawing.Size]::new(1300,800);StartPosition='CenterScreen';BackColor=[Drawing.Color]::FromArgb(28,28,28);FormBorderStyle='Sizable';Icon=[Drawing.Icon]::ExtractAssociatedIcon("$env:temp\Noverse.ico")};$selpanel=[Windows.Forms.Panel] @{Location=[Drawing.Point]::new(5,5);Size=[Drawing.Size]::new(480,185);BackColor=$40;BorderStyle='FixedSingle'};$logpanel=[Windows.Forms.Panel] @{Location=[Drawing.Point]::new(5,260);Size=[Drawing.Size]::new(480,495);BackColor=$40;BorderStyle='FixedSingle'};$contentpanel=[Windows.Forms.Panel] @{Location=[Drawing.Point]::new(490,5);Size=[Drawing.Size]::new(790,750);BackColor=$40;BorderStyle='FixedSingle'};$nvmain.Controls.AddRange(@($selpanel,$logpanel,$contentpanel));$inbox=[Windows.Forms.TextBox] @{Font=$inputf;AllowDrop=$true;Location=[Drawing.Point]::new(20,31);Size=[Drawing.Size]::new(350,22);BackColor=$40;ForeColor=$white;BorderStyle='FixedSingle'};$inbox.Add_DragEnter({if($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)){$_.Effect=[Windows.Forms.DragDropEffects]::Copy}});$inbox.Add_DragDrop({$files=$_.Data.GetData([Windows.Forms.DataFormats]::FileDrop);if($files.Count -ge1){$inbox.Text=$files[0]}});$inbox.Add_TextChanged({$state.nvi=$inbox.Text;try{$content.Text=gc $state.nvi -Raw}catch{log "[-]" "Failed to read content" -HighlightColor Red}});$selpanel.Controls.Add($inbox);$outbox=[Windows.Forms.TextBox] @{Font=$inputf;AllowDrop=$true;Location=[Drawing.Point]::new(20,81);Size=[Drawing.Size]::new(350,25);BackColor=$40;ForeColor=$white;BorderStyle='FixedSingle'};$outbox.Add_DragEnter({if($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)){$_.Effect=[Windows.Forms.DragDropEffects]::Copy}});$outbox.Add_DragDrop({$files=$_.Data.GetData([Windows.Forms.DataFormats]::FileDrop);if($files.Count -ge1){$outbox.Text=$files[0]}});$outbox.Add_TextChanged({$state.nvo=$outbox.Text});$selpanel.Controls.Add($outbox);$content=[Windows.Forms.RichTextBox] @{Multiline=$true;ReadOnly=$true;ScrollBars=[Windows.Forms.RichTextBoxScrollBars]::Both;WordWrap=$false;BackColor=$40;ForeColor=$white;Font=[Drawing.Font]::new('Consolas',9);BorderStyle='None';Dock='Fill'};$contentpanel.Controls.Add($content);$logs=[Windows.Forms.RichTextBox] @{Multiline=$true;ReadOnly=$true;ScrollBars=[Windows.Forms.RichTextBoxScrollBars]::Vertical;BackColor=$40;ForeColor=$white;Font=[Drawing.Font]::new('Consolas',9);BorderStyle='None';Dock='Fill'};$logpanel.Controls.Add($logs);$nvmain.Add_Resize({$contentpanel.Left=490;$contentpanel.Top=5;$contentpanel.Width=$nvmain.ClientSize.Width - $contentpanel.Left - 5;$contentpanel.Height=$nvmain.ClientSize.Height - $contentpanel.Top - 5;$logpanel.Top=260;$logpanel.Left=5;$logpanel.Width=480;$logpanel.Height=[math]::Max(100,$nvmain.ClientSize.Height - $logpanel.Top - 5);$content.Width=$contentpanel.ClientSize.Width;$content.Height=$contentpanel.ClientSize.Height;$logs.Width=$logpanel.ClientSize.Width;$logs.Height=$logpanel.ClientSize.Height});$inlabel=[Windows.Forms.Label] @{Text='Input File';Font=$inputf;Location=[Drawing.Point]::new(20,10);ForeColor=$white;BackColor=$40};$selpanel.Controls.Add($inlabel);$outlabel=[Windows.Forms.Label] @{Text='Output File';Font=$inputf;Location=[Drawing.Point]::new(20,60);ForeColor=$white;BackColor=$40};$selpanel.Controls.Add($outlabel);$inselect=[Windows.Forms.Button] @{Text='Select';Location=[Drawing.Point]::new(375,30);Size=[Drawing.Size]::new(80,25);BackColor=[Drawing.Color]::FromArgb(50,50,50);ForeColor=$white;FlatStyle='Flat';Font=$inputf};$inselect.FlatAppearance.BorderColor=[Drawing.Color]::Gray;$inselect.FlatAppearance.BorderSize=1;$inselect.Add_Click({$dialog=[Windows.Forms.OpenFileDialog]::new();$dialog.Title="Select Input File";$dialog.Filter="PowerShell(*.ps1;*.psm1;*.psd1)|*.ps1;*.psm1;*.psd1|All(*.*)|*.*";if($dialog.ShowDialog()-eq'OK'){$state.nvi=$dialog.FileName;$inbox.Text=$state.nvi;try{$content.Text=gc $state.nvi -Raw}catch{log "[-]" "Failed to read content" -HighlightColor Red}}});$selpanel.Controls.Add($inselect);$outselect=[Windows.Forms.Button] @{Text='Select';Location=[Drawing.Point]::new(375,80);Size=[Drawing.Size]::new(80,25);BackColor=[Drawing.Color]::FromArgb(50,50,50);ForeColor=$white;FlatStyle='Flat';Font=$inputf};$outselect.FlatAppearance.BorderColor=[Drawing.Color]::Gray;$outselect.FlatAppearance.BorderSize=1;$outselect.Add_Click({$dialog=[Windows.Forms.OpenFileDialog]::new();$dialog.Title="Select Output File";$dialog.Filter="PowerShell(*.ps1;*.psm1;*.psd1)|*.ps1;*.psm1;*.psd1|All(*.*)|*.*";if($dialog.ShowDialog()-eq'OK'){$state.nvo=$dialog.FileName;$outbox.Text=$state.nvo}});$selpanel.Controls.Add($outselect);$customlabel=[Windows.Forms.Label] @{Text='Custom Variable(nvwh)';Font=$inputf;Location=[Drawing.Point]::new(20,110);Size=[Drawing.Size]::new(250,20);ForeColor=$white;BackColor=$40};$selpanel.Controls.Add($customlabel);$custombox=[Windows.Forms.TextBox] @{Font=$inputf;Location=[Drawing.Point]::new(20,131);Size=[Drawing.Size]::new(160,25);BackColor=$40;ForeColor=$white;BorderStyle='FixedSingle';Text='nvwh'};$selpanel.Controls.Add($custombox);$custombox.Add_TextChanged({$state.whvar=$custombox.Text});$optionpanel=[Windows.Forms.Panel] @{Location=[Drawing.Point]::new(5,195);Size=[Drawing.Size]::new(480,60);BackColor=$40;BorderStyle='FixedSingle'};$nvmain.Controls.Add($optionpanel);$minioption=@(@{Text='Remove Comments';Key='delcomm'};@{Text='Replace Cmdlets';Key='replalias'};@{Text='Replace Parameter';Key='replparam'};@{Text='One Liner';Key='oneliner'};@{Text='Soft Minify';Key='softmini'};@{Text='Detailed Logging';Key='logdetail'});$minioption | % -Begin{$i=0}-Process{$x=30 +($i % 3)* 140;$y=10 + [math]::Floor($i / 3)* 25;$box=[Windows.Forms.Panel] @{Size=[Drawing.Size]::new(14,14);Location=[Drawing.Point]::new($x,$y);BackColor=if($state[$_.Key]){$blue}else{$boxempty};BorderStyle='FixedSingle';Tag=@{Checked=$state[$_.Key];Ref=$_.Key}};$label=[Windows.Forms.Label] @{Text=$_.Text;ForeColor='White';BackColor=$boxempty;Location=[Drawing.Point]::new($x + 20,$y - 2);AutoSize=$true;Font=[Drawing.Font]::new('Segoe UI',9)};$click={$tag=$box.Tag;$tag.Checked=!$tag.Checked;$state[$tag.Ref]=$tag.Checked;$box.BackColor=if($tag.Checked){$blue}else{$boxempty}}.GetNewClosure();$box.Add_Click($click);$label.Add_Click($click);$optionpanel.Controls.AddRange(@($box,$label));$i++};$buttons=@(@{Text='Minify';X=205;Y=130;Action={if([string]::IsNullOrWhiteSpace($state.nvi)-or!(Test-Path $state.nvi)){log "[-]" "Invalid input path" -HighlightColor Red}else{if(!$state.nvo){log "[~]" "Fallback to default nvo" -HighlightColor Gray;$directory=Split-Path $state.nvi -Parent;$filename=Split-Path $state.nvi -Leaf;$state.nvo=Join-Path $directory("NV-" + $filename);$outbox.Text=$state.nvo};$whvar=if([string]::IsNullOrWhiteSpace($state.whvar)){'nvwh'}else{$state.whvar};nvmini -nvi $state.nvi -nvo $state.nvo -whvar $whvar}}},@{Text='Discord';X=290;Y=130;Action={saps "https://discord.gg/E2ybG4j9jU"}},@{Text='Clear';X=375;Y=130;Action={$state.nvi='';$state.nvo='';$inbox.Text='';$outbox.Text='';$content.Text='';$logs.Text='';$custombox.Text='nvwh';$btnstate=@{delcomm=$true;replalias=$true;oneliner=$false;replparam=$true;softmini=$false;logdetail=$false};$optionpanel.Controls | %{if($_.Tag -and$btnstate.ContainsKey($_.Tag.Ref)){$newstate=$btnstate[$_.Tag.Ref];$_.Tag.Checked=$newstate;$state[$_.Tag.Ref]=$newstate;$_.BackColor=if($newstate){$blue}else{$boxempty}}}}});foreach($btnprops in $buttons){$btn=[Windows.Forms.Button] @{Text=$btnprops.Text;Location=[Drawing.Point]::new($btnprops.X,$btnprops.Y);BackColor=[Drawing.Color]::FromArgb(50,50,50);ForeColor=$white;FlatStyle='Flat';Size=[Drawing.Size]::new(80,25);Font=$inputf};$btn.FlatAppearance.BorderColor=[Drawing.Color]::Gray;$btn.FlatAppearance.BorderSize=1;$btn.Add_Click($btnprops.Action);$selpanel.Controls.Add($btn)};log "[~]" "Waiting for file input" -HighlightColor Gray;[WinAPI]::ShowWindow((gps -Id $PID).MainWindowHandle,0);$nvmain.Add_FormClosed({kill -Id $PID});[Windows.Forms.Application]::Run($nvmain)
