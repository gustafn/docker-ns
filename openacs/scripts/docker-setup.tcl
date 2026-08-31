#!/usr/local/ns/bin/tclsh
# SPDX-License-Identifier: MPL-2.0

# exec curl -s --unix-socket /var/run/docker.sock -o /scripts/docker.config http://localhost/containers/$::env(HOSTNAME)/json

package require json

set F [open /scripts/docker.config]; set json [read $F]; close $F
try {
    set jsonDict [json::json2dict $json]
} on error {errorMsg} {
    puts stderr "error while parsing json file /scripts/docker.config; $errorMsg"
    puts stderr "---"
    puts stderr $json
    puts stderr "---"
    set jsonDict ""
}

if {[dict exists $jsonDict NetworkSettings]} {
    #
    # The docker.config file contains externally published mappings for
    # the plain HTTP endpoint (internally 8080/tcp), the HTTPS endpoint
    # (internally 8443/tcp), and HTTP/3/QUIC (internally 8443/udp).
    #
    #    ...
    #    "NetworkSettings": {
    #        "Ports": {
    #           "8080/tcp": [
    #             {
    #                "HostIp": "192.168.1.192",
    #                "HostPort": "50170"
    #             }
    #           ],
    #           "8443/tcp": [
    #             {
    #                "HostIp": "192.168.1.192",
    #                "HostPort": "50171"
    #             }
    #           ],
    #        }
    #     },
    #     ...
    #
    set supportedMappings {
        8080/tcp http
        8443/tcp https
        8443/udp h3
    }
    foreach {label networkMappings} [dict get $jsonDict NetworkSettings Ports] {

        if {![dict exists $supportedMappings $label]} {
            puts stdout "docker-setup.tcl: ignoring unsupported network label '$label'"
            continue
        }
        set proto [dict get $supportedMappings $label]

        puts stdout "docker-setup.tcl: processing Docker network label '$label' as '$proto'"

        foreach mapping $networkMappings {
            try {
                set host [dict get $mapping HostIp]
                set port [dict get $mapping HostPort]
                lappend containerMapping $label [list proto $proto host $host port $port]
            } on error {errorMsg} {
                puts stdout "docker-setup.tcl: error while processing network mapping: $errorMsg\n<<<$mapping>>>"
            }
        }
    }
}

set F [open /scripts/docker-dict.tcl w]

puts $F [list namespace eval ::docker {}]
puts $F [list set ::docker::jsonDict $jsonDict]
if {[info exists containerMapping]} {
    puts $F [list set ::docker::containerMapping $containerMapping]
}

puts $F {
    #
    # Docker support: determine externally visible host:port mappings.
    #
    # When NaviServer runs inside a container, ports are often published on the
    # Docker host with a (potentially different) external address and port.
    # The returned mappings can be used to whitelist additional Host header
    # values (e.g., "host:port") for a given server configuration.
    #
    # Legacy implementation for setups where the docker environment does not
    # provide this helper.
    #
    proc ::docker::map_external_address_to_server {server port} {
        set label "$port/tcp"
        set s [ns_set create]
        if {$port eq ""
            || ![info exists ::docker::containerMapping]
            || ![dict exists $::docker::containerMapping $label]
        } {
            return $s
        }
        foreach {k info} $::docker::containerMapping {
            if {$k ne $label} continue
            set host    [dict get $info host]
            set pubport [dict get $info port]
            if {[ns_ip valid $host] && [ns_ip inany $host]} continue
            ns_set put $s $server ${host}:${pubport}
        }
        return $s
    }
}

puts $F {
    proc ::docker::external_port {port {transport tcp}} {
        set label "$port/$transport"

        if {![info exists ::docker::containerMapping]
            || ![dict exists $::docker::containerMapping $label]
        } {
            return ""
        }

        set ports {}
        foreach {key info} $::docker::containerMapping {
            if {$key ne $label} {
                continue
            }
            lappend ports [dict get $info port]
        }

        set ports [lsort -unique $ports]
        return [lindex $ports 0]
    }
}

close $F
puts stdout "docker-setup.tcl: script /scripts/docker-dict.tcl generated"
