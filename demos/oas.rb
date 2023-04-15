require_relative '../libs/props'

module OAS
  using Props

  class Info
    props :title, :version, :description?
  end

  class Server
    class Variable
      props :default, :description?, :enum?
    end

    props :url, :description?, variables?: { variabe: Variable }
  end

  class Spec
    props :openapi, info: Info, servers: [Server]
  end
end
