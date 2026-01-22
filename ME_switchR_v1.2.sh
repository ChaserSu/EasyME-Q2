#!/bin/bash

# R版本切换交互式脚本
# 用法: ./ME_switchR.sh 或 bash ME_switchR.sh

# 配置文件路径
R_CONFIG_FILE="/etc/rstudio/rserver.conf"
BACKUP_FILE="/etc/rstudio/rserver.conf.backup"

# R路径定义
SYSTEM_R="/usr/bin/R"

# 自动搜索当前环境的R路径和库路径
find_current_r() {
    # 方法1: 检查当前conda环境中的R
    if [ -n "$CONDA_PREFIX" ]; then
        local conda_r="$CONDA_PREFIX/bin/R"
        if [ -f "$conda_r" ] && [ -x "$conda_r" ]; then
            echo "$conda_r"
            return 0
        fi
    fi
    
    # 方法2: 检查当前PATH中的R
    local path_r=$(which R 2>/dev/null)
    if [ -n "$path_r" ] && [ -f "$path_r" ] && [ -x "$path_r" ]; then
        echo "$path_r"
        return 0
    fi
    
    # 方法3: 检查常见的conda环境路径
    local home_dir=$(eval echo ~$USER)
    local potential_paths=(
        "$home_dir/anaconda3/bin/R"
        "$home_dir/miniconda3/bin/R"
        "$home_dir/.conda/envs/*/bin/R"
        "/opt/anaconda3/bin/R"
        "/opt/miniconda3/bin/R"
    )
    
    for path in "${potential_paths[@]}"; do
        # 处理通配符路径
        for expanded_path in $path; do
            if [ -f "$expanded_path" ] && [ -x "$expanded_path" ]; then
                echo "$expanded_path"
                return 0
            fi
        done
    done
    
    # 如果没有找到，使用默认路径
    echo "$home_dir/anaconda3/bin/R"
    return 1
}

# 从R路径推导库路径
find_library_path() {
    local r_path="$1"
    if [ -z "$r_path" ]; then
        return 1
    fi
    
    # 方法1: 从R路径推导lib目录 (通常是../lib 或 ../lib64)
    local r_dir=$(dirname "$r_path")
    local base_dir=$(dirname "$r_dir")
    
    local potential_lib_paths=(
        "$base_dir/lib"
        "$base_dir/lib64"
        "$base_dir/lib/R/lib"
        "$(dirname "$base_dir")/lib"
    )
    
    for lib_path in "${potential_lib_paths[@]}"; do
        if [ -d "$lib_path" ]; then
            # 检查是否包含重要的库文件[citation:1]
            if [ -n "$(find "$lib_path" -name "*.so" -o -name "*.so.*" | head -n 5)" ] || 
               [ -d "$lib_path/R" ] || 
               [ -f "$lib_path/libR.so" ]; then
                echo "$lib_path"
                return 0
            fi
        fi
    done
    
    # 方法2: 使用R本身来查询库路径[citation:1]
    if [ -f "$r_path" ] && [ -x "$r_path" ]; then
        local r_lib_path=$("$r_path" -e "cat(Sys.getenv('LD_LIBRARY_PATH'))" 2>/dev/null | head -1)
        if [ -n "$r_lib_path" ] && [ -d "$r_lib_path" ]; then
            echo "$r_lib_path"
            return 0
        fi
    fi
    
    # 方法3: 检查conda环境的lib目录
    if [ -n "$CONDA_PREFIX" ]; then
        local conda_lib="$CONDA_PREFIX/lib"
        if [ -d "$conda_lib" ]; then
            echo "$conda_lib"
            return 0
        fi
    fi
    
    # 如果都没找到，返回基于R路径推导的最可能路径
    echo "$base_dir/lib"
    return 1
}

# 初始化R路径和库路径
CONDA_R=$(find_current_r)
CONDA_LIB_PATH=$(find_library_path "$CONDA_R")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印颜色消息
print_message() {
    echo -e "${2}${1}${NC}"
}

# 函数：显示横幅
show_banner() {
    clear
    echo "=========================================="
    echo "          R版本切换工具 v1.2"
    echo "=========================================="
    echo
    print_message "检测到的Conda R路径: $CONDA_R" "$BLUE"
    print_message "检测到的库路径: $CONDA_LIB_PATH" "$BLUE"
    echo
}

