///|
/// A bounded ring buffer for numeric streaming windows.
pub struct DoubleWindow {
  capacity : Int
  values : Array[Double]
  mut start : Int
  mut length : Int
}

///|
/// Creates a fixed-capacity window. Non-positive capacities are normalized to one.
pub fn DoubleWindow::new(capacity : Int) -> DoubleWindow {
  let safe_capacity = if capacity < 1 { 1 } else { capacity }
  {
    capacity: safe_capacity,
    values: Array::make(safe_capacity, 0.0),
    start: 0,
    length: 0,
  }
}

///|
pub fn DoubleWindow::capacity(self : DoubleWindow) -> Int {
  self.capacity
}

///|
pub fn DoubleWindow::length(self : DoubleWindow) -> Int {
  self.length
}

///|
pub fn DoubleWindow::is_full(self : DoubleWindow) -> Bool {
  self.length == self.capacity
}

///|
pub fn DoubleWindow::is_empty(self : DoubleWindow) -> Bool {
  self.length == 0
}

///|
/// Adds a value and returns the value evicted from a full window, if any.
pub fn DoubleWindow::push(self : DoubleWindow, value : Double) -> Double? {
  if self.length < self.capacity {
    let index = (self.start + self.length) % self.capacity
    self.values[index] = value
    self.length += 1
    None
  } else {
    let evicted = self.values[self.start]
    self.values[self.start] = value
    self.start = (self.start + 1) % self.capacity
    Some(evicted)
  }
}

///|
fn DoubleWindow::physical_index(self : DoubleWindow, index : Int) -> Int {
  (self.start + index) % self.capacity
}

///|
pub fn DoubleWindow::get(self : DoubleWindow, index : Int) -> Double? {
  if index < 0 || index >= self.length {
    None
  } else {
    Some(self.values[self.physical_index(index)])
  }
}

///|
pub fn DoubleWindow::first(self : DoubleWindow) -> Double? {
  self.get(0)
}

///|
pub fn DoubleWindow::last(self : DoubleWindow) -> Double? {
  self.get(self.length - 1)
}

///|
pub fn DoubleWindow::to_array(self : DoubleWindow) -> Array[Double] {
  let result : Array[Double] = []
  for i in 0..<self.length {
    result.push(self.values[self.physical_index(i)])
  }
  result
}

///|
pub fn DoubleWindow::clear(self : DoubleWindow) -> Unit {
  self.start = 0
  self.length = 0
}

///|
pub fn DoubleWindow::sum(self : DoubleWindow) -> Double {
  sum(self.to_array())
}

///|
pub fn DoubleWindow::mean(self : DoubleWindow) -> Double {
  mean(self.to_array())
}

///|
pub fn DoubleWindow::variance(self : DoubleWindow) -> Double {
  variance(self.to_array())
}

///|
pub fn DoubleWindow::standard_deviation(self : DoubleWindow) -> Double {
  standard_deviation(self.to_array())
}

///|
pub fn DoubleWindow::median(self : DoubleWindow) -> Double {
  median(self.to_array())
}

///|
pub fn DoubleWindow::quantile(
  self : DoubleWindow,
  probability : Double,
) -> Double {
  quantile(self.to_array(), probability)
}

///|
pub fn DoubleWindow::slope(self : DoubleWindow) -> Double {
  linear_slope(self.to_array())
}

///|
pub fn DoubleWindow::snapshot(self : DoubleWindow) -> StatsSummary {
  let values = self.to_array()
  let accumulator = OnlineMoments::new()
  for value in values {
    accumulator.push(value)
  }
  accumulator.summary(median=median(self.to_array()))
}

///|
/// The policy applied when a timestamp is older than the accepted watermark.
pub(all) enum LateDataPolicy {
  Drop
  KeepForCorrection
  ReplaceSameTimestamp
}

