#' Chumbley Non-Random
#' 
#' This function computes the Chumbley U-Statistic on systemically chosen pairs of windows rather 
#' than the original method which selects randomly chosen pairs of windows
#' @param data1 The first tool mark as a 1-column matrix
#' @param data2 The second tool mark as a 1-column matrix
#' @param window_opt size of the window to be used in the optimization step
#' @param window_val Size of the window to be used in the validation step
#' @param coarse smoothing parameter for the normalization smooth
#' @importFrom stats pnorm
#' @importFrom ggplot2 ggplot
#' @export
#' @return list with
#' \itemize{
#' \item {same_shift_n} Number of same shift offsets used
#' \item {diff_shift_n} Number of different shift offsets used
#' \item {U} observed U statistic
#' \item {p_value} Corresponding p-value
#' \item {same_shift} correlation values corresponding to the same shift offset
#' \item {diff_shift} correlation values corresponding to the different shift offset
#' }
#' @examples 
#' res1 <- chumbley_non_random(ameslab$profile[[1]], ameslab$profile[[2]])
chumbley_non_random <- function(data1, data2, window_opt = 500, window_val = 50, coarse = .25){

  unity <- function(x) {x / sqrt(sum(x^2))} ## normalize columns of a matrix to make correlation computation faster
  
  ####################################################
  ##Clean the marks and compute the smooth residuals##
  ####################################################
  
  data1 <- matrix(data1[round((0.01*nrow(data1))):round(0.99*nrow(data1)),], ncol = 1)
  data2 <- matrix(data2[round((0.01*nrow(data2))):round(0.99*nrow(data2)),], ncol = 1)
  
  ##Normalize the tool marks
  if (!is.null(coarse)) {
    y1 <- data1 - lowess(y = data1,  x = 1:nrow(data1), f= coarse)$y
    y2 <- data2 - lowess(y = data2,  x = 1:nrow(data2), f= coarse)$y
  } else {
    if (any(is.na(data1)) | any(is.na(data2))) browser()
    
    y1 = data1
    y2 = data2
  }
    
  
  ############################################
  ##Compute the observed maximum correlation##
  ############################################
  
  #####################
  ##Optimization step##
  #####################
  ##Each column in these matrices corresponds to a window in the respective tool mark
  y1_mat_opt <- matrix(NA, ncol = length(1:(length(y1) - (window_opt - 1))), nrow = window_opt)
  for(l in 1:(length(y1) - (window_opt - 1))){
    y1_mat_opt[,l] <- y1[l:(l+(window_opt - 1))]
  }
  y2_mat_opt <- matrix(NA, ncol = length(1:(length(y2) - (window_opt - 1))), nrow = window_opt)
  for(l in 1:(length(y2) - (window_opt - 1))){
    y2_mat_opt[,l] <- y2[l:(l+(window_opt - 1))]
  }
  
  ##Compute the correlation between all pairs of windows for the two marks
  ##Rows in the following matrix are mark 2, columns are mark 1
  y2_mat_opt <- apply(scale(y2_mat_opt), 2, unity)
  y1_mat_opt <- apply(scale(y1_mat_opt), 2, unity)
  corr_mat_opt <- t(y2_mat_opt) %*% y1_mat_opt ##correlation matrix
  max_corr_opt_loc <- which(corr_mat_opt == max(corr_mat_opt, na.rm=TRUE), arr.ind = TRUE) ##pair of windows maximizing the correlation
  
  
  ###################
  ##Validation step##
  ###################
  ##Each column in these matrices corresponds to a window in the respective tool mark
  y1_mat_val <- matrix(NA, ncol = length(1:(length(y1) - (window_val - 1))), nrow = window_val)
  for(l in 1:(length(y1) - (window_val - 1))){
    y1_mat_val[,l] <- y1[l:(l+(window_val - 1))]
  }
  y2_mat_val <- matrix(NA, ncol = length(1:(length(y2) - (window_val - 1))), nrow = window_val)
  for(l in 1:(length(y2) - (window_val - 1))){
    y2_mat_val[,l] <- y2[l:(l+(window_val - 1))]
  }
  
  ##Compute the correlation between all pairs of windows for the two marks
  ##Rows in the following matrix are mark 2, columns are mark 1
  y2_mat_val <- apply(scale(y2_mat_val), 2, unity)
  y1_mat_val <- apply(scale(y1_mat_val), 2, unity)
  corr_mat_val <- t(y2_mat_val) %*% y1_mat_val
  
  ##Pull out the correlations that correspond to windows with the same offset as the largest correlation found in the optimization step
  same_shift <- data.frame(row = NA, col = NA, U = NA)
  rows <- max_corr_opt_loc[1] + (window_opt - window_val)
  cols <- max_corr_opt_loc[2] + (window_opt - window_val)
  while(rows + window_val < nrow(corr_mat_val) & cols + window_val < ncol(corr_mat_val)){
    
    rows <- rows + window_val
    cols <- cols + window_val
    same_shift <- rbind(same_shift, c(rows, cols, corr_mat_val[rows,cols]))
    
  }
  rows <- max_corr_opt_loc[1]
  cols <- max_corr_opt_loc[2]
  while(rows - window_val > 0 & cols - window_val > 0){
    
    rows <- rows - window_val
    cols <- cols - window_val
    same_shift <- rbind(same_shift, c(rows, cols, corr_mat_val[rows, cols]))
    
  }
  same_shift <- same_shift[-1,]
  
  ##Pull out the correlations that correspond to windows with different offset as the largest correlation found in the optimization step
  ##along a single anti-diagonal
  diff_shift <- data.frame(row = NA, col = NA, U = NA)
  rows <- max_corr_opt_loc[1] + (window_opt - window_val)
  cols <- max_corr_opt_loc[2]
  while(rows + window_val < nrow(corr_mat_val) & cols - window_val > 0){
    
    rows <- rows + window_val
    cols <- cols - window_val
    diff_shift <- rbind(diff_shift, c(rows, cols, corr_mat_val[rows,cols]))
    
  }
  rows <- max_corr_opt_loc[1]
  cols <- max_corr_opt_loc[2] + (window_opt - window_val)
  while(rows - window_val > 0 & cols + window_val < ncol(corr_mat_val)){
    
    rows <- rows - window_val
    cols <- cols + window_val
    diff_shift <- rbind(diff_shift, c(rows, cols, corr_mat_val[rows, cols]))
    
  }
  diff_shift <- diff_shift[-1,]
  
  ######################################
  ##Compute the Ustatistic if possible##
  ######################################
  if(nrow(same_shift) == 0 | nrow(diff_shift) == 0) {
    
    obs_U <- NA
    n <- length(same_shift$U)
    m <- length(diff_shift$U)
    
  }
  
  if(nrow(same_shift) != 0 & nrow(diff_shift) != 0) {
    
    ranks <- rank(c(same_shift$U, diff_shift$U))
    Rx <- ranks[seq_along(same_shift$U)]
    Ry <- ranks[-(1:length(Rx))]
    n <- length(same_shift$U)
    m <- length(diff_shift$U)
    N <- n + m
    
    t <- sum(Rx) ##Test statistic...sum of sample one ranks
    t1 <- (t - n*((N + 1) / 2)) / sqrt( ((n*m)/(N*(N-1)))*sum(c(Rx^2, Ry^2)) - ((n*m*(N+1)^2) / (4*(N-1)))) ##Standardized test statistics
    obs_U <- t1
    
  }
  pval <- 1 - pnorm(obs_U)

  list(same_shift_n = n, ##Number of same shift offsets used
       diff_shift_n = m, ##Number of different shift offsets used
       U = obs_U, ##observed U-statistic
       p_value = pval, ##Corresponding p-value
       same_shift = same_shift$U,
       diff_shift = diff_shift$U,
       locations = max_corr_opt_loc)
}


