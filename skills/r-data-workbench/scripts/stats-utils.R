#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# stats-utils.R — 统计汇总与结果整理小工具
#
# 用法：
#   source("scripts/stats-utils.R")
#   summarise_ci(df, "mpg", c("cyl", "am"))        # 分组汇总 + SE + 95%CI（字符向量分组）
#   summarise_ciGroups(df, mpg, cyl)               # 同上，懒求值写法
#   describe_all(df)                               # 全变量描述统计
#   tidy_model(m, exp = TRUE)                      # 回归结果表（OR/RR）
#   compare_models(list(base = m1, full = m2))     # 多模型 AIC/BIC 比较
#
# 设计要点：
#   1) 只依赖 base R 与 dplyr，不为小工具引入额外重包；
#   2) 置信区间基于 t 分布（df = n-1），小样本时区间会正确变宽；
#   3) 缺失值行为显式化：汇总时剔除 NA，但结果中同时给出有效样本量 n；
#   4) 输出直接适配 ggplot2 的 geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi))。
# ---------------------------------------------------------------------------

.has_pkg <- function(p) {
  if (requireNamespace(p, quietly = TRUE)) TRUE else FALSE
}

.need <- function(p) {
  if (!.has_pkg(p)) stop("需要 '", p, "'：install.packages('", p, "')", call. = FALSE)
}

