#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# chart-gallery.R — 图表画廊自检：一键渲染 10 张代表性进阶图表
#
# 用法：
#   Rscript examples/chart-gallery.R                 # 输出到 ./gallery_output/
#   Rscript examples/chart-gallery.R <输出目录>       # 指定输出目录
#
# 设计目标：
#   * 无 ggplot2 时给出清晰提示并跳过，不报错崩溃；
#   * 有扩展包用扩展包，没有则用零依赖写法，逐张报告"已渲染 / 已跳过"；
#   * 所有图均为合成数据，不读用户数据；
#   * 退出码 0 = 脚本本身执行正常（个别图因缺包跳过不算失败）。
# ---------------------------------------------------------------------------

outdir <- if (length(commandArgs(trailingOnly = TRUE)) >= 1) {
  commandArgs(trailingOnly = TRUE)[1]
} else "gallery_output"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
# 目录不可写时（只读挂载 / 沙箱）退回临时目录，否则后面 png() 会逐张失败
if (!dir.exists(outdir) || file.access(outdir, 2) != 0) {
  outdir <- file.path(tempdir(), "gallery_output")
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  cat(sprintf("注意：指定目录不可写，产物改写到 %s\n", outdir))
}

n_ok <- 0L; n_skip <- 0L
ok <- function(name, note) { n_ok <<- n_ok + 1L; cat(sprintf("  [OK]   %-16s %s\n", name, note)) }
skip <- function(name, why) { n_skip <<- n_skip + 1L; cat(sprintf("  [SKIP] %-16s %s\n", name, why)) }

has_pkg <- function(p) requireNamespace(p, quietly = TRUE)
png_dev <- function(name, w, h) {
  f <- file.path(outdir, paste0(name, ".png"))
  ok_cairo <- getOption("cairo") %||% FALSE
  if (ok_cairo) png(f, w, h, units = "in", res = 150, type = "cairo")
  else png(f, w, h, units = "in", res = 150)
  f
}
`%||%` <- function(a, b) if (is.null(a)) b else a

draw_wrap <- function(name, w = 5.5, h = 4, expr) {
  r <- try({
    f <- png_dev(name, w, h)
    on.exit(dev.off(), add = TRUE)
    eval(expr)
  }, silent = TRUE)
  if (inherits(r, "try-error"))
    skip(name, conditionMessage(attr(r, "condition")))
  else
    ok(name, file.path(basename(outdir), paste0(name, ".png")))
}

if (!has_pkg("ggplot2")) {
  cat("本脚本用于演示 ggplot2 进阶图表；当前环境无 ggplot2，全部跳过。\n")
  cat("先运行: Rscript scripts/check_env.R --install --optional\n")
  for (nm in c("raincloud", "sig_bracket", "slope", "cleveland", "marimekko",
               "waffle", "streamgraph", "grid_map", "ridges", "sunburst")) skip(nm, "缺 ggplot2")
  cat("跳过不代表环境故障；安装 ggplot2 后重跑即可。\n")
  quit(save = "no", status = 0)
}
suppressPackageStartupMessages(library(ggplot2))
set.seed(2026)

## 合成数据 ---------------------------------------------------------------
n <- 90
df <- data.frame(
  group = factor(rep(c("对照", "低剂量", "高剂量"), each = n), levels = c("对照", "低剂量", "高剂量")),
  value = c(rnorm(n, 10, 2), rnorm(n, 12, 2.6), rnorm(n, 15, 3.2))
)
cat("开始渲染（输出目录:", outdir, "）\n")

## 1. 云雨图（零扩展依赖）--------------------------------------------------
draw_wrap("raincloud", 5, 4, {
  half_violin <- function(data, g, v, width = 0.42) {
    lv <- levels(factor(data[[g]]))
    poly <- do.call(rbind, lapply(seq_along(lv), function(i) {
      d <- density(data[[v]][data[[g]] == lv[i]], n = 512)
      data.frame(g = lv[i], x = i + d$y / max(d$y) * width, y = d$x)
    }))
    poly$g <- factor(poly$g, levels = lv); poly
  }
  poly <- half_violin(df, "group", "value")
  df$pos <- as.numeric(df$group); poly$pos <- as.numeric(poly$g)
  print(
    ggplot(df, aes(x = pos, y = value)) +
      geom_polygon(data = poly, aes(x = pos + (x - pos), y = y, fill = g, group = g),
                   alpha = .55, colour = NA) +
      geom_boxplot(aes(group = group, fill = group), width = .1, outlier.shape = NA,
                   position = position_nudge(x = -.18)) +
      geom_point(aes(colour = group), position = position_jitter(width = .05),
                 size = 1.1, alpha = .5) +
      scale_x_continuous(breaks = 1:3, labels = levels(df$group)) +
      scale_fill_brewer(palette = "Set2") + scale_colour_brewer(palette = "Set2") +
      labs(x = NULL, y = "响应值 (mg/L)", title = "云雨图") +
      theme_classic() + theme(legend.position = "none")
  )
})

