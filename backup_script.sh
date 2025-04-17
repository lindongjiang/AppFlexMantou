#!/bin/bash

# 创建备份目录
BACKUP_DIR="./backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "创建备份目录: $BACKUP_DIR"

# 备份AppFlexNew目录
echo "备份AppFlexNew目录..."
mkdir -p "$BACKUP_DIR/AppFlexNew"
cp -R ./AppFlexNew/* "$BACKUP_DIR/AppFlexNew/"

# 备份AppFlex/iOS/Views/Store目录
echo "备份AppFlex/iOS/Views/Store目录..."
mkdir -p "$BACKUP_DIR/AppFlex/iOS/Views/Store"
cp -R ./AppFlex/iOS/Views/Store/* "$BACKUP_DIR/AppFlex/iOS/Views/Store/"

# 备份iOS/Controllers目录
echo "备份iOS/Controllers目录..."
mkdir -p "$BACKUP_DIR/iOS/Controllers"
cp -R ./iOS/Controllers/* "$BACKUP_DIR/iOS/Controllers/" 2>/dev/null || echo "iOS/Controllers目录为空或不存在"

# 备份AppFlex/AppFlexApp.swift
echo "备份AppFlex/AppFlexApp.swift..."
mkdir -p "$BACKUP_DIR/AppFlex"
cp ./AppFlex/AppFlexApp.swift "$BACKUP_DIR/AppFlex/" 2>/dev/null || echo "AppFlex/AppFlexApp.swift不存在"

echo "备份完成!"
echo "备份路径: $BACKUP_DIR" 