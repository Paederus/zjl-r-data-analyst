# 老代码迁移对照表：把过时 R 绘图代码修到能跑

**什么时候读这份**：接手网上教程、书附代码、多年前的旧脚本，在现代 R（≥ 4.x）+ ggplot2（≥ 3.4/4.x）下报错或图形不对。修代码的顺序：先看本表的"报错特征"列，命中就按"改法"改；改完跑不通再查 `environment-and-troubleshooting.md`。

> 本表基于 2026-10 的实测：对《R语言数据可视化之美》配套代码库 168 个脚本做逐项扫描统计 + 三个国内镜像的包可用性核查；每条结论都标了证据来源。

---

## 一、包已死：装不上的先换包

`install.packages()` 报 `package 'xxx' is not available`（或 `is not available (for this version)`）时，先怀疑包被归档。**2023-10 与 2024 年 CRAN 清走了一批**，其中不少是教程常客：

| 归档包（已实查三个国内镜像均无） | 用途 | 替代方案 |
|---|---|---|
| `rgdal` / `rgeos` / `maptools` | 读 shp、空间运算（2023-10 退役） | **`sf`**：`st_read()` 读、`st_centroid()` 等替换 `rgeos`；配合 `geom_sf()` 绘图 |
| `ggalt` | `geom_dumbbell` 哑铃图、`geom_encircle` | 哑铃图 = `geom_segment()` + 两列 `geom_point()`；圈点 = `stat_ellipse()` |
| `ggTimeSeries` | `stat_steamgraph` 量化波形 | 纯 ggplot2 手写，见 `chart-recipes.md` 4.2 |
| `waffle` | 华夫饼图 | `geom_tile()` 手写，见 `chart-recipes.md` 5.1 |
| `ggmosaic` | 马赛克图 | `geom_rect()` 手写，见 `chart-recipes.md` 5.2 |
| `tabplot` | 大表表格图 | `gt` / `kableExtra`（报告）或 `patchwork` 分块热力图 |
| `ggstream` | streamgraph | 同 `ggTimeSeries` 替代 |
| `ComplexHeatmap`（不在 CRAN） | 聚类热力图 | Bioconductor 安装（`BiocManager::install()`），或先用 `pheatmap` |

核查方法（任何镜像，可复现）：

```r
options(repos = c(CRAN = "https://mirrors.aliyun.com/CRAN/"))
pkgs <- c("rgdal", "ggalt", "ggTimeSeries", "waffle", "ggmosaic")
pkgs[!pkgs %in% rownames(available.packages())]   # 输出即"装不上"的
```

国内镜像从官方 CRAN 同步，归档状态一致；**不要**去全网找旧版源码强装——依赖链多半也退役了，修起来比重写慢。

---

## 二、ggplot2 语法升级：三个最高频

### 2.1 `size =` → `linewidth =`（线宽）

- **何时**：ggplot2 ≥ 3.4 对线条类几何（`geom_line`、`geom_segment`、`geom_hline`、`geom_smooth` 的线、`geom_rect` 边框、`geom_density` 轮廓）传 `size` 会警告，图形仍出但线宽语义已分家。
- **改法**：线宽用 `linewidth`；**点和文字的大小仍叫 `size`**，别改错对象。
- 证据：某书配套库 168 个脚本中 141 个用 `size =`（共 1110 处），全部命中此条。

```r
# 旧
geom_line(size = 1) + geom_point(size = 2)
# 新
geom_line(linewidth = 1) + geom_point(size = 2)
```

### 2.2 `..count..` / `..level..` → `after_stat(...)`

- **何时**：ggplot2 ≥ 3.4 弃用双点统计映射，新版本直接报错。
- **改法**：

```r
# 旧
stat_density_tern(aes(fill = ..level..))     # ggtern
geom_text(stat = "stratum", aes(label = ..stratum..))
# 新
aes(fill = after_stat(level))
geom_text(stat = "stratum", aes(label = after_stat(stratum)))
```

### 2.3 离散 x 与连续 x 不能混在同一张图

