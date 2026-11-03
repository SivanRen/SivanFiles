# 第三方组件

本工程只引入了一个第三方依赖，用于 rar / 7z 等格式的解压。

## libarchive

- 用途：解压 rar、7z、tar、gz、bz2、xz、zst、cab、iso 等格式
- 站点：https://github.com/libarchive/libarchive
- 版本：3.8.x（通过 `matteo-pacini/libarchive-for-swift` 的静态 XCFramework 引入，SPM 依赖，锁定 `1.0.0`）
- 许可证：BSD 2-Clause

```
Copyright (c) 2003-2018 Tim Kientzle
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

## 打包封装

- `libarchive-for-swift`（https://github.com/matteo-pacini/libarchive-for-swift），MIT License。
  仅提供 XCFramework 封装，不含算法实现。

## 说明

libarchive 以**静态库**形式链接进主二进制，App 包里不存在独立的
`.framework` / `.dylib`，因此不需要额外的嵌入与签名步骤，未签名 ipa
的自签流程与之前完全一致。

zip 格式**没有**使用 libarchive，而是本工程自带的纯 Swift 实现
（`Sivan/Core/Zip/`），压缩也仍然是它（store / deflate）。