# base R 实现：按 groups 分组计算 n / missing / mean / sd / median
.summarise_ci_base <- function(d, value, groups) {
  x <- d[[value]]
  key <- if (is.null(groups) || !length(groups)) {
    factor(rep("all", nrow(d)))
  } else {
    interaction(d[groups], drop = TRUE, lex.order = TRUE)
  }
  idx <- split(seq_len(nrow(d)), key)
  rows <- lapply(idx, function(i) {
    v <- x[i]
    data.frame(
      n       = sum(!is.na(v)),
      missing = sum(is.na(v)),
      mean    = mean(v, na.rm = TRUE),
      sd      = stats::sd(v, na.rm = TRUE),
      median  = stats::median(v, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (!is.null(groups) && length(groups)) {
    gv <- do.call(rbind, lapply(idx, function(i) d[i[1], groups, drop = FALSE]))
    out <- cbind(gv, out)
    rownames(out) <- NULL
  }
  out
}

#' 分组汇总：n / mean / sd / se / 95% 置信区间
#'
#' @param data   数据框
#' @param value  待汇总的数值变量（列名字符串）
#' @param groups 分组变量（列名字符向量），可为 NULL 表示整体汇总
#' @param conf   置信水平，默认 0.95
#' @return data.frame：分组列 + n、missing、mean、sd、se、ci_lo、ci_hi
#'
#' 说明：未安装 dplyr 时自动走 base R 实现，结果列完全一致。
summarise_ci <- function(data, value, groups = NULL, conf = 0.95) {
  stopifnot(is.data.frame(data), is.character(value), length(value) == 1)
  if (!value %in% names(data)) stop("找不到列：", value, call. = FALSE)
  if (!is.null(groups) && !all(groups %in% names(data))) {
    stop("找不到分组列：", paste(setdiff(groups, names(data)), collapse = ", "),
         call. = FALSE)
  }

  d <- data[, unique(c(groups, value)), drop = FALSE]

  out <- if (.has_pkg("dplyr")) {
    d |>
      dplyr::group_by(dplyr::across(dplyr::all_of(groups))) |>
      dplyr::summarise(
        n       = sum(!is.na(.data[[value]])),
        missing = sum(is.na(.data[[value]])),
        mean    = mean(.data[[value]], na.rm = TRUE),
        sd      = stats::sd(.data[[value]], na.rm = TRUE),
        median  = stats::median(.data[[value]], na.rm = TRUE),
        .groups = "drop"
      ) |>
      as.data.frame()
  } else {
    .summarise_ci_base(d, value, groups)
  }

  out$se <- out$sd / sqrt(out$n)
  q <- stats::qt(conf / 2 + 0.5, df = pmax(out$n - 1, 1))   # t 乘数，n<=1 时钳制避免 NaN
  out$ci_lo <- out$mean - out$se * q
  out$ci_hi <- out$mean + out$se * q

  # 样本量不足时给出 NA，避免输出误导性的区间
  bad <- !is.finite(out$n) | out$n < 2
  out$se[bad]    <- NA_real_
  out$sd[bad]    <- NA_real_
  out$ci_lo[bad] <- NA_real_
  out$ci_hi[bad] <- NA_real_

  if (any(out$missing > 0)) {
    message(sprintf("  [note] '%s' 共剔除 %d 个缺失值", value, sum(out$missing)))
  }
  out
}

#' 懒求值版本：summarise_ciGroups(df, mpg, cyl, am)
summarise_ciGroups <- function(data, value, ..., conf = 0.95) {
  val <- deparse(substitute(value))
  grp <- as.character(unlist(lapply(substitute(list(...))[-1], deparse)))
  summarise_ci(data, val, if (length(grp)) grp else NULL, conf = conf)
}

#' 全变量描述统计：数值型 + 分类型
describe_all <- function(data) {
  stopifnot(is.data.frame(data))

  num_cols <- names(data)[sapply(data, is.numeric)]
  cat_cols <- names(data)[sapply(data, function(x) is.factor(x) || is.character(x))]

  num_tab <- if (length(num_cols)) {
    do.call(rbind, lapply(num_cols, function(v) {
      x <- data[[v]]
      data.frame(
        variable = v,
        n        = sum(!is.na(x)),
        missing  = sum(is.na(x)),
        mean     = mean(x, na.rm = TRUE),
        sd       = stats::sd(x, na.rm = TRUE),
        median   = stats::median(x, na.rm = TRUE),
        q1       = stats::quantile(x, .25, na.rm = TRUE, names = FALSE),
        q3       = stats::quantile(x, .75, na.rm = TRUE, names = FALSE),
        min      = min(x, na.rm = TRUE),
        max      = max(x, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
    }))
  } else NULL

  cat_tab <- if (length(cat_cols)) {
    do.call(rbind, lapply(cat_cols, function(v) {
      tb <- table(data[[v]], useNA = "ifany")
      data.frame(
        variable = v,
        level    = names(tb),
        n        = as.integer(tb),
        pct      = as.numeric(tb) / sum(tb) * 100,
        stringsAsFactors = FALSE
      )
    }))
  } else NULL

  invisible(list(numeric = num_tab, categorical = cat_tab))
}

#' 整理回归结果表
#'
#' @param model lm / glm 对象
#' @param exp  是否对估计值取指数（logistic/Poisson 取 TRUE 得 OR/RR）
#' @param conf 置信水平
tidy_model <- function(model, exp = FALSE, conf = 0.95) {
  cm <- as.data.frame(stats::coef(summary(model)))
  # 用 confint.default()：glm 走正态近似，避免 confint() 的 profile 计算（慢且可能不收敛）
  ci <- tryCatch(stats::confint.default(model, level = conf),
                 error = function(e) stats::confint(model, level = conf))
  p_col <- if ("Pr(>|z|)" %in% names(cm)) "Pr(>|z|)" else "Pr(>|t|)"
  s_col <- if ("z value"  %in% names(cm)) "z value"  else "t value"

  out <- data.frame(
    term     = rownames(cm),
    estimate = cm[["Estimate"]],
    se       = cm[["Std. Error"]],
    stat     = cm[[s_col]],
    p_value  = cm[[p_col]],
    ci_lo    = ci[, 1],
    ci_hi    = ci[, 2],
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL

  if (isTRUE(exp)) {
    out$estimate <- exp(out$estimate)
    out$ci_lo    <- exp(out$ci_lo)
    out$ci_hi    <- exp(out$ci_hi)
    names(out)[names(out) == "estimate"] <- "OR_or_RR"
  }
  out$p_formatted <- ifelse(out$p_value < 0.001, "< 0.001",
                            formatC(out$p_value, format = "f", digits = 3))
  out
}

#' 多模型并排比较（AIC / BIC / R²）
#'
#' @details R² 列对 lm 取调整前 R²；glm 等无 R² 的模型返回 NA 并另给 McFadden 伪 R²，
#'          不会因 summary() 无 r.squared 字段而破坏整张表。
compare_models <- function(models, exp = FALSE) {
  stopifnot(is.list(models), length(models) > 0)
  nm <- names(models)
  if (is.null(nm) || any(nm == "")) nm <- paste0("m", seq_along(models))

  r2_of <- function(m) {
    s <- tryCatch(summary(m), error = function(e) NULL)
    if (!is.null(s) && !is.null(s$r.squared)) return(as.numeric(s$r.squared))
    NA_real_
  }
  pseudo_r2_of <- function(m) {
    tryCatch({
      if (!inherits(m, "glm")) return(NA_real_)
      ll  <- as.numeric(stats::logLik(m))
      ll0 <- as.numeric(stats::logLik(stats::update(m, . ~ 1)))
      1 - ll / ll0
    }, error = function(e) NA_real_)
  }

  fit <- data.frame(
    model      = nm,
    k          = vapply(models, function(m) length(stats::coef(m)), integer(1)),
    AIC        = vapply(models, function(m) as.numeric(stats::AIC(m)), numeric(1)),
    BIC        = vapply(models, function(m) as.numeric(stats::BIC(m)), numeric(1)),
    logLik     = vapply(models, function(m) as.numeric(stats::logLik(m)), numeric(1)),
    r_squared  = vapply(models, r2_of, numeric(1)),
    pseudo_r2  = vapply(models, pseudo_r2_of, numeric(1)),
    stringsAsFactors = FALSE
  )

  coefs <- do.call(rbind, lapply(seq_along(models), function(i) {
    d <- tidy_model(models[[i]], exp = exp)
    d$model <- nm[i]
    d
  }))

  invisible(list(fit = fit, coefficients = coefs))
}
