require 'rubygems'
require 'rack/test'
require 'shoulda'

Rack::Test::Session.class_eval do
  def options(uri, params = {}, env = {}, &block)
    env = env_for(uri, env.merge(:method => "OPTIONS", :params => params))
    process_request(uri, env, &block)
  end
end

Rack::Test::Methods.class_eval do
  def_delegator :current_session, :options
end

class CorsTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    eval "Rack::Builder.new {( " + File.read(File.dirname(__FILE__) + '/test.ru') + "\n )}"
  end

  should('support simple cors request') { cors_request }

  should 'support regex origins configuration' do
    cors_request :origin => 'http://192.168.0.1:1234'
  end

  should 'support alternative X-Origin header' do
    header 'X-Origin', 'http://localhost:3000'
    get '/'
    assert_cors_success
  end

  should 'support expose header configuration' do
    cors_request '/expose_single_header'
    assert_equal 'expose-test', last_response.headers['Access-Control-Expose-Headers']

  end

  should 'support expose multiple header configuration' do
    cors_request '/expose_multiple_headers'
    assert_equal 'expose-test-1, expose-test-2', last_response.headers['Access-Control-Expose-Headers']
  end

  context 'preflight requests' do
    should 'fail if origin is invalid' do
      preflight_request('http://allyourdataarebelongtous.com', '/')
      assert_cors_failure
    end

    should 'fail if Access-Control-Request-Method does not exist' do
      preflight_request('http://localhost:3000', '/', :method => nil)
      assert_cors_failure
    end

    should 'fail if Access-Control-Request-Method is not allowed' do
      preflight_request('http://localhost:3000', '/get-only', :method => :post)
      assert_cors_failure
    end

    should 'fail if header is not allowed' do
      preflight_request('http://localhost:3000', '/single_header', :headers => 'Fooey')
      assert_cors_failure
    end

    should 'allow any header if headers = :any' do
      preflight_request('http://localhost:3000', '/', :headers => 'Fooey')
      assert_cors_success
    end

    should 'allow header case insensitive match' do
      preflight_request('http://localhost:3000', '/single_header', :headers => 'X-Domain-Token')
      assert_cors_success
    end

    should 'allow multiple headers match' do
      # Webkit style
      preflight_request('http://localhost:3000', '/two_headers', :headers => 'X-Requested-With, X-Domain-Token')
      assert_cors_success

      # Gecko style
      preflight_request('http://localhost:3000', '/two_headers', :headers => 'x-requested-with,x-domain-token')
      assert_cors_success
    end

    should '* origin should allow any origin' do
      preflight_request('http://locohost:3000', '/public')
      assert_cors_success
      assert_equal '*', last_response.headers['Access-Control-Allow-Origin']
    end

    should 'return a Content-Type' do
      preflight_request('http://localhost:3000', '/')
      assert_cors_success
      assert_not_nil last_response.headers['Content-Type']
    end
  end

  protected
    def cors_request(*args)
      path = args.first.is_a?(String) ? args.first : '/'

      opts = args.last.is_a?(Hash) ? args.last : {:origin => 'http://localhost:3000'}
      origin = opts[:origin]

      header 'Origin', origin
      get path
      assert_cors_success
    end

    def preflight_request(origin, path, opts = {})
      header 'Origin', origin
      unless opts.key?(:method) && opts[:method].nil?
        header 'Access-Control-Request-Method', opts[:method] ? opts[:method].to_s.upcase : 'GET'
      end
      if opts[:headers]
        header 'Access-Control-Request-Headers', opts[:headers]
      end
      options path
    end

    def assert_cors_success
      assert_not_nil last_response.headers['Access-Control-Allow-Origin'], 'missing Access-Control-Allow-Origin header'
    end

    def assert_cors_failure
      assert_nil last_response.headers['Access-Control-Allow-Origin'], 'no expecting Access-Control-Allow-Origin header'
    end
end