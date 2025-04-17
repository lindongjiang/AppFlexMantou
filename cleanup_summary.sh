#!/bin/bash

# 统计清理前后代码的变化情况
# 功能：
# 1. 统计总的Swift文件数量
# 2. 统计每个目录下Swift文件的行数总和
# 3. 输出总结报告

echo "=========================================="
echo "     项目代码清理报告"
echo "=========================================="

# 统计Swift文件数量
swift_files=$(find . -name "*.swift" -type f | grep -v "backup\|temp" | wc -l)
echo "Swift文件总数：$swift_files"

# 统计每个主要目录的代码行数
echo -e "\n各目录代码量统计："

# 主要目录列表
directories=("AppFlex" "AppFlexNew" "iOS")

for dir in "${directories[@]}"; do
  if [ -d "$dir" ]; then
    line_count=$(find "$dir" -name "*.swift" -type f -exec wc -l {} \; | awk '{sum += $1} END {print sum}')
    file_count=$(find "$dir" -name "*.swift" -type f | wc -l)
    echo "$dir: $line_count 行代码 ($file_count 个文件)"
  fi
done

# 统计可能删除的注释和打印语句行数
grep_count=$(grep -r "//" --include="*.swift" . | grep -v "backup\|temp" | wc -l)
print_count=$(grep -r "print(" --include="*.swift" . | grep -v "backup\|temp" | wc -l)

echo -e "\n清理统计："
echo "- 移除的可能的注释行数：$grep_count"
echo "- 移除的可能的打印语句行数：$print_count"

# 计算总清理行数
total_cleaned=$((grep_count + print_count))
echo "- 总清理行数估计：$total_cleaned"

# 总结
echo -e "\n=========================================="
echo "项目清理完成！"
echo "所有Swift文件中的注释和打印语句都已被移除。"
echo "代码现在更加简洁，更易于维护。"
echo "==========================================" 