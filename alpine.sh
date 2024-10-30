#!/bin/sh

# 检查 sing-box 是否已经安装并运行，如果正在运行则停止它
if rc-service sing-box status >/dev/null 2>&1; then
    echo "sing-box 已在运行，正在停止它以继续安装..."
    rc-service sing-box stop
    echo "sing-box 已停止。"
else
    echo "sing-box 未运行，准备进行安装。"
fi

# 添加 Tsinghua 的源地址
echo "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/testing" >> /etc/apk/repositories
echo "已添加 Tsinghua 源地址。"

# 安装 openssl 和 sing-box
apk add openssl sing-box curl
echo "已安装 openssl 和 sing-box。"

# 获取当前服务器的 IP 地址
server_ip=$(curl -s https://api.ipify.org)  # 获取当前服务器的 IP 地址
# 获取国家代码
country_code=$(curl -s "https://ipinfo.io/$server_ip/country")

# 检查 jq 是否已安装，如果没有则安装
if ! command -v jq >/dev/null 2>&1; then
    echo "jq 未安装，正在安装..."
    apk add jq
    if [ $? -ne 0 ]; then
        echo "安装 jq 失败，请检查你的包管理器设置。"
        exit 1
    fi
    echo "jq 安装完成。"
else
    echo "jq 已安装，跳过安装步骤。"
fi

# 根据国家代码获取中文国家名称
country_name=$(curl -s "https://restcountries.com/v3.1/alpha/$country_code" | jq -r '.[0].translations.zho.common')

# 检查是否成功获取中文国家名称
if [ -z "$country_name" ]; then
    echo "无法获取中文国家名称，使用国家代码：$country_code"
    country_name="未知国家"
fi

echo "当前服务器的 IP 地址是：$server_ip"
echo "当前服务器所属国家：$country_name"

# 设置默认路径
default_certificate_path="/root/data/ssl/sing-box/server.crt"
default_key_path="/root/data/ssl/sing-box/server.key"

# 提示用户是否自定义证书路径
echo "是否自定义证书和密钥路径？（y/n，默认n）："
read customize_paths

# 处理证书路径选择
if [ "$customize_paths" = "y" ]; then
    # 用户选择自定义路径
    echo "请输入证书路径（留空则使用默认路径 $default_certificate_path）："
    read certificate_path
    certificate_path=${certificate_path:-$default_certificate_path}

    echo "请输入密钥路径（留空则使用默认路径 $default_key_path）："
    read key_path
    key_path=${key_path:-$default_key_path}

    # 验证路径是否有效
    cert_dir=$(dirname "$certificate_path")
    key_dir=$(dirname "$key_path")

    if [ ! -d "$cert_dir" ] || [ ! -d "$key_dir" ]; then
        echo "错误：指定的证书或密钥目录不存在。请检查路径并重试。"
        exit 1
    fi
else
    # 用户选择默认路径
    certificate_path=$default_certificate_path
    key_path=$default_key_path
    # 创建默认证书目录
    mkdir -p /root/data/ssl/sing-box
    echo "默认证书目录已创建：/root/data/ssl/sing-box。"
fi

# 生成自签名证书
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) \
  -keyout "$key_path" \
  -out "$certificate_path" \
  -subj "/CN=bing.com" -days 36500
echo "自签名证书已生成并保存到指定路径。"

# 提示用户输入端口号并验证
while true; do
    echo "请输入端口号（0-65535）："
    read listen_port

    # 检查输入是否为有效数字且在范围内
    if echo "$listen_port" | grep -Eq '^[0-9]+$' && [ "$listen_port" -ge 0 ] && [ "$listen_port" -le 65535 ]; then
        echo "端口号已设置为：$listen_port"
        break
    else
        echo "输入无效，请输入一个在0到65535之间的端口号。"
    fi
done

# 提示用户输入密码并验证
while true; do
    echo "请输入密码："
    read password  # 不隐藏输入

    # 检查密码是否为空
    if [ -n "$password" ]; then
        echo "密码已设置。"
        break
    else
        echo "密码不能为空，请重新输入。"
    fi
done

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
        "certificate_path": "$certificate_path",
        "key_path": "$key_path"
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
echo "sing-box 配置文件已创建：/etc/sing-box/config.json。"

# 设置 sing-box 为开机启动
rc-update add sing-box default
echo "sing-box 已设置为开机启动。"

# 启动 sing-box
rc-service sing-box start
echo "sing-box 已启动。"

# 输出 hysteria2 URL
echo "hysteria2://$password@$server_ip:$listen_port?sni=www.bing.com&insecure=1#自建$country_name"

# 查看 sing-box 状态
rc-service sing-box status
