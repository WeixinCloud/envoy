#!/bin/bash

# 变量

localport="9901"
bindport="9902"
envoyport="9902"
hex_pub_key="0409F9DF311E5421A150DD7D161E4BC5C672179FAD1833FC076BB08FF356F35020CCEA490CE26775A52DC6EA718CC1AA600AED05FBF35E084A6632F6072DA9AD13"
hex_pri_key="3945208F7B2144B13F36E38AC6D39F95889393692860B51A42FB81EF4DF7C5B8"
config="envoy.yaml"
folder="envoy"

path="$(pwd)/${folder}"
configpath="${path}/${config}"
logpath="${path}/run.log"

run="docker run -d -e HEX_PUB_KEY=${hex_pub_key} -e HEX_PRI_KEY=${hex_pri_key} -p ${bindport}:${envoyport} -v ${path}:/home/envoy/custom ccr.ccs.tencentyun.com/weixincloud/wxsmgw:v1 /usr/local/bin/envoy -c /home/envoy/custom/${config} -l debug"

red='\e[31m'
yellow='\e[33m'
green='\e[92m'
blue='\e[94m'
none='\e[0m'

msg() {
    if [ $# -eq 2 ]; then
        case $1 in
        warn)
            local color=$yellow
            ;;
        err)
            local color=$red
            ;;
        ok)
            local color=$blue
            ;;
        esac

        echo -e "${color}[$(date +'%T')] ${2}${none}"
    else
        local color=$green
        echo -e "${color}[$(date +'%T')] ${1}${none}"
    fi
}

show_help() {
    msg err "Usage: $0 [-r | -i | -h]"
    msg err "  -r, --run"
    msg err "  -i, --install"
    msg err "  -h, --help"
    msg err "  -d, --install_docker"

    exit 0
}

pass_cmd() {
    if [ $# -eq 0 ]; then
        show_help
    else
        case $1 in
        -r | --run)
            docker_run
            ;;
        -i | --install)
            install
            ;;
        -h | --help)
            show_help
            ;;
        -d | --install_docker)
            install_docker
            ;;
        *)
            msg err "Error args"
            show_help
            ;;
        esac
    fi
}

show_config() {
    msg "----------config begin----------"
    msg "${localport}:${bindport}:${envoyport}"
    msg "${hex_pub_key}"
    msg "${hex_pri_key}"
    msg "${config}"
    msg "${folder}"
    msg "${path}"
    msg "${configpath}"
    msg "${run}"
    msg "-----------config end-----------"
}


install_docker() {
    msg "install docker begin"
    curl -fsSL get.docker.com -o get-docker.sh
    sudo sh get-docker.sh --mirror Aliyun
    msg "install docker end"
}

# 检查docker安装
check_docker() {
    msg "check docker"
    if ! [ -x "$(command -v docker)" ];then
        msg err "ERROR: docker is not installed."
        exit 1
    fi
}

# 创建文件夹
create_dir() {
    msg "Create Dir ${path}"
    if [ ! -d ${path} ]; then
        mkdir ${path}
    else
        msg warn "Dir ${path} is exist"
    fi

    cd ${path}
    msg "Now path is ${path}"
    msg "Create Dir End"
}

# 创建envoy.yaml配置文件

create_config_file() {

msg "Create ${config} Begin"

if [ ! -f ${configpath} ]; then
cat > ${configpath} <<- EOF
admin:
  access_log_path: /dev/stdout
  address:
    socket_address: { address: 127.0.0.1, port_value: ${localport} }

static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        protocol: TCP
        address: 0.0.0.0
        port_value: ${bindport}
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
                inline_string: com.miniprogram.tencent
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

msg "Create Config Succ"

}

docker_run() {
    msg "Docker Run Begin"

    $run >> ${logpath} 2>&1

    msg "Docker is Running log is ${logpath}"

    docker container ls
}

install() {
    show_config

    check_docker

    create_dir

    create_config_file

    docker_run
}

main() {
    pass_cmd $@
}

main $@
