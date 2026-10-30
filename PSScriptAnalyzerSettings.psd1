@{
  # Core analysis rules
  IncludeRules = @(
    # Avoid problematic patterns
    'PSAvoidGlobalAliases'
    'PSAvoidUsingConvertToSecureStringWithPlainText'
    'PSAvoidUsingInvokeExpression'
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
    'PSUseSupportsShouldProcess'
    'PSUseVerbosityForRequestedLevel'
    # Community packs (Indented.ScriptAnalyzerRules, OptimizationRules). Only active when the caller passes
    # -CustomRulePath; the module path differs per machine, so it cannot live in this file.
    'AvoidDashCharacters'
    'AvoidNewObjectToCreatePSObject'
    'AvoidSmartQuotes'
    'UseExpressionlessArgumentsInTheParameterAttribute'
    'Measure-OptimizeForStatement'
  )
  # Rules to exclude (not applicable for this repo)
  ExcludeRules = @(
    # Exclude rule that requires OutputType for internal scripts
    'PSUseOutputTypeCorrectly'
    # Exclude WriteHost as it's widely used for colored output in scripts
    'PSAvoidUsingWriteHost'
    # Exclude unused parameter warnings for CLI scripts with optional params
    'PSReviewUnusedParameter'
    'PSUseApprovedVerbs'
    'PSAvoidUsingPositionalParameters'
    'PSAvoidAssignmentToAutomaticVariable'
    'PSUseSingularNouns'
    'PSUseShouldProcessForStateChangingFunctions'
    'PSAvoidUsingEmptyCatchBlock'
  )
  # Severity levels: Error, Warning, Information
  Severity = 'Warning'
}
