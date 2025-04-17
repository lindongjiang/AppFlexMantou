#!/bin/bash

echo "开始更新项目引用..."

# 检查TabbarView.swift文件
if [ -f "./AppFlex/iOS/Views/TabbarView.swift" ]; then
    echo "更新AppFlex/iOS/Views/TabbarView.swift中的引用..."
    
    # 创建备份
    cp "./AppFlex/iOS/Views/TabbarView.swift" "./AppFlex/iOS/Views/TabbarView.swift.bak"
    
    # 更新引用，这里假设需要添加import语句
    # 请根据实际情况修改
    sed -i '' 's/import UIKit/import UIKit\nimport AppFlexNew/' "./AppFlex/iOS/Views/TabbarView.swift" 2>/dev/null || echo "无法更新TabbarView.swift"
    
    echo "TabbarView.swift引用已更新，原文件已备份为TabbarView.swift.bak"
else
    echo "TabbarView.swift不存在于AppFlex/iOS/Views/目录"
fi

echo "引用更新完成!"
echo "请检查项目中的其他文件，确保所有引用都指向正确的位置" 