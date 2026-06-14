rows <- 2:25

p = GGally::ggpairs(
  train_data_numeric |> mutate(
    HOSPITAL_EXPIRE_FLAG = train_data_train$HOSPITAL_EXPIRE_FLAG
  ),
  aes(colour = HOSPITAL_EXPIRE_FLAG)
)

ggpair_plots <- "ggpairs"

if (dir.exists(ggpair_plots)) {
  unlink(ggpair_plots, recursive = TRUE)
}
dir.create(ggpair_plots)

for (r in rows) {
  if (dir.exists(paste0(ggpair_plots, "/row_", r))) {
    unlink(paste0(ggpair_plots, "/row_", r), recursive = TRUE)
  }
  dir.create(paste0(ggpair_plots, "/row_", r))
  
  for (c in seq(r-1)) {
    ggplot2::ggsave(paste0(ggpair_plots, "/row_", r, "/col", c, ".png"), p[r, c])
  }
}