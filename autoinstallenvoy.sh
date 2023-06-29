#!/bin/bash

# 变量


port1="9902"
port2="9902"
hex_pub_key="0409F9DF311E5421A150DD7D161E4BC5C672179FAD1833FC076BB08FF356F35020CCEA490CE26775A52DC6EA718CC1AA600AED05FBF35E084A6632F6072DA9AD13"
hex_pri_key="3945208F7B2144B13F36E38AC6D39F95889393692860B51A42FB81EF4DF7C5B8"
config="envoy.yaml"
folder="envoy"

path="$(pwd)/${folder}"
configpath="${path}/${config}"
logpath="${path}/run.log"

run="docker run -e HEX_PUB_KEY=${hex_pub_key} -e HEX_PRI_KEY=${hex_pri_key} -p ${port1}:${port2} -v ${path}:/home/envoy/custom ccr.ccs.tencentyun.com/weixincloud/wxsmgw:v1 /usr/local/bin/envoy -c /home/envoy/custom/${config} -l debug"

red='\e[31m'
yellow='\e[33m'
green='\e[92m'
blue='\e[94m'
none='\e[0m'

msg() {
    case $1 in
    warn)
        local color=$yellow
        ;;
    err)
        local color=$red
        ;;
    ok)
        local color=$green
        ;;
    esac

    echo -e "[${color}$(date +'%T')] ${2}${none}"
}

show_config() {
    msg ok "----------config begin----------"
    msg ok "${port1}:${port2}"
    msg ok "${hex_pub_key}"
    msg ok "${hex_pri_key}"
    msg ok "${config}"
    msg ok "${folder}"
    msg ok "${path}"
    msg ok "${configpath}"
    msg ok "${run}"
    msg ok "-----------config end-----------"
}

# 检查docker安装
check_docker() {
    msg ok "check docker"
}

# 创建文件夹
create_dir() {
    msg ok "Create Dir ${path}"
    if [ ! -d ${path} ]; then
        mkdir ${path}
    else
        msg warn "Dir ${path} is exist"
    fi

    cd ${path}
    msg ok "Now path is ${path}"
    msg ok "Create Dir End"
}

# 创建envoy.yaml配置文件

create_config_file() {

msg ok "Create ${config} Begin"

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
else
    msg warn "file ${configpath} is exist"
fi

msg ok "Create Config Succ"

}

docker_run() {
    msg ok "Docker Run Begin log is ${logpath}"

    $run >> ${logpath} 2>&1

    msg ok "Docker Finish"
}

main() {
    show_config

    check_docker

    create_dir

    create_config_file

    docker_run
}

main $@
