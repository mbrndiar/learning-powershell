@{
    IncludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseApprovedVerbs',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingCmdletAliases',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseSingularNouns'
    )
    Rules = @{
        PSAvoidUsingWriteHost = @{
            Enable = $true
        }
    }
}
