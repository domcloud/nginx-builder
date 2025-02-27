all: opt

NGINX_V := 1.26.2
LIBRE_V := 4.0.0
PASSENGER_V := 6.0.26
# Added by passenger itself: http_ssl_module http_v2_module http_realip_module http_gzip_static_module http_stub_status_module http_addition_module
ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
NGINX_PASSENGER_MODULES := --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_addition_module --add-module='$(ROOT_DIR)passenger/src/nginx_module'
NGINX_MODULES := --user=nginx --group=nginx --with-compat --with-debug --with-file-aio --with-http_v3_module --with-pcre --with-pcre-jit --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-threads --with-openssl="../libressl"
NGINX_OPTIMIZATIONS := --with-cc-opt='-I../libressl/build/include -O2 -flto=auto -ffat-lto-objects -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -fstack-protector-strong -fasynchronous-unwind-tables -fstack-clash-protection' --with-ld-opt='-L../libressl/build/lib -Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-E'
NGINX_FEDORA_CONFIG := --sbin-path=/usr/local/sbin/nginx --modules-path=/usr/local/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx
NGINX_DEBIAN_CONFIG := --sbin-path=/usr/local/sbin/nginx --modules-path=/usr/local/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/body --http-proxy-temp-path=/var/lib/nginx/proxy --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --http-scgi-temp-path=/var/lib/nginx/scgi --pid-path=/run/nginx.pid --lock-path=/var/lock/nginx.lock

nginx-$(NGINX_V).tar.gz:
	curl -sSLO "https://www.nginx.org/download/nginx-$(NGINX_V).tar.gz"
	
nginx: nginx-$(NGINX_V).tar.gz
	rm -rf nginx
	tar -xzf nginx-$(NGINX_V).tar.gz
	mv nginx-$(NGINX_V) nginx
	sed -i 's/ngx_msleep(100)/ngx_msleep(500)/g' nginx/src/os/unix/ngx_process_cycle.c

libressl-$(LIBRE_V).tar.gz:
	curl -sSLO https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-$(LIBRE_V).tar.gz

libressl: libressl-$(LIBRE_V).tar.gz
	rm -rf libressl
	tar -xzf libressl-$(LIBRE_V).tar.gz
	mv libressl-$(LIBRE_V) libressl

passenger-$(PASSENGER_V).tar.gz:
	touch passenger-$(PASSENGER_V).tar.gz

passenger: passenger-$(PASSENGER_V).tar.gz
	rm -rf passenger
	git clone https://github.com/phusion/passenger.git --filter=tree:0 --branch release-$(PASSENGER_V) passenger
	cd passenger && git submodule update --init --recursive
	cd passenger && git apply ../passenger.diff

opt: nginx passenger libressl
	./passenger/bin/passenger-install-nginx-module --auto --languages= \
	--nginx-source-dir=./nginx --prefix=$(PWD)/opt \
	"--extra-configure-flags=$(NGINX_MODULES) $(NGINX_OPTIMIZATIONS)"
	cp -r test/* opt

build: nginx passenger libressl
	rm -rf build
	mkdir -p build/debian
	./passenger/bin/passenger-install-nginx-module --auto --languages=ruby,python,nodejs \
	--nginx-source-dir=./nginx --prefix=/usr/local/share/nginx --nginx-no-install \
	"--extra-configure-flags=$(NGINX_DEBIAN_CONFIG) $(NGINX_MODULES) $(NGINX_OPTIMIZATIONS)"
	cp -a nginx/objs/nginx build/debian/nginx
	mkdir -p build/fedora
# For faster build we extract commands from passenger-install-nginx-module
	cd nginx && sh ./configure --prefix='/usr/local/share/nginx' \
	$(NGINX_PASSENGER_MODULES) $(NGINX_FEDORA_CONFIG) $(NGINX_MODULES) $(NGINX_OPTIMIZATIONS) && make
	cp -a nginx/objs/nginx build/fedora/nginx
	cp -a passenger/buildout build/passenger
	find build -type f -name "*.o" -delete
	tar -czvf nginx-builder.tar.gz build

install: nginx passenger libressl
# Run the Passenger installation with Nginx module
	./passenger/bin/passenger-install-nginx-module --auto --languages=ruby,python,nodejs \
	--nginx-source-dir=./nginx --prefix=/usr/local --nginx-no-install \
	"--extra-configure-flags=$(NGINX_FEDORA_CONFIG) $(NGINX_MODULES) $(NGINX_OPTIMIZATIONS)"
	cp -a nginx/objs/nginx /usr/local/sbin/nginx; chmod +x /usr/local/sbin/nginx
# Create necessary directories and set permissions
	mkdir -p /usr/local/lib64/nginx/modules /var/log/nginx /var/lib/nginx/tmp/{client_body,fastcgi,proxy,scgi,uwsgi} /etc/nginx/conf.d /var/run/passenger-instreg
	getent group nginx > /dev/null || groupadd -r nginx && id -u nginx > /dev/null 2>&1 || useradd -r -g nginx -s /sbin/nologin -d /nonexistent -c "nginx user" nginx
	chmod 0700 -R /var/log/nginx /var/lib/nginx/
	chown -R nginx:root /var/lib/nginx
	cp passenger/bin/* /usr/local/bin
	find /usr/local/bin/passenger* -type f -exec sed -i 's|source_root =.*|source_root = "$(PWD)/passenger"|g' {} +

clean:
	rm -rf libressl nginx/objs passenger/buildout/lib*
	find passenger/buildout -type f \( -name "*.o" -or -name "*.a" \) -exec rm -rf {} +

diff:
	cd passenger; git diff > ../passenger.diff

patch:
	cd passenger; git reset --hard; git apply ../passenger.diff
