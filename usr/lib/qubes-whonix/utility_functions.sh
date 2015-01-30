#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

export QT_X11_NO_MITSHM=1
export XDG_CURRENT_DESKTOP=gnome

# /etc/uwt.d/50_uwt_default relies on this in order to allow connection 
# to proxy for template
PROXY_SERVER="http://10.137.255.254:8082/"
PROXY_META='<meta name=\"application-name\" content=\"tor proxy\"\/>'

if [ ! -d "/var/run/qubes" ]; then
    QUBES_WHONIX="unknown"
    exit 0

elif [ -f "/var/run/qubes-service/updates-proxy-setup" ]; then
    QUBES_WHONIX="template"
    if [ ! -e '/var/run/qubes-service/qubes-whonix-secure-proxy' ]; then
        curl.anondist-orig --connect-timeout 3 "${PROXY_SERVER}" | grep -q "${PROXY_META}" && {
            sudo touch '/var/run/qubes-service/qubes-whonix-secure-proxy'
        }
    fi

elif [ -f "/usr/share/anon-gw-base-files/gateway" ]; then
    QUBES_WHONIX="gateway"

elif [ -f "/usr/share/anon-ws-base-files/workstation" ]; then
    QUBES_WHONIX="workstation"

else
    QUBES_WHONIX="unknown"
fi

immutableFilesEnable() {
    files="${1}"
    suffix="${2}"

    for file in "${files[@]}"; do
        if [ -f "${file}" ] && ! [ -L "${file}" ]; then 
            sudo chattr +i "${file}${suffix}"
        fi
    done
}

immutableFilesDisable() {
    files="${1}"
    suffix="${2}"

    for file in "${files[@]}"; do
        if [ -f "${file}" ] && ! [ -L "${file}" ]; then 
            sudo chattr -i "${file}${suffix}"
        fi
    done
}

copyAnondist() {
    file="${1}"
    suffix="${2-.anondist}"

    # Remove any softlinks first
    if [ -L "${file}" ]; then 
        sudo rm -f "${file}"
    fi

    if [ -f "${file}" ] && [ -n "$(diff ${file} ${file}${suffix})" ]; then 
        sudo chattr -i "${file}"
        sudo rm -f "${file}"
        sudo cp -p "${file}${suffix}" "${file}"
        sudo chattr +i "${file}"
    elif ! [ -f "${file}" ]; then 
        sudo cp -p "${file}${suffix}" "${file}"
        sudo chattr +i "${file}"
    fi
}

# Will only enable / disable if service is not already in that state
enable_sysv() {
    servicename=${1}
    disable=${2-0}

    # Check to see if the service is already enabled and if not, enable it
    string="/etc/rc$(runlevel | awk '{ print $2 }').d/S[0-9][0-9]${servicename}"

    if [ $(find $string 2>/dev/null | wc -l) -eq ${disable} ] ; then
        case ${disable} in
            0)
                echo "${1} is currently disabled; enabling it"
                sudo systemctl --quiet enable ${servicename}
                ;;
            1)
                echo "${1} is currently enabled; disabling it"
                sudo service ${servicename} stop
                sudo systemctl --quiet disable ${servicename}
                ;;
        esac
    fi
}

disable_sysv() {
    enable_sysv ${1} 1
}
