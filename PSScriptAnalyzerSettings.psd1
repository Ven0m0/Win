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
    # Exclude WriteHost as it's widely used for colored output in scripts
    'PSAvoidUsingWriteHost'
    # Exclude empty catch blocks used for stdin read fallback
    'PSAvoidUsingEmptyCatchBlock'
    # Exclude unused parameter warnings for CLI scripts with optional params
    'PSReviewUnusedParameter'
  )
  # Severity levels: Error, Warning, Information
  Severity = 'Warning'
}
