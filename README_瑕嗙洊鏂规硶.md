# 零点相位 V6.0.2：资源打包热修复

这是给已经上传 V6.0.1 CloudBuild 的 GitHub 仓库使用的最小补丁。

解压后按原路径覆盖仓库中的三个文件：

```text
project.yml
Scripts/build_unsigned_ipa.sh
.github/workflows/build-unsigned-ipa.yml
```

然后进入 GitHub Actions，运行：

```text
Build Phase Zero 6.0.2 unsigned IPA
```

不要把本 ZIP 自己上传成仓库里的一个文件。GitHub 在这方面不会体谅人类，只会安静地保留一个完全没用的压缩包。
