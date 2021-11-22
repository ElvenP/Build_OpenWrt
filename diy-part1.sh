# Add a feed source
#cat >> feeds.conf.default <<EOF
#src-git kenzo https://github.com/kenzok8/openwrt-packages
#src-git small https://github.com/kenzok8/small
#EOF

git clone https://github.com/kenzok8/openwrt-packages.git package/openwrt-packages
 
git clone https://github.com/kenzok8/small.git package/small
