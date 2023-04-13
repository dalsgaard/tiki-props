require 'json'
require_relative './oas'

info = OAS::Info.new title: 'Demo', version: '1.0.0'
servers = %w[http://foo.bar http://bar.baz].map { |url| OAS::Server.new url: url }
spec = OAS::Spec.new openapi: '3.0.3', info: info, servers: servers
File.write 'oas.json', JSON.pretty_generate(spec.serialize)
