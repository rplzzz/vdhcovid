#' Get population for one or more localities
#'
#' @param locality Name of localities to get population for.  Ignored if \code{fips}
#' is specified
#' @param fips FIPS codes for localities to get populaiton for.  If specified this
#' overrides the \code{locality} parameter
#' @return Vector of populations
#' @export
getpop <- function(locality=NULL, fips=NULL)
{
  if(is.null(locality) && is.null(fips)) {
    stop('Must specify either locality or FIPS code')
  }

  if(is.null(fips)) {
    filt <- vdhcovid::valocalities[match(locality, vdhcovid::valocalities$locality), ]
  }
  else {
    filt <- vdhcovid::valocalities[match(fips, vdhcovid::valocalities$fips), ]
  }
  filt$population
}
