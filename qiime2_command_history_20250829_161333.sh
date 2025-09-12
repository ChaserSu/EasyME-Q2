#!/bin/bash
# QIIME2 命令历史 - 生成于 Fri Aug 29 16:13:33 CST 2025
# 工作目录: /public_data/home/16s
# 注意: 此文件包含所有确认执行的命令

set -e  # 遇到错误自动退出


# 设置工作目录
cd "/public_data/home/16s" 

# 初始化Conda
source "/public_data/home/software/db/miniconda3/etc/profile.d/conda.sh"

# 激活QIIME2环境
conda activate "qiime2-amplicon-2025.4"

# 创建日志目录
mkdir -p log

# =============================================
# 生成manifest文件 - 2025-08-29 16:13:38
# 工作目录: /public_data/home/16s
function generate_manifest() {
    use_prefixf="n"
    prefixf=""
    use_suffixf="y"
    suffixf=".raw_1.fastq.gz"
    touch forward
    find . -type f -name "*.raw_1.fastq.gz" -print0 | while IFS= read -r -d '' file; do
        clean_path="${file#./}"
        filename=$(basename "$clean_path")
        sample_name=${filename#""}
        sample_name=${sample_name%".raw_1.fastq.gz"}
        echo -e "${sample_name}\t$PWD/$clean_path"
    done >> forward
    sort -t $'\t' -k1,1 -o forward forward
    use_prefixr="n"
    prefixr=""
    use_suffixr="y"
    suffixr=".raw_2.fastq.gz"
    touch reverse
    find . -type f -name "*.raw_2.fastq.gz" -print0 | while IFS= read -r -d '' file; do
        clean_path="${file#./}"
        filename=$(basename "$clean_path")
        sample_name=${filename#""}
        sample_name=${sample_name%".raw_2.fastq.gz"}
        echo -e "${sample_name}\t$PWD/$clean_path"
    done >> reverse
    sort -t $'\t' -k1,1 -o reverse reverse
    join -t $'\t' forward reverse > manifest.csv
    echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" | cat - manifest.csv > manifest.tmp && mv manifest.tmp manifest.csv
    cat manifest.csv | tr " " "\t" > manifest
    rm -f forward reverse manifest.csv
    echo "manifest : $PWD/manifest"
}

generate_manifest

# =============================================
# 导入数据并生成摘要 - 2025-08-29 16:14:24
# 工作目录: /public_data/home/16s
qiime tools import     --type 'SampleData[PairedEndSequencesWithQuality]'     --input-path manifest     --output-path paired-raw-demux.qza     --input-format PairedEndFastqManifestPhred33V2
qiime demux summarize     --i-data paired-raw-demux.qza     --verbose     --o-visualization paired-raw-demux.qzv

# =============================================
# 去除barcode和引物（双端模式） - 2025-08-29 16:33:59
# 工作目录: /public_data/home/16s
qiime cutadapt trim-paired     --i-demultiplexed-sequences paired-raw-demux.qza     --p-front-f "GTGCCAGCMGCCGCGGTAA"     --p-front-r "GGACTACHVGGGTWTCTAAT"     --o-trimmed-sequences paired-demux2.qza     --p-cores "12"     --verbose
cp -f paired-demux2.qza paired-demux.qza
rm paired-demux2.qza
qiime tools export     --input-path paired-demux.qza     --output-path demux_exported
qiime demux summarize     --i-data paired-demux.qza     --verbose     --o-visualization paired-demux.qzv

# =============================================
# 运行 DADA2 去噪（双端模式） - 2025-08-29 16:38:04
# 工作目录: /public_data/home/16s

# DADA2双端去噪
qiime dada2 denoise-paired     --i-demultiplexed-seqs paired-demux.qza     --p-trim-left-f "0"     --p-trim-left-r "0"     --p-trunc-len-f "0"     --p-trunc-len-r "0"     --p-max-ee-f "2.0"     --p-max-ee-r "2.0"     --p-min-overlap "12"     --o-representative-sequences dada2-rep-seqs.qza     --o-table dada2-table.qza     --o-denoising-stats dada2-stats.qza     --p-pooling-method "pseudo"     --p-n-threads "128"     --verbose

# =============================================
# 导出 DADA2 结果 - 2025-08-29 17:53:36
# 工作目录: /public_data/home/16s
mkdir -p "dada2-exported"
qiime tools export     --input-path dada2-table.qza     --output-path "dada2-exported"
biom convert     -i "dada2-exported/feature-table.biom"     -o "dada2-exported/otu_table.tsv"     --table-type="OTU table"     --to-tsv
sed -i '1d' "dada2-exported/otu_table.tsv"
sed -i 's/#OTU ID/ASV ID/' "dada2-exported/otu_table.tsv"
cat "dada2-exported/otu_table.tsv" | tr '\t' ',' >"dada2-exported/otu_table.csv"

# =============================================
# 执行物种注释 - 2025-08-29 17:54:02
# 工作目录: /public_data/home/16s

# 物种注释
qiime feature-classifier classify-sklearn     --i-reads dada2-rep-seqs.qza     --i-classifier "2024.09.backbone.v4.nb.sklearn-1.4.2.qza"     --o-classification taxonomy.qza     --p-n-jobs "128"     --verbose

# 分类结果可视化
qiime metadata tabulate     --m-input-file taxonomy.qza     --o-visualization taxonomy.qzv

# =============================================
# 生成物种注释条形图 - 2025-08-29 18:02:27
# 工作目录: /public_data/home/16s

# 生成物种注释条形图
qiime taxa barplot     --i-table dada2-table.qza     --i-taxonomy taxonomy.qza     --m-metadata-file "sample-metadata.tsv"     --o-visualization taxa-bar-plots.qzv     --verbose

# =============================================
# 导出带物种注释的结果 - 2025-08-29 18:06:44
# 工作目录: /public_data/home/16s
mkdir -p "taxonomy-exported"
qiime tools export     --input-path dada2-table.qza     --output-path "taxonomy-exported"
qiime tools export     --input-path taxonomy.qza     --output-path "taxonomy-exported"
biom add-metadata     -i "taxonomy-exported/feature-table.biom"     --observation-metadata-fp "taxonomy-exported/taxonomy.tsv"     -o "taxonomy-exported/feature-table.tax.biom"     --sc-separated taxonomy     --observation-header OTUID,taxonomy
biom convert     -i "taxonomy-exported/feature-table.tax.biom"     -o "taxonomy-exported/otu_table.tax.tsv"     --table-type="OTU table"     --to-tsv --header-key taxonomy
sed -i '1d' "taxonomy-exported/otu_table.tax.tsv"
sed -i 's/#OTU ID/ASV ID/' "taxonomy-exported/otu_table.tax.tsv"
cat "taxonomy-exported/otu_table.tax.tsv" | tr '\t' ',' >"taxonomy-exported/otu_table.tax.csv"
