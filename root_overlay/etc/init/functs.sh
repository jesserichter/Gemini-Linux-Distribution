#!/bin/bash

GOOD=$'\e[32;01m'
WARN=$'\e[33;01m'
BAD=$'\e[31;01m'
HILITE=$'\e[36;01m'
BRACKET=$'\e[34;01m'
NORMAL=$'\e[0m'
ENDCOL=$'\e[A\e['$(( COLS - 8 ))'C'

ebegin() {
	echo -e " ${GOOD}*${NORMAL} $*"
}

eend() {
	local retval="${1:-0}" efunc="${2:-eerror}" msg
	shift 2

	if [[ ${retval} == "0" ]] ; then
		msg="${BRACKET}[ ${GOOD}ok${BRACKET} ]${NORMAL}"
	else
		msg="${BRACKET}[ ${BAD}!!${BRACKET} ]${NORMAL} $*"
	fi
	echo -e "${ENDCOL} ${msg}"
}

rc_set_network_parms() {
	if [ -n "${SRV_PROXY}" ]; then
		echo -e "export http_proxy=\"${SRV_PROXY}\"\nexport https_proxy=\"${SRV_PROXY}\"\nexport ftp_proxy=\"${SRV_PROXY}\"" > /etc/init/env/50proxy
	else
		echo -e "unset http_proxy\nunset https_proxy\nunset ftp_proxy" > /etc/init/env/50proxy
	fi

	if [ -n "${SRV_DNS}" ]; then
		echo "nameserver ${SRV_DNS}" > /etc/resolv.conf
		[ -n "${SRV_DNS_SEARCH}" ] && echo "search ${SRV_DNS_SEARCH}" >> /etc/resolv.conf
	fi

	if [ -n "${SRV_DNS_DNSCACHE}" ]; then
		echo "1" > /service/dnscache/env/FORWARDONLY
		echo "${SRV_DNS_DNSCACHE}" > /service/dnscache/root/servers/@
		killall dnscache &>/dev/null
	else
		rm -f /service/dnscache/env/FORWARDONLY
		cp -f /service/dnscache/root/servers/@.roots /service/dnscache/root/servers/@
	fi

	if [ -n "${SRV_NTP}" ]; then
		sed -i "s|^server.*|server ${SRV_NTP}|" /etc/ntp.conf
	fi
}

rc_detect_wlans() {
	friendly_ap=$(iwlist eth1 scan | egrep '(avira|nyleve)' | sed 's|.*"\(.*\)".*|\1|' | head -n1)
	if [ -n "${friendly_ap}" ]; then
		echo "'${friendly_ap}' AP found"
		sh /etc/init/wireless_${friendly_ap}
	fi
}

# not used
rc_detect_lans() {

	location=$(ip addr show eth0 | grep 'inet '| awk '{ print $2 }')

	ebegin "   eth0 ${location}"

	case ${location} in
		"10.2.1.1/16" )
			SRV_NTP='81.12.221.100'
			SRV_DNS='10.2.0.3'
			SRV_PROXY='http://proxy.bu.avira.com:3128'
			;;
		"10.212.0.20/24" )
			SRV_DNS='10.212.0.1'
			SRV_NTP='10.212.0.1'
			;;
		"*" )
			:
			;;
	esac

}

