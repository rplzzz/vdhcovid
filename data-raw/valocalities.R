

valocalities <-
  readr::read_csv(here::here('data-raw','va-health-districts.csv'),
                  col_types = 'iccnic')

valocalities$popdens <- valocalities$population / valocalities$areaSqMile

usethis::use_data(valocalities)
