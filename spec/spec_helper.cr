require "spec"
require "pg"
require "../src/kemal-session-postgres"

Db         = DB.open "postgres://postgres:passw0rd@localhost:54321/test_db"
SESSION_ID = Random::Secure.hex

Spec.before_each do
  Kemal::Session.config.secret = "super-awesome-secret"
  Kemal::Session.config.engine = Kemal::Session::PostgresEngine.new(Db)
end

Spec.after_each do
  Db.exec("DROP TABLE IF EXISTS sessions")
end

# Utility for fact-checking session data against data in session table
def get_from_db(session_id : String)
  Db.query_one "SELECT data FROM sessions WHERE session_id = $1;", session_id, &.read(String)
end

def create_context(session_id : String)
  response = HTTP::Server::Response.new(IO::Memory.new)
  headers = HTTP::Headers.new

  unless session_id == ""
    Kemal::Session.config.engine.create_session(session_id)
    cookies = HTTP::Cookies.new
    cookies << HTTP::Cookie.new(Kemal::Session.config.cookie_name, Kemal::Session.encode(session_id))
    cookies.add_request_headers(headers)
  end

  request = HTTP::Request.new("GET", "/", headers)
  return HTTP::Server::Context.new(request, response)
end

class UserJsonSerializer
  JSON.mapping({
    id:   Int32,
    name: String,
  })
  include Kemal::Session::StorableObject

  def initialize(@id : Int32, @name : String); end

  def serialize
    self.to_json
  end

  def self.unserialize(value : String)
    UserJsonSerializer.from_json(value)
  end
end
