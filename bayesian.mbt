///|
/// `Bayesian` implements a simplified Bayesian Online Change Point Detection using a Normal-Gamma conjugate prior.
pub struct Bayesian {
  hazard_rate : Double
  mut run_length_probs : Array[Double]
  // Sufficient statistics for each run length
  mut mu_t : Array[Double]
  mut kappa_t : Array[Double]
  mut alpha_t : Array[Double]
  mut beta_t : Array[Double]
  // Prior parameters
  mu0 : Double
  kappa0 : Double
  alpha0 : Double
  beta0 : Double
  max_run_length : Int
}

///|
/// Creates a new Bayesian Online Change Point Detector.
pub fn Bayesian::new(
  hazard_rate? : Double = 0.01,
  mu0? : Double = 0.0,
  kappa0? : Double = 1.0,
  alpha0? : Double = 1.0,
  beta0? : Double = 1.0,
  max_run_length? : Int = 100,
) -> Bayesian {
  {
    hazard_rate,
    run_length_probs: [1.0],
    mu_t: [mu0],
    kappa_t: [kappa0],
    alpha_t: [alpha0],
    beta_t: [beta0],
    mu0,
    kappa0,
    alpha0,
    beta0,
    max_run_length,
  }
}

///|
/// Student-T probability density function (simplified)
fn student_t_pdf(
  x : Double,
  mu : Double,
  variance : Double,
  _nu : Double,
) -> Double {
  // We use a simplified Gaussian approximation for speed since this is a demonstration
  let diff = x - mu
  let exp_val = @math.exp(-(diff * diff) / (2.0 * variance))
  exp_val / (2.0 * 3.14159265358979323846 * variance).sqrt()
}

///|
/// Updates the detector and returns the probability of a change point at the current step.
pub fn Bayesian::update(self : Bayesian, value : Double) -> Double {
  let len = self.run_length_probs.length()

  // 1. Evaluate predictive probabilities for each run length
  let pred_probs = Array::make(len, 0.0)
  for i in 0..<len {
    // Predictive variance based on parameters
    let variance = self.beta_t[i] *
      (self.kappa_t[i] + 1.0) /
      (self.alpha_t[i] * self.kappa_t[i])
    let mean = self.mu_t[i]
    pred_probs[i] = student_t_pdf(value, mean, variance, 2.0 * self.alpha_t[i])
  }

  // 2. Calculate growth probabilities and change probability
  let mut change_prob = 0.0
  let new_probs = Array::make(len + 1, 0.0)
  let mut sum_probs = 0.0

  for i in 0..<len {
    let p = self.run_length_probs[i] * pred_probs[i]
    // Probability of change point
    change_prob += p * self.hazard_rate
    // Probability of growing run length
    new_probs[i + 1] = p * (1.0 - self.hazard_rate)
  }
  new_probs[0] = change_prob

  // Normalize
  for i in 0..<=len {
    sum_probs += new_probs[i]
  }
  for i in 0..<=len {
    new_probs[i] = new_probs[i] / sum_probs
  }

  // Truncate to max_run_length to save memory
  let truncated_len = if new_probs.length() > self.max_run_length {
    self.max_run_length
  } else {
    new_probs.length()
  }
  let truncated_probs = Array::make(truncated_len, 0.0)
  for i in 0..<truncated_len {
    truncated_probs[i] = new_probs[i]
  }
  self.run_length_probs = truncated_probs

  // 3. Update sufficient statistics
  let new_mu = Array::make(self.run_length_probs.length(), self.mu0)
  let new_kappa = Array::make(self.run_length_probs.length(), self.kappa0)
  let new_alpha = Array::make(self.run_length_probs.length(), self.alpha0)
  let new_beta = Array::make(self.run_length_probs.length(), self.beta0)

  for i in 0..<len {
    if i + 1 < self.run_length_probs.length() {
      new_kappa[i + 1] = self.kappa_t[i] + 1.0
      new_alpha[i + 1] = self.alpha_t[i] + 0.5
      new_mu[i + 1] = (self.kappa_t[i] * self.mu_t[i] + value) /
        new_kappa[i + 1]
      let diff = value - self.mu_t[i]
      new_beta[i + 1] = self.beta_t[i] +
        self.kappa_t[i] * diff * diff / (2.0 * new_kappa[i + 1])
    }
  }

  self.mu_t = new_mu
  self.kappa_t = new_kappa
  self.alpha_t = new_alpha
  self.beta_t = new_beta

  return new_probs[0]
}

///|
/// Rich result form of the Bayesian update.
pub fn Bayesian::update_result(
  self : Bayesian,
  value : Double,
  index? : Int = 0,
) -> DetectionResult {
  let probability = self.update(value)
  DetectionResult::new(
    probability > 0.5,
    probability,
    probability,
    DistributionShift,
    index,
    evidence=probability,
  )
}
