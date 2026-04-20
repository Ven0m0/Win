@{
  # Core analysis rules
  IncludeRules = @(
    # Avoid problematic patterns
    'PSAvoidGlobalAliases'
    'PSAvoidUsingConvertToSecureStringWithPlainText'
    'PSAvoidUsingEmptyCatchBlock'
    'PSAvoidUsingInvokeExpression'
    'PSAvoidUsingPositionalParameters'
    'PSAvoidUsingUsernameAndPasswordParams'
    'PSAvoidUsingWriteHost'
    'PSUseBOMForUnicodeEncodedFile'
    'PSUseCorrectCasing'
    # Best practices
    'PSProvideCommentHelp'
    'PSReservedCmdletChar'
    'PSReservedParams'
    'PSUseApprovedVerbs'
    'PSUseCmdletCorrectly'
    'PSUseConsistentIndentation'
    'PSUseConsistentWhitespace'
    'PSUseSingularNouns'
    'PSUseSupportsShouldProcess'
    'PSUseVerbosityForRequestedLevel'
  )
  # Rules to exclude (not applicable for this repo)
  ExcludeRules = @(
    # Exclude rule that requires OutputType for internal scripts
    'PSUseOutputTypeCorrectly'
  )
  # Severity levels: Error, Warning, Information
  SeverityLevel = 'Warning'
  # Custom settings
  MaximumCulture = ''
  OutputEncoding = 'UTF-8'
}
