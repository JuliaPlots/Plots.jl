#!/bin/sh
set -ex
sudo add-apt-repository -y ppa:pov/wkhtmltopdf
sudo apt-get -qq update
sudo apt-get install -y wkhtmltopdf
wkhtmltopdf -V
wkhtmltoimage -V
# echo 'exec xvfb-run -a -s "-screen 0 640x480x16" wkhtmltoimage "$@"' | sudo tee /usr/local/bin/wkhtmltoimage.sh >/dev/null
# sudo chmod a+x /usr/local/bin/wkhtmltoimage.sh
export DISPLAY=:99.0
sh -e /etc/init.d/xvfb start
sleep 3 # give xvfb some time to start
