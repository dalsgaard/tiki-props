require_relative '../libs/props'

module OAS
  using Props

  class Info
    props :title, :version, :description?
  end

  class Server
    props :url, :description?
  end

  class Spec
    props :openapi, info: Info, servers: [Server]
  end

end
