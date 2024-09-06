#!/bin/bash

# Secure WireGuard server installer
# https://github.com/ThemeWayOut/wireguard-install

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

function isRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo "Bạn cần chạy tập lệnh này với tư cách là root"
		exit 1
	fi
}

function checkVirt() {
	if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo "OpenVZ không được hỗ trợ"
		exit 1
	fi

	if [ "$(systemd-detect-virt)" == "lxc" ]; then
		echo "LXC không được hỗ trợ (chưa)."
		echo "WireGuard có thể chạy trong một container LXC,"
		echo "nhưng mô-đun kernel phải được cài đặt trên máy chủ,"
		echo "container phải được chạy với một số tham số cụ thể"
		echo "và chỉ cần cài đặt các công cụ trong container."
		exit 1
	fi
}

function checkOS() {
	source /etc/os-release
	OS="${ID}"
	if [[ ${OS} == "debian" || ${OS} == "raspbian" ]]; then
		if [[ ${VERSION_ID} -lt 10 ]]; then
			echo "Phiên bản Debian của bạn (${VERSION_ID}) không được hỗ trợ. Vui lòng sử dụng Debian 10 Buster hoặc mới hơn."
			exit 1
		fi
		OS=debian # ghi đè nếu là raspbian
	elif [[ ${OS} == "ubuntu" ]]; then
		RELEASE_YEAR=$(echo "${VERSION_ID}" | cut -d'.' -f1)
		if [[ ${RELEASE_YEAR} -lt 18 ]]; then
			echo "Phiên bản Ubuntu của bạn (${VERSION_ID}) không được hỗ trợ. Vui lòng sử dụng Ubuntu 18.04 hoặc mới hơn."
			exit 1
		fi
	elif [[ ${OS} == "fedora" ]]; then
		if [[ ${VERSION_ID} -lt 32 ]]; then
			echo "Phiên bản Fedora của bạn (${VERSION_ID}) không được hỗ trợ. Vui lòng sử dụng Fedora 32 hoặc mới hơn."
			exit 1
		fi
	elif [[ ${OS} == 'centos' ]] || [[ ${OS} == 'almalinux' ]] || [[ ${OS} == 'rocky' ]]; then
		if [[ ${VERSION_ID} == 7* ]]; then
			echo "Phiên bản CentOS của bạn (${VERSION_ID}) không được hỗ trợ. Vui lòng sử dụng CentOS 8 hoặc mới hơn."
			exit 1
		fi
	elif [[ -e /etc/oracle-release ]]; then
		source /etc/os-release
		OS=oracle
	elif [[ -e /etc/arch-release ]]; then
		OS=arch
	else
		echo "Có vẻ như bạn không đang chạy trình cài đặt này trên hệ thống Debian, Ubuntu, Fedora, CentOS, AlmaLinux, Oracle hoặc Arch Linux."
		exit 1
	fi
}

function getHomeDirForClient() {
	local CLIENT_NAME=$1

	if [ -z "${CLIENT_NAME}" ]; then
		echo "Lỗi: getHomeDirForClient() yêu cầu một tên khách hàng làm tham số"
		exit 1
	fi

	# Thư mục chính của người dùng, nơi cấu hình của khách hàng sẽ được ghi
	if [ -e "/home/${CLIENT_NAME}" ]; then
		# nếu $1 là tên người dùng
		HOME_DIR="/home/${CLIENT_NAME}"
	elif [ "${SUDO_USER}" ]; then
		# nếu không, sử dụng SUDO_USER
		if [ "${SUDO_USER}" == "root" ]; then
			# Nếu chạy sudo với quyền root
			HOME_DIR="/root"
		else
			HOME_DIR="/home/${SUDO_USER}"
		fi
	else
		# nếu không có SUDO_USER, sử dụng /root
		HOME_DIR="/root"
	fi

	echo "$HOME_DIR"
}

function initialCheck() {
	isRoot
	checkVirt
	checkOS
}


