#' Conducting Score Tests for Interaction
#' 
#' Conduct score tests comparing a fitted model and a more general alternative
#' model.
#' 
#' There are two tests available here:
#' 
#' \bold{Asymptotic Test}
#' 
#' This is based on the classical variance component test to construct a
#' testing procedure for the hypothesis about Gaussian process function.
#' 
#' \bold{Bootstrap Test}
#' 
#' When it comes to small sample size, we can use bootstrap test instead, which
#' can give valid tests with moderate sample sizes and requires similar
#' computational effort to a permutation test.
#' 
#' @param Y (vector of length n) Reponses of the dataframe.
#' @param X (dataframe, n*p) Fixed effects variables in the dataframe (could
#' contains several subfactors).
#' @param K_list (list of matrices) A nested list of kernel term matrices. 
#' The first level corresponds to each base kernel function in kern_func_list, 
#' the second level corresponds to each kernel term specified in the formula.
#' @param K_int (matrix, n*n) The kernel matrix to be tested.
#' @param mode (character) A character string indicating which tuning parameter
#' criteria is to be used.
#' @param strategy (character) A character string indicating which ensemble
#' strategy is to be used.
#' @param beta_exp (numeric/character) A numeric value specifying the parameter
#' when strategy = "exp" \code{\link{ensemble_exp}}.
#' @param test (character) A character string indicating which test is to be
#' used.
#' @param lambda (numeric) A numeric string specifying the range of tuning parameter 
#' to be chosen. The lower limit of lambda must be above 0.
#' @param B (integer) A numeric value indicating times of resampling when test
#' = "boot".
#' @return \item{pvalue}{(numeric) p-value of the test.}
#' \item{lambda}{(numeric) The selected tuning parameter based on the estimated
#' ensemble kernel matrix.} \item{u_hat}{(vector of length K) A vector of
#' weights of the kernels in the library.}
#' @author Wenying Deng
#' @seealso method: \code{\link{generate_kernel}}
#' 
#' mode: \code{\link{tuning}}
#' 
#' strategy: \code{\link{ensemble}}
#' @references Xihong Lin. Variance component testing in generalised linear
#' models with random effects. June 1997.
#' 
#' Arnab Maity and Xihong Lin. Powerful tests for detecting a gene effect in
#' the presence of possible gene-gene interactions using garrote kernel
#' machines. December 2011.
#' 
#' Petra Bu ̊zˇkova ́, Thomas Lumley, and Kenneth Rice. Permutation and
#' parametric bootstrap tests for gene-gene and gene-environment interactions.
#' January 2011.
#' @examples
#' 
#' rbf_kern_func <- generate_kernel(method = "rbf", l = 1.25)
#' K_int <- parse_kernel_terms(y ~ k(x1):k(x3, x4):x2, rbf_kern_func, dora)
#' testing(Y = CVEK:::model_matrices$y, X = CVEK:::model_matrices$X, 
#' K_list = CVEK:::model_matrices$K, K_int = K_int[[1]], 
#' mode = "loocv", strategy = "stack",
#' beta_exp = 1, test = "boot", lambda = exp(seq(-10, 5)), 
#' B = 100)
#' 
#' 
#' 
#' @export testing
testing <- function(Y, X, K_list, K_int, 
                    mode = "loocv", strategy = "stack", 
                    beta_exp = 1, test = "boot", 
                    lambda = exp(seq(-10, 5)), B = 100) {
  
  n <- length(Y)
  if(sum(X[, 1] == 1) != n) {
    X <- cbind(matrix(1, nrow = n, ncol = 1), X)
  }
  result <- estimation(Y, X, K_list, mode, strategy, beta, lambda)
  lambda <- result$lambda
  beta0 <- result$beta
  alpha0 <- result$alpha
  K_ens <- result$K
  u_hat <- result$u_hat
  y_fixed <- X %*% beta0
  sigma2_hat <- estimate_sigma2(Y, X, lambda, y_fixed, alpha0, K_ens)
  tau_hat <- sigma2_hat / lambda
  
  func_name <- paste0("test_", test)
  
  pvalue <- do.call(func_name, list(Y = Y, X = X, K_int = K_int, 
                                    y_fixed = y_fixed, alpha0 = alpha0,
                                    K_ens = K_ens, sigma2_hat = sigma2_hat, 
                                    tau_hat = tau_hat, B = B))
  
  list(pvalue = pvalue, lambda = lambda, u_hat = u_hat)
}





