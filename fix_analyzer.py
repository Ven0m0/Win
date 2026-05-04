with open('Scripts/Common.ps1', 'r', encoding='utf-8-sig') as f:
    content = f.read()

lines = content.split('\n')
# Currently it is:
# 1160: function Get-Log {
# 1161:     [CmdletBinding()]
# 1162:     param()
# 1163:     <#
# 1164:     .SYNOPSIS

# That's perfectly valid syntax... Wait, where does the <# start?
# In PSScriptAnalyzer, maybe the block comment can't be between param() and the rest?
# Usually block comments go BEFORE the function definition, or inside the function BEFORE param(), or inside param().

# Let's move <# ... #> to BEFORE [CmdletBinding()]

def move_synopsis_before_cmdletbinding(start_func_line, end_synopsis_line):
    # This is a bit complicated, let's just do it manually for Get-Log
    pass

# For Get-Log:
# 1160: function Get-Log {
# 1161:     [CmdletBinding()]
# 1162:     param()
# 1163:     <#
# 1164:     .SYNOPSIS
# 1165:         Returns the accumulated log entries
# 1166:     #>

lines[1160] = "    <#"
lines[1161] = "    .SYNOPSIS"
lines[1162] = "        Returns the accumulated log entries"
lines[1163] = "    #>"
lines[1164] = "function Get-Log {"
lines[1165] = "    [CmdletBinding()]"
lines[1166] = "    param()"

# Same for Show-GamingDisplayStatus
# 703: function Show-GamingDisplayStatus {
# 704:     [CmdletBinding()]
# 705:     param()
# 706:     <#
# 707:     .SYNOPSIS
# 708:         Displays current gaming display settings
# 709:     #>

lines[703] = "    <#"
lines[704] = "    .SYNOPSIS"
lines[705] = "        Displays current gaming display settings"
lines[706] = "    #>"
lines[707] = "function Show-GamingDisplayStatus {"
lines[708] = "    [CmdletBinding()]"
lines[709] = "    param()"

with open('Scripts/Common.ps1', 'w', encoding='utf-8-sig') as f:
    f.write('\n'.join(lines))
