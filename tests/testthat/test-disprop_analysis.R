test_that("Function ic works", {
  test_df <- ic(1, 1)

  expected_output <- tibble::tribble(
    ~"ic_lower", ~"ic", ~"ic_upper",
    log2(qgamma(0.025, 1.5, 1.5)),
    0,
    log2(qgamma(0.975, 1.5, 1.5))
  )

  expect_equal(test_df[, 1], expected_output[, 1])
  expect_equal(test_df[, 2], expected_output[, 2])
  expect_equal(test_df[, 3], expected_output[, 3])
})

test_that("Function ror works", {
  test_df <- ror(1:2, 2:3, 3:4, 4:5)

  expected_output <- tibble::tribble(
    ~"ror_lower", ~"ror", ~"ror_upper",
    NA, 1 * 4 / (2 * 3), NA,
    NA, 2 * 5 / (3 * 4), NA
  )

  # expect_equal(test_df[, 1], expected_output[, 1])
  expect_equal(test_df[, 2], expected_output[, 2])
  # expect_equal(test_df[, 3], expected_output[, 3])
})


test_that("Function add_expected_count works", {

  df_colnames = list(report_id = "report_id",
                     drug = "drug",
                     event = "event")

  produced_output <- pvutils::add_expected_counts(pvutils::drug_event_df,
                                                  df_colnames,
  expected_count_estimators = c("rrr", "prr", "ror")
  )

  # Should return as many rows as there are unique report_ids in drug_event_df
  # (N=1000)
  expect_equal(
    nrow(produced_output),
    nrow(dplyr::distinct(drug_event_df[, c("drug", "event")], ))
  )

  # Some internal checks that the counts agree for at least one line
  first_row <- produced_output[1, ]
  expect_equal(sum(first_row[, c("obs", "b", "c", "d")]), first_row$n_tot)
  expect_equal(sum(first_row[, c("obs", "b")]), first_row$n_drug)
  expect_equal(sum(first_row[, c("obs", "c")]), first_row$n_event)
  expect_equal(first_row$n_event_prr, first_row$c)
  expect_equal(first_row$n_tot_prr, diff(as.numeric(first_row[, c("n_drug", "n_tot")])))
})

test_that("The whole disproportionality function chain runs without NA output except in PRR and ROR", {
  output <- pvutils::drug_event_df |>
    pvutils::da() |>
    dplyr::select(-dplyr::starts_with("ror")) |>
    dplyr::select(-dplyr::starts_with("prr"))

  expect_equal(FALSE, any(is.na(output)))
})

test_that("The grouping functionality runs", {

  drug_event_df_with_grouping  <- pvutils::drug_event_df |>
    dplyr::mutate("group" = report_id %% 2)
  da_1 <- drug_event_df_with_grouping |> pvutils::da(df_colnames = list(report_id = "report_id",
                                                                        drug = "drug",
                                                                        event = "event",
                                                                        group_by = "group"))

  first_row_ic_group_0 <- as.numeric(da_1[1,]$ic)
  manual_calc_ic_first_row_group_0 <- as.numeric(log2((14 + 0.5)/(da_1[1,8] + 0.5)))

  expect_equal(manual_calc_ic_first_row_group_0, first_row_ic_group_0)
})

test_that("Custom column names can be passed through the df_colnames list", {

  drug_event_df_custom_names  <- pvutils::drug_event_df |>
    dplyr::rename( RepId= report_id, Drug = drug, Event = event)
  da_1 <- drug_event_df_custom_names |> pvutils::da(df_colnames = list(report_id = "RepId",
                                                                        drug = "Drug",
                                                                        event = "Event",
                                                                        group_by = NULL))


  custom_colnames <- colnames(da_1)[1:2]

  expect_equal(custom_colnames, c("Drug", "Event"))
})