#' Conducting Score Tests for Interaction Using Asymptotic Test
#' 
#' Conduct score tests comparing a fitted model and a more general alternative
#' model using asymptotic test.
#' 
#' \bold{Asymptotic Test}
#' 
#' This is based on the classical variance component test to construct a
#' testing procedure for the hypothesis about Gaussian process function.
#' 
#' @param Y (vector of length n) Reponses of the dataframe.
#' @param X (dataframe, n*p) Fixed effects variables in the dataframe (could
#' contains several subfactors).
#' @param K_int (matrix, n*n) The kernel matrix to be tested.
#' @param y_fixed (vector of length n) Estimated fixed effects of the
#' responses.
#' @param alpha0 (vector of length n) Random effects estimator of the estimated
#' ensemble kernel matrix.
#' @param K_ens (matrix, n*n) Estimated ensemble kernel matrix.
#' @param sigma2_hat (numeric) The estimated noise of the fixed effects.
#' @param tau_hat (numeric) The estimated noise of the random effects.
#' @param B (integer) A numeric value indicating times of resampling when test
#' = "boot".
#' @return \item{pvalue}{(numeric) p-value of the test.}
#' @author Wenying Deng
#' @seealso method: \code{\link{generate_kernel}}
#' 
#' mode: \code{\link{tuning}}
#' 
#' strategy: \code{\link{ensemble}}
#' @references Xihong Lin. Variance component testing in generalised linear
#' models with random effects. June 1997.
#' 
#' Arnab Maity and Xihong Lin. Powerful tests for detecting a gene effect in
#' the presence of possible gene-gene interactions using garrote kernel
#' machines. December 2011.
#' 
#' Petra Bu ̊zˇkova ́, Thomas Lumley, and Kenneth Rice. Permutation and
#' parametric bootstrap tests for gene-gene and gene-environment interactions.
#' January 2011.
test_asym <- function(Y, X, K_int, y_fixed, alpha0,
                      K_ens, sigma2_hat, tau_hat, B) {
  
  n <- length(Y)
  score_chi <-
    compute_stat(Y, K_int, y_fixed, K_ens, sigma2_hat, tau_hat)
  K0 <- K_ens
  V0_inv <- ginv(tau_hat * K0 + sigma2_hat * diag(n))
  P0_mat <- V0_inv - V0_inv %*%
    X %*% ginv(t(X) %*% V0_inv %*% X) %*% t(X) %*% V0_inv
  drV0_tau <- K0
  drV0_sigma2 <- diag(n)
  drV0_del <- tau_hat * K_int
  I0 <- compute_info(P0_mat,
                     mat_del = drV0_del, mat_sigma2 = drV0_sigma2,
                     mat_tau = drV0_tau)
  tot_dim <- ncol(I0)
  I_deldel <-
    I0[1, 1] -
    I0[1, 2:tot_dim] %*% ginv(I0[2:tot_dim, 2:tot_dim]) %*% I0[2:tot_dim, 1]
  md <- tau_hat * tr(K_int %*% P0_mat) / 2
  m_chi <- I_deldel / (2 * md)
  d_chi <- md / m_chi
  pvalue <- 1 - pchisq(score_chi / m_chi, d_chi)
  
  pvalue
}





#' Conducting Score Tests for Interaction Using Bootstrap Test
#' 
#' Conduct score tests comparing a fitted model and a more general alternative
#' model using bootstrap test.
#' 
#' \bold{Bootstrap Test}
#' 
#' When it comes to small sample size, we can use bootstrap test instead, which
#' can give valid tests with moderate sample sizes and requires similar
#' computational effort to a permutation test.
#' 
#' @param Y (vector of length n) Reponses of the dataframe.
#' @param X (dataframe, n*p) Fixed effects variables in the dataframe (could
#' contains several subfactors).
#' @param K_int (matrix, n*n) The kernel matrix to be tested.
#' @param y_fixed (vector of length n) Estimated fixed effects of the
#' responses.
#' @param alpha0 (vector of length n) Random effects estimator of the estimated
#' ensemble kernel matrix.
#' @param K_ens (matrix, n*n) Estimated ensemble kernel matrix.
#' @param sigma2_hat (numeric) The estimated noise of the fixed effects.
#' @param tau_hat (numeric) The estimated noise of the random effects.
#' @param B (integer) A numeric value indicating times of resampling when test
#' = "boot".
#' @return \item{pvalue}{(numeric) p-value of the test.}
#' @author Wenying Deng
#' @seealso method: \code{\link{generate_kernel}}
#' 
#' mode: \code{\link{tuning}}
#' 
#' strategy: \code{\link{ensemble}}
#' @references Xihong Lin. Variance component testing in generalised linear
#' models with random effects. June 1997.
#' 
#' Arnab Maity and Xihong Lin. Powerful tests for detecting a gene effect in
#' the presence of possible gene-gene interactions using garrote kernel
#' machines. December 2011.
#' 
#' Petra Bu ̊zˇkova ́, Thomas Lumley, and Kenneth Rice. Permutation and
#' parametric bootstrap tests for gene-gene and gene-environment interactions.
#' January 2011.
test_boot <- function(Y, X, K_int, y_fixed, alpha0,
                      K_ens, sigma2_hat, tau_hat, B) {
  
  n <- length(Y)
  meanY <- K_ens %*% alpha0 + y_fixed
  bs_test <- sapply(1:B, function(k) {
    Ystar <- meanY + rnorm(n, sd = sqrt(sigma2_hat))
    compute_stat(Ystar, K_int, y_fixed, K_ens, sigma2_hat, tau_hat)
  })
  original_test <-
    compute_stat(Y, K_int, y_fixed, K_ens, sigma2_hat, tau_hat)
  pvalue <- mean(as.numeric(original_test) <= bs_test)
  
  pvalue
}
