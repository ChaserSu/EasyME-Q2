#!/bin/bash
# =============================================
# 全局命令历史记录系统
# =============================================
GLOBAL_COMMAND_HISTORY=()
COMMAND_HISTORY_FILE="qiime2_command_history_$(date +%Y%m%d_%H%M%S).sh"

# 初始化命令历史文件
function init_command_history() {
    echo "#!/bin/bash" >"$COMMAND_HISTORY_FILE"
    echo "# QIIME2 命令历史 - 生成于 $(date)" >>"$COMMAND_HISTORY_FILE"
    echo "# 工作目录: $PWD" >>"$COMMAND_HISTORY_FILE"
    echo "# 注意: 此文件包含所有确认执行的命令" >>"$COMMAND_HISTORY_FILE"
    echo "" >>"$COMMAND_HISTORY_FILE"
    echo "set -e  # 遇到错误自动退出" >>"$COMMAND_HISTORY_FILE"
    echo "" >>"$COMMAND_HISTORY_FILE"
}

# 添加命令到历史记录
function add_to_history() {
    local cmd="$1"
    local comment="$2"

    # 添加注释说明
    if [ -n "$comment" ]; then
        echo -e "\n# $comment" >>"$COMMAND_HISTORY_FILE"
    fi

    # 添加到全局数组和文件
    GLOBAL_COMMAND_HISTORY+=("$cmd")
    echo "$cmd" >>"$COMMAND_HISTORY_FILE"
}

