% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/lower_level_disprop_analysis.R
\name{count_expected_rrr}
\alias{count_expected_rrr}
\title{Count Expected for Relative Reporting Rate}
\usage{
count_expected_rrr(df_colnames, df)
}
\arguments{
\item{df_colnames}{Some description to be added}

\item{df}{See documentation for add_expected_counts}
}
\value{
A data frame with columns for obs, n_drug,
n_event, n_tot and (RRR) expected
}
\description{
Internal function to provide expected counts related to the RRR
}
\seealso{
\code{\link[dtplyr]{lazy_dt}}
 \code{\link[dplyr]{distinct}}, \code{\link[dplyr]{mutate}}, \code{\link[dplyr]{n_distinct}}, \code{\link[dplyr]{group_by}}, \code{\link[dplyr]{count}}, \code{\link[dplyr]{rename}}, \code{\link[dplyr]{select}}
}
