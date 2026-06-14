#cur_seed <- Sys.time() |> as.integer()
cur_seed <- 1779536630
set.seed(cur_seed)
keras3::set_random_seed(cur_seed)
#writeLines(cur_seed |> as.character(), "R_objects/seed.txt")

# Data
library(tidyverse)
library(tidymodels)

columns_to_remove <- c(
  "subject_id", "hadm_id", "icustay_id", "DIAGNOSIS", "ICD9_diagnosis", "DOB",
  "ADMITTIME", "Diff"
)

train_X <- read_csv("train_X.csv")
train_y <- read_csv("train_y.csv")
test_X <- read_csv("test_X.csv")
MIMIC_metadata_diagnose <- read_csv("MIMIC_metadata_diagnose.csv")
MIMIC_diagnoses <- read_csv("MIMIC_diagnoses.csv") |> janitor::clean_names()

combined_XY <- left_join(train_X, train_y) |>
  left_join(MIMIC_diagnoses) |>
  select(-seq_num) |>
  mutate(from_data = 1)

test_X <- test_X |>
  left_join(MIMIC_diagnoses) |>
  select(-seq_num) |>
  mutate(HOSPITAL_EXPIRE_FLAG = NA, from_data = 2)

merged_for_multi_hot_encode <- rbind(combined_XY, test_X)

multi_hot_encode <- function(df) df |>
  mutate(value = 1) |>
  pivot_wider(
    names_from = icd9_code,
    values_from = value,
    values_fill = 0,
    values_fn = max,
    names_prefix = "ICD9_code_"
  )

one_hot_encode <- function(df) {
  # Identify numeric and categorical columns
  num_cols <- sapply(df, is.numeric)
  cat_cols <- !num_cols
  
  # Convert categorical columns to factors
  df[cat_cols] <- lapply(df[cat_cols], as.factor)
  
  # One-hot encode categorical columns only
  dummy_matrix <- model.matrix(~ . - 1, data = df[cat_cols])
  
  # Combine untouched numeric columns with encoded columns
  final_df <- cbind(df[num_cols], as.data.frame(dummy_matrix))
  final_df
}

system.time({
  encoded_data <- merged_for_multi_hot_encode |>
    multi_hot_encode() |>
    select(-columns_to_remove) |>
    one_hot_encode()
  
  combined_XY <- encoded_data |>
    filter(from_data == 1) |>
    select(-from_data)
  
  test_X <- encoded_data |>
    filter(from_data == 2) |>
    select(-c(from_data, HOSPITAL_EXPIRE_FLAG))
})
rm(encoded_data)

train_test_split <- rsample::initial_split(combined_XY, 0.8, strata = HOSPITAL_EXPIRE_FLAG)
train_data <- rsample::training(train_test_split)
test_data <- rsample::testing(train_test_split)

library(keras3)

NN_model <- keras_model_sequential()
NN_model |>
  layer_dense(units = 1000, activation = "relu", input_shape = ncol(train_data) - 1) |>
  # layer_dense(units = 5000, activation = "relu") |>
  # layer_dense(units = 2500, activation = "relu") |>
  # layer_dense(units = 1250, activation = "relu") |>
  # layer_dense(units = 625, activation = "relu") |>
  # layer_dense(units = 313, activation = "relu") |>
  # layer_dense(units = 79, activation = "relu") |>
  layer_dense(units = 400, activation = "relu") |>
  layer_dense(units = 20, activation = "relu") |>
  layer_dense(units = 1, activation = "sigmoid")

NN_model |> compile(
  optimizer = "adam",
  loss = loss_binary_focal_crossentropy(),
  metrics = list(metric_auc())
)

NN_train_X <- train_data |>
  select(-HOSPITAL_EXPIRE_FLAG) |>
  as.matrix()
NN_train_y <- train_data$HOSPITAL_EXPIRE_FLAG

NN_test_X <- test_data |>
  select(-HOSPITAL_EXPIRE_FLAG) |>
  as.matrix()
NN_test_y <- test_data$HOSPITAL_EXPIRE_FLAG

early_stop <- callback_early_stopping(
  monitor = "val_auc",
  mode = "max",
  patience = 10,
  restore_best_weights = TRUE
)

NN_fit <- NN_model |> 
    keras3::fit(
      x = NN_train_X, 
      y = NN_train_y,
      validation_data = list(
        NN_test_X,
        NN_test_y
      ),
      epochs = 1000,
      batch_size = 32, # default
      verbose = 1,
      callbacks = list(early_stop)
    )
plot(NN_fit)

test_y <- predict(
  NN_model,
  test_X |>
    as.matrix()
)
test_y <- read_csv("test_X.csv") |>
  select(icustay_id) |>
  mutate(HOSPITAL_EXPIRE_FLAG = test_y[,1])
write_csv(test_y, "test_y/test_y.csv") # model predictions