# 函数：显示菜单
show_menu() {
    print_message "请选择要执行的操作:" "$BLUE"
    echo
    print_message "1. 切换到 Conda R ($(basename "$CONDA_R"))" "$GREEN"
    print_message "2. 切换到系统 R ($(basename "$SYSTEM_R"))" "$GREEN"
    print_message "3. 显示当前 R 版本状态" "$YELLOW"
    print_message "4. 从备份恢复配置" "$YELLOW"
    print_message "5. 重新搜索R路径和库路径" "$YELLOW"
    print_message "6. 退出脚本" "$RED"
    echo
    print_message "请输入选择 [1-6]: " "$BLUE"
}

# 函数：检查文件是否存在
check_file() {
    if [ ! -f "$1" ]; then
        print_message "错误: 文件 $1 不存在" "$RED"
        return 1
    fi
    return 0
}

# 函数：检查R路径是否有效
check_r_path() {
    if [ ! -f "$1" ]; then
        print_message "警告: R路径 $1 不存在" "$YELLOW"
        return 1
    fi
    
    if [ ! -x "$1" ]; then
        print_message "警告: R路径 $1 不可执行" "$YELLOW"
        return 1
    fi
    
    return 0
}

# 函数：检查库路径是否有效
check_lib_path() {
    local lib_path="$1"
    
    if [ -z "$lib_path" ]; then
        print_message "警告: 库路径为空" "$YELLOW"
        return 1
    fi
    
    if [ ! -d "$lib_path" ]; then
        print_message "警告: 库路径 $lib_path 不存在" "$YELLOW"
        return 1
    fi
    
    # 检查路径是否包含必要的库文件[citation:1]
    if [ ! -f "$lib_path/libR.so" ] && [ ! -d "$lib_path/R" ]; then
        print_message "警告: 库路径 $lib_path 可能不包含R库文件" "$YELLOW"
        return 2
    fi
    
    return 0
}

# 函数：创建备份
create_backup() {
    if check_file "$R_CONFIG_FILE"; then
        sudo cp "$R_CONFIG_FILE" "$BACKUP_FILE"
        print_message "已创建备份: $BACKUP_FILE" "$GREEN"
    else
        print_message "配置文件不存在，创建新配置" "$YELLOW"
    fi
}

# 函数：重启RStudio Server
restart_rstudio() {
    print_message "重启RStudio Server..." "$YELLOW"
    if sudo rstudio-server restart; then
        print_message "RStudio Server 重启成功" "$GREEN"
    else
        print_message "RStudio Server 重启失败，请手动检查" "$RED"
    fi
}

# 函数：更新RStudio配置
update_rstudio_config() {
    local r_path="$1"
    local lib_path="$2"
    local config_file="$3"
    
    # 创建备份
    create_backup
    
    # 创建临时配置文件
    local temp_config=$(mktemp)
    
    # 如果原配置文件存在，复制内容
    if [ -f "$config_file" ]; then
        sudo cat "$config_file" > "$temp_config"
    fi
    
    # 更新或添加rsession-which-r配置[citation:1]
    if grep -q "rsession-which-r" "$temp_config"; then
        sed -i "s|rsession-which-r=.*|rsession-which-r=$r_path|" "$temp_config"
    else
        echo "rsession-which-r=$r_path" >> "$temp_config"
    fi
    
    # 更新或添加rsession-ld-library-path配置[citation:1]
    if grep -q "rsession-ld-library-path" "$temp_config"; then
        sed -i "s|rsession-ld-library-path=.*|rsession-ld-library-path=$lib_path|" "$temp_config"
    else
        echo "rsession-ld-library-path=$lib_path" >> "$temp_config"
    fi
    
    # 应用新配置
    sudo cp "$temp_config" "$config_file"
    sudo rm -f "$temp_config"
    
    print_message "已更新RStudio配置:" "$GREEN"
    print_message "  rsession-which-r: $r_path" "$GREEN"
    print_message "  rsession-ld-library-path: $lib_path" "$GREEN"
}

