#!/bin/bash

# 变量


port="9902:9902"
hex_pub_key="0409F9DF311E5421A150DD7D161E4BC5C672179FAD1833FC076BB08FF356F35020CCEA490CE26775A52DC6EA718CC1AA600AED05FBF35E084A6632F6072DA9AD13"
hex_pri_key="3945208F7B2144B13F36E38AC6D39F95889393692860B51A42FB81EF4DF7C5B8"
config="envoy.yaml"
folder="envoy"

path="$(pwd)/${folder}"
configpath="${path}/${config}"

run="docker run -e HEX_PUB_KEY=${hex_pub_key} -e HEX_PRI_KEY=${hex_pri_key} -p ${port} -v ${path}:/home/envoy/custom ccr.ccs.tencentyun.com/weixincloud/wxsmgw:v1 /usr/local/bin/envoy -c /home/envoy/custom/${config} -l debug"

colorbegin="\e[31m"
colorend="\e[0m"

printf "${colorbegin}"
printf "%s\n\n" "----------config begin----------"
printf "%s\n" "${port}"
printf "%s\n" "${hex_pub_key}"
printf "%s\n" "${hex_pri_key}"
printf "%s\n" "${config}"
printf "%s\n" "${folder}"
printf "%s\n" "${path}"
printf "%s\n" "${configpath}"
printf "%s\n" "${run}"
printf "\n%s\n" "-----------config end-----------"
printf "${colorend}\n"

# 检查docker安装

# 创建文件夹

echo "Create Dir ${path}"
if [ ! -d ${path} ]; then
    mkdir ${path}
fi
cd ${path}
echo "Now path is ${path}"
echo "Create Dir End"

echo " ...... "

# 创建envoy.yaml配置文件

echo "Create ${config} Begin"

if [ ! -f ${configpath} ]; then
cat > ${configpath} <<- EOF
admin:
  access_log_path: /dev/stdout
  address:
    socket_address: { address: 127.0.0.1, port_value: 9901 }

static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        protocol: TCP
        address: 0.0.0.0
        port_value: 9902
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          scheme_header_transformation:
            scheme_to_overwrite: https
          stat_prefix: ingress_http
          access_log:
            - name: envoy.access_loggers.stdout
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  auto_host_rewrite: true
                  cluster: httpbin
          http_filters:
          - name: sm
            typed_config:
              "@type": type.googleapis.com/sm.SM
              enable: true
              hex_pub_key:
                environment_variable: HEX_PUB_KEY
              hex_pri_key:
                environment_variable: HEX_PRI_KEY
              pem_appid:
                inline_string: WXFinGate_Test
              pem_cert:
                filename: /home/envoy/sm.crt
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
  clusters:
  - name: httpbin
    connect_timeout: 30s
    type: LOGICAL_DNS
    dns_lookup_family: V4_ONLY
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: httpbin
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: httpbin.org
                port_value: 80
EOF
fi

echo "Create Config Succ"

echo " ...... "

echo "Docker Run ..."

$run

echo "Docker Run Succ"
