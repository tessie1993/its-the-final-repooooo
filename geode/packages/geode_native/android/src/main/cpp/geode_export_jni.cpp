#include "api/geode_api.h"
#include <android/asset_manager_jni.h>
#include <jni.h>
#include <memory>
#include <string>
#include <vector>

namespace {
struct ExportSession {
    geode_viz* viz = nullptr;
    geode_analysis* analysis = nullptr;
    std::string scene;
    ~ExportSession() {
        if (viz) { geode_viz_release_scenes(viz); geode_viz_destroy(viz); }
        if (analysis) geode_analysis_destroy(analysis);
    }
};
std::string string(JNIEnv* env, jstring value) {
    if (!value) return {};
    const char* text = env->GetStringUTFChars(value, nullptr);
    if (!text) return {};
    std::string result(text);
    env->ReleaseStringUTFChars(value, text);
    return result;
}
void fail(JNIEnv* env, const char* message) {
    env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), message);
}
}
#define EXPORT_JNI(name) Java_dev_geode_geode_1native_GeodeExportBindings_##name
extern "C" {
JNIEXPORT jlong JNICALL EXPORT_JNI(create)(JNIEnv* env, jclass, jobject assets,
        jstring cache, jint width, jint height) {
    auto session = std::make_unique<ExportSession>();
    session->viz = geode_viz_create(AAssetManager_fromJava(env, assets), string(env, cache).c_str());
    session->analysis = geode_analysis_create(48000, 2048, 100.f);
    if (!session->viz || !session->analysis) { fail(env, "Could not create offline renderer"); return 0; }
    geode_viz_set_offscreen(session->viz, 1);
    geode_viz_surface_created(session->viz);
    geode_viz_surface_changed(session->viz, width, height);
    return reinterpret_cast<jlong>(session.release());
}
JNIEXPORT void JNICALL EXPORT_JNI(frame)(JNIEnv* env, jclass, jlong handle,
        jstring scene, jdouble seconds, jfloat energy, jfloatArray samples,
        jintArray overlay, jint width, jint height) {
    auto* session = reinterpret_cast<ExportSession*>(handle);
    if (!session || !samples || !overlay || width <= 0 || height <= 0 ||
        static_cast<int64_t>(width) * height != env->GetArrayLength(overlay)) {
        fail(env, "Invalid offline frame"); return;
    }
    const auto id = string(env, scene);
    if (session->scene != id) {
        geode_viz_cut(session->viz);
        if (!geode_viz_set_scene(session->viz, id.c_str())) { fail(env, "Unknown export scene"); return; }
        session->scene = id;
    }
    const auto count = env->GetArrayLength(samples);
    std::vector<float> pcm(count);
    env->GetFloatArrayRegion(samples, 0, count, pcm.data());
    geode_analysis_push(session->analysis, pcm.data(), count / 2, 2);
    GeodeFeatureFrame features{};
    while (geode_analysis_pull(session->analysis, &features)) {
        features.macroEnergy *= energy;
        geode_viz_set_features(session->viz, &features);
    }
    std::vector<float> mono(count / 2);
    for (int i = 0; i < count / 2; ++i) mono[i] = (pcm[i * 2] + pcm[i * 2 + 1]) * .5f;
    geode_viz_push_pcm(session->viz, mono.data(), static_cast<int>(mono.size()));
    std::vector<jint> pixels(static_cast<size_t>(width) * height);
    env->GetIntArrayRegion(overlay, 0, static_cast<jsize>(pixels.size()), pixels.data());
    geode_viz_set_overlay_rgba(session->viz, reinterpret_cast<uint32_t*>(pixels.data()), width, height);
    geode_viz_render(session->viz, seconds, 0);
}
JNIEXPORT void JNICALL EXPORT_JNI(close)(JNIEnv*, jclass, jlong handle) {
    delete reinterpret_cast<ExportSession*>(handle);
}
}
