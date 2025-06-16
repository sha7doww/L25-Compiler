#!/usr/bin/env bash
# ------------------------------------------------------------
# test_all.sh – 一键构建并跑全部示例
# ------------------------------------------------------------
set -euo pipefail

rm -rf build

echo "================ 1. build  ================="
./build.sh                        # 先编译编译器 & 解释器

echo -e "\n================ 2. run samples ================"
# 要测试的 .l25 源文件列表（按需增删）
SAMPLES=( 
          sample/pdf_sample.l25 sample/test.l25 sample/func_return.l25 sample/map.l25 
          sample/power.l25 sample/mask_right.l25 sample/complex4.l25
        )

for SRC in "${SAMPLES[@]}"; do
  if [[ -f "$SRC" ]]; then
    OUT="${SRC%.l25}.pcode"      # 输出 pcode 与源文件同目录
    echo -e "\n--- $SRC -> $OUT ---"
    ./run.sh "$SRC" -o "$OUT"    # 调用项目自带脚本完成编译+运行
  else
    echo "!!! 跳过：找不到 $SRC"
  fi
done

echo -e "\nAll samples finished."
