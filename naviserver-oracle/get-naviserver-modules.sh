#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
#
# We require bash to be able to execute the "source" command.
#

build=0
keep=1

while getopts m:ik flag; do
    case "${flag}" in
        m) modules=${OPTARG} ;;
        i) build=1 ;;
        k) keep=1 ;;
        *) echo "Got unknown flag <${flag}>"
    esac
done

#
# Get setup information of the underlying NaviServer installation
#
. /usr/local/ns/lib/nsConfig.sh

echo mkdir -p ${build_dir}

mkdir -p ${build_dir}

# cover just the base case, where version_modules == version_ns
version_modules=${version_ns}

echo "trying to obtain modules '${modules}' in version ${version_modules}."

if [ "${version_modules}" != "GIT" ] ; then
    modules_src_dir=modules
    modules_tar="naviserver-${version_modules}-modules.tar.gz"
    modules_url=https://downloads.sourceforge.net/sourceforge/naviserver/${modules_tar}
else
    modules_src_dir="modules-git"
    modules_tar=
    modules_url=
fi
: "${modules_src_dir:?}"


cd ${build_dir} || exit 1
if [ "${modules_tar}" != "" ] ; then
    curl -L -s -k -o ${modules_tar} ${modules_url}
    tar zxf ${modules_tar}

else
    mkdir modules && cd modules || exit 1
    for module in ${modules}
    do
        git clone "https://github.com/naviserver-project/${module}"
    done
fi

if [ "${build}" = "1" ] ; then
    for module in ${modules}
    do
        echo "Building ${module} ..."
        cd "${build_dir}/modules/${module}" || exit 1
        # shellcheck disable=SC2086
        case "${module}" in
            nsdbpg)
                ${make} PGLIB=${pg_lib} PGINCLUDE=${pg_incl} NAVISERVER=${ns_install_dir} ${extra_debug_flags:-} install ;;
            nsoracle)
                ORACLE_HOME=/usr/lib/instantclient ${make} NAVISERVER=${ns_install_dir} ${extra_debug_flags:-} install ;;
            *)
                ${make} NAVISERVER=${ns_install_dir} ${extra_debug_flags:-} install ;;
        esac
    done
fi

if [ "${keep}" = "0" ] ; then
    rm -rf $build_dir
fi

#echo "ls in ${build_dir}"
#ls ${build_dir}
#echo "ls in ${build_dir}/modules"
#ls ${build_dir}/modules
