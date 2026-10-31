#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# quickstart.R — 一条命令验证整个技能包能否跑通
#
# 用法（在任意目录执行，输出落在当前目录的 output/ 下）：
#   Rscript <技能目录>/examples/quickstart.R
#
# 特点：
#   1) 只依赖 base R，未装 ggplot2 / dplyr 也能完整跑通（内部自动走 base R 回退）；
#   2) 走的是与正式分析完全相同的工具链：summarise_ci() → export_figure() → 表格 + sessionInfo；
#   3) 结束时逐项校验产物（文件存在、体积合理、PNG 头合法），任一失败则以非 0 退出码结束。
#
# 若环境已装 ggplot2，会额外产出 examples 目录下的 ggplot2 版本对照图。
# ---------------------------------------------------------------------------

# --- 定位脚本自身所在目录（不依赖工作目录） --------------------------------
# 注意：Rscript 会把路径里的空格编码成 "~+~"（"R 语言" → "R~+~语言"）。
# 不做还原就 normalizePath，拿到的是不存在的路径，后面 source()/read.csv() 会全部失败。
.this_file <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  m <- grep("^--file=", a, value = TRUE)
  if (length(m)) {
    p <- gsub("~+~", " ", sub("^--file=", "", m[1]), fixed = TRUE)
    return(normalizePath(p, mustWork = FALSE))
  }
  normalizePath(".", mustWork = FALSE)
}
script_dir <- dirname(.this_file())

# 脚本目录定位失败（路径被改写、脚本被内联执行）时逐步兜底，不直接中断
if (!dir.exists(script_dir)) {
  cand <- file.path(getwd(), "examples")
  if (dir.exists(cand)) script_dir <- cand
}
if (!dir.exists(script_dir)) script_dir <- getwd()
skill_dir  <- dirname(script_dir)
assets_dir <- file.path(skill_dir, "assets")
scripts_dir <- file.path(skill_dir, "scripts")

# 当前目录不可写时（沙箱、只读挂载常见）退回临时目录，保证自检能跑完
if (file.access(getwd(), 2) != 0) {
  tmp <- file.path(tempdir(), "quickstart_output")
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  if (dir.exists(tmp)) {
    setwd(tmp)
    cat(sprintf("注意：当前目录不可写，产物已改写到 %s\n", tmp))
  }
}

say <- function(...) cat(sprintf(...), "\n", sep = "")

say("==================================================================")
say(" R 数据分析工作台 · 自检（quickstart）")
say("==================================================================")
say("技能目录 : %s", skill_dir)
say("工作目录 : %s", getwd())
say("R 版本   : %s", R.version.string)

fail <- character(0)
check <- function(label, ok, detail = "") {
  say("  [%s] %-38s %s", if (isTRUE(ok)) "OK" else "!!", label, detail)
  if (!isTRUE(ok)) fail <<- c(fail, label)
  invisible(ok)
}

# --- 1. 载入工具脚本 -------------------------------------------------------
say("\n[1] 载入技能脚本")
for (f in c("theme_academic.R", "export_figure.R", "stats-utils.R")) {
  p <- file.path(scripts_dir, f)
  ok <- tryCatch({ suppressMessages(source(p)); TRUE },
                 error = function(e) { say("      载入失败：%s", conditionMessage(e)); FALSE })
  check(paste("source", f), ok)
}

# --- 2. 读取示例数据 -------------------------------------------------------
say("\n[2] 读取示例数据")
csv <- file.path(assets_dir, "sample-data.csv")
check("示例数据存在", file.exists(csv), csv)

