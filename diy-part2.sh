# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)

# 删除自定义源默认的 argon 主题
rm -rf package/lean/luci-theme-argon

# 拉取 主题
#git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon.git package/lean/luci-theme-argon

git clone https://github.com/esirplayground/luci-theme-atmaterial-ColorIcon.git package/lean/luci-theme-atmaterial-ColorIcon


#单独添加软件包
git clone https://github.com/lisaac/luci-app-dockerman package/dockerman
git clone https://github.com/ElvenP/luci-app-onliner package/onliner
git clone https://github.com/siwind/luci-app-wolplus package/luci-app-wolplus

# 替换默认主题为 luci-theme-argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/' feeds/luci/collections/luci/Makefile

# 设置默认IP为 
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate

# 删除默认密码
sed -i "/CYXluq4wUazHjmCDBCqXF/d" package/lean/default-settings/files/zzz-default-settings

#添加修改名字
sed -i "s/OpenWrt /ElvenP Compiled in $(TZ=UTC-8 date "+%Y.%m.%d") OpenWrt /g" package/lean/default-settings/files/zzz-default-settings
