all: nginx passenger opt
install: nginx passenger build

NGINX_V := 1.26.2
NGINX_MODULES := --user=nginx --group=nginx --with-compat --with-debug --with-file-aio --with-http_gunzip_module --with-http_gzip_static_module --with-http_realip_module --with-http_ssl_module --with-http_sub_module --with-http_v2_module --with-http_v3_module --with-pcre --with-pcre-jit --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-threads
NGINX_OPTIMIZATIONS := --with-cc-opt='-O2 -flto=auto -ffat-lto-objects -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -fstack-protector-strong -fasynchronous-unwind-tables -fstack-clash-protection' --with-ld-opt='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-E'

nginx-$(NGINX_V).tar.gz:
	curl -sSLO "https://www.nginx.org/download/nginx-$(NGINX_V).tar.gz"
	
nginx: nginx-$(NGINX_V).tar.gz
	tar -xzf nginx-$(NGINX_V).tar.gz
	mv nginx-$(NGINX_V) nginx
	sed -i 's/ngx_msleep(100)/ngx_msleep(2500)/g' nginx/src/os/unix/ngx_process_cycle.c

passenger:
	@echo "passenger folder not found. Cloning from GitHub..."
	git clone https://github.com/phusion/passenger.git passenger
	git submodule update --init --recursive

opt:
	./passenger/bin/passenger-install-nginx-module --auto --languages=ruby,python,nodejs \
	--nginx-source-dir=./nginx --prefix=$(PWD)/opt \
	"--extra-configure-flags=$(NGINX_MODULES) $(NGINX_OPTIMIZATIONS)"
	cp -r test/* opt

build:
	./passenger/bin/passenger-install-nginx-module --auto --languages=ruby,python,nodejs \
	--nginx-source-dir=./nginx --prefix=/usr/local \
	"--extra-configure-flags=--sbin-path=/usr/local/sbin/nginx --modules-path=/usr/local/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx $(NGINX_MODULES) $(NGINX_OPTIMIZATIONS)"

diff:
	cd passenger; git diff > ../passenger.diff
