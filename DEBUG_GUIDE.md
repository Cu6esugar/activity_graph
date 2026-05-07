# Debug 日志说明

## 已添加的 Debug 日志

### 1. EXIF 读取日志
位置：`lib/services/exif_service.dart`

输出内容：
- 图片路径
- 所有可用的 EXIF 标签列表
- 找到的 DateTime 字段名称和值
- 解析后的时间
- EXIF 中的 GPS 坐标（如果有）
- 解析失败信息（如果失败）

示例输出：
```
=== EXIF Debug Log ===
Image path: /path/to/image.jpg
Available EXIF tags: [Image DateTime, EXIF DateTimeOriginal, ...]
Found EXIF DateTimeOriginal: 2024-05-07 10-30-45
Parsed EXIF time: 2024-05-07 10:30:45.000 (using field: EXIF DateTimeOriginal)
GPS coordinates in EXIF: Lat=31.2304, Lon=121.4737
=== EXIF Debug End ===
```

### 2. FIT 文件解析日志
位置：`lib/services/fit_parser_service.dart`

输出内容：
- FIT 文件路径
- 总数据消息数量
- 提取的 GPS 点数量
- 开始和结束时间
- 活动类型
- 总距离
- 前 3 个 GPS 点详情
- 后 3 个 GPS 点详情

示例输出：
```
=== FIT Parser Debug Log ===
FIT file path: 22576860731_ACTIVITY.fit
FIT file parsed, total data messages: 30191
GPS points extracted: 12000
FIT start time: 2016-04-19 08:53:08.000
FIT end time: 2016-04-19 10:45:30.000
Activity type: running
Total distance: 15000.0m

First 3 GPS points:
  Point 0: Time=2016-04-19 08:53:08, Lat=31.230416, Lon=121.473708
  Point 1: Time=2016-04-19 08:53:09, Lat=31.230417, Lon=121.473709
  Point 2: Time=2016-04-19 08:53:10, Lat=31.230418, Lon=121.473710

Last 3 GPS points:
  Point 11997: Time=2016-04-19 10:45:28, Lat=31.231020, Lon=121.474520
  Point 11998: Time=2016-04-19 10:45:29, Lat=31.231021, Lon=121.474521
  Point 11999: Time=2016-04-19 10:45:30, Lat=31.231022, Lon=121.474522
=== FIT Parser Debug End ===
```

### 3. GPS 匹配日志
位置：`lib/models/fit_data.dart`

输出内容：
- 目标时间（图片时间）
- GPS 点数量和时间范围
- 精确匹配结果（如果在 5 秒容忍度内）
- 最近匹配结果（如果没有精确匹配）
- 时间差（秒和分钟）
- 匹配点的详细信息
- 大时间差警告（> 30分钟）

示例输出：
```
=== GPS Matching Debug ===
Target time (image): 2016-04-19 09:15:30.000
GPS points count: 12000
GPS time range: 2016-04-19 08:53:08.000 to 2016-04-19 10:45:30.000
Found exact match within 5s tolerance:
  Matched point time: 2016-04-19 09:15:32.000
  Time difference: 2s
  Lat: 31.230890
  Lon: 121.473920
  Speed: 2.50 m/s
  Pace: 6:40 min/km
=== Matching Debug End ===
```

或无精确匹配：
```
=== GPS Matching Debug ===
Target time (image): 2016-04-19 09:15:30.000
GPS points count: 12000
GPS time range: 2016-04-19 08:53:08.000 to 2016-04-19 10:45:30.000
No exact match within tolerance, finding closest point...
Closest point found at index 3500:
  Point time: 2016-04-19 09:15:32.000
  Time difference: 2s (0min)
  Lat: 31.230890
  Lon: 121.473920
=== Matching Debug End ===
```

或时区问题：
```
=== GPS Matching Debug ===
Target time (image): 2016-04-19 17:15:30.000
GPS points count: 12000
GPS time range: 2016-04-19 08:53:08.000 to 2016-04-19 10:45:30.000
Closest point found at index 0:
  Point time: 2016-04-19 08:53:08.000
  Time difference: 30622s (510min)
  Lat: 31.230416
  Lon: 121.473708
WARNING: Time difference is more than 30 minutes!
This might indicate timezone mismatch or wrong file selection
=== Matching Debug End ===
```

## 如何查看日志

运行应用时，日志会输出到控制台：

```bash
flutter run -d windows
```

在控制台窗口查看：
1. 选择图片后 - 查看 EXIF 日志
2. 选择 FIT 文件后 - 查看 FIT 解析日志
3. 匹配时 - 查看 GPS 匹配日志

## 使用日志诊断问题

### 1. 时区问题
如果看到：
```
Time difference: XXXXs (YYYmin)
WARNING: Time difference is more than 30 minutes!
```

原因可能是：
- 照片 EXIF 时间是 UTC，但 FIT 已转为本地时间
- 相机时区设置错误
- 照片和 FIT 文件来自不同活动

解决方案：
- 检查相机时区设置
- 检查照片拍摄时间是否正确
- 确认 FIT 文件是正确的活动

### 2. EXIF 无时间
如果看到：
```
Failed to parse EXIF datetime - no valid time field found
```

原因：
- 照片没有 EXIF 数据
- EXIF 时间字段损坏

解决方案：
- 使用其他工具查看照片 EXIF
- 手动添加时间（需要修改代码）

### 3. GPS 点太少
如果看到：
```
GPS points extracted: 0
```

原因：
- FIT 文件没有 GPS 数据
- GPS 信号丢失

解决方案：
- 检查 FIT 文件是否正确
- 使用其他 GPS 文件格式

## 图片显示问题修复

已修改：
- 使用 `ClipRect` 包裹 InteractiveViewer
- `constrained: true` 使图片受容器约束
- `BoxFit.contain` 显示完整图片
- 缩放范围：0.5x - 3x

现在图片会完整显示在 400px 高度的容器中，支持缩放查看。