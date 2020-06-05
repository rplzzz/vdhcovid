#' Daily VDH COVID-19 testing data by health district
#'
#' This is the raw VDH testing and positive case fraction reports by health
#' district.
#'
#' @format Data frame with 4 columns
#' \describe{
#' \item{date}{Date of the lab reports.}
#' \item{HealthDistrict}{VDH health district.}
#' \item{ntest}{Number of PCR test encounters reported.}
#' \item{npos}{Number of positive tests reported.}
#' }
#'
#' @source Virginia Department of Health
#' \url{https://www.vdh.virginia.gov/coronavirus/}
"vadailytests"

#' Weekly VDH COVID-19 testing data by health district
#'
#' VDH testing and positive case fraction reports aggregated to weekly resolution
#' and adjusted for overdispersion.
#'
#' Test counts and reports are aggregated by week, with weeks running Monday
#' through Sunday (they are defined this way so that a Monday morning update
#' has data for a full week).  The date assigned is the date of the last day (Sunday)
#' of the week.
#' The positive test fraction is
#' calculated as the number of positive tests for the week divided by the total
#' number of tests for the week.
#'
#' To adjust for overdispersion we also calculate the daily positive test fraction
#' and its variance over the 7 days in the week.  The effective number of samples
#' is calculated as p*(1-p)/sig2, where p is the weekly positive test fraction.
#' Loosely speaking, what we're doing here is assuming that the sample prevalence
#' is constant over a week and taking the variance of the daily measurements as
#' an estimate of the variance in the measurement procedure.  Then we set the
#' effective number of tests such that the variance of the posterior PDF of the
#' p inferred from those observations will be equal to the observed variance.
#' From this, the effective number of positive results is estimated by multiplying
#' neff by fpos.  Both neff and nposeff are rounded to the nearest integer (meaning
#' that nposeff/neff may not be precisely equal fpos).
#'
#' Finally, note that this procedure is performed only when the number of observations
#' for the week is greater than 32 and there are at least 4 days of observations
#' in the week.  Weeks that don't meet these standards in a district are left
#' unadjusted.  This prevents us from getting crazy results for partial weeks or
#' weeks with just a few observations.  We also force neff <= ntest (so far only
#' one week in one district has required adjustment in this respect).
#'
#' @format Data frame with 10 columns
#' \describe{
#' \item{HealthDistrict}{VDH health district.}
#' \item{week}{Week number}
#' \item{date}{Date of the last day of the week with recorded measurements.}
#' \item{ntest}{Number of reported tests for the week.}
#' \item{npos}{Number of reported cases for the week.}
#' \item{varpos}{Variance in the daily positive test fraction.}
#' \item{nday}{Number of days reported in the week.}
#' \item{neff}{Effective number of samples (see details).}
#' \item{nposeff}{Effective number of positive samples.}
#' }
#' @source Virginia Department of Health
#' \url{https://www.vdh.virginia.gov/coronavirus/}
"vaweeklytests"

#' Daily cumulative cases by locality
#'
#' Raw data from VDH.  Note that it starts on 17 March, which is a few weeks later
#' than the testing data.
#'
#' @format Data frame with 7 columns
#' \describe{
#' \item{date}{Date of the report.}
#' \item{fips}{FIPS code for the locality.}
#' \item{locality}{Name of the locality (city or county).}
#' \item{HealthDistrict}{VDH health district the locality belongs to.}
#' \item{cases}{Cumulative COVID-19 cases in the locality.}
#' \item{hosp}{Cumulative hospitalizations for COVID-19 in the locality.}
#' \item{deaths}{Cumulative deaths from COVID-19 in the locality.}
#' }
#' @source Virginia Department of Health
#' \url{https://www.vdh.virginia.gov/coronavirus/}
"vadailycases"

#' Weekly new cases by locality
#'
#' This is aggregated from the daily data.  We give new cases for each week
#' instead of cumulative cases.  As with \code{\link{vaweeklytests}}, the date
#' is given for the last day of the week.
#'
#' @format Data frame with 8 columns
#' \describe{
#' \item{date}{Date of the last day of the week.}
#' \item{fips}{FIPS code for the locality.}
#' \item{locality}{Name of the locality (city or county).}
#' \item{HealthDistrict}{VDH health district the locality belongs to.}
#' \item{week}{Week number, counting from the beginning of the year.}
#' \item{cases}{New cases in the locality for the week.}
#' \item{hosp}{New hospitalizations in the locality for the week.}
#' \item{deaths}{New deaths in the locality for the week.}
#' }
#'
#' @source Virginia Department of Health
#' \url{https://www.vdh.virginia.gov/coronavirus/}
"vaweeklycases"