function installQuestions() {
	echo "Chào mừng bạn đến với trình cài đặt WireGuard!"
	echo "Kho lưu trữ git có sẵn tại: https://github.com/ThemeWayOut/wireguard-install"
	echo ""
	echo "Tôi cần hỏi bạn một vài câu hỏi trước khi bắt đầu cài đặt."
	echo "Bạn có thể giữ các tùy chọn mặc định và chỉ cần nhấn enter nếu bạn đồng ý với chúng."
	echo ""

	# Phát hiện địa chỉ IPv4 hoặc IPv6 công cộng và tự động điền cho người dùng
	SERVER_PUB_IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | awk '{print $1}' | head -1)
	if [[ -z ${SERVER_PUB_IP} ]]; then
		# Phát hiện địa chỉ IPv6 công cộng
		SERVER_PUB_IP=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)
	fi
	read -rp "Địa chỉ công cộng IPv4 hoặc IPv6: " -e -i "${SERVER_PUB_IP}" SERVER_PUB_IP

	# Phát hiện giao diện công cộng và tự động điền cho người dùng
	SERVER_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
	until [[ ${SERVER_PUB_NIC} =~ ^[a-zA-Z0-9_]+$ ]]; do
		read -rp "Giao diện công cộng: " -e -i "${SERVER_NIC}" SERVER_PUB_NIC
	done

	until [[ ${SERVER_WG_NIC} =~ ^[a-zA-Z0-9_]+$ && ${#SERVER_WG_NIC} -lt 16 ]]; do
		read -rp "Tên giao diện WireGuard: " -e -i wg0 SERVER_WG_NIC
	done

	until [[ ${SERVER_WG_IPV4} =~ ^([0-9]{1,3}\.){3} ]]; do
		read -rp "Server WireGuard IPv4: " -e -i 192.168.1.1 SERVER_WG_IPV4
	done

	until [[ ${SERVER_WG_IPV6} =~ ^([a-f0-9]{1,4}:){3,4}: ]]; do
		read -rp "Server WireGuard IPv6: " -e -i fd42:42:42::1 SERVER_WG_IPV6
	done

	# Tạo số ngẫu nhiên trong khoảng cổng riêng
	RANDOM_PORT=$(shuf -i49152-65535 -n1)
	until [[ ${SERVER_PORT} =~ ^[0-9]+$ ]] && [ "${SERVER_PORT}" -ge 1 ] && [ "${SERVER_PORT}" -le 65535 ]; do
		read -rp "Cổng WireGuard của server [1-65535]: " -e -i "${RANDOM_PORT}" SERVER_PORT
	done

	# DNS Adguard mặc định
	until [[ ${CLIENT_DNS_1} =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
		read -rp "Trình phân giải DNS đầu tiên để sử dụng cho các khách hàng: " -e -i 8.8.8.8 CLIENT_DNS_1
	done
	until [[ ${CLIENT_DNS_2} =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
		read -rp "Trình phân giải DNS thứ hai để sử dụng cho các khách hàng (tùy chọn): " -e -i 8.4.4.8 CLIENT_DNS_2
		if [[ ${CLIENT_DNS_2} == "" ]]; then
			CLIENT_DNS_2="${CLIENT_DNS_1}"
		fi
	done

	until [[ ${ALLOWED_IPS} =~ ^.+$ ]]; do
		echo -e "\nWireGuard sử dụng một tham số gọi là AllowedIPs để xác định những gì được định tuyến qua VPN."
		read -rp "Danh sách IP được phép cho các khách hàng được tạo (để mặc định để định tuyến mọi thứ): " -e -i '116.122.159.19/32, 175.0.0.0/8, 183.0.0.0/8, 220.0.0.0/8, 118.214.75.79/32, 203.119.73.32/32, 34.117.59.81/32' ALLOWED_IPS
		if [[ ${ALLOWED_IPS} == "" ]]; then
			ALLOWED_IPS="116.122.159.19/32, 175.0.0.0/8, 183.0.0.0/8, 220.0.0.0/8, 118.214.75.79/32, 203.119.73.32/32, 34.117.59.81/32"
		fi
	done

	echo ""
	echo "Được rồi, đó là tất cả những gì tôi cần. Chúng ta đã sẵn sàng để thiết lập server WireGuard của bạn."
	echo "Bạn sẽ có thể tạo một khách hàng vào cuối quá trình cài đặt."
	read -n1 -r -p "Nhấn phím bất kỳ để tiếp tục..."
}

function installWireGuard() {
	# Chạy các câu hỏi thiết lập trước
	installQuestions

	# Cài đặt công cụ và mô-đun WireGuard
	if [[ ${OS} == 'ubuntu' ]] || [[ ${OS} == 'debian' && ${VERSION_ID} -gt 10 ]]; then
		apt-get update
		apt-get install -y wireguard iptables resolvconf qrencode
	elif [[ ${OS} == 'debian' ]]; then
		if ! grep -rqs "^deb .* buster-backports" /etc/apt/; then
			echo "deb http://deb.debian.org/debian buster-backports main" >/etc/apt/sources.list.d/backports.list
			apt-get update
		fi
		apt update
		apt-get install -y iptables resolvconf qrencode
		apt-get install -y -t buster-backports wireguard
	elif [[ ${OS} == 'fedora' ]]; then
		if [[ ${VERSION_ID} -lt 32 ]]; then
			dnf install -y dnf-plugins-core
			dnf copr enable -y jdoss/wireguard
			dnf install -y wireguard-dkms
		fi
		dnf install -y wireguard-tools iptables qrencode
	elif [[ ${OS} == 'centos' ]] || [[ ${OS} == 'almalinux' ]] || [[ ${OS} == 'rocky' ]]; then
		if [[ ${VERSION_ID} == 8* ]]; then
			yum install -y epel-release elrepo-release
			yum install -y kmod-wireguard
			yum install -y qrencode # không có trên phiên bản 9
		fi
		yum install -y wireguard-tools iptables
	elif [[ ${OS} == 'oracle' ]]; then
		dnf install -y oraclelinux-developer-release-el8
		dnf config-manager --disable -y ol8_developer
		dnf config-manager --enable -y ol8_developer_UEKR6
		dnf config-manager --save -y --setopt=ol8_developer_UEKR6.includepkgs='wireguard-tools*'
		dnf install -y wireguard-tools qrencode iptables
	elif [[ ${OS} == 'arch' ]]; then
		pacman -S --needed --noconfirm wireguard-tools qrencode
	fi

	# Đảm bảo thư mục tồn tại (điều này có vẻ không đúng trên fedora)
	mkdir /etc/wireguard >/dev/null 2>&1

	chmod 600 -R /etc/wireguard/

	SERVER_PRIV_KEY=$(wg genkey)
	SERVER_PUB_KEY=$(echo "${SERVER_PRIV_KEY}" | wg pubkey)

	# Lưu cài đặt WireGuard
	echo "SERVER_PUB_IP=${SERVER_PUB_IP}
SERVER_PUB_NIC=${SERVER_PUB_NIC}
SERVER_WG_NIC=${SERVER_WG_NIC}
SERVER_WG_IPV4=${SERVER_WG_IPV4}
SERVER_WG_IPV6=${SERVER_WG_IPV6}
SERVER_PORT=${SERVER_PORT}
SERVER_PRIV_KEY=${SERVER_PRIV_KEY}
SERVER_PUB_KEY=${SERVER_PUB_KEY}
CLIENT_DNS_1=${CLIENT_DNS_1}
CLIENT_DNS_2=${CLIENT_DNS_2}
ALLOWED_IPS=${ALLOWED_IPS}" >/etc/wireguard/params

	# Thêm giao diện server
	echo "[Interface]
Address = ${SERVER_WG_IPV4}/24,${SERVER_WG_IPV6}/64
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_PRIV_KEY}" >"/etc/wireguard/${SERVER_WG_NIC}.conf"

	if pgrep firewalld; then
		FIREWALLD_IPV4_ADDRESS=$(echo "${SERVER_WG_IPV4}" | cut -d"." -f1-3)".0"
		FIREWALLD_IPV6_ADDRESS=$(echo "${SERVER_WG_IPV6}" | sed 's/:[^:]*$/:0/')
		echo "PostUp = firewall-cmd --add-port ${SERVER_PORT}/udp && firewall-cmd --add-rich-rule='rule family=ipv4 source address=${FIREWALLD_IPV4_ADDRESS}/24 masquerade' && firewall-cmd --add-rich-rule='rule family=ipv6 source address=${FIREWALLD_IPV6_ADDRESS}/24 masquerade'
PostDown = firewall-cmd --remove-port ${SERVER_PORT}/udp && firewall-cmd --remove-rich-rule='rule family=ipv4 source address=${FIREWALLD_IPV4_ADDRESS}/24 masquerade' && firewall-cmd --remove-rich-rule='rule family=ipv6 source address=${FIREWALLD_IPV6_ADDRESS}/24 masquerade'" >>"/etc/wireguard/${SERVER_WG_NIC}.conf"
	else
		echo "PostUp = iptables -I INPUT -p udp --dport ${SERVER_PORT} -j ACCEPT
PostUp = iptables -I FORWARD -i ${SERVER_PUB_NIC} -o ${SERVER_WG_NIC} -j ACCEPT
PostUp = iptables -I FORWARD -i ${SERVER_WG_NIC} -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostUp = ip6tables -I FORWARD -i ${SERVER_WG_NIC} -j ACCEPT
PostUp = ip6tables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostDown = iptables -D INPUT -p udp --dport ${SERVER_PORT} -j ACCEPT
PostDown = iptables -D FORWARD -i ${SERVER_PUB_NIC} -o ${SERVER_WG_NIC} -j ACCEPT
PostDown = iptables -D FORWARD -i ${SERVER_WG_NIC} -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostDown = ip6tables -D FORWARD -i ${SERVER_WG_NIC} -j ACCEPT
PostDown = ip6tables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE" >>"/etc/wireguard/${SERVER_WG_NIC}.conf"
	fi

	# Kích hoạt định tuyến trên server
	echo "net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1" >/etc/sysctl.d/wg.conf

	sysctl --system

	systemctl start "wg-quick@${SERVER_WG_NIC}"
	systemctl enable "wg-quick@${SERVER_WG_NIC}"

	newClient
	echo -e "${GREEN}Nếu bạn muốn thêm nhiều khách hàng hơn, bạn chỉ cần chạy lại script này một lần nữa!${NC}"

	# Kiểm tra xem WireGuard có đang chạy không
	systemctl is-active --quiet "wg-quick@${SERVER_WG_NIC}"
	WG_RUNNING=$?

	# WireGuard có thể không hoạt động nếu chúng ta đã cập nhật kernel. Thông báo cho người dùng khởi động lại
	if [[ ${WG_RUNNING} -ne 0 ]]; then
		echo -e "\n${RED}CẢNH BÁO: WireGuard dường như không đang chạy.${NC}"
		echo -e "${ORANGE}Bạn có thể kiểm tra xem WireGuard có đang chạy không bằng: systemctl status wg-quick@${SERVER_WG_NIC}${NC}"
		echo -e "${ORANGE}Nếu bạn nhận được thông báo như \"Không tìm thấy thiết bị ${SERVER_WG_NIC}\", vui lòng khởi động lại!${NC}"
	else # WireGuard đang chạy
		echo -e "\n${GREEN}WireGuard đang chạy.${NC}"
		echo -e "${GREEN}Bạn có thể kiểm tra trạng thái của WireGuard bằng: systemctl status wg-quick@${SERVER_WG_NIC}\n\n${NC}"
		echo -e "${ORANGE}Nếu bạn không có kết nối internet từ khách hàng, hãy thử khởi động lại server.${NC}"
	fi
}

function newClient() {
	# Nếu SERVER_PUB_IP là IPv6, thêm dấu ngoặc nếu thiếu
	if [[ ${SERVER_PUB_IP} =~ .*:.* ]]; then
		if [[ ${SERVER_PUB_IP} != *"["* ]] || [[ ${SERVER_PUB_IP} != *"]"* ]]; then
			SERVER_PUB_IP="[${SERVER_PUB_IP}]"
		fi
	fi
	ENDPOINT="${SERVER_PUB_IP}:${SERVER_PORT}"

	echo ""
	echo "Cấu hình khách hàng"
	echo ""
	echo "Tên khách hàng phải bao gồm các ký tự chữ cái và số. Nó cũng có thể bao gồm dấu gạch dưới hoặc dấu gạch ngang và không được vượt quá 15 ký tự."

	until [[ ${CLIENT_NAME} =~ ^[a-zA-Z0-9_-]+$ && ${CLIENT_EXISTS} == '0' && ${#CLIENT_NAME} -lt 16 ]]; do
		read -rp "Tên khách hàng: " -e CLIENT_NAME
		CLIENT_EXISTS=$(grep -c -E "^### Khách hàng ${CLIENT_NAME}\$" "/etc/wireguard/${SERVER_WG_NIC}.conf")

		if [[ ${CLIENT_EXISTS} != 0 ]]; then
			echo ""
			echo -e "${ORANGE}Một khách hàng với tên đã chỉ định đã được tạo, vui lòng chọn tên khác.${NC}"
			echo ""
		fi
	done

	for DOT_IP in {2..254}; do
		DOT_EXISTS=$(grep -c "${SERVER_WG_IPV4::-1}${DOT_IP}" "/etc/wireguard/${SERVER_WG_NIC}.conf")
		if [[ ${DOT_EXISTS} == '0' ]]; then
			break
		fi
	done

	if [[ ${DOT_EXISTS} == '1' ]]; then
		echo ""
		echo "Subnet đã cấu hình chỉ hỗ trợ tối đa 253 khách hàng."
		exit 1
	fi

	BASE_IP=$(echo "$SERVER_WG_IPV4" | awk -F '.' '{ print $1"."$2"."$3 }')
	until [[ ${IPV4_EXISTS} == '0' ]]; do
		read -rp "IPv4 WireGuard của khách hàng: ${BASE_IP}." -e -i "${DOT_IP}" DOT_IP
		CLIENT_WG_IPV4="${BASE_IP}.${DOT_IP}"
		IPV4_EXISTS=$(grep -c "$CLIENT_WG_IPV4/32" "/etc/wireguard/${SERVER_WG_NIC}.conf")

		if [[ ${IPV4_EXISTS} != 0 ]]; then
			echo ""
			echo -e "${ORANGE}Một khách hàng với IPv4 đã chỉ định đã được tạo, vui lòng chọn IPv4 khác.${NC}"
			echo ""
		fi
	done

	BASE_IP=$(echo "$SERVER_WG_IPV6" | awk -F '::' '{ print $1 }')
	until [[ ${IPV6_EXISTS} == '0' ]]; do
		read -rp "IPv6 WireGuard của khách hàng: ${BASE_IP}::" -e -i "${DOT_IP}" DOT_IP
		CLIENT_WG_IPV6="${BASE_IP}::${DOT_IP}"
		IPV6_EXISTS=$(grep -c "${CLIENT_WG_IPV6}/128" "/etc/wireguard/${SERVER_WG_NIC}.conf")

		if [[ ${IPV6_EXISTS} != 0 ]]; then
			echo ""
			echo -e "${ORANGE}Một khách hàng với IPv6 đã chỉ định đã được tạo, vui lòng chọn IPv6 khác.${NC}"
			echo ""
		fi
	done

	# Tạo cặp khóa cho khách hàng
	CLIENT_PRIV_KEY=$(wg genkey)
	CLIENT_PUB_KEY=$(echo "${CLIENT_PRIV_KEY}" | wg pubkey)
	CLIENT_PRE_SHARED_KEY=$(wg genpsk)

	HOME_DIR=$(getHomeDirForClient "${CLIENT_NAME}")

	# Tạo tệp khách hàng và thêm server làm peer
	echo "[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128
DNS = ${CLIENT_DNS_1},${CLIENT_DNS_2}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
Endpoint = ${ENDPOINT}
AllowedIPs = ${ALLOWED_IPS}" >"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"

	# Thêm khách hàng làm peer vào server
	echo -e "\n### Khách hàng ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
AllowedIPs = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128" >>"/etc/wireguard/${SERVER_WG_NIC}.conf"

	wg syncconf "${SERVER_WG_NIC}" <(wg-quick strip "${SERVER_WG_NIC}")

	# Tạo mã QR nếu qrencode đã được cài đặt
	if command -v qrencode &>/dev/null; then
		echo -e "${GREEN}\nĐây là tệp cấu hình khách hàng của bạn dưới dạng mã QR:\n${NC}"
		qrencode -t ansiutf8 -l L <"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"
		echo ""
	fi

	echo -e "${GREEN}Tệp cấu hình khách hàng của bạn nằm trong ${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf${NC}"
}

function listClients() {
	NUMBER_OF_CLIENTS=$(grep -c -E "^### Client" "/etc/wireguard/${SERVER_WG_NIC}.conf")
	if [[ ${NUMBER_OF_CLIENTS} -eq 0 ]]; then
		echo ""
		echo "Bạn không có khách hàng nào tồn tại!"
		exit 1
	fi

	grep -E "^### Client" "/etc/wireguard/${SERVER_WG_NIC}.conf" | cut -d ' ' -f 3 | nl -s ') '
}

function revokeClient() {
	NUMBER_OF_CLIENTS=$(grep -c -E "^### Client" "/etc/wireguard/${SERVER_WG_NIC}.conf")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		echo ""
		echo "Bạn không có khách hàng nào tồn tại!"
		exit 1
	fi

	echo ""
	echo "Chọn khách hàng hiện có mà bạn muốn thu hồi"
	grep -E "^### Client" "/etc/wireguard/${SERVER_WG_NIC}.conf" | cut -d ' ' -f 3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Chọn một khách hàng [1]: " CLIENT_NUMBER
		else
			read -rp "Chọn một khách hàng [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done

	# Khớp số đã chọn với tên khách hàng
	CLIENT_NAME=$(grep -E "^### Client" "/etc/wireguard/${SERVER_WG_NIC}.conf" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)

	# Xóa khối [Peer] khớp với $CLIENT_NAME
	sed -i "/^### Client ${CLIENT_NAME}\$/,/^$/d" "/etc/wireguard/${SERVER_WG_NIC}.conf"

	# Xóa tệp khách hàng đã tạo
	HOME_DIR=$(getHomeDirForClient "${CLIENT_NAME}")
	rm -f "${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"

	# Khởi động lại wireguard để áp dụng thay đổi
	wg syncconf "${SERVER_WG_NIC}" <(wg-quick strip "${SERVER_WG_NIC}")
}

function uninstallWg() {
	echo ""
	echo -e "\n${RED}CẢNH BÁO: Điều này sẽ gỡ cài đặt WireGuard và xóa tất cả các tệp cấu hình!${NC}"
	echo -e "${ORANGE}Vui lòng sao lưu thư mục /etc/wireguard nếu bạn muốn giữ các tệp cấu hình của mình.\n${NC}"
	read -rp "Bạn có thực sự muốn gỡ cài đặt WireGuard không? [y/n]: " -e REMOVE
	REMOVE=${REMOVE:-n}
	if [[ $REMOVE == 'y' ]]; then
		checkOS

		systemctl stop "wg-quick@${SERVER_WG_NIC}"
		systemctl disable "wg-quick@${SERVER_WG_NIC}"

		if [[ ${OS} == 'ubuntu' ]]; then
			apt-get remove -y wireguard wireguard-tools qrencode
		elif [[ ${OS} == 'debian' ]]; then
			apt-get remove -y wireguard wireguard-tools qrencode
		elif [[ ${OS} == 'fedora' ]]; then
			dnf remove -y --noautoremove wireguard-tools qrencode
			if [[ ${VERSION_ID} -lt 32 ]]; then
				dnf remove -y --noautoremove wireguard-dkms
				dnf copr disable -y jdoss/wireguard
			fi
		elif [[ ${OS} == 'centos' ]] || [[ ${OS} == 'almalinux' ]] || [[ ${OS} == 'rocky' ]]; then
			yum remove -y --noautoremove wireguard-tools
			if [[ ${VERSION_ID} == 8* ]]; then
				yum remove --noautoremove kmod-wireguard qrencode
			fi
		elif [[ ${OS} == 'oracle' ]]; then
			yum remove --noautoremove wireguard-tools qrencode
		elif [[ ${OS} == 'arch' ]]; then
			pacman -Rs --noconfirm wireguard-tools qrencode
		fi

		rm -rf /etc/wireguard
		rm -f /etc/sysctl.d/wg.conf

		# Tải lại sysctl
		sysctl --system

		# Kiểm tra xem WireGuard có đang chạy không
		systemctl is-active --quiet "wg-quick@${SERVER_WG_NIC}"
		WG_RUNNING=$?

		if [[ ${WG_RUNNING} -eq 0 ]]; then
			echo "WireGuard đã không gỡ cài đặt thành công."
			exit 1
		else
			echo "WireGuard đã gỡ cài đặt thành công."
			exit 0
		fi
	else
		echo ""
		echo "Gỡ cài đặt bị hủy!"
	fi
}

function manageMenu() {
	echo "Chào mừng bạn đến với WireGuard-install!"
	echo "Kho lưu trữ git có sẵn tại: https://github.com/ThemeWayOut/Wireguard-Install"
	echo ""
	echo "Có vẻ như WireGuard đã được cài đặt."
	echo ""
	echo "Bạn muốn làm gì?"
	echo "   1) Thêm một người dùng mới"
	echo "   2) Liệt kê tất cả người dùng"
	echo "   3) Thu hồi người dùng hiện có"
	echo "   4) Gỡ cài đặt WireGuard"
	echo "   5) Thoát"
	until [[ ${MENU_OPTION} =~ ^[1-5]$ ]]; do
		read -rp "Chọn một tùy chọn [1-5]: " MENU_OPTION
	done
	case "${MENU_OPTION}" in
	1)
		newClient
		;;
	2)
		listClients
		;;
	3)
		revokeClient
		;;
	4)
		uninstallWg
		;;
	5)
		exit 0
		;;
	esac
}

# Kiểm tra quyền root, ảo hóa, hệ điều hành...
initialCheck

# Kiểm tra xem WireGuard đã được cài đặt hay chưa và tải tham số
if [[ -e /etc/wireguard/params ]]; then
	source /etc/wireguard/params
	manageMenu
else
	installWireGuard
fi
