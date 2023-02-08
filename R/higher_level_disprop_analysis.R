#' @title Calculate counts required for expected counts, and expected counts
#' @description Produces various counts used in disproportionality analysis.
#' @param df A data table, or an object possible to convert to a data table, e.g.
#' a tibble or data.frame. For column specifications, see details.
#' @param da_estimators A character vector containing the desired expected counts.
#' Defaults to all possible options, i.e. c("rrr", "prr", "ror").
#'
#' @details
#' The passed data table should contain three columns: "report_id", "drug_name"
#' and "event_name". It should have one row per reported drug-event-combination,
#' i.e. receiving an additional report for drug A and event 1 would add one row
#' to the table. The same report_id can occur on several rows, if the same
#' report contains several drugs and/or events. Column report_id must be of type
#' numeric or character. Columns drug_name and event_name must be
#' characters.
#' @return A tibble with counts.
#' @importFrom dplyr arrange count distinct everything group_by mutate n_distinct
#' rename select ungroup
#' @import data.table
#' @export

add_expected_counts <- function(df,
                                da_estimators = c("rrr", "prr", "ror")) {
  # data.table complains if you haven't defined these variables as NULLs
  NULL -> desc -> ends_with -> exp_ror -> d -> b -> exp_prr -> n_tot_prr ->
    n_event_prr -> exp_rrr -> obs -> n -> n_event -> n_drug -> n_tot ->
    event -> drug -> report_id

  checkmate::qassert(df[[1]], c("S+", "N+"))
  checkmate::qassert(df[[2]], "S+")
  checkmate::qassert(df[[3]], "S+")

  if (!any(utils::hasName(df, c("report_id", "drug", "event")))) {
    stop("At least one of column names 'report_id', 'drug' and 'event' is not
         found. Please check the passed object.")
  }

  checkmate::qassert(da_estimators, "S+")
  if (any(!da_estimators %in% c("rrr", "prr", "ror"))) {
    stop("Only 'rrr', 'prr' and 'ror' are allowed in parameter 'da_estimators'")
  }


  if (!typeof(df) == "data.table") {
    df <- data.table::as.data.table(df)
  }

  #  Begin with the RRR counts, as they're the computationally most feasible,
  #  and useful for calculating PRR and ROR.
  count_dt <- dtplyr::lazy_dt(df, immutable = FALSE) |>
    dplyr::distinct() |>
    dplyr::mutate(n_tot = dplyr::n_distinct(report_id)) |>
    dplyr::group_by(drug) |>
    dplyr::mutate(n_drug = dplyr::n_distinct(report_id)) |>
    dplyr::ungroup() |>
    dplyr::group_by(event) |>
    dplyr::mutate(n_event = dplyr::n_distinct(report_id)) |>
    dplyr::ungroup() |>
    dplyr::count(drug, event, n_tot, n_drug, n_event) |>
    dplyr::rename(obs = n) |>
    # Note that the as.numeric must be called in the same mutate as we do
    # the multiplication
    dplyr::mutate(exp_rrr = as.numeric(n_drug) * as.numeric(n_event) /
                    as.numeric(n_tot)) |>
    dplyr::select(drug, event, obs, n_drug, n_event, n_tot, exp_rrr)

  # Calc PRR counts if requested
  if (any(c("ror", "prr") %in% da_estimators)) {
    count_dt <- count_dt |>
      dplyr::mutate(
        n_event_prr = n_event - obs,
        n_tot_prr = n_tot - n_drug
      ) |>
      dplyr::mutate(exp_prr = as.numeric(n_drug) * as.numeric(n_event_prr) /
                      as.numeric(n_tot_prr)) |>
      dplyr::select(tidyselect::everything(), n_event_prr, n_tot_prr, exp_prr)
  }

  # Calc ROR counts if requested. Count "a" equal obs.
  if ("ror" %in% da_estimators) {
    count_dt <- count_dt |>
      dplyr::mutate(
        b = n_drug - obs,
        c = n_event_prr,
        d = n_tot_prr - n_event + obs
      ) |>
      dplyr::mutate(exp_ror = as.numeric(b) * as.numeric(c) / as.numeric(d)) |>
      dplyr::select(tidyselect::everything(), b, c, d, exp_ror)
  }

  if (!"rrr" %in% da_estimators) {
    count_dt <- count_dt |> dplyr::select(-tidyselect::ends_with("rrr"))
  }

  count_df <- count_dt |>
    dplyr::arrange(dplyr::desc(obs)) |>
    tibble::as_tibble()

  return(count_df)
}

#' @title Wrapper for adding disproportionality estimates to data frame
#' containing expected counts
#' @inheritParams add_expected_counts
#' @param da_estimators Character vector, defaults to c("ic", "prr", "ror").
#' @param rule_of_N Numeric. To protect against spurious
#' associations due to small observed counts, prr and ror point and
#' interval estimates are set to NA when the observed is less or equal to
#' the value passed as 'rule_of_N'. Defaults to 3, but 5 is sometimes used.
#' Set to NULL if you don't want to apply any such rule.
#' @param number_of_digits Integer. Defaults to 2. Set to NULL to avoid rounding.
#' @param ... For passing additional arguments, e.g. significance level.
#' @return The passed data frame with additional columns as specified by
#' parameters.
#' @export
add_disproportionality <- function(df,
                                   da_estimators = c("ic", "prr", "ror"),
                                   rule_of_N = 3,
                                   number_of_digits = 2,
                                   ...) {

  checkmate::qassert(rule_of_N, c("N1[0,]", "0"))
  # Function round actually rounds decimals in digits, so we can pass this on
  # without further concerns
  checkmate::qassert(number_of_digits, c("N1[0,]", "0"))


  da_df <- df

  if ("ic" %in% da_estimators) {
    ic_df <- pvutils::ic(da_df$obs, da_df$exp_rrr)
    da_df <- da_df |> dplyr::bind_cols(ic_df)
  }

  if ("prr" %in% da_estimators) {
    prr_df <- pvutils::prr(
      obs = da_df$obs,
      n_drug = da_df$n_drug,
      n_event_prr = da_df$n_event_prr,
      n_tot_prr = da_df$n_tot_prr
    )

    da_df <- da_df |> dplyr::bind_cols(prr_df)
  }

  if ("ror" %in% da_estimators) {
    ror_df <- pvutils::ror(
      a = da_df$obs,
      b = da_df$b,
      c = da_df$c,
      d = da_df$d
    )

    da_df <- da_df |> dplyr::bind_cols(ror_df)
  }

  # "Rule of three"
  if (any(c("ror", "prr") %in% da_estimators) & !is.null(rule_of_N)) {
    # Apply rule of N to these colnames
    da_estimators_not_ic <- stringr::str_subset(da_estimators, "ic", negate = T)

    # Only need to do this check once
    replace_these_rows <- da_df[["obs"]] <= rule_of_N

    da_df |>
      dplyr::mutate(dplyr::across(
        dplyr::starts_with(da_estimators_not_ic),
        ~ ifelse(replace_these_rows, NA, dplyr::cur_column())
      ))
  }

  # Rounding of output
  if (!is.null(number_of_digits)) {

    # Only apply to non-report-count columns, i.e. expected or da_estimates
    da_df |> dplyr::mutate(dplyr::across(
      dplyr::starts_with(c("exp", da_estimators)),
      ~ round(.x, digits = number_of_digits)
    ))
  }

  return(da_df)
}

#' @title FUNCTION_TITLE
#' @description FUNCTION_DESCRIPTION
#' @param df PARAM_DESCRIPTION
#' @param ... PARAM_DESCRIPTION
#' @return OUTPUT_DESCRIPTION
#' @details DETAILS
#' @examples
#' da_1 <- da(drug_event_df)
#' @export

da <- function(df, ...){

  df |> add_expected_counts() |> add_disproportionality()

}