## 2. 显著性括号箱形图 ------------------------------------------------------
draw_wrap("sig_bracket", 5, 4.2, {
  pr <- combn(levels(df$group), 2, simplify = FALSE)
  pv <- vapply(pr, function(g) t.test(value ~ group, data = subset(df, group %in% g))$p.value, 0)
  star <- ifelse(pv < .001, "***", ifelse(pv < .01, "**", ifelse(pv < .05, "*", "ns")))
  ymax <- max(df$value)
  br <- data.frame(x1 = match(sapply(pr, `[`, 1), levels(df$group)),
                   x2 = match(sapply(pr, `[`, 2), levels(df$group)),
                   y = ymax * (1.02 + seq_along(pv) * .11), lab = star)
  print(
    ggplot(df, aes(group, value)) +
      geom_boxplot(aes(fill = group), width = .55, outlier.shape = NA, alpha = .85) +
      geom_segment(data = br, aes(x = x1, xend = x2, y = y, yend = y), linewidth = .4) +
      geom_text(data = br, aes((x1 + x2) / 2, y + ymax * .015, label = lab), size = 3.2) +
      scale_fill_brewer(palette = "Set2") +
      labs(x = NULL, y = "响应值 (mg/L)", title = "显著性标注") +
      theme_classic() + theme(legend.position = "none")
  )
})

## 3. 坡度图 ---------------------------------------------------------------
draw_wrap("slope", 5, 3.8, {
  yrs <- 2019:2023
  sl <- data.frame(country = c("A", "B", "C", "D"),
                   matrix(c(82, 71, 65, 58, 79, 68, 70, 61, 76, 72, 74, 55,
                            74, 70, 77, 60, 78, 66, 80, 63), nrow = 4), check.names = FALSE)
  names(sl)[-1] <- yrs
  long <- data.frame(country = sl$country, year = rep(yrs, each = 4),
                     value = as.vector(as.matrix(sl[, -1])))
  long$hi <- long$country %in% c("A", "C")
  print(
    ggplot(long, aes(year, value)) +
      geom_line(aes(group = country, colour = hi), linewidth = .8) +
      geom_point(aes(colour = hi), size = 2.4) +
      geom_text(data = subset(long, year == max(year)), aes(label = country, colour = hi),
                hjust = -.35, size = 3.4, show.legend = FALSE) +
      scale_colour_manual(values = c(`TRUE` = "#D73027", `FALSE` = "grey65")) +
      scale_x_continuous(breaks = yrs, expand = expansion(mult = c(.05, .12))) +
      labs(x = NULL, y = "得分", title = "坡度图") +
      theme_classic() + theme(legend.position = "none")
  )
})

## 4. 克利夫兰点图 ---------------------------------------------------------
draw_wrap("cleveland", 4.8, 4.2, {
  d <- data.frame(item = paste0("指标", 1:14),
                  value = c(88, 76, 72, 69, 65, 61, 58, 54, 49, 45, 40, 36, 30, 25))
  print(
    ggplot(d, aes(value, reorder(item, value))) +
      geom_segment(aes(x = 0, xend = value, yend = reorder(item, value)),
                   colour = "grey70", linewidth = .5) +
      geom_point(colour = "#2166AC", size = 2.6) +
      scale_x_continuous(expand = expansion(mult = c(0, .12))) +
      labs(x = "得分", y = NULL, title = "克利夫兰点图") +
      theme_classic()
  )
})

## 5. 不等宽柱形（Marimekko）----------------------------------------------
draw_wrap("marimekko", 5.5, 4, {
  d <- data.frame(seg = c("A", "B", "C"), total = c(500, 300, 200),
                  s1 = c(250, 180, 60), s2 = c(150, 60, 90), s3 = c(100, 60, 50))
  d$share <- d$total / sum(d$total); d$xmax <- cumsum(d$share); d$xmin <- d$xmax - d$share
  long <- rbind(data.frame(seg = d$seg, xmin = d$xmin, xmax = d$xmax, s = "s1", v = d$s1 / d$total),
                data.frame(seg = d$seg, xmin = d$xmin, xmax = d$xmax, s = "s2", v = d$s2 / d$total),
                data.frame(seg = d$seg, xmin = d$xmin, xmax = d$xmax, s = "s3", v = d$s3 / d$total))
  long <- long[order(long$seg, long$s), ]
  long$ymax <- ave(long$v, long$seg, FUN = cumsum); long$ymin <- long$ymax - long$v
  print(
    ggplot(long) +
      geom_rect(aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = s),
                colour = "white", linewidth = .6) +
      scale_fill_brewer(palette = "Blues") + scale_y_continuous(labels = scales::percent) +
      labs(x = "段内占比（宽度=总量）", y = "构成", fill = "系列", title = "不等宽柱形") +
      theme_minimal()
  )
})

