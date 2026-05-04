with open('tests/Common.Tests.ps1', 'r', encoding='utf-8-sig') as f:
    content = f.read()

content = content.replace(
    '        Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter { $Object -eq "Restart required to apply changes..." `\n            -and $ForegroundColor -eq "Yellow" }',
    '        Should -Invoke -CommandName Write-Host -Times 1 -ParameterFilter {\n            $Object -eq "Restart required to apply changes..." -and $ForegroundColor -eq "Yellow"\n        }'
)

content = content.replace(
    '        Should -Invoke -CommandName Write-Warn -Times 1 -ParameterFilter { $Message -eq "Service \'NonExistentService\' not found" `\n        }',
    '        Should -Invoke -CommandName Write-Warn -Times 1 -ParameterFilter {\n            $Message -eq "Service \'NonExistentService\' not found"\n        }'
)

with open('tests/Common.Tests.ps1', 'w', encoding='utf-8-sig') as f:
    f.write(content)
