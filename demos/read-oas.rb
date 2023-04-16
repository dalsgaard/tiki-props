require 'json'
require_relative './oas'

spec = OAS::Spec.read './oas.demo.json'

puts spec.openapi, spec.info.version, spec.servers&.first&.variables('foo')&.default
