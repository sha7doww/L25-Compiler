#!/usr/bin/env bash
# ------------------------------------------------------------
# test_all.sh – 自动遍历 sample/ 子目录并跑全部用例
# ------------------------------------------------------------
set -euo pipefail

# 删除所有 .out 与 .pcode 文件，避免残留干扰本轮测试
find sample -type f \( -name '*.out' -o -name '*.pcode' \) -delete

# -------- 0. 清理旧构建，重新 build --------
echo "================ 0. clean build ================"
rm -rf build
echo "================ 1. build        ================"
./build.sh

echo -e "\n================ 2. run samples  ================"
overall_pass=true   # 记录是否所有用例均通过

for dir in sample/*/; do               # 只遍历目录
  [[ -d "$dir" ]] || continue

  case_name=$(basename "$dir")
  src="${dir}${case_name}.l25"
  in_file="${dir}${case_name}.in"
  out_file="${dir}${case_name}.out"
  ans_file="${dir}${case_name}.ans"
  pcode="${dir}${case_name}.pcode"

  echo -e "\n--- Case: $case_name ---"

  # 1) 检查源文件
  if [[ ! -f "$src" ]]; then
    echo -e "\n!!! WARNING: 缺少源码 $src ，跳过"
    overall_pass=false
    continue
  fi

  # 2) 运行
  if [[ -f "$in_file" ]]; then
    echo -e "\n(with input $in_file)"
    ./run.sh "$src" -o "$pcode" < "$in_file" | tee "$out_file"
  else
    ./run.sh "$src" -o "$pcode"       | tee "$out_file"
  fi

  # 3) 结果比对
  if [[ -f "$ans_file" ]]; then
    if diff -q "$out_file" "$ans_file" >/dev/null; then
      echo -e "\n✅  PASS : 输出与 $ans_file 一致"
    else
      echo -e "\n❌  FAIL : 输出与 $ans_file 不一致（diff 见下）"
      diff -u "$ans_file" "$out_file" || true
      overall_pass=false
    fi
  else
    echo -e "\n⚠️  NOTE : 未提供答案文件 $ans_file ，仅生成输出 $out_file"
  fi
done

echo -e "\n================ 3. summary      ================"
if $overall_pass; then
  echo -e "🎉  所有测试点均通过！\n"
  exit 0
else
  echo -e "⚠️  一些测试点失败或者缺少文件，请检查上面日志。\n"
  exit 1
fi
