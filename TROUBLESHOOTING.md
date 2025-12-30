# Troubleshooting

This guide helps you diagnose issues with DataBar.

## Finding the Logs

DataBar writes diagnostic logs to help troubleshoot issues. To find them:

1. Open **Finder**
2. Press **Cmd + Shift + G** (Go to Folder)
3. Enter: `~/Library/Logs/DataBar`
4. Open `telemetry.log`

Alternatively, run this command in Terminal:

```bash
open ~/Library/Logs/DataBar
```

### What the Logs Contain

The log file records:

- Authentication errors (sign-in failures, token refresh issues)
- API errors when fetching analytics data
- Session restoration problems
- Timestamps and app version for each event

Logs are stored in JSON format, one entry per line.

## Common Issues

### "Error!" in Menu Bar

This indicates DataBar could not fetch your analytics data. Common causes:

- **Token expired**: Sign out and sign back in from Settings
- **Network issues**: Check your internet connection
- **API quota exceeded**: Wait a few minutes and try again

### Sign-In Not Working

If you cannot sign in with your Google account:

1. Check that you have a stable internet connection
2. Try signing out completely, then signing in again
3. Check the logs for specific error messages

### Data Not Updating

If the user count appears stuck:

1. Verify the correct property is selected in Settings
2. Check that your Google Analytics property has real-time data enabled
3. Try clicking "Open Google Analytics" to verify data in the web interface

## Reporting Issues

When reporting a bug, please include:

1. Your macOS version
2. DataBar version (found in About)
3. Relevant log entries from `~/Library/Logs/DataBar/telemetry.log`

Report issues at: https://github.com/sammarks/DataBar/issues
