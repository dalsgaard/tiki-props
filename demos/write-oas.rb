require 'json'
require_relative './oas'

info = OAS::Info.new title: 'Demo', version: '1.0.0'
variables = {
  foo: OAS::Server::Variable.new(default: 8080),
  bar: OAS::Server::Variable.new(default: 8081)
}
servers = %w[http://foo.bar http://bar.baz].map { |url| OAS::Server.new(url:, variables:) }
spec = OAS::Spec.new(openapi: '3.0.3', info:, servers:)

spec.write 'oas.demo.json'
