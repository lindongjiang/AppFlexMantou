#!/bin/bash

# 清理Swift文件中的注释和打印语句
# 作用：
# 1. 删除所有以 // 开头的单行注释
# 2. 删除所有形如 /* ... */ 的多行注释
# 3. 删除所有包含print(的行

# 查找所有Swift文件
find . -name "*.swift" | while read file; do
  echo "处理文件: $file"
  
  # 创建临时文件
  tmp_file="${file}.tmp"
  
  # 删除单行注释，多行注释和打印语句
  # 1. 删除以//开头的整行
  # 2. 删除形如/* ... */的多行注释（包括跨行的情况）
  # 3. 删除包含print(的行
  sed -E '
    # 删除以//开头的整行
    /^[[:space:]]*\/\//d
    
    # 删除打印语句行
    /print\(/d
  ' "$file" > "$tmp_file"
  
  # 处理跨行的/* */注释（这种注释sed很难一次处理，所以使用awk）
  awk '
    BEGIN { in_comment = 0 }
    {
      if (in_comment) {
        if (index($0, "*/") > 0) {
          # 找到注释结束位置
          rest = substr($0, index($0, "*/") + 2)
          if (rest != "") {
            print rest
          }
          in_comment = 0
        }
      } else {
        if (index($0, "/*") > 0) {
          # 找到注释开始位置
          before = substr($0, 1, index($0, "/*") - 1)
          if (index($0, "*/") > index($0, "/*")) {
            # 单行注释 /* ... */
            after = substr($0, index($0, "*/") + 2)
            if (before != "" || after != "") {
              print before after
            }
          } else {
            # 跨行注释开始
            if (before != "") {
              print before
            }
            in_comment = 1
          }
        } else {
          print $0
        }
      }
    }
  ' "$tmp_file" > "${file}.clean"
  
  # 用处理后的文件替换原文件
  mv "${file}.clean" "$file"
  
  # 删除临时文件
  rm -f "$tmp_file"
done

echo "所有Swift文件的注释和打印语句已删除完成" 