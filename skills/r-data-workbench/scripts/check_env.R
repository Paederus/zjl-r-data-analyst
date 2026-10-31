#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# check_env.R — R 分析与绘图环境自检（针对中国大陆网络优化）
#
# 用法：
#   Rscript check_env.R                          # 仅检查（不联网、不改动文件）
#   Rscript check_env.R --list-mirrors           # 列出国内镜像的延迟与二进制支持
#   Rscript check_env.R --install                # 装缺失必需包（自动选最快国内镜像）
#   Rscript check_env.R --install --optional     # 连可选扩展包一起装
#   Rscript check_env.R --install --only=ggrepel,patchwork   # 只装指定包
#   Rscript check_env.R --install --binary       # 强制二进制，免编译（macOS/Windows）
#   Rscript check_env.R --install --source       # 强制源码编译（Linux 默认）
#   Rscript check_env.R --install --jobs=4       # 并行编译进程数
#   Rscript check_env.R --install --proxy=http://127.0.0.1:7890   # 走本地代理
#   Rscript check_env.R --install --save         # 把最优镜像永久写入 ~/.Rprofile
#   Rscript check_env.R --install --lib=<目录>   # 指定安装目标库
#   Rscript check_env.R --install --verbose      # 显示 R 的完整安装输出（排查用）
#
# 镜像选择优先级：
#   --mirror=<URL>  >  环境变量 CRAN_MIRROR  >  自动测速（默认，仅安装时联网）
# 自动测速会并发探测国内镜像，选响应最快且可用的一个；单个镜像安装失败时
# 自动换下一个镜像重试，最后才回落到手动下载指引。
#
# 安装目标库：--lib= 指定 > 第一个可写库 > 用户库（R_LIBS_USER，含 %v/%p 展开）
# ---------------------------------------------------------------------------

# R < 4.4 的 base 没有 %||%，这里自备一份，保证脚本在旧版 R 上也能跑
if (!exists("%||%", envir = baseenv())) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

args <- commandArgs(trailingOnly = TRUE)
do_inst    <- "--install"    %in% args
inst_opt   <- "--optional"   %in% args
list_mir   <- "--list-mirrors" %in% args
do_save    <- "--save"       %in% args
do_verbose <- "--verbose"    %in% args
force_bin  <- "--binary"     %in% args
force_src  <- "--source"     %in% args

get_arg <- function(key) {
  v <- grep(paste0("^--", key, "="), args, value = TRUE)
  if (length(v)) sub(paste0("^--", key, "="), "", v[1]) else NULL
}

only_arg   <- get_arg("only")
mirror_arg <- get_arg("mirror")
lib_arg    <- get_arg("lib")
jobs_arg   <- get_arg("jobs")
proxy_arg  <- get_arg("proxy")

# 国内网络常见问题：默认 60 秒超时对大包不够；libcurl 支持 HTTPS 且能断点续传
if (do_inst) {
  options(timeout = max(600, getOption("timeout") %||% 60))
  options(download.file.method = "libcurl")
}

# --- 代理（国内常见：本地 HTTP 代理） --------------------------------------
if (!is.null(proxy_arg) && nzchar(proxy_arg)) {
  Sys.setenv(http_proxy = proxy_arg, https_proxy = proxy_arg)
  options(download.file.method = "libcurl")
  cat("已设置代理:", proxy_arg, "\n")
}

