# 环境、报错与故障排查

## 1. 环境自检清单

```bash
Rscript --version
Rscript -e 'cat(R.version.string, "\n"); print(.libPaths())'
Rscript -e 'cat(capabilities()[c("png","cairo","X11")], "\n")'
```

```r
pkgs <- c("ggplot2","dplyr","tidyr","readr","stringr","forcats","scales",
          "patchwork","ggrepel","showtext","systemfonts","ragg","svglite")
data.frame(pkg = pkgs,
           installed = pkgs %in% rownames(installed.packages()))
```

### R 本体（解释器）下载：也走国内镜像

CRAN 官方站下 R 安装包在国内常常只有几十 KB/s。用镜像的 `bin/` 目录：

| 平台 | 地址 | 下哪个文件 |
|---|---|---|
| Windows | `https://mirrors.tuna.tsinghua.edu.cn/CRAN/bin/windows/base/` | `R-4.x.x-win.exe` |
| macOS (Apple Silicon) | `https://mirrors.tuna.tsinghua.edu.cn/CRAN/bin/macosx/` | `R-4.x.x-arm64.pkg` |
| macOS (Intel) | 同上 | `R-4.x.x-x86_64.pkg` |
| Linux | 发行版仓库 | `apt install r-base` / `dnf install R` |

把域名换成 `mirrors.aliyun.com`、`mirrors.ustc.edu.cn` 等同样有效（路径一致）。macOS 也可 `brew install r`，但 Homebrew 走的境外源可能需要代理。

缺包安装：**自动测速选国内镜像 → 失败自动换源 → 仍失败才手动下载**。默认连 `cloud.r-project.org` 在国内经常几百 KB/s 甚至超时，不要用。

```r
# 手动装（自己写脚本时至少设好镜像与超时）
options(repos   = c(CRAN = "https://mirrors.aliyun.com/CRAN/"),
        timeout = 600,                       # 默认 60s 对大包不够
        download.file.method = "libcurl")    # 支持 HTTPS、可续传
install.packages(c("tidyr", "readr", "showtext", "ragg", "svglite"))

# 装到用户库（系统库无写权限 / 被安全软件拦截时）
install.packages(pkgs, lib = "~/Library/R/arm64/4.5/library")  # macOS arm64
# macOS Intel: ~/Library/R/x86_64/4.x/library；Linux: ~/R/x86_64-pc-linux-gnu-library/4.x
# Windows: %USERPROFILE%/Documents/R/win-library/4.x
```

一键脚本（推荐，自动处理镜像、超时、二进制、用户库）：

| 命令 | 作用 |
|---|---|
| `Rscript check_env.R --install` | 装缺失的必需包（自动测速选最快镜像） |
| `Rscript check_env.R --install --optional` | 连常用扩展包一起装 |
| `Rscript check_env.R --install --only=ggrepel,lme4` | 只装指定包（可写任意包名） |
| `Rscript check_env.R --install --binary` | 强制二进制，**免编译**（macOS/Windows） |
| `Rscript check_env.R --install --jobs=4` | 源码编译时并行进程数 |
| `Rscript check_env.R --install --proxy=http://127.0.0.1:7890` | 走本地代理（Clash/V2Ray 默认端口） |
| `Rscript check_env.R --install --save` | 把最优镜像永久写入 `~/.Rprofile` |
| `Rscript check_env.R --list-mirrors` | 看各镜像延迟与是否支持二进制 |

### 备选镜像（按优先级，均已实测可访问）

| 镜像 | URL | 备注 |
|---|---|---|
| 阿里云 | `https://mirrors.aliyun.com/CRAN/` | 通常最快 |
| 中科大 USTC | `https://mirrors.ustc.edu.cn/CRAN/` | 老牌稳定 |
| 北外 BFSU | `https://mirrors.bfsu.edu.cn/CRAN/` | 教育网快 |
| 清华 TUNA | `https://mirrors.tuna.tsinghua.edu.cn/CRAN/` | 老牌稳定 |
| 南京大学 | `https://mirrors.nju.edu.cn/CRAN/` | 备用 |
| 上海交大 | `https://mirror.sjtu.edu.cn/CRAN/` | 备用 |
| 腾讯云 | `https://mirrors.cloud.tencent.com/CRAN/` | 备用 |
| CRAN 官方 | `https://cloud.r-project.org/` | 国内慢，仅作最后备选 |

