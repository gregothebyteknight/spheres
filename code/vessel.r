
# LOADING LIBRARIES
source("./module.r")

library(rgl) # interactive 3D plotting
library(fifer) # for scring.to.colors
library(htmlwidgets) # for saving the plot

setwd(this.path::here())
options(rgl.printRglwidget = TRUE)

# VARIABLES DECLARATION
num_steps <- 400 # number of steps
step_size <- 0.5  # step size
prob <- 0.01 # probability of branching

r <- 3 # radius of vessel
d <- 1 # width of vessel's walls
lambda <- 0.02 # Poisson process intensity
jitter_sd <- 0.1  # standard deviation for jitter

tree <- list(matrix(c(0, 0, 0), nrow = 1)) # list to hold branch trajectories
new_point <- kent_point(2, 0, c(1, 0, 0), 1, tree[[1]], step_size)
tree[[1]] <- rbind(tree[[1]], new_point) # add first step

dot_loc <- matrix(ncol = 3, nrow = 0) # final matrix of dot location

# INTERATION THROUGH THE TREE
for (step in 1:num_steps) {
  new_branches <- list()
  tree_len <- length(tree)

  # EXTENDING EXISTING BRANCHES
  for (i in 1:tree_len) {
    branch <- tree[[i]]
    last_dot <- tree[[i]][nrow(branch), ]

    # Compute the current direction from the last two points
    if (nrow(branch) > 1) {
      vec <- last_dot - branch[nrow(branch) - 1, ]
      vec <- vec / sqrt(sum(vec^2))
    } else {
      vec <- vec_init
    }

    # Extend the branch using a new direction based on the current direction
    new_point <- kent_point(50, 1000, vec, 0, last_dot, step_size)
    tree[[i]] <- rbind(tree[[i]], new_point)

    # BRANCHING CONDITION
    if (runif(1) < prob) {
      branch_new_point <- kent_point(2, 0, vec, 1, last_dot, step_size)
      new_branch <- rbind(branch, branch_new_point)
      new_branches[[length(new_branches) + 1]] <- new_branch
    }
  }
  tree <- c(tree, new_branches)
}

# VESSEL SIMULATION
for (branch in tree) {
  for (i in seq_len(nrow(branch) - 1)) {
    # Compute branch direction vector
    curr_pnt <- branch[i, ]
    next_pnt <- branch[i + 1, ]
    br_vec <- next_pnt - curr_pnt
    br_norm <- sqrt(sum(br_vec^2))
    br_vec <- br_vec / br_norm

    # Generate 3D Poisson parallelepiped
    prizm <- pois_in_space(r, d, br_norm, lambda)

    if ((npoints(prizm) > 0)) {  # Check if any points are generated
      prizm <- cbind(as.numeric(prizm$data$x), as.numeric(prizm$data$y),
                     as.numeric(prizm$data$z))

      # Modify to tube: keep points close to the vessel wall
      cond <- sqrt(prizm[, 2]^2 + prizm[, 3]^2)
      prizm <- prizm[abs(cond - r) <= d / 2, , drop = FALSE]

      # Compute and apply rotation using Rodrigues' formula
      prizm_rot <- t(rotation(br_vec) %*% t(prizm))

      # Translation: add the current point vector using vectorized addition
      prizm_rot <- prizm_rot + matrix(curr_pnt, nrow = nrow(prizm_rot),
                                      ncol = 3, byrow = TRUE)
      prizm_rot <- prizm_rot + # add jitter
        matrix(rnorm(length(prizm_rot), 0, jitter_sd), ncol = 3)

      dot_loc <- rbind(dot_loc, prizm_rot)
    }
  }
}

# VISUALIZATION
# Create a batch vector that assigns a unique id to each branch’s points
batch <- unlist(lapply(seq_along(tree), function(i) rep(i, nrow(tree[[i]]))))

# plot the initial branch points
rgl::plot3d(do.call(rbind, tree), col = fifer::string.to.colors(batch),
            xlab = "X", ylab = "Y", zlab = "Z")

# add the vessel simulation dots on the same plot
rgl::points3d(dot_loc, size = 2)

widget <- rgl::rglwidget()
htmlwidgets::saveWidget(widget, "../images/vessel_combined.html",
                        selfcontained = TRUE)

# Save as CSV
dot_loc <- scale(dot_loc, center = TRUE, scale = FALSE) # centering
colnames(dot_loc) <- c("x", "y", "z") # rename columns
utils::write.csv(dot_loc, "../data/vessel_loc.csv", row.names = FALSE)