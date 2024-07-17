#!/bin/bash

# 确保脚本在错误时退出并处理未定义变量
set -euo pipefail

# 检查并安装缺少的包
check_and_install_package() {
    if ! command -v "$1" &>/dev/null; then
        echo "Package $1 is not installed. Installing..."
        if [ "$(uname)" == "Darwin" ]; then
            # macOS
            brew install "$1"
        elif [ -x "$(command -v apt-get)" ]; then
            # Debian-based
            sudo apt-get update
            sudo apt-get install -y "$1"
        elif [ -x "$(command -v yum)" ]; then
            # RedHat-based
            sudo yum install -y "$1"
        else
            echo "Unsupported OS or package manager. Please install $1 manually."
            exit 1
        fi
    fi
}

# 检查并安装 jq 和 curl
check_and_install_package jq
check_and_install_package curl

# API 请求 URL 和 头部信息
# https://console.scaleway.com/iam/api-keys 去生成一个
AUTH_TOKEN="XXXXXXXXX"
# https://console.scaleway.com/organization  点击你用户名右边的那个复制按钮，既可以拿到 ORGANIZATION_ID
ORGANIZATION_ID="XXXXXXXXXXXX下"
SCALEWAY_URL="https://api.scaleway.com/billing/v2beta1/consumptions?organization_id=$ORGANIZATION_ID"

# 换成 飞书、企业微信登WebHook地址
WEBHOOK_URL="https://webhook.com"

# 使用 curl 获取 JSON 数据
response=$(curl -s -X GET -H "X-Auth-Token: $AUTH_TOKEN" "$SCALEWAY_URL") || {
    echo "Error fetching data from Scaleway API"
    exit 1
}

# 使用 jq 解析 JSON 数据并计算 nanos 的总和
nanos_total=$(echo "$response" | jq '[.consumptions[].value.nanos] | add') || {
    echo "Error parsing JSON data"
    exit 1
}

# 处理 nanos 总和（除以 1000000000）
total=$(awk "BEGIN {printf \"%.2f\", $nanos_total / 1000000000}") || {
    echo "Error calculating total"
    exit 1
}

# 准备 webhook 的 payload
payload=$(jq -n --arg title "Scaleway账单" --arg content "当前账单总额为：$total 欧" '{title: $title, content: $content}')

# 发送通知到 webhook
webhook_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK_URL") || {
    echo "Error sending webhook"
    exit 1
}
echo "webhook response: $webhook_response"

# 输出最终结果
echo "最终结果: $total"
