# GPS Overlay on Photo Application

## 功能说明

这是一个将 GPS 轨迹数据叠加到照片上的 Flutter 应用。

### 主要功能

1. **图片选择**：选择 JPG/PNG 格式的照片
2. **FIT 文件解析**：解析 Garmin FIT 文件，提取 GPS 轨迹数据
3. **EXIF 时间读取**：从照片的 EXIF 数据中自动读取拍摄时间
4. **GPS 数据匹配**：根据照片时间找到对应的 GPS 位置和配速数据
5. **Overlay 绘制**：在照片上绘制以下信息：
   - GPS 轨迹线（可配置颜色和宽度）
   - 当前位置标记点
   - 配速、速度、距离信息
   - 时间戳

### Overlay 配置选项

- 显示/隐藏 GPS 轨迹线
- 显示/隐藏当前位置点
- 显示/隐藏配速信息
- 显示/隐藏时间戳
- 自定义轨迹线颜色和宽度
- 自定义位置点颜色
- 自定义文字颜色

## 项目结构

```
lib/
├── main.dart                      # 应用入口
├── models/
│   ├── gps_point.dart             # GPS 数据点模型
│   └── fit_data.dart              # FIT 文件数据模型
├── services/
│   ├── fit_parser_service.dart    # FIT 文件解析服务
│   └── exif_service.dart          # EXIF 数据读取服务
├── widgets/
│   └── overlay_painter.dart       # Overlay 绘制组件
└── screens/
    └── home_screen.dart           # 主页面UI

```

## 依赖包

- `image_picker: ^1.0.7` - 图片选择（实际使用 file_picker）
- `file_picker: ^8.0.0` - 文件选择器
- `exif: ^3.3.0` - EXIF 数据读取
- `fit_parser: ^2.0.0` - FIT 文件解析
- `path_provider: ^2.1.2` - 路径处理
- `path: ^1.9.0` - 路径工具
- `intl: ^0.19.0` - 国际化和日期格式化

## 使用方法

### 1. 编译和运行

```bash
flutter pub get
flutter run -d windows
```

### 2. 操作步骤

1. 点击 "Select Image" 按钮，选择一张照片
2. 点击 "Select FIT File" 按钮，选择一个 FIT 文件
3. 应用会自动：
   - 从照片 EXIF 读取拍摄时间
   - 解析 FIT 文件获取 GPS 轨迹
   - 匹配照片时间点的 GPS 数据
4. 在 "Overlay Settings" 区域配置显示选项
5. 查看照片上的 GPS overlay

### 3. FIT 文件要求

FIT 文件应包含以下数据：
- GPS 坐标（position_lat, position_long）
- 时间戳（timestamp）
- 可选：速度、距离、心率等数据

## 技术细节

### FIT 文件解析

使用 `fit_parser` 包解析 Garmin FIT 文件：
- 提取 GPS 轨迹点（经纬度、海拔、速度、距离）
- 计算配速（pace = 1000 / speed）
- 支持心率数据
- **时间戳类型处理**：FIT 文件中的 timestamp 可能是 double 或 int 类型，已正确处理类型转换
- **时区转换**：FIT 文件中的时间戳是 UTC 时间，自动转换为本地时区显示

### 图片显示

- 使用 `InteractiveViewer` 支持图片缩放和移动
- 最小缩放：0.1，最大缩放：5.0
- `BoxFit.contain` 显示完整图片，不裁剪
- 用户可以用鼠标滚轮或触摸手势缩放查看细节

### GPS 坐标转换

FIT 文件中的 GPS 坐标使用 semicircles 单位：
```dart
degrees = semicircles * 180 / 2147483648.0
```

### EXIF 时间读取

从照片 EXIF 数据中读取以下字段（按优先级）：
1. `Image DateTime`
2. `EXIF DateTimeOriginal`
3. `EXIF DateTimeDigitized`

**注意**：EXIF 时间通常没有时区信息，可能是 UTC 或本地时间，取决于相机设置。

### 时间匹配与显示

- FIT 文件时间戳：UTC 时间 → 自动转换为本地时区
- EXIF 时间：本地时间（假设相机设置正确）
- UI 显示所有时间均为本地时区，方便用户核对
- 显示匹配状态指示：
  - ✓ GPS Data Matched（成功匹配）
  - ⚠ No GPS match found（时间超出范围）

### Overlay 绘制

使用 Flutter 的 `CustomPaint` 和 `CustomPainter` 绘制 overlay：
- GPS 轨迹线使用 `Path` 和 `Paint` 绘制
- 文字信息使用 `TextPainter` 绘制
- 自动计算 GPS 边界并缩放到图片尺寸

## 测试状态

✅ 代码静态分析通过
✅ 所有依赖包安装成功
✅ 数据模型创建完成
✅ 服务类实现完成
✅ UI 组件创建完成
✅ 功能集成完成

⚠️ 手动运行测试（因首次编译需下载引擎文件）

## 注意事项

1. **首次运行**：需要下载 Windows 引擎文件，可能需要等待几分钟
2. **照片要求**：照片应包含 EXIF 时间信息，否则无法匹配 GPS 数据
3. **FIT 文件**：确保 FIT 文件覆盖照片拍摄时间范围
4. **时间匹配**：默认容忍 5 秒误差，会自动选择最接近的时间点
5. **时区问题**：
   - FIT 文件时间自动转换为本地时区显示
   - 如果照片时间与 FIT 时间相差数小时，可能是时区设置问题
   - 检查 UI 中显示的时间是否匹配
6. **图片查看**：
   - 大图片自动缩放显示完整内容
   - 使用鼠标滚轮或触摸手势缩放查看细节
   - 可移动图片查看不同区域

## 后续改进建议

1. 添加导出功能（保存带 overlay 的图片）
2. 支持更多文件格式（GPX、TCX 等）
3. 添加更多 overlay 样式选项
4. 支持手动时间调整
5. 添加 GPS 轨迹动画显示
6. 支持多张照片批量处理