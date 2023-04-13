require 'json'
require_relative './oas'

input = JSON.parse(File.read('./oas.json'))
spec = OAS::Spec.new input

puts spec.openapi, spec.info.version
