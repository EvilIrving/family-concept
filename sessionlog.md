## 真机联调切换到 Cloudflare 正式域名 · 2026-04-14 10:28 · Codex

这次真机显示“网络🔗失败”，根因是 iOS 端把 API 地址写成了 `http://localhost:8787`。模拟器访问本机服务时还能工作，真机里的 `localhost` 指向手机自己，所以请求一定失败。

后续决定直接走 Cloudflare 正式后端，统一使用 `https://api.kitchen.onecat.dev`。这样真机、模拟器和后续外部测试都走同一条 HTTPS 链路，省掉局域网 IP、ATS 例外和本地穿透问题。对应修改已经落在 `kitchen/kitchen/Info.plist`、`kitchen/kitchen/Services/APIClient.swift` 和 `worker/wrangler.jsonc`。

部署时又遇到一个 Cloudflare 新规则：免费版 Durable Objects 需要用 `new_sqlite_classes` 声明迁移，旧写法 `new_classes` 会直接部署失败，报错代码是 `10097`。这个坑已经在 `worker/wrangler.jsonc` 修正，后面如果再新建 Durable Object，继续沿用 SQLite migration 写法。

README 也补上了正式部署说明，部署目标域名固定为 `api.kitchen.onecat.dev`，流程是 `pnpm d1:migrate:remote` 后再 `pnpm deploy`，部署后先验证 `/api/v1/health` 和 `/api/v1/bootstrap`。

## 修复多因素导致的 Android 应用启动失败问题

time: 2026-03-12

source: gemini-cli

topic: Android Build and Launch Debugging

tags: [bugfix, build, android, gradle]

summary:
应用在 Android 模拟器上启动失败（超时）。经过排查，发现问题由多个因素共同导致：Dart 代码层面的编译错误、静态分析警告（包括缺失依赖和废弃 API），以及最关键的本地 Java 环境配置错误。通过逐一修复这些问题，最终成功在 Android 模拟器上构建并启动了应用。

decisions:

1. **修复 Dart 编译错误:** 修正了 `lib/data/database_helper.dart` 中 `Sqflite.firstIntValue` 方法的参数类型错误。
2. **解决静态分析问题:**
    * 为项目添加了缺失的 `path` 依赖。
    * 移除了 `database_helper.dart` 中不必要的类型转换。
    * 将项目中所有已废弃的 `withOpacity()` 调用替换为推荐的 `withAlpha()`。
3. **诊断和修复构建环境:**
    * 多次尝试 `launch_app` 均超时，怀疑是 Android 构建问题。
    * 直接在 `android` 目录下运行 `./gradlew assembleDebug`，明确了错误是“找不到 Java 运行时”。
    * 运行 `flutter doctor -v` 查找到正确的 `JAVA_HOME` 路径。
    * 设置正确的 `JAVA_HOME` 环境变量后，成功执行了 Gradle 构建。
4. **成功启动:** 在解决了所有代码和环境问题后，`launch_app` 命令成功启动了应用。

reason:
* `launch_app` 工具的超时错误信息不够具体，无法直接定位到是 Dart 代码问题还是原生构建环境问题。通过使用 `analyze_files` 定位代码问题，并直接调用 `gradlew` 来获取更详细的原生构建错误日志，是解决此类复合问题的有效策略。`flutter doctor` 默认不显示 Java 路径，需要使用 `-v` 参数获取详细信息。

refs:
* `lib/data/database_helper.dart`
* `flutter doctor -v`
* `cd android && export JAVA_HOME=... && ./gradlew assembleDebug`
