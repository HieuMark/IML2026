library(tidyverse)
library(tidymodels)

train_X <- read_csv("train_X.csv")
train_y <- read_csv("train_y.csv")
train_data <- left_join(train_X, train_y)
train_data <- train_data |>
  mutate(HOSPITAL_EXPIRE_FLAG = as.factor(HOSPITAL_EXPIRE_FLAG))

knn_tune <- nearest_neighbor(
  neighbors = tune(),
  weight_func = tune(),
  dist_power = tune()
) |>
  set_mode("classification") |>
  set_engine("kknn")

knn_wf <- workflow() |>
  add_model(knn_tune) |>
  add_formula(HOSPITAL_EXPIRE_FLAG ~ . - subject_id - hadm_id)

folds <- vfold_cv(train_data, v = 5, strata = HOSPITAL_EXPIRE_FLAG)

knn_grid <- grid_regular(
  neighbors(c(1L, 50L)),
  weight_func(
    c("rectangular", "triangular", "epanechnikov", "biweight", "triweight", "cos", "inv", "gaussian", "rank", "optimal")
  ),
  dist_power(c(1, 2)),
  levels = c(neighbors = 2, weight_func = 10, dist_power = 2)
)

knn_res <- tune_grid(
  knn_wf,
  resamples = folds,
  grid = knn_grid,
  control = control_grid(verbose = TRUE)
)

saveRDS(knn_res, "R_objects/KNN_CV_result.RDS") # save out the result