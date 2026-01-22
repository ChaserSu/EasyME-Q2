# 附赠一个小工具，可以快捷切换R-Sever的后端R到当前Conda环境的R版本
<img width="1071" height="799" alt="image" src="https://github.com/user-attachments/assets/f8c5eac3-6cfc-4884-a235-f04765f827c3" />
# 切换到Conda环境的R后，请尽量使用Conda管理（尤其是下载）R的程序包，防止遇到潜在的冲突

```
mamba/conda search r-包名  # 精确搜：r-ggplot2 | 模糊搜：r-gg*
# 基础安装（多包空格分隔）
mamba/conda install r-包名1 r-包名2
# 指定版本+conda-forge频道
mamba/conda install -c conda-forge r-包名=版本号
mamba/conda remove 包名  # 卸载+清依赖：mamba/conda remove --prune r-包名
mamba/conda list | grep r-  # 筛选所有R包 | 精确查：mamba/conda list r-包名
mamba/conda update r-包名  # 更全部包：mamba/conda update --all（谨慎）
# BiocManager 安装生信类 R 包，先在Conda中进入R
if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager", repos = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/")
library(BiocManager)
BiocManager::install(version = "3.18")
# 多包批量安装（向量格式）
BiocManager::install(c("clusterProfiler", "org.Hs.eg.db", "ggplot2"))
```

# EasyME-Q2
厌倦了在QIIME2的初始设置上就卡住吗？EasyME-Q2来帮你

🚀 平滑入门：通过交互式CLI菜单，引导你完成最棘手的初始步骤（如创建manifest文件和数据导入）。

📚 在实践中学习：每次分析都会生成一个command_history.sh脚本。查看最终运行的精确QIIME2命令，让每次分析都变成一堂学习课。

✅ 内置可复现性：你的参数和命令被自动记录，确保完全可复现。

🎯 为初学者打造：停止记忆语法，开始开展科学。

## 🚀 开始之前 (Prerequisites)

请确保在运行脚本前，已准备好以下 **三个必需文件**：

### 1. 测序数据 (Sequencing Data)
*   放置于工作目录或其子目录下，个人习惯是建立一个名为“rawData”文件夹并将测序文件复制到其中。
*   必须是双端测序的压缩文件 (`.fastq.gz`)，并遵循典型的命名格式，例如：
    *   `A_1_1.raw_1.fastq.gz` (正向读取 Forward Read)
    *   `A_1_1.raw_2.fastq.gz` (反向读取 Reverse Read)
*   其中A_1_1是你的样品名称，这样只需要输入样品名称前的内容和样品名称后的内容，我们的脚本就可以直接通过读取测序文件名来确定样品名。

### 2. 样本元数据文件 (`sample-metadata.tsv`)
*   一个描述样品分组的TSV文件。
*   **重要**：必须保存为 **UTF-8 编码**。
*   需包含 `sample-id` 列。格式请严格遵循 [QIIME 2 官方元数据规范](https://docs.qiime2.org/2024.10/tutorials/metadata/)。
*   **示例格式：**
    ```tsv
    sample-id    barcode-sequence    body-site
    #q2:types    categorical         categorical
    L1S8         AGCTGACTAGTC       gut
    L1S57        ACACACTATGGC       gut
    ```

### 3. 预训练分类器 (Classifier)
*   用于物种注释的QZA文件（例如 `unite_ver10_dynamic_s_all_19.02.2025-Q2-2024.10.qza`）。
*   请从 [QIIME 2 数据资源页面](https://docs.qiime2.org/2024.10/data-resources/) 下载所需引物对应的分类器。

---

## 📁 脚本选择

我们提供了两个功能通用的脚本，其唯一区别在于预置的默认引物序列，以方便您的使用：
*   **`ME_16S.sh`**：预置 **515F-806R** 引物为默认值。
*   **`ME_ITS.sh`**：预置 **AMV4.5NF-AMDGR** 引物为默认值。

**使用方法**：只需将所选脚本复制到您的**工作目录**（包含上述FASTQ文件的目录）即可运行。

---

## 📖 学习与复现

本工具的核心优势之一是为每次分析自动生成一个 **回放脚本**（例如：`qiime2_command_history_20250829_161333.sh`）。

该文件完整记录了本次分析所执行的所有精确的 QIIME2 命令，具有两大价值：
1.  **完美复现**：可直接运行此脚本以复现整个分析流程。
2.  **最佳学习**：是您理解和学习 QIIME2 底层命令操作的绝佳参考。

我们也在代码库中提供了一个示例回放文件供您查阅。我们的数据都是双端的，如果你需要单端的版本，请给我留言，我会为您修改。
我们的功能都是模块化的，你也可以添加其他功能，例如将Qiime2官方的生成PCoA图的功能加入进来，相信我，当你可以这么做了的时候，你已经不必这么做了，就像已经学会走路的婴儿不再需要学步车，希望我们的小工具能够协助你走出Qiime2分析的第一步。