## 6. 华夫饼图（零扩展依赖；waffle 包已从 CRAN 归档）-----------------------
draw_wrap("waffle", 4.5, 4.2, {
  d <- data.frame(cat = c("研发", "市场", "运营", "其他"), n = c(42, 27, 18, 13))
  units <- rep(d$cat, d$n)
  waff <- data.frame(cat = units, row = rep(1:10, each = 10)[seq_along(units)],
                     col = rep(1:10, times = 10)[seq_along(units)])
  print(
    ggplot(waff, aes(col, row, fill = cat)) +
      geom_tile(colour = "white", linewidth = 1.2) + coord_equal() +
      scale_fill_brewer(palette = "Set2") +
      labs(title = "100 人团队构成（1 格 = 1 人）") +
      theme_void() + theme(legend.position = "bottom")
  )
})

## 7. 量化波形图（零扩展依赖；ggTimeSeries 包已归档）-----------------------
draw_wrap("streamgraph", 6, 3.6, {
  m <- expand.grid(t = 1:60, s = paste0("S", 1:5))
  m$v <- pmax(0, 5 + sin(m$t / 6 + as.numeric(sub("S", "", m$s))) * 3 + rnorm(nrow(m), 0, .4))
  m <- m[order(m$s, m$t), ]
  m$base <- ave(m$v, m$t, FUN = function(z) c(0, cumsum(z)[-length(z)])) -
            ave(m$v, m$t, FUN = sum) / 2
  m$top <- m$base + m$v
  print(
    ggplot(m, aes(t)) +
      geom_ribbon(aes(ymin = base, ymax = top, fill = s), alpha = .9,
                  colour = "white", linewidth = .2) +
      scale_fill_brewer(palette = "Set2") +
      labs(x = "时间", y = NULL, title = "量化波形图") +
      theme_minimal() + theme(panel.grid.minor = element_blank())
  )
})

## 8. 网格地图（邮标法示意，零扩展依赖）------------------------------------
draw_wrap("grid_map", 5.2, 4, {
  grid <- expand.grid(gx = 1:8, gy = 1:6)
  grid$v <- round(runif(nrow(grid), 0, 100))
  print(
    ggplot(grid) +
      geom_rect(aes(xmin = gx - .46, xmax = gx + .46, ymin = gy - .46, ymax = gy + .46, fill = v),
                colour = "white", linewidth = .8) +
      geom_text(aes(gx, gy, label = v), size = 2.4, colour = "white") +
      scale_fill_gradientn(colours = c("#F7FCF5", "#74C476", "#00441B")) +
      coord_equal() + labs(title = "网格地图（方法示意，非真实边界）") +
      theme_void()
  )
})

## 9. 峰峦图（有 ggridges 用扩展包，没有则跳过）----------------------------
if (has_pkg("ggridges")) {
  draw_wrap("ridges", 5.4, 4, {
    suppressPackageStartupMessages(library(ggridges))
    d <- expand.grid(t = 1:200, g = paste0("组", 1:6))
    d$v <- rnorm(nrow(d), mean = as.numeric(sub("组", "", d$g)) * 1.5, sd = 1.4)
    print(
      ggplot(d, aes(v, g, fill = g)) +
        geom_density_ridges(scale = 2.2, rel_min_height = .01, alpha = .8,
                            quantile_lines = TRUE, quantiles = c(.25, .5, .75)) +
        scale_fill_viridis_d(guide = "none") +
        labs(x = "指标值", y = NULL, title = "峰峦图") +
        theme_ridges(font_size = 10, grid = TRUE)
    )
  })
} else skip("ridges", "缺 ggridges")

## 10. 旭日图（有 ggraph/igraph 用扩展包，没有则跳过）----------------------
if (has_pkg("ggraph") && has_pkg("igraph")) {
  draw_wrap("sunburst", 4.2, 4.2, {
    suppressPackageStartupMessages({library(ggraph); library(igraph)})
    ed <- data.frame(from = c("root", "root", "A", "A", "B", "B"),
                     to = c("A", "B", "A1", "A2", "B1", "B2"))
    g <- graph_from_data_frame(ed)
    V(g)$depth <- as.numeric(distances(g, v = "root")[1, V(g)$name])
    print(
      ggraph(g, layout = "partition", circular = TRUE) +
        geom_node_arc_bar(aes(fill = depth), colour = "white", linewidth = .4) +
        geom_node_text(aes(label = name, filter = depth <= 1), size = 3) +
        coord_fixed() + scale_fill_distiller(palette = "Blues", guide = "none") +
        labs(title = "旭日图") + theme_void()
    )
  })
} else skip("sunburst", "缺 ggraph/igraph")

## 汇总 -------------------------------------------------------------------
cat("\n==== 画廊渲染汇总 ====\n")
cat(sprintf("渲染成功 %d 张，跳过 %d 张。\n", n_ok, n_skip))
cat("跳过 = 缺扩展包，可运行 Rscript scripts/check_env.R --install --optional 补齐；退出码 0 = 脚本执行正常。\n")
quit(save = "no", status = 0)
