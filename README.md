# macOS File Cleanup Script

A shell script for automatically cleaning up old files from specified directories on macOS, such as Downloads and Trash folders.

## Features

- 🗂️ Clean files older than specified days (customizable)
- 🗑️ Optionally remove empty directories
- 🧪 Dry-run mode for safe testing
- 🔍 Verbose logging with colored output
- 🤖 Cron-friendly (non-interactive mode)
- 🛡️ Built-in safety features and exclusion patterns
- 🎯 macOS optimized (excludes .DS_Store, etc.)

## Requirements

- macOS
- Bash shell
- Terminal with **Full Disk Access** permission (required for ~/.Trash access)

### Granting Full Disk Access to Terminal

1. **macOS Ventura or later:**
   - Apple menu → **System Settings**
   - **Privacy & Security** → **Full Disk Access**

2. **macOS Monterey or earlier:**
   - Apple menu → **System Preferences**
   - **Security & Privacy** → **Privacy** tab → **Full Disk Access**

3. Click the **🔒** to unlock settings, then **+** to add Terminal.app
4. Restart Terminal application

## Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/ngc-shj/macos-file-cleanup/main/cleanup_old_files.sh

# Make executable
chmod +x cleanup_old_files.sh
```

## Usage

### Basic Usage

```bash
# Test run (recommended first step)
./cleanup_old_files.sh --days 60 --dry-run --verbose

# Delete files older than 60 days
./cleanup_old_files.sh --days 60 --verbose

# Force execution without confirmation (for cron)
./cleanup_old_files.sh --days 90 --force --verbose
```

### Options

| Option | Description |
|--------|-------------|
| `--days N` | Delete files older than N days (default: 60) |
| `--dry-run` | Show what would be deleted without actually deleting |
| `--verbose` | Show detailed execution logs |
| `--force` | Skip confirmation prompt (required for cron) |
| `--remove-empty-dirs` | Also remove empty directories |
| `--help` | Show help message |

### Cron Setup

```bash
# Edit crontab
crontab -e

# Run daily at 2 AM
0 2 * * * /path/to/cleanup_old_files.sh --days 90 --force --verbose >> /var/log/file_cleanup.log 2>&1

# Run weekly on Sunday at 3 AM (with empty directory cleanup)
0 3 * * 0 /path/to/cleanup_old_files.sh --days 60 --force --remove-empty-dirs >> /var/log/file_cleanup.log 2>&1
```

## Configuration

The script targets these directories by default:
- `~/Downloads`
- `~/.Trash`

To add more directories, edit the `TARGET_FOLDERS` array in the script:

```bash
TARGET_FOLDERS=(
    "$HOME/Downloads"
    "$HOME/.Trash"
    "$HOME/Desktop/temp"  # Add custom directories
    # "/tmp"
)
```

### Exclusion Patterns

The script automatically excludes macOS system files:
- `.DS_Store`
- `Icon\r` (custom folder icons)
- `Thumbs.db`

Add custom exclusion patterns in the `EXCLUDE_PATTERNS` array.

## Examples

```bash
# Clean Downloads folder (30 days, test mode)
./cleanup_old_files.sh --days 30 --dry-run

# Aggressive cleanup (7 days, include empty dirs)
./cleanup_old_files.sh --days 7 --remove-empty-dirs --verbose

# Conservative monthly cleanup
./cleanup_old_files.sh --days 120 --force
```

## Safety Features

- **Confirmation prompt** for interactive use
- **Dry-run mode** for testing
- **System file exclusion** (`.DS_Store`, etc.)
- **Error handling** with colored output
- **Size reporting** shows space freed
- **Detailed logging** for audit trail

## Logging

For cron jobs, redirect output to a log file:

```bash
# Create log directory
sudo mkdir -p /var/log
sudo touch /var/log/file_cleanup.log
sudo chown $(whoami) /var/log/file_cleanup.log

# Example cron with logging
0 2 * * * /path/to/cleanup_old_files.sh --days 90 --force --verbose >> /var/log/file_cleanup.log 2>&1
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Troubleshooting

### "Permission denied" accessing ~/.Trash
- Ensure Terminal has **Full Disk Access** permission
- Restart Terminal after granting permission

### Script doesn't run in cron
- Use absolute paths in crontab
- Include `--force` option for non-interactive execution
- Check cron logs: `grep CRON /var/log/system.log`

### Files not being deleted
- Check file permissions
- Use `--verbose` flag to see detailed logs
- Verify target directories exist
