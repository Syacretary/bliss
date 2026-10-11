#include <jni.h>

#include <cstdlib>
#include <string>
#include <unistd.h>
#include <vector>

#include "node.h"

extern "C" JNIEXPORT jint JNICALL
Java_com_syacretary_bliss_NodeRuntimeBridge_startNode(
    JNIEnv* env,
    jobject /* instance */,
    jobjectArray arguments,
    jstring session_key) {
  const jsize count = env->GetArrayLength(arguments);
  if (count < 7 || session_key == nullptr) return static_cast<jint>(2);

  std::vector<std::string> values;
  values.reserve(static_cast<size_t>(count));
  for (jsize index = 0; index < count; ++index) {
    auto value = static_cast<jstring>(env->GetObjectArrayElement(arguments, index));
    if (value == nullptr) return static_cast<jint>(2);
    const char* chars = env->GetStringUTFChars(value, nullptr);
    if (chars == nullptr) return static_cast<jint>(2);
    values.emplace_back(chars);
    env->ReleaseStringUTFChars(value, chars);
    env->DeleteLocalRef(value);
  }

  // argv: node, entry, runtime dir, no-backup data dir, cache dir, port, bearer.
  setenv("TMPDIR", values[4].c_str(), 1);
  setenv("HOME", values[3].c_str(), 1);
  setenv("NODE_COMPILE_CACHE", (values[4] + "/node-compile-cache").c_str(), 1);
  setenv("NODE_COMPILE_CACHE_PORTABLE", "1", 1);
  setenv("NODE_OPTIONS", "--max-old-space-size-percentage=40", 1);
  const char* secret = env->GetStringUTFChars(session_key, nullptr);
  if (secret == nullptr) return static_cast<jint>(2);
  setenv("BLISS_SESSION_KEY", secret, 1);
  env->ReleaseStringUTFChars(session_key, secret);
  if (chdir(values[2].c_str()) != 0) return static_cast<jint>(2);

  std::vector<char*> argv;
  argv.reserve(values.size());
  for (std::string& value : values) argv.push_back(value.data());
  return static_cast<jint>(node::Start(static_cast<int>(argv.size()), argv.data()));
}
