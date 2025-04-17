#!/bin/bash

echo "开始合并AppFlexApp.swift文件..."

# 检查文件是否存在
if [ ! -f "./AppFlex/AppFlexApp.swift" ]; then
    echo "错误: AppFlex/AppFlexApp.swift不存在"
    exit 1
fi

if [ ! -f "./AppFlexNew/AppFlexApp.swift" ]; then
    echo "错误: AppFlexNew/AppFlexApp.swift不存在"
    exit 1
fi

# 创建临时目录
TEMP_DIR="./temp_merge"
mkdir -p "$TEMP_DIR"

# 复制文件到临时目录
cp "./AppFlex/AppFlexApp.swift" "$TEMP_DIR/AppFlexApp_orig.swift"
cp "./AppFlexNew/AppFlexApp.swift" "$TEMP_DIR/AppFlexApp_new.swift"

# 生成一个合并的文件
MERGED_FILE="$TEMP_DIR/AppFlexApp_merged.swift"

echo "// 合并后的AppFlexApp.swift文件，基于AppFlexNew，包含AppFlex中的额外功能" > "$MERGED_FILE"
echo "// 合并日期: $(date)" >> "$MERGED_FILE"
echo "" >> "$MERGED_FILE"

# 提示手动合并
echo "需要手动合并两个文件:"
echo "原始文件: $TEMP_DIR/AppFlexApp_orig.swift"
echo "新版文件: $TEMP_DIR/AppFlexApp_new.swift"
echo "请使用文本编辑器或diff工具合并这两个文件，并将结果保存到: $MERGED_FILE"
echo "合并完成后，运行以下命令将合并后的文件复制到项目中:"
echo "cp \"$MERGED_FILE\" \"./AppFlexNew/AppFlexApp.swift\""

echo "合并准备工作完成!" 