#!/bin/bash

# macOS File Cleanup Script
# Author: [Your Name]
# Description: Automatically removes files older than specified days from target directories
# License: MIT
# Version: 1.0.0

set -euo pipefail  # エラー時に即座に停止、未定義変数使用時にエラー

# 設定
DAYS_OLD=60  # デフォルト値
DRY_RUN=false
VERBOSE=false
FORCE=false  # cron実行用
REMOVE_EMPTY_DIRS=false  # 空ディレクトリ削除

# 削除対象フォルダを配列で定義
TARGET_FOLDERS=(
    "$HOME/Downloads"
    "$HOME/.Trash"
    # 必要に応じて他のフォルダも追加
    # "$HOME/Desktop/temp"
    # "/tmp"
)

# 除外するファイル・フォルダのパターン（正規表現）
EXCLUDE_PATTERNS=(
    "\.DS_Store$"
    "Icon\r$"
    "Thumbs\.db$"
    # 必要に応じて他のパターンも追加
)

# 色付き出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ用関数
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

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: $0 [OPTIONS]

このスクリプトは指定されたフォルダ配下の指定日数経過したファイルを削除します。

OPTIONS:
    --days N        削除対象とする日数を指定 (デフォルト: ${DAYS_OLD}日)
    --dry-run       実際には削除せず、削除対象のファイルを表示のみ
    --verbose       詳細な実行ログを表示
    --force         確認プロンプトを表示せず強制実行 (cron用)
    --remove-empty-dirs  空のディレクトリも削除する
    --help          このヘルプを表示

対象フォルダ:
EOF
    for folder in "${TARGET_FOLDERS[@]}"; do
        echo "    - $folder"
    done
    echo
    echo "使用例:"
    echo "    $0 --days 30 --dry-run              # 30日経過したファイルをテスト表示"
    echo "    $0 --days 90 --verbose              # 90日経過したファイルを削除"
    echo "    $0 --days 60 --force                # cron用: 確認なしで削除実行"
    echo "    $0 --days 30 --remove-empty-dirs    # 空ディレクトリも削除"
}

