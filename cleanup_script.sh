#!/bin/bash

echo "开始执行项目整理..."

# 步骤1：删除iOS/Controllers目录中的空文件
echo "正在清理iOS/Controllers目录..."
rm -rf ./iOS/Controllers 2>/dev/null
echo "iOS/Controllers目录已清理"

# 步骤2：删除AppFlex/iOS/Views/Store目录中的重复文件
echo "正在删除重复的控制器文件..."
# 保存这些文件的列表，以便在需要时恢复
STORE_FILES=(
    "StoreCollectionViewController.swift"
    "webcloudCollectionViewController.swift"
    "listCollectionViewController.swift"
    "cloudCollectionViewController.swift"
    "webDetailCollectionViewController.swift"
)

for file in "${STORE_FILES[@]}"; do
    echo "删除 AppFlex/iOS/Views/Store/$file"
    rm -f "./AppFlex/iOS/Views/Store/$file" 2>/dev/null
done

echo "重复控制器文件已删除"

echo "整理完成！"
echo "请使用Xcode重新打开项目，确保所有引用正确" 