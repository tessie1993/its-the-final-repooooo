#include "NativeSession.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <stdexcept>

namespace geode::flutter {

NativeSession::NativeSession(AAssetManager* assets, std::string cache)
    : assets_(assets), cache_(std::move(cache)), player_(geode_player_create()),
      worker_([this] { analyze(); }) {}

NativeSession::~NativeSession() {
    running_.store(false);
    worker_.join();
    // Retire the last DSP through the player before destroying it. A live chain
    // must never be freed while an Oboe callback can still reference it.
    geode_player_set_dsp(player_, nullptr);
    geode_player_destroy(player_);
}

bool NativeSession::features(GeodeFeatureFrame& out) {
    std::lock_guard lock(frameMutex_);
    out = frame_;
    return hasFrame_;
}

void NativeSession::setDsp(const std::array<float, 16>& config) {
    std::lock_guard lock(dspMutex_);
    dspConfig_ = config;
    dspDirty_.store(true);
}

void NativeSession::installDsp(int rate) {
    std::array<float, 16> config;
    {
        std::lock_guard lock(dspMutex_);
        config = dspConfig_;
        dspDirty_.store(false);
    }
    geode_dsp* dsp = geode_dsp_create(rate, 2);
    geode_dsp_set_enabled(dsp, config[0] > 0.5f);
    for (int i = 0; i < 10; ++i)
        geode_dsp_set_band(dsp, i, static_cast<int>(std::lround(config[i + 1] * 100)));
    geode_dsp_set_bass_boost(dsp, static_cast<int>(config[11] * 1000));
    geode_dsp_set_loudness_mb(dsp, static_cast<int>(config[12] * 100));
    geode_dsp_set_gain_db(dsp, config[13]);
    geode_dsp_set_crossfeed(dsp, config[14] > 0.5f);
    geode_dsp_set_limiter(dsp, config[15] > 0.5f);
    geode_player_set_dsp(player_, dsp);
}

void NativeSession::analyze() {
    geode_analysis* analysis = nullptr;
    int rate = 0;
    bool silence = true;
    std::array<float, 2048> stereo{};
    std::array<float, 1024> mono{};
    while (running_.load()) {
        const int currentRate = geode_player_output_sample_rate(player_);
        if (currentRate > 0 && currentRate != rate) {
            rate = currentRate;
            geode_analysis_destroy(analysis);
            analysis = geode_analysis_create(rate, 2048, 100.f);
            installDsp(rate);
        } else if (rate > 0 && dspDirty_.load()) {
            installDsp(rate);
        }
        if (reset_.exchange(false)) {
            geode_analysis_reset(analysis);
            std::lock_guard lock(frameMutex_);
            frame_ = {};
            hasFrame_ = false;
        }
        const size_t count = geode_player_read_tap(player_, stereo.data(), mono.size());
        if (count > 0 && analysis) {
            silence = false;
            geode_analysis_push(analysis, stereo.data(), count, 2);
            GeodeFeatureFrame next{};
            bool updated = false;
            while (geode_analysis_pull(analysis, &next)) updated = true;
            if (updated) {
                std::lock_guard lock(frameMutex_);
                frame_ = next;
                hasFrame_ = true;
            }
            for (size_t i = 0; i < count; ++i)
                mono[i] = (stereo[2 * i] + stereo[2 * i + 1]) * 0.5f;
            std::lock_guard lock(vizMutex_);
            if (viz_) {
                if (updated) geode_viz_set_features(viz_, &next);
                geode_viz_push_pcm(viz_, mono.data(), static_cast<int>(count));
            }
        } else {
            if (!silence && (!geode_player_play_when_ready(player_) ||
                            geode_player_state(player_) == GEODE_PLAYER_ENDED)) {
                silence = true;
                GeodeFeatureFrame quiet{};
                {
                    std::lock_guard lock(frameMutex_);
                    frame_ = quiet;
                    hasFrame_ = true;
                }
                std::lock_guard lock(vizMutex_);
                if (viz_) geode_viz_set_features(viz_, &quiet);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(4));
        }
    }
    geode_analysis_destroy(analysis);
}

void NativeSession::createSurface(int width, int height) {
    std::lock_guard lock(vizMutex_);
    viz_ = geode_viz_create(assets_, cache_.c_str());
    if (!viz_) throw std::runtime_error("Cannot create native visualizer");
    geode_viz_surface_created(viz_);
    geode_viz_surface_changed(viz_, width, height);
    geode_viz_set_reduced_motion(viz_, reducedMotion_);
    geode_viz_set_scene(viz_, scene_.c_str());
    for (const auto& [name, value] : params_) geode_viz_set_param(viz_, name.c_str(), value);
    if (!milkTextures_.empty()) geode_viz_set_milk_texture_dir(viz_, milkTextures_.c_str());
    if (!milkPath_.empty()) geode_viz_load_milk_preset(viz_, milkPath_.c_str());
}

void NativeSession::releaseSurface() {
    std::lock_guard lock(vizMutex_);
    if (viz_) {
        geode_viz_release_scenes(viz_);
        geode_viz_destroy(viz_);
        viz_ = nullptr;
    }
}

void NativeSession::render(double time) {
    std::lock_guard lock(vizMutex_);
    if (viz_) geode_viz_render(viz_, time, 0);
}

bool NativeSession::scene(const std::string& id) {
    std::lock_guard lock(vizMutex_);
    if (viz_ && !geode_viz_set_scene(viz_, id.c_str())) return false;
    scene_ = id;
    return true;
}

bool NativeSession::param(const std::string& name, float value) {
    std::lock_guard lock(vizMutex_);
    bool known = false;
    for (int i = 0; i < geode_viz_param_count(); ++i)
        if (name == geode_viz_param_name(i)) { known = true; break; }
    if (!known) return false;
    params_[name] = value;
    return !viz_ || geode_viz_set_param(viz_, name.c_str(), value);
}

void NativeSession::reducedMotion(bool enabled) {
    std::lock_guard lock(vizMutex_);
    reducedMotion_ = enabled;
    if (viz_) geode_viz_set_reduced_motion(viz_, enabled);
}

void NativeSession::milk(const std::string& path) {
    std::lock_guard lock(vizMutex_);
    milkPath_ = path;
    if (viz_) geode_viz_load_milk_preset(viz_, path.c_str());
}

void NativeSession::milkTextures(const std::string& path) {
    std::lock_guard lock(vizMutex_);
    milkTextures_ = path;
    if (viz_) geode_viz_set_milk_texture_dir(viz_, path.c_str());
}

void NativeSession::touch(float x, float y, float dx, float dy, float dt, float strength) {
    std::lock_guard lock(vizMutex_);
    if (viz_) geode_viz_queue_touch_stroke(viz_, x, y, dx, dy, dt, strength);
}

std::string NativeSession::scenes() {
    std::lock_guard lock(vizMutex_);
    // Registry enumeration does not create GL resources.
    geode_viz* target = viz_ ? viz_ : geode_viz_create(assets_, cache_.c_str());
    const size_t size = geode_viz_scene_ids(target, nullptr, 0);
    std::string result(size + 1, '\0');
    geode_viz_scene_ids(target, result.data(), result.size());
    result.resize(size);
    if (!viz_) geode_viz_destroy(target);
    return result;
}

std::string NativeSession::error() {
    const size_t size = geode_player_last_error(player_, nullptr, 0);
    std::string result(size + 1, '\0');
    geode_player_last_error(player_, result.data(), result.size());
    result.resize(size);
    return result;
}

} // namespace geode::flutter
