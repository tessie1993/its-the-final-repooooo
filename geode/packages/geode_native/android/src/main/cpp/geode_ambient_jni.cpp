#include "AmbientAudioBus.hpp"

#include <android/asset_manager_jni.h>
#include <jni.h>
#include <memory>
#include <stdexcept>
#include <string>

namespace {
struct AmbientRenderer {
    geode_viz* viz = nullptr;
    uint64_t cursor = 0;
    std::array<float, 8192> pcm{};
    ~AmbientRenderer() {
        if (viz) { geode_viz_release_scenes(viz); geode_viz_destroy(viz); }
    }
};
AmbientRenderer* renderer(jlong handle) { return reinterpret_cast<AmbientRenderer*>(handle); }
std::string text(JNIEnv* env, jstring value) {
    if (!value) return {};
    const char* utf = env->GetStringUTFChars(value, nullptr);
    if (!utf) return {};
    std::string result(utf);
    env->ReleaseStringUTFChars(value, utf);
    return result;
}
void fail(JNIEnv* env, const char* message) {
    env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), message);
}
}

#define AMBIENT_METHOD(name) Java_dev_geode_geode_1native_GeodeAmbientBindings_##name
extern "C" {
JNIEXPORT jlong JNICALL AMBIENT_METHOD(create)(JNIEnv* env, jclass, jobject assets,
        jstring cache, jint width, jint height) {
    try {
        auto r = std::make_unique<AmbientRenderer>();
        r->viz = geode_viz_create(AAssetManager_fromJava(env, assets), text(env, cache).c_str());
        if (!r->viz) throw std::runtime_error("Cannot create ambient visualizer");
        geode_viz_surface_created(r->viz);
        geode_viz_surface_changed(r->viz, width, height);
        if (!geode_viz_set_scene(r->viz, "water")) throw std::runtime_error("Cannot load water scene");
        return reinterpret_cast<jlong>(r.release());
    } catch (const std::exception& error) { fail(env, error.what()); return 0; }
}
JNIEXPORT void JNICALL AMBIENT_METHOD(render)(JNIEnv* env, jclass, jlong handle, jdouble seconds) {
    if (!handle) return;
    try {
        auto* r = renderer(handle);
        GeodeFeatureFrame frame{};
        size_t count = geode::flutter::AmbientAudioBus::instance().read(frame, r->pcm.data(), r->pcm.size(), r->cursor);
        geode_viz_set_features(r->viz, &frame);
        if (count > 0) geode_viz_push_pcm(r->viz, r->pcm.data(), static_cast<int>(count));
        geode_viz_render(r->viz, seconds, 0);
    } catch (const std::exception& error) { fail(env, error.what()); }
}
JNIEXPORT void JNICALL AMBIENT_METHOD(scene)(JNIEnv* env, jclass, jlong handle, jstring id) {
    if (handle && !geode_viz_set_scene(renderer(handle)->viz, text(env, id).c_str()))
        fail(env, "This ambient scene could not load");
}
JNIEXPORT void JNICALL AMBIENT_METHOD(param)(JNIEnv* env, jclass, jlong handle, jstring name, jfloat value) {
    if (handle) geode_viz_set_param(renderer(handle)->viz, text(env, name).c_str(), value);
}
JNIEXPORT void JNICALL AMBIENT_METHOD(reducedMotion)(JNIEnv*, jclass, jlong handle, jboolean enabled) {
    if (handle) geode_viz_set_reduced_motion(renderer(handle)->viz, enabled);
}
JNIEXPORT void JNICALL AMBIENT_METHOD(milk)(JNIEnv* env, jclass, jlong handle, jstring path) {
    if (handle) geode_viz_load_milk_preset(renderer(handle)->viz, text(env, path).c_str());
}
JNIEXPORT void JNICALL AMBIENT_METHOD(touch)(JNIEnv*, jclass, jlong handle, jfloat x, jfloat y,
        jfloat dx, jfloat dy, jfloat dt, jfloat strength) {
    if (handle) geode_viz_queue_touch_stroke(renderer(handle)->viz, x, y, dx, dy, dt, strength);
}
JNIEXPORT void JNICALL AMBIENT_METHOD(close)(JNIEnv*, jclass, jlong handle) { delete renderer(handle); }
}
