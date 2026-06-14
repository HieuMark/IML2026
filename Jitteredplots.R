library(ggplot2)
library(dplyr)

# Example dataset
df <- combined_XY |>
  mutate(HOSPITAL_EXPIRE_FLAG = as.factor(HOSPITAL_EXPIRE_FLAG))

# Variable you want to compare against everything else
target_var <- "HOSPITAL_EXPIRE_FLAG"

Pairwise_X_y <- function(plot_type, plot_func) {
  # Create folder for plots
  if (dir.exists(plot_type)) unlink(plot_type, recursive = TRUE)
  dir.create(plot_type, showWarnings = FALSE)
  
  # Variables to compare against
  other_vars <- setdiff(names(df), target_var)
  
  for (var in other_vars) {
    
    p <- ggplot(df, aes(x = .data[[var]],
                        y = .data[[target_var]])) +
      plot_func(fill = "skyblue") +
      labs(
        title = paste(target_var, "vs", var),
        x = var,
        y = target_var
      ) +
      theme_minimal()
    
    # Save plot
    ggsave(
      filename = paste0(plot_type, "/", target_var, "_vs_", var, ".png"),
      plot = p,
      width = 6,
      height = 4
    )
  }
}

Pairwise_X_y("boxplots", geom_boxplot)
Pairwise_X_y("jitteredplots", geom_jitter)