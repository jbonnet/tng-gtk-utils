## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).
# encoding: utf-8
# frozen_string_literal: true
require 'net/http'
require 'json'
require 'redis'
require 'tng/gtk/utils/logger'
require 'tng/gtk/utils/cache'

module Tng
  module Gtk
    module Utils

      class Fetch
        
        class << self; attr_accessor :site; end
  
        def self.call(params)
          msg=self.name+'#'+__method__.to_s
          began_at=Time.now.utc
          Tng::Gtk::Utils::Logger.info(start_stop: 'START', component:self.name, operation:__method__.to_s, message:"params=#{params} site=#{self.site}")
          original_params = params.dup
          begin
            if params.key?(:uuid)
              no_cache=ENV.fetch('NO_CACHE', nil)
              
              unless no_cache
                cached = Tng::Gtk::Utils::Cache.cached?(params[:uuid])
                return cached unless (cached.nil? || cached.empty?)
              end
              uuid = params.delete :uuid
              uri = URI.parse("#{self.site}/#{uuid}")
              # mind that there cany be more params, so we might need to pass params as well
            else
              uri = URI.parse(self.site)
              uri.query = URI.encode_www_form(sanitize(params))
            end
            Tng::Gtk::Utils::Logger.debug(component:self.name, operation:__method__.to_s, message:"uri=#{uri}")
            request = Net::HTTP::Get.new(uri)
            request['content-type'] = 'application/json'
            response = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(request)}
            Tng::Gtk::Utils::Logger.debug(component:self.name, operation:__method__.to_s, message:"response=#{response.inspect}")
            case response
            when Net::HTTPSuccess
              body = response.read_body
              Tng::Gtk::Utils::Logger.debug(component:self.name, operation:__method__.to_s, message:"body=#{body}", status: '200')
              result = JSON.parse(body, quirks_mode: true, symbolize_names: true)
              cache_result(result)
              Tng::Gtk::Utils::Logger.info(start_stop: 'STOP', component:self.name, operation:__method__.to_s, message:"result=#{result} site=#{self.site}", time_elapsed: Time.now.utc - began_at)
              return result
            when Net::HTTPNotFound
              Tng::Gtk::Utils::Logger.info(start_stop: 'STOP', component:self.name, operation:__method__.to_s, message:"body=#{body}", status:'404', time_elapsed: Time.now.utc - began_at)
              return {} unless uuid.nil?
              return []
            else
              Tng::Gtk::Utils::Logger.error(start_stop: 'STOP', component:self.name, operation:__method__.to_s, message:"#{response.message}", status:'404', time_elapsed: Time.now.utc - began_at)
              return nil
            end
          rescue Exception => e
            Tng::Gtk::Utils::Logger.error(start_stop: 'STOP', component:self.name, operation:__method__.to_s, message:"#{e.message}", time_elapsed: Time.now.utc - began_at)
          end
          nil
        end
  
        private
        def self.sanitize(params)
          params[:page_number] ||= ENV.fetch('DEFAULT_PAGE_NUMBER', 0)
          params[:page_size]   ||= ENV.fetch('DEFAULT_PAGE_SIZE', 100)
          params
        end
  
        def self.cache_result(result)
          Tng::Gtk::Utils::Logger.debug(component:self.name, operation:__method__.to_s, message:"result=#{result}")
          if result.is_a?(Hash)      
            STDERR.puts "Caching #{result}"
            Tng::Gtk::Utils::Cache.cache(result)
            return
          end
          STDERR.puts "#{result} is not an Hash"
          result.each do |record|
            STDERR.puts "Caching #{record}"
            Tng::Gtk::Utils::Cache.cache(record)
          end
        end
      end
    end
  end
end
