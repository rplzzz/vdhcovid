## code to prepare `vdhcases` dataset goes here

library('readr')
library('here')

source(here('data-raw','constants.R'))

dataurl <- 'https://www.vdh.virginia.gov/content/uploads/sites/182/2020/05/VDH-COVID-19-PublicUseDataset-Cases.csv'
coltypes <- 'cicciii'

newdata <-
  read_csv(dataurl, col_types = coltypes) %>%
  rename(date=`Report Date`,
         fips=FIPS,
         locality=Locality,
         HealthDistrict=`VDH Health District`,
         cases=`Total Cases`,
         hosp=Hospitalizations,
         deaths=Deaths
  )
newdata$date <- lubridate::mdy(newdata$date)

## TODO:  Check for retroactive changes here

vadailycases <- arrange(newdata, date)

## Create a weekly aggregated version.  These are cumulative cases, so we take the
## maximum value from each grouping.  Later we'll difference these to produce
## weekly new cases
t <- as.numeric(newdata$date - strt)
newdata$week <- as.integer(floor(t/7))
vaweeklycum <- group_by(newdata, fips, locality, HealthDistrict, week) %>%
  summarise(date=max(week)*7 + wk0date,
            cases=max(cases),
            hosp=max(hosp),
            deaths=max(deaths),
            nday=n()) %>%
  ungroup() %>%
  arrange(date)

## Now, difference week over week to get the number of new events during the week
vaweeklycases <-
  group_by(vaweeklycum, fips) %>%
  mutate(cases = c(NA_integer_, diff(cases)),
         hosp = c(NA_integer_, diff(hosp)),
         deaths = c(NA_integer_, diff(deaths)),
         diffweek = c(NA_integer_, diff(week))) %>%
  filter(!is.na(diffweek)) %>%
  ungroup()

## Check to see that there aren't any skipped weeks
stopifnot(all(vaweeklycases$diffweek == 1))

vaweeklycases <- select(vaweeklycases, -nday, -diffweek)

## Fix the locality names
loctbl <- select(valocalities, fips, locality)
vadailycases <- rename(vadailycases, county=locality) %>%
  left_join(loctbl, by='fips')
vaweeklycases <- rename(vaweeklycases, county=locality) %>%
  left_join(loctbl, by='fips')

usethis::use_data(vadailycases, vaweeklycases, overwrite=TRUE)