实测结论（2026-10，国内家用宽带）：

- 上述 7 个国内镜像**都同时提供源码、macOS arm64 二进制、Windows 二进制**，即都能免编译安装；
- 每个镜像的延迟差异明显（0.05–0.5s），且不同运营商、不同时间会变化，所以**不要硬编码某一个镜像**，用 `--list-mirrors` 现测；
- **Posit 公共包源（`packagemanager.posit.co`）在国内大陆基本不可用**，8 秒超时无响应，不要作为首选；
- 已失效、不要使用：`mirrors.163.com/CRAN/`（无响应）、`mirrors.huaweicloud.com/repository/r/`（404）。

### 二进制 vs 源码：这是国内装包速度的关键

| 平台 | 默认行为 | 建议 |
|---|---|---|
| Windows | `install.packages()` 默认取 `.zip` 二进制 | 保持默认，无需编译 |
| macOS | 国内镜像同时有 `.tgz` 二进制与源码，`pkgType = "both"` 时优先二进制 | 用 `--binary` 最稳 |
| Linux | 只能源码编译 | `--jobs=4` 并行；`apt install r-cran-*` 或 Posit 的 Linux 二进制仓库更快 |

编译型重包（`lme4`、`forecast`、`readr`、`data.table`、`sf`、`rstan`、`tidytext`）在 macOS 上源码编译常因缺 `gfortran`／系统库失败，**优先用二进制**能绕开绝大多数编译错误。

> 小技巧：`install.packages(type = "binary")` 在 macOS/Windows 且镜像有二进制时，会直接下载预编译包，不调用编译器，通常快 5–10 倍。

### 自动安装失败 → 手动下载安装

全部镜像都失败时（公司网络、代理拦截、证书问题），按镜像路径直接下载，别去 CRAN 官方站（国内慢）：

| 要下的文件 | 镜像内路径 |
|---|---|
| 源码包（通用） | `<镜像>/src/contrib/<包名>_<版本>.tar.gz` |
| macOS arm64 二进制 | `<镜像>/bin/macosx/big-sur-arm64/contrib/4.5/<包名>_<版本>.tgz` |
| macOS Intel 二进制 | `<镜像>/bin/macosx/contrib/4.5/<包名>_<版本>.tgz` |
| Windows 二进制 | `<镜像>/bin/windows/contrib/4.5/<包名>_<版本>.zip` |

例：`https://mirrors.aliyun.com/CRAN/bin/windows/contrib/4.5/ggrepel_0.9.6.zip`。
不知道最新版本号时，先打开同目录下的 `PACKAGES` 文件搜包名即可。

```r
# 本地安装（type 必须与文件类型对应）
install.packages("~/Downloads/ggpubr_0.6.0.tar.gz", repos = NULL, type = "source")     # 源码
install.packages("~/Downloads/ggpubr_0.6.0.tgz",    repos = NULL, type = "mac.binary") # macOS
install.packages("C:/Users/me/Downloads/ggpubr_0.6.0.zip", repos = NULL, type = "win.binary") # Windows
# 或 RStudio: Tools → Install Packages → Install from: Package Archive File
```

**依赖缺失**：手动装时若报 `there is no package called 'rlang'`，说明依赖也得先装——用 `tools::package_dependencies("ggpubr", db = available.packages(), recursive = TRUE)` 查全量依赖，逐个按上面的路径下载。