# 引数の解析
while [[ $# -gt 0 ]]; do
    case $1 in
        --days)
            if [[ -n $2 ]] && [[ $2 =~ ^[0-9]+$ ]]; then
                DAYS_OLD=$2
                shift 2
            else
                log_error "--days オプションには正の整数を指定してください"
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
            log_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# 除外パターンをチェックする関数
is_excluded() {
    local file="$1"
    local basename_file=$(basename "$file")
    
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$basename_file" =~ $pattern ]]; then
            return 0  # 除外対象
        fi
    done
    return 1  # 除外対象ではない
}

# メイン処理
main() {
    if [[ $DRY_RUN == true ]]; then
        log_warning "DRY-RUNモード: 実際にはファイルを削除しません"
    elif [[ $FORCE == true ]]; then
        log_info "強制実行モード: ${DAYS_OLD}日以上経過したファイルを削除します"
    fi
    
    log_info "${DAYS_OLD}日以上経過したファイルの検索を開始します..."
    
    local total_deleted=0
    local total_size_deleted=0
    
    for folder in "${TARGET_FOLDERS[@]}"; do
        # フォルダの存在確認
        if [[ ! -d "$folder" ]]; then
            log_warning "フォルダが存在しません: $folder"
            continue
        fi
        
        log_info "処理中: $folder"
        
        local folder_deleted=0
        local folder_size_deleted=0
        
        # findコマンドでファイルを検索（macOS用の設定）
        # -mtime +60: 60日より古いファイル
        # -type f: ファイルのみ（ディレクトリは除外）
        while IFS= read -r -d '' file; do
            # 除外パターンチェック
            if is_excluded "$file"; then
                [[ $VERBOSE == true ]] && log_info "除外: $file"
                continue
            fi
            
            # ファイルサイズを取得
            local file_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
            
            if [[ $DRY_RUN == true ]]; then
                echo "削除対象: $file ($(numfmt --to=iec $file_size))"
            else
                if [[ $VERBOSE == true ]]; then
                    log_info "削除中: $file ($(numfmt --to=iec $file_size))"
                fi
                
                if rm "$file" 2>/dev/null; then
                    [[ $VERBOSE == true ]] && log_success "削除完了: $file"
                    ((folder_deleted++))
                    ((folder_size_deleted += file_size))
                else
                    log_error "削除に失敗: $file"
                fi
            fi
            
        done < <(find "$folder" -type f -mtime +$DAYS_OLD -print0 2>/dev/null)
        
        if [[ $DRY_RUN == false ]]; then
            if [[ $folder_deleted -gt 0 ]]; then
                log_success "$folder: ${folder_deleted}個のファイルを削除 ($(numfmt --to=iec $folder_size_deleted))"
            else
                log_info "$folder: 削除対象のファイルはありませんでした"
            fi
        fi
        
        ((total_deleted += folder_deleted))
        ((total_size_deleted += folder_size_deleted))
    done
    
    # 結果サマリー
    echo
    log_info "=== 実行結果 ==="
    if [[ $DRY_RUN == true ]]; then
        log_info "DRY-RUN: ${total_deleted}個のファイルが削除対象です"
    else
        if [[ $total_deleted -gt 0 ]]; then
            log_success "合計 ${total_deleted}個のファイルを削除しました ($(numfmt --to=iec $total_size_deleted))"
        else
            log_info "削除対象のファイルはありませんでした"
        fi
    fi
    
    # 空のディレクトリを削除（オプション指定時のみ）
    if [[ $DRY_RUN == false && $REMOVE_EMPTY_DIRS == true ]]; then
        log_info "空のディレクトリを削除中..."
        local empty_dirs_deleted=0
        for folder in "${TARGET_FOLDERS[@]}"; do
            if [[ -d "$folder" ]]; then
                # 削除前に空ディレクトリの数をカウント
                local empty_count=$(find "$folder" -type d -empty 2>/dev/null | wc -l)
                if [[ $empty_count -gt 0 ]]; then
                    find "$folder" -type d -empty -delete 2>/dev/null || true
                    # 削除後に残った空ディレクトリの数を確認
                    local remaining_count=$(find "$folder" -type d -empty 2>/dev/null | wc -l)
                    local deleted_count=$((empty_count - remaining_count))
                    if [[ $deleted_count -gt 0 ]]; then
                        [[ $VERBOSE == true ]] && log_success "$folder: ${deleted_count}個の空ディレクトリを削除"
                        ((empty_dirs_deleted += deleted_count))
                    fi
                fi
            fi
        done
        if [[ $empty_dirs_deleted -gt 0 ]]; then
            log_success "合計 ${empty_dirs_deleted}個の空ディレクトリを削除しました"
        else
            [[ $VERBOSE == true ]] && log_info "削除対象の空ディレクトリはありませんでした"
        fi
    elif [[ $DRY_RUN == true && $REMOVE_EMPTY_DIRS == true ]]; then
        log_info "空のディレクトリ検索中..."
        local total_empty_dirs=0
        for folder in "${TARGET_FOLDERS[@]}"; do
            if [[ -d "$folder" ]]; then
                while IFS= read -r -d '' empty_dir; do
                    echo "削除対象（空ディレクトリ）: $empty_dir"
                    ((total_empty_dirs++))
                done < <(find "$folder" -type d -empty -print0 2>/dev/null)
            fi
        done
        if [[ $total_empty_dirs -gt 0 ]]; then
            log_info "DRY-RUN: ${total_empty_dirs}個の空ディレクトリが削除対象です"
        else
            log_info "削除対象の空ディレクトリはありませんでした"
        fi
    fi
}

# スクリプトの実行確認（--forceまたは--dry-runの場合はスキップ）
if [[ $DRY_RUN == false && $FORCE == false ]]; then
    echo -e "${YELLOW}警告: このスクリプトは以下のフォルダから${DAYS_OLD}日以上経過したファイルを削除します:${NC}"
    for folder in "${TARGET_FOLDERS[@]}"; do
        echo "  - $folder"
    done
    echo
    read -p "続行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "処理を中止しました"
        exit 0
    fi
fi

# メイン処理実行
main

log_info "処理完了"