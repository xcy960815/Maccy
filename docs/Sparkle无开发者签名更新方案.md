# Sparkle 无开发者签名更新方案

## 背景

当前项目的自动更新使用 Sparkle。

没有 Apple Developer 签名时，仍然可以使用 Sparkle 更新，但前提是：

1. 应用内置 `SUPublicEDKey`
2. 发布的更新压缩包带有 `sparkle:edSignature`
3. `appcast.xml` 指向的更新条目包含签名信息

也就是说：

- 可以没有 Apple Developer / Developer ID 签名
- 但不能没有 Sparkle 的 EdDSA 签名

## 当前仓库改动

本仓库已做以下调整：

1. `Clipbook/Info.plist` 增加 `SUPublicEDKey`
2. GitHub Actions 在 tag 构建时先对 `.app` 做有效的 ad-hoc 签名
3. GitHub Actions 再使用 Sparkle `sign_update` 对发布 zip 签名
4. GitHub Actions 更新 `appcast.xml` 时写入 `sparkle:edSignature`
5. 新增 `scripts/generate_sparkle_keys.swift`，用于本地生成一组 Sparkle EdDSA 密钥

## 首次配置

### 1. 生成密钥

在本地执行：

```bash
swift scripts/generate_sparkle_keys.swift
```

输出会包含两段 Base64：

- 私钥：用于签名更新包
- 公钥：用于写入应用 `Info.plist`

### 2. 配置 GitHub Secret

在仓库 Settings -> Secrets and variables -> Actions 中新增：

- `SPARKLE_PRIVATE_KEY`

值为上一步生成的私钥 Base64 文本。

## 发布流程

发布时继续走 tag 触发的 GitHub Actions：

1. 构建 `Clipbook.app`
2. 对 `.app` 执行 ad-hoc 签名，保证 bundle 代码签名有效
3. 打包为 zip
4. 使用 Sparkle `sign_update` 对 zip 生成 EdDSA 签名
5. 上传 Release 资产
6. 更新 `master` 分支上的 `appcast.xml`

## 注意事项

### 1. `SUPublicEDKey` 与私钥必须配对

如果重新生成了新的私钥，就必须同步更新：

- GitHub Secret `SPARKLE_PRIVATE_KEY`
- `Clipbook/Info.plist` 中的 `SUPublicEDKey`

否则新版本更新会因为签名校验失败被 Sparkle 拒绝。

### 2. 这个方案解决的是 Sparkle 更新签名，不是 Apple 签名

即使更新链可用，产物本身仍然可能是：

- 未做 Apple Developer 签名
- 未做 notarization

所以这个方案保证的是 Sparkle 能校验更新包来源，不保证绕过 Gatekeeper 的所有分发限制。

### 3. 不能只签 zip，不签 `.app`

`CODE_SIGNING_ALLOWED=NO` 构建出来的产物，可能带有不完整的 ad-hoc 痕迹。  
这种情况下，即使 zip 的 `sparkle:edSignature` 正确，Sparkle 仍然可能在安装阶段报：

- “此更新未正确签名，无法验证其真实性”

因此发布流程里必须在打 zip 前，对 `.app` 再执行一次明确的 ad-hoc 签名，例如：

```bash
codesign --force --deep --sign - Clipbook.app
```

### 4. 现有旧 release 资产不会自动变成可更新

只有接入本方案后，新生成的 release zip 才会带 Sparkle 签名并可用于后续更新。
