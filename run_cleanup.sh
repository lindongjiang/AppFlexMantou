#!/bin/bash

echo "=== AppFlex项目整理工具 ==="
echo "此脚本将执行以下操作:"
echo "1. 备份所有相关文件"
echo "2. 清理重复的控制器文件"
echo "3. 准备合并AppFlexApp.swift文件"
echo "4. 更新项目引用"
echo ""
echo "警告: 此操作会修改项目文件，请确保您已经了解操作的影响。"
read -p "是否继续? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 1
fi

# 检查脚本是否存在
if [ ! -f "./backup_script.sh" ] || [ ! -f "./cleanup_script.sh" ] || [ ! -f "./merge_app_file.sh" ] || [ ! -f "./update_references.sh" ]; then
    echo "错误: 缺少必要的脚本文件"
    exit 1
fi

# 设置脚本为可执行
chmod +x ./backup_script.sh
chmod +x ./cleanup_script.sh
chmod +x ./merge_app_file.sh
chmod +x ./update_references.sh

echo "=== 第1步: 备份文件 ==="
./backup_script.sh
if [ $? -ne 0 ]; then
    echo "备份失败，操作终止"
    exit 1
fi
echo ""

echo "=== 第2步: 清理重复文件 ==="
./cleanup_script.sh
if [ $? -ne 0 ]; then
    echo "清理失败，操作终止"
    exit 1
fi
echo ""

echo "=== 第3步: 准备合并AppFlexApp.swift ==="
./merge_app_file.sh
if [ $? -ne 0 ]; then
    echo "合并准备失败，操作终止"
    exit 1
fi
echo ""

echo "=== 第4步: 更新项目引用 ==="
./update_references.sh
if [ $? -ne 0 ]; then
    echo "更新引用失败，操作终止"
    exit 1
fi
echo ""

echo "=== 整理操作完成 ==="
echo "请检查项目，确保所有文件和引用都正确"
echo "请使用Xcode重新打开项目，测试应用功能" 