#' Adjusted Chumbley Non-Random
#' 
#' This function computes the Chumbley U-Statistic on systemically chosen pairs of windows rather 
#' than the original method which selects randomly chosen pairs of windows
#' @param data1 The first tool mark as a 1-column matrix
#' @param data2 The second tool mark as a 1-column matrix
#' @param window_opt size of the window to be used in the optimization step
#' @param window_val Size of the window to be used in the validation step
#' @param coarse smoothing parameter for the normalization smooth
#' @importFrom stats pnorm
#' @importFrom ggplot2 ggplot
#' @export
#' @return list with
#' \itemize{
#' \item {same_shift_n} Number of same shift offsets used
#' \item {diff_shift_n} Number of different shift offsets used
#' \item {U} observed U statistic
#' \item {p_value} Corresponding p-value
#' \item {same_shift} correlation values corresponding to the same shift offset
#' \item {diff_shift} correlation values corresponding to the different shift offset
#' }
#' @examples 
#' res2 <- chumbley_non_random_adj(ameslab$profile[[1]], ameslab$profile[[2]])
#' 
chumbley_non_random_adj <- function(data1, data2, window_opt = 500, window_val = 50, coarse = .25){
  
  unity <- function(x) {x / sqrt(sum(x^2))} ## normalize columns of a matrix to make correlation computation faster
  
  ####################################################
  ##Clean the marks and compute the smooth residuals##
  ####################################################
  
  data1 <- matrix(data1[round((0.01*nrow(data1))):round(0.99*nrow(data1)),], ncol = 1)
  data2 <- matrix(data2[round((0.01*nrow(data2))):round(0.99*nrow(data2)),], ncol = 1)
  
  ##Normalize the tool marks
  if (!is.null(coarse)) {
    y1 <- data1 - lowess(y = data1,  x = 1:nrow(data1), f= coarse)$y
    y2 <- data2 - lowess(y = data2,  x = 1:nrow(data2), f= coarse)$y
  } else {
    if (any(is.na(data1)) | any(is.na(data2))) browser()
    
    y1 = data1
    y2 = data2
  }
  
  
  ############################################
  ##Compute the observed maximum correlation##
  ############################################
  
  #####################
  ##Optimization step##
  #####################
  ##Each column in these matrices corresponds to a window in the respective tool mark
  y1_mat_opt <- matrix(NA, ncol = length(1:(length(y1) - (window_opt - 1))), nrow = window_opt)
  for(l in 1:(length(y1) - (window_opt - 1))){
    y1_mat_opt[,l] <- y1[l:(l+(window_opt - 1))]
  }
  y2_mat_opt <- matrix(NA, ncol = length(1:(length(y2) - (window_opt - 1))), nrow = window_opt)
  for(l in 1:(length(y2) - (window_opt - 1))){
    y2_mat_opt[,l] <- y2[l:(l+(window_opt - 1))]
  }
  
  ##Compute the correlation between all pairs of windows for the two marks
  ##Rows in the following matrix are mark 2, columns are mark 1
  y2_mat_opt <- apply(scale(y2_mat_opt), 2, unity)
  y1_mat_opt <- apply(scale(y1_mat_opt), 2, unity)
  corr_mat_opt <- t(y2_mat_opt) %*% y1_mat_opt ##correlation matrix
  max_corr_opt_loc <- which(corr_mat_opt == max(corr_mat_opt, na.rm=TRUE), arr.ind = TRUE) ##pair of windows maximizing the correlation
  
  
  ###################
  ##Validation step##
  ###################
  ##Each column in these matrices corresponds to a window in the respective tool mark
  y1_mat_val <- matrix(NA, ncol = length(1:(length(y1) - (window_val - 1))), nrow = window_val)
  for(l in 1:(length(y1) - (window_val - 1))){
    y1_mat_val[,l] <- y1[l:(l+(window_val - 1))]
  }
  y2_mat_val <- matrix(NA, ncol = length(1:(length(y2) - (window_val - 1))), nrow = window_val)
  for(l in 1:(length(y2) - (window_val - 1))){
    y2_mat_val[,l] <- y2[l:(l+(window_val - 1))]
  }
  
  ##Compute the correlation between all pairs of windows for the two marks
  ##Rows in the following matrix are mark 2, columns are mark 1
  y2_mat_val <- apply(scale(y2_mat_val), 2, unity)
  y1_mat_val <- apply(scale(y1_mat_val), 2, unity)
  corr_mat_val <- t(y2_mat_val) %*% y1_mat_val
  
  ##Pull out the correlations that correspond to windows with the same offset as the largest correlation found in the optimization step
  shift <- max_corr_opt_loc[2]-max_corr_opt_loc[1]
  rows <- NULL
  if (length(y1)-window_val > 1)
    rows <- seq(from=1, to=length(y1)-window_val, by=window_val)
  
  cols <- NULL
  if (length(y2)-window_val > 1+shift)
    cols <- seq(from=1+shift, to=length(y2)-window_val, by=window_val) 
  
  idx <- min(length(rows), length(cols))
  my_same_shift <- data.frame()
  my_diff_shift <- data.frame()
  
  if (idx > 0) {
  my_same_shift <- data.frame(rows=rows[1:idx], 
                           cols=cols[1:idx])
  my_same_shift <- subset(my_same_shift, rows>0 & cols>0 & 
                            rows <= dim(corr_mat_val)[1] & cols <= dim(corr_mat_val)[2])
  my_same_shift$U <- as.vector(apply(my_same_shift, MARGIN = 1,
                                     function(y) {
                                       corr_mat_val[y[1], y[2]]
                                     }))
  
  ##Pull out the correlations that correspond to windows with different offset as the largest correlation found in the optimization step
  ##along a single anti-diagonal
  my_diff_shift <- data.frame(rows=rows[1:idx], 
                              cols=cols[c(2:idx,1)])
  my_diff_shift <- subset(my_diff_shift, rows>0 & cols>0 &
                            rows <= dim(corr_mat_val)[1] & cols <= dim(corr_mat_val)[2])
  my_diff_shift$U <- as.vector(apply(my_diff_shift, MARGIN = 1,
                                     function(y) {
                                       corr_mat_val[y[1], y[2]]
                                     }))
  }
  ######################################
  ##Compute the Ustatistic if possible##
  ######################################
  if(nrow(my_same_shift) == 0 | nrow(my_diff_shift) == 0) {
    
    obs_U <- NA
    n <- length(my_same_shift$U)
    m <- length(my_diff_shift$U)
    
  }
  
  if(nrow(my_same_shift) != 0 & nrow(my_diff_shift) != 0) {
    
    ranks <- rank(c(my_same_shift$U, my_diff_shift$U))
    Rx <- ranks[seq_along(my_same_shift$U)]
    Ry <- ranks[-(1:length(Rx))]
    n <- length(my_same_shift$U)
    m <- length(my_diff_shift$U)
    N <- n + m
    
    t <- sum(Rx) ##Test statistic...sum of sample one ranks
    t1 <- (t - n*((N + 1) / 2)) / sqrt( ((n*m)/(N*(N-1)))*sum(c(Rx^2, Ry^2)) - ((n*m*(N+1)^2) / (4*(N-1)))) ##Standardized test statistics
    obs_U <- t1
    
  }
  pval <- 1 - pnorm(obs_U)
  
  list(my_same_shift_n = n, ##Number of same shift offsets used
       my_diff_shift_n = m, ##Number of different shift offsets used
       U = obs_U, ##observed U-statistic
       p_value = pval, ##Corresponding p-value
       same_shift = my_same_shift$U,
       diff_shift = my_diff_shift$U,
       locations = max_corr_opt_loc)
}

