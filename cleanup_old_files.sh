#!/bin/bash

# macOS File Cleanup Script
# Author: NOGUCHI Shoji
# Description: Automatically removes files older than specified days from target directories
# License: MIT
# Version: 1.0.0

set -euo pipefail  # Exit immediately on error, error on undefined variables

# Configuration
DAYS_OLD=60  # Default value
DRY_RUN=false
VERBOSE=false
FORCE=false  # For cron execution
REMOVE_EMPTY_DIRS=false  # Remove empty directories

# Define target folders as array
TARGET_FOLDERS=(
    "$HOME/Downloads"
    "$HOME/.Trash"
    # Add other folders as needed
    # "$HOME/Desktop/temp"
    # "/tmp"
)

# Exclude patterns for files/folders (regular expressions)
EXCLUDE_PATTERNS=(
    "\.DS_Store$"
    "Icon\r$"
    "Thumbs\.db$"
    # Add other patterns as needed
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help display
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

This script deletes files older than specified days from designated folders.

OPTIONS:
    --days N        Specify number of days for deletion target (default: ${DAYS_OLD} days)
    --dry-run       Show deletion targets without actually deleting
    --verbose       Display detailed execution logs
    --force         Force execution without confirmation prompt (for cron)
    --remove-empty-dirs  Also delete empty directories
    --help          Show this help

Target folders:
EOF
    for folder in "${TARGET_FOLDERS[@]}"; do
        echo "    - $folder"
    done
    echo
    echo "Examples:"
    echo "    $0 --days 30 --dry-run              # Test display files older than 30 days"
    echo "    $0 --days 90 --verbose              # Delete files older than 90 days"
    echo "    $0 --days 60 --force                # For cron: execute deletion without confirmation"
    echo "    $0 --days 30 --remove-empty-dirs    # Also delete empty directories"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --days)
            if [[ -n $2 ]] && [[ $2 =~ ^[0-9]+$ ]]; then
                DAYS_OLD=$2
                shift 2
            else
                log_error "Please specify a positive integer for --days option"
                exit 1
            fi
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --remove-empty-dirs)
            REMOVE_EMPTY_DIRS=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to check exclude patterns
is_excluded() {
    local file="$1"
    local basename_file=$(basename "$file")
    
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$basename_file" =~ $pattern ]]; then
            return 0  # Excluded
        fi
    done
    return 1  # Not excluded
}

# Main processing
main() {
    if [[ $DRY_RUN == true ]]; then
        log_warning "DRY-RUN mode: Files will not actually be deleted"
    elif [[ $FORCE == true ]]; then
        log_info "Force execution mode: Will delete files older than ${DAYS_OLD} days"
    fi
    
    log_info "Starting search for files older than ${DAYS_OLD} days..."
    
    local total_deleted=0
    local total_size_deleted=0
    
    for folder in "${TARGET_FOLDERS[@]}"; do
        # Check folder existence
        if [[ ! -d "$folder" ]]; then
            log_warning "Folder does not exist: $folder"
            continue
        fi
        
        log_info "Processing: $folder"
        
        local folder_deleted=0
        local folder_size_deleted=0
        
        # Search files with find command (macOS configuration)
        # -mtime +60: files older than 60 days
        # -type f: files only (exclude directories)
        while IFS= read -r -d '' file; do
            # Check exclude patterns
            if is_excluded "$file"; then
                [[ $VERBOSE == true ]] && log_info "Excluded: $file"
                continue
            fi
            
            # Get file size
            local file_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
            
            if [[ $DRY_RUN == true ]]; then
                echo "Deletion target: $file ($(numfmt --to=iec $file_size))"
            else
                if [[ $VERBOSE == true ]]; then
                    log_info "Deleting: $file ($(numfmt --to=iec $file_size))"
                fi
                
                if rm "$file" 2>/dev/null; then
                    [[ $VERBOSE == true ]] && log_success "Deletion completed: $file"
                    ((folder_deleted++))
                    ((folder_size_deleted += file_size))
                else
                    log_error "Failed to delete: $file"
                fi
            fi
            
        done < <(find "$folder" -type f -mtime +$DAYS_OLD -print0 2>/dev/null)
        
        if [[ $DRY_RUN == false ]]; then
            if [[ $folder_deleted -gt 0 ]]; then
                log_success "$folder: Deleted ${folder_deleted} files ($(numfmt --to=iec $folder_size_deleted))"
            else
                log_info "$folder: No files found for deletion"
            fi
        fi
        
        ((total_deleted += folder_deleted))
        ((total_size_deleted += folder_size_deleted))
    done
    
    # Result summary
    echo
    log_info "=== Execution Results ==="
    if [[ $DRY_RUN == true ]]; then
        log_info "DRY-RUN: ${total_deleted} files are targeted for deletion"
    else
        if [[ $total_deleted -gt 0 ]]; then
            log_success "Total ${total_deleted} files deleted ($(numfmt --to=iec $total_size_deleted))"
        else
            log_info "No files found for deletion"
        fi
    fi
    
    # Delete empty directories (only when option is specified)
    if [[ $DRY_RUN == false && $REMOVE_EMPTY_DIRS == true ]]; then
        log_info "Deleting empty directories..."
        local empty_dirs_deleted=0
        for folder in "${TARGET_FOLDERS[@]}"; do
            if [[ -d "$folder" ]]; then
                # Count empty directories before deletion
                local empty_count=$(find "$folder" -type d -empty 2>/dev/null | wc -l)
                if [[ $empty_count -gt 0 ]]; then
                    find "$folder" -type d -empty -delete 2>/dev/null || true
                    # Check remaining empty directories after deletion
                    local remaining_count=$(find "$folder" -type d -empty 2>/dev/null | wc -l)
                    local deleted_count=$((empty_count - remaining_count))
                    if [[ $deleted_count -gt 0 ]]; then
                        [[ $VERBOSE == true ]] && log_success "$folder: Deleted ${deleted_count} empty directories"
                        ((empty_dirs_deleted += deleted_count))
                    fi
                fi
            fi
        done
        if [[ $empty_dirs_deleted -gt 0 ]]; then
            log_success "Total ${empty_dirs_deleted} empty directories deleted"
        else
            [[ $VERBOSE == true ]] && log_info "No empty directories found for deletion"
        fi
    elif [[ $DRY_RUN == true && $REMOVE_EMPTY_DIRS == true ]]; then
        log_info "Searching for empty directories..."
        local total_empty_dirs=0
        for folder in "${TARGET_FOLDERS[@]}"; do
            if [[ -d "$folder" ]]; then
                while IFS= read -r -d '' empty_dir; do
                    echo "Deletion target (empty directory): $empty_dir"
                    ((total_empty_dirs++))
                done < <(find "$folder" -type d -empty -print0 2>/dev/null)
            fi
        done
        if [[ $total_empty_dirs -gt 0 ]]; then
            log_info "DRY-RUN: ${total_empty_dirs} empty directories are targeted for deletion"
        else
            log_info "No empty directories found for deletion"
        fi
    fi
}

# Script execution confirmation (skip for --force or --dry-run)
if [[ $DRY_RUN == false && $FORCE == false ]]; then
    echo -e "${YELLOW}Warning: This script will delete files older than ${DAYS_OLD} days from the following folders:${NC}"
    for folder in "${TARGET_FOLDERS[@]}"; do
        echo "  - $folder"
    done
    echo
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Process cancelled"
        exit 0
    fi
fi

# Execute main processing
main

log_info "Process completed"
