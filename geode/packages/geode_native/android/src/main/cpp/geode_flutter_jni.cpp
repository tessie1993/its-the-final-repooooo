#include "NativeSession.hpp"

#include <android/asset_manager_jni.h>
#include <jni.h>
#include <unistd.h>

#include <algorithm>
#include <exception>
#include <string>

using geode::flutter::NativeSession;

namespace {
NativeSession* session(jlong handle) { return reinterpret_cast<NativeSession*>(handle); }
std::string string(JNIEnv* env, jstring value) {
    if (!value) return {};
    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (!chars) return {};
    std::string result(chars);
    env->ReleaseStringUTFChars(value, chars);
    return result;
}
void fail(JNIEnv* env, const char* message) {
    env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), message);
}
} // namespace

#define JNI_METHOD(name) Java_dev_geode_geode_1native_NativeBindings_##name

extern "C" {

JNIEXPORT jlong JNICALL JNI_METHOD(create)(JNIEnv* env, jclass, jobject assets, jstring cache) {
    try {
        return reinterpret_cast<jlong>(new NativeSession(AAssetManager_fromJava(env, assets), string(env, cache)));
    } catch (const std::exception& error) { fail(env, error.what()); return 0; }
}

JNIEXPORT void JNICALL JNI_METHOD(destroy)(JNIEnv*, jclass, jlong handle) { delete session(handle); }

JNIEXPORT void JNICALL JNI_METHOD(open)(JNIEnv*, jclass, jlong handle, jint fd,
                                       jlong offset, jlong length, jlong token, jboolean next) {
    if (!handle) { if (fd >= 0) close(fd); return; }
    if (next) geode_player_set_next(session(handle)->player(), fd, offset, length, token);
    else {
        session(handle)->resetAnalysis();
        geode_player_open(session(handle)->player(), fd, offset, length, token);
    }
}

JNIEXPORT void JNICALL JNI_METHOD(command)(JNIEnv*, jclass, jlong handle, jint command, jlong value, jdouble extra) {
    if (!handle) return;
    auto* s = session(handle);
    auto* p = s->player();
    switch (command) {
        case 0: geode_player_play(p); break;
        case 1: geode_player_pause(p); break;
        case 2: geode_player_stop(p); s->resetAnalysis(); break;
        case 3: geode_player_seek(p, std::max<jlong>(0, value) * 1000); s->resetAnalysis(); break;
        case 4: geode_player_set_volume(p, static_cast<float>(extra)); break;
        case 5: geode_player_set_crossfade(p, static_cast<int>(value), static_cast<int>(extra)); break;
        default: break;
    }
}

JNIEXPORT jlongArray JNICALL JNI_METHOD(snapshot)(JNIEnv* env, jclass, jlong handle) {
    auto* p = session(handle)->player();
    const jlong values[] = {
        geode_player_state(p), geode_player_play_when_ready(p), geode_player_position_us(p) / 1000,
        geode_player_duration_us(p) / 1000, geode_player_current_token(p), geode_player_output_sample_rate(p)
    };
    jlongArray out = env->NewLongArray(6);
    if (out) env->SetLongArrayRegion(out, 0, 6, values);
    return out;
}

JNIEXPORT jfloatArray JNICALL JNI_METHOD(features)(JNIEnv* env, jclass, jlong handle) {
    static_assert(sizeof(GeodeFeatureFrame) == GEODE_FEATURE_FRAME_FLOATS * sizeof(float));
    GeodeFeatureFrame frame{};
    if (!session(handle)->features(frame)) return nullptr;
    auto out = env->NewFloatArray(GEODE_FEATURE_FRAME_FLOATS);
    if (out) env->SetFloatArrayRegion(out, 0, GEODE_FEATURE_FRAME_FLOATS, reinterpret_cast<const float*>(&frame));
    return out;
}

JNIEXPORT jstring JNICALL JNI_METHOD(error)(JNIEnv* env, jclass, jlong handle) {
    return env->NewStringUTF(session(handle)->error().c_str());
}

JNIEXPORT void JNICALL JNI_METHOD(surfaceCreated)(JNIEnv* env, jclass, jlong handle, jint width, jint height) {
    try { session(handle)->createSurface(width, height); }
    catch (const std::exception& error) { fail(env, error.what()); }
}

JNIEXPORT void JNICALL JNI_METHOD(surfaceDestroyed)(JNIEnv*, jclass, jlong handle) {
    session(handle)->releaseSurface();
}

JNIEXPORT void JNICALL JNI_METHOD(render)(JNIEnv* env, jclass, jlong handle, jdouble time) {
    try { session(handle)->render(time); }
    catch (const std::exception& error) { fail(env, error.what()); }
}

JNIEXPORT jboolean JNICALL JNI_METHOD(scene)(JNIEnv* env, jclass, jlong handle, jstring id) {
    return session(handle)->scene(string(env, id));
}

JNIEXPORT jboolean JNICALL JNI_METHOD(param)(JNIEnv* env, jclass, jlong handle, jstring name, jdouble value) {
    return session(handle)->param(string(env, name), static_cast<float>(value));
}

JNIEXPORT void JNICALL JNI_METHOD(reducedMotion)(JNIEnv*, jclass, jlong handle, jboolean on) {
    session(handle)->reducedMotion(on);
}

JNIEXPORT void JNICALL JNI_METHOD(milk)(JNIEnv* env, jclass, jlong handle, jstring path) {
    session(handle)->milk(string(env, path));
}

JNIEXPORT void JNICALL JNI_METHOD(milkTextures)(JNIEnv* env, jclass, jlong handle, jstring path) {
    session(handle)->milkTextures(string(env, path));
}

JNIEXPORT jstring JNICALL JNI_METHOD(scenes)(JNIEnv* env, jclass, jlong handle) {
    return env->NewStringUTF(session(handle)->scenes().c_str());
}

JNIEXPORT void JNICALL JNI_METHOD(touch)(JNIEnv*, jclass, jlong handle, jfloat x, jfloat y,
                                        jfloat dx, jfloat dy, jfloat dt, jfloat strength) {
    session(handle)->touch(x, y, dx, dy, dt, strength);
}

JNIEXPORT void JNICALL JNI_METHOD(equalizer)(JNIEnv* env, jclass, jlong handle, jfloatArray values) {
    if (!values || env->GetArrayLength(values) != 16) { fail(env, "Expected 16 DSP settings"); return; }
    std::array<float, 16> config{};
    env->GetFloatArrayRegion(values, 0, 16, config.data());
    session(handle)->setDsp(config);
}

JNIEXPORT jobject JNICALL JNI_METHOD(readTags)(JNIEnv* env, jclass, jint fd) {
    geode_tags* tags = geode_tags_read(fd); // consumes and closes fd
    jclass mapClass = env->FindClass("java/util/HashMap");
    jmethodID construct = env->GetMethodID(mapClass, "<init>", "()V");
    jmethodID put = env->GetMethodID(mapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
    jobject map = env->NewObject(mapClass, construct);
    if (!tags || !map) { geode_tags_destroy(tags); return map; }
    auto field = [&](const char* key, jobject value) {
        jstring name = env->NewStringUTF(key);
        jobject previous = env->CallObjectMethod(map, put, name, value);
        if (previous) env->DeleteLocalRef(previous);
        env->DeleteLocalRef(name);
        env->DeleteLocalRef(value);
    };
    const char* keys[] = {"title", "artist", "album", "albumArtist", "genre", "comment"};
    for (int i = 0; i < GEODE_TAG_TEXT_COUNT; ++i)
        field(keys[i], env->NewStringUTF(geode_tags_text(tags, static_cast<GeodeTagText>(i))));
    jclass numberClass = env->FindClass("java/lang/Double");
    jmethodID number = env->GetMethodID(numberClass, "<init>", "(D)V");
    auto numeric = [&](const char* key, double value) { field(key, env->NewObject(numberClass, number, value)); };
    numeric("year", geode_tags_year(tags));
    numeric("track", geode_tags_track(tags));
    numeric("durationMs", geode_tags_duration_ms(tags));
    float trackGain = 0, trackPeak = 0, albumGain = 0, albumPeak = 0;
    int mask = geode_tags_replaygain(tags, &trackGain, &trackPeak, &albumGain, &albumPeak);
    if (mask & GEODE_TAG_TRACK_GAIN) numeric("trackGainDb", trackGain);
    if (mask & GEODE_TAG_TRACK_PEAK) numeric("trackPeak", trackPeak);
    if (mask & GEODE_TAG_ALBUM_GAIN) numeric("albumGainDb", albumGain);
    if (mask & GEODE_TAG_ALBUM_PEAK) numeric("albumPeak", albumPeak);
    geode_tags_destroy(tags);
    return map;
}

} // extern "C"
