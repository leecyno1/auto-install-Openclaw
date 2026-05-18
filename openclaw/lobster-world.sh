if [ "$AUTO_CONFIRM_ALL" = "0" ]; then
    echo "⚡ 快速启动向导 (y/N): "
    read -r quickstart
    if [[ "$quickstart" =~ ^[Yy] ]]; then
        # 自动：基础模型配置 + 中档技能 + 启动工作台
        bash config-menu.sh --quickstart --profile medium --launch-workbench
    fi
fi