# --- 镜像清单（均为中国大陆可直接访问的 CRAN 镜像） ------------------------
mirror_catalog <- list(
  list(name = "清华 TUNA",   url = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"),
  list(name = "中科大 USTC", url = "https://mirrors.ustc.edu.cn/CRAN/"),
  list(name = "北外 BFSU",   url = "https://mirrors.bfsu.edu.cn/CRAN/"),
  list(name = "阿里云",      url = "https://mirrors.aliyun.com/CRAN/"),
  list(name = "南京大学",    url = "https://mirrors.nju.edu.cn/CRAN/"),
  list(name = "上海交大",    url = "https://mirror.sjtu.edu.cn/CRAN/"),
  list(name = "腾讯云",      url = "https://mirrors.cloud.tencent.com/CRAN/"),
  list(name = "CRAN 官方",   url = "https://cloud.r-project.org/")
)
cat_names <- vapply(mirror_catalog, `[[`, character(1), "name")
cat_urls  <- vapply(mirror_catalog, `[[`, character(1), "url")

ver_dir <- paste0(R.version$major, ".", sub("\\..*$", "", R.version$minor))
is_mac  <- grepl("darwin", R.version$platform)
is_win  <- .Platform$OS.type == "windows"

# 当前平台可能的二进制包索引路径
bin_paths <- function() {
  if (is_win) {
    return(paste0("bin/windows/contrib/", ver_dir, "/PACKAGES"))
  }
  if (is_mac) {
    p <- character(0)
    if (grepl("aarch64|arm64", R.version$platform)) {
      p <- c(p, paste0("bin/macosx/big-sur-arm64/contrib/", ver_dir, "/PACKAGES"))
    }
    p <- c(p, paste0("bin/macosx/contrib/", ver_dir, "/PACKAGES"))
    return(p)
  }
  character(0)   # Linux 一般无二进制源
}

# 探测单个 URL：读前 4KB，校验内容确实是 CRAN 的 PACKAGES 索引（排除 404 页面）
# 只依赖 base R 的连接，不调用 curl 命令，避免 shell 引号与平台差异
probe_url <- function(url, timeout = 4) {
  t0 <- proc.time()[["elapsed"]]
  ok <- FALSE
  con <- NULL
  old <- options(timeout = timeout)
  on.exit({ options(old); if (!is.null(con)) try(close(con), silent = TRUE) }, add = TRUE)
  ok <- tryCatch({
    con <- base::url(url, open = "rb")
    raw <- readBin(con, "raw", 4096)
    length(raw) > 0 &&
      length(grepRaw(charToRaw("Package:"), raw, all = FALSE)) > 0
  }, error = function(e) FALSE, warning = function(w) FALSE)
  list(code = if (isTRUE(ok)) 200L else NA_integer_,
       sec  = proc.time()[["elapsed"]] - t0)
}

# 探测全部镜像：返回 name/url/code/sec/bin（bin 为该镜像是否有所需二进制）
probe_mirrors <- function(timeout = 4, with_bin = TRUE) {
  rows <- lapply(seq_along(cat_urls), function(i) {
    r <- probe_url(paste0(cat_urls[i], "src/contrib/PACKAGES"), timeout)
    bin <- NA
    if (with_bin && isTRUE(r$code == 200L)) {
      bp <- bin_paths()
      bin <- if (length(bp)) {
        any(vapply(paste0(cat_urls[i], bp), function(u)
          isTRUE(probe_url(u, timeout)$code == 200L), logical(1)))
      } else {
        FALSE
      }
    }
    data.frame(name = cat_names[i], url = cat_urls[i],
               code = r$code, sec = r$sec, bin = bin,
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

print_mirror_table <- function(tab) {
  # 中文字符在终端占两列，按显示宽度补齐，避免表格错位
  disp_w <- function(s) nchar(s) + sum(grepl("[\u4e00-\u9fff]", strsplit(s, "")[[1]]))
  pad <- function(s, w) paste0(s, strrep(" ", max(0, w - disp_w(s))))
  cat("\n  镜像          响应     源码  二进制\n")
  for (i in seq_len(nrow(tab))) {
    ok  <- isTRUE(tab$code[i] == 200L)
    bin <- if (is.na(tab$bin[i])) "-" else if (isTRUE(tab$bin[i])) "支持" else "无"
    cat(sprintf("  %s %7s  %-4s  %s\n",
                pad(tab$name[i], 12),
                if (is.na(tab$sec[i])) "超时" else sprintf("%.2fs", tab$sec[i]),
                if (ok) "OK" else "不通",
                bin))
  }
  cat("\n")
}

# --- 确定使用的镜像 --------------------------------------------------------
env_mirror <- Sys.getenv("CRAN_MIRROR")
mirror <- NULL
mirror_source <- ""

if (!is.null(mirror_arg) && nzchar(mirror_arg)) {
  mirror <- mirror_arg
  mirror_source <- "命令行指定"
} else if (nzchar(env_mirror)) {
  mirror <- env_mirror
  mirror_source <- "环境变量 CRAN_MIRROR"
}

# 只探测一次，列表展示与自动选择共用结果
probe_tab <- NULL
if (list_mir || ((do_inst || do_save) && is.null(mirror))) {
  if (list_mir) {
    cat("\n================ 国内 CRAN 镜像测速 ================\n")
    cat("（读 2KB 校验索引；二进制列表示能否免编译安装）\n")
  } else {
    cat("正在测速选择最优镜像 ...\n")
  }
  probe_tab <- probe_mirrors(timeout = 4)
  if (list_mir) print_mirror_table(probe_tab)
}

if ((do_inst || do_save) && is.null(mirror)) {
  good <- probe_tab[!is.na(probe_tab$code) & probe_tab$code == 200L, , drop = FALSE]
  if (nrow(good)) {
    # 国内镜像优先：官方源即使探测略快，大包吞吐往往差很多，给它加 0.35s 惩罚
    good$key <- good$sec + ifelse(good$name == "CRAN 官方", 0.35, 0)
    good <- good[order(good$key), , drop = FALSE]
    mirror <- good$url[1]
    mirror_source <- sprintf("自动测速（%s，%.2fs）", good$name[1], good$sec[1])
  } else {
    mirror <- cat_urls[1]
    mirror_source <- "全部镜像不可达，回退到清华 TUNA"
    cat("  !! 所有镜像均无响应，请检查网络/代理；仍将以默认镜像尝试。\n")
  }
}

if (is.null(mirror)) {   # 纯检查模式：不联网，用默认镜像展示
  mirror <- cat_urls[1]
  mirror_source <- "默认（未联网测速）"
}

# 安装类型：macOS/Windows 优先二进制（免编译），Linux 只能源码
inst_type <- if (force_src) {
  "source"
} else if (force_bin) {
  "binary"
} else if (is_mac || is_win) {
  "both"
} else {
  "source"
}

# --- 安装目标库 ------------------------------------------------------------
expand_lib <- function(p) {
  if (!nzchar(p)) return("")
  v <- paste(R.version$major, sub("\\..*$", "", R.version$minor), sep = ".")
  p <- gsub("%v", v, p, fixed = TRUE)
  p <- gsub("%p", R.version$platform, p, fixed = TRUE)
  gsub("^~", path.expand("~"), p)
}
user_lib <- expand_lib(Sys.getenv("R_LIBS_USER"))
if (!nzchar(user_lib)) user_lib <- path.expand("~/R/library")
if (!user_lib %in% .libPaths()) .libPaths(c(user_lib, .libPaths()))

choose_lib <- function() {
  if (!is.null(lib_arg) && nzchar(lib_arg)) {
    return(normalizePath(expand_lib(lib_arg), mustWork = FALSE))
  }
  libs <- .libPaths()
  writable <- libs[file.access(libs, 2) == 0]
  if (length(writable)) return(writable[1])
  user_lib
}
inst_lib <- choose_lib()
if (do_inst) {
  dir.create(inst_lib, recursive = TRUE, showWarnings = FALSE)
  if (!inst_lib %in% .libPaths()) .libPaths(c(inst_lib, .libPaths()))
}

# --- 报告头 ----------------------------------------------------------------
cat("\n================ R 环境自检 ================\n")
cat("R 版本      :", R.version.string, "\n")
cat("平台        :", R.version$platform, "\n")
cat("用户库路径  :", paste(.libPaths()[1], collapse = ""), "\n")
cat("CRAN 镜像   :", mirror, "\n")
cat("镜像来源    :", mirror_source, "\n")
if (do_inst) {
  cat("安装目标库  :", inst_lib,
      if (file.access(inst_lib, 2) == 0) "(可写)" else "(不可写!)", "\n")
  cat("安装类型    :", switch(inst_type,
      binary = "binary（二进制，免编译）",
      source = "source（源码编译）",
      both   = "both（有二进制用二进制，否则源码）"), "\n")
  cat("下载超时    :", getOption("timeout"), "秒\n")
}

# --- 1. 图形设备能力（真实冒烟测试，不信任 capabilities()） ----------------
cat("\n[1] 图形设备冒烟测试\n")
smoke <- function(label, open_fun) {
  f <- tempfile(fileext = paste0(".", attr(open_fun, "ext")))
  ok <- tryCatch({
    suppressWarnings(open_fun(f))
    par(mar = c(2, 2, 1, 1))
    plot.new(); points(0.5, 0.5)
    grDevices::dev.off()
    file.exists(f) && file.size(f) > 0
  }, error = function(e) {
    if (grDevices::dev.cur() != 1) try(grDevices::dev.off(), silent = TRUE)
    FALSE
  })
  if (file.exists(f)) unlink(f)
  cat(sprintf("    %-12s %s\n", label, ifelse(ok, "OK", "不可用")))
  invisible(ok)
}
png_dev <- function(f) grDevices::png(f, width = 400, height = 400)
attr(png_dev, "ext") <- "png"
pdf_dev <- function(f) grDevices::pdf(f, width = 4, height = 4)
attr(pdf_dev, "ext") <- "pdf"
cairo_dev <- function(f) grDevices::cairo_pdf(f, width = 4, height = 4)
attr(cairo_dev, "ext") <- "pdf"
ragg_ok <- requireNamespace("ragg", quietly = TRUE)
smoke("png", png_dev)
smoke("pdf", pdf_dev)
smoke("cairo_pdf", cairo_dev)
if (ragg_ok) {
  ragg_dev <- function(f) ragg::agg_png(f, width = 400, height = 400)
  attr(ragg_dev, "ext") <- "png"
  smoke("ragg_png", ragg_dev)
}

# --- 2. 依赖包 -------------------------------------------------------------
required <- c("ggplot2", "dplyr", "tidyr", "readr", "stringr", "forcats",
              "scales", "tibble", "purrr")
optional <- c("patchwork", "cowplot", "ggrepel", "ggpubr", "ggsci",
              "showtext", "systemfonts", "ragg", "svglite", "viridisLite",
              "RColorBrewer", "broom", "modelsummary", "car", "lme4",
              "factoextra", "forecast", "writexl", "readxl", "here",
              # 缺失数据诊断与多重插补
              "mice", "VIM", "naniar",
              # 重抽样与自助法
              "coin", "boot",
              # 探索性因子分析 / 心理测量
              "psych",
              # 监督分类（决策树、随机森林、支持向量机）
              "rpart", "rpart.plot", "party", "partykit",
              "randomForest", "e1071", "kernlab", "caret", "pROC",
              # 稳健与混合效应生态
              "effectsize", "performance", "emmeans")

check <- function(pkgs, label) {
  cat(sprintf("\n[%s]\n", label))
  missing <- character(0)
  for (p in pkgs) {
    ok <- requireNamespace(p, quietly = TRUE)
    ver <- if (ok) as.character(utils::packageVersion(p)) else ""
    cat(sprintf("    %-14s %-8s %s\n", p, ifelse(ok, "OK", "缺失"), ver))
    if (!ok) missing <- c(missing, p)
  }
  missing
}

miss_req <- check(required, "2. 必需包")
miss_opt <- check(optional, "3. 常用扩展包")

# --- 4. 中文字体 -----------------------------------------------------------
cat("\n[4] 中文字体探测\n")
has_sf <- requireNamespace("systemfonts", quietly = TRUE)
if (has_sf) {
  fams <- tryCatch(systemfonts::system_fonts()$family, error = function(e) character(0))
  cand <- c("PingFang SC", "Heiti SC", "Songti SC", "STHeiti", "Hiragino Sans GB",
            "Microsoft YaHei", "SimHei", "SimSun", "Noto Sans CJK SC",
            "Source Han Sans SC", "WenQuanYi Micro Hei")
  hit <- intersect(cand, unique(fams))
  if (length(hit)) {
    cat("    找到中文字体:", paste(hit, collapse = ", "), "\n")
  } else {
    cat("    未找到常见中文字体，导出中文图请显式 font_add() 指定字体文件路径\n")
  }
} else {
  cat("    未安装 systemfonts，跳过字体探测\n")
}

# --- 手动安装指引（自动安装全部镜像失败时逐包打印） ----------------------
manual_hint <- function(p, repos) {
  cat(sprintf("      · %s\n", p))
  cat(sprintf("        包主页  : https://cran.r-project.org/package=%s\n", p))
  cat(sprintf("        源码包  : %ssrc/contrib/%s_<最新版本>.tar.gz\n", repos, p))
  if (is_mac) {
    cat(sprintf("        mac 二进制: %sbin/macosx/%scontrib/%s/%s_<版本>.tgz\n",
                repos, if (grepl("aarch64|arm64", R.version$platform)) "big-sur-arm64/" else "",
                ver_dir, p))
  } else if (is_win) {
    cat(sprintf("        Win 二进制: %sbin/windows/contrib/%s/%s_<版本>.zip\n", repos, ver_dir, p))
  }
  cat(sprintf("        本地安装: install.packages('<下载路径>', repos = NULL, type = '%s')\n",
              if (is_win) "win.binary" else if (is_mac) "mac.binary" else "source"))
}

# --- 5. 安装缺失包 ---------------------------------------------------------
# --only 可指定任意包名（不限于上面的清单），已装的自动跳过
only_pkgs <- character(0)
if (!is.null(only_arg) && nzchar(only_arg)) {
  only_pkgs <- trimws(strsplit(only_arg, ",")[[1]])
  only_pkgs <- only_pkgs[nzchar(only_pkgs)]
}

to_inst <- if (do_inst) c(miss_req, if (inst_opt) miss_opt) else character(0)
if (length(only_pkgs) && do_inst) {
  to_inst <- only_pkgs[!vapply(only_pkgs, requireNamespace, logical(1), quietly = TRUE)]
  miss_req <- intersect(miss_req, only_pkgs)
  miss_opt <- intersect(miss_opt, only_pkgs)
}

if (length(miss_req) && !do_inst) {
  cat(sprintf('\n[5] 缺失必需包（未带 --install，仅给出命令）\n'))
  cat(sprintf('    install.packages(c("%s"), repos = "%s")\n',
              paste(miss_req, collapse = '", "'), mirror))
  cat('    一键安装 : Rscript check_env.R --install          # 自动测速选镜像\n')
  cat('    连可选包 : 上述命令再加 --optional\n')
  cat('    免编译   : 加 --binary（macOS/Windows）\n')
  cat('    看镜像   : Rscript check_env.R --list-mirrors\n')
}

if (do_inst && length(to_inst)) {
  ncpu <- if (!is.null(jobs_arg) && nzchar(jobs_arg)) {
    suppressWarnings(as.integer(jobs_arg))
  } else if (inst_type != "binary") {
    min(8L, max(1L, parallel::detectCores() - 1L))
  } else 1L
  if (!is.na(ncpu) && ncpu > 1) options(Ncpus = ncpu)

  # 备选镜像链：主镜像优先，其后按测速结果（或清单顺序）排列
  others <- if (!is.null(probe_tab)) {
    g <- probe_tab[!is.na(probe_tab$code) & probe_tab$code == 200L, , drop = FALSE]
    g$key <- g$sec + ifelse(g$name == "CRAN 官方", 0.35, 0)
    g <- g[order(g$key), , drop = FALSE]
    g$url[g$url != mirror]
  } else {
    setdiff(cat_urls, mirror)
  }
  try_list <- utils::head(c(mirror, others), 4)

  cat(sprintf("\n[5] 自动安装缺失包（共 %d 个）\n", length(to_inst)))
  cat("    待安装:", paste(to_inst, collapse = ", "), "\n")
  if (!is.na(ncpu) && ncpu > 1) cat("    并行编译:", ncpu, "进程\n")

  remaining <- to_inst
  for (i in seq_along(try_list)) {
    m <- try_list[[i]]
    if (!length(remaining)) break
    cat(sprintf("\n    --- 镜像 %d/%d: %s\n", i, length(try_list), m))
    t0 <- Sys.time()
    suppressWarnings(utils::install.packages(
      remaining, lib = inst_lib, repos = m,
      type = inst_type, quiet = !do_verbose))
    remaining <- remaining[!vapply(remaining, requireNamespace, logical(1),
                                   quietly = TRUE)]
    dt <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
    cat(sprintf("        用时 %.1fs，剩余未装 %d 个\n", dt, length(remaining)))
  }

  ok_pkgs <- setdiff(to_inst, remaining)
  if (length(ok_pkgs)) {
    cat(sprintf("\n    安装成功 %d 个: %s\n", length(ok_pkgs),
                paste(ok_pkgs, collapse = ", ")))
  }

  if (length(remaining)) {
    cat(sprintf("\n    仍有 %d 个未装上: %s\n", length(remaining),
                paste(remaining, collapse = ", ")))
    cat("\n    手动下载安装（按顺序尝试）：\n")
    for (p in utils::head(remaining, 8)) manual_hint(p, mirror)
    cat("\n    排查建议：\n")
    cat('      · 换镜像重装 : Rscript check_env.R --install --mirror=https://mirrors.bfsu.edu.cn/CRAN/\n')
    cat('      · 看哪个镜像快 : Rscript check_env.R --list-mirrors\n')
    cat('      · 走本地代理 : 加 --proxy=http://127.0.0.1:7890（Clash/V2Ray 等默认端口）\n')
    cat('      · 强制免编译 : 加 --binary（macOS/Windows 有二进制，可绕开缺系统库的编译错误）\n')
    cat('      · 用户库无权限 : 加 --lib=<目录>，如\n')
    cat(sprintf('        --lib="%s"\n', user_lib))
    cat('      · 完全离线 : 在能上网的机器上下载 .tar.gz/.tgz，拷贝后\n')
    cat('        install.packages(list.files("<目录>", full.names = TRUE), repos = NULL, type = "source")\n')
  }
}

# --- 6. 结论（安装后重新核对，避免用过期清单下结论） ----------------------
if (do_inst && length(to_inst)) {
  miss_req <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (inst_opt) {
    miss_opt <- optional[!vapply(optional, requireNamespace, logical(1), quietly = TRUE)]
  }
}

cat("\n================ 结论 ================\n")
if (!length(miss_req)) {
  cat("核心依赖齐全，可以直接开始分析与绘图。\n")
} else {
  cat("缺少必需包:", paste(miss_req, collapse = ", "), "\n")
  cat("一键安装: Rscript check_env.R --install    # 自动测速选最快国内镜像\n")
  cat("提示：装不上时改用 base R 绘图（barplot/plot/boxplot）作为降级方案，并向用户说明。\n")
}
if (length(miss_opt)) {
  cat("\n可选扩展包缺失（按需安装，--install 时加 --optional 一起装）:",
      paste(miss_opt, collapse = ", "), "\n")
}

# --- 7. 永久写入镜像配置（可选） ------------------------------------------
if (do_save) {
  rp <- path.expand("~/.Rprofile")
  marker_begin <- "## >>> r-data-workbench: CRAN 镜像 >>>"
  marker_end   <- "## <<< r-data-workbench <<<"
  block <- c(marker_begin,
             sprintf('options(repos = c(CRAN = "%s"))', mirror),
             'options(timeout = 600)        # 大包下载超时放宽',
             'options(download.file.method = "libcurl")',
             marker_end)
  old <- if (file.exists(rp)) readLines(rp, warn = FALSE) else character(0)
  if (any(old == marker_begin)) {
    s <- match(marker_begin, old); e <- match(marker_end, old)
    if (!is.na(s) && !is.na(e) && e > s) old <- old[-c(s:e)]
  }
  if (length(old) && nzchar(tail(old, 1))) old <- c(old, "")
  if (file.exists(rp)) file.copy(rp, paste0(rp, ".bak"), overwrite = TRUE)
  writeLines(c(old, block), rp, useBytes = TRUE)
  cat("\n已写入 ~/.Rprofile（旧文件备份为 ~/.Rprofile.bak）：\n")
  cat(paste0("  ", block, collapse = "\n"), "\n")
  cat("下次启动 R 即自动使用该镜像；想换镜像重跑 --install --save 即可。\n")
}

cat("\n")
