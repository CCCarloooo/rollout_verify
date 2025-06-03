# Shell 脚本语法详解与示例

本文档详细解释了EvaluateMarco.sh脚本中使用的所有Shell语法特性，并提供实用的例子。

## 目录
1. [基础语法](#1-基础语法)
2. [变量操作](#2-变量操作)
3. [条件判断](#3-条件判断)
4. [循环结构](#4-循环结构)
5. [数组操作](#5-数组操作)
6. [字符串处理](#6-字符串处理)
7. [算术运算](#7-算术运算)
8. [文件操作](#8-文件操作)
9. [进程控制](#9-进程控制)
10. [重定向和管道](#10-重定向和管道)
11. [函数和脚本](#11-函数和脚本)
12. [特殊变量](#12-特殊变量)
13. [高级特性](#13-高级特性)

---

## 1. 基础语法

### 1.1 Shebang 行
```bash
#!/bin/bash          # 指定bash解释器
#!/usr/bin/env bash  # 使用env查找bash（更通用）
#!/bin/sh            # 使用sh解释器
```

### 1.2 脚本选项设置
```bash
set -e               # 遇到错误立即退出
set -u               # 使用未定义变量时报错
set -x               # 显示执行的命令（调试用）
set -o pipefail      # 管道中任何命令失败都会导致整个管道失败
set -euxo pipefail   # 组合使用多个选项
```

### 1.3 注释
```bash
# 这是单行注释
echo "hello"  # 行末注释

: '
这是多行注释
可以写多行内容
'
```

---

## 2. 变量操作

### 2.1 变量定义和赋值
```bash
name="张三"           # 字符串赋值
age=25               # 数字赋值
readonly pi=3.14     # 只读变量
declare -r const=100 # 声明只读变量
unset name           # 删除变量
```

### 2.2 变量引用
```bash
echo $name           # 基本引用
echo ${name}         # 推荐写法，避免歧义
echo "${name}先生"    # 字符串拼接
```

### 2.3 位置参数
```bash
echo $0              # 脚本名称
echo $1              # 第1个参数
echo $2              # 第2个参数
echo ${10}           # 第10个参数（需要花括号）
echo $@              # 所有参数（分别加引号）
echo $*              # 所有参数（作为一个字符串）
echo $#              # 参数个数
```

### 2.4 变量默认值
```bash
# 如果var为空或未定义，使用默认值
echo ${var:-"默认值"}

# 如果var为空或未定义，设置并返回默认值
echo ${var:="默认值"}

# 如果var非空，返回替换值
echo ${var:+"替换值"}

# 如果var为空或未定义，打印错误并退出
echo ${var:?"变量必须设置"}
```

### 2.5 间接变量引用
```bash
varname="age"
age=25
echo ${!varname}     # 输出: 25（相当于echo $age）
```

---

## 3. 条件判断

### 3.1 test 命令和 [ ]
```bash
# 文件测试
[ -f file.txt ]      # 文件存在且是普通文件
[ -d directory ]     # 目录存在
[ -e path ]          # 路径存在（文件或目录）
[ -r file.txt ]      # 文件可读
[ -w file.txt ]      # 文件可写
[ -x file.txt ]      # 文件可执行
[ -s file.txt ]      # 文件非空

# 字符串测试
[ -z "$str" ]        # 字符串为空
[ -n "$str" ]        # 字符串非空
[ "$str1" = "$str2" ] # 字符串相等
[ "$str1" != "$str2" ] # 字符串不等

# 数值比较
[ $num1 -eq $num2 ]  # 等于
[ $num1 -ne $num2 ]  # 不等于
[ $num1 -lt $num2 ]  # 小于
[ $num1 -le $num2 ]  # 小于等于
[ $num1 -gt $num2 ]  # 大于
[ $num1 -ge $num2 ]  # 大于等于
```

### 3.2 [[ ]] 扩展测试
```bash
# 模式匹配
[[ $filename == *.txt ]]      # 文件名匹配模式
[[ $str =~ ^[0-9]+$ ]]        # 正则表达式匹配

# 逻辑运算
[[ $a -gt 5 && $b -lt 10 ]]   # 逻辑与
[[ $a -eq 1 || $b -eq 2 ]]    # 逻辑或
[[ ! -f file.txt ]]           # 逻辑非
```

### 3.3 条件结构
```bash
# if 语句
if [ $age -ge 18 ]; then
    echo "成年人"
elif [ $age -ge 13 ]; then
    echo "青少年"
else
    echo "儿童"
fi

# case 语句
case $choice in
    1|yes|y)
        echo "选择了是"
        ;;
    2|no|n)
        echo "选择了否"
        ;;
    *)
        echo "无效选择"
        ;;
esac
```

---

## 4. 循环结构

### 4.1 for 循环
```bash
# 遍历列表
for item in apple banana orange; do
    echo $item
done

# 遍历文件
for file in *.txt; do
    echo "处理文件: $file"
done

# C风格循环
for ((i=1; i<=10; i++)); do
    echo $i
done

# 遍历数组
arr=("a" "b" "c")
for item in "${arr[@]}"; do
    echo $item
done
```

### 4.2 while 循环
```bash
counter=1
while [ $counter -le 10 ]; do
    echo $counter
    counter=$((counter + 1))
done

# 读取文件行
while IFS= read -r line; do
    echo "行内容: $line"
done < file.txt
```

### 4.3 until 循环
```bash
counter=1
until [ $counter -gt 10 ]; do
    echo $counter
    counter=$((counter + 1))
done
```

### 4.4 循环控制
```bash
for i in {1..10}; do
    if [ $i -eq 5 ]; then
        continue        # 跳过当前迭代
    fi
    if [ $i -eq 8 ]; then
        break          # 退出循环
    fi
    echo $i
done
```

---

## 5. 数组操作

### 5.1 数组定义
```bash
# 方法1：直接赋值
arr=(apple banana orange)

# 方法2：逐个赋值
fruits[0]="apple"
fruits[1]="banana"
fruits[2]="orange"

# 方法3：declare声明
declare -a numbers=(1 2 3 4 5)
```

### 5.2 数组访问
```bash
echo ${arr[0]}       # 访问第一个元素
echo ${arr[@]}       # 所有元素
echo ${arr[*]}       # 所有元素（作为单个字符串）
echo ${#arr[@]}      # 数组长度
echo ${!arr[@]}      # 所有索引
```

### 5.3 数组操作
```bash
# 添加元素
arr+=(grape)
arr[${#arr[@]}]="watermelon"

# 删除元素
unset arr[1]

# 切片
echo ${arr[@]:1:3}   # 从索引1开始，取3个元素

# 遍历数组
for i in "${!arr[@]}"; do
    echo "索引$i: ${arr[$i]}"
done
```

---

## 6. 字符串处理

### 6.1 字符串长度
```bash
str="hello world"
echo ${#str}         # 输出: 11
```

### 6.2 字符串截取
```bash
str="hello world"
echo ${str:0:5}      # 输出: hello （从位置0开始，取5个字符）
echo ${str:6}        # 输出: world （从位置6到结尾）
echo ${str: -5}      # 输出: world （倒数5个字符）
```

### 6.3 字符串删除
```bash
filename="test.tar.gz"
echo ${filename#*.}      # 输出: tar.gz （删除左边最短匹配）
echo ${filename##*.}     # 输出: gz （删除左边最长匹配）
echo ${filename%.*}      # 输出: test.tar （删除右边最短匹配）
echo ${filename%%.*}     # 输出: test （删除右边最长匹配）
```

### 6.4 字符串替换
```bash
str="hello world world"
echo ${str/world/WORLD}      # 输出: hello WORLD world （替换第一个）
echo ${str//world/WORLD}     # 输出: hello WORLD WORLD （替换所有）
echo ${str/#hello/hi}        # 输出: hi world world （替换开头）
echo ${str/%world/WORLD}     # 输出: hello world WORLD （替换结尾）
```

### 6.5 大小写转换
```bash
str="Hello World"
echo ${str^^}        # 输出: HELLO WORLD （转大写）
echo ${str,,}        # 输出: hello world （转小写）
echo ${str^}         # 输出: Hello World （首字母大写）
echo ${str,}         # 输出: hello World （首字母小写）
```

---

## 7. 算术运算

### 7.1 $(( )) 算术展开
```bash
result=$((5 + 3))            # 加法
result=$((10 - 3))           # 减法
result=$((4 * 5))            # 乘法
result=$((10 / 3))           # 除法（整数）
result=$((10 % 3))           # 取余
result=$((2 ** 3))           # 幂运算

# 自增自减
i=5
echo $((i++))                # 输出5，然后i变成6
echo $((++i))                # i先变成7，然后输出7
echo $((i--))                # 输出7，然后i变成6
echo $((--i))                # i先变成5，然后输出5
```

### 7.2 let 命令
```bash
let "result = 5 + 3"
let "i++"
let "j *= 2"
```

### 7.3 expr 命令
```bash
result=$(expr 5 + 3)         # 注意操作符两边要有空格
result=$(expr $a \* $b)      # 乘号需要转义
```

### 7.4 bc 命令（浮点运算）
```bash
result=$(echo "scale=2; 10/3" | bc)    # 输出: 3.33
result=$(echo "sqrt(16)" | bc)         # 输出: 4
```

---

## 8. 文件操作

### 8.1 基本文件命令
```bash
touch file.txt              # 创建空文件
mkdir -p dir1/dir2          # 递归创建目录
cp source dest              # 复制文件
mv old new                  # 移动/重命名
rm -rf dir                  # 递归删除目录
ln -s target link           # 创建符号链接
```

### 8.2 文件内容操作
```bash
cat file.txt                # 显示文件内容
head -n 10 file.txt         # 显示前10行
tail -n 10 file.txt         # 显示后10行
tail -f file.txt            # 实时监控文件变化
wc -l file.txt              # 统计行数
wc -w file.txt              # 统计单词数
```

### 8.3 文件查找
```bash
find . -name "*.txt"        # 按名称查找文件
find . -type f -size +1M    # 查找大于1MB的文件
find . -mtime -7            # 查找7天内修改的文件
locate filename             # 快速查找文件（需要updatedb）
which command               # 查找命令位置
```

### 8.4 文件权限
```bash
chmod 755 file.txt          # 设置权限
chmod +x script.sh          # 添加执行权限
chown user:group file.txt   # 改变所有者
chgrp group file.txt        # 改变组
```

---

## 9. 进程控制

### 9.1 后台进程
```bash
command &                   # 后台运行命令
nohup command &             # 后台运行，忽略挂断信号
jobs                        # 显示当前作业
fg %1                       # 将作业1调到前台
bg %1                       # 将作业1放到后台
kill %1                     # 杀死作业1
```

### 9.2 进程等待
```bash
command1 &
pid1=$!                     # 获取最后一个后台进程的PID
command2 &
pid2=$!

wait $pid1                  # 等待特定进程
wait                        # 等待所有后台进程
```

### 9.3 信号处理
```bash
# trap 捕获信号
trap 'echo "收到中断信号"' INT
trap 'echo "脚本退出"; cleanup' EXIT
trap 'echo "收到TERM信号"' TERM

# 发送信号
kill -INT $pid              # 发送中断信号
kill -TERM $pid             # 发送终止信号
kill -KILL $pid             # 强制杀死进程
killall process_name        # 杀死所有同名进程
```

---

## 10. 重定向和管道

### 10.1 输出重定向
```bash
command > file.txt          # 重定向到文件（覆盖）
command >> file.txt         # 重定向到文件（追加）
command 2> error.log        # 重定向错误输出
command > out.txt 2>&1      # 重定向标准输出和错误输出
command &> all.log          # 同上的简写形式
command > /dev/null 2>&1    # 丢弃所有输出
```

### 10.2 输入重定向
```bash
command < input.txt         # 从文件读取输入
command <<< "string"        # 从字符串读取输入
```

### 10.3 管道
```bash
command1 | command2         # 将command1的输出作为command2的输入
ps aux | grep nginx         # 查找nginx进程
cat file.txt | sort | uniq  # 排序并去重
```

### 10.4 Here Document
```bash
cat << EOF
这是一个
多行文本
EOF

# 不进行变量替换
cat << 'EOF'
$HOME 不会被替换
EOF

# 重定向到文件
cat > config.txt << EOF
name=value
port=8080
EOF
```

---

## 11. 函数和脚本

### 11.1 函数定义
```bash
# 方法1
function greet() {
    echo "Hello, $1!"
}

# 方法2
greet() {
    echo "Hello, $1!"
    return 0
}

# 调用函数
greet "张三"
```

### 11.2 函数参数和返回值
```bash
calculate() {
    local a=$1
    local b=$2
    local result=$((a + b))
    echo $result    # 通过echo返回值
}

result=$(calculate 5 3)
echo "结果: $result"
```

### 11.3 局部变量
```bash
my_function() {
    local local_var="只在函数内可见"
    global_var="全局可见"
}
```

### 11.4 脚本包含
```bash
source script.sh            # 在当前shell中执行脚本
. script.sh                 # 同上的简写形式
bash script.sh              # 在新shell中执行脚本
```

---

## 12. 特殊变量

### 12.1 位置参数
```bash
$0                          # 脚本名称
$1, $2, ...                 # 位置参数
$@                          # 所有参数（数组形式）
$*                          # 所有参数（字符串形式）
$#                          # 参数个数
```

### 12.2 状态变量
```bash
$?                          # 上一个命令的退出状态
$$                          # 当前shell的PID
$!                          # 最后一个后台进程的PID
$PPID                       # 父进程PID
```

### 12.3 环境变量
```bash
$HOME                       # 用户主目录
$USER                       # 当前用户名
$PATH                       # 执行路径
$PWD                        # 当前工作目录
$OLDPWD                     # 前一个工作目录
$SHELL                      # 当前shell
$RANDOM                     # 随机数
```

---

## 13. 高级特性

### 13.1 命令替换
```bash
current_date=$(date)        # 推荐写法
current_date=`date`         # 旧写法

files_count=$(ls | wc -l)
echo "文件数量: $files_count"
```

### 13.2 进程替换
```bash
diff <(sort file1.txt) <(sort file2.txt)
echo "data" > >(command)
```

### 13.3 大括号展开
```bash
echo {1..10}                # 输出: 1 2 3 4 5 6 7 8 9 10
echo {a..z}                 # 输出: a b c ... z
echo file{1,2,3}.txt        # 输出: file1.txt file2.txt file3.txt
```

### 13.4 通配符
```bash
*.txt                       # 匹配所有.txt文件
file?.log                   # 匹配file1.log, fileA.log等
file[0-9].txt              # 匹配file0.txt到file9.txt
file[!0-9].txt             # 匹配不是数字的
```

### 13.5 条件执行
```bash
command1 && command2        # command1成功才执行command2
command1 || command2        # command1失败才执行command2
command1; command2          # 顺序执行，不管成功失败
```

---

## 实用技巧

### 1. 调试脚本
```bash
bash -x script.sh           # 显示执行过程
bash -n script.sh           # 检查语法不执行
```

### 2. 错误处理
```bash
set -e                      # 遇到错误立即退出
set -u                      # 使用未定义变量时报错
set -o pipefail             # 管道命令失败时退出
```

### 3. 安全编程
```bash
# 总是使用双引号
echo "$variable"

# 检查变量是否设置
: ${VAR:?"变量VAR必须设置"}

# 使用local关键字
function my_func() {
    local var="局部变量"
}
```

### 4. 性能优化
```bash
# 避免不必要的子shell
((count++))                 # 而不是 count=$((count + 1))

# 使用内置命令
[[ condition ]]             # 而不是 test condition
```

这个语法总结涵盖了Shell脚本的所有重要特性，可以作为编写和理解复杂Shell脚本的参考手册。 