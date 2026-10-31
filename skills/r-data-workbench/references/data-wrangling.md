# 数据准备与整洁化

目标：把任意来源的原始数据变成一个"每行一个观测、每列一个变量、每个单元格一个值"的整洁数据框（tidy data），并让转换过程可追溯、可重跑。

## 1. 读取

```r
readr::read_csv("data/raw.csv", show_col_types = FALSE)          # 逗号
readr::read_csv2("data/raw.csv")                                  # 分号（欧洲）
readr::read_tsv("data/raw.tsv")
readxl::read_excel("data/raw.xlsx", sheet = 1, skip = 2)          # 多表头时 skip
haven::read_sav("data/raw.sav")                                   # SPSS
jsonlite::fromJSON("data/raw.json", flatten = TRUE)
arrow::read_parquet("data/raw.parquet")                           # 大文件首选
```

- 中文 CSV 乱码：优先 `readr::read_csv(..., locale = locale(encoding = "GBK"))`，或先转存 UTF-8。
- 大文件（> 500 MB）：`data.table::fread()` 或 `arrow`，不要用 `read.csv()`。

## 2. 结构探查（必做）

```r
dim(df); str(df); summary(df)
colSums(is.na(df))                                   # 缺失分布
sum(duplicated(df))                                  # 重复行
df |> count(group, sort = TRUE)                      # 分类水平计数
df |> summarise(across(where(is.numeric), ~sum(is.infinite(.x))))  # 无穷值
```

把发现的问题列成清单再动手，不要边看边改。

## 3. dplyr 五大动词

```r
df |>
  filter(group != "NA", value > 0) |>          # 行筛选
  select(id, group, value, everything()) |>    # 列选择/重排
  mutate(ratio = value / total,                # 新增/改写列
         group = factor(group, levels = c("Control", "A", "B")),
         date  = lubridate::ymd(date)) |>
  arrange(desc(value)) |>                      # 排序
  group_by(group) |>                           # 分组
  summarise(n = n(), mean = mean(value, na.rm = TRUE),
            sd = sd(value, na.rm = TRUE), .groups = "drop")
```

常用辅助：`rename()`、`relocate()`、`distinct()`、`slice_max()`、`pull()`、`across(where(is.numeric), scale)`、`case_when()`、`if_else()`、`coalesce()`、`na_if()`。

**分组计数**：`count(group)` 是 `group_by() + summarise(n = n())` 的快捷写法。

## 4. 宽长表转换（tidyr）

```r
# 宽 → 长
df_long <- df_wide |> pivot_longer(cols = starts_with("treat"),
                                   names_to = "treatment",
                                   values_to = "response")

# 长 → 宽
df_wide <- df_long |> pivot_wider(names_from = treatment, values_from = response)

# 一列拆多列 / 多列合一
df |> separate(col = code, into = c("site", "year"), sep = "-", convert = TRUE)
df |> unite(col = "id", site, year, sep = "_", remove = FALSE)

# 缺失值处理
df |> drop_na(value)
df |> fill(group, .direction = "down")
df |> replace_na(list(value = 0))
```

> `reshape2::melt()/dcast()` 仍可用但已停止更新，新代码用 `tidyr`。

## 5. 多表连接

```r
inner_join(a, b, by = "id")
left_join(a, b, by = c("site" = "site_code"))     # 列名不同
full_join(a, b, by = "id")
anti_join(a, b, by = "id")                        # 找出 a 中 b 没有的
semi_join(a, b, by = "id")                        # 只保留匹配上的
```

连接后**必须查行数变化**：`nrow()` 膨胀说明键不唯一，会产生笛卡尔积。

## 6. 字符串与日期

```r
stringr::str_detect(x, "^A")      # 匹配
stringr::str_replace(x, "-", "_")
stringr::str_trim(x)
stringr::str_pad(x, 3, pad = "0")
forcats::fct_reorder(grp, value)  # 按数值重排因子
forcats::fct_lump(grp, n = 6)     # 长尾合并为 Other

lubridate::ymd("2024-01-05")
lubridate::floor_date(date, "month")   # 按月聚合
lubridate::wday(date, label = TRUE, week_start = 1)
as.numeric(difftime(d2, d1, units = "days"))
```

## 7. data.table（大数据）

```r
library(data.table)
dt <- fread("data/big.csv")
dt[group == "A" & value > 0,                       # i：行筛选
   .(mean = mean(value), n = .N),                  # j：聚合
   by = .(site, year)]                             # by：分组

setkey(dt, id)
dt[lookup, on = "id", nomatch = 0]                 # 键连接
dt[, ratio := value / total]                       # 引用式新增列（原地，无拷贝）
```

语法记忆：`DT[i, j, by]` —— 先选行，再算列，最后分组。

## 8. 缺失值与异常值

| 情况 | 处理 | 注意 |
|---|---|---|
| 缺失 < 5% 且随机 | 删除（`drop_na`）或中位数/众数填补 | 必须报告删除比例 |
| 缺失较多或有结构 | 多重插补 `mice::mice()`，或模型内建处理 | 单值插补会低估方差 |
| 分类变量缺失 | 单列 "Unknown" 水平 | 不要静默并入其他水平 |
| 离群点 | 先确认是否为录入错误 | 真值不要随意删；可用稳健方法（Wilcoxon、稳健回归） |
| 量纲差异大 | 标准化 `scale()` 或 `min-max` | 聚类/PCA/平行坐标必做 |

**异常值判定**：箱线图 1.5×IQR、`z-score > 3`、`boxplot.stats()$out`、马氏距离（多变量）。

## 9. 输出

```r
readr::write_csv(df_clean, "data/clean.csv", na = "")
writexl::write_xlsx(list(raw = df, clean = df_clean), "output/tables/data.xlsx")
saveRDS(df_clean, "data/clean.rds")     # R 内部复用，保留类型
```

## 10. 常见坑

| 现象 | 原因 | 修法 |
|---|---|---|
| `summarise()` 后每组多行 | 忘了 `.groups = "drop"` | 显式写 `.groups` |
| 连接后行数翻倍 | 连接键不唯一 | `distinct()` 去重或改用复合键 |
| `pivot_longer` 后全是字符型 | 列类型不一致 | `names_transform` / `values_transform` 指定类型 |
| 因子水平顺序乱 | 默认按字母序 | `factor(x, levels = 自定义)` |
| 中文列名报错 | 非 ASCII 名称 | 用反引号 `` `列名` `` 或改英文名 |
| `NA` 被当作字符串 | 原始数据写了 "NA"/"-" | 读取时 `na = c("", "NA", "-", "null")` |