df <- utils::read.csv(csv, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
df$group <- factor(df$group, levels = c("Control", "Treat_A", "Treat_B"))
say("      维度：%d 行 × %d 列", nrow(df), ncol(df))
check("行数 ≥ 60", nrow(df) >= 60, sprintf("n = %d", nrow(df)))
check("分组水平 = 3", nlevels(df$group) == 3, paste(levels(df$group), collapse = " / "))

na_tab <- vapply(df, function(x) sum(is.na(x)), integer(1))
say("      缺失值：%s", paste(sprintf("%s=%d", names(na_tab)[na_tab > 0],
                                      na_tab[na_tab > 0]), collapse = ", "))
check("缺失值已如实统计", sum(na_tab) > 0, sprintf("共 %d 个", sum(na_tab)))

# --- 3. 分组汇总 + 置信区间 ------------------------------------------------
say("\n[3] 分组汇总（summarise_ci）")
agg <- summarise_ci(df, "response", "group", conf = 0.95)
print(agg, digits = 3, row.names = FALSE)
check("汇总列完整", all(c("n", "mean", "se", "ci_lo", "ci_hi") %in% names(agg)))
check("置信区间单调", all(agg$ci_lo <= agg$mean & agg$mean <= agg$ci_hi))

# 对照 base R 回退实现：未装 dplyr 的环境走的就是这条路径，必须与 dplyr 版一致
if (exists(".summarise_ci_base", mode = "function")) {
  agg_base <- .summarise_ci_base(df, "response", "group")
  agg_base <- agg_base[order(agg_base$group), ]
  agg_dpl  <- agg[order(agg$group), ]
  same <- isTRUE(all.equal(round(agg_base$mean, 6), round(agg_dpl$mean, 6))) &&
    isTRUE(all.equal(agg_base$n, agg_dpl$n))
  check("base R 回退与 dplyr 结果一致", same)
}

# --- 4. 出图并导出 PNG + PDF ----------------------------------------------
say("\n[4] 绘图与导出（base R 设备链，缺包环境同样可用）")
cols <- c("#0072B2", "#D55E00", "#009E73")[seq_len(nrow(agg))]

draw_bar <- function() {
  op <- graphics::par(mar = c(3.2, 4.2, 2.6, 0.8), mgp = c(2.4, 0.7, 0), las = 1,
                      family = "sans", cex.axis = 0.9)
  on.exit(graphics::par(op), add = TRUE)
  ymax <- max(agg$ci_hi, na.rm = TRUE) * 1.18
  bp <- graphics::barplot(agg$mean, names.arg = agg$group, col = cols, border = NA,
                          ylim = c(0, ymax), ylab = "Response (mg/L)",
                          cex.names = 0.95, space = 0.55)
  graphics::arrows(bp, agg$ci_lo, bp, agg$ci_hi, angle = 90, code = 3,
                   length = 0.06, lwd = 1.1, col = "grey20")
  graphics::abline(h = 0, col = "grey40", lwd = 0.8)
  graphics::title(main = "Group mean with 95% CI", adj = 0,
                  cex.main = 1.05, font.main = 2)
  graphics::text(bp, agg$ci_hi, sprintf("n=%d", agg$n), pos = 3, cex = 0.75,
                 col = "grey30", xpd = NA)
}

made <- export_figure(draw_bar, "fig01_group_mean_ci", use = "journal")
check("PNG 已生成", any(grepl("\\.png$", made)))
check("PDF 已生成", any(grepl("\\.pdf$", made)))

# 第二张图：分布（箱线图），验证多次导出互不干扰
draw_box <- function() {
  op <- graphics::par(mar = c(3.2, 4.2, 2.6, 0.8), mgp = c(2.4, 0.7, 0), las = 1,
                      cex.axis = 0.9)
  on.exit(graphics::par(op), add = TRUE)
  graphics::boxplot(response ~ group, data = df, col = grDevices::adjustcolor(cols, 0.35),
                    border = "grey25", outline = FALSE, ylab = "Response (mg/L)",
                    xlab = "", main = "Distribution by group", adj = 0,
                    cex.main = 1.05, font.main = 2)
  graphics::stripchart(response ~ group, data = df, vertical = TRUE, method = "jitter",
                       pch = 19, cex = 0.55, col = grDevices::adjustcolor("grey20", 0.45),
                       add = TRUE, jitter = 0.12)
}
made2 <- export_figure(draw_box, "fig02_group_distribution", use = "journal")
check("第二张图已生成", length(made2) >= 1)

# --- 5. 结果表 + 会话信息 --------------------------------------------------
say("\n[5] 结果表与会话信息")
tbl <- export_table(agg, "tbl01_group_summary")
check("结果表已写出", file.exists(tbl), basename(tbl))
si <- save_session_info()
check("sessionInfo 已写出", file.exists(si), basename(si))

# --- 6. 产物校验 ----------------------------------------------------------
say("\n[6] 产物校验")
# 阈值按格式分档：位图 > 5KB，矢量 PDF/SVG > 1KB（矢量文件体积本来就小），文本 > 100 字节
.size_threshold <- function(f) {
  ext <- tolower(tools::file_ext(f))
  if (ext %in% c("png", "tif", "tiff", "jpg", "jpeg")) return(5 * 1024)
  if (ext %in% c("pdf", "svg")) return(1024)
  100
}
for (f in c(made, made2)) {
  sz <- file.info(f)$size
  check(sprintf("%s 体积合理", basename(f)), !is.na(sz) && sz > .size_threshold(f),
        sprintf("%.1f KB", sz / 1024))
}
for (f in c(tbl, si)) {
  sz <- file.info(f)$size
  check(sprintf("%s 非空", basename(f)), !is.na(sz) && sz > 100,
        sprintf("%.1f KB", sz / 1024))
}
png_files <- grep("\\.png$", c(made, made2), value = TRUE)
for (p in png_files) {
  sig <- readBin(p, "raw", n = 8)
  check(sprintf("%s PNG 文件头合法", basename(p)),
        length(sig) == 8 && identical(sig[1:4], as.raw(c(0x89, 0x50, 0x4e, 0x47))))
}

# --- 7. 可选：ggplot2 版本对照 --------------------------------------------
say("\n[7] ggplot2 增强路径（可选）")
if (requireNamespace("ggplot2", quietly = TRUE)) {
  p <- ggplot2::ggplot(agg, ggplot2::aes(group, mean, fill = group)) +
    ggplot2::geom_col(width = 0.6, alpha = 0.9) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = ci_lo, ymax = ci_hi),
                           width = 0.12, linewidth = 0.4) +
    scale_fill_wb("okabe") +
    ggplot2::labs(x = NULL, y = "Response (mg/L)",
                  title = "Group mean with 95% CI", fill = "Group") +
    theme_academic()
  m3 <- export_figure(p, "fig03_group_mean_ci_ggplot", use = "journal")
  check("ggplot2 版本已导出", length(m3) >= 1, paste(basename(m3), collapse = ", "))
} else {
  say("  [--] 未安装 ggplot2，跳过（base R 路径已完整验证，不影响结论）")
}

# --- 8. 结论 --------------------------------------------------------------
say("\n==================================================================")
if (!length(fail)) {
  say(" 结果：全部通过")
  say(" 产物目录：%s", normalizePath(file.path(getwd(), "output"), mustWork = FALSE))
  say("   ├─ figures/  %s", paste(basename(c(made, made2)), collapse = ", "))
  say("   └─ tables/   %s", basename(tbl))
  say(" 下一步：把 %s 换成你的数据文件，按同样流程即可。",
      "assets/sample-data.csv")
  say("==================================================================")
  quit(status = 0)
} else {
  say(" 结果：%d 项未通过", length(fail))
  say(" 失败项：%s", paste(fail, collapse = "; "))
  say(" 排查建议：见 references/environment-and-troubleshooting.md")
  say("==================================================================")
  quit(status = 1)
}