3. **GitHub 上的包**（CRAN 没有）：`remotes::install_github("owner/repo")`；国内常失败，可加 `options(timeout = 600)` 或用 Gitee 镜像。
4. **装到没有写权限的库**：先建用户库 `dir.create("~/Library/R/arm64/4.5/library", recursive = TRUE)`，再 `install.packages(pkgs, lib = <该路径>)`，并确认 `.libPaths()` 包含它。
5. **彻底离线**：在能上网的机器上 `download.packages(pkgs, destdir = "pkgs", type = "source")`，把整个目录拷过去，`install.packages(list.files("pkgs", full.names = TRUE), repos = NULL, type = "source")`。

### 代理与永久镜像配置

公司网络或需要科学上网时，让 R 走本地代理（Clash / V2Ray 默认 7890）：

```r
Sys.setenv(http_proxy = "http://127.0.0.1:7890",
           https_proxy = "http://127.0.0.1:7890")
options(download.file.method = "libcurl")
```

免每次设置，写进 `~/.Rprofile`（`check_env.R --install --save` 会自动写入并备份原文件）：

```r
## >>> r-data-workbench: CRAN 镜像 >>>
options(repos = c(CRAN = "https://mirrors.aliyun.com/CRAN/"))
options(timeout = 600)
options(download.file.method = "libcurl")
## <<< r-data-workbench <<<
```

### 国内安装高频报错

| 报错 | 原因 | 解决 |
|---|---|---|
| `cannot open URL ... Timeout of 60 seconds was reached` | 默认超时太短，大包下不完 | `options(timeout = 600)` |
| `unable to access index for repository` | 镜像不可达 / DNS 污染 | `--list-mirrors` 换一个；或设代理 |
| `SSL certificate problem: unable to get local issuer certificate` | 公司网络中间人证书 | Windows 改 `options(download.file.method = "wininet")`；或设 `CURL_CA_BUNDLE` |
| `there is no package called 'xxx'`（编译中途） | 依赖没装上 | 先装依赖，或用 `--binary` 绕开编译 |
| `ld: library not found for -lgfortran` | macOS 缺 gfortran，源码编译失败 | 改用 `--binary`；或装 mac 版 gfortran |
| `package 'x' is not available for this version of R` | 镜像索引过期或包已归档 | 换镜像；归档包用 `install.packages("x", repos = "https://cran.r-project.org")` 或从 CRAN Archive 下源码 |
| `Warning: unable to move temporary installation` | 杀毒软件/OneDrive 锁文件 | 装到用户库 `--lib=~`，或把库目录排除在实时扫描外 |
| 下载速度只有几十 KB/s | 用了官方源或跨境线路 | 换国内镜像（阿里云/中科大） |

### 安装后仍找不到包

- 确认安装到了 `.libPaths()` 里的某个库：`find.package("pkg")`。
- 重启 R 会话或 `library(pkg)` 前检查拼写。
- 多版本 R 共存时装到了旧版本库：用当前会话的 `R.version.string` 核对。

## 2. 高频报错对照表

| 报错 / 现象 | 原因 | 解决 |
|---|---|---|
| `could not find function "ggplot"` | 未加载包 | `library(ggplot2)` |
| `there is no package called 'x'` | 未安装 | `install.packages("x")` |
| `object 'x' not found` | 变量名错 / 未赋值 / 作用域问题 | 检查拼写，确认在 `aes()` 中用列名而非字符串 |
| `Aesthetics must be either length 1 or the same as the data` | 映射向量长度不匹配 | 改为列名映射，或把常量写在 `aes()` 外 |
| `Discrete value supplied to continuous scale` | 数值列被读成字符 | `as.numeric()` 或读取时指定 `col_types` |
| `Continuous value supplied to discrete scale` | 字符映射给了 `fill` 连续标度 | 改 `scale_fill_manual()` 或先 `factor()` |
| `stat_count() must not be used with a y aesthetic` | 用了 `geom_bar()` 但已给 y | 改 `geom_col()` |
| `Removed k rows containing missing values` | 有 NA 或超出 limits | 检查缺失值；用 `coord_cartesian()` 代替 `ylim()` |
| `Font family not found` / 中文变方框 | 设备无该字体 | 见第 4 节 |
| `invalid graphics state` | 设备异常 | `dev.off()` 后重开 |
| `cannot open file 'Rplots.pdf'` | 无写权限 / 已打开 | 指定 `ggsave()` 路径 |
| `there is no package called 'ragg'`（ggsave 报） | 缺后端 | 装 `ragg`，或指定 `device = "png"` |
| `Killed` / 内存溢出 | 数据过大 | `data.table`/`arrow`，分块处理，`rm()` + `gc()` |
| `contrasts can be applied only to factors with 2 or more levels` | 分组只剩 1 个水平 | 检查筛选条件后的分组计数 |
| `NA/NaN/Inf in 'x'`（建模时报） | 数据含缺失/无穷 | `na.omit()` 或先插补，`is.finite()` 过滤 |

