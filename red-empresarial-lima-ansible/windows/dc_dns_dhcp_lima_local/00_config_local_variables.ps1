$JhalexConfig = @{
    VmVisibleName  = "DC-DNS-DHCP-LIMA"
    Hostname       = "LIM-DC01"
    DomainName     = "jhalex.local"
    NetbiosName    = "JHALEX"

    SiteLima       = "SITE-LIM-ESXI"
    SiteHuancayo   = "SITE-HYO-FISICA"
    SiteArequipa   = "SITE-AQP-AWS"

    Location       = "Lima"
    Platform       = "ESXi virtualizado"

    IPAddress      = "192.168.40.10"
    PrefixLength   = 27
    SubnetMask     = "255.255.255.224"
    Gateway        = "192.168.40.1"

    DnsInitial     = @("192.168.40.10","8.8.8.8")
    DnsFinal       = @("192.168.40.10")
    DnsForwarders  = @("8.8.8.8","1.1.1.1")

    LimaSubnets    = @(
        "192.168.10.0/25",
        "192.168.20.0/24",
        "192.168.30.0/24",
        "192.168.40.0/27",
        "192.168.50.16/28",
        "192.168.60.0/25",
        "192.168.70.0/27",
        "192.168.80.0/27",
        "192.168.99.0/27"
    )
}