# 显示命令历史
function show_command_history() {
    if [ ${#GLOBAL_COMMAND_HISTORY[@]} -gt 0 ]; then
        echo -e "\n\n=============================================="
        echo -e "命令执行历史 (已保存到 $COMMAND_HISTORY_FILE)"
        echo -e "=============================================="

        # 打印带注释的完整历史
        cat "$COMMAND_HISTORY_FILE"

        echo -e "\n您可以直接运行此脚本重新执行所有命令:"
        echo -e "  bash $COMMAND_HISTORY_FILE"
    else
        echo -e "\n没有命令被确认执行。"
    fi
}

# =============================================
# 初始化设置
# =============================================
init_command_history

# # 在脚本开头创建命令历史文件
# echo "#!/bin/bash" > "$COMMAND_HISTORY_FILE"
# echo "# QIIME2 命令历史 - 生成于 $(date)" >> "$COMMAND_HISTORY_FILE"
# echo "# 工作目录: $PWD" >> "$COMMAND_HISTORY_FILE"
# echo "" >> "$COMMAND_HISTORY_FILE"

# 交互式设置
echo "===== QIIME2 分析流程配置 ====="
# 初始化设置
function init_settings() {
    echo "正在初始化设置..."
    local step_commands=()
    # 1. 设置工作目录
    read -p "请输入工作目录 [默认: $PWD]: " workdir
    WORKDIR="${workdir:-$PWD}"
    cd_cmd="cd \"$WORKDIR\" "
    echo -e "\n准备执行的工作目录设置命令:\n$cd_cmd"
    eval "$cd_cmd"
    echo "工作目录设置为: $WORKDIR"
    step_commands+=("$cd_cmd")
    add_to_history "$cd_cmd" "设置工作目录"
    # 2. 设置Conda源目录
    read -p "请输入Conda初始化脚本路径或自动扫描 [默认: /public_data/home/software/db/miniconda3/etc/profile.d/conda.sh]: " conda_source
    CONDA_SOURCE="${conda_source:-/public_data/home/software/db/miniconda3/etc/profile.d/conda.sh}"
    # 初始化Conda
    if [ -f "$CONDA_SOURCE" ]; then
        source_cmd="source \"$CONDA_SOURCE\""
        echo -e "\n准备执行的Conda初始化命令:\n$source_cmd"
        eval "$source_cmd"
        echo "正在启动程序，请稍后………"
        echo "已加载Conda: $CONDA_SOURCE"
        step_commands+=("$source_cmd")
        add_to_history "$source_cmd" "初始化Conda"
    else
        echo "警告: 未找到Conda初始化脚本 - $CONDA_SOURCE"
        read -p "是否尝试自动查找Conda?[默认: y][Y/n]: " find_conda
        find_conda=${find_conda:-y} # 默认值为y

        if [[ $find_conda =~ ^[Yy]$ ]]; then
            # 尝试常见路径
            possible_paths=(
                "$HOME/miniconda3/etc/profile.d/conda.sh"
                "$HOME/anaconda3/etc/profile.d/conda.sh"
                "/opt/miniconda3/etc/profile.d/conda.sh"
                "/opt/anaconda3/etc/profile.d/conda.sh"
                "/usr/local/anaconda3/etc/profile.d/conda.sh"
                "/public_data/home/software/db/miniconda3/etc/profile.d/conda.sh"
            )

            for path in "${possible_paths[@]}"; do
                if [ -f "$path" ]; then
                    source_cmd="source \"$path\""
                    echo -e "\n准备执行的Conda初始化命令:\n$source_cmd"
                    eval "$source_cmd"
                    echo "正在启动程序，请稍后………"
                    echo "已自动加载Conda: $path"
                    step_commands+=("$source_cmd")
                    add_to_history "$source_cmd" "自动初始化Conda"
                    break
                fi
            done

            if ! command -v conda &>/dev/null; then
                echo "错误: 无法找到Conda，请手动设置路径"
                exit 1
            fi
        else
            echo "请确保Conda已正确安装并配置"
            exit 1
        fi
    fi
    # 3. 设置QIIME2环境
    echo "可用环境列表:"
    conda env list
    read -p "请输入QIIME2环境名称或自动扫描 [默认: qiime2-amplicon-2025.4]: " qiime_env
    QIIME_ENV="${qiime_env:-qiime2-amplicon-2025.4}"
    # 激活QIIME2环境
    activate_cmd="conda activate \"$QIIME_ENV\""
    echo -e "\n准备执行的环境激活命令:\n$activate_cmd"
    if eval "$activate_cmd"; then
        echo "已激活环境: $QIIME_ENV"
        step_commands+=("$activate_cmd")
        add_to_history "$activate_cmd" "激活QIIME2环境"
    else
        echo "错误: 无法激活环境 - $QIIME_ENV"
        echo "可用环境列表:"
        conda env list
        exit 1
    fi
    # 创建日志目录
    mkdir_cmd="mkdir -p log"
    echo -e "\n准备执行的创建日志目录命令:\n$mkdir_cmd"
    eval "$mkdir_cmd"
    step_commands+=("$mkdir_cmd")
    add_to_history "$mkdir_cmd" "创建日志目录"
    # 初始化命令历史文件
    # 显示本步骤执行的命令
    if [ ${#step_commands[@]} -gt 0 ]; then
        echo -e "\n初始化设置完成，执行的命令已保存:"
        printf "%b\n" "${step_commands[@]}"
        echo -e "完整记录在: $COMMAND_HISTORY_FILE"
    fi
}

# 调用初始化函数
init_settings

# 交互式菜单函数
function show_menu() {
    clear
    echo "============================================="
    echo " QIIME2 16S/ITS 分析流程 - 交互式控制面板"
    echo " 版本: 2025.6.22.1537 by 王飞龙 适用于双端rawData数据"
    echo " 已写入AMV4.5NF-AMDGR引物序列"
    echo "============================================="
    echo " 开始分析前检查文件是否齐全："
    echo " 1、测序文件如rawData等"
    echo " 2、sample-metadata.tsv 包含试验的分组信息"
    echo " 3、feature-classifier文件 用于进行物种注释"
    echo "============================================="
    echo "当前工作目录: $WORKDIR"
    echo "当前Conda环境: $QIIME_ENV"
    echo "---------------------------------------------"
    echo "1. 生成 manifest 文件（双端模式）"
    echo "2. 导入数据并生成摘要"
    echo "3. 去除barcode&引物（双端模式）"
    echo "4. 运行 DADA2 去噪（双端模式）"
    echo "5. 导出 DADA2 结果（无物种注释）"
    echo "6. 执行物种注释（需分类器文件）"
    echo "7. 生成物种注释条形图"
    echo "8. 导出物种注释结果"
    echo "9. 执行完整流程（步骤1-8）"
    echo "0. 退出"
    echo "---------------------------------------------"
    read -p "请选择操作 [0-9]: " choice
}
# 检查文件是否存在
function check_file() {
    if [ ! -f "$1" ]; then
        echo "错误: 文件不存在 - $1"
        return 1
    fi
    return 0
}
# 步骤1: 生成 manifest 文件
function generate_manifest() {
    # 记录整个函数调用
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n# =============================================" >>"$COMMAND_HISTORY_FILE"
    echo "# 生成manifest文件 - $timestamp" >>"$COMMAND_HISTORY_FILE"
    echo "# 工作目录: $PWD" >>"$COMMAND_HISTORY_FILE"
    # 记录用户交互过程
    {
        echo "function generate_manifest() {"
        # 检查是否已存在 manifest 文件
        if [ -f "manifest" ]; then
            read -p "如果已存在manifest，则： [1-3] [默认: 1][1.覆盖;2.跳过;3.取消]: " existing_choice
            existing_choice=${existing_choice:-"1"}
            echo "    existing_choice=\"$existing_choice\""
            case $existing_choice in
            1)
                echo "    rm manifest"
                ;;
            2)
                echo "    head -n 5 manifest"
                echo "    echo \"...\""
                echo "    return"
                ;;
            3)
                echo "    return"
                ;;
            *)
                echo "    return"
                ;;
            esac
        fi
        # 记录forward文件生成
        read -p "是否使用forward前缀？[默认: n] (y/n): " use_prefixf
        use_prefixf=${use_prefixf:-n}
        echo "    use_prefixf=\"$use_prefixf\""
        if [[ "$use_prefixf" == "y" || "$use_prefixf" == "Y" ]]; then
            read -p "请输入样品名前缀 [默认: raw.]: " prefixf
            prefixf=${prefixf:-"raw."}
            echo "    prefixf=\"$prefixf\""
        else
            prefixf=""
            echo "    prefixf=\"\""
        fi
        read -p "是否使用后缀？[默认: 有] (y/n): " use_suffixf
        use_suffixf=${use_suffixf:-y}
        echo "    use_suffixf=\"$use_suffixf\""
        if [[ "$use_suffixf" == "y" || "$use_suffixf" == "Y" ]]; then
            read -p "请输入样品名后缀 [默认: .raw_1.fastq.gz]: " suffixf
            suffixf=${suffixf:-".raw_1.fastq.gz"}
            echo "    suffixf=\"$suffixf\""
        else
            suffixf=""
            echo "    suffixf=\"\""
        fi
        # 记录实际执行的命令
        echo "    touch forward"
        echo "    find . -type f -name \"${prefixf}*${suffixf}\" -print0 | while IFS= read -r -d '' file; do"
        echo "        clean_path=\"\${file#./}\""
        echo "        filename=\$(basename \"\$clean_path\")"
        echo "        sample_name=\${filename#\"$prefixf\"}"
        echo "        sample_name=\${sample_name%\"$suffixf\"}"
        echo "        echo -e \"\${sample_name}\t\$PWD/\$clean_path\""
        echo "    done >> forward"
        echo "    sort -t $'\t' -k1,1 -o forward forward"
        # 记录reverse文件生成
        read -p "是否使用reverse前缀？[默认: n] (y/n): " use_prefixr
        use_prefixr=${use_prefixr:-n}
        echo "    use_prefixr=\"$use_prefixr\""
        if [[ "$use_prefixr" == "y" || "$use_prefixr" == "Y" ]]; then
            read -p "请输入样品名前缀 [默认: raw.]: " prefixr
            prefixr=${prefixr:-"raw."}
            echo "    prefixr=\"$prefixr\""
        else
            prefixr=""
            echo "    prefixr=\"\""
        fi
        read -p "是否使用后缀？[默认: 有] (y/n): " use_suffixr
        use_suffixr=${use_suffixr:-y}
        echo "    use_suffixr=\"$use_suffixr\""
        if [[ "$use_suffixr" == "y" || "$use_suffixr" == "Y" ]]; then
            read -p "请输入样品名后缀 [默认: .raw_2.fastq.gz]: " suffixr
            suffixr=${suffixr:-".raw_2.fastq.gz"}
            echo "    suffixr=\"$suffixr\""
        else
            suffixr=""
            echo "    suffixr=\"\""
        fi
        echo "    touch reverse"
        echo "    find . -type f -name \"${prefixr}*${suffixr}\" -print0 | while IFS= read -r -d '' file; do"
        echo "        clean_path=\"\${file#./}\""
        echo "        filename=\$(basename \"\$clean_path\")"
        echo "        sample_name=\${filename#\"$prefixr\"}"
        echo "        sample_name=\${sample_name%\"$suffixr\"}"
        echo "        echo -e \"\${sample_name}\t\$PWD/\$clean_path\""
        echo "    done >> reverse"
        echo "    sort -t $'\t' -k1,1 -o reverse reverse"
        echo "    join -t $'\t' forward reverse > manifest.csv"
        echo "    echo -e \"sample-id\tforward-absolute-filepath\treverse-absolute-filepath\" | cat - manifest.csv > manifest.tmp && mv manifest.tmp manifest.csv"
        echo "    cat manifest.csv | tr \" \" \"\t\" > manifest"
        echo "    rm -f forward reverse manifest.csv"
        echo "    echo \"manifest : \$PWD/manifest\""
        echo "}"
        echo -e "\ngenerate_manifest" >>"$COMMAND_HISTORY_FILE"
    } >>"$COMMAND_HISTORY_FILE"
    # 执行原始函数逻辑
    {
        echo "步骤1: 生成 manifest 文件..."
        if [ -f "manifest" ]; then
            case $existing_choice in
            1)
                echo "删除现有 manifest 文件并重新生成..."
                rm manifest
                ;;
            2)
                echo "使用现有 manifest 文件。"
                echo "内容预览:"
                head -n 5 manifest
                echo "..."
                return
                ;;
            3)
                echo "退出 manifest 生成步骤。"
                return
                ;;
            *)
                echo "无效选择，退出 manifest 生成步骤。"
                return
                ;;
            esac
        fi
        # 生成forward文件
        touch forward
        find . -type f -name "${prefixf}*${suffixf}" -print0 | while IFS= read -r -d '' file; do
            clean_path="${file#./}"
            filename=$(basename "$clean_path")
            sample_name=${filename#"$prefixf"}
            sample_name=${sample_name%"$suffixf"}
            echo -e "${sample_name}\t$PWD/$clean_path"
        done >>forward
        sort -t $'\t' -k1,1 -o forward forward
        # 生成reverse文件
        touch reverse
        find . -type f -name "${prefixr}*${suffixr}" -print0 | while IFS= read -r -d '' file; do
            clean_path="${file#./}"
            filename=$(basename "$clean_path")
            sample_name=${filename#"$prefixr"}
            sample_name=${sample_name%"$suffixr"}
            echo -e "${sample_name}\t$PWD/$clean_path"
        done >>reverse
        sort -t $'\t' -k1,1 -o reverse reverse
        # 合并生成manifest
        join -t $'\t' forward reverse >manifest.csv
        echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" | cat - manifest.csv >manifest.tmp && mv manifest.tmp manifest.csv
        cat manifest.csv | tr " " "\t" >manifest
        rm -f forward reverse manifest.csv
        echo "manifest 文件已生成: $PWD/manifest"
        head -n 5 manifest
    }
}

