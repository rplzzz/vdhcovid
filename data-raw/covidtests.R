library(dplyr)
library(readr)
library(here)

source(here('data-raw','constants.R'))

dataurl <- 'https://data.virginia.gov/api/views/3u5k-c2gr/rows.csv?accessType=DOWNLOAD'
# API url:  'https://data.virginia.gov/resource/3u5k-c2gr.csv'

ctypes <- 'cciiiiiiii'
newdata <- read_csv(dataurl, col_types = ctypes) %>%
  select(date=`Lab Report Date`,
         HealthDistrict=`Health District`,
         ntest=`Number of PCR Testing Encounters`,
         npos=`Number of Positive PCR Testing Encounters`) %>%
  filter(date != 'Not Reported', !HealthDistrict %in% c('Out of State', 'Unknown', 'Out Of State'))

newdata$date <- lubridate::mdy(newdata$date)
newdata <- filter(newdata, date >= strt, !is.na(HealthDistrict), ntest > 0)

if(any(newdata$HealthDistrict == "Blue Ridge")) {
  message('Renaming "Blue Ridge" to "Thomas Jefferson" for backward compatibility')
  newdata$HealthDistrict[newdata$HealthDistrict=='Blue Ridge'] <- "Thomas Jefferson"
}

## Check for changes in the data
chknew <- semi_join(newdata, vdhcovid::vadailytests, by=c('date', 'HealthDistrict'))
changed <- anti_join(vdhcovid::vadailytests, newdata, by=c('date', 'HealthDistrict', 'ntest', 'npos'))
nchg <- nrow(changed)
if(nchg > 0) {
  if(exists('ACCEPT_CHANGES') && ACCEPT_CHANGES) {
    ACCEPT_CHANGES <- FALSE
    warning(nchg, ' changed entries found.  ACCEPT_CHANGES is set, so new entries will be adopted')
  }
  else {
    changed <- left_join(changed, newdata, by=c('date','HealthDistrict'))
    stop(nchg, ' changed entries.  See table "changed" for list.')
  }
}


vadailytests <- arrange(newdata, date)

## There seems to be a strong weekly cycle, so create a version that's aggregated
## by week.  The data also seems to be way overdispersed, so within each weekly
## group we calculate the variance of the positive test fraction.  We will use that
## to estimate the effective number of observations, which will in general be less
## than the reported number of tests
t <- as.numeric(newdata$date - strt)
newdata$week <- as.integer(floor(t/7))
vaweeklytests <- group_by(newdata, HealthDistrict, week) %>%
  mutate(fpos=npos/ntest, sdvalid=ntest>0) %>%          # This is the daily positive fraction
  summarise(date=max(week)*7 + wk0date, ntest=sum(ntest), npos=sum(npos), varpos=var(fpos[sdvalid]), nday=n()) %>%
  mutate(ntest=ifelse(ntest>0, ntest, 1L)) %>%   # If there are no tests at all for a week, record one test
                                                # to prevent divide-by-zero
  mutate(fpos=npos/ntest) %>%          # This is the weekly positive fraction
  ungroup() %>%
  arrange(date)

## Minimum number of tests for adjustment.  If the nominal count was smaller than
## this, then we won't adjust.  Also, we won't adjust to anything smaller than this
## (The latter provision prevents the perverse situation where adding a few tests
## takes you over the threshold and therefore gets you adjusted to something much
## smaller)
adjustmin <- 32

## The variance of a beta distribution is a*b/((a+b)^2(a+b+1)), where a = npos+1
## and b = nneg+1.  This is kind of beastly to solve for N, so we'll make the
## approximation that N is large enough that we can neglect the difference between
## N, N+1, and N+2.  With this simplification the variance is fpos*(1-fpos)/Neff.
## The Neff derived this way will not in general be an integer.  The neff, nposeff,
## are rounded to the nearest integer, and the fpos reported is nposeff/neff.
vaweeklytests$neff <-
    if_else(vaweeklytests$ntest > adjustmin & vaweeklytests$nday > 4 & vaweeklytests$npos > 0,
              as.integer(
                pmax(
                  adjustmin,
                  round(vaweeklytests$fpos * (1-vaweeklytests$fpos) / vaweeklytests$varpos)
                )),
                vaweeklytests$ntest)
vaweeklytests$neff <- pmin(vaweeklytests$neff, vaweeklytests$ntest)          # Don't let neff be larger than ntest
vaweeklytests$nposeff <- as.integer(round(vaweeklytests$neff * vaweeklytests$fpos))

usethis::use_data(vadailytests, vaweeklytests, overwrite=TRUE)
