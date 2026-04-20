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
        'PSUseOutputTypeCorrectly'
        'PSUseSingularNouns'
        'PSUseSupportsShouldProcess'
        'PSUseVerbosityForRequestedLevel'
    )

    # Rules to exclude (not applicable for this repo)
    ExcludeRules = @(
        # Exclude rule requiring output type for internal scripts
        'PSProvideDefaultParameterValue'
    )

    # Severity levels: Error, Warning, Information
    SeverityLevel = 'Warning'

    # Custom settings
    MaximumCulture = ''
    OutputEncoding = [System.Text.Encoding]::UTF8
}
