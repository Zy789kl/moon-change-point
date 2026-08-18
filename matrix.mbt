///|
/// Small dense matrix type used for low-dimensional covariance diagnostics.
pub struct SquareMatrix {
  size : Int
  data : Array[Double]
}

///|
pub fn SquareMatrix::new(size : Int, fill? : Double = 0.0) -> SquareMatrix {
  let safe_size = if size < 1 { 1 } else { size }
  { size: safe_size, data: Array::make(safe_size * safe_size, fill) }
}

///|
pub fn SquareMatrix::identity(size : Int) -> SquareMatrix {
  let matrix = SquareMatrix::new(size)
  for i in 0..<matrix.size {
    matrix.set(i, i, 1.0)
  }
  matrix
}

///|
pub fn SquareMatrix::size(self : SquareMatrix) -> Int {
  self.size
}

///|
pub fn SquareMatrix::get(
  self : SquareMatrix,
  row : Int,
  column : Int,
) -> Double {
  if row < 0 || column < 0 || row >= self.size || column >= self.size {
    0.0
  } else {
    self.data[row * self.size + column]
  }
}

///|
pub fn SquareMatrix::set(
  self : SquareMatrix,
  row : Int,
  column : Int,
  value : Double,
) -> Unit {
  if row >= 0 && column >= 0 && row < self.size && column < self.size {
    self.data[row * self.size + column] = value
  }
}

///|
pub fn SquareMatrix::diagonal(self : SquareMatrix) -> Array[Double] {
  let result : Array[Double] = []
  for i in 0..<self.size {
    result.push(self.get(i, i))
  }
  result
}

///|
pub fn SquareMatrix::transpose(self : SquareMatrix) -> SquareMatrix {
  let result = SquareMatrix::new(self.size)
  for row in 0..<self.size {
    for column in 0..<self.size {
      result.set(column, row, self.get(row, column))
    }
  }
  result
}

///|
pub fn SquareMatrix::add(
  self : SquareMatrix,
  other : SquareMatrix,
) -> SquareMatrix {
  let size = if self.size < other.size { self.size } else { other.size }
  let result = SquareMatrix::new(size)
  for row in 0..<size {
    for column in 0..<size {
      result.set(row, column, self.get(row, column) + other.get(row, column))
    }
  }
  result
}

///|
pub fn SquareMatrix::scale(
  self : SquareMatrix,
  factor : Double,
) -> SquareMatrix {
  let result = SquareMatrix::new(self.size)
  for row in 0..<self.size {
    for column in 0..<self.size {
      result.set(row, column, self.get(row, column) * factor)
    }
  }
  result
}

///|
pub fn SquareMatrix::multiply(
  self : SquareMatrix,
  other : SquareMatrix,
) -> SquareMatrix {
  let size = if self.size < other.size { self.size } else { other.size }
  let result = SquareMatrix::new(size)
  for row in 0..<size {
    for column in 0..<size {
      let mut total = 0.0
      for k in 0..<size {
        total += self.get(row, k) * other.get(k, column)
      }
      result.set(row, column, total)
    }
  }
  result
}

///|
pub fn SquareMatrix::quadratic_form(
  self : SquareMatrix,
  vector : Array[Double],
) -> Double {
  let size = if vector.length() < self.size {
    vector.length()
  } else {
    self.size
  }
  let mut result = 0.0
  for row in 0..<size {
    for column in 0..<size {
      result += vector[row] * self.get(row, column) * vector[column]
    }
  }
  result
}

///|
pub fn SquareMatrix::regularize(self : SquareMatrix, diagonal : Double) -> Unit {
  for i in 0..<self.size {
    self.set(i, i, self.get(i, i) + diagonal)
  }
}

///|
pub fn SquareMatrix::determinant(self : SquareMatrix) -> Double {
  if self.size == 1 {
    self.get(0, 0)
  } else if self.size == 2 {
    self.get(0, 0) * self.get(1, 1) - self.get(0, 1) * self.get(1, 0)
  } else {
    let mut determinant = 0.0
    for column in 0..<self.size {
      let minor = SquareMatrix::new(self.size - 1)
      for row in 1..<self.size {
        for minor_column in 0..<(self.size - 1) {
          let source_column = if minor_column < column {
            minor_column
          } else {
            minor_column + 1
          }
          minor.set(row - 1, minor_column, self.get(row, source_column))
        }
      }
      let sign_factor = if column % 2 == 0 { 1.0 } else { -1.0 }
      determinant += sign_factor * self.get(0, column) * minor.determinant()
    }
    determinant
  }
}

///|
pub fn diagonal_mahalanobis(
  vector : Array[Double],
  means : Array[Double],
  variances : Array[Double],
) -> Double {
  let size = if vector.length() < means.length() {
    vector.length()
  } else {
    means.length()
  }
  let mut total = 0.0
  for i in 0..<size {
    let scale = if variances[i] < 1.0e-12 { 1.0e-12 } else { variances[i] }
    let difference = vector[i] - means[i]
    total += difference * difference / scale
  }
  total.sqrt()
}
