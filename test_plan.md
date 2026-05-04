The CI runs failed with:
1. PSScriptAnalyzer failed due to syntax errors. Wait, the output was:
Missing closing '}' in statement block or type definition.
At D:\a\Win\Win\Scripts\Common.ps1:703 char:35
+ function Show-GamingDisplayStatus {

This indicates there is a syntax error in `Scripts/Common.ps1`.

Let's check what I broke.
