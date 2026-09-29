# TimeManager

TimeManager 是一个仍在开发中的 Flutter 学习时间与计划管理 App。

目前支持：

- 自由新增、编辑和删除学习计划
- 批量选择和删除学习计划
- 每个计划可独立设置进入后台时是否自动暂停
- 自定义首页激励文案，通过醒目的学习按钮开始或继续计划
- 按计划进行学习倒计时，并可暂停或调整本次剩余时间
- 保存剩余时间和已学习进度，下次进入时继续
- 查看今日学习统计与各计划完成率
- 使用本地存储保留计划、进度、学习记录和设置
- 支持简体中文和 English 界面切换，并保存语言偏好
- 倒计时结束可选择铃声、震动或无提醒，提供五种可试听的提示音
- 可从本机选择计划图片，裁剪后保存到本地；首页、计划管理和统计页使用统一的方形图片区展示图标
- 可从本机选择提示音、截取片段，用作倒计时提醒
- 后台继续计时的计划使用 Android 系统调度完成通知

## 下载

Android APK 通过 GitHub Releases 提供：[下载最新版 Release](https://github.com/iLLyaaaaaa/timemanager/releases/latest)。

请按手机或设备的 CPU 架构选择安装包：

- `arm64-v8a`：大多数现代 Android 手机，建议优先选择。
- `armeabi-v7a`：较旧的 32 位 ARM 设备。
- `x86_64`：部分 Android 模拟器和 x86-64 设备。

不确定设备架构时，可先尝试 `arm64-v8a`。如果系统提示安装包不兼容，再确认设备架构并下载对应版本。

## 本地运行

安装 Flutter 与 Android 开发环境后，在项目目录执行：

```sh
flutter pub get
flutter run
```

生成 Android APK：

```sh
flutter build apk --release --split-per-abi
```

本项目尚在开发中。构建产物和 APK 不纳入 Git 仓库。
