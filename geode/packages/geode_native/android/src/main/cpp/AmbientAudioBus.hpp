#pragma once

#include "api/geode_api.h"
#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <mutex>

namespace geode::flutter {

// A bounded process-local multicast snapshot. Wallpaper/dream renderers never
// reference a player's lifetime, and each GL thread tracks its own PCM cursor.
class AmbientAudioBus {
public:
    static AmbientAudioBus& instance() {
        static AmbientAudioBus bus;
        return bus;
    }

    void publish(const GeodeFeatureFrame* frame, const float* mono, size_t count) {
        std::lock_guard guard(mutex_);
        if (frame) frame_ = *frame;
        for (size_t i = 0; i < count; ++i) pcm_[written_++ % pcm_.size()] = mono[i];
        updated_ = std::chrono::steady_clock::now();
    }

    void silence() {
        const GeodeFeatureFrame quiet{};
        const std::array<float, 512> zeros{};
        publish(&quiet, zeros.data(), zeros.size());
    }

    size_t read(GeodeFeatureFrame& frame, float* out, size_t capacity, uint64_t& cursor) {
        std::lock_guard guard(mutex_);
        if (std::chrono::steady_clock::now() - updated_ > std::chrono::milliseconds(300)) {
            frame = {};
            cursor = written_;
            std::fill_n(out, std::min<size_t>(capacity, 512), 0.f);
            return std::min<size_t>(capacity, 512);
        }
        frame = frame_;
        const uint64_t oldest = written_ > pcm_.size() ? written_ - pcm_.size() : 0;
        cursor = std::clamp(cursor, oldest, written_);
        size_t count = std::min<uint64_t>(capacity, written_ - cursor);
        for (size_t i = 0; i < count; ++i) out[i] = pcm_[(cursor + i) % pcm_.size()];
        cursor += count;
        return count;
    }

private:
    std::mutex mutex_;
    GeodeFeatureFrame frame_{};
    std::array<float, 8192> pcm_{};
    uint64_t written_ = 0;
    std::chrono::steady_clock::time_point updated_{};
};
} // namespace geode::flutter