# 函数：显示当前状态
show_status() {
    print_message "=== 当前R版本状态 ===" "$YELLOW"
    
    # 检查当前使用的R
    if check_file "$R_CONFIG_FILE"; then
        if grep -q "rsession-which-r" "$R_CONFIG_FILE"; then
            CURRENT_R=$(grep "rsession-which-r" "$R_CONFIG_FILE" | cut -d= -f2 | tr -d ' ')
            print_message "RStudio Server 配置的R: $CURRENT_R" "$GREEN"
            
            # 检查配置的R是否存在
            if check_r_path "$CURRENT_R"; then
                R_VERSION=$("$CURRENT_R" --version 2>/dev/null | head -1 || echo "无法获取版本")
                print_message "R版本: $R_VERSION" "$GREEN"
            fi
        else
            print_message "RStudio Server 未配置rsession-which-r" "$YELLOW"
        fi
        
        # 检查当前使用的库路径
        if grep -q "rsession-ld-library-path" "$R_CONFIG_FILE"; then
            CURRENT_LIB=$(grep "rsession-ld-library-path" "$R_CONFIG_FILE" | cut -d= -f2 | tr -d ' ')
            print_message "RStudio Server 配置的库路径: $CURRENT_LIB" "$GREEN"
            check_lib_path "$CURRENT_LIB"
        else
            print_message "RStudio Server 未配置rsession-ld-library-path" "$YELLOW"
        fi
    else
        print_message "RStudio Server 配置文件不存在" "$YELLOW"
    fi
    
    # 显示系统R信息
    print_message "\n系统R路径: $SYSTEM_R" "$NC"
    if check_r_path "$SYSTEM_R"; then
        SYSTEM_VERSION=$("$SYSTEM_R" --version 2>/dev/null | head -1)
        print_message "系统R版本: $SYSTEM_VERSION" "$NC"
    fi
    
    # 显示Conda R信息
    print_message "\n当前检测到的Conda R路径: $CONDA_R" "$NC"
    if check_r_path "$CONDA_R"; then
        CONDA_VERSION=$("$CONDA_R" --version 2>/dev/null | head -1)
        print_message "Conda R版本: $CONDA_VERSION" "$NC"
    else
        print_message "警告: 当前检测到的Conda R路径无效" "$RED"
    fi
    
    # 显示检测到的库路径
    print_message "当前检测到的库路径: $CONDA_LIB_PATH" "$NC"
    check_lib_path "$CONDA_LIB_PATH"
    
    # 检查备份状态
    if [ -f "$BACKUP_FILE" ]; then
        print_message "\n备份文件存在: $BACKUP_FILE" "$GREEN"
    else
        print_message "\n暂无备份文件" "$YELLOW"
    fi
    
    echo
    read -p "按回车键继续..."
}

# 函数：切换到Conda R
switch_to_conda() {
    print_message "切换到Conda R..." "$YELLOW"
    
    if ! check_r_path "$CONDA_R"; then
        print_message "错误: Conda R路径无效，请检查环境是否正确" "$RED"
        read -p "按回车键继续..."
        return 1
    fi
    
    # 检查库路径
    if ! check_lib_path "$CONDA_LIB_PATH"; then
        print_message "警告: 库路径可能有问题，但继续配置..." "$YELLOW"
    fi
    
    # 更新RStudio配置[citation:1]
    update_rstudio_config "$CONDA_R" "$CONDA_LIB_PATH" "$R_CONFIG_FILE"
    
    print_message "已切换到Conda R: $CONDA_R" "$GREEN"
    restart_rstudio
    read -p "按回车键继续..."
}

# 函数：切换到系统R
switch_to_system() {
    print_message "切换到系统R..." "$YELLOW"
    
    if ! check_r_path "$SYSTEM_R"; then
        print_message "错误: 系统R路径无效" "$RED"
        read -p "按回车键继续..."
        return 1
    fi
    
    # 对于系统R，通常使用系统默认库路径，所以设置为空字符串
    local system_lib_path=""
    
    # 更新RStudio配置
    update_rstudio_config "$SYSTEM_R" "$system_lib_path" "$R_CONFIG_FILE"
    
    print_message "已切换到系统R: $SYSTEM_R" "$GREEN"
    print_message "注意: 系统R模式已清空rsession-ld-library-path，使用系统默认库路径" "$YELLOW"
    restart_rstudio
    read -p "按回车键继续..."
}

