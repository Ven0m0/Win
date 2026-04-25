import re

with open('Scripts/Common.ps1', 'rb') as f:
    content = f.read().decode('utf-8-sig')

# Double comment
if content.startswith('# Common.ps1'):
    content = '#' + content

# Arrays
old_array = r"""    $results = @()

    foreach ($path in $GpuPaths) {
        $gpuName = ($path -split '\\')[-1]
        $entry = [ordered]@{
            GpuName = $gpuName
            Path    = $path
            P0State = $null
            HDCP    = $null
        }

        if ($Setting -eq "All" -or $Setting -eq "P0State") {
            try {
                $entry.P0State = (Get-ItemProperty -Path "Registry::$path" -Name 'DisableDynamicPstate' -ErrorAction Stop).DisableDynamicPstate
            } catch {
                $entry.P0State = $null
            }
        }

        if ($Setting -eq "All" -or $Setting -eq "HDCP") {
            try {
                $entry.HDCP = (Get-ItemProperty -Path "Registry::$path" -Name 'RMHdcpKeyglobZero' -ErrorAction Stop).RMHdcpKeyglobZero
            } catch {
                $entry.HDCP = $null
            }
        }

        $results += [pscustomobject]$entry
    }

    return $results"""

new_array = r"""    [array]$results = foreach ($path in $GpuPaths) {
        $gpuName = ($path -split '\\')[-1]
        $entry = [ordered]@{
            GpuName = $gpuName
            Path    = $path
            P0State = $null
            HDCP    = $null
        }

        if ($Setting -eq "All" -or $Setting -eq "P0State") {
            try {
                $entry.P0State = (Get-ItemProperty -Path "Registry::$path" -Name 'DisableDynamicPstate' -ErrorAction Stop).DisableDynamicPstate
            } catch {
                $entry.P0State = $null
            }
        }

        if ($Setting -eq "All" -or $Setting -eq "HDCP") {
            try {
                $entry.HDCP = (Get-ItemProperty -Path "Registry::$path" -Name 'RMHdcpKeyglobZero' -ErrorAction Stop).RMHdcpKeyglobZero
            } catch {
                $entry.HDCP = $null
            }
        }

        [pscustomobject]$entry
    }

    return $results"""

# Using regex replace considering CRLF
new_content_str = re.sub(old_array.replace('\n', '\r?\n'), new_array, content)

# Fix CI script fallback! Let's modify `.github/workflows/ps-format.yml`
with open('.github/workflows/ps-format.yml', 'rb') as yml_f:
    yml_content = yml_f.read().decode('utf-8')

old_yml = """if ($files.Count -eq 0) {
  # Fallback to all ps1 files if no changes detected
  $files = @(Get-ChildItem -Path . -Recurse -Include *.ps1,*.psm1,*.psd1 -File | Select-Object -ExpandProperty FullName)
}"""

new_yml = """if ($files.Count -eq 0) {
  # Fallback to all ps1 files if no changes detected
  $files = @()
}"""

yml_content = yml_content.replace(old_yml, new_yml)

with open('.github/workflows/ps-format.yml', 'wb') as yml_f:
    yml_f.write(yml_content.encode('utf-8'))


with open('Scripts/Common.ps1', 'wb') as f:
    f.write(b'\xef\xbb\xbf' + new_content_str.replace('\r\n', '\n').replace('\n', '\r\n').encode('utf-8'))
