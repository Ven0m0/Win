BeforeAll {
  Import-Module Pester -MinimumVersion 5.0

  # Mocking Get-ItemProperty as it's the core of Get-RegistryValueSafe
  Mock -CommandName "Get-ItemProperty" -MockWith {
    param($Path, $Name, $ErrorAction)

    if ($Path -eq "HKLM:\SOFTWARE\Test" -and $Name -eq "ExistingValue") {
      return @{ "ExistingValue" = "TestData" }
    }

    # Simulate the behavior of Get-ItemProperty when a value is not found
    throw "Property $Name does not exist at path $Path"
  }

  # Source the script containing the functions
  . "$PSScriptRoot\Common.ps1"
}

Describe "Get-RegistryValueSafe" {
  Context "Success scenario" {
    It "Should return the expected value when it exists" {
      # Arrange
      $path = "HKLM:\SOFTWARE\Test"
      $name = "ExistingValue"

      # Act
      $result = Get-RegistryValueSafe -Path $path -Name $name

      # Assert
      $result | Should -Be "TestData"
    }
  }

  Context "Fallback scenarios" {
    It "Should return `$null` by default when the value does not exist" {
      # Arrange
      $path = "HKLM:\SOFTWARE\Test"
      $name = "NonExistentValue"

      # Act
      $result = Get-RegistryValueSafe -Path $path -Name $name

      # Assert
      $result | Should -BeNull
    }

    It "Should return the provided default value when the value does not exist" {
      # Arrange
      $path = "HKLM:\SOFTWARE\Test"
      $name = "NonExistentValue"
      $defaultValue = "DefaultData"

      # Act
      $result = Get-RegistryValueSafe -Path $path -Name $name -DefaultValue $defaultValue

      # Assert
      $result | Should -Be "DefaultData"
    }

    It "Should return `$null` by default when the path does not exist" {
      # Arrange
      $path = "HKLM:\SOFTWARE\NonExistentPath"
      $name = "SomeValue"

      # Act
      $result = Get-RegistryValueSafe -Path $path -Name $name

      # Assert
      $result | Should -BeNull
    }
  }
}

Describe "VDF Serialization/Deserialization" {
    Context "ConvertTo-VDF" {
        It "Should correctly serialize a simple hashtable" {
            $data = [ordered]@{ "key" = "value" }
            $result = ConvertTo-VDF -Data $data
            $resultString = $result -join ""
            $resultString | Should -Be "`"key`"`t`t`"value`"`n"
        }

        It "Should correctly serialize nested hashtables" {
            $data = [ordered]@{
                "parent" = [ordered]@{
                    "child" = "value"
                }
            }
            $result = ConvertTo-VDF -Data $data
            $resultString = $result -join ""
            # Expected output with tabs and newlines
            $expected = "`"parent`"`n{`n`t`"child`"`t`t`"value`"`n}`n"
            $resultString | Should -Be $expected
        }

        It "Should handle multiple keys and maintain order" {
            $data = [ordered]@{
                "key1" = "value1"
                "key2" = "value2"
            }
            $result = ConvertTo-VDF -Data $data
            $resultString = $result -join ""
            $expected = "`"key1`"`t`t`"value1`"`n`"key2`"`t`t`"value2`"`n"
            $resultString | Should -Be $expected
        }

        It "Should return nothing for invalid input" {
            $result = ConvertTo-VDF -Data "not a hashtable"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "ConvertFrom-VDF" {
        It "Should parse a simple VDF string" {
            $content = @(
                '"key" "value"'
            )
            $result = ConvertFrom-VDF -Content $content
            $result["key"] | Should -Be '"value"'
        }

        It "Should parse nested VDF structures" {
            $content = @(
                '"parent"',
                '{',
                '  "child" "value"',
                '}'
            )
            $result = ConvertFrom-VDF -Content $content
            $result["parent"]["child"] | Should -Be '"value"'
        }
    }

    Context "Round-trip Verification" {
        It "Should serialize and then deserialize back to the same structure" {
            $original = [ordered]@{
                "root" = [ordered]@{
                    "setting1" = "1"
                    "setting2" = "0"
                }
            }

            # Act
            $serialized = ConvertTo-VDF -Data $original
            # Convert string output to array for ConvertFrom-VDF
            $lines = $serialized -split "`n" | Where-Object { $_ -ne "" }
            $deserialized = ConvertFrom-VDF -Content $lines

            # Assert
            $deserialized.root.setting1 | Should -Be '"1"'
            $deserialized.root.setting2 | Should -Be '"0"'
        }
    }
}