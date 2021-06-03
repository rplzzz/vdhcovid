## daily and weekly vaccinations.

library(dplyr)
library(readr)
library(here)

source(here('data-raw','constants.R'))

dataurl <- 'https://data.virginia.gov/api/views/28k2-x2rj/rows.csv?accessType=DOWNLOAD'
ctypes <- 'ccccccii'
newdata <- read_csv(dataurl, col_types = ctypes)

names(newdata) <- c('date', 'fips', 'county', 'district', 'facility_type', 'mfgr',
                    'dose_num', 'ndose')
newdata$date <- lubridate::mdy(newdata$date)
## Rename BRHD for backward compatibility
newdata$district[newdata$district == 'Blue Ridge'] <- 'Thomas Jefferson'
newdata <- filter(newdata,
                  !is.na(date),
                  grepl('^51[0-9]{3}$', fips),
                  dose_num == 2 | mfgr == 'J&J'
                  )
newdata$fips <- as.integer(newdata$fips)
newdata <- group_by(newdata, date, fips, county, district) %>%
  summarise(ndose = sum(ndose)) %>%
  ungroup() %>%
  left_join(valocalities[,c('fips', 'locality', 'population')], by='fips') %>%
  select(c('date', 'fips', 'locality', 'population', 'district', 'ndose'))

## Fill in missing days with zeros
daystart <- min(newdata$date)
dayend <- max(newdata$date)
date <- seq(daystart, dayend, by=1)
fips <- unique(newdata$fips)
datefips <- tidyr::crossing(date, fips)
datefips <- left_join(datefips, unique(newdata[,c('fips','locality','population','district')]),
                      by = c('fips'))
newdata <- left_join(datefips, newdata[,c('date','fips','ndose')], by=c('date','fips'))
newdata$ndose[is.na(newdata$ndose)] <- 0L

vadailyvax <-
  group_by(newdata, fips) %>%
  mutate(vaxtotal = cumsum(ndose), vaxfrac = vaxtotal/population) %>%
  ungroup()

## Aggregate to weekly totals.
t <- as.numeric(newdata$date - strt)         # strt defined in constants.R
newdata$week <- as.integer(floor(t/7))

vaweeklyvax <-
  group_by(newdata, week, fips, locality, district, population) %>%
  summarise(date=max(week)*7 + wk0date, ndose = sum(ndose)) %>%
  ungroup()

vaweeklyvax <-
  group_by(vaweeklyvax, fips) %>%
  mutate(vaxtotal = cumsum(ndose), vaxfrac = vaxtotal/population) %>%
  ungroup()

## Reorder columns
vaweeklyvax <-
  select(vaweeklyvax, date, week, fips, locality, district, population, ndose,
         vaxtotal, vaxfrac)

usethis::use_data(vadailyvax, overwrite=TRUE, compress='xz')
usethis::use_data(vaweeklyvax, overwrite=TRUE, compress='xz')