///|
/// A timestamped sample that has passed through a reorder buffer.
pub struct OrderedPoint {
  point : SignalPoint
  late : Bool
  arrival_order : Int
}

///|
/// A small bounded reorder buffer for streams with late data.
pub struct ReorderBuffer {
  capacity : Int
  policy : LateDataPolicy
  pending : Array[OrderedPoint]
  mut watermark : Int64
  mut arrival_order : Int
  mut dropped : Int
  mut late_count : Int
}

///|
pub fn ReorderBuffer::new(
  capacity? : Int = 64,
  policy? : LateDataPolicy = KeepForCorrection,
) -> ReorderBuffer {
  {
    capacity: if capacity < 1 {
      1
    } else {
      capacity
    },
    policy,
    pending: [],
    watermark: -9223372036854775807L,
    arrival_order: 0,
    dropped: 0,
    late_count: 0,
  }
}

///|
pub fn ReorderBuffer::watermark(self : ReorderBuffer) -> Int64 {
  self.watermark
}

///|
pub fn ReorderBuffer::pending_count(self : ReorderBuffer) -> Int {
  self.pending.length()
}

///|
pub fn ReorderBuffer::dropped_count(self : ReorderBuffer) -> Int {
  self.dropped
}

///|
pub fn ReorderBuffer::late_count(self : ReorderBuffer) -> Int {
  self.late_count
}

///|
fn insert_ordered(buffer : Array[OrderedPoint], item : OrderedPoint) -> Unit {
  let mut position = buffer.length()
  for i in 0..<buffer.length() {
    if item.point.timestamp < buffer[i].point.timestamp {
      position = i
      break
    }
  }
  buffer.push(item)
  let mut i = buffer.length() - 1
  while i > position {
    buffer[i] = buffer[i - 1]
    i -= 1
  }
  buffer[position] = item
}

///|
/// Inserts a point. Returned points are safe to process in timestamp order.
pub fn ReorderBuffer::push(
  self : ReorderBuffer,
  point : SignalPoint,
) -> Array[OrderedPoint] {
  self.arrival_order += 1
  let is_late = point.timestamp < self.watermark
  if is_late {
    self.late_count += 1
  }
  match self.policy {
    Drop if is_late => {
      self.dropped += 1
      []
    }
    ReplaceSameTimestamp => {
      let mut replaced = false
      for i in 0..<self.pending.length() {
        if self.pending[i].point.timestamp == point.timestamp {
          self.pending[i] = {
            point,
            late: is_late,
            arrival_order: self.arrival_order,
          }
          replaced = true
          break
        }
      }
      if !replaced {
        insert_ordered(self.pending, {
          point,
          late: is_late,
          arrival_order: self.arrival_order,
        })
      }
      self.flush_if_needed()
    }
    _ => {
      insert_ordered(self.pending, {
        point,
        late: is_late,
        arrival_order: self.arrival_order,
      })
      self.flush_if_needed()
    }
  }
}

///|
fn ReorderBuffer::flush_if_needed(self : ReorderBuffer) -> Array[OrderedPoint] {
  let result : Array[OrderedPoint] = []
  while self.pending.length() > self.capacity {
    let item = self.pending.remove(0)
    self.watermark = item.point.timestamp
    result.push(item)
  }
  result
}

///|
/// Flushes every pending item at the end of a stream.
pub fn ReorderBuffer::flush(self : ReorderBuffer) -> Array[OrderedPoint] {
  let result : Array[OrderedPoint] = []
  while self.pending.length() > 0 {
    let item = self.pending.remove(0)
    if item.point.timestamp > self.watermark {
      self.watermark = item.point.timestamp
    }
    result.push(item)
  }
  result
}

///|
/// Returns a copy of the buffered points without changing the buffer.
pub fn ReorderBuffer::peek(self : ReorderBuffer) -> Array[OrderedPoint] {
  let result : Array[OrderedPoint] = []
  for item in self.pending {
    result.push(item)
  }
  result
}
