# bhkey

macOS 外接键盘零延迟按键重映射工具

**Language**: [English](README.md) | [한국어](README.ko.md) | 中文

## 简介

bhkey 使用 Apple 原生 `hidutil` 内核属性 API 重映射外接键盘的修饰键，无需虚拟驱动，无后台进程占用 CPU。映射在内核层面生效，输入延迟为零。与 Karabiner-Elements 不同，bhkey 不向系统安装任何内容，所有文件均位于用户主目录内。

通过 VendorID+ProductID 精准定位外接键盘，内置键盘和 Magic Keyboard 绝不受影响。

## 系统要求

- macOS 10.12 Sierra 及以上（`hidutil` 从 Sierra 开始引入）
- `bash`

## 安装

```bash
git clone https://github.com/baekho-lim/bhkey.git
cd bhkey
chmod +x bhkey.sh
bash bhkey.sh apply
```

`apply` 命令会执行 5 项预检，通过 `hidutil` 应用映射，并安装 LaunchAgent 以在重启和 USB 热插拔后自动生效。

## 默认映射

| 物理按键 | macOS 行为 | 备注 |
|---|---|---|
| Left Alt | Left Command (⌘) | Windows → Mac 布局 |
| Left Win | Left Option (⌥) | Windows → Mac 布局 |
| Right Alt | Right Command (⌘) | |
| Right Win | F19 | 语音输入触发键 |
| 한/영 键 (0x90) | F18 | 输入法切换 |
| 한자 键 (0x91) | F19 | 同 Right Win |

此默认布局专为在 macOS 上使用 Windows 布局键盘（如 Corsair、Leopold）设计。

## 命令

```bash
bash bhkey.sh apply     # 执行预检并应用映射
bash bhkey.sh reset     # 移除所有自定义映射
bash bhkey.sh status    # 显示当前 hidutil 状态和 LaunchAgent 状态
bash bhkey.sh version   # 打印版本号
```

## 工作原理

1. **hidutil**: bhkey 调用 `hidutil property --set` 传入 JSON 映射载荷。这是 macOS 原生 API，在内核层面设置按键转换，无驱动、无进程、无延迟。
2. **设备定向**: `--matching` 标志通过 VendorID 和 ProductID 过滤，仅对指定外接键盘生效。
3. **LaunchAgent 持久化**: 在 `~/Library/LaunchAgents/com.bh.keymapping.plist` 安装 plist，配置 `RunAtLoad: true` 和 `WatchPaths: /dev`，登录时及 USB 设备插入时自动重新应用映射。

## 应用后配置（韩语键盘用户）

运行 `bhkey apply` 后，在系统设置中分配 F18/F19 键：

1. **输入法切换 (F18)**: 系统设置 > 键盘 > 键盘快捷键 > 输入法 > 将 F18 分配给"选择上一个输入法"或"在输入法菜单中选择下一个"
2. **语音输入 / 听写 (F19)**: 系统设置 > 键盘 > 听写 > 将快捷键设置为 F19（在快捷键输入框中按 Right Win 键即可）

## 反冲突检测

bhkey 在应用映射前执行 5 项检查：

1. 检测 macOS 系统设置中的修饰键覆盖 — 警告可能存在的双重映射冲突
2. 检测 Karabiner-Elements 或 Corsair iCUE 进程 — 两者均可能与 `hidutil` 冲突
3. 检测目标外接键盘 — 未找到设备时中止
4. 处理 `hidutil` 权限错误，并在 macOS 14.2+ 提供 `sudo` 提示
5. 通过 `plutil -lint` 验证 LaunchAgent plist 语法后再加载

## 自定义映射

如需更改按键映射，请参阅 [`docs/CUSTOMIZE.md`](docs/CUSTOMIZE.md)，其中包含 HID 用途表、如何查找键盘的 VendorID/ProductID，以及如何修改映射载荷。

## 许可证

MIT
