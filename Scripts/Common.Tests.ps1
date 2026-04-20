BeforeAll {
  # Mocking Get-ItemProperty as it's the core of Get-RegistryValueSafe
  Mock -CommandName "Get-ItemProperty" -MockWith {
    param($Path, $Name, $ErrorAction)

    if ($Path -eq "HKLM:\SOFTWARE\Test" -and $Name -eq "ExistingValue") {
      return @{ "ExistingValue" = "TestData" }
    }

    # Simulate the behavior of Get-ItemProperty when a value is not found
    throw "Property $Name does not exist at path $Path"
  }

  # Source the script containing the function
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
