# Community Call Reminder Bot Script (PowerShell version)
# This script checks if it's a meeting week and posts reminders to open issues

param(
    [Parameter(Mandatory=$true)]
    [string]$Repo,
    
    [string]$AnchorDate = "2025-12-16",
    [string]$MeetingLink = "https://zoom-lfx.platform.linuxfoundation.org/meeting/92041330205?password=2f345bee-0c14-4dd5-9883-06fbc9c60581",
    [string]$CalendarLink = "https://zoom-lfx.platform.linuxfoundation.org/meetings/hiero?view=week",
    [bool]$DryRun = $false
)

Write-Host "=== Community Call Reminder Bot ==="
Write-Host "Repository: $Repo"
Write-Host "Anchor Date: $AnchorDate"
Write-Host "Dry Run: $DryRun"
Write-Host "=================================="

# Check if it's a meeting week
$anchorDateTime = [DateTime]::Parse($AnchorDate)
$today = Get-Date
$daysDiff = ($today - $anchorDateTime).Days

$isMeetingWeek = ($daysDiff -ge 0) -and (($daysDiff % 14) -eq 0)

if (-not $isMeetingWeek) {
    Write-Host "Not a fortnightly meeting week. Skipping execution."
    exit 0
}

Write-Host "Meeting week detected. Proceeding to check open issues."

# Get all open issues with author information
$issuesJson = & "C:\Program Files\GitHub CLI\gh.exe" issue list --repo $Repo --state open --json number,author
$issues = $issuesJson | ConvertFrom-Json

if ($issues.Count -eq 0) {
    Write-Host "No open issues found."
    exit 0
}

# Group by author and get latest issue per user
$latestIssues = $issues | Group-Object { $_.author.login } | ForEach-Object {
    $latestIssue = $_.Group | Sort-Object number -Descending | Select-Object -First 1
    @{
        Author = $_.Name
        IssueNumber = $latestIssue.number
    }
}

# Calculate meeting time (4 hours from now)
$meetingTime = (Get-Date).AddHours(4).ToString("HH:mm 'UTC' (hh:mm tt 'UTC')")

# Prepare comment body
$commentBody = @"
Hello, this is the Community Call Bot.

## Community Call Reminder

This is a reminder that the Hiero Python SDK Community Call is scheduled in approximately 4 hours at **$meetingTime**.

We host fortnightly community calls where we want to hear from the community about all things related to the Python SDK. This is a great opportunity to discuss this issue, ask questions, or provide feedback directly to the maintainers and community.

### Meeting Details:
- **Time:** $meetingTime
- **Join Link:** [Zoom Meeting]($MeetingLink)
- **Calendar:** [Hiero Calendar]($CalendarLink)

### What to expect:
- Discussion of open issues and feature requests
- Q&A with maintainers
- Community feedback and suggestions
- Updates on SDK development

**Disclaimer:** This is an automated reminder. Please subscribe to the meeting to be notified of any changes and check the Hiero calendar for the most up-to-date information.
"@

# Process only the latest issue per user
foreach ($issue in $latestIssues) {
    Write-Host "Processing Issue #$($issue.IssueNumber) (latest for user: $($issue.Author))"
    
    # Check for bot's unique signature to prevent duplicate comments
    $commentsJson = & "C:\Program Files\GitHub CLI\gh.exe" issue view $issue.IssueNumber --repo $Repo --json comments
    $comments = ($commentsJson | ConvertFrom-Json).comments
    $alreadyCommented = $comments | Where-Object { $_.body -like "*Hello, this is the Community Call Bot.*" }

    if (-not $alreadyCommented) {
        if ($DryRun) {
            Write-Host "DRY RUN: Would post reminder to Issue #$($issue.IssueNumber)"
            Write-Host "Comment body:"
            Write-Host $commentBody
            Write-Host "---"
        } else {
            & "C:\Program Files\GitHub CLI\gh.exe" issue comment $issue.IssueNumber --repo $Repo --body $commentBody
            Write-Host "Reminder posted to Issue #$($issue.IssueNumber)"
        }
    } else {
        Write-Host "Issue #$($issue.IssueNumber) already notified. Skipping."
    }
}

Write-Host "Community call reminder process completed."