#pragma once

// Turns the edges seen on the RF data pin into frames of raw pulse timings.
//
// The receiver of the RF module has no squelch: without a signal its output
// is a stream of random short pulses. This class
//   - folds pulses shorter than a filter time into their neighbours,
//   - cuts the stream into frames at every pause longer than the idle time,
//   - drops frames that are too short to be a real transmission.
//
// A frame is a list of signed durations in microseconds: positive = signal
// present (mark), negative = no signal (space). The last entry is the pause
// that ended the frame. This is the same convention ESPHome uses for raw
// remote codes, so a frame can be pasted into any tool that understands them.
//
// Like protocol.h it has no dependency on ESPHome and is tested on a PC.

#include <cstddef>
#include <cstdint>
#include <vector>

namespace esphome::bl3361 {

class PulseFramer {
 public:
  PulseFramer(uint32_t filter_us, uint32_t idle_us, size_t min_pulses, size_t max_pulses)
      : filter_us_(filter_us), idle_us_(idle_us), min_pulses_(min_pulses), max_pulses_(max_pulses) {}

  /// Adds a finished pulse: how long the line stayed at `level`. Returns true
  /// when this completed a frame, which is then available from frame().
  bool push(uint32_t duration_us, bool level) {
    if (!this->have_run_) {
      // Leading glitches are not worth a frame of their own.
      if (duration_us >= this->filter_us_)
        this->start_run_(level, duration_us);
      return false;
    }
    if (level == this->run_level_) {
      // Same level as the run: it continues, together with any glitch between.
      this->run_us_ += this->glitch_us_ + duration_us;
      this->glitch_us_ = 0;
      return false;
    }
    if (duration_us < this->filter_us_) {
      // Short pulse of the other level: remember it, it is merged into the
      // run if the run's level comes back, and dropped otherwise.
      this->glitch_us_ += duration_us;
      return false;
    }
    const bool done = this->commit_(this->run_level_, this->run_us_);
    this->start_run_(level, duration_us);
    return done;
  }

  /// Call when the line has been quiet for the idle time. Ends the frame in
  /// progress, if any. Returns true when that produced a frame.
  bool flush() {
    if (!this->have_run_)
      return false;
    bool done;
    if (this->run_level_) {
      done = this->commit_(true, this->run_us_);
      // The pause that ended the frame was never seen as an edge; add it.
      if (!done)
        done = this->commit_(false, this->idle_us_);
    } else {
      // The line already rests in its quiet state: that run is the pause.
      done = this->commit_(false, this->run_us_ > this->idle_us_ ? this->run_us_ : this->idle_us_);
    }
    this->have_run_ = false;
    this->glitch_us_ = 0;
    return done;
  }

  /// Forgets everything that is in progress.
  void reset() {
    this->have_run_ = false;
    this->glitch_us_ = 0;
    this->frame_.clear();
  }

  bool has_pending() const { return this->have_run_ || !this->frame_.empty(); }

  /// The last completed frame. Valid until the next push() or flush().
  const std::vector<int32_t> &frame() const { return this->ready_; }

  uint32_t dropped_frames() const { return this->dropped_; }

 protected:
  void start_run_(bool level, uint32_t duration_us) {
    this->run_level_ = level;
    this->run_us_ = duration_us;
    this->glitch_us_ = 0;
    this->have_run_ = true;
  }

  static int32_t signed_duration_(bool level, uint32_t duration_us) {
    // Cap so a long pause cannot overflow the sign convention.
    const int32_t capped = duration_us > 0x3FFFFFFF ? 0x3FFFFFFF : static_cast<int32_t>(duration_us);
    return level ? capped : -capped;
  }

  /// Appends a pulse to the frame being built. Returns true when it closed the frame.
  bool commit_(bool level, uint32_t duration_us) {
    this->frame_.push_back(signed_duration_(level, duration_us));
    const bool is_pause = duration_us >= this->idle_us_;
    if (!is_pause && this->frame_.size() < this->max_pulses_)
      return false;
    // The frame is over, either by a pause or because it grew too long.
    const bool keep = this->frame_.size() > this->min_pulses_;
    if (keep) {
      this->ready_.swap(this->frame_);
    } else if (this->frame_.size() > 1) {
      this->dropped_++;
    }
    this->frame_.clear();
    return keep;
  }

  uint32_t filter_us_;
  uint32_t idle_us_;
  size_t min_pulses_;
  size_t max_pulses_;

  bool have_run_{false};
  bool run_level_{false};
  uint32_t run_us_{0};
  uint32_t glitch_us_{0};
  std::vector<int32_t> frame_;
  std::vector<int32_t> ready_;
  uint32_t dropped_{0};
};

}  // namespace esphome::bl3361
