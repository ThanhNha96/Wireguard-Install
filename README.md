# WireGuard installer

![Lint](https://github.com/angristan/wireguard-install/workflows/Lint/badge.svg)
[![Say Thanks!](https://img.shields.io/badge/Say%20Thanks-!-1EAEDB.svg)](https://saythanks.io/to/angristan)

** Dự án này là một script bash nhằm thiết lập một VPN [WireGuard](https://www.wireguard.com/) trên máy chủ Linux, một cách dễ dàng nhất có thể!

** WireGuard là một VPN điểm-đến-điểm có thể được sử dụng theo nhiều cách khác nhau. Ở đây, chúng tôi hiểu VPN là: khách hàng sẽ chuyển tiếp tất cả lưu lượng của mình qua một đường hầm mã hóa đến máy chủ. Máy chủ sẽ áp dụng NAT cho lưu lượng của khách hàng để nó có vẻ như khách hàng đang duyệt web với IP của máy chủ.

Script hỗ trợ cả IPv4 và IPv6. Vui lòng kiểm tra các [vấn đề](https://github.com/angristan/wireguard-install/issues) để biết thông tin phát triển đang diễn ra, lỗi và các tính năng dự kiến! Bạn cũng có thể muốn kiểm tra các [thảo luận](https://github.com/angristan/wireguard-install/discussions) để được giúp đỡ.

WireGuard không phù hợp với môi trường của bạn? Hãy kiểm tra [openvpn-install](https://github.com/angristan/openvpn-install).

## Requirements

Supported distributions:

- AlmaLinux >= 8
- Arch Linux
- CentOS Stream >= 8
- Debian >= 10
- Fedora >= 32
- Oracle Linux
- Rocky Linux >= 8
- Ubuntu >= 18.04

Cách sử dụng

Tải xuống và thực thi script. Trả lời các câu hỏi mà script đưa ra và nó sẽ tự lo phần còn lại.

```bash
curl -O https://raw.githubusercontent.com/ThemeWayOut/Wireguard-Install/master/wireguard-install.sh
chmod +x wireguard-install.sh
./wireguard-install.sh
```
```bash
AllowedIPs = 116.122.159.19/32, 175.0.0.0/8, 183.0.0.0/8, 220.0.0.0/8, 118.214.75.79/32, 203.119.73.32/32, 34.117.59.81/32
```

Nó sẽ cài đặt WireGuard (module kernel và công cụ) trên máy chủ, cấu hình nó, tạo một dịch vụ systemd và một tệp cấu hình cho khách hàng.

Chạy lại script để thêm hoặc xóa khách hàng!

Nhà cung cấp

Tôi khuyên bạn nên sử dụng những nhà cung cấp đám mây giá rẻ này cho máy chủ VPN của bạn:

- [Vultr](https://www.vultr.com/?ref=8948982-8H): Địa điểm toàn cầu, hỗ trợ IPv6, bắt đầu từ 5 USD/tháng
- [Hetzner](https://hetzner.cloud/?ref=ywtlvZsjgeDq): Đức, Phần Lan và Mỹ. Hỗ trợ IPv6, 20 TB lưu lượng, bắt đầu từ 4,5€/tháng.
- [Digital Ocean](https://m.do.co/c/ed0ba143fe53): Địa điểm toàn cầu, hỗ trợ IPv6, bắt đầu từ 4 USD/tháng.
- [KDatacenter](https://www.kdatacenter.com/): Địa chỉ Hàn Quốc, hỗ trợ IPv6 bắt đầu từ 19 USD/tháng.
