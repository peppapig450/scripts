# Cleanup Tmp Mounts

Automatically removes orphaned `/tmp/tmp-mount-*` directories created by Apple processes via daily launchd job.

## Files

- `cleanup-tmp-mounts` - Bash script that does the cleanup
- `com.cleanup.tmpmounts.plist` - launchd config for daily execution at 4:00 AM

## Setup

### Install Script

```bash
mkdir -p ~/.local/bin
cp cleanup-tmp-mounts ~/.local/bin/
chmod +x ~/.local/bin/cleanup-tmp-mounts
```

**Note:** The plist hardcodes `/Users/nick/.local/bin/cleanup-tmp-mounts`. Either use this path or edit the `ProgramArguments` in the plist file.

### Install & Load Service

```bash
sudo install -o root -g wheel -m 644 com.cleanup.tmpmounts.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/com.cleanup.tmpmounts.plist
```

### Verify

```bash
sudo launchctl list | grep com.cleanup.tmpmounts
```

Should show:
```
-	0	com.cleanup.tmpmounts
```

## Usage

Runs automatically daily at 4:00 AM. For manual execution:

```bash
sudo ~/.local/bin/cleanup-tmp-mounts
```

## Configuration

To change schedule, edit the plist `StartCalendarInterval` section and reload:

```bash
sudo launchctl unload /Library/LaunchDaemons/com.cleanup.tmpmounts.plist
sudo launchctl load /Library/LaunchDaemons/com.cleanup.tmpmounts.plist
```

## Logs

- Script logs: `/var/log/cleanup-tmp-mounts.log`
- launchd stdout: `/var/log/cleanup-tmpmounts.out`  
- launchd stderr: `/var/log/cleanup-tmpmounts.err`

```bash
sudo tail -f /var/log/cleanup-tmp-mounts.log
```

## Requirements

- Bash 4.0+ (install via `brew install bash` if needed)
- Root access for installation and execution

## Removal

```bash
sudo launchctl unload /Library/LaunchDaemons/com.cleanup.tmpmounts.plist
sudo rm /Library/LaunchDaemons/com.cleanup.tmpmounts.plist
rm ~/.local/bin/cleanup-tmp-mounts
```
