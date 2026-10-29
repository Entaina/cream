require "ipaddr"
require "resolv"
require "net/http"

# Outbound HTTP to user-configured URLs (webhooks, Slack). Only public hosts are
# allowed, and the connection is pinned to the address that was validated so a
# second DNS lookup cannot point it at an internal service (DNS rebinding).
class SafeOutboundHttp
  BLOCKED_NETWORKS = [
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("100.64.0.0/10"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.0.0.0/24"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("198.18.0.0/15"),
    IPAddr.new("224.0.0.0/4"),
    IPAddr.new("240.0.0.0/4"),
    IPAddr.new("::/96"),
    IPAddr.new("::1/128"),
    IPAddr.new("64:ff9b::/96"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10"),
    IPAddr.new("ff00::/8")
  ].freeze

  DEFAULT_OPEN_TIMEOUT = 5
  DEFAULT_READ_TIMEOUT = 10

  def self.start(uri)
    parsed, address = resolve_public!(uri)
    http = Net::HTTP.new(parsed.hostname, parsed.port)
    http.ipaddr = address
    http.use_ssl = parsed.scheme == "https"
    http.open_timeout = DEFAULT_OPEN_TIMEOUT
    http.read_timeout = DEFAULT_READ_TIMEOUT
    http.start { yield http }
  end

  def self.resolve_public!(uri)
    parsed = uri.is_a?(URI) ? uri : URI.parse(uri.to_s)
    raise ArgumentError, "unsupported scheme" unless parsed.scheme&.downcase&.in?(%w[http https])

    [parsed, resolve_public_host!(parsed.hostname)]
  end
  private_class_method :resolve_public!

  # Returns the first address of a host whose addresses are all public.
  def self.resolve_public_host!(hostname)
    raise ArgumentError, "missing host" if hostname.blank?

    addresses = Resolv.getaddresses(hostname)
    raise ArgumentError, "host does not resolve" if addresses.empty?
    raise ArgumentError, "host resolves to private address" if addresses.any? { |addr| private_ip?(addr) }

    addresses.first
  end

  def self.private_ip?(address)
    ip = IPAddr.new(address)
    ip = ip.native if ip.ipv4_mapped?
    BLOCKED_NETWORKS.any? { |network| network.family == ip.family && network.include?(ip) }
  rescue IPAddr::InvalidAddressError
    true
  end
  private_class_method :private_ip?
end
