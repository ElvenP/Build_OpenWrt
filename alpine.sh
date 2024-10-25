#!/bin/sh

# 提示用户输入端口号并验证
while true; do
    echo "请输入端口号（0-65535）："
    read listen_port

    # 检查输入是否为有效数字且在范围内
    if echo "$listen_port" | grep -Eq '^[0-9]+$' && [ "$listen_port" -ge 0 ] && [ "$listen_port" -le 65535 ]; then
        break
    else
        echo "输入无效，请输入一个在0到65535之间的端口号。"
    fi
done

# 提示用户输入密码并验证
while true; do
    echo "请输入密码："
    read -s password  # 使用 -s 选项隐藏输入

    # 检查密码是否为空
    if [ -n "$password" ]; then
        break
    else
        echo "密码不能为空，请重新输入。"
    fi
done

# 检查 sing-box 是否已经安装并运行，如果正在运行则停止它
if rc-service sing-box status >/dev/null 2>&1; then
    echo "sing-box 已在运行，将停止它以继续安装..."
    rc-service sing-box stop
fi

# 添加 Tsinghua 的源地址
echo "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/testing" >> /etc/apk/repositories

# 更新包列表并安装 openssl 和 sing-box
apk update
apk add openssl sing-box

# 创建证书目录
mkdir -p /root/data/ssl/sing-box

# 生成自签名证书
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout /root/data/ssl/sing-box/server.key \
  -out /root/data/ssl/sing-box/server.crt \
  -subj "/CN=bing.com" -days 36500

# 创建 sing-box 配置文件
cat << EOF > /etc/sing-box/config.json
{
  "log": {
    "level": "info"
  },
  "dns": {
    "servers": [
      {
        "address": "tls://8.8.8.8"
      }
    ]
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "listen": "::",
      "listen_port": $listen_port,
      "up_mbps": 1000,
      "down_mbps": 1000,
      "users": [
        {
          "name": "py",
          "password": "$password"
        }
      ],
      "ignore_client_bandwidth": false,
      "tls": {
        "enabled": true,
        "certificate_path": "/root/data/ssl/sing-box/server.crt",
        "key_path": "/root/data/ssl/sing-box/server.key"
      },
      "masquerade": "https://bing.com"
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      }
    ]
  }
}
EOF

# 设置 sing-box 为开机启动
rc-update add sing-box default

# 启动 sing-box
rc-service sing-box start

echo "sing-box 已成功安装和配置，并设置为开机启动"
echo "监听端口为：$listen_port"
