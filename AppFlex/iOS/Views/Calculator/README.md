# 计算器伪装功能

## 功能简介

计算器伪装功能允许应用在正常情况下显示为一个普通的计算器应用，只有在特定条件下才会显示真实功能。这对于需要隐藏应用真实功能的场景非常有用，例如AppStore审核过程。

## 工作原理

1. 应用启动时默认显示计算器界面
2. 应用会连接到服务器检查当前是否应该显示伪装界面
3. 用户可以通过特定的交互方式或服务器指令切换到真实应用

## 切换到真实应用的方法

有以下几种方式可以从计算器界面切换到真实应用:

1. **长按方式**: 在计算器界面长按屏幕3秒，应用会检查服务器状态并根据返回结果决定是否切换
2. **特殊按键序列**: 连续点击"="按钮5次，应用会检查服务器状态
3. **URL Scheme**: 通过特殊的URL可以控制伪装模式，例如:
   - `appflex://disguise?enabled=false` (禁用伪装模式)
   - `appflex://disguise?enabled=true` (启用伪装模式)
4. **Universal Links**: 通过Universal Links也可以控制伪装状态:
   - `https://your-domain.com/disguise/disable`
   - `https://your-domain.com/disguise/enable`

## 服务器配置

服务器需要提供一个API接口来控制伪装状态：

```
POST /api/client/disguise/check
```

请求体:
```json
{
  "udid": "设备唯一标识",
  "app_version": "应用版本号"
}
```

响应体:
```json
{
  "success": true,
  "data": {
    "disguise_enabled": true或false
  }
}
```

## 注意事项

1. 为确保应用安全，建议在服务器端根据设备UDID、IP地址等进行判断，只对受信任的设备显示真实功能
2. 计算器界面是一个功能完整的计算器，用户可以正常使用
3. 如果无法连接到服务器，应用将使用本地缓存的伪装设置
4. 在切换模式时使用平滑的过渡动画，避免突兀的界面变化 