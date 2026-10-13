#pragma once

#include "api/geode_api.h"

#include <array>
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>

namespace geode::flutter {

// One session per Flutter engine. Only the analysis worker consumes the player's
// SPSC PCM tap; GL resources are created/rendered/destroyed on the texture thread.
class NativeSession final {
public:
    NativeSession(AAssetManager* assets, std::string cache);
    ~NativeSession();
    NativeSession(const NativeSession&) = delete;
    NativeSession& operator=(const NativeSession&) = delete;

    geode_player* player() const { return player_; }
    void resetAnalysis() { reset_.store(true); }
    bool features(GeodeFeatureFrame& out);
    void setDsp(const std::array<float, 16>& config);
    void createSurface(int width, int height);
    void releaseSurface();
    void render(double time);
    bool scene(const std::string& id);
    bool param(const std::string& name, float value);
    void reducedMotion(bool enabled);
    void milk(const std::string& path);
    void milkTextures(const std::string& path);
    void touch(float x, float y, float dx, float dy, float dt, float strength);
    std::string scenes();
    std::string error();

private:
    void analyze();
    void installDsp(int sampleRate);
    AAssetManager* assets_;
    std::string cache_;
    geode_player* player_;
    std::atomic<bool> running_{true};
    std::atomic<bool> reset_{false};
    std::mutex frameMutex_;
    GeodeFeatureFrame frame_{};
    bool hasFrame_ = false;
    std::mutex vizMutex_;
    geode_viz* viz_ = nullptr;
    std::string scene_ = "aurora";
    std::string milkPath_;
    std::string milkTextures_;
    bool reducedMotion_ = false;
    std::unordered_map<std::string, float> params_;
    std::mutex dspMutex_;
    // enabled, ten band gains in dB, bass (0..1), loudness dB, preamp dB,
    // crossfeed, limiter. New chains are installed instead of mutating live DSP.
    std::array<float, 16> dspConfig_{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1};
    std::atomic<bool> dspDirty_{true};
    std::thread worker_;
};

} // namespace geode::flutter
