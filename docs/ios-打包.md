# 用 GitHub Actions 打 iOS 包

没有 Mac 也能出 `.ipa`。仓库里已经放了一个工作流：

```
.github/workflows/ios.yml     # 每次 push 到 main 自动跑，也能手动触发
```

产出在 **Actions → 某次运行 → Artifacts → xiaowo-ios-unsigned**，下载下来就是 `App.ipa`。

## 先说清楚：未签名 ≠ 能直接装

iOS 和 Android 不一样，装到手机上必须有签名。所以现在这条流水线产出的是**未签名包**，
它证明「代码能在 iOS 上编过」，但不能直接拖进手机。

要装到 iPhone，两条路：

| 路线 | 成本 | 有效期 | 适用 |
|---|---|---|---|
| A. 未签名包 + 本地重签 | 免费 Apple ID | **7 天**，自动过期 | 自己试试 |
| B. 付费开发者账号 + CI 直接出签名包 | $99/年 | 1 年 | 长期用、给家人装 |

---

## 路线 A：下载 IPA，用 Sideloadly 重签

1. 打开仓库 **Actions → iOS 打包 → 最新一次运行**
2. 页面底部 **Artifacts** 下载 `xiaowo-ios-unsigned.zip`，解压出 `App.ipa`
3. 电脑装 [Sideloadly](https://sideloadly.io/)（Windows 也有）
4. iPhone 用数据线连电脑，Sideloadly 里选中 `App.ipa`，Apple ID 填你自己的
5. 点 Start，输入 Apple ID 密码（走的是 Apple 的开发者登录，不会存密码）
6. 手机上 **设置 → 通用 → VPN与设备管理** 里信任一下这个开发者证书

限制：

- **7 天后过期**，App 打不开，要重新签一次（重签不会丢数据）
- 免费账号同时最多装 3 个自签 App
- 每次重签都要连电脑

---

## 路线 B：CI 直接出签名包（需要开发者账号）

有 $99/年的账号后，把它变成 CI 里的 secrets，推代码就出可直接安装的 IPA。

### 需要准备的 4 样东西

| 名字 | 怎么来 |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | 钥匙串导出 `.p12`，`base64 -i cert.p12 \| pbcopy` |
| `P12_PASSWORD` | 导出 `.p12` 时设的密码 |
| `BUILD_PROVISION_PROFILE_BASE64` | 开发者后台下载 `.mobileprovision`，同样 base64 |
| `APPLE_TEAM_ID` | 开发者后台右上角，10 位字符 |

放到 **仓库 → Settings → Secrets and variables → Actions → New repository secret**。

### 工作流

把下面这段存成 `.github/workflows/ios-signed.yml`（默认不提交，避免没有 secrets 时红叉）：

```yaml
name: iOS 签名打包

on:
  workflow_dispatch:

jobs:
  ipa:
    runs-on: macos-15
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: 导入证书到临时钥匙串
        env:
          CERT_B64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
          CERT_PWD: ${{ secrets.P12_PASSWORD }}
        run: |
          set -euo pipefail
          KEYCHAIN=$RUNNER_TEMP/app.keychain-db
          KEYCHAIN_PWD=$(uuidgen)
          echo "$CERT_B64" | base64 --decode > $RUNNER_TEMP/cert.p12
          security create-keychain -p "$KEYCHAIN_PWD" $KEYCHAIN
          security set-keychain-settings -lut 21600 $KEYCHAIN
          security unlock-keychain -p "$KEYCHAIN_PWD" $KEYCHAIN
          security import $RUNNER_TEMP/cert.p12 -P "$CERT_PWD" -A -t cert -f pkcs12 -k $KEYCHAIN
          security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PWD" $KEYCHAIN
          security list-keychain -d user -s $KEYCHAIN

      - name: 安装描述文件
        env:
          PP_B64: ${{ secrets.BUILD_PROVISION_PROFILE_BASE64 }}
        run: |
          set -euo pipefail
          PP_PATH=$RUNNER_TEMP/profile.mobileprovision
          echo "$PP_B64" | base64 --decode > $PP_PATH
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          cp $PP_PATH ~/Library/MobileDevice/Provisioning\ Profiles/

      - name: 编译并导出 ipa
        env:
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          set -euo pipefail
          flutter pub get
          flutter build ipa --release \
            --export-options-plist=ios/ExportOptions.plist

      - uses: actions/upload-artifact@v4
        with:
          name: xiaowo-ios-signed
          path: build/ios/ipa/*.ipa
```

### 还需要 `ios/ExportOptions.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>   <!-- 上架换成 app-store -->
  <key>teamID</key>
  <string>你的 Team ID</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.kkui.airdogMobile</key>
    <string>描述文件里的 Name</string>
  </dict>
</dict>
</plist>
```

`method` 的取值：

| 值 | 用途 |
|---|---|
| `development` | 自己几台设备装 |
| `ad-hoc` | 指定 UDID 的设备装（最多 100 台/年） |
| `app-store` | 上架 App Store |
| `enterprise` | 企业内部分发（$299/年） |

---

## 常见坑

**1. `flutter test` 挂了**

CI 用的是最新 stable，可能比本地 Flutter 新/旧。看日志里报的是 API 变更还是测试本身的问题。
本机 `flutter --version` 是 3.47.7，CI 大概率也在这个版本附近。

**2. `pod install` 超时**

CocoaPods 第一次拉 specs 很慢，偶发失败。重跑一次通常就好。

**3. 编译过但装上去闪退**

多数是 `Info.plist` 少了权限描述。本项目已经加了：

```
NSPhotoLibraryUsageDescription    选照片
NSCameraUsageDescription          拍照
NSLocalNetworkUsageDescription    连你自己的服务器
```

**4. 手机连不上服务器**

登录页填的是电脑局域网 IP（比如 `192.168.31.27:8080`），要求：

- 手机和电脑同一 Wi-Fi
- 后端监听 `0.0.0.0`（AirDogsApi 已经是）
- 防火墙放行 8080：

```powershell
New-NetFirewallRule -DisplayName "AirDogsApi 8080" -Direction Inbound `
  -Protocol TCP -LocalPort 8080 -Action Allow -Profile Private
```

iOS 第一次连局域网会弹「是否允许查找本地网络设备」，选允许。