# 步骤2: 导入数据并生成摘要
function import_and_summarize() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n# =============================================" >>"$COMMAND_HISTORY_FILE"
    echo "# 导入数据并生成摘要 - $timestamp" >>"$COMMAND_HISTORY_FILE"
    echo "# 工作目录: $PWD" >>"$COMMAND_HISTORY_FILE"
    echo "步骤2: 导入数据并生成摘要..."
    local step_commands=()
    if ! check_file "manifest"; then
        read -p "manifest 文件不存在，是否生成? [y/N]: " generate
        if [[ $generate =~ ^[Yy]$ ]]; then
            generate_manifest
        else
            return
        fi
    fi
    # 导入原始数据命令
    import_cmd=$(
        cat <<EOF
qiime tools import \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path manifest \
    --output-path paired-raw-demux.qza \
    --input-format PairedEndFastqManifestPhred33V2
EOF
    )
    echo -e "\n准备执行的导入命令:\n"
    printf "%b\n" "$import_cmd"
    echo ""
    echo "执行中..."
    time eval "$import_cmd" \
        &>log/import_and_summarize.log
    step_commands+=("$import_cmd")
    add_to_history "$import_cmd"
    # 生成原始数据摘要命令
    summarize_cmd=$(
        cat <<EOF
qiime demux summarize \
    --i-data paired-raw-demux.qza \
    --verbose \
    --o-visualization paired-raw-demux.qzv
EOF
    )
    echo -e "\n准备执行的摘要生成命令:\n"
    printf "%b\n" "$summarize_cmd"
    echo "执行中..."
    time eval "$summarize_cmd" \
        &>log/import_and_summarize.log
    step_commands+=("$summarize_cmd")
    add_to_history "$summarize_cmd"
    # 询问是否进行质控
    read -p "是否进行引物修剪(也可以不修剪直接在dada2中切除)? [Y/n]（默认: Y）: " do_qc
    do_qc=${do_qc:-Y}
    if [[ $do_qc =~ ^[Yy]$ ]]; then
        echo "数据已导入，请继续执行步骤3进行质控（引物修剪）。"
        echo "原始数据文件: paired-raw-demux.qza"
        echo "可视化文件: paired-raw-demux.qzv"
    else
        echo "跳过质控，直接使用原始数据..."
        cp_cmd1="cp paired-raw-demux.qza paired-demux.qza"
        cp_cmd2="cp paired-raw-demux.qzv paired-demux.qzv"
        eval "$cp_cmd1"
        eval "$cp_cmd2"
        echo "已创建副本: paired-demux.qza（未质控的原始数据）"
        step_commands+=("$cp_cmd1")
        step_commands+=("$cp_cmd2")
        add_to_history "$cp_cmd1"
        add_to_history "$cp_cmd2"
    fi
    # 显示本步骤执行的命令
    if [ ${#step_commands[@]} -gt 0 ]; then
        echo -e "\n本步骤执行的命令，您可以复制保存:"
        printf "%b\n" "${step_commands[@]}"
        echo -e "或在以下文件中查看记录 $COMMAND_HISTORY_FILE"
    fi
}

# 步骤3: 去除barcode和引物（双端模式）
function trim_primers() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n# =============================================" >>"$COMMAND_HISTORY_FILE"
    echo "# 去除barcode和引物（双端模式） - $timestamp" >>"$COMMAND_HISTORY_FILE"
    echo "# 工作目录: $PWD" >>"$COMMAND_HISTORY_FILE"
    echo "步骤3: 去除barcode和引物（双端模式）..."
    local step_commands=()
    if ! check_file "paired-raw-demux.qza"; then
        echo "错误: 输入文件 paired-raw-demux.qza 不存在"
        return
    fi
    echo "请选择裁剪方式："
    echo "1. 基于引物序列进行裁剪（默认）"
    echo "2. 基于碱基位置进行裁剪"
    read -p "请输入选项 [1/2，默认: 1]: " trim_mode
    trim_mode=${trim_mode:-1}
    read -p "请输入使用的线程数 [默认: 12]: " threads
    threads=${threads:-12}
    if [[ "$trim_mode" == "2" ]]; then
        # === 基于位置裁剪逻辑 ===
        echo ">> 基于位置进行裁剪..."
        read -p "请输入5'端裁剪碱基数 [默认: 30]: " fwd_cut
        fwd_cut=${fwd_cut:-30}
        read -p "请输入反向5'端裁剪碱基数 [默认: 30]: " rev_cut
        rev_cut=${rev_cut:-30}
        trim_cmd1=$(
            cat <<EOF
qiime cutadapt trim-paired \
  --i-demultiplexed-sequences paired-raw-demux.qza \
  --p-forward-cut $fwd_cut \
  --p-reverse-cut $rev_cut \
  --o-trimmed-sequences paired-demux2.qza \
  --p-cores $threads \
  --verbose
EOF
        )
        echo -e "\n准备执行5'端位置裁剪命令:\n"
        printf "%b\n" "$trim_cmd1"
        time eval "$trim_cmd1" \
            &>log/primer_trimming.log
        step_commands+=("$trim_cmd1")
        add_to_history "$trim_cmd1"
        read -p "是否继续从3'端裁剪？[默认: 是] (y/n): " trim_3p
        trim_3p=${trim_3p:-y}
        if [[ "$trim_3p" == "y" || "$trim_3p" == "Y" ]]; then
            read -p "请输入正向3'端裁剪碱基数（负数，默认: -20）: " fwd_cut3
            fwd_cut3=${fwd_cut3:--20}
            read -p "请输入反向3'端裁剪碱基数（负数，默认: -20）: " rev_cut3
            rev_cut3=${rev_cut3:--20}
            trim_cmd2=$(
                cat <<EOF
qiime cutadapt trim-paired \
  --i-demultiplexed-sequences paired-demux2.qza \
  --p-forward-cut $fwd_cut3 \
  --p-reverse-cut $rev_cut3 \
  --o-trimmed-sequences paired-demux.qza \
  --p-cores $threads \
  --verbose
rm paired-demux2.qza
EOF
            )
            echo -e "\n准备执行3'端位置裁剪命令:\n"
            printf "%b\n" "$trim_cmd2"
            time eval "$trim_cmd2" \
                &>>log/primer_trimming.log
            rm paired-demux2.qza
            step_commands+=("$trim_cmd2")
            add_to_history "$trim_cmd2"
        else
            cp -f paired-demux2.qza paired-demux.qza
            rm paired-demux2.qza
            cp_cmd1="cp -f paired-demux2.qza paired-demux.qza"
            cp_cmd2="rm paired-demux2.qza"
            step_commands+=("$cp_cmd1")
            step_commands+=("$cp_cmd2")
            add_to_history "$cp_cmd1"
            add_to_history "$cp_cmd2"
        fi
    else
        # === 基于引物序列裁剪逻辑 ===
        echo ">> 基于引物序列进行裁剪..."
        echo "可以直接查看原始序列的具体内容，或查阅文献获得具体信息"
        echo "例如：解压forward序列文件raw.L1.1.fq.gz，文本文件打开。"
        echo "将开头(5'端)重复率比较高的序列填到front-f中，将尾部(3'端)重复率比较高的填到adapter_f中"
        echo "raw.L1.2.fq.gz同理，填到front-r和adapter_r。"
        echo "===== 引物序列设置 [默认ITS2（诺禾）]====="
        read -p "请输入正向引物5'端序列front-f [默认F: GCATCGATGAAGAACGCAGC]: " forward_primer
        forward_primer=${forward_primer:-"GCATCGATGAAGAACGCAGC"}
        read -p "请输入反向引物5'端序列front-r [默认R: TCCTCCGCTTATTGATATGC]: " reverse_primer
        reverse_primer=${reverse_primer:-"TCCTCCGCTTATTGATATGC"}
        trim_cmd1=$(
            cat <<EOF
qiime cutadapt trim-paired \
    --i-demultiplexed-sequences paired-raw-demux.qza \
    --p-front-f "$forward_primer" \
    --p-front-r "$reverse_primer" \
    --o-trimmed-sequences paired-demux2.qza \
    --p-cores "$threads" \
    --verbose
EOF
        )
        echo -e "\n准备执行5'端引物修剪命令:\n"
        printf "%b\n" "$trim_cmd1"
        time eval "$trim_cmd1" \
            &>log/primer_trimming.log
        step_commands+=("$trim_cmd1")
        add_to_history "$trim_cmd1"
        read -p "是否继续从3'端修剪（adapter_f/adapter_r）？[默认: n] (y/n): " use_adapter
        use_adapter=${use_adapter:-n}
        if [[ "$use_adapter" == "y" || "$use_adapter" == "Y" ]]; then
            read -p "请输入正向引物3'端序列adapter_f [默认: ATGATTA]: " adapter_f
            adapter_f=${adapter_f:-"ATGATTA"}
            read -p "请输入反向引物3'端序列adapter_r [默认: ATCCCGA]: " adapter_r
            adapter_r=${adapter_r:-"ATCCCGA"}
            trim_cmd2=$(
                cat <<EOF
qiime cutadapt trim-paired \
    --i-demultiplexed-sequences paired-demux2.qza \
    --p-adapter-f "$adapter_f" \
    --p-adapter-r "$adapter_r" \
    --p-cores "$threads" \
    --verbose \
    --o-trimmed-sequences paired-demux.qza
EOF
            )
            trim_cmd3=$(
                cat <<EOF
rm paired-demux2.qza
EOF
            )
            echo -e "\n准备执行3'端引物修剪命令:\n"
            printf "%b\n" "$trim_cmd2"
            time eval "$trim_cmd2" \
                &>>log/primer_trimming.log
            step_commands+=("$trim_cmd2")
            add_to_history "$trim_cmd2"
            printf "%b\n" "$trim_cmd3"
            eval "$trim_cmd3"
            step_commands+=("$trim_cmd3")
            add_to_history "$trim_cmd3"
        else
            echo "跳过3'端修剪。"
            cp_cmd1="cp -f paired-demux2.qza paired-demux.qza"
            cp_cmd2="rm paired-demux2.qza"
            printf "%b\n" "$cp_cmd1"
            printf "%b\n" "$cp_cmd2"
            step_commands+=("$cp_cmd1")
            step_commands+=("$cp_cmd2")
            eval "$cp_cmd1"
            eval "$cp_cmd2"
            add_to_history "$cp_cmd1"
            add_to_history "$cp_cmd2"
        fi
    fi
    # 导出与可视化
    export_cmd=$(
        cat <<EOF
qiime tools export \
    --input-path paired-demux.qza \
    --output-path demux_exported
EOF
    )
    summarize_cmd=$(
        cat <<EOF
qiime demux summarize \
    --i-data paired-demux.qza \
    --verbose \
    --o-visualization paired-demux.qzv
EOF
    )
    echo -e "\n准备执行的导出命令:\n"
    printf "%b\n" "$export_cmd"
    time eval "$export_cmd" \
        &>>log/primer_trimming.log
    step_commands+=("$export_cmd")
    add_to_history "$export_cmd"
    echo -e "\n准备执行的摘要命令:\n"
    printf "%b\n" "$summarize_cmd"
    time eval "$summarize_cmd" \
        &>>log/primer_trimming.log
    step_commands+=("$summarize_cmd")
    add_to_history "$summarize_cmd"
    echo "裁剪完成。结果文件: paired-demux.qza"
    echo "可视化文件: paired-demux.qzv"
    echo "日志文件: log/primer_trimming.log"
    if [ ${#step_commands[@]} -gt 0 ]; then
        echo -e "\n本步骤执行的命令如下，可保存以供复现:"
        printf "%b\n" "${step_commands[@]}"
        echo "或在以下文件中查看: $COMMAND_HISTORY_FILE"
    fi
}

# 步骤4: 运行 DADA2 去噪（双端模式）
function run_dada2() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n# =============================================" >>"$COMMAND_HISTORY_FILE"
    echo "# 运行 DADA2 去噪（双端模式） - $timestamp" >>"$COMMAND_HISTORY_FILE"
    echo "# 工作目录: $PWD" >>"$COMMAND_HISTORY_FILE"
    echo "步骤4: 运行 DADA2 去噪（双端模式）..."
    local step_commands=()
    if ! check_file "paired-demux.qza"; then
        echo "错误: 输入文件 paired-demux.qza 不存在"
        return
    fi
    # 获取用户输入参数
    echo "===== 正向序列参数设置(如果你已经切除了引物和barcode则都填0) ====="
    read -p "请输入正向序列 trim-left 值 [默认: 0]: " trim_left_f
    trim_left_f=${trim_left_f:-0}
    read -p "请输入正向序列 trunc-len 值 [默认: 0]: " trunc_len_f
    trunc_len_f=${trunc_len_f:-0}
    echo "===== 反向序列参数设置 ====="
    read -p "请输入反向序列 trim-left 值 [默认: 0]: " trim_left_r
    trim_left_r=${trim_left_r:-0}
    read -p "请输入反向序列 trunc-len 值 [默认: 0]: " trunc_len_r
    trunc_len_r=${trunc_len_r:-0}
    read -p "请输入使用的线程数 [默认: 12]: " threads
    threads=${threads:-12}
    read -p "请输入最大期望错误值 (max-ee) [默认: 2.0]: " max_ee
    max_ee=${max_ee:-2.0}
    read -p "请输入最小重叠长度 [默认: 12]: " min_overlap
    min_overlap=${min_overlap:-12}
    read -p "请输入样本去噪时的合并方法。可选两种：
        'independent'：独立处理每个样本（推荐）。
        'pseudo'：合并处理各个样本 
        [默认: pseudo]: " pooling_method
    pooling_method=${pooling_method:-"pseudo"}
    # 构建DADA2命令
    dada2_cmd=$(
        cat <<EOF
qiime dada2 denoise-paired \
    --i-demultiplexed-seqs paired-demux.qza \
    --p-trim-left-f "$trim_left_f" \
    --p-trim-left-r "$trim_left_r" \
    --p-trunc-len-f "$trunc_len_f" \
    --p-trunc-len-r "$trunc_len_r" \
    --p-max-ee-f "$max_ee" \
    --p-max-ee-r "$max_ee" \
    --p-min-overlap "$min_overlap" \
    --o-representative-sequences dada2-rep-seqs.qza \
    --o-table dada2-table.qza \
    --o-denoising-stats dada2-stats.qza \
    --p-pooling-method "$pooling_method" \
    --p-n-threads "$threads" \
    --verbose
EOF
    )
    # 显示并执行命令
    echo -e "\n准备执行的DADA2去噪命令:\n"
    printf "%b\n" "$dada2_cmd"
    echo "执行中..."
    time eval "$dada2_cmd" \
        &>log/run_dada2.log
    step_commands+=("$dada2_cmd")
    add_to_history "$dada2_cmd" "DADA2双端去噪"
    # 显示结果信息
    echo -e "\nDADA2 双端去噪完成。生成文件:"
    echo "- 代表序列: dada2-rep-seqs.qza"
    echo "- 特征表: dada2-table.qza"
    echo "- 统计信息: dada2-stats.qza"
    echo "- 日志文件: log/run_dada2.log"
    # 显示本步骤执行的命令
    if [ ${#step_commands[@]} -gt 0 ]; then
        echo -e "\n本步骤执行的命令，您可以复制保存:"
        printf "%b\n" "${step_commands[@]}"
        echo -e "或在以下文件中查看记录 $COMMAND_HISTORY_FILE"
    fi
}

# 步骤5: 导出 DADA2 结果
function export_dada2() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n# =============================================" >>"$COMMAND_HISTORY_FILE"
    echo "# 导出 DADA2 结果 - $timestamp" >>"$COMMAND_HISTORY_FILE"
    echo "# 工作目录: $PWD" >>"$COMMAND_HISTORY_FILE"
    echo "步骤5: 导出 DADA2 结果..."
    local step_commands=()
    if ! check_file "dada2-table.qza"; then
        echo "错误: DADA2 结果文件不存在"
        return
    fi
    # 创建输出目录
    output_dir="dada2-exported"
    mkdir_cmd="mkdir -p \"$output_dir\""
    eval "$mkdir_cmd"
    step_commands+=("$mkdir_cmd")
    add_to_history "$mkdir_cmd"
    # 导出特征表命令
    export_cmd=$(
        cat <<EOF
qiime tools export \
    --input-path dada2-table.qza \
    --output-path "$output_dir"
EOF
    )
    echo -e "\n准备执行的导出命令:\n"
    printf "%b\n" "$export_cmd"
    echo "执行中..."
    time eval "$export_cmd" \
        &>log/export_dada2.log
    step_commands+=("$export_cmd")
    add_to_history "$export_cmd"
    # BIOM转换命令
    biom_cmd=$(
        cat <<EOF
biom convert \
    -i "$output_dir/feature-table.biom" \
    -o "$output_dir/otu_table.tsv" \
    --table-type="OTU table" \
    --to-tsv
EOF
    )
    echo -e "\n准备执行的BIOM转换命令:\n"
    printf "%b\n" "$biom_cmd"
    echo "执行中..."
    time eval "$biom_cmd" \
        &>>log/export_dada2.log
    step_commands+=("$biom_cmd")
    add_to_history "$biom_cmd"
    # 处理TSV文件命令
    sed_cmds=(
        "sed -i '1d' \"$output_dir/otu_table.tsv\""
        "sed -i 's/#OTU ID/ASV ID/' \"$output_dir/otu_table.tsv\""
        "cat \"$output_dir/otu_table.tsv\" | tr '\t' ',' >\"$output_dir/otu_table.csv\""
    )
    echo -e "\n准备执行的文件处理命令:"
    for cmd in "${sed_cmds[@]}"; do
        printf "%b\n" "$cmd"
        eval "$cmd"
        step_commands+=("$cmd")
        add_to_history "$cmd"
    done
    echo -e "\nDADA2 结果已导出到 $output_dir 目录"
    echo "生成文件:"
    echo "- $output_dir/feature-table.biom"
    echo "- $output_dir/otu_table.tsv"
    echo "- $output_dir/otu_table.csv"
    echo "- 日志文件: log/export_dada2.log"
    # 显示本步骤执行的命令
    if [ ${#step_commands[@]} -gt 0 ]; then
        echo -e "\n本步骤执行的命令，您可以复制保存:"
        printf "%b\n" "${step_commands[@]}"
        echo -e "或在以下文件中查看记录 $COMMAND_HISTORY_FILE"
    fi
}

# 步骤6: 物种注释
function classify_taxonomy() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n# =============================================" >>"$COMMAND_HISTORY_FILE"
    echo "# 执行物种注释 - $timestamp" >>"$COMMAND_HISTORY_FILE"
    echo "# 工作目录: $PWD" >>"$COMMAND_HISTORY_FILE"
    echo "步骤6: 执行物种注释..."
    local step_commands=()
    if ! check_file "dada2-rep-seqs.qza"; then
        echo "错误: 代表序列文件不存在"
        return
    fi
    # 获取分类器文件
    read -p "请输入分类器文件路径 [默认: unite_ver10_dynamic_s_all_19.02.2025-Q2-2024.10.qza]: " classifier
    classifier=${classifier:-"unite_ver10_dynamic_s_all_19.02.2025-Q2-2024.10.qza"}
    if ! check_file "$classifier"; then
        echo "错误: 分类器文件不存在"
        return
    fi
    # 获取线程数
    read -p "请输入使用的线程数 [默认: 1]: " threads
    threads=${threads:-1}
    # 构建分类命令
    classify_cmd=$(
        cat <<EOF
qiime feature-classifier classify-sklearn \
    --i-reads dada2-rep-seqs.qza \
    --i-classifier "$classifier" \
    --o-classification taxonomy.qza \
    --p-n-jobs "$threads" \
    --verbose
EOF
    )
    # 显示并执行命令
    echo -e "\n准备执行的物种注释命令:\n"
    printf "%b\n" "$classify_cmd"
    echo "执行中..."
    time eval "$classify_cmd" \
        &>log/classify_taxonomy.log
    step_commands+=("$classify_cmd")
    add_to_history "$classify_cmd" "物种注释"
    # 构建可视化命令
    visualize_cmd=$(
        cat <<EOF
qiime metadata tabulate \
    --m-input-file taxonomy.qza \
    --o-visualization taxonomy.qzv
EOF
    )
    echo -e "\n准备执行的分类结果可视化命令:\n"
    printf "%b\n" "$visualize_cmd"
    echo "执行中..."
    time eval "$visualize_cmd" \
        &>>log/classify_taxonomy.log
    step_commands+=("$visualize_cmd")
    add_to_history "$visualize_cmd" "分类结果可视化"
    echo -e "\n物种注释完成。生成文件:"
    echo "- 分类结果: taxonomy.qza"
    echo "- 可视化结果: taxonomy.qzv"
    echo "- 日志文件: log/classify_taxonomy.log"
    # 显示本步骤执行的命令
    if [ ${#step_commands[@]} -gt 0 ]; then
        echo -e "\n本步骤执行的命令，您可以复制保存:"
        printf "%b\n" "${step_commands[@]}"
        echo -e "或在以下文件中查看记录 $COMMAND_HISTORY_FILE"
    fi
}

# 步骤7: 生成物种注释条形图
function taxa_barplot() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n# =============================================" >>"$COMMAND_HISTORY_FILE"
    echo "# 生成物种注释条形图 - $timestamp" >>"$COMMAND_HISTORY_FILE"
    echo "# 工作目录: $PWD" >>"$COMMAND_HISTORY_FILE"
    echo "步骤7: 生成物种注释条形图..."
    local step_commands=()
    if ! check_file "dada2-table.qza"; then
        echo "错误: 特征表不存在"
        return
    fi
    if ! check_file "taxonomy.qza"; then
        echo "错误: 物种注释文件不存在"
        return
    fi
    # 获取元数据文件
    read -p "请输入元数据文件路径 [默认: sample-metadata.tsv]: " metadata
    metadata=${metadata:-"sample-metadata.tsv"}
    if ! check_file "$metadata"; then
        echo "错误: 元数据文件不存在"
        return
    fi
    # 构建条形图生成命令
    barplot_cmd=$(
        cat <<EOF
qiime taxa barplot \
    --i-table dada2-table.qza \
    --i-taxonomy taxonomy.qza \
    --m-metadata-file "$metadata" \
    --o-visualization taxa-bar-plots.qzv \
    --verbose
EOF
    )
    # 显示并执行命令
    echo -e "\n准备执行的条形图生成命令:\n"
    printf "%b\n" "$barplot_cmd"
    echo "执行中..."
    time eval "$barplot_cmd" \
        &>log/taxa_barplot.log
    step_commands+=("$barplot_cmd")
    add_to_history "$barplot_cmd" "生成物种注释条形图"
    echo -e "\n物种注释条形图已生成:"
    echo "- 可视化文件: taxa-bar-plots.qzv"
    echo "- 日志文件: log/taxa_barplot.log"
    # 显示本步骤执行的命令
    if [ ${#step_commands[@]} -gt 0 ]; then
        echo -e "\n本步骤执行的命令，您可以复制保存:"
        printf "%b\n" "${step_commands[@]}"
        echo -e "或在以下文件中查看记录 $COMMAND_HISTORY_FILE"
    fi
}

# 步骤8: 导出带物种注释的结果
function export_taxonomy() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n# =============================================" >>"$COMMAND_HISTORY_FILE"
    echo "# 导出带物种注释的结果 - $timestamp" >>"$COMMAND_HISTORY_FILE"
    echo "# 工作目录: $PWD" >>"$COMMAND_HISTORY_FILE"
    echo "步骤8: 导出带物种注释的结果..."
    local step_commands=()
    if ! check_file "dada2-table.qza" || ! check_file "taxonomy.qza"; then
        echo "错误: 必需文件不存在"
        return
    fi
    # 创建输出目录
    output_dir="taxonomy-exported"
    mkdir_cmd="mkdir -p \"$output_dir\""
    echo -e "\n准备执行的命令:\n$mkdir_cmd"
    eval "$mkdir_cmd"
    step_commands+=("$mkdir_cmd")
    add_to_history "$mkdir_cmd"
    # 导出特征表命令
    export_table_cmd=$(
        cat <<EOF
qiime tools export \
    --input-path dada2-table.qza \
    --output-path "$output_dir"
EOF
    )
    echo -e "\n准备执行的命令:\n$export_table_cmd"
    echo "执行中..."
    time eval "$export_table_cmd" \
        &>log/export_taxonomy.log
    step_commands+=("$export_table_cmd")
    add_to_history "$export_table_cmd"
    # 导出物种注释命令
    export_tax_cmd=$(
        cat <<EOF
qiime tools export \
    --input-path taxonomy.qza \
    --output-path "$output_dir"
EOF
    )
    echo -e "\n准备执行的命令:\n$export_tax_cmd"
    echo "执行中..."
    time eval "$export_tax_cmd" \
        &>log/export_taxonomy.log
    step_commands+=("$export_tax_cmd")
    add_to_history "$export_tax_cmd"
    # 合并结果命令
    biom_add_cmd=$(
        cat <<EOF
biom add-metadata \
    -i "$output_dir/feature-table.biom" \
    --observation-metadata-fp "$output_dir/taxonomy.tsv" \
    -o "$output_dir/feature-table.tax.biom" \
    --sc-separated taxonomy \
    --observation-header OTUID,taxonomy
EOF
    )
    echo -e "\n准备执行的命令:\n$biom_add_cmd"
    echo "执行中..."
    time eval "$biom_add_cmd" \
        &>log/export_taxonomy.log
    step_commands+=("$biom_add_cmd")
    add_to_history "$biom_add_cmd"
    # 转换格式命令
    biom_convert_cmd=$(
        cat <<EOF
biom convert \
    -i "$output_dir/feature-table.tax.biom" \
    -o "$output_dir/otu_table.tax.tsv" \
    --table-type="OTU table" \
    --to-tsv --header-key taxonomy
EOF
    )
    echo -e "\n准备执行的命令:\n$biom_convert_cmd"
    echo "执行中..."
    time eval "$biom_convert_cmd" \
        &>log/export_taxonomy.log
    step_commands+=("$biom_convert_cmd")
    add_to_history "$biom_convert_cmd"
    # 清理和格式化命令
    sed_cmd1="sed -i '1d' \"$output_dir/otu_table.tax.tsv\""
    sed_cmd2="sed -i 's/#OTU ID/ASV ID/' \"$output_dir/otu_table.tax.tsv\""
    tr_cmd="cat \"$output_dir/otu_table.tax.tsv\" | tr '\t' ',' >\"$output_dir/otu_table.tax.csv\""
    time eval "$biom_convert_cmd" \
        echo -e "\n准备执行的命令:\n$sed_cmd1\n$sed_cmd2\n$tr_cmd"
    echo "执行中..."
    time eval "sed_cmd1" \
        &>log/export_taxonomy.log
    time eval "sed_cmd2" \
        &>log/export_taxonomy.log
    time eval "tr_cmd" \
        &>log/export_taxonomy.log
    step_commands+=("$sed_cmd1" "$sed_cmd2" "$tr_cmd")
    add_to_history "$sed_cmd1"
    add_to_history "$sed_cmd2"
    add_to_history "$tr_cmd"
    echo "带物种注释的结果已导出到 $output_dir 目录"
    # 显示本步骤执行的命令
    if [ ${#step_commands[@]} -gt 0 ]; then
        echo -e "\n本步骤执行的命令，您可以复制保存:"
        printf "%b\n" "${step_commands[@]}"
        echo -e "或在以下文件中查看记录 $COMMAND_HISTORY_FILE"
    fi
}

# 完整流程
function full_pipeline() {
    generate_manifest
    import_and_summarize
    trim_primers
    run_dada2
    export_dada2
    classify_taxonomy
    taxa_barplot
    export_taxonomy
}

# 主循环
while true; do
    show_menu
    case $choice in
    1)
        generate_manifest
        read -p "按回车键继续..."
        ;;
    2)
        import_and_summarize
        read -p "按回车键继续..."
        ;;
    3)
        trim_primers
        read -p "按回车键继续..."
        ;;
    4)
        run_dada2
        read -p "按回车键继续..."
        ;;
    5)
        export_dada2
        read -p "按回车键继续..."
        ;;
    6)
        classify_taxonomy
        read -p "按回车键继续..."
        ;;
    7)
        taxa_barplot
        read -p "按回车键继续..."
        ;;
    8)
        export_taxonomy
        read -p "按回车键继续..."
        ;;
    9)
        full_pipeline
        read -p "按回车键继续..."
        ;;
    0)
        show_command_history
        echo "退出程序。"
        exit 0
        ;;
    *)
        echo "无效选择"
        read -p "按回车键继续..."
        ;;
    esac
done
