library(dplyr)
library(readr)
library(here)

dataurl <-
  'https://www.vdh.virginia.gov/content/uploads/sites/182/2020/05/VDH-COVID-19-PublicUseDataset-Tests_by-LabReportDate.csv'
ctypes <- 'cciiii'
newdata <- read_csv(dataurl, col_types = ctypes) %>%
  select(date=`Lab Report Date`,
         HealthDistrict=`Health District`,
         ntest=`Number of PCR Testing Encounters`,
         npos=`Number of Positive PCR Tests`) %>%
  filter(date != 'Not Reported', !HealthDistrict %in% c('Out of State', 'Unknown'))

newdata$date <- lubridate::mdy(newdata$date)
strt <- as.Date('2019-12-30')              # Last Monday before 2020-01-01
newdata <- filter(newdata, date >= strt)

## Check for changes in the data
chknew <- semi_join(newdata, vdhcovid::daily, by=c('date', 'HealthDistrict'))
changed <- anti_join(vdhcovid::daily, newdata, by=c('date', 'HealthDistrict', 'ntest', 'npos'))
if(nrow(changed) > 0) {
  stop('One or more existing entries have changed.  See table "changed" for list.')
}


daily <- arrange(newdata, date)

## There seems to be a strong weekly cycle, so create a version that's aggregated
## by week.  The data also seems to be way overdispersed, so within each weekly
## group we calculate the variance of the positive test fraction.  We will use that
## to estimate the effective number of observations, which will in general be less
## than the reported number of tests
t <- as.numeric(newdata$date - strt)
newdata$week <- as.integer(floor(t/7))
weekly <- group_by(newdata, HealthDistrict, week) %>%
  mutate(fpos=npos/ntest) %>%
  summarise(date=max(date), ntest=sum(ntest), npos=sum(npos), varpos=var(fpos), nday=n()) %>%
  mutate(fpos=npos/ntest) %>%
  ungroup() %>%
  arrange(date)

## The variance of a beta distribution is a*b/((a+b)^2(a+b+1)), where a = npos+1
## and b = nneg+1.  This is kind of beastly to solve for N, so we'll make the
## approximation that N is large enough that we can neglect the difference between
## N, N+1, and N+2.  With this simplification the variance is fpos*(1-fpos)/Neff.
## The Neff derived this way will not in general be an integer.  The neff, nposeff,
## are rounded to the nearest integer, and the fpos reported is nposeff/neff.
weekly$neff <-
  if_else(weekly$ntest > 32 & weekly$nday > 4 & weekly$npos > 0,
          as.integer(round(weekly$fpos * (1-weekly$fpos) / weekly$varpos)),
          weekly$ntest)
weekly$neff <- pmin(weekly$neff, weekly$ntest)          # Don't let neff be larger than ntest
weekly$nposeff <- as.integer(round(weekly$neff * weekly$fpos))

usethis::use_data(daily, weekly, overwrite=TRUE)
