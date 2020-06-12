#### Parse the record of COVID-19 tests by district and assign to localities

library('here')
library('dplyr')
library('tidyr')
library('vdhcovid')


### Splendid.  Now we need to allocate the tests to individual jurisdictions within
### each district.  Start by loading the table of counties and districts.  It's
### pretty awesome that they give us the area of each county, but we won't need it.
vahd <-
  readr::read_csv(here('data-raw','va-health-districts.csv'),
                  col_types = 'iccnic') %>%
  select(-areaSqMile)

## This table still has Bedford City and Clifton Forge City, which have since
## merged into Bedford County and Alleghany county respectively.
ibedcty <- which(vahd$fips == 51515)
ibedcoun <- which(vahd$fips == 51019)
icliffrg <- which(vahd$fips == 51560)
ialleg <- which(vahd$fips == 51005)

vahd$population[ibedcoun] <- vahd$population[ibedcoun] + vahd$population[ibedcty]
vahd$population[ialleg] <- vahd$population[ialleg] + vahd$population[icliffrg]
vahd <- vahd[-c(ibedcty, icliffrg),]

## Ensure that all districts are represented
stopifnot(setequal(vahd$district, vaweeklytests$HealthDistrict))

district_total_pop <-
  group_by(vahd, district) %>%
  summarise(disttotpop = sum(population))
vahd <-
  left_join(vahd, district_total_pop, by='district') %>%
  mutate(distpopfrac=population/disttotpop) %>%
  select(fips, locality, district, population, distpopfrac)

## Impute tests to localities proportional to population, making sure to give
## an integer number of tests to each.
## XXX Need to get the number of cases for each locality too!
impute_tests <- function(df, grouping)
  #function(week, date, fips, locality, ntest_district, population, distpopfrac, ...)
{
  rfac <- df$neff[1] / df$ntest_district[1]
  df$nposeff_local <- if_else(df$cases > 0, pmax(round(df$cases * rfac), 1), 0)
  df$ntest_local <- df$nposeff_local

  rows <- order(df$distpopfrac, decreasing=TRUE)

  ntest <- df$neff[1] - sum(df$ntest_local)   # remaining tests to allocate
  stopifnot(ntest >= 0)
  pop <- sum(df$population)       # population in unimputed localities

  for(irow in rows) {
    frac <- df$population[irow] / pop
    alloctest <- round(frac*ntest)
    df$ntest_local[irow] <- df$ntest_local[irow] + alloctest
    ntest <- ntest - alloctest
    pop <- pop - df$population[irow]
  }

  mutate(df, date=grouping$date) %>%
    select(week, date, fips, locality, ntesteff=ntest_local, nposeff=nposeff_local)
}

## Join in the weekly cases so that we can make sure that each locality has at
## at least as many tests as cases.
locality_cases <- select(vaweeklycases, fips, week, cases)

va_weekly_ntest_county <-
  rename(vaweeklytests, district=HealthDistrict, ntest_district=ntest) %>%
  left_join(vahd, by='district') %>%
  left_join(locality_cases, by=c('fips', 'week')) %>%
  filter(!is.na(cases)) %>%
  group_by(date, district) %>%
  group_map(impute_tests) %>%
  bind_rows()

usethis::use_data(va_weekly_ntest_county, overwrite=TRUE)