# 函数：恢复备份
restore_backup() {
    if [ -f "$BACKUP_FILE" ]; then
        print_message "从备份恢复配置..." "$YELLOW"
        sudo cp "$BACKUP_FILE" "$R_CONFIG_FILE"
        print_message "配置已从备份恢复" "$GREEN"
        restart_rstudio
    else
        print_message "错误: 备份文件不存在" "$RED"
    fi
    read -p "按回车键继续..."
}

# 函数：重新搜索R路径和库路径
rescan_r_path() {
    print_message "重新搜索R路径和库路径..." "$YELLOW"
    OLD_CONDA_R="$CONDA_R"
    OLD_CONDA_LIB="$CONDA_LIB_PATH"
    
    CONDA_R=$(find_current_r)
    CONDA_LIB_PATH=$(find_library_path "$CONDA_R")
    
    print_message "R路径搜索结果:" "$BLUE"
    print_message "  旧路径: $OLD_CONDA_R" "$NC"
    print_message "  新路径: $CONDA_R" "$NC"
    
    print_message "库路径搜索结果:" "$BLUE"
    print_message "  旧路径: $OLD_CONDA_LIB" "$NC"
    print_message "  新路径: $CONDA_LIB_PATH" "$NC"
    
    if check_r_path "$CONDA_R"; then
        CONDA_VERSION=$("$CONDA_R" --version 2>/dev/null | head -1)
        print_message "检测到的R版本: $CONDA_VERSION" "$GREEN"
    else
        print_message "警告: 检测到的R路径可能无效" "$RED"
    fi
    
    if check_lib_path "$CONDA_LIB_PATH"; then
        print_message "库路径有效性检查: 通过" "$GREEN"
    else
        print_message "警告: 检测到的库路径可能有问题" "$RED"
    fi
    
    read -p "按回车键继续..."
}

# 函数：检查sudo权限
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        print_message "此操作需要sudo权限，请输入密码:" "$YELLOW"
        if ! sudo -v; then
            print_message "错误: 无法获取sudo权限" "$RED"
            return 1
        fi
    fi
    return 0
}

# 主程序 - 交互式菜单
main() {
    while true; do
        show_banner
        show_menu
        
        read choice
        
        case $choice in
            1)
                if check_sudo; then
                    switch_to_conda
                else
                    print_message "权限不足，无法执行此操作" "$RED"
                    read -p "按回车键继续..."
                fi
                ;;
            2)
                if check_sudo; then
                    switch_to_system
                else
                    print_message "权限不足，无法执行此操作" "$RED"
                    read -p "按回车键继续..."
                fi
                ;;
            3)
                show_status
                ;;
            4)
                if check_sudo; then
                    restore_backup
                else
                    print_message "权限不足，无法执行此操作" "$RED"
                    read -p "按回车键继续..."
                fi
                ;;
            5)
                rescan_r_path
                ;;
            6)
                print_message "感谢使用R版本切换工具，再见！" "$GREEN"
                exit 0
                ;;
            *)
                print_message "无效选择，请输入1-6之间的数字" "$RED"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 检查是否以非交互方式调用（带参数）
if [ $# -gt 0 ]; then
    case "$1" in
        "system")
            if check_sudo; then
                switch_to_system
            else
                print_message "错误: 需要sudo权限" "$RED"
                exit 1
            fi
            ;;
        "conda")
            if check_sudo; then
                switch_to_conda
            else
                print_message "错误: 需要sudo权限" "$RED"
                exit 1
            fi
            ;;
        "status")
            show_status
            ;;
        "restore")
            if check_sudo; then
                restore_backup
            else
                print_message "错误: 需要sudo权限" "$RED"
                exit 1
            fi
            ;;
        "rescan")
            rescan_r_path
            exit 0
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 [command]"
            echo ""
            echo "命令:"
            echo "  system   切换到系统R (/usr/bin/R)"
            echo "  conda    切换到自动检测的Conda R"
            echo "  status   显示当前R版本状态"
            echo "  restore  从备份恢复配置"
            echo "  rescan   重新搜索R路径和库路径"
            echo "  help     显示此帮助信息"
            echo ""
            echo "不带参数运行将进入交互模式"
            ;;
        *)
            print_message "错误: 未知命令 '$1'" "$RED"
            echo ""
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
else
    # 没有参数，进入交互模式
    main
fi