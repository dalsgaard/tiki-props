require 'json'
require_relative './oas'

input = JSON.parse(File.read('./oas.demo.json'))
spec = OAS::Spec.new input

puts spec.openapi, spec.info.version, spec.servers&.first&.variables&.[]('foo')&.default
