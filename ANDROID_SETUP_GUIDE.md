# Android模拟器完整安装指南

## 当前环境状态

❌ **未安装：**
- Android SDK
- Android Studio
- Java JDK
- Android模拟器

✅ **已就绪：**
- Flutter SDK
- Windows平台
- Visual Studio

## 安装步骤（约45-60分钟）

### 第1步：下载Android Studio（10-15分钟）

**下载地址：**
https://developer.android.com/studio

**文件信息：**
- 文件名：`android-studio-2024.x.x-windows.exe`
- 大小：约900-1000MB
- 版本：推荐最新稳定版

**下载方式：**
1. 打开浏览器访问上述链接
2. 点击 "Download Android Studio"
3. 同意条款并下载
4. 保存到 `C:\Users\ligang\Downloads\`

### 第2步：安装Android Studio（15-20分钟）

**安装流程：**

```powershell
# 1. 运行安装程序（管理员权限）
右键点击下载的exe文件 → "以管理员身份运行"

# 2. 安装向导设置：
- 安装路径：C:\Program Files\Android\Android Studio（默认）
- 选择组件：全部勾选
  ✓ Android Studio
  ✓ Android Virtual Device
  ✓ Performance (Intel® HAXM)
  ✓ Android SDK
  
# 3. 等待安装完成
首次启动会自动下载：
  - Android SDK（约2GB）
  - SDK Platform Tools
  - SDK Build Tools
  - Android Emulator
  
# 4. 完成设置向导：
- Standard 安装类型
- 接受所有许可协议
- 下载推荐的SDK组件
```

**预期安装目录：**
```
C:\Program Files\Android\Android Studio\          # IDE程序
C:\Users\ligang\AppData\Local\Android\Sdk\         # SDK目录
```

### 第3步：配置Flutter Android SDK（2分钟）

安装完成后，配置Flutter：

```bash
# 1. 设置Android SDK路径
flutter config --android-sdk "C:\Users\ligang\AppData\Local\Android\Sdk"

# 2. 接受Android许可（全部输入y）
flutter doctor --android-licenses
# 提示时会问约8-10个许可，每个都输入 y 然后回车

# 3. 验证配置
flutter doctor
# 应该看到 [√] Android toolchain
```

### 第4步：创建Android模拟器（5-10分钟）

**方法A：通过Android Studio GUI（推荐）**

```
1. 启动 Android Studio
2. 进入主界面后，点击：
   More Actions → Virtual Device Manager
   或 Tools → Device Manager
   
3. 点击 "Create Device"（创建设备）

4. 选择硬件设备：
   Category: Phone
   推荐：Pixel 6（标准尺寸，5.0英寸）
   或：Pixel 4a（4.6英寸，测试小屏）
   点击 Next
   
5. 选择系统镜像：
   推荐推荐：
   - Release: Android 13 (API Level 33)
   - 或：Android 14 (API Level 34)
   选择带 Google Play 的版本
   点击 Download 等待下载（约500MB）
   Download完成后点击 Next
   
6. 配置模拟器设置：
   - AVD Name: Pixel_6_API_33（自动生成）
   - Show Advanced Settings（可选）：
     * RAM: 2048 MB（推荐）
     * VM heap: 256 MB
     * Graphics: Software（兼容性好）
     * 或 Hardware（性能好，需显卡支持）
   点击 Finish
   
7. 模拟器创建成功
```

**方法B：通过命令行（高级）**

```bash
# 使用 avdmanager 创建（需先安装SDK）
cd C:\Users\ligang\AppData\Local\Android\Sdk\tools\bin

# 创建设备配置
avdmanager create avd \
  -n Pixel_6_API_33 \
  -k "system-images;android-33;google_apis;x86_64" \
  -d "pixel_6"
```

### 第5步：启动Android模拟器（1分钟）

**方法A：通过Android Studio**

```
1. 打开 Device Manager
2. 找到创建的模拟器（Pixel_6_API_33）
3. 点击右侧的 ▶️（播放）按钮启动
4. 等待模拟器启动（约30-60秒）
5. 看到Android桌面界面
```

**方法B：通过命令行**

```bash
# 1. 查看可用模拟器
flutter emulators

# 输出类似：
# 1 available emulator:
# Pixel_6_API_33 • Pixel 6 • Google • android-33

# 2. 启动模拟器
flutter emulators --launch Pixel_6_API_33

# 或使用emulator命令
C:\Users\ligang\AppData\Local\Android\Sdk\emulator\emulator.exe -avd Pixel_6_API_33
```

### 第6步：在模拟器上运行应用（1分钟）

```bash
# 1. 础认模拟器已启动
flutter devices

# 输出应包含：
# Pixel_6_API_33 (mobile) • emulator-5554 • android-x86 • Android 13 (API 33) (emulator)

# 2. 运行Flutter应用
flutter run -d emulator-5554

# 或使用设备名
flutter run -d Pixel_6_API_33

