# AppFlex项目整理计划

## 背景
在项目中发现了多个重复的文件，分布在不同的目录中：
- AppFlexNew/
- AppFlex/iOS/Views/Store/
- iOS/Controllers/

这种重复会导致维护困难，可能造成代码差异和BUG。

## 整理目标
1. 保持业务逻辑完整性
2. 消除重复文件
3. 规范化项目结构

## 文件处理策略

### 1. 保留的文件
以AppFlexNew/目录下的文件为主要版本，包括：
- StoreCollectionViewController.swift
- webcloudCollectionViewController.swift
- listCollectionViewController.swift
- cloudCollectionViewController.swift
- webDetailCollectionViewController.swift

### 2. 需要合并的文件
将以下文件内容合并，以AppFlexNew版本为基础，保留AppFlex版本中的额外功能：
- AppFlex/AppFlexApp.swift → 与AppFlexNew/AppFlexApp.swift合并

### 3. 需要删除的文件
删除以下重复文件：
- iOS/Controllers/StoreCollectionViewController.swift (空文件)
- iOS/Controllers/WebcloudCollectionViewController.swift (空文件)
- AppFlex/iOS/Views/Store/StoreCollectionViewController.swift (重复)
- AppFlex/iOS/Views/Store/webcloudCollectionViewController.swift (重复)
- AppFlex/iOS/Views/Store/listCollectionViewController.swift (重复)
- AppFlex/iOS/Views/Store/cloudCollectionViewController.swift (重复)
- AppFlex/iOS/Views/Store/webDetailCollectionViewController.swift (重复)

## 执行步骤
1. 备份所有文件
2. 删除iOS/Controllers目录中的空文件
3. 比较并合并AppFlexApp.swift文件
4. 删除AppFlex/iOS/Views/Store目录中的重复文件
5. 修改项目引用，确保引用AppFlexNew目录下的文件

## 注意事项
- 保留最新的功能实现
- 确保TabbarView.swift中的引用指向正确位置
- 执行前进行完整备份 