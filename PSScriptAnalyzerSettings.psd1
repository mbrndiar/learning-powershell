# Repo-wide analyzer policy. Limiting Severity to Error and Warning keeps the
# signal focused on likely defects; Information-level style noise is excluded
# so a clean run means something. PSAvoidUsingWriteHost is enabled to enforce
# the course habit of emitting objects to the pipeline instead of writing
# straight to the host. Rare, deliberate exceptions (such as the intentional
# null-comparison counterexample) use per-file SuppressMessageAttribute at the
# call site with a justification, rather than disabling a rule globally here.
@{
    Severity = @('Error', 'Warning')
    Rules = @{
        PSAvoidUsingWriteHost = @{
            Enable = $true
        }
    }
}
