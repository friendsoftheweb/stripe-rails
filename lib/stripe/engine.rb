require 'stripe'

module Stripe
  class Engine < ::Rails::Engine
    isolate_namespace Stripe

    class << self
      attr_accessor :testing
    end

    config.stripe = Struct.new(:api_base, :secret_key, :verify_ssl_certs, :publishable_key, :endpoint, :debug_js, :auto_mount).new

    initializer 'stripe.configure.defaults', :before => 'stripe.configure' do |app|
      stripe = app.config.stripe
      stripe.secret_key ||= ENV['STRIPE_SECRET_KEY']
      stripe.endpoint ||= '/stripe'
      stripe.auto_mount = true if stripe.auto_mount.nil?
      if stripe.debug_js.nil?
        stripe.debug_js = ::Rails.env.development?
      end
    end

    initializer 'stripe.configure' do |app|
      [:api_base, :verify_ssl_certs].each do |key|
        value = app.config.stripe.send(key)
        Stripe.send("#{key}=", value) unless value.nil?
      end
      secret_key = app.config.stripe.secret_key
      Stripe.api_key = secret_key unless secret_key.nil?
      $stderr.puts <<-MSG unless Stripe.api_key
No stripe.com API key was configured for environment #{::Rails.env}! this application will be
unable to interact with stripe.com. You can set your API key with either the environment
variable `STRIPE_SECRET_KEY` (recommended) or by setting `config.stripe.secret_key` in your
environment file directly.
      MSG
    end

    initializer 'stripe.javascript_helper' do
      ActiveSupport.on_load :action_controller do
        helper Stripe::JavascriptHelper
      end
    end

    initializer 'stripe.plans_and_coupons' do |app|
      for configuration in %w(plans coupons)
        path = app.root.join("config/stripe/#{configuration}.rb")
        load path if path.exist?
      end
    end

    rake_tasks do
      load 'stripe/rails/tasks.rake'
    end
  end
end
