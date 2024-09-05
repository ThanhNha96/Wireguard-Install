# WireGuard installer

![Lint](https://github.com/angristan/wireguard-install/workflows/Lint/badge.svg)
[![Say Thanks!](https://img.shields.io/badge/Say%20Thanks-!-1EAEDB.svg)](https://saythanks.io/to/angristan)

** Dự án này là một script bash nhằm thiết lập một VPN [WireGuard](https://www.wireguard.com/) trên máy chủ Linux, một cách dễ dàng nhất có thể!

** WireGuard là một VPN điểm-đến-điểm có thể được sử dụng theo nhiều cách khác nhau. Ở đây, chúng tôi hiểu VPN là: khách hàng sẽ chuyển tiếp tất cả lưu lượng của mình qua một đường hầm mã hóa đến máy chủ. Máy chủ sẽ áp dụng NAT cho lưu lượng của khách hàng để nó có vẻ như khách hàng đang duyệt web với IP của máy chủ.

The script supports both IPv4 and IPv6. Please check the [issues](https://github.com/angristan/wireguard-install/issues) for ongoing development, bugs and planned features! You might also want to check the [discussions](https://github.com/angristan/wireguard-install/discussions) for help.

WireGuard does not fit your environment? Check out [openvpn-install](https://github.com/angristan/openvpn-install).

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

## Usage

Download and execute the script. Answer the questions asked by the script and it will take care of the rest.

```bash
curl -O https://raw.githubusercontent.com/ThemeWayOut/Wireguard-Install/master/wireguard-install.sh
chmod +x wireguard-install.sh
./wireguard-install.sh
```
```bash
AllowedIPs = 116.122.159.19/32, 175.0.0.0/8, 183.0.0.0/8, 220.0.0.0/8, 118.214.75.79/32, 203.119.73.32/32, 34.117.59.81/32
```

It will install WireGuard (kernel module and tools) on the server, configure it, create a systemd service and a client configuration file.

Run the script again to add or remove clients!

## Providers

I recommend these cheap cloud providers for your VPN server:

- [Vultr](https://www.vultr.com/?ref=8948982-8H): Worldwide locations, IPv6 support, starting at \$5/month
- [Hetzner](https://hetzner.cloud/?ref=ywtlvZsjgeDq): Germany, Finland and USA. IPv6, 20 TB of traffic, starting at 4.5€/month
- [Digital Ocean](https://m.do.co/c/ed0ba143fe53): Worldwide locations, IPv6 support, starting at \$4/month

## Contributing

## Discuss changes

Please open an issue before submitting a PR if you want to discuss a change, especially if it's a big one.

### Code formatting

We use [shellcheck](https://github.com/koalaman/shellcheck) and [shfmt](https://github.com/mvdan/sh) to enforce bash styling guidelines and good practices. They are executed for each commit / PR with GitHub Actions, so you can check the configuration [here](https://github.com/angristan/wireguard-install/blob/master/.github/workflows/lint.yml).

## Say thanks

You can [say thanks](https://saythanks.io/to/angristan) if you want!

## Credits & Licence

This project is under the [MIT Licence](https://raw.githubusercontent.com/angristan/wireguard-install/master/LICENSE)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=angristan/wireguard-install&type=Date)](https://star-history.com/#angristan/wireguard-install&Date)
