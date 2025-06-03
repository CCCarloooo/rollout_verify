#!/bin/bash

echo "=== 检查实际的环境管理工具 ==="

# 1. 检查当前环境信息
echo "1. 当前环境信息:"
echo "   提示符显示: $(echo $PS1 | grep -o '([^)]*)')"
echo "   CONDA_DEFAULT_ENV: $CONDA_DEFAULT_ENV"
echo "   CONDA_PREFIX: $CONDA_PREFIX"

# 2. 检查 conda 命令
echo ""
echo "2. 检查 conda 命令:"
if command -v conda > /dev/null 2>&1; then
    echo "✓ conda 命令可用"
    conda --version
    conda info --envs | head -10
else
    echo "❌ conda 命令不可用"
fi

# 3. 检查 micromamba 命令
echo ""
echo "3. 检查 micromamba 命令:"
if command -v micromamba > /dev/null 2>&1; then
    echo "✓ micromamba 命令可用"
    micromamba --version
else
    echo "❌ micromamba 命令不可用"
fi

# 4. 检查可能的别名
echo ""
echo "4. 检查别名:"
alias | grep -i conda || echo "无 conda 相关别名"
alias | grep -i micromamba || echo "无 micromamba 相关别名"

# 5. 检查 conda 环境列表
echo ""
echo "5. 检查环境列表:"
if conda info --envs 2>/dev/null; then
    echo "✓ 找到 conda 环境"
else
    echo "❌ 无法获取 conda 环境列表"
fi

# 6. 测试直接使用 conda 激活环境
echo ""
echo "6. 测试 conda 环境激活:"
eval "$(conda shell.bash hook)"
conda activate vllmqw25

echo "激活后的环境: $CONDA_DEFAULT_ENV"
echo "Python 路径: $(which python)"

# 7. 测试 io_tools
echo ""
echo "7. 测试 io_tools (使用 conda):"

python -c "
try:
    import io_tools
    print('✓ io_tools 导入成功！')
    print(f'模块位置: {io_tools.__file__}')
except ImportError as e:
    print(f'❌ io_tools 导入失败: {e}')
    import os
    if os.path.exists('io_tools.py'):
        print('✓ 但是 io_tools.py 文件存在于当前目录')
    else:
        print('❌ 当前目录也没有 io_tools.py')
"

echo ""
echo "=== 建议的修复方案 ==="
echo "基于检查结果，你应该在脚本中使用:"
echo "  eval \"\$(conda shell.bash hook)\""
echo "  conda activate /opt/conda/envs/vllmqw25"
echo "而不是 micromamba 命令"