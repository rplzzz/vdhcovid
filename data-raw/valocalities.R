

valocalities <-
  readr::read_csv(here::here('data-raw','va-health-districts.csv'),
                  col_types = 'iccnic')

pd <- valocalities$popdens <- valocalities$population / valocalities$areaSqMile
valocalities$stdpopdens <- (pd-mean(pd)) / sd(pd)

usethis::use_data(valocalities, overwrite=TRUE)
