# OTUS Linux Professional — Сценарии iptables

Стенд разворачивается одной командой: **Vagrant + Ansible** (VirtualBox, `bento/ubuntu-22.04`).

## Содержимое репозитория

| Путь | Назначение |
|---|---|
| [Vagrantfile](Vagrantfile) | 4 ВМ и сети стенда, запуск Ansible |
| [ansible.cfg](ansible.cfg) | настройки Ansible (inventory от Vagrant) |
| [ansible/playbook.yml](ansible/playbook.yml) | основной playbook |
| [ansible/group_vars/](ansible/group_vars/) | переменная `star` (задание со *) |
| [ansible/host_vars/](ansible/host_vars/) | адреса и маршруты каждой ВМ |
| [ansible/roles/common/](ansible/roles/common/) | пакеты, ip_forward, netplan, default route |
| [ansible/roles/inet_router/](ansible/roles/inet_router/) | NAT в интернет + port knocking |
| [ansible/roles/central_router/](ansible/roles/central_router/) | knock-скрипт knock.sh |
| [ansible/roles/central_server/](ansible/roles/central_server/) | nginx |
| [ansible/roles/inet_router2/](ansible/roles/inet_router2/) | проброс 8080 -> 192.168.0.2:80 |
| [screenshots/](screenshots/) | скриншоты выполнения |

## Схема

~~
               Интернет (VirtualBox NAT, eth0)
                    |
            +---------------+
            |  inetRouter   |  eth1 192.168.255.1/30
            |               |  MASQUERADE, port knocking 8881 -> 7777 -> 9991 -> ssh
            +---------------+
                    |
                    |  eth1 192.168.255.2/30
            +---------------+  eth3 192.168.255.5/30    eth1 192.168.255.6/30  +---------------+
            | centralRouter |------------------------------------------------| inetRouter2   |
            |   knock.sh    |                                                | DNAT :8080    |
            +---------------+                                                +---------------+
                    |  eth2 192.168.0.1/28                       eth2 192.168.56.10/24 |
                    |                                                                | host-only
            +---------------+                                                  хост 192.168.56.1
            | centralServer |  eth1 192.168.0.2/28, nginx :80
            +---------------+
~~

Default в интернет у centralRouter и centralServer — только через **inetRouter**
(eth0 этих ВМ без шлюза, сетевая конфигурация cloud-init отключена).

## Запуск

~~bash
vagrant up                    # основное задание (проброс с маскарадингом)
STAR=true vagrant up          # задание со * (проброс без маскарадинга)
STAR=true vagrant provision   # переключить уже поднятый стенд в режим со *
~~

## 1. Port knocking: centralRouter -> ssh inetRouter

Правила: [ansible/roles/inet_router/templates/rules.v4.j2](ansible/roles/inet_router/templates/rules.v4.j2).
Модуль `-m recent`: стук 8881 -> 7777 -> 9991 открывает tcp/22 на 30 секунд только для постучавшего IP.

~~bash
vagrant ssh centralRouter
sudo -i
ssh -o ConnectTimeout=5 vagrant@192.168.255.1                       # без стука — timeout
knock.sh 192.168.255.1 8881 7777 9991 && ssh vagrant@192.168.255.1  # пароль vagrant
~~

## 2. nginx на centralServer и проброс inetRouter2:8080 -> centralServer:80

Правила: [ansible/roles/inet_router2/templates/rules.v4.j2](ansible/roles/inet_router2/templates/rules.v4.j2).

~~bash
curl --noproxy '*' http://192.168.56.10:8080/
vagrant ssh centralServer -c "sudo tail -n 1 /var/log/nginx/access.log"
~~

В основном варианте (MASQUERADE) nginx видит адрес `192.168.255.6` (inetRouter2).

## 3. Default в интернет через inetRouter

~~bash
vagrant ssh centralServer -c "ip r | grep default; sudo traceroute -n -I -m 3 8.8.8.8"
# 192.168.0.1 -> 192.168.255.1 -> ...
~~

## 4*. Проход на 80-й порт без маскарадинга

`STAR=true`: на inetRouter2 остаётся только DNAT (без MASQUERADE), а на centralRouter
добавляется маршрут `192.168.56.0/24 via 192.168.255.6`. Ответ centralServer возвращается
через inetRouter2, который по conntrack делает обратную трансляцию. Default в интернет не меняется.

В логе nginx — настоящий адрес клиента `192.168.56.1`.

## Материалы

- [Kernel: TPROXY](https://www.kernel.org/doc/Documentation/networking/tproxy.txt)
- [ipset: features](https://ipset.netfilter.org/features.html)
- [Iptables Tutorial (Oskar Andreasson)](https://www.frozentux.net/iptables-tutorial/iptables-tutorial.html)
- [Habr: Port knocking](https://habr.com/ru/articles/136871/)
- [Блокировать ли ICMP-трафик](https://14bytes.ru/blokirovat-li-icmp-trafik-bezopasno-li/)