## 3. 图表跑不出来时的排查顺序

1. **退到 base R**：`plot(df$x, df$y)` 能否出图 → 判断是数据问题还是 ggplot 问题。
2. **只留一层**：`ggplot(df, aes(x, y)) + geom_point()` → 逐层加回，定位出错图层。
3. **看数据结构**：`str(df)` → 数值列是否被读成字符、因子水平是否符合预期。
4. **查缺失**：`sum(!complete.cases(df))`。
5. **最小复现**：用 `head(df, 20)` 或 `dput(head(df, 5))` 造最小例子。

## 4. 中文字体与乱码

### 4.1 诊断

```r
systemfonts::system_fonts() |> subset(grepl("Hei|Song|Kai|YaHei|PingFang|Noto", family))
```

### 4.2 方案 A：showtext（跨平台最稳）

```r
library(showtext)
showtext_auto()
# macOS
font_add("cn", "/System/Library/Fonts/Supplemental/Songti.ttc")
# Windows
# font_add("cn", "C:/Windows/Fonts/msyh.ttc")
# Linux
# font_add("cn", "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")

ggplot(df, aes(x, y)) + geom_point() +
  theme(text = element_text(family = "cn"))
```

`showtext_auto()` 要在**绘图前**调用；导出 PDF 时建议配 `showtext_opts(dpi = 300)`。

### 4.3 方案 B：cairo 设备

```r
ggsave("fig.pdf", p, device = cairo_pdf, width = 85, height = 70, units = "mm")
ggsave("fig.png", p, device = ragg::agg_png, dpi = 300, width = 1700, height = 1400, units = "px")
```

`cairo_pdf` 自动嵌入字体，投稿友好；`ragg::agg_png` 比默认 png 设备渲染质量高、支持字体回退。

### 4.4 中文 CSV 乱码

```r
readr::read_csv("data.csv", locale = locale(encoding = "GBK"))
# 或
readLines("data.csv", n = 1, warn = FALSE)   # 检查编码
```

## 5. 包管理

```r
# 记录依赖
renv::init(); renv::snapshot()      # 项目级锁定版本
# 复现
renv::restore()

# 会话信息
sessionInfo()
writeLines(capture.output(sessionInfo()), "output/session_info.txt")
```

同一脚本内**不要**混用 `library(plyr)` 与 `dplyr`（`summarise`/`rename` 会冲突）；必须用时 `dplyr::summarise()` 显式指定。

## 6. 性能

| 症状 | 优化 |
|---|---|
| 读取慢 | `fread()` / `arrow::read_parquet()` |
| 聚合慢 | `data.table` 或 `dtplyr` |
| 绘图慢（点 > 10 万） | `geom_hex()`、`scattermore::geom_scattermore()`、先抽样 |
| 循环慢 | 向量化 → `purrr::map_*()` → 必要时 `Rcpp` |
| 内存爆 | 只读需要的列（`select =`）、`rm()` + `gc()`、分块 |

## 7. 交付前自检

```bash
Rscript R/01_analysis.R     # 从干净会话重跑
ls -lh output/figures/      # 文件是否生成、大小是否合理
```

- 脚本里不要留 `setwd()` 绝对路径；用项目根目录 + 相对路径，或 `here::here()`。
- 不要依赖控制台里的临时对象，所有中间结果都要能从数据重新算出。