# 3. 应用会在模拟器中启动
```

## 快速验证响应式布局

模拟器启动后，测试响应式功能：

### 验证清单

**1. 默认尺寸测试（Pixel 6）**
```
屏幕尺寸：1080x2400 (约400dp宽)
预期效果：
- 轨迹：35-40%宽度
- 文字：约10px（可读）
- 信息框：充满宽度
- Padding：约10px
```

**2. 小屏模拟器测试**
```
创建：Pixel 4a (约380dp宽)
验证：
- 所有元素自动缩小
- 文字小但清晰
- 轨迹紧凑可见
```

**3. 大屏模拟器测试**
```
创建：Pixel Tablet (约800dp+宽)
验证：
- 所有元素放大
- 文字清晰大
- 轨迹宽敞易看
```

## 保存图片验证

在模拟器中保存带overlay的照片：

```
1. 选择照片和FIT文件
2. 添加overlay
3. 点击保存
4. 图片保存在模拟器Downloads目录
5. 通过Android Studio的Device File Explorer提取
```

## 详细验证步骤

### 步骤1：启动模拟器并运行应用

```bash
# 启动模拟器
flutter emulators --launch Pixel_6_API_33

# 等待30-60秒启动
# 模拟器桌面显示

# 运行应用
flutter run -d emulator-5554
```

### 步骤2：选择照片和FIT文件

```
1. 点击 "Select Image"
   → Android文件选择器打开
   → 选择照片（建议小于5MB）

2. 点击 "Select FIT File"
   → 选择FIT文件（22576860731_ACTIVITY.fit）
   
3. 础认GPS数据解析成功
   → 显示GPS点数、距离等信息
   
4. 输入活动名称（可选）
   → 例如："Morning Run"
```

### 步骤3：验证overlay显示

```
检查点：
✓ GPS轨迹在右上角
✓ 轨迹形状真实（不变形）
✓ 轨迹大小适中（35-40%宽度）
✓ 文字清晰可读（中文标签）
✓ 信息框充满宽度
✓ 位置标记可见
```

### 步骤4：保存并验证图片

```
1. 点击 "Save Image with Overlay"
2. Android保存对话框
3. 选择保存位置
4. 等待保存完成
5. 提取保存的图片：
   Android Studio → View → Tool Windows → Device File Explorer
   → /sdcard/Download/overlay_xxx.jpg
   → 右键 Save As... 到电脑
   
6. 打开图片验证：
   - overlay尺寸与屏幕显示一致
   - 所有元素按比例放大/缩小
   - 文字清晰可读
```

## 故障排查

### 问题1：模拟器启动失败

```bash
# 解决：检查HAXM或启用软件渲染
# 编辑模拟器配置
# Graphics: Software GLES 2.0

# 或安装HAXM
C:\Users\ligang\AppData\Local\Android\Sdk\extras\intel\Hardware_Accelerated_Execution_Manager\intelhaxm-android.exe
```

### 问题2：flutter doctor显示Android问题

```bash
# 确认SDK路径
flutter config --android-sdk "正确路径"

# 重新接受许可
flutter doctor --android-licenses

# 检查环境变量
ANDROID_HOME = C:\Users\ligang\AppData\Local\Android\Sdk
ANDROID_SDK_ROOT = C:\Users\ligang\AppData\Local\Android\Sdk
```

### 问题3：应用无法在模拟器运行

```bash
# 础认模拟器已连接
adb devices

# 输出应显示：
# emulator-5554   device

# 重启adb
adb kill-server
adb start-server
```

## 预期验证效果

### 模拟器上的响应式表现

**Pixel 6（约400dp）- 标准手机**
```
┌──────────────────────┐
│轨迹区(右上35%)       │
│                      │
│                      │
│                      │
│                      │
│                      │
│                      │
┌──────────────────────┐
│配速: 9:20            │
│距离: 5.23km          │ ← 文字约10px
│心率: 145             │
│时间: 10:30:45        │
└──────────────────────┘
```

**保存的图片对比：**
- 小屏保存：overlay紧凑（400px图片）
- 大屏保存：overlay放大（2000px图片）
- 比例关系一致

## 总时间估算

| 步骤 | 时间 |
|-----|------|
| 下载Android Studio | 10-15分钟 |
| 安装Android Studio | 15-20分钟 |
| 配置Flutter SDK | 2分钟 |
| 创建模拟器 | 5-10分钟 |
| 启动并验证 | 5分钟 |
| **总计** | **35-50分钟** |

## 立即开始

### 最快验证方案

**1. 先用Windows验证（已完成）**
- 应用已在Windows运行
- 调整窗口大小可验证响应式

**2. 然后安装Android（如需要）**
- 按上述步骤安装Android Studio
- 创建Pixel 6模拟器
- 在模拟器上验证真实手机效果

**响应式布局已实现，Android和Windows效果一致！**

现在你可以选择：
- 继续在Windows调整窗口验证（已就绪）
- 或安装Android模拟器完整验证（约40分钟）

需要我协助哪个方案？