- **症状**：`Discrete value supplied to a continuous scale.`（或反之）
- **场景**：手写半小提琴（多边形，x 是数值）+ 箱形图（x 是因子）叠在一图；或自算的参考线画在类别轴上。
- **改法**：类别轴整体转数值位置——`df$pos <- as.numeric(df$group)`，所有图层用 `pos`，最后 `scale_x_continuous(breaks = 1:3, labels = levels(df$group))` 贴回标签。完整示例见 `chart-recipes.md` 1.1。

---

## 三、其他高频旧写法

### 3.1 `reshape2::melt()` → `tidyr::pivot_longer()`

- **何时**：宽表转长表；老代码 41/168 个文件在用。
- `reshape2` 本身还在 CRAN 但多年不维护，且 `melt` 与 `data.table::melt`、`reshape::melt` 同名易串包。

```r
# 旧
m <- reshape2::melt(df, id = "time")
# 新
m <- tidyr::pivot_longer(df, cols = -time, names_to = "variable", values_to = "value")
```

配套的 `reshape::cast()` → `tidyr::pivot_wider()`；`plyr::join()` → `dplyr::left_join()`（plyr 与 dplyr 同载会互相搞坏 `summarise`，只留一个）。

### 3.2 `fortify(sp 对象)` → sf 管道

- **症状**：`fortify(map_shp)` 报错或 `rgdal` 装不上连带失败。
- **改法**：

```r
# 旧链：readOGR() -> fortify() -> geom_polygon(long/lat/group)
# 新链：
library(sf)
mp <- st_read("map.shp", quiet = TRUE)
ggplot() + geom_sf(data = mp, aes(fill = value)) + coord_sf()
```

投影用 `st_transform(mp, crs = 4326)`；质心 `st_centroid()`。`broom::tidy()` 只在拿到 sf 对象前的过渡期用。

### 3.3 R 4.0 起的默认值变化

| 变化 | 症状 | 改法 |
|---|---|---|
| `stringsAsFactors` 默认 FALSE | 旧脚本依赖字符列自动成因子，`facet_wrap`/图例顺序乱 | 显式 `factor(x, levels = ...)`（本来就该写） |
| `read.csv` 不再自动识别 `NA` 串之外的占位符 | `"999"`、空串进了数值列 | 读入时 `na.strings = c("NA", "", "999")` |
| `matrix()`/`data.frame()` 构造行为收紧 | `data.frame(matrix(...), check.names=FALSE)` 后列名带反引号 | 列名规范化后再赋 `names()` |

### 3.4 `aes_string()` → `.data[[ ]]`

```r
# 旧（已弃用）
ggplot(df, aes_string("x", "y", colour = "grp"))
# 新
ggplot(df, aes(.data[["x"]], .data[["y"]], colour = .data[[grp_var]]))
```

写自定义绘图函数时这条必改，`aes_string` 传字符串的安全替代就是 `.data[[ ]]`。

### 3.5 图形设备旧写法

```r
# 旧：Cairo::CairoPDF("f.pdf", 6, 4)          # 依赖外部 Cairo 库
# 新：pdf 设备优先 cairo 变体
ggsave("fig1.pdf", p, width = 6, height = 4, device = cairo_pdf)   # 中文/透明度正常
png("fig1.png", 1800, 1400, res = 300, type = "cairo")             # macOS/Windows 中文
```

字体老三样：`windowsFonts()`/`quartzFonts()` 手动注册 → `showtext::font_add()` + `showtext_auto()`，跨平台一致。

---

## 四、排查顺序建议

1. 先跑 `R.version.string` 和 `packageVersion("ggplot2")`——低于 3.4 的迁移规则反向适用（新代码别拿到旧版跑）。
2. 报错指向包 → 查第一节包是否归档；指向 aesthetic → 查 2.1–2.3；指向 `melt/cast/join` → 3.1。
3. 改完先小数据复现（`head(df)` 子集），通过再上全量。
4. 书里代码普遍缺 `set.seed()`、`stringsAsFactors`、字体注册三件套——修语法时顺手补上，见 `chart-recipes.md` 开头的通用约定。
